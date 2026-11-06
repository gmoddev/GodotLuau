#include "character_controller.h"
#include "rbx_character.h"
#include "roblox_services.h"
#include "roblox_network.h"
#include "luau_value_bindings.h"
#include <godot_cpp/classes/multiplayer_api.hpp>
#include <godot_cpp/classes/multiplayer_peer.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <cmath>
#include <cstring>
#include <limits>

namespace {
bool OptionalBoolean(lua_State* Thread, int Index) {
    if (lua_isnoneornil(Thread,Index)) return false;
    luaL_checktype(Thread,Index,LUA_TBOOLEAN);
    return lua_toboolean(Thread,Index)!=0;
}
uint64_t Generation(lua_State* Thread) {
    return *static_cast<const uint64_t*>(lua_touserdata(Thread,lua_upvalueindex(2)));
}
}

bool RBXCharacter::ControllerLocalCharacter() const {
    if (!LocalControl || PresentationOnly || is_dead || !is_inside_tree() || is_queued_for_deletion() || !GetPhysicsBody()) return false;
    auto Player=Object::cast_to<PlayerObject>(ObjectDB::get_instance(DepartureObserver));
    return Player && Player->is_local && !Player->is_queued_for_deletion() && Player->is_inside_tree() &&
        Object::cast_to<Players>(Player->get_parent()) && Player->get_character()==this &&
        Player->get_viewport()==get_viewport();
}
bool RBXCharacter::ControllerContextValid() const {
    if (!ControllerLocalCharacter() || ControllerPlayer!=DepartureObserver || ControllerService!=gl_net_service_id()) return false;
    auto Service=Object::cast_to<NetworkService>(ObjectDB::get_instance(ControllerService));
    if ((ControllerService && !Service) || (Service?Service->get_mode():0)!=ControllerNetMode) return false;
    if (!ControllerNetMode) return true;
    Ref<MultiplayerAPI> Multiplayer=get_multiplayer();
    Ref<MultiplayerPeer> Peer=Multiplayer.is_valid()?Multiplayer->get_multiplayer_peer():Ref<MultiplayerPeer>();
    return Peer.is_valid() && uint64_t(Peer->get_instance_id())==ControllerTransport &&
        Peer->get_connection_status()==MultiplayerPeer::CONNECTION_CONNECTED;
}
bool RBXCharacter::IsControllerActive() const {
    return ControllerModeValue==1 && ControllerGuard && GLReferenceState(ControllerGuard) && ControllerContextValid();
}
bool RBXCharacter::ControllerOwnedBy(lua_State* Thread) const {
    if (!GLExecutionDomain::IsClientExecution() || !Thread || !IsControllerActive()) return false;
    auto Owner=GLGetOwner(Thread);
    auto GuardOwner=GLGetOwner(GLReferenceState(ControllerGuard));
    return Owner && Owner->Alive && Owner==GuardOwner;
}
void RBXCharacter::ClearControllerInput() {
    ControllerDirection=Vector3(); ControllerHasMove=false;
    ControllerSprint=false; ControllerRelative=false; ControllerJump=false; JumpRequested=false;
    if (auto Body=GetPhysicsBody()) {
        Vector3 Velocity=Body->get_velocity(); Velocity.x=Velocity.z=0; Body->set_velocity(Velocity);
        Body->ReleaseScriptedCapture();
    }
}
void RBXCharacter::RetireController() {
    const int Previous=ControllerGuard; ControllerGuard=0;
    ControllerPlayer=ControllerService=ControllerTransport=0; ControllerNetMode=0;
    if (Previous) GLUnreference(nullptr,Previous);
    ClearControllerInput();
}
void RBXCharacter::PollController() {
    if (ControllerModeValue!=1) return;
    if (ControllerGuard && !IsControllerActive()) RetireController();
    else if (!ControllerInputAllowed()) ClearControllerInput();
}
bool RBXCharacter::SelectController(lua_State* Thread, int Mode) {
    if (!Thread || !GLExecutionDomain::IsClientExecution() || (Mode!=0 && Mode!=1) || !ControllerLocalCharacter()) return false;
    auto Owner=GLGetOwner(Thread);
    if (!Owner || !Owner->Alive) return false;
    if (Mode==0) {
        if (ControllerModeValue==0) return true;
        if (IsControllerActive() && !ControllerOwnedBy(Thread)) return false;
        RetireController(); ControllerModeValue=0;
        set_physics_process_priority(ControllerNativePriority);
        if (auto Body=GetPhysicsBody()) Body->SetScriptedInput(false);
        return true;
    }
    if (ControllerGeneration==std::numeric_limits<uint64_t>::max()) return false;
    auto Service=Object::cast_to<NetworkService>(ObjectDB::get_instance(gl_net_service_id()));
    const int ModeValue=Service?Service->get_mode():0;
    Ref<MultiplayerAPI> Multiplayer=get_multiplayer();
    Ref<MultiplayerPeer> Peer=Multiplayer.is_valid()?Multiplayer->get_multiplayer_peer():Ref<MultiplayerPeer>();
    if (ModeValue && (Peer.is_null() || Peer->get_connection_status()!=MultiplayerPeer::CONNECTION_CONNECTED)) return false;
    lua_pushboolean(Thread,true); const int Guard=GLReference(Thread,-1); lua_pop(Thread,1);
    const bool WasNative=ControllerModeValue==0;
    if (WasNative) ControllerNativePriority=get_physics_process_priority();
    RetireController();
    if (WalkingToPoint) FinishMovement(false);
    npc_move_dir=Vector3();
    ControllerGuard=Guard; ControllerPlayer=DepartureObserver; ControllerService=gl_net_service_id();
    ControllerNetMode=ModeValue; ControllerTransport=ModeValue?uint64_t(Peer->get_instance_id()):0;
    ++ControllerGeneration; ControllerModeValue=1;
    set_physics_process_priority(100);
    if (auto Body=GetPhysicsBody()) Body->SetScriptedInput(true);
    return true;
}
bool RBXCharacter::ControllerInputAllowed() const {
    if (!ControllerFocused || !can_process() || Engine::get_singleton()->is_editor_hint() || gl_freecam().active || gl_menu_open()) return false;
    auto Focus=get_viewport()->gui_get_focus_owner();
    return !Object::cast_to<LineEdit>(Focus) && !Object::cast_to<TextEdit>(Focus);
}
bool RBXCharacter::ControllerCanCommand(lua_State* Thread, uint64_t Lease) const {
    return Lease==ControllerGeneration && ControllerOwnedBy(Thread) && ControllerInputAllowed();
}
bool RBXCharacter::SetControllerMove(lua_State* Thread, uint64_t Lease, Vector3 Direction, bool Relative, bool Sprint) {
    if (!Direction.is_finite() || Direction.y!=0 || Direction.length_squared()>1.000001 ||
        !ControllerCanCommand(Thread,Lease)) return false;
    ControllerDirection=Direction.limit_length(1); ControllerRelative=Relative;
    ControllerSprint=Sprint; ControllerHasMove=true;
    return true;
}
bool RBXCharacter::ControllerRequestJump(lua_State* Thread, uint64_t Lease) {
    auto Body=GetPhysicsBody();
    if (!ControllerCanCommand(Thread,Lease) || !Body || !Body->is_on_floor()) return false;
    ControllerJump=true; return true;
}
bool RBXCharacter::RotateControllerCamera(lua_State* Thread, uint64_t Lease, Vector2 Delta) {
    if (!Delta.is_finite() || std::abs(Delta.x)>1 || std::abs(Delta.y)>1 || !ControllerCanCommand(Thread,Lease)) return false;
    auto Body=GetPhysicsBody(); return Body && Body->RotateScriptedCamera(Delta);
}
bool RBXCharacter::CaptureControllerMouse(lua_State* Thread, uint64_t Lease, bool Capture) {
    if (Lease!=ControllerGeneration || !ControllerOwnedBy(Thread) || (Capture && !ControllerInputAllowed())) return false;
    auto Body=GetPhysicsBody(); return Body && Body->CaptureScriptedMouse(Capture);
}

bool GLCharacterControllerIndex(lua_State* Thread, Node* Target, const char* Key) {
    auto Character=Object::cast_to<RBXCharacter>(Target);
    if (!Character) return false;
    if (!strcmp(Key,"ControllerMode")) { lua_pushinteger(Thread,Character->GetControllerMode()); return true; }
    if (!strcmp(Key,"ControllerActive")) { lua_pushboolean(Thread,Character->ControllerOwnedBy(Thread)); return true; }
    if (!strcmp(Key,"ControllerInputEnabled")) { lua_pushboolean(Thread,Character->ControllerCanCommand(Thread,Character->GetControllerGeneration())); return true; }
    const bool Move=!strcmp(Key,"Move"), Jump=!strcmp(Key,"Jump");
    if ((Move || Jump) && Character->GetControllerMode()!=1) return false;
    if (!Move && !Jump && strcmp(Key,"RotateCamera") && strcmp(Key,"CaptureMouse")) return false;
    GLPushNodeHandle(Thread,Character);
    *static_cast<uint64_t*>(lua_newuserdata(Thread,sizeof(uint64_t)))=Character->GetControllerGeneration();
    lua_pushstring(Thread,Key);
    lua_pushcclosure(Thread,([](lua_State* State)->int {
        // Parse only typed/raw value data; no user __index runs before revalidation.
        const char* Method=lua_tostring(State,lua_upvalueindex(3));
        Vector3 Direction; Vector2 Delta; bool Relative=false, Sprint=false, Capture=false;
        if (!strcmp(Method,"Move")) {
            if (lua_gettop(State)>4) luaL_error(State,"[Character:Control] Move accepts Direction, RelativeToCamera and Sprint");
            auto Value=check_vector3(State,2);
            if (!Value) luaL_error(State,"[Character:Control] Move requires a native Vector3");
            Direction=Vector3(Value->x,Value->y,Value->z);
            Relative=OptionalBoolean(State,3); Sprint=OptionalBoolean(State,4);
        } else if (!strcmp(Method,"RotateCamera")) {
            if (lua_gettop(State)!=2) luaL_error(State,"[Character:Control] RotateCamera requires one Vector2");
            luaL_checktype(State,2,LUA_TTABLE);
            lua_rawgetfield(State,2,"X"); luaL_checktype(State,-1,LUA_TNUMBER); const double X=luaL_checknumber(State,-1); lua_pop(State,1);
            lua_rawgetfield(State,2,"Y"); luaL_checktype(State,-1,LUA_TNUMBER); const double Y=luaL_checknumber(State,-1); lua_pop(State,1); Delta=Vector2(X,Y);
        } else if (!strcmp(Method,"CaptureMouse")) {
            if (lua_gettop(State)!=2) luaL_error(State,"[Character:Control] CaptureMouse requires one boolean");
            luaL_checktype(State,2,LUA_TBOOLEAN); Capture=lua_toboolean(State,2)!=0;
        } else if (lua_gettop(State)>1) luaL_error(State,"[Character:Control] Jump takes no arguments");
        auto Current=Object::cast_to<RBXCharacter>(GLNodeUpvalue(State,1));
        bool Result=false;
        if (Current && !Current->is_queued_for_deletion()) {
            const uint64_t Lease=Generation(State);
            if (!strcmp(Method,"Move")) Result=Current->SetControllerMove(State,Lease,Direction,Relative,Sprint);
            else if (!strcmp(Method,"Jump")) Result=Current->ControllerRequestJump(State,Lease);
            else if (!strcmp(Method,"RotateCamera")) Result=Current->RotateControllerCamera(State,Lease,Delta);
            else Result=Current->CaptureControllerMouse(State,Lease,Capture);
        }
        lua_pushboolean(State,Result); return 1;
    }),"CharacterControllerCommand",3);
    return true;
}
bool GLCharacterControllerWrite(lua_State* Thread, Node* Target, const char* Key) {
    auto Character=Object::cast_to<RBXCharacter>(Target);
    if (!Character) return false;
    if (!strcmp(Key,"ControllerActive") || !strcmp(Key,"ControllerInputEnabled")) luaL_error(Thread,"[Character:Control] Controller state is read-only");
    if (strcmp(Key,"ControllerMode")) return false;
    const double Value=lua_type(Thread,3)==LUA_TNUMBER?lua_tonumber(Thread,3):-1;
    if ((Value!=0 && Value!=1) || !Character->SelectController(Thread,int(Value)))
        luaL_error(Thread,"[Character:Control] ControllerMode requires a live Client-owned Player.Character and Native or Scripted");
    return true;
}
