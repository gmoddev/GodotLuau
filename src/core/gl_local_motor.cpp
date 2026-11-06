#include "local_motor.h"
#include "input_actions.h"
#include "gl_execution_domain.h"
#include "gl_runtime.h"
#include "luau_value_bindings.h"
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <cmath>
#include <cstring>
#include <map>

namespace {
std::map<uint64_t,uint64_t> CameraOwners;
template<class T> T* Resolve(uint64_t Id) { return Object::cast_to<T>(ObjectDB::get_instance(Id)); }
bool Finite(Vector3 Value, double Limit) {
    return Value.is_finite() && std::abs(Value.x)<=Limit && std::abs(Value.y)<=Limit && std::abs(Value.z)<=Limit;
}
KinematicMotor3D* RequireMotor(lua_State* Thread) {
    auto Motor=Object::cast_to<KinematicMotor3D>(GLNodeUpvalue(Thread,1));
    if (!GLExecutionDomain::IsClientExecution() || !Motor || !Motor->OwnerAlive())
        luaL_error(Thread,"[Input:Motor] Retired motor or non-Client execution");
    Motor->AdoptOwner(Thread);
    if (!Motor->CanCommand()) luaL_error(Thread,"[Input:Motor] Motor must be in the local scene");
    return Motor;
}
void PushVector(lua_State* Thread, Vector3 Value) { push_vector3(Thread,Value.x,Value.y,Value.z); }
}

KinematicMotor3D::KinematicMotor3D() {
    // Internal children do not become script-visible handles or duplicate as
    // authored children when the body is cloned/loaded.
    Ref<CapsuleShape3D> Shape; Shape.instantiate(); Shape->set_radius(0.35); Shape->set_height(1.8);
    auto Collider=memnew(CollisionShape3D); Collider->set_name("MotorCollision"); Collider->set_shape(Shape);
    add_child(Collider,false,Node::INTERNAL_MODE_BACK);
    set_floor_snap_length(0.2); set_floor_stop_on_slope_enabled(true);
    set_collision_layer(0); set_collision_mask(0);
}
KinematicMotor3D::~KinematicMotor3D() { RetireCamera(); if (OwnerGuard) GLUnreference(nullptr,OwnerGuard); }
void KinematicMotor3D::_bind_methods() {
    ClassDB::bind_method(D_METHOD("SetMoveVelocity","Velocity"),&KinematicMotor3D::SetMoveVelocity);
    ClassDB::bind_method(D_METHOD("Jump","Speed"),&KinematicMotor3D::Jump);
    ClassDB::bind_method(D_METHOD("Teleport","Position"),&KinematicMotor3D::Teleport);
    ClassDB::bind_method(D_METHOD("SetViewAngles","Yaw","Pitch"),&KinematicMotor3D::SetViewAngles);
    ClassDB::bind_method(D_METHOD("AcquireCamera"),&KinematicMotor3D::AcquireCamera);
    ClassDB::bind_method(D_METHOD("ReleaseCamera"),&KinematicMotor3D::ReleaseCamera);
    ClassDB::bind_method(D_METHOD("CaptureMouse","Capture"),&KinematicMotor3D::CaptureMouse);
    ClassDB::bind_method(D_METHOD("CameraActive"),&KinematicMotor3D::CameraActive);
    ClassDB::bind_method(D_METHOD("GetTicks"),&KinematicMotor3D::GetTicks);
}
void KinematicMotor3D::AdoptOwner(lua_State* Thread) {
    if (!OwnerGuard) {
        lua_pushboolean(Thread,true); OwnerGuard=GLReference(Thread,-1); lua_pop(Thread,1);
        set_velocity(Vector3()); HasMove=false; HasTeleport=false; JumpCommand=0;
        set_collision_layer(1); set_collision_mask(1);
        if (is_inside_tree()) set_physics_process(true);
    }
}
bool KinematicMotor3D::OwnerAlive() const { return !OwnerGuard || GLReferenceState(OwnerGuard)!=nullptr; }
bool KinematicMotor3D::CanCommand() const {
    return GLInputAllowed() && OwnerGuard && OwnerAlive() && is_inside_tree() && can_process() && !is_queued_for_deletion() && !Engine::get_singleton()->is_editor_hint();
}
void KinematicMotor3D::_ready() {
    if (!Engine::get_singleton()->is_editor_hint()) {
        set_physics_process(OwnerGuard!=0);
        // Input fence -100, established RunService.Stepped 0, motor 100.
        set_physics_process_priority(100);
    }
}
void KinematicMotor3D::_notification(int What) {
    if (What==NOTIFICATION_APPLICATION_FOCUS_OUT) { HasMove=false; JumpCommand=0; ReleaseMouse(); }
    if (What==NOTIFICATION_PAUSED) { HasMove=false; JumpCommand=0; ReleaseMouse(); }
    if (What==NOTIFICATION_EXIT_TREE) { HasMove=false; HasTeleport=false; JumpCommand=0; RetireCamera(); }
}
void KinematicMotor3D::_physics_process(double Delta) {
    if (!OwnerAlive()) { RetireCamera(); set_velocity(Vector3()); set_physics_process(false); queue_free(); return; }
    if (Engine::get_singleton()->is_editor_hint()) return;
    ++Ticks;
    if (HasTeleport) { set_global_position(TeleportCommand); set_velocity(Vector3()); reset_physics_interpolation(); HasTeleport=false; }
    Vector3 Velocity=get_velocity();
    Velocity.x=HasMove?MoveCommand.x:0; Velocity.z=HasMove?MoveCommand.z:0; HasMove=false;
    if (is_on_floor()) { Velocity.y=JumpCommand>0?JumpCommand:0; }
    else Velocity.y=(std::max)(-100.0,double(Velocity.y)-24.0*Delta);
    JumpCommand=0;
    set_velocity(Velocity); move_and_slide();
}
bool KinematicMotor3D::SetMoveVelocity(Vector3 Velocity) {
    if (!CanCommand() || !Finite(Velocity,100) || Velocity.y!=0 || Velocity.length()>100) return false;
    MoveCommand=Velocity; HasMove=true; return true;
}
bool KinematicMotor3D::Jump(double Speed) {
    if (!CanCommand() || !std::isfinite(Speed) || Speed<=0 || Speed>50 || !is_on_floor()) return false;
    JumpCommand=Speed; return true;
}
bool KinematicMotor3D::Teleport(Vector3 Position) {
    if (!CanCommand() || !Finite(Position,100000)) return false;
    TeleportCommand=Position; HasTeleport=true; HasMove=false; JumpCommand=0; return true;
}
bool KinematicMotor3D::SetViewAngles(double NextYaw, double NextPitch) {
    if (!CanCommand() || !std::isfinite(NextYaw) || !std::isfinite(NextPitch) || std::abs(NextYaw)>1000000 || std::abs(NextPitch)>1.45) return false;
    Yaw=std::remainder(NextYaw,6.283185307179586); Pitch=NextPitch;
    if (auto Camera=Resolve<Camera3D>(CameraId)) Camera->set_rotation(Vector3(Pitch,Yaw,0));
    return true;
}
bool KinematicMotor3D::CameraActive() const {
    if (!CameraLease || !is_inside_tree()) return false;
    auto Found=CameraOwners.find(CameraViewport);
    return Found!=CameraOwners.end() && Found->second==uint64_t(get_instance_id()) && get_viewport()->get_camera_3d()==Resolve<Camera3D>(CameraId);
}
bool KinematicMotor3D::AcquireCamera() {
    if (!CanCommand()) return false;
    uint64_t View=get_viewport()->get_instance_id(); auto Found=CameraOwners.find(View);
    if (Found!=CameraOwners.end() && Found->second!=uint64_t(get_instance_id()) && Resolve<KinematicMotor3D>(Found->second)) return false;
    if (CameraActive()) return true;
    if (CameraOwners.size()>=16 && Found==CameraOwners.end()) return false;
    Camera3D* Camera=Resolve<Camera3D>(CameraId);
    if (!Camera) {
        Camera=memnew(Camera3D); Camera->set_name("MotorCamera"); Camera->set_position(Vector3(0,0.65,0)); Camera->set_rotation(Vector3(Pitch,Yaw,0));
        CameraId=Camera->get_instance_id(); const uint64_t Id=get_instance_id(); add_child(Camera,false,Node::INTERNAL_MODE_BACK);
        if (Resolve<KinematicMotor3D>(Id)!=this) return false;
        Camera=Resolve<Camera3D>(CameraId); if (!Camera) return false;
        if (!CanCommand() || uint64_t(get_viewport()->get_instance_id())!=View) { Camera->clear_current(); return false; }
    }
    Camera3D* Previous=get_viewport()->get_camera_3d(); PreviousCamera=Previous && Previous!=Camera?uint64_t(Previous->get_instance_id()):0;
    CameraViewport=View; CameraOwners[View]=get_instance_id(); CameraLease=true; Camera->make_current(); return true;
}
void KinematicMotor3D::ReleaseMouse() {
    if (MouseLease) {
        Input* Hardware=Input::get_singleton();
        if (Hardware && Hardware->get_mouse_mode()==Input::MOUSE_MODE_CAPTURED) Hardware->set_mouse_mode(Input::MouseMode(PreviousMouse));
        MouseLease=false;
    }
}
void KinematicMotor3D::ReleaseCamera() {
    if (!GLInputAllowed()) return;
    RetireCamera();
}
void KinematicMotor3D::RetireCamera() {
    auto OwnedCamera=Resolve<Camera3D>(CameraId);
    if (MouseLease && is_inside_tree() && OwnedCamera && OwnedCamera->is_inside_tree() && !CameraActive()) MouseLease=false;
    else ReleaseMouse();
    if (CameraLease) {
        auto Found=CameraOwners.find(CameraViewport);
        if (Found!=CameraOwners.end() && Found->second==uint64_t(get_instance_id())) {
            if (auto View=Resolve<Viewport>(CameraViewport)) if (View->get_camera_3d()==Resolve<Camera3D>(CameraId)) {
                auto Previous=Resolve<Camera3D>(PreviousCamera);
                if (Previous && Previous->is_inside_tree() && Previous->get_viewport()==View) Previous->make_current();
                else if (auto Camera=Resolve<Camera3D>(CameraId)) Camera->clear_current();
            }
            CameraOwners.erase(Found);
        }
        CameraLease=false; PreviousCamera=CameraViewport=0;
    }
}
bool KinematicMotor3D::CaptureMouse(bool Capture) {
    if (!CanCommand() || !CameraActive()) return false;
    if (!Capture) { ReleaseMouse(); return true; }
    if (!MouseLease) { PreviousMouse=Input::get_singleton()->get_mouse_mode(); MouseLease=true; }
    Input::get_singleton()->set_mouse_mode(Input::MOUSE_MODE_CAPTURED); return true;
}

namespace {
int MotorMethod(lua_State* Thread) {
    auto Motor=RequireMotor(Thread); const char* Method=lua_tostring(Thread,lua_upvalueindex(2)); bool Result=false;
    if (!strcmp(Method,"SetMoveVelocity") || !strcmp(Method,"Teleport")) {
        auto Value=check_vector3(Thread,2); Vector3 Vector(Value->x,Value->y,Value->z);
        Result=!strcmp(Method,"Teleport")?Motor->Teleport(Vector):Motor->SetMoveVelocity(Vector);
    } else if (!strcmp(Method,"Jump")) Result=Motor->Jump(luaL_optnumber(Thread,2,5));
    else if (!strcmp(Method,"SetViewAngles")) Result=Motor->SetViewAngles(luaL_checknumber(Thread,2),luaL_checknumber(Thread,3));
    else if (!strcmp(Method,"AcquireCamera")) Result=Motor->AcquireCamera();
    else if (!strcmp(Method,"ReleaseCamera")) { Motor->ReleaseCamera(); Result=true; }
    else if (!strcmp(Method,"CaptureMouse")) { luaL_checktype(Thread,2,LUA_TBOOLEAN); Result=Motor->CaptureMouse(lua_toboolean(Thread,2)); }
    lua_pushboolean(Thread,Result); return 1;
}
}
bool GLMotorIndex(lua_State* Thread, Node* Target, const char* Key) {
    auto Motor=Object::cast_to<KinematicMotor3D>(Target); if (!Motor) return false;
    if (!GLExecutionDomain::IsClientExecution() || !Motor->OwnerAlive()) luaL_error(Thread,"[Input:Motor] Client-owned local motor required");
    if (!strcmp(Key,"Position")) { PushVector(Thread,Motor->is_inside_tree()?Motor->get_global_position():Motor->get_position()); return true; }
    if (!strcmp(Key,"Velocity")) { PushVector(Thread,Motor->get_velocity()); return true; }
    if (!strcmp(Key,"Grounded")) { lua_pushboolean(Thread,Motor->is_on_floor()); return true; }
    if (!strcmp(Key,"FloorNormal")) { PushVector(Thread,Motor->is_on_floor()?Motor->get_floor_normal():Vector3()); return true; }
    if (!strcmp(Key,"Yaw")) { lua_pushnumber(Thread,Motor->GetYaw()); return true; }
    if (!strcmp(Key,"Pitch")) { lua_pushnumber(Thread,Motor->GetPitch()); return true; }
    if (!strcmp(Key,"CameraActive")) { lua_pushboolean(Thread,Motor->CameraActive()); return true; }
    if (!strcmp(Key,"PhysicsTicks")) { lua_pushnumber(Thread,Motor->GetTicks()); return true; }
    static const char* Methods[]={"SetMoveVelocity","Jump","Teleport","SetViewAngles","AcquireCamera","ReleaseCamera","CaptureMouse"};
    for (const char* Method:Methods) if (!strcmp(Key,Method)) { GLPushNodeHandle(Thread,Motor); lua_pushstring(Thread,Method); lua_pushcclosure(Thread,MotorMethod,Method,2); return true; }
    return false;
}
bool GLMotorWrite(lua_State* Thread, Node* Target, const char* Key) {
    auto Motor=Object::cast_to<KinematicMotor3D>(Target); if (!Motor) return false;
    if (!GLExecutionDomain::IsClientExecution() || !Motor->OwnerAlive()) luaL_error(Thread,"[Input:Motor] Client-owned local motor required");
    if (!strcmp(Key,"Name") || !strcmp(Key,"Parent")) { Motor->AdoptOwner(Thread); return false; }
    luaL_error(Thread,"[Input:Motor] Motor observations are read-only; use bounded commands"); return true;
}
