#include "gl_native_editor_api.h"
#include "gl_native_editor.h"
#include "gl_execution_domain.h"
#include "gl_asset.h"
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>
#include <algorithm>
#include <cstring>
#include <vector>
#include <map>
#include <set>

namespace {
using namespace godot;
struct Use {std::string Module,Member;int Line,Column;};
struct Cached {std::string Hash;std::vector<Use> Uses;bool Complete=true;};
// Pure strings/coordinates only; no AST pointers, Godot objects or VM roots.
std::map<std::string,Cached> Cache;
String Import(const Luau::AstExpr* Value) {
    auto Call=Value?Value->as<Luau::AstExprCall>():nullptr;
    auto Global=Call?Call->func->as<Luau::AstExprGlobal>():nullptr;
    if(!Global || std::strcmp(Global->name.value,"require") || Call->args.size!=1)return {};
    String Path=String::utf8(GLNativeEditor::Text(Call->args.data[0]).c_str());
    if(!GLProjectResourcePath(Path) || (Path.get_extension()!="luau" && Path.get_extension()!="lua"))return {};
    return Path;
}
struct Writes : Luau::AstVisitor {
    std::set<const Luau::AstLocal*> Assigned;
    unsigned Visited=0;
    bool visit(Luau::AstNode*) override {return ++Visited<100000;}
    bool visit(Luau::AstStatAssign* Node) override {
        for(auto Value:Node->vars)if(auto Local=Value->as<Luau::AstExprLocal>())Assigned.insert(Local->local);
        return ++Visited<100000;
    }
};
struct References : Luau::AstVisitor {
    const std::set<const Luau::AstLocal*>& Assigned;
    std::map<const Luau::AstLocal*,std::pair<std::string,std::string>> Imports;
    std::vector<Use> Uses;unsigned Visited=0;bool Complete=true;
    explicit References(const std::set<const Luau::AstLocal*>& Values):Assigned(Values){}
    bool Continue() {if(++Visited>=100000){Complete=false;return false;}return true;}
    bool visit(Luau::AstNode*) override {return Continue();}
    std::pair<std::string,std::string> Resolve(const Luau::AstExpr* Value) {
        String Path=Import(Value);if(!Path.is_empty())return {Path.utf8().get_data(),{}};
        if(auto Local=Value?Value->as<Luau::AstExprLocal>():nullptr) {
            auto Found=Imports.find(Local->local);if(Found!=Imports.end())return Found->second;
        }
        if(auto Field=Value?Value->as<Luau::AstExprIndexName>():nullptr) {
            auto Base=Field->expr->as<Luau::AstExprLocal>();
            auto Found=Base?Imports.find(Base->local):Imports.end();
            if(Found!=Imports.end() && Found->second.second.empty())return {Found->second.first,Field->index.value};
        }
        return {};
    }
    void Add(const std::pair<std::string,std::string>& Value,const Luau::Location& Location) {
        if(Value.first.empty() || Value.second.empty())return;
        if(Uses.size()>=128){Complete=false;return;}
        Uses.push_back({Value.first,Value.second,int(Location.begin.line)+1,int(Location.begin.column)+1});
    }
    bool visit(Luau::AstStatLocal* Node) override {
        for(size_t I=0;I<Node->vars.size && I<Node->values.size;++I) {
            auto Local=Node->vars.data[I];if(Assigned.count(Local))continue;
            auto Value=Resolve(Node->values.data[I]);if(!Value.first.empty())Imports[Local]=Value;
        }
        return Continue();
    }
    bool visit(Luau::AstExprIndexName* Node) override {Add(Resolve(Node),Node->indexLocation);return Continue();}
    bool visit(Luau::AstExprLocal* Node) override {
        auto Found=Imports.find(Node->local);if(Found!=Imports.end())Add(Found->second,Node->location);
        return Continue();
    }
};
Cached Parse(const String& Source,const std::string& Hash) {
    Cached Result;Result.Hash=Hash;auto Bytes=Source.utf8();
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Bytes.get_data(),Bytes.length(),Names,Allocator);
    if(!Parsed.root || !Parsed.errors.empty()){Result.Complete=false;return Result;}
    Writes Mutations;Parsed.root->visit(&Mutations);
    if(Mutations.Visited>=100000){Result.Complete=false;return Result;}
    References Visitor(Mutations.Assigned);Parsed.root->visit(&Visitor);
    Result.Uses=std::move(Visitor.Uses);Result.Complete=Visitor.Complete;return Result;
}
}

godot::Dictionary GLIndexProjectModule(const godot::String& Module,const godot::String& Member,const godot::Dictionary& Buffers) {
    using namespace godot;
    Dictionary Result;Result["result"]=ERR_UNAVAILABLE;Result["References"]=Array();
    String TargetModule=Module;
    if(!Engine::get_singleton()->is_editor_hint() || GLExecutionDomain::IsExecuting() || OS::get_singleton()->get_thread_caller_id()!=OS::get_singleton()->get_main_thread_id() ||
       !GLProjectResourcePath(TargetModule) || (TargetModule.get_extension()!="luau" && TargetModule.get_extension()!="lua") || Member.is_empty() || Member.utf8().length()>128)return Result;
    for(int Index=0;Index<Member.length();++Index) {
        char32_t C=Member[Index];if(!((C>='A'&&C<='Z')||(C>='a'&&C<='z')||C=='_'||(Index>0&&C>='0'&&C<='9')))return Result;
    }
    const uint64_t Started=Time::get_singleton()->get_ticks_usec();
    std::set<std::string> Files;std::vector<std::pair<String,int>> Directories{{"res://",0}};
    bool Truncated=false;int ScannedDirectories=0;
    while(!Directories.empty()) {
        auto Entry=Directories.back();Directories.pop_back();
        if(++ScannedDirectories>256){Truncated=true;break;}
        String Checked=Entry.second?Entry.first:String("res://__GodotLuauIndexRoot__");
        if(!GLProjectResourcePath(Checked)){Truncated=true;continue;}
        Ref<DirAccess> Directory=DirAccess::open(Entry.first);if(Directory.is_null()){Truncated=true;continue;}
        if(Directory->list_dir_begin()!=OK){Truncated=true;continue;}
        std::vector<std::pair<String,bool>> Names;
        for(String Name=Directory->get_next();!Name.is_empty();Name=Directory->get_next()) {
            if(Name.begins_with(".") || Directory->is_link(Name))continue;
            if(Names.size()>=2048){Truncated=true;break;}
            Names.push_back({Name,Directory->current_is_dir()});
        }
        Directory->list_dir_end();std::sort(Names.begin(),Names.end(),[](const auto& A,const auto& B){return A.first<B.first;});
        for(const auto& Name:Names) {
            String Path=Entry.first.path_join(Name.first);
            if(Name.second) {if(Entry.second<8)Directories.push_back({Path,Entry.second+1});else Truncated=true;}
            else if((Path.get_extension()=="luau" || Path.get_extension()=="lua") && GLProjectResourcePath(Path)) {
                if(Files.size()>=256){Truncated=true;continue;}Files.insert(Path.utf8().get_data());
            }
        }
        if(Time::get_singleton()->get_ticks_usec()-Started>250000){Truncated=true;break;}
    }
    Array Matches;size_t BytesRead=0;int ParsedCount=0,CachedCount=0,Scanned=0;std::set<std::string> Retained;
    const std::string WantedModule=TargetModule.utf8().get_data(),WantedMember=Member.utf8().get_data();
    for(const auto& Path:Files) {
        if(Time::get_singleton()->get_ticks_usec()-Started>250000){Truncated=true;break;}
        String NativePath=String::utf8(Path.c_str()),Source;
        if(Buffers.has(NativePath) && Buffers[NativePath].get_type()==Variant::STRING)Source=Buffers[NativePath];
        else {
            Ref<FileAccess> File=FileAccess::open(NativePath,FileAccess::READ);
            if(File.is_null() || File->get_length()>256*1024){Truncated=true;continue;}
            Source=File->get_as_text();
        }
        auto Bytes=Source.utf8();
        if(Bytes.length()>256*1024 || BytesRead+Bytes.length()>8*1024*1024){Truncated=true;continue;}
        BytesRead+=Bytes.length();++Scanned;Retained.insert(Path);
        std::string Hash=Source.sha256_text().utf8().get_data();auto Found=Cache.find(Path);
        if(Found==Cache.end() || Found->second.Hash!=Hash){Found=Cache.insert_or_assign(Path,Parse(Source,Hash)).first;++ParsedCount;}
        else ++CachedCount;
        if(!Found->second.Complete)Truncated=true;
        for(const auto& Use:Found->second.Uses)if(Use.Module==WantedModule && Use.Member==WantedMember) {
            if(Matches.size()>=1024){Truncated=true;break;}
            Dictionary Item;Item["Path"]=NativePath;Item["Line"]=Use.Line;Item["Column"]=Use.Column;Item["SourceSHA256"]=String::utf8(Hash.c_str());Matches.push_back(Item);
        }
    }
    for(auto Entry=Cache.begin();Entry!=Cache.end();)if(!Retained.count(Entry->first))Entry=Cache.erase(Entry);else ++Entry;
    Result["result"]=OK;Result["Module"]=TargetModule;Result["Member"]=Member;Result["References"]=Matches;
    Result["ScannedFiles"]=Scanned;Result["ParsedFiles"]=ParsedCount;Result["CachedFiles"]=CachedCount;Result["BytesRead"]=int64_t(BytesRead);
    Result["Truncated"]=Truncated;Result["Microseconds"]=int64_t(Time::get_singleton()->get_ticks_usec()-Started);
    Result["Scope"]="Static require member/alias uses; reassigned imports and dynamic exports are unsupported";
    Result["ColumnEncoding"]="UTF-8 bytes; navigation opens the exact source line";
    return Result;
}
