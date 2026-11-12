#include "gl_native_editor_api.h"
#include "gl_native_editor.h"
#include "gl_asset.h"
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/script_language_extension.hpp>

namespace {
using namespace godot;
String ImportPath(const Luau::AstExpr* Value) {
    auto Call=Value?Value->as<Luau::AstExprCall>():nullptr;
    auto Name=Call?Call->func->as<Luau::AstExprGlobal>():nullptr;
    if(!Name || std::string(Name->name.value)!="require" || Call->args.size!=1)return {};
    return String::utf8(GLNativeEditor::Text(Call->args.data[0]).c_str());
}
bool ModulePath(const String& Path) {
    return GLProjectResourcePath(Path) && (Path.get_extension()=="luau" || Path.get_extension()=="lua");
}
struct Navigation : Luau::AstVisitor {
    std::string Symbol;Luau::Position Cursor;
    std::unordered_map<const Luau::AstLocal*,const Luau::AstExpr*> Values;
    std::unordered_map<const Luau::AstLocal*,std::vector<Luau::Location>> References;
    const Luau::AstLocal* Local=nullptr;
    const Luau::AstExprIndexName* Member=nullptr;
    unsigned Visited=0;
    Navigation(std::string Name,Luau::Position Position):Symbol(std::move(Name)),Cursor(Position){}
    bool visit(Luau::AstNode*) override {return ++Visited<100000;}
    bool visit(Luau::AstStatLocal* Node) override {
        for(size_t I=0;I<Node->vars.size;++I) {
            auto Var=Node->vars.data[I];
            if(I<Node->values.size)Values[Var]=Node->values.data[I];
            if(Symbol==Var->name.value && (!Local || Var->location.containsClosed(Cursor)))Local=Var;
        }
        return ++Visited<100000;
    }
    bool visit(Luau::AstStatLocalFunction* Node) override {
        Values[Node->name]=Node->func;
        if(Symbol==Node->name->name.value && !Local)Local=Node->name;
        return ++Visited<100000;
    }
    bool visit(Luau::AstExprLocal* Node) override {
        auto& Uses=References[Node->local];if(Uses.size()<128)Uses.push_back(Node->location);
        if(Symbol==Node->local->name.value && Node->location.containsClosed(Cursor))Local=Node->local;
        return ++Visited<100000;
    }
    bool visit(Luau::AstExprIndexName* Node) override {
        if(Symbol==Node->index.value && Node->indexLocation.containsClosed(Cursor))Member=Node;
        return ++Visited<100000;
    }
};
int ExportLine(const String& Source,const std::string& Member) {
    auto Bytes=Source.utf8();Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Bytes.get_data(),Bytes.length(),Names,Allocator);
    if(!Parsed.root)return -1;
    std::unordered_map<const Luau::AstLocal*,const Luau::AstExpr*> Values;
    const Luau::AstExpr* Returned=nullptr;
    for(auto Statement:Parsed.root->body) {
        if(auto Local=Statement->as<Luau::AstStatLocal>())for(size_t I=0;I<Local->vars.size && I<Local->values.size;++I)Values[Local->vars.data[I]]=Local->values.data[I];
        if(auto Return=Statement->as<Luau::AstStatReturn>())if(Return->list.size==1)Returned=Return->list.data[0];
    }
    const Luau::AstLocal* ReturnedLocal=nullptr;
    if(auto Local=Returned?Returned->as<Luau::AstExprLocal>():nullptr) {
        ReturnedLocal=Local->local;auto Found=Values.find(ReturnedLocal);if(Found!=Values.end())Returned=Found->second;
    }
    if(auto Table=Returned?Returned->as<Luau::AstExprTable>():nullptr)for(const auto& Item:Table->items)
        if(GLNativeEditor::Text(Item.key)==Member) {
            if(auto Local=Item.value->as<Luau::AstExprLocal>())return int(Local->local->location.begin.line)+1;
            return int(Item.value->location.begin.line)+1;
        }
    if(ReturnedLocal)for(auto Statement:Parsed.root->body)if(auto Function=Statement->as<Luau::AstStatFunction>())
        if(auto Field=Function->name->as<Luau::AstExprIndexName>())if(Member==Field->index.value)
            if(auto Local=Field->expr->as<Luau::AstExprLocal>())if(Local->local==ReturnedLocal)return int(Statement->location.begin.line)+1;
    return -1;
}
}

godot::Dictionary GLInspectNativeCode(const godot::String& Code, const godot::String& Path) {
    return GLNativeEditor::Inspect(Code,Path);
}

godot::Dictionary GLNavigateNativeCode(const godot::String& Code,const godot::String& Symbol,const godot::String& Path) {
    using namespace godot;
    Dictionary Result; Result["result"]=ERR_UNAVAILABLE; Result["type"]=ScriptLanguageExtension::LOOKUP_RESULT_SCRIPT_LOCATION;
    if (Code.utf8().length()>1024*1024 || Symbol.length()>1024) return Result;
    String Target=Symbol;
    if (Target.begins_with("res://") && GLProjectResourcePath(Target) &&
        (Target.get_extension()=="lua" || Target.get_extension()=="luau") && FileAccess::file_exists(Target)) {
        Result["result"]=OK;Result["script_path"]=Target;Result["location"]=1;return Result;
    }
    String Clean=Code.replace(String::chr(0xffff),"");auto Bytes=Clean.utf8();
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Bytes.get_data(),Bytes.length(),Names,Allocator);
    if (!Parsed.root) return Result;
    Luau::Position Cursor(~0u,0);int Marker=Code.find(String::chr(0xffff));
    if(Marker>=0) {
        Cursor=Luau::Position(0,0);auto Prefix=Code.substr(0,Marker).utf8();
        for(int I=0;I<Prefix.length();++I)if(Prefix[I]=='\n'){++Cursor.line;Cursor.column=0;}else ++Cursor.column;
    }
    std::string Name=Symbol.utf8().get_data();auto Dot=Name.find('.');
    std::string Member=Dot==std::string::npos?std::string():Name.substr(Dot+1);
    Navigation Symbols(Dot==std::string::npos?Name:Name.substr(0,Dot),Cursor);Parsed.root->visit(&Symbols);
    if(Symbols.Member)if(auto Local=Symbols.Member->expr->as<Luau::AstExprLocal>()){Symbols.Local=Local->local;Member=Name;}
    if(Symbols.Local) {
        Array Uses;for(const auto& Location:Symbols.References[Symbols.Local]) {
            Dictionary Use;Use["path"]=Path;Use["line"]=int(Location.begin.line)+1;Use["column"]=int(Location.begin.column)+1;Uses.push_back(Use);
        }
        Result["references"]=Uses;
        auto Found=Symbols.Values.find(Symbols.Local);
        String Imported=Found==Symbols.Values.end()?String():ImportPath(Found->second);
        if(!Imported.is_empty()) {
            if(!ModulePath(Imported))return Result;
            Ref<FileAccess> File=FileAccess::open(Imported,FileAccess::READ);
            if(File.is_null() || File->get_length()>1024*1024)return Result;
            int Line=Member.empty()?1:ExportLine(File->get_as_text(),Member);
            if(Line<1)return Result;
            Result["result"]=OK;Result["script_path"]=Imported;Result["location"]=Line;return Result;
        }
        if(Member.empty()) {
            Result["result"]=OK;Result["script_path"]=Path;Result["location"]=int(Symbols.Local->location.begin.line)+1;return Result;
        }
    }
    if (GLNativeEditor::Class(Symbol.utf8().get_data())) {
        Result["result"]=OK; Result["type"]=ScriptLanguageExtension::LOOKUP_RESULT_CLASS;Result["class_name"]=Symbol;
        Result["description"]="Approved Scene class. Scene.Describe lists the admitted members.";return Result;
    }
    for (auto Statement:Parsed.root->body) {
        const char* Name=nullptr;
        if (auto Function=Statement->as<Luau::AstStatLocalFunction>()) Name=Function->name->name.value;
        if (auto Function=Statement->as<Luau::AstStatFunction>()) if (auto Global=Function->name->as<Luau::AstExprGlobal>()) Name=Global->name.value;
        if (Name && Symbol==String::utf8(Name)) {
            Result["result"]=OK;Result["script_path"]=Path;Result["location"]=int(Statement->location.begin.line)+1;return Result;
        }
    }
    return Result;
}
