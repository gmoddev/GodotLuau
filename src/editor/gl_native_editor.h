#ifndef GL_NATIVE_EDITOR_H
#define GL_NATIVE_EDITOR_H

#include "gl_native_registry.gen.h"
#include "gl_native_values.h"
#include "Luau/Ast.h"
#include "Luau/Parser.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <cmath>
#include <string>
#include <unordered_map>
#include <unordered_set>

// Read-only syntax/metadata tooling. No script execution or native instantiation.
namespace GLNativeEditor {
struct Handle { std::string Class; bool Scope=false; bool Resource=false; bool Mutable=false; };
inline const GLNative::Class* Class(const std::string& Name) {
    for (const auto& Item:GLNative::Classes) if (Name==Item.Name) return &Item;
    return nullptr;
}
inline bool IsA(std::string Name, const char* Base) {
    for (int Depth=0;!Name.empty() && Depth<64;++Depth) {
        if (Name==Base) return true;
        auto Item=Class(Name); if (!Item) break;
        Name=Item->Base;
    }
    return false;
}
inline std::string Text(const Luau::AstExpr* Expression) {
    if (Expression) if (auto Value=Expression->as<Luau::AstExprConstantString>()) return std::string(Value->value.data,Value->value.size);
    return {};
}
inline const GLNative::Property* Property(const std::string& Name, const std::string& Key) {
    const GLNative::Property* Best=nullptr;
    for (const auto& Item:GLNative::Properties) if (Key==Item.Name && IsA(Name,Item.Class) && (!Best || IsA(Item.Class,Best->Class))) Best=&Item;
    return Best;
}
inline const GLNative::Method* Method(const std::string& Name, const std::string& Key) {
    const GLNative::Method* Best=nullptr;
    for (const auto& Item:GLNative::Methods) if (Key==Item.Name && IsA(Name,Item.Class) && (!Best || IsA(Item.Class,Best->Class))) Best=&Item;
    return Best;
}
inline std::string TypeName(GLNative::Kind Type,const char* Class=nullptr,const char* Element=nullptr) {
    if(Element)return std::string("Array<")+Element+">";
    if(Class)return Class;
    if(auto Name=GLNativeValueName(Type))return Name;
    switch(Type) {
        case GLNative::Number:return "number";case GLNative::Integer:return "integer";
        case GLNative::Boolean:return "boolean";case GLNative::Text:return "string";
        case GLNative::Colour:return "Color3";case GLNative::Void:return "()";
        default:return "native value";
    }
}
inline std::string Signature(const GLNative::Method& Method) {
    std::string Result=std::string(Method.Class)+"."+Method.Name+"(";
    for(int Index=0;Index<Method.Arguments;++Index) {
        const auto& Argument=GLNative::Arguments[Method.FirstArgument+Index];
        if(Index)Result+=", ";
        Result+=std::string(Argument.Name)+": "+TypeName(Argument.Type,Argument.ResourceClass,Argument.Element);
        if(Argument.Default)Result+=" = "+std::string(Argument.Default);
    }
    return Result+") -> "+TypeName(Method.Return,Method.ReturnClass,Method.ReturnElement);
}
inline std::string StaticPath(const Luau::AstExpr* Expression,int Depth=0) {
    if(!Expression || Depth>16)return {};
    if(auto Global=Expression->as<Luau::AstExprGlobal>())return Global->name.value;
    if(auto Field=Expression->as<Luau::AstExprIndexName>()) {
        auto Parent=StaticPath(Field->expr,Depth+1);if(!Parent.empty())return Parent+"."+Field->index.value;
    }
    return {};
}
inline bool Operation(const std::string& Name) {
    for (const auto& Item:GLNative::ScopeOperations) if (Name==Item.Name) return true;
    return Name=="Destroy" || Name=="IsA" || Name=="GetChildren" || Name=="GetDescendants" || Name=="FindFirstChild";
}
class Visitor : public Luau::AstVisitor {
    static constexpr const char* Marker="__GLNativeCursor__";
    std::unordered_map<const Luau::AstLocal*,Handle> Locals;
    std::unordered_set<std::string> Errors, Suggestions;
    godot::String Path;
    Luau::Position CursorPosition;
    unsigned Visited=0;
    bool Continue() { return ++Visited<100000; }
    void Error(const Luau::Location& Location, const char* Code, const std::string& Message) {
        if (Diagnostics.size()>=64) return;
        std::string Key=std::to_string(Location.begin.line)+":"+std::to_string(Location.begin.column)+Code;
        if (!Errors.insert(Key).second) return;
        godot::Dictionary Item;
        Item["line"]=int(Location.begin.line+1); Item["column"]=int(Location.begin.column+1);
        Item["path"]=Path; Item["code"]=Code; Item["message"]=godot::String::utf8(Message.c_str());
        Diagnostics.push_back(Item);
    }
    void Suggest(const char* Name, const std::string& Filter, int Kind, const char* Signature) {
        if (Options.size()>=128 || std::string(Name).find(Filter)!=0 || !Suggestions.insert(Name).second) return;
        godot::Dictionary Item;
        Item["display"]=Name; Item["insert_text"]=Name; Item["kind"]=Kind; Item["type"]=1;
        Item["description"]=Signature; Item["location"]=0; Item["default_value"]=godot::Variant();
        Item["font_color"]=godot::Color(0.85f,0.9f,1.f); Item["icon"]=godot::Variant();
        Item["matches"]=godot::PackedInt32Array();
        Options.push_back(Item);
    }
    bool Cursor(const std::string& Name, std::string& Filter) {
        auto Position=Name.find(Marker); if (Position==std::string::npos) return false;
        Filter=Name.substr(0,Position); return true;
    }
    Handle Annotation(const Luau::AstType* Annotation) {
        if (!Annotation) return {};
        if (auto Type=Annotation->as<Luau::AstTypeReference>()) {
            std::string Name=Type->name.value;
            if (Name=="NativeSceneScope") return {"Node3D",true,false,true};
            bool Mutable=Name.find("MutableNative")==0;
            if (Mutable) Name=Name.substr(13);
            else if (Name.find("Native")==0) Name=Name.substr(6);
            else return {};
            if (auto Info=Class(Name)) return {Name,false,Info->Resource,Mutable};
        }
        return {};
    }
    Handle Infer(const Luau::AstExpr* Expression, int Depth=0) {
        if (!Expression || Depth>16) return {};
        if (auto Local=Expression->as<Luau::AstExprLocal>()) {
            auto Found=Locals.find(Local->local); return Found==Locals.end()?Handle{}:Found->second;
        }
        if (auto Group=Expression->as<Luau::AstExprGroup>()) return Infer(Group->expr,Depth+1);
        if (auto Assertion=Expression->as<Luau::AstExprTypeAssertion>()) {
            Handle Type=Annotation(Assertion->annotation);
            return Type.Class.empty()?Infer(Assertion->expr,Depth+1):Type;
        }
        auto Call=Expression->as<Luau::AstExprCall>();
        if (!Call) return {};
        auto Function=Call->func->as<Luau::AstExprIndexName>(); if (!Function) return {};
        std::string Name=Function->index.value;
        if (auto Global=Function->expr->as<Luau::AstExprGlobal>())
            if (std::string(Global->name.value)=="Scene" && Name=="new") return {"Node3D",true,false,true};
        auto Receiver=Infer(Function->expr,Depth+1);
        size_t Offset=Call->self?0:1;
        if (!Receiver.Scope || Call->args.size<=Offset) return {};
        if (Name=="New" || Name=="Load") {
            std::string Target=Text(Call->args.data[Offset]);
            if (auto Info=Class(Target)) return {Target,false,Info->Resource,Name=="New"};
        }
        if (Name=="Get" && Call->args.size>Offset+1) {
            auto Target=Infer(Call->args.data[Offset],Depth+1);
            if (auto Info=Property(Target.Class,Text(Call->args.data[Offset+1])))
                if (Info->Type==GLNative::ResourceValue) return {Info->ResourceClass,false,true,false};
        }
        if(Name=="Call" && Call->args.size>Offset+1) {
            auto Target=Infer(Call->args.data[Offset],Depth+1);
            if(auto Info=Method(Target.Class,Text(Call->args.data[Offset+1])))
                if(Info->ReturnClass)if(auto Returned=Class(Info->ReturnClass))return {Returned->Name,false,Returned->Resource,false};
        }
        if (Name=="Clone") return Infer(Call->args.data[Offset],Depth+1);
        if (Name=="Instantiate") return {"Node",false,false,true};
        return {};
    }
    void CheckValue(const GLNative::Property& Item, const Luau::AstExpr* Value) {
        if (!Value) return;
        bool Wrong=false;
        if (auto Number=Value->as<Luau::AstExprConstantNumber>()) {
            Wrong=(Item.Type!=GLNative::Number && Item.Type!=GLNative::Integer && Item.Type!=GLNative::VariantValue) || !std::isfinite(Number->value) ||
                Number->value<Item.Min || Number->value>Item.Max || (Item.Type==GLNative::Integer && std::floor(Number->value)!=Number->value);
        } else if (Value->is<Luau::AstExprConstantBool>()) Wrong=Item.Type!=GLNative::Boolean && Item.Type!=GLNative::VariantValue;
        else if (auto String=Value->as<Luau::AstExprConstantString>()) Wrong=(Item.Type!=GLNative::Text && Item.Type!=GLNative::VariantValue && Item.Type!=GLNative::PathValue) || (Item.Type==GLNative::Text && (String->value.size<Item.Min || String->value.size>Item.Max));
        else if (Value->is<Luau::AstExprConstantNil>()) Wrong=Item.Type!=GLNative::ResourceValue && Item.Type!=GLNative::NodeValue && Item.Type!=GLNative::VariantValue;
        else if (Value->is<Luau::AstExprTable>()) Wrong=Item.Type!=GLNative::Vector2Value && Item.Type<=GLNative::Void;
        if (Wrong) Error(Value->location,"E_NATIVE_TYPE",std::string("Invalid literal for ")+Item.Class+"."+Item.Name+"; check the native type and bounds");
    }
    void CheckProperties(const Handle& Target, const Luau::AstExpr* Expression) {
        if (Target.Class.empty()) return;
        if (Target.Resource && !Target.Mutable) Error(Expression->location,"E_NATIVE_IMMUTABLE","Loaded/getter resource handles cannot be configured");
        auto Table=Expression->as<Luau::AstExprTable>(); if (!Table) return;
        for (const auto& Entry:Table->items) {
            if (!Entry.key || !Entry.key->is<Luau::AstExprConstantString>()) continue;
            auto Name=Text(Entry.key); auto Item=Property(Target.Class,Name);
            if (!Item) Error(Entry.key->location,"E_NATIVE_PROPERTY","Unapproved property "+Target.Class+"."+Name);
            else if (Item->ReadOnly) Error(Entry.key->location,"E_NATIVE_READONLY","Observation property cannot be configured: "+Name);
            else CheckValue(*Item,Entry.value);
        }
    }
    void Members(const Handle& Target, const std::string& Filter) {
        if (Target.Scope) for (const auto& Item:GLNative::ScopeOperations) Suggest(Item.Name,Filter,1,Item.Signature);
        if (Target.Resource) return; // resources have opaque handles, not direct fields
        for (const auto& Item:GLNative::Properties) if (IsA(Target.Class,Item.Class)) Suggest(Item.Name,Filter,4,Item.ResourceClass?Item.ResourceClass:"Approved native property");
        for (const char* Name:{"Name","Parent","ClassName","Destroy","IsA","FindFirstChild","GetChildren","GetDescendants"})
            Suggest(Name,Filter,Operation(Name)?1:4,"Native ObjectID-backed handle");
    }
public:
    godot::Array Diagnostics, Options;
    godot::String CallHint;
    bool Handled=false;
    explicit Visitor(const godot::String& SourcePath,Luau::Position Cursor):Path(SourcePath),CursorPosition(Cursor) {}
    bool visit(Luau::AstNode*) override { return Continue(); }
    bool visit(Luau::AstStatLocal* Statement) override {
        for (size_t Index=0;Index<Statement->vars.size;++Index) {
            Handle Type=Index<Statement->values.size?Infer(Statement->values.data[Index]):Handle{};
            if (Type.Class.empty()) Type=Annotation(Statement->vars.data[Index]->annotation);
            Locals[Statement->vars.data[Index]]=Type;
        }
        return Continue();
    }
    bool visit(Luau::AstExprFunction* Function) override {
        for (auto Argument:Function->args) Locals[Argument]=Annotation(Argument->annotation);
        return Continue();
    }
    bool visit(Luau::AstStatAssign* Statement) override {
        for (size_t Index=0;Index<Statement->vars.size;++Index) {
            auto Target=Statement->vars.data[Index];
            if (auto Local=Target->as<Luau::AstExprLocal>()) Locals[Local->local]=Index<Statement->values.size?Infer(Statement->values.data[Index]):Handle{};
            if (auto Field=Target->as<Luau::AstExprIndexName>()) {
                Handle Type=Infer(Field->expr); if (Type.Class.empty()) continue;
                auto Item=Property(Type.Class,Field->index.value);
                if (Type.Resource) Error(Field->indexLocation,"E_NATIVE_RESOURCE","Use Scope:Get/Configure for opaque resource handles");
                else if (!Item) Error(Field->indexLocation,"E_NATIVE_PROPERTY","Unapproved native property "+std::string(Field->index.value));
                else if (Item->ReadOnly) Error(Field->indexLocation,"E_NATIVE_READONLY","Observation property cannot be assigned");
                else if (Index<Statement->values.size) CheckValue(*Item,Statement->values.data[Index]);
            }
        }
        return Continue();
    }
    bool visit(Luau::AstExprIndexName* Expression) override {
        std::string Name=Expression->index.value, Filter;
        if(Cursor(Name,Filter)) {
            auto Parent=StaticPath(Expression->expr);
            if(Parent=="Scene.Enums") {Handled=true;for(const auto& Item:GLNative::Constants)Suggest(Item.Class,Filter,0,"Approved native enum family");}
            else if(Parent.find("Scene.Enums.")==0) {
                Handled=true;
                for(const auto& Item:GLNative::Constants) {
                    auto Family=std::string("Scene.Enums.")+Item.Class;
                    if(Parent==Family)Suggest(Item.Enum,Filter,0,"Approved native enum");
                    else if(Parent==Family+"."+Item.Enum)Suggest(Item.Name,Filter,6,(std::string(Item.Name)+" = "+std::to_string(Item.Value)).c_str());
                }
            }
        }
        auto Type=Infer(Expression->expr);
        if (Cursor(Name,Filter) && !Type.Class.empty()) { Handled=true; Members(Type,Filter); }
        else if (Cursor(Name,Filter)) {
            if (auto Global=Expression->expr->as<Luau::AstExprGlobal>()) if (std::string(Global->name.value)=="Scene")
                { Handled=true; for (const char* Item:{"new","Classes","Describe","Value","Enums","PolicySHA256","ApiSHA256"}) Suggest(Item,Filter,1,"Approved native Scene API"); }
        }
        else if (Type.Resource) Error(Expression->indexLocation,"E_NATIVE_RESOURCE","Use Scope:Get/Configure/Call for opaque resource handles");
        return Continue();
    }
    bool visit(Luau::AstExprCall* Expression) override {
        auto Function=Expression->func->as<Luau::AstExprIndexName>(); if (!Function) return Continue();
        if(StaticPath(Function)=="Scene.Value" && Expression->args.size) {
            std::string Filter;
            if(Cursor(Text(Expression->args.data[0]),Filter)) {
                Handled=true;
                for(int Type=GLNative::Vector2Value;Type<=GLNative::PathValue;++Type)
                    if(Type!=GLNative::VariantValue)if(auto Name=GLNativeValueName(GLNative::Kind(Type)))Suggest(Name,Filter,0,"Bounded pure native value; no object authority");
            }
        }
        auto Receiver=Infer(Function->expr); if (!Receiver.Scope) return Continue();
        std::string Name=Function->index.value;
        size_t Offset=Expression->self?0:1;
        if (Expression->args.size<=Offset) return Continue();
        auto First=Expression->args.data[Offset];
        if (Name=="New" || Name=="Load") {
            std::string Type=Text(First), Filter;
            if (Cursor(Type,Filter)) {
                Handled=true;
                if (Name=="New") for (const auto& Item:GLNative::Classes) if (Item.Construct) Suggest(Item.Name,Filter,0,"Approved native constructor");
                if (Name=="Load") for (const char* Item:GLNative::LoadTypes) Suggest(Item,Filter,0,"Immutable project resource");
                return Continue();
            }
            if (First->is<Luau::AstExprConstantString>()) {
                auto Info=Class(Type); bool Allowed=Info && Info->Construct;
                if (Name=="Load") { Allowed=false; for (const char* Item:GLNative::LoadTypes) if (Type==Item) Allowed=true; }
                if (!Allowed) Error(First->location,"E_NATIVE_CLASS","Unapproved native "+Name+" type "+Type);
                else if (Name=="New" && Expression->args.size>Offset+1) CheckProperties({Type,false,Info->Resource,true},Expression->args.data[Offset+1]);
            }
        } else if (Name=="Configure" && Expression->args.size>Offset+1) CheckProperties(Infer(First),Expression->args.data[Offset+1]);
        else if ((Name=="Call" || Name=="Connect" || Name=="Get") && Expression->args.size>Offset+1) {
            auto Target=Infer(First); if (Target.Class.empty()) return Continue();
            auto Argument=Expression->args.data[Offset+1]; std::string Member=Text(Argument), Filter;
            if (Cursor(Member,Filter)) {
                Handled=true;
                if (Name=="Call") for (const auto& Item:GLNative::Methods) if (IsA(Target.Class,Item.Class)) Suggest(Item.Name,Filter,1,Signature(Item).c_str());
                if (Name=="Connect") for (const auto& Item:GLNative::Signals) if (IsA(Target.Class,Item.Class)) Suggest(Item.Name,Filter,2,"Owner-scoped native signal");
                if (Name=="Get") for (const auto& Item:GLNative::Properties) if (IsA(Target.Class,Item.Class) && std::string(Item.Name)!="FullRect") Suggest(Item.Name,Filter,4,"Approved native getter");
            } else if (Argument->is<Luau::AstExprConstantString>()) {
                bool Allowed=false;
                if (Name=="Get") Allowed=Property(Target.Class,Member)!=nullptr && Member!="FullRect";
                if (Name=="Connect") for (const auto& Item:GLNative::Signals) if (Member==Item.Name && IsA(Target.Class,Item.Class)) Allowed=true;
                if (Name=="Call") if (auto Item=Method(Target.Class,Member)) {
                    if(Expression->location.containsClosed(CursorPosition)) {Handled=true;CallHint=godot::String::utf8(Signature(*Item).c_str());}
                    Allowed=true; size_t Count=Expression->args.size-Offset-2;
                    if (Count<size_t(Item->Required) || Count>size_t(Item->Arguments)) Error(Argument->location,"E_NATIVE_ARGUMENTS","Wrong argument count for "+Member);
                    if (Item->Mutates && Target.Resource && !Target.Mutable) Error(Argument->location,"E_NATIVE_IMMUTABLE","Loaded/getter resource cannot receive a mutating call");
                    for (size_t Index=0;Index<Count && Index<size_t(Item->Arguments);++Index)
                        CheckValue(GLNative::Arguments[Item->FirstArgument+Index],Expression->args.data[Offset+2+Index]);
                }
                if (!Allowed) Error(Argument->location,"E_NATIVE_MEMBER","Unapproved native "+Name+" member "+Target.Class+"."+Member);
            }
        }
        return Continue();
    }
};
inline godot::Dictionary Inspect(const godot::String& Source, const godot::String& Path) {
    godot::Dictionary Result;
    Result["Handled"]=false; Result["Diagnostics"]=godot::Array(); Result["Options"]=godot::Array();
    auto Utf8=Source.utf8();
    if (Utf8.length()>1024*1024) { Result["Skipped"]=true; return Result; }
    godot::String Code=Source;
    int Position=Code.find(godot::String::chr(0xFFFF));
    if (Position>=0) Code=Code.substr(0,Position)+"__GLNativeCursor__()"+Code.substr(Position+1);
    auto Bytes=Code.utf8();
    Luau::Allocator Allocator; Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Bytes.get_data(),Bytes.length(),Names,Allocator);
    Luau::Position Cursor(~0u,0);
    if(Position>=0) {
        Cursor=Luau::Position(0,0);auto Prefix=Source.substr(0,Position).utf8();
        for(int Index=0;Index<Prefix.length();++Index)if(Prefix[Index]=='\n'){++Cursor.line;Cursor.column=0;}else ++Cursor.column;
    }
    Visitor Analyzer(Path,Cursor); if (Parsed.root) Parsed.root->visit(&Analyzer);
    Result["Handled"]=Analyzer.Handled; Result["Diagnostics"]=Analyzer.Diagnostics; Result["Options"]=Analyzer.Options;
    Result["result"]=int(godot::OK); Result["options"]=Analyzer.Options; Result["force"]=true; Result["call_hint"]=Analyzer.CallHint;
    return Result;
}
}
#endif
