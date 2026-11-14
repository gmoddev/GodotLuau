#include "gl_project_indexer.h"
#include "gl_native_declarations.gen.h"
#include "Luau/Ast.h"
#include "Luau/Parser.h"
#include "Luau/Frontend.h"
#include "Luau/Cancellation.h"
#include "Luau/ConfigResolver.h"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/Autocomplete.h"
#include "Luau/ToString.h"
#include "Luau/Error.h"
#include "Luau/AstQuery.h"
#include "Luau/TypePack.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <set>
#include <stdexcept>
#include <thread>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace {
using Entry=GLProjectIndexer::Entry;
constexpr size_t MaxFiles=4096, MaxBytes=32*1024*1024, MaxFileBytes=256*1024, PageSize=256;
using Clock=std::chrono::steady_clock;
bool ModulePath(const std::string& Name) {
    if(Name.size()>1024 || Name.compare(0,6,"res://") || Name.size()<7)return false;
    auto Relative=Name.substr(6);
    if(Relative.find_first_of("\\:\0",0,3)!=std::string::npos || Relative.find("//")!=std::string::npos || Relative.back()=='/')return false;
    for(unsigned char C:Relative)if(C<32 || C==127)return false;
    std::filesystem::path Path=std::filesystem::u8path(Relative);
    for(const auto& Component:Path) {
        auto Text=Component.u8string();
        if(Text.empty() || Text=="." || Text==".." || Text.back()=='.' || Text.back()==' ')return false;
    }
    return Relative[0]!='/' && (Path.extension()==".luau" || Path.extension()==".lua");
}
bool Identifier(const std::string& Name) {
    if(Name.empty() || Name.size()>128)return false;
    for(size_t I=0;I<Name.size();++I) {
        char C=Name[I];if(!((C>='A' && C<='Z') || (C>='a' && C<='z') || C=='_' || (I && C>='0' && C<='9')))return false;
    }
    static const std::set<std::string> Reserved={"and","break","continue","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while"};
    return !Reserved.count(Name);
}
bool Linked(const std::filesystem::path& Path) {
#ifdef _WIN32
    auto Attributes=GetFileAttributesW(Path.c_str());
    if(Attributes==INVALID_FILE_ATTRIBUTES || (Attributes&FILE_ATTRIBUTE_REPARSE_POINT))return true;
#endif
    std::error_code Error;auto Status=std::filesystem::symlink_status(Path,Error);
    if(Error || std::filesystem::is_symlink(Status))return true;
    return std::filesystem::is_regular_file(Status) && (std::filesystem::hard_link_count(Path,Error)!=1 || Error);
}
std::string Literal(const Luau::AstExpr* Expr) {
    if(auto Text=Expr?Expr->as<Luau::AstExprConstantString>():nullptr)return {Text->value.data,Text->value.size};
    return {};
}
std::string Import(const Luau::AstExpr* Expr) {
    auto Call=Expr?Expr->as<Luau::AstExprCall>():nullptr;
    auto Global=Call?Call->func->as<Luau::AstExprGlobal>():nullptr;
    if(!Global || std::string(Global->name.value)!="require" || Call->args.size!=1)return {};
    auto Name=Literal(Call->args.data[0]);return ModulePath(Name)?Name:std::string();
}
struct Document { std::string Source;std::vector<Entry> Entries;std::vector<std::string> Dependencies;uint64_t Revision=0;bool Incomplete=false; };
struct Writes:Luau::AstVisitor {
    std::set<const Luau::AstLocal*> Assigned;size_t Nodes=0;
    bool visit(Luau::AstNode*) override{return ++Nodes<100000;}
    bool visit(Luau::AstStatAssign* Node) override {
        for(auto Expr:Node->vars)if(auto Local=Expr->as<Luau::AstExprLocal>())Assigned.insert(Local->local);
        return ++Nodes<100000;
    }
};
struct Symbols:Luau::AstVisitor {
    Document& Doc;const Writes& Mutations;
    std::map<const Luau::AstLocal*,std::pair<std::string,std::string>> Imports;
    size_t Nodes=0;
    Symbols(Document& Value,const Writes& Changed):Doc(Value),Mutations(Changed){}
    bool Next(){if(++Nodes>=100000){Doc.Incomplete=true;return false;}return true;}
    bool visit(Luau::AstNode*) override{return Next();}
    void Add(const char* Name,const char* Kind,Luau::Location Where,std::string Target={},const Luau::Location* Definition=nullptr) {
        if(Doc.Entries.size()>=512 || std::char_traits<char>::length(Name)>128){Doc.Incomplete=true;return;}
        Entry Item;Item.Name=Name;Item.Kind=Kind;Item.Target=std::move(Target);
        Item.Line=int(Where.begin.line)+1;Item.Column=int(Where.begin.column)+1;
        if(Definition){Item.DefinitionLine=int(Definition->begin.line)+1;Item.DefinitionColumn=int(Definition->begin.column)+1;}
        Doc.Entries.push_back(std::move(Item));
    }
    std::pair<std::string,std::string> Resolve(const Luau::AstExpr* Expr) {
        auto Path=Import(Expr);if(!Path.empty())return {Path,{}};
        if(auto Local=Expr?Expr->as<Luau::AstExprLocal>():nullptr) {
            auto Found=Imports.find(Local->local);if(Found!=Imports.end())return Found->second;
        }
        if(auto Field=Expr?Expr->as<Luau::AstExprIndexName>():nullptr) {
            auto Base=Resolve(Field->expr);if(!Base.first.empty() && Base.second.empty())return {Base.first,Field->index.value};
        }
        return {};
    }
    bool visit(Luau::AstStatLocal* Node) override {
        for(size_t I=0;I<Node->vars.size;++I) {
            auto Local=Node->vars.data[I];Add(Local->name.value,"Local",Local->location);
            if(I<Node->values.size && !Mutations.Assigned.count(Local)) {
                auto Value=Resolve(Node->values.data[I]);if(!Value.first.empty())Imports[Local]=std::move(Value);
            }
        }
        return Next();
    }
    bool visit(Luau::AstStatLocalFunction* Node) override {Add(Node->name->name.value,"Function",Node->name->location);return Next();}
    bool visit(Luau::AstExprFunction* Node) override {
        for(auto Arg:Node->args)Add(Arg->name.value,"Argument",Arg->location);return Next();
    }
    bool visit(Luau::AstStatFunction* Node) override {
        if(auto Field=Node->name->as<Luau::AstExprIndexName>())Add(Field->index.value,"MemberFunction",Field->indexLocation);
        return Next();
    }
    bool visit(Luau::AstStatTypeAlias* Node) override {Add(Node->name.value,Node->exported?"ExportedType":"Type",Node->nameLocation);return Next();}
    bool visit(Luau::AstExprCall* Node) override {
        auto Path=Import(Node);if(!Path.empty()) {
            Add("require","Import",Node->location,Path);
            if(Doc.Dependencies.size()<128)Doc.Dependencies.push_back(Path);else Doc.Incomplete=true;
        }
        return Next();
    }
    bool visit(Luau::AstExprIndexName* Node) override {
        auto Value=Resolve(Node);Add(Node->index.value,Value.first.empty()?"SyntacticMember":"ImportedMember",Node->indexLocation,Value.first);return Next();
    }
    bool visit(Luau::AstExprLocal* Node) override {
        auto Found=Imports.find(Node->local);
        if(Found!=Imports.end() && !Found->second.second.empty())Add(Found->second.second.c_str(),"ImportedAlias",Node->location,Found->second.first);
        Add(Node->local->name.value,"LocalReference",Node->location,{},&Node->local->location);return Next();
    }
    bool visit(Luau::AstExprGlobal* Node) override {Add(Node->name.value,"SyntacticGlobal",Node->location);return Next();}
};
void Parse(Document& Doc) {
    Doc.Entries.clear();Doc.Dependencies.clear();Doc.Incomplete=false;
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Doc.Source.data(),Doc.Source.size(),Names,Allocator);
    if(!Parsed.root || !Parsed.errors.empty()){Doc.Incomplete=true;return;}
    Writes Mutations;Parsed.root->visit(&Mutations);
    if(Mutations.Nodes>=100000){Doc.Incomplete=true;return;}
    Symbols Visitor(Doc,Mutations);Parsed.root->visit(&Visitor);
}
struct Sources:Luau::FileResolver {
    std::map<std::string,Document> Files;
    std::set<std::string> Semantic;
    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& Name) override {
        auto It=Files.find(Name);if(It==Files.end() || !Semantic.count(Name))return {};
        return Luau::SourceCode{It->second.Source,Luau::SourceCode::Module};
    }
    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo*,Luau::AstExpr* Expr,const Luau::TypeCheckLimits&) override {
        auto Name=Literal(Expr);if(!ModulePath(Name) || !Files.count(Name))return {};
        return Luau::ModuleInfo{Name};
    }
};
}

struct GLProjectIndexer::State {
    mutable std::mutex Mutex;std::condition_variable Wake;
    std::thread Worker;std::atomic<uint64_t> Latest{0};bool Closing=false,Queued=false;
    Request Pending;std::shared_ptr<const Result> Ready;
    std::shared_ptr<Luau::FrontendCancellationToken> Cancellation;
    Sources Resolver;Luau::NullConfigResolver Config;
    std::unique_ptr<Luau::Frontend> Frontend;
    std::string Root,Definitions;
    bool Scanned=false,DiscoveryIncomplete=false;
    State(){Worker=std::thread([this]{Run();});}
    bool Cancelled(uint64_t Generation)const{return Latest.load()!=Generation;}
    void ResetFrontend(const Request& Value) {
        Resolver.Semantic.clear();Config.defaultConfig.mode=Luau::Mode::Strict;
        Luau::FrontendOptions Options;Options.retainFullTypeGraphs=true;Options.forAutocomplete=true;Options.moduleTimeLimitSec=0.05;
        Frontend=std::make_unique<Luau::Frontend>(&Resolver,&Config,Options);
        std::string DeclarationSource=Value.Definitions;
        if(DeclarationSource.empty()) {
            for(const char* Part:GLNative::EditorDeclarations)DeclarationSource+=Part;
            DeclarationSource+="\ndeclare script: {Parent: NativeNode}\ndeclare game: any\ndeclare __IS_CLIENT: boolean\n";
        }
        for(auto Globals:{&Frontend->globals,&Frontend->globalsForAutocomplete}) {
            Luau::unfreeze(Globals->globalTypes);Luau::registerBuiltinGlobals(*Frontend,*Globals);
            auto Loaded=Frontend->loadDefinitionFile(*Globals,Globals->globalScope,DeclarationSource,"GodotLuauNative",false,Globals==&Frontend->globalsForAutocomplete);
            if(!Loaded.success)throw std::runtime_error("Embedded native declarations could not be loaded");
            Luau::freeze(Globals->globalTypes);
        }
        Root=Value.Root;Definitions=Value.Definitions;
    }
    void Run() {
        for(;;) {
            Request Value;uint64_t Generation;
            {
                std::unique_lock<std::mutex> Lock(Mutex);Wake.wait(Lock,[this]{return Closing || Queued;});
                if(Closing)return;
                Value=std::move(Pending);Queued=false;Generation=Latest.load();
                Cancellation=std::make_shared<Luau::FrontendCancellationToken>();Cancellation->cancelled.store(false);
            }
            auto Report=std::make_shared<Result>();Report->Generation=Generation;auto Start=Clock::now();
            try {Analyze(Value,*Report);}catch(const std::exception& Error){Report->Error=std::string("[Editor:Index] ")+Error.what();Report->Incomplete=true;Frontend.reset();}
            Report->Microseconds=uint64_t(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now()-Start).count());
            std::lock_guard<std::mutex> Lock(Mutex);
            if(!Cancelled(Generation))Ready=std::move(Report);
        }
    }
    void Analyze(const Request& Value,Result& Report) {
        if(Root!=Value.Root || Definitions!=Value.Definitions){Resolver.Files.clear();Scanned=false;}
        if(!Frontend || Root!=Value.Root || Definitions!=Value.Definitions)ResetFrontend(Value);
        auto Generation=Report.Generation;
        std::error_code Error;auto Base=std::filesystem::absolute(std::filesystem::u8path(Value.Root),Error);
        if(Error || Base.empty()){Report.Error="Invalid project root";return;}
        bool Interactive=Scanned && !Value.Refresh && (Value.Query=="Complete" || Value.Query=="Definition" || Value.Query=="Rename");
        if(Interactive)Report.Incomplete=DiscoveryIncomplete;
        auto Ancestor=Base.root_path();for(const auto& Part:Base.relative_path()){Ancestor/=Part;if(Linked(Ancestor)){Report.Error="Linked project root refused";return;}}
        std::set<std::string> Discovered;std::vector<std::string> Order;
        auto Add=[&](const std::string& Name) {
            if(!ModulePath(Name))return;
            if(Discovered.size()>=MaxFiles){Report.Incomplete=true;return;}
            if(Discovered.insert(Name).second)Order.push_back(Name);
        };
        if(!Value.Active.empty())Add(Value.Active);
        for(const auto& Buffer:Value.Buffers)Add(Buffer.first);
        if(Interactive)for(const auto& Pair:Resolver.Files)Add(Pair.first);
        std::filesystem::recursive_directory_iterator It,End;
        if(!Interactive)It=std::filesystem::recursive_directory_iterator(Base,std::filesystem::directory_options::none,Error);
        size_t Visited=0;
        while(!Error && It!=End && !Cancelled(Generation)) {
            auto Path=It->path();bool Skip=It.depth()>16 || Path.filename().u8string().front()=='.' || Linked(Path);
            if(Skip)It.disable_recursion_pending();
            else if(It->is_regular_file(Error))Add("res://"+Path.lexically_relative(Base).generic_u8string());
            if(++Visited>=65536){Report.Incomplete=true;break;}
            It.increment(Error);
        }
        if(Cancelled(Generation))return;
        if(Error)Report.Incomplete=true;
        // Don't evict entries merely because discovery was bounded or interrupted.
        if(!Interactive && !Report.Incomplete)for(auto File=Resolver.Files.begin();File!=Resolver.Files.end();) {
            if(!Discovered.count(File->first)){Frontend->markDirty(File->first);File=Resolver.Files.erase(File);}else ++File;
        }
        std::vector<std::string> Changed;
        size_t RetainedBytes=0;for(const auto& Pair:Resolver.Files)RetainedBytes+=Pair.second.Source.size();
        for(const auto& Name:Order) {
            if(Cancelled(Generation))return;
            std::string Source;auto Buffer=Value.Buffers.find(Name);
            if(Buffer!=Value.Buffers.end())Source=Buffer->second;
            else {
                if(Interactive) {auto Found=Resolver.Files.find(Name);if(Found!=Resolver.Files.end()){++Report.Files;++Report.Cached;Report.Bytes+=Found->second.Source.size();}continue;}
                auto Path=Base/std::filesystem::u8path(Name.substr(6));
                bool Unsafe=false;auto PartPath=Base;for(const auto& Part:std::filesystem::u8path(Name.substr(6))){PartPath/=Part;if(Linked(PartPath)){Unsafe=true;break;}}
                if(Unsafe){Report.Incomplete=true;Frontend->markDirty(Name);Resolver.Files.erase(Name);continue;}
                auto Size=std::filesystem::file_size(Path,Error);
                if(Error || Size>MaxFileBytes){Report.Incomplete=true;Error.clear();Frontend->markDirty(Name);Resolver.Files.erase(Name);continue;}
                std::ifstream Input(Path,std::ios::binary);Source.resize(size_t(Size));Input.read(Source.data(),std::streamsize(Size));
                if(!Input){Report.Incomplete=true;Frontend->markDirty(Name);Resolver.Files.erase(Name);continue;}
            }
            if(Source.size()>MaxFileBytes || Report.Bytes+Source.size()>MaxBytes){Report.Incomplete=true;continue;}
            Report.Bytes+=Source.size();++Report.Files;
            auto Found=Resolver.Files.find(Name);
            if(Found!=Resolver.Files.end() && Found->second.Source==Source){++Report.Cached;continue;}
            size_t Previous=Found==Resolver.Files.end()?0:Found->second.Source.size();
            if(RetainedBytes-Previous+Source.size()>MaxBytes || (Found==Resolver.Files.end() && Resolver.Files.size()>=MaxFiles)){Report.Incomplete=true;continue;}
            RetainedBytes=RetainedBytes-Previous+Source.size();
            auto& Doc=Resolver.Files[Name];Doc.Source=std::move(Source);Doc.Revision=Generation;Parse(Doc);Changed.push_back(Name);++Report.Parsed;
        }
        if(!Interactive){Scanned=true;DiscoveryIncomplete=Report.Incomplete;}
        // markDirty uses the pinned frontend's reverse dependency graph.
        std::set<std::string> Invalidated;
        for(const auto& Name:Changed){std::vector<std::string> Dirty;Frontend->markDirty(Name,&Dirty);Invalidated.insert(Dirty.begin(),Dirty.end());}
        Report.Invalidated=Invalidated.size();
        std::set<std::string> Needed;size_t SemanticBytes=0;
        std::vector<std::string> ToCheck;
        if(Value.Query=="Diagnostics")ToCheck.insert(ToCheck.end(),Order.begin(),Order.end());
        if(ModulePath(Value.Active))ToCheck.push_back(Value.Active);
        while(!ToCheck.empty()) {
            auto Name=ToCheck.back();ToCheck.pop_back();auto Found=Resolver.Files.find(Name);
            if(Found==Resolver.Files.end() || Needed.count(Name))continue;
            if(Needed.size()>=256 || SemanticBytes+Found->second.Source.size()>4*1024*1024){Report.Incomplete=true;continue;}
            Needed.insert(Name);SemanticBytes+=Found->second.Source.size();
            ToCheck.insert(ToCheck.end(),Found->second.Dependencies.begin(),Found->second.Dependencies.end());
        }
        auto Allowed=Resolver.Semantic;Allowed.insert(Needed.begin(),Needed.end());
        size_t RetainedSemanticBytes=0;for(const auto& Name:Allowed){auto Found=Resolver.Files.find(Name);if(Found!=Resolver.Files.end())RetainedSemanticBytes+=Found->second.Source.size();}
        if(Allowed.size()>256 || RetainedSemanticBytes>4*1024*1024){ResetFrontend(Value);Allowed=Needed;}
        bool Expanded=Allowed!=Resolver.Semantic;Resolver.Semantic=std::move(Allowed);
        if(Expanded && Needed.count(Value.Active))Frontend->markDirty(Value.Active);
        auto Options=Frontend->options;Options.cancellationToken=Cancellation;
        // Analysis is demand-driven for active buffers; project diagnostics check
        // all discovered modules with a bounded total request time.
        auto Check=[&](const std::string& Name) {
            auto Checked=Frontend->check(Name,Options);
            if(!Checked.timeoutHits.empty())Report.Incomplete=true;
            for(const auto& Diagnostic:Checked.errors) {
                if(Report.Diagnostics.size()>=256){Report.Incomplete=true;break;}
                Entry Item;Item.Path=Diagnostic.moduleName;Item.Kind="Diagnostic";Item.Name=Luau::toString(Diagnostic).substr(0,2048);
                Item.Line=int(Diagnostic.location.begin.line)+1;Item.Column=int(Diagnostic.location.begin.column)+1;
                Report.Diagnostics.push_back(std::move(Item));
            }
        };
        if(Needed.count(Value.Active) && !Cancelled(Generation))Check(Value.Active);
        if(Value.Query=="Diagnostics")for(const auto& Name:Needed) {
            if(Cancelled(Generation))return;
            Check(Name);
        }
        if(Cancelled(Generation))return;
        auto Emit=[&](Entry Item) {if(Report.Matches++<Value.Offset)return;if(Report.Entries.size()<PageSize)Report.Entries.push_back(std::move(Item));else Report.More=true;};
        if(Value.Query=="Complete" && Resolver.Files.count(Value.Active)) {
            auto Completed=Luau::autocomplete(*Frontend,Value.Active,Luau::Position(unsigned(std::max(1,Value.Line)-1),unsigned(std::max(1,Value.Column)-1)),{});
            std::map<std::string,Luau::AutocompleteEntry> Sorted(Completed.entryMap.begin(),Completed.entryMap.end());
            for(const auto& Pair:Sorted) {
                if(Pair.first.find(Value.Member)!=0)continue;
                Entry Item;Item.Name=Pair.first;Item.Kind="Completion";
                if(Pair.second.type){Luau::ToStringOptions Display;Display.maxTypeLength=2048;Display.maxTableLength=1024;Item.Type=Luau::toString(*Pair.second.type,Display).substr(0,2048);}Emit(std::move(Item));
            }
            return;
        }
        const Entry* Selected=nullptr;
        auto Current=Resolver.Files.find(Value.Active);
        if(Current!=Resolver.Files.end())for(const auto& Item:Current->second.Entries)
            if(Item.Line==Value.Line && Value.Column>=Item.Column && Value.Column<Item.Column+int(Item.Name.size())){Selected=&Item;break;}
        if(Value.Query=="Definition" && Needed.count(Value.Active)) {
            auto Source=Frontend->getSourceModule(Value.Active);auto Module=Frontend->moduleResolverForAutocomplete.getModule(Value.Active);
            if(Source && Module)if(auto Type=Luau::findTypeAtPosition(*Module,*Source,Luau::Position(unsigned(std::max(1,Value.Line)-1),unsigned(std::max(1,Value.Column)-1))))
                if(auto Function=Luau::get<Luau::FunctionType>(Luau::follow(*Type));Function && Function->definition && Function->definition->definitionModuleName) {
                    Entry Item;Item.Name=Selected?Selected->Name:Value.Member;Item.Kind="Definition";Item.Path=*Function->definition->definitionModuleName;
                    Item.Line=int(Function->definition->originalNameLocation.begin.line)+1;Item.Column=int(Function->definition->originalNameLocation.begin.column)+1;
                    Emit(std::move(Item));return;
                }
            if(Selected && Selected->Kind=="ImportedMember") {
                auto Imported=Frontend->moduleResolverForAutocomplete.getModule(Selected->Target);
                if(Imported && Imported->returnType)if(auto First=Luau::first(Imported->returnType))
                    if(auto Table=Luau::get<Luau::TableType>(Luau::follow(*First))) {
                        auto Property=Table->props.find(Selected->Name);
                        if(Property!=Table->props.end() && Property->second.location && !Table->definitionModuleName.empty()) {
                            Entry Item;Item.Name=Selected->Name;Item.Kind="Definition";Item.Path=Table->definitionModuleName;
                            Item.Line=int(Property->second.location->begin.line)+1;Item.Column=int(Property->second.location->begin.column)+1;Emit(std::move(Item));return;
                        }
                    }
            }
        }
        if(Value.Query=="Rename" && (!Selected || !Identifier(Value.Replacement) || Current->second.Incomplete)) {Report.Error="Rename requires a complete lexical binding and an identifier";return;}
        int DefinitionLine=Selected?(Selected->DefinitionLine?Selected->DefinitionLine:Selected->Line):0;
        int DefinitionColumn=Selected?(Selected->DefinitionLine?Selected->DefinitionColumn:Selected->Column):0;
        if(Value.Query=="Rename") {
            if(Selected->Kind!="Local" && Selected->Kind!="Function" && Selected->Kind!="Argument" && Selected->Kind!="LocalReference") {Report.Error="Only exact lexical bindings support rename";return;}
            for(const auto& Item:Current->second.Entries)if(Item.Name==Value.Replacement) {Report.Error="Rename could capture another binding";return;}
            Report.Revisions[Value.Active]=Current->second.Source;
        }
        size_t DependencyIndex=0;
        for(const auto& Pair:Resolver.Files) {
            if(Cancelled(Generation))return;
            const auto& Name=Pair.first;const auto& Doc=Pair.second;
            Report.Incomplete|=Doc.Incomplete;
            if(Value.Query=="Dependencies") {
                if(DependencyIndex++>=Value.Offset && Report.Dependencies.size()<PageSize)Report.Dependencies[Name]=Doc.Dependencies;
                Report.More=DependencyIndex>Value.Offset+PageSize;continue;
            }
            for(auto Item:Doc.Entries) {
                Item.Path=Name;Item.Revision=Doc.Revision;
                if(Value.Query=="References" && ((Item.Kind!="ImportedMember" && Item.Kind!="ImportedAlias") || Item.Target!=Value.Module || Item.Name!=Value.Member))continue;
                if(Value.Query=="Search" && Item.Name.find(Value.Member)==std::string::npos)continue;
                if(Value.Query=="Rename") {
                    if(Name!=Value.Active || Item.Name!=Selected->Name)continue;
                    bool Definition=Item.Line==DefinitionLine && Item.Column==DefinitionColumn;
                    if(!Definition && (Item.Kind!="LocalReference" || Item.DefinitionLine!=DefinitionLine || Item.DefinitionColumn!=DefinitionColumn))continue;
                    Item.Target=Value.Replacement;
                }
                if(Value.Query=="Definition") {
                    if(!Selected)continue;
                    if(Selected->Kind=="Import") {if(Name!=Selected->Target)continue;Item.Line=1;Item.Column=1;Emit(Item);return;}
                    if(Selected->Kind=="ImportedMember") {
                        if(Name!=Selected->Target || Item.Name!=Selected->Name || (Item.Kind!="Function" && Item.Kind!="MemberFunction"))continue;
                        // A named table member is a candidate, not proof it is exported.
                        Item.Kind="DefinitionCandidate";
                    } else if(Name!=Value.Active || Item.Line!=DefinitionLine || Item.Column!=DefinitionColumn)continue;
                }
                Emit(std::move(Item));
            }
        }
    }
};
GLProjectIndexer::GLProjectIndexer():Data(std::make_unique<State>()){}
GLProjectIndexer::~GLProjectIndexer() {
    {std::lock_guard<std::mutex> Lock(Data->Mutex);Data->Closing=true;++Data->Latest;if(Data->Cancellation)Data->Cancellation->cancel();}
    Data->Wake.notify_one();Data->Worker.join();
}
uint64_t GLProjectIndexer::Submit(Request Value) {
    std::lock_guard<std::mutex> Lock(Data->Mutex);
    static const std::set<std::string> Queries={"Symbols","References","Search","Complete","Definition","Rename","Diagnostics","Dependencies"};
    if(Value.Buffers.size()>64 || Value.Definitions.size()>4*1024*1024 || !Queries.count(Value.Query) || Value.Member.size()>128 || Value.Root.size()>4096 || Value.Offset>4096*512 || Value.Line<1 || Value.Column<1 || Value.Line>256*1024 || Value.Column>256*1024)return 0;
    size_t Bytes=0;for(const auto& Pair:Value.Buffers){Bytes+=Pair.second.size();if(Pair.second.size()>MaxFileBytes || Bytes>8*1024*1024 || !ModulePath(Pair.first))return 0;}
    if(Data->Cancellation)Data->Cancellation->cancel();
    Data->Pending=std::move(Value);Data->Queued=true;auto Generation=++Data->Latest;
    Data->Wake.notify_one();return Generation;
}
std::shared_ptr<const GLProjectIndexer::Result> GLProjectIndexer::Poll(uint64_t Generation)const {
    std::lock_guard<std::mutex> Lock(Data->Mutex);return Generation==Data->Latest.load() && Data->Ready && Data->Ready->Generation==Generation?Data->Ready:nullptr;
}
void GLProjectIndexer::Cancel() {
    std::lock_guard<std::mutex> Lock(Data->Mutex);++Data->Latest;Data->Queued=false;if(Data->Cancellation)Data->Cancellation->cancel();
}
