#include "gl_scene_authoring.h"
#include "gl_runtime.h"
#include "gl_asset.h"
#include "luau_value_bindings.h"
#include "luau_variant_bindings.h"
#include "gl_native_registry.gen.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/scene_state.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/box_shape3d.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/canvas_layer.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/color_rect.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/directional_light3d.hpp>
#include <godot_cpp/classes/environment.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/label3d.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/omni_light3d.hpp>
#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/primitive_mesh.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/shape3d.hpp>
#include <godot_cpp/classes/soft_body3d.hpp>
#include <godot_cpp/classes/sphere_mesh.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/spot_light3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/world_environment.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/callable_custom.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <array>
#include <unordered_set>

using namespace godot;
namespace {
using namespace GLNative;
constexpr size_t MaxNodes = 2048, MaxResources = 1024, MaxSubscriptions = 128, MaxScopes = 256;
std::vector<uint64_t> Scopes;
const char* CheckedString(lua_State* Thread, int Index, size_t Maximum=128) {
    luaL_checktype(Thread,Index,LUA_TSTRING);
    size_t Length=0; const char* Value=lua_tolstring(Thread,Index,&Length);
    if (!Length || Length>Maximum || std::memchr(Value,0,Length)) luaL_error(Thread,"[Scene:Type] Invalid bounded name/path");
    return Value;
}
template<class T> T* Resolve(uint64_t Id) { return Object::cast_to<T>(ObjectDB::get_instance(Id)); }
SceneScope* ScopeOf(Node* Target) {
    for (int Depth=0;Target && Depth<64;++Depth,Target=Target->get_parent())
        if (auto Scope=Object::cast_to<SceneScope>(Target)) return Scope;
    return nullptr;
}
void PushNode(lua_State* Thread, Node* Target) {
    if (!Target) { lua_pushnil(Thread); return; }
    GLPushNodeHandle(Thread,Target);
    luaL_getmetatable(Thread,"GodotObject"); lua_setmetatable(Thread,-2);
}
Node* NodeAt(lua_State* Thread, int Index) {
    if (!_gl_has_metatable(Thread,Index,"GodotObject")) luaL_error(Thread,"[Scene:Type] Expected live Node");
    Node* Target=gow_node(static_cast<GodotObjectWrapper*>(lua_touserdata(Thread,Index)));
    if (!Target || Target->is_queued_for_deletion()) luaL_error(Thread,"[Scene:Lifetime] Node was destroyed");
    return Target;
}
SceneScope* ScopeAt(lua_State* Thread) {
    auto Scope=Object::cast_to<SceneScope>(NodeAt(Thread,1));
    if (!Scope || !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Authority] Scope requires its live execution owner");
    return Scope;
}
using ResourceHandle=std::shared_ptr<GLSceneResource>;
ResourceHandle* HandleAt(lua_State* Thread, int Index) {
    return _gl_has_metatable(Thread,Index,"SceneResource") ? static_cast<ResourceHandle*>(lua_touserdata(Thread,Index)) : nullptr;
}
int ResourceEqual(lua_State* Thread) {
    auto Left=HandleAt(Thread,1), Right=HandleAt(Thread,2);
    bool Equal=false;
    if (Left && Right && *Left && *Right && (*Left)->Value.is_valid() && (*Right)->Value.is_valid()) {
        auto A=Resolve<SceneScope>((*Left)->Scope), B=Resolve<SceneScope>((*Right)->Scope);
        Equal=A && B && A->CanUse(Thread) && B->CanUse(Thread) && (*Left)->Value==(*Right)->Value;
    }
    lua_pushboolean(Thread,Equal); return 1;
}
void PushResource(lua_State* Thread, SceneScope* Scope, Ref<Resource> Value, bool ReadOnly=false) {
    if (Value.is_null()) { lua_pushnil(Thread); return; }
    Scope->Resources.erase(std::remove_if(Scope->Resources.begin(),Scope->Resources.end(),[](const auto& Entry){return Entry.expired();}),Scope->Resources.end());
    if (Scope->Resources.size()>=MaxResources) luaL_error(Thread,"[Scene:Limit] Resource handle limit");
    auto Slot=std::make_shared<GLSceneResource>();
    Slot->Value=Value; Slot->Scope=Scope->get_instance_id(); Slot->ReadOnly=ReadOnly;
    Scope->Resources.push_back(Slot);
    auto Handle=static_cast<ResourceHandle*>(lua_newuserdatadtor(Thread,sizeof(ResourceHandle),[](void* Data){static_cast<ResourceHandle*>(Data)->~shared_ptr();}));
    new (Handle) ResourceHandle(std::move(Slot));
    luaL_getmetatable(Thread,"SceneResource"); lua_setmetatable(Thread,-2);
}
Object* TargetAt(lua_State* Thread, SceneScope* Scope, int Index, bool Write) {
    if (auto Handle=HandleAt(Thread,Index)) {
        if (!*Handle || (*Handle)->Scope!=uint64_t(Scope->get_instance_id()) || (*Handle)->Value.is_null() || (Write && (*Handle)->ReadOnly))
            luaL_error(Thread,"[Scene:Authority] Resource is retired, foreign or immutable");
        return (*Handle)->Value.ptr();
    }
    Node* Target=NodeAt(Thread,Index);
    if (ScopeOf(Target)!=Scope) luaL_error(Thread,"[Scene:Authority] Target must belong to this scope");
    return Target;
}
const Property* FindProperty(Object* Target, const char* Key) {
    for (const auto& Item:Properties) if (!strcmp(Item.Name,Key) && Target->is_class(Item.Class)) return &Item;
    return nullptr;
}
bool Bounded(double Value, double Min, double Max) { return std::isfinite(Value) && Value>=Min && Value<=Max; }
Variant ReadValue(lua_State* Thread, SceneScope* Scope, const Property& Item, int Index) {
    if (Index<0) Index=lua_gettop(Thread)+1+Index;
    switch (Item.Type) {
        case Number: case Integer: {
            if (lua_type(Thread,Index)!=LUA_TNUMBER) break;
            double Value=lua_tonumber(Thread,Index);
            if (!Bounded(Value,Item.Min,Item.Max) || (Item.Type==Integer && Value!=std::floor(Value))) break;
            return Item.Type==Integer?Variant(int64_t(Value)):Variant(Value);
        }
        case Boolean: if (lua_isboolean(Thread,Index)) return bool(lua_toboolean(Thread,Index)); break;
        case Text: if (lua_type(Thread,Index)==LUA_TSTRING) {
            size_t Bytes=0; const char* Raw=lua_tolstring(Thread,Index,&Bytes);
            if (Bytes<Item.Min || Bytes>Item.Max || std::memchr(Raw,0,Bytes)) break;
            String Value=String::utf8(Raw,int64_t(Bytes));
            if (!strcmp(Item.Name,"Name") && (Value.contains("/") || Value.contains(":") || Value.contains(".") || Value.contains("@"))) break;
            return Value;
        } break;
        case GLNative::Vector: if (auto Value=check_vector3(Thread,Index)) {
            if (Bounded(Value->x,Item.Min,Item.Max) && Bounded(Value->y,Item.Min,Item.Max) && Bounded(Value->z,Item.Min,Item.Max)) return Vector3(Value->x,Value->y,Value->z);
        } break;
        case Vector2Value: if (lua_istable(Thread,Index)) {
            lua_rawgetfield(Thread,Index,"X"); lua_rawgetfield(Thread,Index,"Y");
            bool Valid=lua_type(Thread,-2)==LUA_TNUMBER && lua_type(Thread,-1)==LUA_TNUMBER;
            double X=lua_tonumber(Thread,-2); double Y=lua_tonumber(Thread,-1); lua_pop(Thread,2);
            if (Valid && Bounded(X,Item.Min,Item.Max) && Bounded(Y,Item.Min,Item.Max)) return Vector2(X,Y);
        } break;
        case Colour: if (auto Value=check_color3(Thread,Index)) {
            if (Bounded(Value->r,0,1) && Bounded(Value->g,0,1) && Bounded(Value->b,0,1)) return Color(Value->r,Value->g,Value->b);
        } break;
        case Void: break;
        case ResourceValue:
            if (lua_isnil(Thread,Index)) return Variant();
            if (auto Handle=HandleAt(Thread,Index)) if (*Handle && (*Handle)->Scope==uint64_t(Scope->get_instance_id()) && (*Handle)->Value.is_valid() && (*Handle)->Value->is_class(Item.ResourceClass))
                return (*Handle)->Value;
            break;
    }
    luaL_error(Thread,"[Scene:Type] Invalid %s.%s (kind %d; bounds %g..%g)",Item.Class,Item.Name,int(Item.Type),Item.Min,Item.Max);
    return Variant();
}
struct Assignment { const Property* Item; Variant Value; };
std::vector<Assignment> Validate(lua_State* Thread, SceneScope* Scope, Object* Target, int Index) {
    luaL_checktype(Thread,Index,LUA_TTABLE);
    std::vector<Assignment> Batch;
    lua_pushnil(Thread);
    while (lua_next(Thread,Index)) {
        if (Batch.size()>=32 || lua_type(Thread,-2)!=LUA_TSTRING) luaL_error(Thread,"[Scene:Type] At most 32 named properties required");
        const char* Key=CheckedString(Thread,-2);
        const Property* Item=FindProperty(Target,Key);
        if (!Item) luaL_error(Thread,"[Scene:Property] Unsupported property %s",Key);
        Batch.push_back({Item,ReadValue(Thread,Scope,*Item,-1)}); lua_pop(Thread,1);
    }
    return Batch;
}
void Apply(Object* Target, const std::vector<Assignment>& Batch) {
    const uint64_t Id=Target->get_instance_id();
    Ref<Resource> KeepAlive=Object::cast_to<Resource>(Target);
    for (const auto& Entry:Batch) {
        Target=ObjectDB::get_instance(Id);
        if (!Target) return; // native notifications may synchronously destroy a Node
        const char* Key=Entry.Item->Native;
        if (!strcmp(Key,"@font")) Object::cast_to<Control>(Target)->add_theme_font_override("font",Ref<Font>(Entry.Value));
        else if (!strcmp(Key,"@font_size")) Object::cast_to<Control>(Target)->add_theme_font_size_override("font_size",int(int64_t(Entry.Value)));
        else if (!strcmp(Key,"@separation")) Object::cast_to<Control>(Target)->add_theme_constant_override("separation",int(int64_t(Entry.Value)));
        else if (!strcmp(Key,"@full_rect")) {
            if (bool(Entry.Value)) Object::cast_to<Control>(Target)->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
            else Object::cast_to<Control>(Target)->set_anchors_preset(Control::PRESET_TOP_LEFT);
        } else Target->set(Key,Entry.Value);
    }
}
const GLNative::Class* FindClass(const char* Name) {
    for (const auto& Item:GLNative::Classes) if (!strcmp(Item.Name,Name)) return &Item;
    return nullptr;
}
bool RegistryIsA(const char* Name, const char* Base);
Node* CreateNode(const char* Name) {
    const auto* Item=FindClass(Name);
    if (!Item || !Item->Construct || Item->Resource || !ClassDB::can_instantiate(Name)) return nullptr;
    Variant Created=ClassDB::instantiate(StringName(Name));
    Object* Value=Created;
    auto Target=Object::cast_to<Node>(Value);
    if (!Target) { if (Value && !Object::cast_to<RefCounted>(Value)) memdelete(Value); return nullptr; }
    if (auto Edit=Object::cast_to<LineEdit>(Target)) Edit->set_max_length(8192);
    return Target;
}
Ref<Resource> CreateResource(const char* Name) {
    const auto* Item=FindClass(Name);
    if (!Item || !Item->Construct || !Item->Resource || !ClassDB::can_instantiate(Name)) return Ref<Resource>();
    // ClassDB returns a Variant owning the initial RefCounted reference. Keep it
    // alive until the scoped Ref has acquired ownership; never borrow a pointer
    // from a temporary Variant whose destruction could release the resource.
    Variant Created=ClassDB::instantiate(StringName(Name));
    Object* Value=Created;
    auto Target=Object::cast_to<Resource>(Value);
    if (!Target) { if (Value && !Object::cast_to<RefCounted>(Value)) memdelete(Value); return Ref<Resource>(); }
    return Ref<Resource>(Target);
}
void PushProperty(lua_State* Thread, SceneScope* Scope, Object* Target, const char* Key) {
    const Property* Item=FindProperty(Target,Key);
    if (!Item) luaL_error(Thread,"[Scene:Property] Unsupported property %s",Key);
    Variant Value;
    if (!strcmp(Item->Native,"@font")) Value=Object::cast_to<Control>(Target)->get_theme_font("font");
    else if (!strcmp(Item->Native,"@font_size")) Value=Object::cast_to<Control>(Target)->get_theme_font_size("font_size");
    else if (!strcmp(Item->Native,"@separation")) Value=Object::cast_to<Control>(Target)->get_theme_constant("separation");
    else if (!strcmp(Item->Native,"@full_rect")) luaL_error(Thread,"[Scene:Property] FullRect is a write-only preset");
    else Value=Target->get(Item->Native);
    if (Item->Type==Text) { String Text=Value; lua_pushstring(Thread,Text.utf8().get_data()); return; }
    if (Item->Type==ResourceValue) { PushResource(Thread,Scope,Ref<Resource>(Value),true); return; }
    if (Value.get_type()==Variant::VECTOR2) {
        Vector2 Point=Value; lua_newtable(Thread); lua_pushnumber(Thread,Point.x); lua_setfield(Thread,-2,"X"); lua_pushnumber(Thread,Point.y); lua_setfield(Thread,-2,"Y"); return;
    }
    if (!gl_variant_to_luau(Thread,Value)) lua_pushnil(Thread);
}
int New(lua_State* Thread) {
    SceneScope* Scope=ScopeAt(Thread);
    const char* Class=CheckedString(Thread,2);
    luaL_checktype(Thread,3,LUA_TTABLE);
    Scope->Nodes.erase(std::remove_if(Scope->Nodes.begin(),Scope->Nodes.end(),[](uint64_t Id){return Resolve<Node>(Id)==nullptr;}),Scope->Nodes.end());
    if (Scope->Nodes.size()>=MaxNodes) luaL_error(Thread,"[Scene:Limit] Node limit");
    Node* Parent=lua_isnoneornil(Thread,4)?Scope:NodeAt(Thread,4);
    if (ScopeOf(Parent)!=Scope) luaL_error(Thread,"[Scene:Authority] Parent must belong to this scope");
    int Depth=0; for (Node* Item=Parent;Item && Item!=Scope;Item=Item->get_parent()) ++Depth;
    if (Depth>=32) luaL_error(Thread,"[Scene:Limit] Hierarchy depth limit");
    if (Ref<Resource> Resource=CreateResource(Class); Resource.is_valid()) {
        auto Batch=Validate(Thread,Scope,Resource.ptr(),3); Apply(Resource.ptr(),Batch); PushResource(Thread,Scope,Resource); return 1;
    }
    auto Delete=[](Node* Target){if(Target) memdelete(Target);};
    std::unique_ptr<Node,decltype(Delete)> Target(CreateNode(Class),Delete);
    if (!Target) luaL_error(Thread,"[Scene:Type] Unsupported class %s",Class);
    auto Batch=Validate(Thread,Scope,Target.get(),3); Apply(Target.get(),Batch);
    uint64_t Id=Target->get_instance_id(); uint64_t ScopeId=Scope->get_instance_id();
    Scope->Nodes.push_back(Id);
    Node* Added=Target.release(); Parent->add_child(Added);
    Scope=Resolve<SceneScope>(ScopeId);
    Added=Resolve<Node>(Id);
    if (!Scope || !Scope->CanUse(Thread) || !Added || Added->is_queued_for_deletion()) luaL_error(Thread,"[Scene:Lifetime] Construction was retired by a callback");
    PushNode(Thread,Added); return 1;
}
int Configure(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); Object* Target=TargetAt(Thread,Scope,2,true);
    auto Batch=Validate(Thread,Scope,Target,3); Apply(Target,Batch); return 0;
}
int Get(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); Object* Target=TargetAt(Thread,Scope,2,false);
    const char* Key=CheckedString(Thread,3); PushProperty(Thread,Scope,Target,Key); return 1;
}
const GLNative::Method* FindMethod(Object* Target, const char* Name) {
    for (const auto& Item:GLNative::Methods) if (!strcmp(Item.Name,Name) && Target->is_class(Item.Class)) return &Item;
    return nullptr;
}
const GLNative::Signal* FindSignal(Node* Target, const char* Name) {
    for (const auto& Item:GLNative::Signals) if (!strcmp(Item.Name,Name) && Target->is_class(Item.Class)) return &Item;
    return nullptr;
}
bool ValidNative(const Property& Item, const Variant& Value) {
    switch (Item.Type) {
        case Void: return Value.get_type()==Variant::NIL;
        case Number: case Integer:
            return (Value.get_type()==Variant::FLOAT || Value.get_type()==Variant::INT) &&
                Bounded(double(Value),Item.Min,Item.Max) && (Item.Type!=Integer || double(Value)==std::floor(double(Value)));
        case Boolean: return Value.get_type()==Variant::BOOL;
        case Text: {
            if (Value.get_type()!=Variant::STRING && Value.get_type()!=Variant::STRING_NAME) return false;
            String Text=Value; auto Bytes=Text.utf8();
            return Bytes.length()>=Item.Min && Bytes.length()<=Item.Max && !std::memchr(Bytes.get_data(),0,Bytes.length());
        }
        case GLNative::Vector: {
            if (Value.get_type()!=Variant::VECTOR3) return false;
            Vector3 Point=Value; return Bounded(Point.x,Item.Min,Item.Max) && Bounded(Point.y,Item.Min,Item.Max) && Bounded(Point.z,Item.Min,Item.Max);
        }
        case Vector2Value: {
            if (Value.get_type()!=Variant::VECTOR2) return false;
            Vector2 Point=Value; return Bounded(Point.x,Item.Min,Item.Max) && Bounded(Point.y,Item.Min,Item.Max);
        }
        case Colour: {
            if (Value.get_type()!=Variant::COLOR) return false;
            Color ValueColor=Value; return Bounded(ValueColor.r,0,1) && Bounded(ValueColor.g,0,1) && Bounded(ValueColor.b,0,1) && Bounded(ValueColor.a,0,1);
        }
        case ResourceValue: {
            if (Value.get_type()==Variant::NIL) return true;
            if (Value.get_type()!=Variant::OBJECT) return false;
            Ref<Resource> ResourceValue=Value;
            return ResourceValue.is_null() || ResourceValue->is_class(Item.ResourceClass);
        }
    }
    return false;
}
void PushValue(lua_State* Thread, SceneScope* Scope, const Variant& Value, Kind Type) {
    if (Type==ResourceValue) { PushResource(Thread,Scope,Ref<Resource>(Value),true); return; }
    if (Type==Text) { String Text=Value; lua_pushstring(Thread,Text.utf8().get_data()); return; }
    if (Type==Vector2Value) {
        Vector2 Point=Value; lua_newtable(Thread); lua_pushnumber(Thread,Point.x); lua_setfield(Thread,-2,"X"); lua_pushnumber(Thread,Point.y); lua_setfield(Thread,-2,"Y"); return;
    }
    if (!gl_variant_to_luau(Thread,Value)) luaL_error(Thread,"[Scene:Type] Unsupported native result");
}
int Call(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); Object* Target=TargetAt(Thread,Scope,2,false);
    const char* Name=CheckedString(Thread,3);
    const auto* Item=FindMethod(Target,Name);
    if (!Item || !Target->has_method(Item->Native)) luaL_error(Thread,"[Scene:Method] Method %s is not admitted on this target",Name);
    if (Item->Mutates) TargetAt(Thread,Scope,2,true);
    int Count=lua_gettop(Thread)-3;
    if (Count<Item->Required || Count>Item->Arguments) luaL_error(Thread,"[Scene:Arguments] %s requires %d..%d arguments",Name,Item->Required,Item->Arguments);
    std::array<Variant,4> Values; std::array<const Variant*,4> Pointers;
    for (int Index=0;Index<Item->Arguments;++Index) {
        const auto& Argument=GLNative::Arguments[Item->FirstArgument+Index];
        if (Index<Count) Values[Index]=ReadValue(Thread,Scope,Argument,4+Index);
        else {
            if (!Argument.Default) luaL_error(Thread,"[Scene:Arguments] Missing required %s",Argument.Name);
            if (Argument.Type==Boolean) Values[Index]=!strcmp(Argument.Default,"true");
            else if (Argument.Type==Integer) Values[Index]=String(Argument.Default).to_int();
            else Values[Index]=String(Argument.Default).to_float();
        }
        Pointers[Index]=&Values[Index];
    }
    uint64_t ScopeId=Scope->get_instance_id();
    Ref<Resource> KeepAlive=Object::cast_to<Resource>(Target);
    Variant Receiver=Target, Result; GDExtensionCallError Error{};
    Receiver.callp(Item->Native,Pointers.data(),Item->Arguments,Result,Error);
    if (Error.error!=GDEXTENSION_CALL_OK) luaL_error(Thread,"[Scene:Invocation] %s rejected (code %d, argument %d)",Name,int(Error.error),Error.argument);
    Scope=Resolve<SceneScope>(ScopeId);
    if (!Scope || !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Lifetime] Owner retired during %s",Name);
    if (Item->Return==Void) return 0;
    Property Expected{"",Name,Item->Native,Item->Return,-1e12,1e12,Item->ReturnClass};
    if (Item->Return==Text) { Expected.Min=0; Expected.Max=8192; }
    if (!ValidNative(Expected,Result)) luaL_error(Thread,"[Scene:Type] %s returned an unsupported or nonfinite value",Name);
    PushValue(Thread,Scope,Result,Item->Return); return 1;
}
int BuildMesh(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Primitive=Object::cast_to<PrimitiveMesh>(TargetAt(Thread,Scope,2,false));
    if (!Primitive) luaL_error(Thread,"[Scene:Type] Mesh requires a primitive resource");
    Array Arrays=Primitive->get_mesh_arrays();
    PackedVector3Array Vertices=Arrays[godot::Mesh::ARRAY_VERTEX];
    if (Vertices.size()>8192) luaL_error(Thread,"[Scene:Limit] Primitive vertex limit");
    Ref<ArrayMesh> Result; Result.instantiate(); Result->add_surface_from_arrays(godot::Mesh::PRIMITIVE_TRIANGLES,Arrays);
    PushResource(Thread,Scope,Result,true); return 1;
}
int Pin(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Body=Object::cast_to<SoftBody3D>(TargetAt(Thread,Scope,2,true));
    double Index=luaL_checknumber(Thread,3); luaL_checktype(Thread,4,LUA_TBOOLEAN);
    Ref<ArrayMesh> Geometry;
    if (Body) Geometry=Body->get_mesh();
    if (!Body || !Body->is_inside_tree() || Geometry.is_null() || Geometry->get_surface_count()!=1 || !Bounded(Index,0,8191) || Index!=std::floor(Index) || Index>=Geometry->surface_get_array_len(0))
        luaL_error(Thread,"[Scene:Type] Pin requires an active soft body and valid vertex");
    Body->set_point_pinned(int(Index),lua_toboolean(Thread,4)!=0); return 0;
}
int Tone(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); double Frequency=luaL_checknumber(Thread,2); double Seconds=luaL_checknumber(Thread,3);
    if (!Bounded(Frequency,20,20000) || !Bounded(Seconds,0.001,1)) luaL_error(Thread,"[Scene:Limit] Tone bounds exceeded");
    constexpr int Rate=22050; int Count=int(Seconds*Rate); PackedByteArray Samples; Samples.resize(Count*2);
    for (int Index=0;Index<Count;++Index) {
        int16_t Sample=int16_t(std::sin(6.283185307179586*Frequency*Index/Rate)*(1.0-double(Index)/Count)*16000);
        Samples.set(Index*2,uint8_t(Sample)); Samples.set(Index*2+1,uint8_t(uint16_t(Sample)>>8));
    }
    Ref<AudioStreamWAV> Audio; Audio.instantiate(); Audio->set_format(AudioStreamWAV::FORMAT_16_BITS); Audio->set_mix_rate(Rate); Audio->set_data(Samples);
    PushResource(Thread,Scope,Audio,true); return 1;
}
int Load(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); const char* Type=CheckedString(Thread,2);
    bool Allowed=false; for (const char* Candidate:GLNative::LoadTypes) if (!strcmp(Candidate,Type)) Allowed=true;
    if (!Allowed) luaL_error(Thread,"[Scene:Type] Unsupported load type %s",Type);
    String Path=CheckedString(Thread,3,4096);
    if (!GLProjectResourcePath(Path)) luaL_error(Thread,"[Scene:Resource] Project resource path denied");
    Ref<FileAccess> File=FileAccess::open(Path,FileAccess::READ);
    if (File.is_null() || File->get_length()>16*1024*1024) luaL_error(Thread,"[Scene:Resource] Resource unavailable or encoded input exceeds 16 MiB");
    File.unref();
    Ref<Resource> Value=ResourceLoader::get_singleton()->load(Path,Type);
    if (Value.is_null() || !Value->is_class(Type)) luaL_error(Thread,"[Scene:Resource] Resource type or load failed");
    PushResource(Thread,Scope,Value,true); return 1;
}
int ParentDepth(lua_State* Thread, SceneScope* Scope, Node* Parent) {
    if (ScopeOf(Parent)!=Scope || Parent->is_queued_for_deletion()) luaL_error(Thread,"[Scene:Authority] Parent must belong to this live scope");
    int Depth=0; for (Node* Item=Parent;Item && Item!=Scope;Item=Item->get_parent()) ++Depth;
    if (Depth>=32) luaL_error(Thread,"[Scene:Limit] Hierarchy depth limit");
    return Depth;
}
void ReapNodes(SceneScope* Scope) {
    Scope->Nodes.erase(std::remove_if(Scope->Nodes.begin(),Scope->Nodes.end(),[](uint64_t Id){return Resolve<Node>(Id)==nullptr;}),Scope->Nodes.end());
}
const Property* NativeProperty(const char* Class, const String& Name) {
    // Serialized theme overrides use Godot's native storage spelling.
    String Alias=Name;
    if (Name=="theme_override_fonts/font") Alias="@font";
    if (Name=="theme_override_font_sizes/font_size") Alias="@font_size";
    if (Name=="theme_override_constants/separation") Alias="@separation";
    for (const auto& Item:GLNative::Properties)
        if (RegistryIsA(Class,Item.Class) && Alias==Item.Native) return &Item;
    return nullptr;
}
bool ResourceGraph(const Variant& Value, std::unordered_set<uint64_t>& Seen, int& Values, int Depth=0) {
    if (++Values>16384 || Depth>16) return false;
    if (Value.get_type()==Variant::OBJECT) {
        Object* ObjectValue=Value;
        if (!ObjectValue) return true;
        auto ResourceValue=Object::cast_to<Resource>(ObjectValue);
        if (!ResourceValue || ResourceValue->get_script().get_type()!=Variant::NIL) return false;
        if (!Seen.insert(ResourceValue->get_instance_id()).second) return true;
        if (Seen.size()>MaxResources) return false;
        auto List=ResourceValue->get_property_list();
        for (int Index=0;Index<List.size();++Index) {
            Dictionary Info=List[Index];
            if ((int64_t(Info["usage"])&PROPERTY_USAGE_STORAGE)==0) continue;
            StringName Name=Info["name"];
            if (!ResourceGraph(ResourceValue->get(Name),Seen,Values,Depth+1)) return false;
        }
    } else if (Value.get_type()==Variant::ARRAY) {
        Array Items=Value;
        if (Items.size()>16384) return false;
        for (int Index=0;Index<Items.size();++Index) if (!ResourceGraph(Items[Index],Seen,Values,Depth+1)) return false;
    } else if (Value.get_type()==Variant::DICTIONARY) {
        Dictionary Items=Value; if (Items.size()>16384) return false;
        Array Keys=Items.keys();
        for (int Index=0;Index<Keys.size();++Index)
            if (!ResourceGraph(Keys[Index],Seen,Values,Depth+1) || !ResourceGraph(Items[Keys[Index]],Seen,Values,Depth+1)) return false;
    }
    return true;
}
void CheckScene(lua_State* Thread, SceneScope* Scope, const Ref<PackedScene>& Scene, int Depth) {
    Ref<SceneState> State=Scene->get_state();
    if (State.is_null() || !Scene->can_instantiate() || State->get_connection_count()!=0)
        luaL_error(Thread,"[Scene:Composition] Scene must be instantiable with no stored signal connections");
    ReapNodes(Scope);
    if (State->get_node_count()<=0 || size_t(State->get_node_count())>MaxNodes-Scope->Nodes.size())
        luaL_error(Thread,"[Scene:Limit] Scene node budget exceeded");
    std::unordered_set<uint64_t> Resources; int Values=0;
    for (int Index=0;Index<State->get_node_count();++Index) {
        String Type=State->get_node_type(Index); const auto* Class=FindClass(Type.utf8().get_data());
        if (!Class || !Class->Construct || Class->Resource || State->get_node_instance(Index).is_valid() || !State->get_node_groups(Index).is_empty())
            luaL_error(Thread,"[Scene:Composition] Unapproved class, nested/inherited instance or group");
        String Name=State->get_node_name(Index); auto Bytes=Name.utf8();
        if (Bytes.length()==0 || Bytes.length()>128 || Name.contains("/") || Name.contains(":") || Name.contains(".") || Name.contains("@"))
            luaL_error(Thread,"[Scene:Composition] Invalid bounded scene node name");
        NodePath Path=State->get_node_path(Index);
        int LocalDepth=String(Path)=="."?0:Path.get_name_count();
        if (Depth+1+LocalDepth>32) luaL_error(Thread,"[Scene:Limit] Scene hierarchy depth exceeded");
        for (int PropertyIndex=0;PropertyIndex<State->get_node_property_count(Index);++PropertyIndex) {
            String Name=State->get_node_property_name(Index,PropertyIndex);
            const Property* Item=NativeProperty(Class->Name,Name);
            Variant Value=State->get_node_property_value(Index,PropertyIndex);
            if (!Item || !ValidNative(*Item,Value) || !ResourceGraph(Value,Resources,Values))
                luaL_error(Thread,"[Scene:Composition] Property %s.%s is not admitted",Class->Name,Name.utf8().get_data());
        }
    }
}
std::vector<uint64_t> CheckSubtree(lua_State* Thread, SceneScope* Scope, Node* Root, int Depth, bool Owned) {
    std::vector<std::pair<uint64_t,int>> Work{{uint64_t(Root->get_instance_id()),Depth+1}};
    std::vector<uint64_t> Result;
    for (size_t Index=0;Index<Work.size();++Index) {
        Node* Item=Resolve<Node>(Work[Index].first);
        if (!Item || Item==Scope || Item->is_queued_for_deletion() || Item->get_script().get_type()!=Variant::NIL)
            luaL_error(Thread,"[Scene:Composition] Invalid or scripted subtree");
        const auto* Class=FindClass(Item->get_class().utf8().get_data());
        if (!Class || !Class->Construct || Class->Resource || Work[Index].second>32)
            luaL_error(Thread,"[Scene:Composition] Unapproved class or subtree depth");
        if (Owned && (ScopeOf(Item)!=Scope || std::find(Scope->Nodes.begin(),Scope->Nodes.end(),Work[Index].first)==Scope->Nodes.end()))
            luaL_error(Thread,"[Scene:Authority] Subtree contains an unadopted native node");
        if (Result.size()>=MaxNodes) luaL_error(Thread,"[Scene:Limit] Subtree node budget exceeded");
        Result.push_back(Work[Index].first);
        for (int Child=0;Child<Item->get_child_count();++Child) {
            if (Work.size()>=MaxNodes) luaL_error(Thread,"[Scene:Limit] Subtree node budget exceeded");
            Work.push_back({uint64_t(Item->get_child(Child)->get_instance_id()),Work[Index].second+1});
        }
    }
    return Result;
}
int Attach(lua_State* Thread, SceneScope* Scope, Node* Parent, std::unique_ptr<Node,void(*)(Node*)> Root, int Depth) {
    auto Ids=CheckSubtree(Thread,Scope,Root.get(),Depth,false);
    ReapNodes(Scope);
    if (Ids.size()>MaxNodes-Scope->Nodes.size()) luaL_error(Thread,"[Scene:Limit] Composition node budget exceeded");
    Scope->Nodes.insert(Scope->Nodes.end(),Ids.begin(),Ids.end());
    uint64_t ScopeId=Scope->get_instance_id(), RootId=Root->get_instance_id();
    Parent->add_child(Root.release());
    Scope=Resolve<SceneScope>(ScopeId); Node* Added=Resolve<Node>(RootId);
    if (!Scope || !Scope->CanUse(Thread) || !Added || Added->is_queued_for_deletion()) luaL_error(Thread,"[Scene:Lifetime] Composition retired during tree entry");
    PushNode(Thread,Added); return 1;
}
int Instantiate(lua_State* Thread) {
    auto Scope=ScopeAt(Thread);
    auto Scene=Object::cast_to<PackedScene>(TargetAt(Thread,Scope,2,false));
    if (!Scene) luaL_error(Thread,"[Scene:Type] Instantiate requires a project PackedScene");
    Node* Parent=lua_isnoneornil(Thread,3)?Scope:NodeAt(Thread,3);
    int Depth=ParentDepth(Thread,Scope,Parent);
    Ref<PackedScene> KeepAlive=Scene;
    CheckScene(Thread,Scope,KeepAlive,Depth);
    std::unique_ptr<Node,void(*)(Node*)> Root(Scene->instantiate(),[](Node* Value){if(Value) memdelete(Value);});
    if (!Root) luaL_error(Thread,"[Scene:Composition] Native scene instantiation failed");
    return Attach(Thread,Scope,Parent,std::move(Root),Depth);
}
int Clone(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Source=Object::cast_to<Node>(TargetAt(Thread,Scope,2,false));
    if (!Source) luaL_error(Thread,"[Scene:Type] Clone requires an owned Node");
    Node* Parent=lua_isnoneornil(Thread,3)?Scope:NodeAt(Thread,3);
    int Depth=ParentDepth(Thread,Scope,Parent);
    auto Ids=CheckSubtree(Thread,Scope,Source,Depth,true);
    ReapNodes(Scope);
    if (Ids.size()>MaxNodes-Scope->Nodes.size()) luaL_error(Thread,"[Scene:Limit] Clone node budget exceeded");
    // No script, signal, group or packed-instantiation flags are copied.
    std::unique_ptr<Node,void(*)(Node*)> Root(Source->duplicate(0),[](Node* Value){if(Value) memdelete(Value);});
    if (!Root) luaL_error(Thread,"[Scene:Composition] Native duplicate failed");
    return Attach(Thread,Scope,Parent,std::move(Root),Depth);
}
int Reparent(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Source=Object::cast_to<Node>(TargetAt(Thread,Scope,2,true));
    Node* Parent=NodeAt(Thread,3);
    int Depth=ParentDepth(Thread,Scope,Parent);
    if (!Source || Source==Scope || Source==Parent || Source->is_ancestor_of(Parent)) luaL_error(Thread,"[Scene:Composition] Invalid or cyclic reparent");
    CheckSubtree(Thread,Scope,Source,Depth,true);
    if (!lua_isnoneornil(Thread,4)) luaL_checktype(Thread,4,LUA_TBOOLEAN);
    bool Keep=lua_isnoneornil(Thread,4) || lua_toboolean(Thread,4);
    uint64_t ScopeId=Scope->get_instance_id(), Id=Source->get_instance_id();
    Source->reparent(Parent,Keep);
    Scope=Resolve<SceneScope>(ScopeId); Source=Resolve<Node>(Id);
    if (!Scope || !Scope->CanUse(Thread) || !Source || Source->is_queued_for_deletion() || ScopeOf(Source)!=Scope)
        luaL_error(Thread,"[Scene:Lifetime] Reparent retired during native notification");
    return 0;
}
int Play(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Audio=Object::cast_to<AudioStreamPlayer>(TargetAt(Thread,Scope,2,true));
    if (!Audio || Audio->get_stream().is_null()) luaL_error(Thread,"[Scene:Type] Play requires an audio player with a stream");
    Audio->play(); return 0;
}
int Stop(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Audio=Object::cast_to<AudioStreamPlayer>(TargetAt(Thread,Scope,2,true));
    if (!Audio) luaL_error(Thread,"[Scene:Type] Stop requires an audio player");
    Audio->stop(); return 0;
}
int Impulse(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Body=Object::cast_to<RigidBody3D>(TargetAt(Thread,Scope,2,true));
    auto Value=check_vector3(Thread,3);
    if (!Body || !Value || !Bounded(Value->x,-100000,100000) || !Bounded(Value->y,-100000,100000) || !Bounded(Value->z,-100000,100000)) luaL_error(Thread,"[Scene:Type] Impulse requires a scoped body and finite bounded Vector3");
    Body->apply_central_impulse(Vector3(Value->x,Value->y,Value->z)); return 0;
}
int Destroy(lua_State* Thread) {
    Node* Target=NodeAt(Thread,1); auto Scope=ScopeOf(Target);
    if (!Scope || !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Authority] Destroy requires the live owner");
    if (Target==Scope) Scope->Retire(); else Target->queue_free(); return 0;
}
// Like GL-022's child relay, callback reference is part of base Callable identity.
// Godot deliberately strips bind() arguments when comparing signal slots.
class SceneCallable : public CallableCustom {
    uint64_t Receiver;
    int Reference;
    int Signature;
    static bool Equal(const CallableCustom* Left, const CallableCustom* Right) {
        auto A=static_cast<const SceneCallable*>(Left); auto B=static_cast<const SceneCallable*>(Right);
        return A->Receiver==B->Receiver && A->Reference==B->Reference;
    }
    static bool Less(const CallableCustom* Left, const CallableCustom* Right) {
        auto A=static_cast<const SceneCallable*>(Left); auto B=static_cast<const SceneCallable*>(Right);
        return A->Reference!=B->Reference?A->Reference<B->Reference:A->Receiver<B->Receiver;
    }
public:
    SceneCallable(uint64_t Id, int Ref, int Descriptor) : Receiver(Id),Reference(Ref),Signature(Descriptor) {}
    uint32_t hash() const override { return uint32_t(Reference); }
    String get_as_text() const override { return String("[Scene:Signal] ")+String::num_int64(Reference); }
    CompareEqualFunc get_compare_equal_func() const override { return Equal; }
    CompareLessFunc get_compare_less_func() const override { return Less; }
    ObjectID get_object() const override { return ObjectID(Receiver); }
    bool is_valid() const override {
        auto Scope=Resolve<SceneScope>(Receiver);
        return GLReferenceState(Reference) && Scope && !Scope->Retired && !Scope->is_queued_for_deletion();
    }
    int get_argument_count(bool& Valid) const override { Valid=true; return GLNative::Signals[Signature].Arguments; }
    void call(const Variant** Arguments, int Count, Variant& Result, GDExtensionCallError& Error) const override {
        Error.error=GDEXTENSION_CALL_OK; Result=Variant();
        const auto& Item=GLNative::Signals[Signature];
        if (Count!=Item.Arguments) {
            Error.error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; return;
        }
        std::vector<Variant> Values; Values.reserve(Count);
        for (int Index=0;Index<Count;++Index) {
            if (!ValidNative(GLNative::Arguments[Item.FirstArgument+Index],*Arguments[Index])) {
                Error.error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; Error.argument=Index; return;
            }
            Values.push_back(*Arguments[Index]);
        }
        auto Scope=Resolve<SceneScope>(Receiver); if (!Scope) return;
        Scope->OnSignal(Reference,Signature,Values);
    }
};
int Connect(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Source=Object::cast_to<Node>(TargetAt(Thread,Scope,2,false));
    const char* Signal=CheckedString(Thread,3); luaL_checktype(Thread,4,LUA_TFUNCTION);
    const auto* Item=FindSignal(Source,Signal);
    if (!Item || !Source->has_signal(Item->Native)) luaL_error(Thread,"[Scene:Signal] Unsupported source/signal %s",Signal);
    const char* Native=Item->Native;
    // Reap retired callback owners even when their scope remains live.
    for (size_t Index=Scope->Subscriptions.size();Index>0;--Index) {
        const auto& Item=Scope->Subscriptions[Index-1];
        auto Target=Resolve<Node>(Item.Source);
        if (!GLReferenceState(Item.Reference) || !Target || Target->is_queued_for_deletion()) Scope->Disconnect(Item.Reference);
    }
    if (Scope->Subscriptions.size()>=MaxSubscriptions) luaL_error(Thread,"[Scene:Limit] Subscription limit");
    int Reference=GLReference(Thread,4);
    Callable Handler(memnew(SceneCallable(Scope->get_instance_id(),Reference,int(Item-GLNative::Signals))));
    if (Source->connect(Native,Handler)!=OK) { GLUnreference(nullptr,Reference); luaL_error(Thread,"[Scene:Signal] Connection failed"); }
    Scope->Subscriptions.push_back({uint64_t(Source->get_instance_id()),Native,Handler,Reference});
    lua_newtable(Thread);
    GLPushNodeHandle(Thread,Scope); lua_pushinteger(Thread,Reference);
    lua_pushcclosure(Thread,[](lua_State* State)->int {
        auto Owner=Object::cast_to<SceneScope>(GLNodeUpvalue(State,1));
        if (Owner && Owner->CanUse(State)) Owner->Disconnect(lua_tointeger(State,lua_upvalueindex(2)));
        return 0;
    },"Disconnect",2); lua_setfield(Thread,-2,"Disconnect");
    lua_newtable(Thread); lua_pushinteger(Thread,Reference); GLPushNodeHandle(Thread,Source);
    lua_pushcclosure(Thread,[](lua_State* State)->int {
        const char* Key=luaL_checkstring(State,2);
        Node* Target=GLNodeUpvalue(State,2);
        if (!strcmp(Key,"Connected")) lua_pushboolean(State,Target && !Target->is_queued_for_deletion() && GLReferenceState(lua_tointeger(State,lua_upvalueindex(1)))!=nullptr);
        else lua_pushnil(State); return 1;
    },"ConnectionIndex",2); lua_setfield(Thread,-2,"__index"); lua_setmetatable(Thread,-2);
    return 1;
}
int Root(lua_State* Thread) {
    auto Owner=GLGetOwner(Thread); Node* Parent=NodeAt(Thread,1);
    Node* Script=Owner?Resolve<Node>(Owner->NativeId):nullptr;
    if (!Owner || !Owner->Alive || !Script || Script->get_parent()!=Parent)
        luaL_error(Thread,"[Scene:Authority] Scene.new requires the executing script's parent");
    for (Node* Item=Parent;Item;Item=Item->get_parent()) {
        String Type=Item->get_class();
        if (Type!="Node" && Type!="Node3D" && Type!="RobloxWorkspace" && Type!="Folder" && Type!="Window")
            luaL_error(Thread,"[Scene:Authority] Scene parent must be a plain bootstrap container");
    }
    if (Scopes.size()>=MaxScopes) luaL_error(Thread,"[Scene:Limit] Scope limit");
    lua_pushboolean(Thread,true); int Guard=GLReference(Thread,-1); lua_pop(Thread,1);
    auto Scope=memnew(SceneScope); Scope->Anchor=GLGetOwnerState(Thread); Scope->Guard=Guard;
    Scope->set_name("Scene"); uint64_t Id=Scope->get_instance_id(); Parent->add_child(Scope);
    Scope=Resolve<SceneScope>(Id);
    if (!Scope || !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Lifetime] Scope construction was retired");
    PushNode(Thread,Scope); return 1;
}
bool RegistryIsA(const char* Name, const char* Base) {
    for (int Depth=0;Name && *Name && Depth<64;++Depth) {
        if (!strcmp(Name,Base)) return true;
        const auto* Item=FindClass(Name); if (!Item) return false;
        Name=Item->Base;
    }
    return false;
}
const char* KindName(Kind Type) {
    static const char* Names[]={"number","integer","boolean","string","Vector3","Vector2","Color3","Resource","void"};
    return Names[int(Type)];
}
void PushShape(lua_State* Thread, const Property& Item) {
    lua_newtable(Thread);
    lua_pushstring(Thread,KindName(Item.Type)); lua_setfield(Thread,-2,"Type");
    lua_pushstring(Thread,Item.Name); lua_setfield(Thread,-2,"Name");
    lua_pushnumber(Thread,Item.Min); lua_setfield(Thread,-2,"Minimum");
    lua_pushnumber(Thread,Item.Max); lua_setfield(Thread,-2,"Maximum");
    if (Item.ResourceClass) { lua_pushstring(Thread,Item.ResourceClass); lua_setfield(Thread,-2,"ResourceClass"); }
}
int GetClasses(lua_State* Thread) {
    lua_newtable(Thread); int Index=1;
    for (const auto& Item:GLNative::Classes) { lua_pushstring(Thread,Item.Name); lua_rawseti(Thread,-2,Index++); }
    return 1;
}
int Describe(lua_State* Thread) {
    const char* Name=CheckedString(Thread,1); const auto* Class=FindClass(Name);
    if (!Class) { lua_pushnil(Thread); return 1; }
    lua_newtable(Thread);
    lua_pushstring(Thread,Class->Name); lua_setfield(Thread,-2,"Name");
    lua_pushstring(Thread,Class->Base); lua_setfield(Thread,-2,"Base");
    lua_pushboolean(Thread,Class->Construct && ClassDB::can_instantiate(Name)); lua_setfield(Thread,-2,"Constructible");
    lua_pushboolean(Thread,ClassDB::class_exists(Name)); lua_setfield(Thread,-2,"Available");
    lua_pushboolean(Thread,Class->Resource); lua_setfield(Thread,-2,"Resource");
    lua_newtable(Thread);
    for (const auto& Item:GLNative::Properties) if (RegistryIsA(Name,Item.Class)) {
        lua_getfield(Thread,-1,Item.Name); bool Present=!lua_isnil(Thread,-1); lua_pop(Thread,1);
        if (!Present) { PushShape(Thread,Item); lua_setfield(Thread,-2,Item.Name); }
    }
    lua_setfield(Thread,-2,"Properties");
    lua_newtable(Thread);
    for (const auto& Item:GLNative::Methods) if (RegistryIsA(Name,Item.Class)) {
        lua_newtable(Thread); lua_pushboolean(Thread,Item.Mutates); lua_setfield(Thread,-2,"Mutates");
        lua_pushinteger(Thread,Item.Required); lua_setfield(Thread,-2,"RequiredArguments");
        lua_pushstring(Thread,KindName(Item.Return)); lua_setfield(Thread,-2,"Returns");
        lua_newtable(Thread);
        for (int Index=0;Index<Item.Arguments;++Index) { PushShape(Thread,GLNative::Arguments[Item.FirstArgument+Index]); lua_rawseti(Thread,-2,Index+1); }
        lua_setfield(Thread,-2,"Arguments"); lua_setfield(Thread,-2,Item.Name);
    }
    lua_setfield(Thread,-2,"Methods");
    lua_newtable(Thread);
    for (const auto& Item:GLNative::Signals) if (RegistryIsA(Name,Item.Class)) {
        lua_newtable(Thread);
        for (int Index=0;Index<Item.Arguments;++Index) { PushShape(Thread,GLNative::Arguments[Item.FirstArgument+Index]); lua_rawseti(Thread,-2,Index+1); }
        lua_setfield(Thread,-2,Item.Name);
    }
    lua_setfield(Thread,-2,"Signals"); return 1;
}
void PushEnums(lua_State* Thread) {
    lua_newtable(Thread); int Root=lua_gettop(Thread);
    for (const auto& Item:GLNative::Constants) {
        lua_getfield(Thread,Root,Item.Class);
        if (lua_isnil(Thread,-1)) { lua_pop(Thread,1); lua_newtable(Thread); lua_pushvalue(Thread,-1); lua_setfield(Thread,Root,Item.Class); }
        int Class=lua_gettop(Thread); lua_getfield(Thread,Class,Item.Enum);
        if (lua_isnil(Thread,-1)) { lua_pop(Thread,1); lua_newtable(Thread); lua_pushvalue(Thread,-1); lua_setfield(Thread,Class,Item.Enum); }
        lua_pushinteger(Thread,Item.Value); lua_setfield(Thread,-2,Item.Name); lua_pop(Thread,2);
    }
    lua_pushnil(Thread);
    while (lua_next(Thread,Root)) {
        int Class=lua_gettop(Thread); lua_pushnil(Thread);
        while (lua_next(Thread,Class)) { lua_setreadonly(Thread,-1,true); lua_pop(Thread,1); }
        lua_setreadonly(Thread,Class,true); lua_pop(Thread,1);
    }
    lua_setreadonly(Thread,Root,true);
}
}

SceneScope::SceneScope() { Scopes.push_back(get_instance_id()); }
SceneScope::~SceneScope() {
    Retire(false); GLUnreference(nullptr,Guard);
    uint64_t Id=get_instance_id(); Scopes.erase(std::remove(Scopes.begin(),Scopes.end(),Id),Scopes.end());
}
void SceneScope::_bind_methods() {}
void SceneScope::_notification(int What) { if (What==NOTIFICATION_EXIT_TREE) Retire(false); }
bool SceneScope::CanUse(lua_State* Thread) const {
    return !Retired && !is_queued_for_deletion() && Guard && GLReferenceState(Guard) && GLGetOwnerState(Thread)==Anchor;
}
void SceneScope::Disconnect(int Reference) {
    for (size_t Index=0;Index<Subscriptions.size();++Index) if (Subscriptions[Index].Reference==Reference) {
        auto Item=Subscriptions[Index]; Subscriptions.erase(Subscriptions.begin()+Index);
        if (Node* Source=Resolve<Node>(Item.Source)) if (Source->is_connected(Item.Signal,Item.Handler)) Source->disconnect(Item.Signal,Item.Handler);
        GLUnreference(nullptr,Reference); return;
    }
}
void SceneScope::Retire(bool Delete) {
    if (!Retired) {
        Retired=true;
        while (!Subscriptions.empty()) Disconnect(Subscriptions.back().Reference);
        for (auto& Weak:Resources) if (auto Slot=Weak.lock()) Slot->Value.unref();
        Resources.clear();
    }
    if (Delete && !is_queued_for_deletion()) queue_free();
}
void SceneScope::OnSignal(int Reference, int Signature, const std::vector<Variant>& Values) {
    if (Retired || is_queued_for_deletion() || !GLReferenceState(Guard)) return;
    auto Entry=std::find_if(Subscriptions.begin(),Subscriptions.end(),[Reference](const auto& Item){return Item.Reference==Reference;});
    if (Entry==Subscriptions.end()) return;
    Node* Source=Resolve<Node>(Entry->Source);
    if (!Source || Source->is_queued_for_deletion()) return;
    uint64_t ScopeId=get_instance_id();
    GLDispatch(Reference,[ScopeId,Signature,Values](lua_State* Thread) {
        auto Scope=Resolve<SceneScope>(ScopeId);
        if (!Scope || !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Lifetime] Signal owner retired");
        const auto& Item=GLNative::Signals[Signature];
        for (int Index=0;Index<Item.Arguments;++Index)
            PushValue(Thread,Scope,Values[Index],GLNative::Arguments[Item.FirstArgument+Index].Type);
        return Item.Arguments;
    }); // callback may destroy this scope; never touch it after dispatch
}
void GLRegisterScene(lua_State* Thread) {
    luaL_newmetatable(Thread,"SceneResource");
    lua_pushliteral(Thread,"SceneResource"); lua_setfield(Thread,-2,"__type");
    lua_pushcfunction(Thread,ResourceEqual,"ResourceIdentity"); lua_setfield(Thread,-2,"__eq"); lua_pop(Thread,1);
    lua_newtable(Thread);
    lua_pushcfunction(Thread,Root,"new"); lua_setfield(Thread,-2,"new");
    lua_pushcfunction(Thread,GetClasses,"Classes"); lua_setfield(Thread,-2,"Classes");
    lua_pushcfunction(Thread,Describe,"Describe"); lua_setfield(Thread,-2,"Describe");
    lua_pushstring(Thread,GLNative::PolicySHA256); lua_setfield(Thread,-2,"PolicySHA256");
    lua_pushstring(Thread,GLNative::ApiSHA256); lua_setfield(Thread,-2,"ApiSHA256");
    PushEnums(Thread); lua_setfield(Thread,-2,"Enums");
    lua_setreadonly(Thread,-1,true); lua_setglobal(Thread,"Scene");
}
void GLRetireScenes(lua_State* Anchor) {
    auto Snapshot=Scopes;
    for (uint64_t Id:Snapshot) if (auto Scope=Resolve<SceneScope>(Id)) if (Scope->Anchor==Anchor) Scope->Retire();
}
bool GLSceneLocal(Node* Target) { return ScopeOf(Target)!=nullptr; }
bool GLSceneMutation(lua_State* Thread, Node* Target, bool Clone) {
    if (auto Scope=ScopeOf(Target)) if (Clone || !Scope->CanUse(Thread)) return false;
    for (uint64_t Id:Scopes) if (auto Scope=Resolve<SceneScope>(Id))
        if (Target && Target->is_ancestor_of(Scope) && (Clone || !Scope->CanUse(Thread))) return false;
    return true;
}
bool GLSceneIndex(lua_State* Thread, Node* Target, const char* Key) {
    auto Scope=ScopeOf(Target); if (!Scope) return false;
    Key=CheckedString(Thread,2);
    if (Scope->Retired || Scope->is_queued_for_deletion()) luaL_error(Thread,"[Scene:Lifetime] Scene was retired");
    if (Target==Scope) {
        struct Method { const char* Name; lua_CFunction Function; };
#define GL_SCENE_OPERATION(Name, Function) {#Name,Function},
        static const Method Methods[]={GL_NATIVE_SCOPE_OPERATIONS(GL_SCENE_OPERATION)};
#undef GL_SCENE_OPERATION
        for (const auto& Item:Methods) if (!strcmp(Key,Item.Name)) {
            if (!Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Authority] Scope methods require its live execution owner");
            lua_pushcfunction(Thread,Item.Function,Item.Name); return true;
        }
    }
    if (!strcmp(Key,"Destroy")) { lua_pushcfunction(Thread,Destroy,"Destroy"); return true; }
    if (!strcmp(Key,"Parent")) { PushNode(Thread,Target->get_parent()); return true; }
    if (!strcmp(Key,"ClassName")) { lua_pushstring(Thread,Target->get_class().utf8().get_data()); return true; }
    if (!strcmp(Key,"IsA") || !strcmp(Key,"FindFirstChild") || !strcmp(Key,"GetChildren") || !strcmp(Key,"GetDescendants")) return false;
    const Property* Item=FindProperty(Target,Key);
    if (Item && Item->Type==ResourceValue && !Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Authority] Resource access requires the live owner");
    if (!Item) for (int Index=0;Index<Target->get_child_count();++Index) {
        Node* Child=Target->get_child(Index);
        if (Child->get_name()==StringName(Key)) { PushNode(Thread,Child); return true; }
    }
    PushProperty(Thread,Scope,Target,Key); return true;
}
bool GLSceneWrite(lua_State* Thread, Node* Target, const char* Key) {
    auto Scope=ScopeOf(Target); if (!Scope) return false;
    Key=CheckedString(Thread,2);
    if (!Scope->CanUse(Thread)) luaL_error(Thread,"[Scene:Authority] Scene write requires its live execution owner");
    const Property* Item=FindProperty(Target,Key);
    if (!Item) luaL_error(Thread,"[Scene:Property] Unsupported property %s",Key);
    Variant Value=ReadValue(Thread,Scope,*Item,3); Apply(Target,{{Item,Value}}); return true;
}
