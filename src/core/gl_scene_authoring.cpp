#include "gl_scene_authoring.h"
#include "gl_runtime.h"
#include "gl_asset.h"
#include "luau_value_bindings.h"
#include "luau_variant_bindings.h"
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

using namespace godot;
namespace {
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
enum Kind { Number, Integer, Boolean, Text, Vector, Vector2Value, Colour, ResourceValue };
struct Property { const char* Class; const char* Name; const char* Native; Kind Type; double Min=0; double Max=0; const char* ResourceClass=nullptr; };
// Fixed schema. Native property spelling is never supplied by gameplay code.
const Property Properties[]={
    {"Node","Name","name",Text,1,128},
    {"Node3D","Position","position",Vector,-100000,100000},
    {"Node3D","RotationDegrees","rotation_degrees",Vector,-360000,360000},
    {"Node3D","Scale","scale",Vector,0.001,100},
    {"Node3D","Visible","visible",Boolean},
    {"MeshInstance3D","Mesh","mesh",ResourceValue,0,0,"Mesh"},
    {"GeometryInstance3D","Material","material_override",ResourceValue,0,0,"Material"},
    {"CollisionObject3D","CollisionLayer","collision_layer",Integer,0,4294967295.0},
    {"CollisionObject3D","CollisionMask","collision_mask",Integer,0,4294967295.0},
    {"RigidBody3D","Mass","mass",Number,0.01,10000},
    {"RigidBody3D","GravityScale","gravity_scale",Number,0,100},
    {"RigidBody3D","Freeze","freeze",Boolean},
    {"CollisionShape3D","Shape","shape",ResourceValue,0,0,"Shape3D"},
    {"CollisionShape3D","Disabled","disabled",Boolean},
    {"Light3D","Color","light_color",Colour},
    {"Light3D","Energy","light_energy",Number,0,64},
    {"Light3D","ShadowEnabled","shadow_enabled",Boolean},
    {"OmniLight3D","Range","omni_range",Number,0.01,10000},
    {"SpotLight3D","Range","spot_range",Number,0.01,10000},
    {"Camera3D","Fov","fov",Number,1,179},
    {"Camera3D","Near","near",Number,0.01,100},
    {"Camera3D","Far","far",Number,100,100000},
    {"WorldEnvironment","Environment","environment",ResourceValue,0,0,"Environment"},
    {"Label3D","Text","text",Text,0,8192},
    {"Label3D","Billboard","billboard",Integer,0,3},
    {"Label3D","FontSize","font_size",Integer,1,256},
    {"CanvasLayer","Layer","layer",Integer,-128,128},
    {"Control","Visible","visible",Boolean},
    {"Control","Position","position",Vector2Value,-100000,100000},
    {"Control","Size","size",Vector2Value,0,100000},
    {"Control","MinSize","custom_minimum_size",Vector2Value,0,100000},
    {"Control","MouseFilter","mouse_filter",Integer,0,2},
    {"Control","Modulate","modulate",Colour},
    {"Control","FontSize","@font_size",Integer,1,256},
    {"Control","FullRect","@full_rect",Boolean},
    {"BoxContainer","Separation","@separation",Integer,0,1024},
    {"ColorRect","Color","color",Colour},
    {"Label","Text","text",Text,0,8192},
    {"Button","Text","text",Text,0,8192},
    {"LineEdit","Text","text",Text,0,8192},
    {"LineEdit","PlaceholderText","placeholder_text",Text,0,1024},
    {"AudioStreamPlayer","Stream","stream",ResourceValue,0,0,"AudioStream"},
    {"AudioStreamPlayer","VolumeDb","volume_db",Number,-80,6},
    {"AudioStreamPlayer","PitchScale","pitch_scale",Number,0.1,4},
    {"SoftBody3D","Mesh","mesh",ResourceValue,0,0,"ArrayMesh"},
    {"SoftBody3D","CollisionLayer","collision_layer",Integer,0,4294967295.0},
    {"SoftBody3D","CollisionMask","collision_mask",Integer,0,4294967295.0},
    {"SoftBody3D","SimulationPrecision","simulation_precision",Integer,1,20},
    {"SoftBody3D","TotalMass","total_mass",Number,0.01,10000},
    {"BoxMesh","Size","size",Vector,0.001,10000},
    {"SphereMesh","Radius","radius",Number,0.001,10000},
    {"SphereMesh","Height","height",Number,0.002,20000},
    {"SphereMesh","RadialSegments","radial_segments",Integer,4,64},
    {"SphereMesh","Rings","rings",Integer,1,32},
    {"BoxShape3D","Size","size",Vector,0.001,10000},
    {"SphereShape3D","Radius","radius",Number,0.001,10000},
    {"StandardMaterial3D","Color","albedo_color",Colour},
    {"StandardMaterial3D","Roughness","roughness",Number,0,1},
    {"StandardMaterial3D","EmissionEnabled","emission_enabled",Boolean},
    {"StandardMaterial3D","Emission","emission",Colour},
    {"Environment","BackgroundMode","background_mode",Integer,1,1},
    {"Environment","BackgroundColor","background_color",Colour},
    {"Environment","AmbientLightSource","ambient_light_source",Integer,3,3},
    {"Environment","AmbientLightColor","ambient_light_color",Colour},
    {"Environment","AmbientLightEnergy","ambient_light_energy",Number,0,16}
};
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
        case Vector: if (auto Value=check_vector3(Thread,Index)) {
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
        case ResourceValue:
            if (lua_isnil(Thread,Index)) return Variant();
            if (auto Handle=HandleAt(Thread,Index)) if (*Handle && (*Handle)->Scope==uint64_t(Scope->get_instance_id()) && (*Handle)->Value.is_valid() && (*Handle)->Value->is_class(Item.ResourceClass))
                return (*Handle)->Value;
            break;
    }
    luaL_error(Thread,"[Scene:Type] Invalid or out-of-bounds %s",Item.Name);
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
        if (!strcmp(Key,"@font_size")) Object::cast_to<Control>(Target)->add_theme_font_size_override("font_size",int(int64_t(Entry.Value)));
        else if (!strcmp(Key,"@separation")) Object::cast_to<Control>(Target)->add_theme_constant_override("separation",int(int64_t(Entry.Value)));
        else if (!strcmp(Key,"@full_rect")) {
            if (bool(Entry.Value)) Object::cast_to<Control>(Target)->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
            else Object::cast_to<Control>(Target)->set_anchors_preset(Control::PRESET_TOP_LEFT);
        } else Target->set(Key,Entry.Value);
    }
}
Node* CreateNode(const char* Class) {
#define GL_NODE(Type) if (!strcmp(Class,#Type)) return memnew(Type)
    GL_NODE(Node3D); GL_NODE(MeshInstance3D); GL_NODE(StaticBody3D); GL_NODE(RigidBody3D); GL_NODE(CollisionShape3D);
    GL_NODE(DirectionalLight3D); GL_NODE(OmniLight3D); GL_NODE(SpotLight3D); GL_NODE(Camera3D); GL_NODE(WorldEnvironment); GL_NODE(Label3D);
    GL_NODE(CanvasLayer); GL_NODE(Control); GL_NODE(ColorRect); GL_NODE(PanelContainer); GL_NODE(VBoxContainer); GL_NODE(HBoxContainer);
    GL_NODE(Label); GL_NODE(Button); GL_NODE(AudioStreamPlayer); GL_NODE(SoftBody3D);
#undef GL_NODE
    if (!strcmp(Class,"LineEdit")) { auto Edit=memnew(LineEdit); Edit->set_max_length(8192); return Edit; }
    return nullptr;
}
Ref<Resource> CreateResource(const char* Class) {
#define GL_RESOURCE(Type) if (!strcmp(Class,#Type)) { Ref<Type> Value; Value.instantiate(); return Value; }
    GL_RESOURCE(BoxMesh); GL_RESOURCE(SphereMesh); GL_RESOURCE(BoxShape3D); GL_RESOURCE(SphereShape3D); GL_RESOURCE(StandardMaterial3D); GL_RESOURCE(Environment);
#undef GL_RESOURCE
    return Ref<Resource>();
}
void PushProperty(lua_State* Thread, SceneScope* Scope, Object* Target, const char* Key) {
    const Property* Item=FindProperty(Target,Key);
    if (!Item) luaL_error(Thread,"[Scene:Property] Unsupported property %s",Key);
    Variant Value;
    if (!strcmp(Item->Native,"@font_size")) Value=Object::cast_to<Control>(Target)->get_theme_font_size("font_size");
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
    if (strcmp(Type,"Texture2D") && strcmp(Type,"AudioStream") && strcmp(Type,"Mesh")) luaL_error(Thread,"[Scene:Type] Unsupported load type");
    String Path=CheckedString(Thread,3,4096);
    if (!GLProjectResourcePath(Path)) luaL_error(Thread,"[Scene:Resource] Project resource path denied");
    Ref<FileAccess> File=FileAccess::open(Path,FileAccess::READ);
    if (File.is_null() || File->get_length()>16*1024*1024) luaL_error(Thread,"[Scene:Resource] Resource unavailable or encoded input exceeds 16 MiB");
    File.unref();
    Ref<Resource> Value=ResourceLoader::get_singleton()->load(Path,Type);
    if (Value.is_null() || !Value->is_class(Type)) luaL_error(Thread,"[Scene:Resource] Resource type or load failed");
    PushResource(Thread,Scope,Value,true); return 1;
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
    bool HasText;
    static bool Equal(const CallableCustom* Left, const CallableCustom* Right) {
        auto A=static_cast<const SceneCallable*>(Left); auto B=static_cast<const SceneCallable*>(Right);
        return A->Receiver==B->Receiver && A->Reference==B->Reference;
    }
    static bool Less(const CallableCustom* Left, const CallableCustom* Right) {
        auto A=static_cast<const SceneCallable*>(Left); auto B=static_cast<const SceneCallable*>(Right);
        return A->Reference!=B->Reference?A->Reference<B->Reference:A->Receiver<B->Receiver;
    }
public:
    SceneCallable(uint64_t Id, int Ref, bool Text) : Receiver(Id),Reference(Ref),HasText(Text) {}
    uint32_t hash() const override { return uint32_t(Reference); }
    String get_as_text() const override { return String("[Scene:Signal] ")+String::num_int64(Reference); }
    CompareEqualFunc get_compare_equal_func() const override { return Equal; }
    CompareLessFunc get_compare_less_func() const override { return Less; }
    ObjectID get_object() const override { return ObjectID(Receiver); }
    bool is_valid() const override { return GLReferenceState(Reference) && Resolve<SceneScope>(Receiver); }
    int get_argument_count(bool& Valid) const override { Valid=true; return HasText?1:0; }
    void call(const Variant** Arguments, int Count, Variant& Result, GDExtensionCallError& Error) const override {
        Error.error=GDEXTENSION_CALL_OK; Result=Variant();
        if (Count!=(HasText?1:0) || (HasText && Arguments[0]->get_type()!=Variant::STRING)) {
            Error.error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; return;
        }
        auto Scope=Resolve<SceneScope>(Receiver); if (!Scope) return;
        if (HasText) Scope->OnText(*Arguments[0],Reference); else Scope->OnEvent(Reference);
    }
};
int Connect(lua_State* Thread) {
    auto Scope=ScopeAt(Thread); auto Source=Object::cast_to<Node>(TargetAt(Thread,Scope,2,false));
    const char* Signal=CheckedString(Thread,3); luaL_checktype(Thread,4,LUA_TFUNCTION);
    const char* Native=nullptr;
    if (!strcmp(Signal,"Pressed") && Object::cast_to<Button>(Source)) Native="pressed";
    if (!strcmp(Signal,"TextSubmitted") && Object::cast_to<LineEdit>(Source)) Native="text_submitted";
    if (!strcmp(Signal,"Finished") && Object::cast_to<AudioStreamPlayer>(Source)) Native="finished";
    if (!Native) luaL_error(Thread,"[Scene:Signal] Unsupported source/signal");
    // Reap retired callback owners even when their scope remains live.
    for (size_t Index=Scope->Subscriptions.size();Index>0;--Index) {
        const auto& Item=Scope->Subscriptions[Index-1];
        auto Target=Resolve<Node>(Item.Source);
        if (!GLReferenceState(Item.Reference) || !Target || Target->is_queued_for_deletion()) Scope->Disconnect(Item.Reference);
    }
    if (Scope->Subscriptions.size()>=MaxSubscriptions) luaL_error(Thread,"[Scene:Limit] Subscription limit");
    int Reference=GLReference(Thread,4);
    Callable Handler(memnew(SceneCallable(Scope->get_instance_id(),Reference,String(Native)=="text_submitted")));
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
void SceneScope::OnEvent(int Reference) {
    if (Retired || !GLReferenceState(Guard)) return;
    if (std::none_of(Subscriptions.begin(),Subscriptions.end(),[Reference](const auto& Item){return Item.Reference==Reference;})) return;
    GLDispatch(Reference,[](lua_State*){return 0;}); // may destroy this scope; no access afterwards
}
void SceneScope::OnText(String Text, int Reference) {
    if (Retired || !GLReferenceState(Guard) || Text.length()>8192) return;
    if (std::none_of(Subscriptions.begin(),Subscriptions.end(),[Reference](const auto& Item){return Item.Reference==Reference;})) return;
    GLDispatch(Reference,[Text](lua_State* Thread){lua_pushstring(Thread,Text.utf8().get_data());return 1;});
}
void GLRegisterScene(lua_State* Thread) {
    luaL_newmetatable(Thread,"SceneResource");
    lua_pushliteral(Thread,"SceneResource"); lua_setfield(Thread,-2,"__type"); lua_pop(Thread,1);
    lua_newtable(Thread); lua_pushcfunction(Thread,Root,"new"); lua_setfield(Thread,-2,"new"); lua_setglobal(Thread,"Scene");
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
        static const Method Methods[]={{"New",New},{"Configure",Configure},{"Get",Get},{"Mesh",BuildMesh},{"Pin",Pin},{"Tone",Tone},{"Load",Load},{"Play",Play},{"Stop",Stop},{"Impulse",Impulse},{"Connect",Connect}};
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
