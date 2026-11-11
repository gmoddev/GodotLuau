#include "gl_native_editor_api.h"
#include "gl_native_editor.h"
#include "gl_asset.h"
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/script_language_extension.hpp>

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
    if (GLNativeEditor::Class(Symbol.utf8().get_data())) {
        Result["result"]=OK; Result["type"]=ScriptLanguageExtension::LOOKUP_RESULT_CLASS;Result["class_name"]=Symbol;
        Result["description"]="Approved Scene class. Scene.Describe lists the admitted members.";return Result;
    }
    String Clean=Code.replace(String::chr(0xffff),"");auto Bytes=Clean.utf8();
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Bytes.get_data(),Bytes.length(),Names,Allocator);
    if (!Parsed.root) return Result;
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
