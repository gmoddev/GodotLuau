#ifndef RBX_CHARACTER_H
#define RBX_CHARACTER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/physics_body3d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include "rbx_model.h"
#include "roblox_player.h"
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/label3d.hpp>
#include <godot_cpp/classes/sprite3d.hpp>
#include <godot_cpp/classes/sprite_base3d.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/base_material3d.hpp>
#include <vector>
#include <array>

#include "lua.h"
#include "lualib.h"
#include "gl_errors.h"
#include "gl_runtime.h"   // gl_state_alive
#include "gl_execution_domain.h"
#include <cmath>

using namespace godot;

// ════════════════════════════════════════════════════════════════════
//  RBXCharacter — Movement and health system for 3D characters
//
//  RBXCharacter is the character's "engine". It handles:
//  - Movement physics (WASD + camera)
//  - Health and damage
//  - Signals (Died, HealthChanged)
//  - Collision detection with RobloxParts (Touched event)
//
//  Properties editable from Luau:
//    humanoid.WalkSpeed  = 20    -- Normal speed
//    humanoid.JumpPower  = 20    -- Jump force
//    humanoid.Health     = 100   -- Current health
////
//  RBXCharacter — Sistema de movimiento y salud del personaje 3D
//
//  El RBXCharacter es el "motor" del personaje. Maneja:
//  - Física de movimiento (WASD + cámara)
//  - Salud y daño
//  - Señales (Died, HealthChanged)
//  - Detección de colisiones con RobloxParts (evento Touched)
//
//  Propiedades modificables desde Luau:
//    humanoid.WalkSpeed  = 20    -- Velocidad normal
//    humanoid.JumpPower  = 20    -- Fuerza del salto
//    humanoid.Health     = 100   -- Salud actual
// ════════════════════════════════════════════════════════════════════
class RBXAnimator : public Node {
    GDCLASS(RBXAnimator, Node);
protected:
    static void _bind_methods() {}
};

class RBXCharacter : public RBXModel {
    GDCLASS(RBXCharacter, RBXModel);

public:
    // Callback for Luau signals (Died, HealthChanged)
    //// Callback para señales Luau (Died, HealthChanged)
    struct LuaCallback {
        lua_State* main_L;
        int ref;
        bool active = true;
    };

    std::vector<LuaCallback> died_cbs;
    std::vector<LuaCallback> health_changed_cbs;
    std::vector<LuaCallback> state_changed_cbs;
    // Senales de movimiento de Roblox. Se disparan desde _physics_process con el
    // estado real del cuerpo, asi que Animate.lua (el script de animacion que
    // trae cada NPC de un place importado) funciona tal cual.
    std::vector<LuaCallback> running_cbs;
    std::vector<LuaCallback> jumping_cbs;
    std::vector<LuaCallback> freefalling_cbs;
    std::vector<LuaCallback> climbing_cbs;
    std::vector<LuaCallback> swimming_cbs;
    std::vector<LuaCallback> gettingup_cbs;
    std::vector<LuaCallback> seated_cbs;
    std::vector<LuaCallback> moveto_cbs;
    // Senales que Roblox tiene y aqui no tienen disparador propio todavia: se
    // aceptan y guardan la conexion para que el script no muera (es lo que hace
    // que Animate.lua llegue hasta el final y los NPC se animen).
    std::vector<LuaCallback> other_move_cbs;

    // Estado de animación REAL de este personaje (1.14.17). Lo lee el
    // NetworkService para replicarlo tal cual, en vez de que cada máquina lo
    // deduzca del movimiento del muñeco (que hacía durar de más los saltos).
    float anim_speed01  = 0.0f;
    bool  anim_airborne = false;

    void add_died_callback(lua_State* main_L, int ref) {
        died_cbs.push_back({main_L, ref, true});
    }
    void add_health_changed_callback(lua_State* main_L, int ref) {
        health_changed_cbs.push_back({main_L, ref, true});
    }
    void add_state_changed_callback(lua_State* main_L, int ref) {
        state_changed_cbs.push_back({main_L, ref, true});
    }
    // add_move_signal_callback(which, ...) — 0=Running 1=Jumping 2=FreeFalling
    // 3=Climbing 4=Swimming 5=GettingUp 6=Seated 7=MoveToFinished
    std::vector<LuaCallback>* move_signal_list(int which) {
        switch (which) {
            case 0: return &running_cbs;
            case 1: return &jumping_cbs;
            case 2: return &freefalling_cbs;
            case 3: return &climbing_cbs;
            case 4: return &swimming_cbs;
            case 5: return &gettingup_cbs;
            case 6: return &seated_cbs;
            case 7: return &moveto_cbs;
            default: return &other_move_cbs;
        }
    }
    void add_move_signal_callback(int which, lua_State* main_L, int ref) {
        move_signal_list(which)->push_back({main_L, ref, true});
    }
    void remove_callbacks_for_state(lua_State* L) {
        for (auto& cb : died_cbs)           if (cb.main_L == L) cb.active = false;
        for (auto& cb : health_changed_cbs) if (cb.main_L == L) cb.active = false;
        for (auto& cb : state_changed_cbs)  if (cb.main_L == L) cb.active = false;
        for (int w = 0; w <= 13; w++)
            for (auto& cb : *move_signal_list(w)) if (cb.main_L == L) cb.active = false;
    }
    void _gl_disconnect(int ref) {
        for (auto& cb : died_cbs)           if (cb.ref == ref) cb.active = false;
        for (auto& cb : health_changed_cbs) if (cb.ref == ref) cb.active = false;
        for (auto& cb : state_changed_cbs)  if (cb.ref == ref) cb.active = false;
        for (int w = 0; w <= 13; w++)
            for (auto& cb : *move_signal_list(w)) if (cb.ref == ref) cb.active = false;
    }

    static void fire_lua_died(std::vector<LuaCallback>& cbs, uint64_t Owner = 0) {
        for (int i = (int)cbs.size() - 1; i >= 0; i--) {
            if (Owner) { auto Live = Object::cast_to<Node>(ObjectDB::get_instance(Owner)); if (!Live || Live->is_queued_for_deletion()) return; }
            auto cb = cbs[i];
            if (!cb.active || !GLReferenceAlive(cb.main_L, cb.ref)) { cbs.erase(cbs.begin() + i); continue; }
            GLDispatch(cb.ref, [](lua_State*) -> int { return 0; });
        }
    }
    static void fire_lua_state_changed(std::vector<LuaCallback>& cbs, int new_state, int old_state, uint64_t Owner = 0) {
        for (int i = (int)cbs.size() - 1; i >= 0; i--) {
            if (Owner) { auto Live = Object::cast_to<Node>(ObjectDB::get_instance(Owner)); if (!Live || Live->is_queued_for_deletion()) return; }
            auto cb = cbs[i];
            if (!cb.active || !GLReferenceAlive(cb.main_L, cb.ref)) { cbs.erase(cbs.begin() + i); continue; }
            GLDispatch(cb.ref, [&](lua_State* Thread) -> int {
                lua_pushnumber(Thread, new_state);
                lua_pushnumber(Thread, old_state);
                return 2;
            });
        }
    }

    // Dispara una senal de movimiento con un solo argumento (velocidad para
    // Running, booleano para Jumping/Climbing/...).
    static void fire_lua_one(std::vector<LuaCallback>& cbs, const Variant& arg, uint64_t Owner = 0) {
        for (int i = (int)cbs.size() - 1; i >= 0; i--) {
            if (Owner) { auto Live = Object::cast_to<Node>(ObjectDB::get_instance(Owner)); if (!Live || Live->is_queued_for_deletion()) return; }
            auto cb = cbs[i];
            if (!cb.active || !GLReferenceAlive(cb.main_L, cb.ref)) { cbs.erase(cbs.begin() + i); continue; }
            GLDispatch(cb.ref, [&](lua_State* Thread) -> int {
                if (arg.get_type() == Variant::BOOL) lua_pushboolean(Thread, (bool)arg);
                else                                 lua_pushnumber(Thread, (double)arg);
                return 1;
            });
        }
    }

    static void fire_lua_health_changed(std::vector<LuaCallback>& cbs, float new_hp, float old_hp, uint64_t Owner = 0) {
        for (int i = (int)cbs.size() - 1; i >= 0; i--) {
            if (Owner) { auto Live = Object::cast_to<Node>(ObjectDB::get_instance(Owner)); if (!Live || Live->is_queued_for_deletion()) return; }
            auto cb = cbs[i];
            if (!cb.active || !GLReferenceAlive(cb.main_L, cb.ref)) { cbs.erase(cbs.begin() + i); continue; }
            GLDispatch(cb.ref, [&](lua_State* Thread) -> int {
                lua_pushnumber(Thread, new_hp);
                lua_pushnumber(Thread, old_hp);
                return 2;
            });
        }
    }

private:

    uint64_t PhysicsIdentity = 0;
    uint64_t ActiveAnimatorIdentity = 0, ActiveTrackIdentity = 0;
    bool LocalControl = false;
    bool PresentationOnly = gl_net_role() == 2;
    bool Synchronizing = false;
    bool TransformWarning = false;
    bool RigRefreshQueued = false;
    bool InsidePhysics = false;
    bool JumpRequested = false;
    Vector3 ObservedVelocity;
    double ObservedAt = 0;
    bool WalkingToPoint = false;
    uint64_t MoveTargetIdentity = 0;
    Vector3 MoveTarget;
    double MoveTargetElapsed = 0;
    int PendingMoveResult = -1;
    Transform3D LastPose;
    std::array<std::pair<uint64_t, uint64_t>, 32> PendingTouches;
    size_t PendingTouchCount = 0;
    std::array<std::pair<int, int>, 64> PendingStates;
    size_t PendingStateCount = 0;
    bool SignalWarning = false;
    float  health                 = 100.0f;
    float  max_health             = 100.0f;
    float  walk_speed             = 16.0f;
    float  jump_power             = 20.0f;
    float  jump_height            = 7.2f;
    float  hip_height             = 0.0f;
    float  gravity                = 45.0f;
    bool   is_dead                = false;
    bool   auto_rotate            = true;
    // Suavidad del giro del cuerpo hacia la direccion de movimiento (AutoRotate).
    // Mayor = gira mas rapido; menor = mas suave. Independiente de los FPS.
    // v1.8.3: bajado de 9 a 5 (giro claramente mas suave, no brusco).
    float  GroundAcceleration = 110.0f;
    float  AirAcceleration = 45.0f;
    float  turn_speed             = 11.0f;   // giro rapido hacia el movimiento, como Roblox
    bool   auto_jump_enabled      = true;
    float  name_display_distance  = 100.0f;
    float  health_display_distance= 100.0f;
    // 0 = R6, 1 = R15
    int    rig_type               = 1;
    bool   evaluate_state_machine = true;
    bool   break_joints_on_death  = true;
    bool   requires_neck          = true;
    String display_name;

    // ── Display overhead (nombre + barra de vida), como Roblox ──────────
    uint64_t OverheadIdentity = 0, NameIdentity = 0, BarIdentity = 0;
    Node3D* GetOverhead() const { return Object::cast_to<Node3D>(ObjectDB::get_instance(OverheadIdentity)); }
    Label3D* GetNameLabel() const { return Object::cast_to<Label3D>(ObjectDB::get_instance(NameIdentity)); }
    Sprite3D* GetHealthBar() const { return Object::cast_to<Sprite3D>(ObjectDB::get_instance(BarIdentity)); }

    // ── HumanoidStateType (mirror of Enum.HumanoidStateType in Luau) ─
    //// ── HumanoidStateType (espejo de Enum.HumanoidStateType en Luau) ─
    // 0=None 1=Running 2=Jumping 3=Landed 4=Swimming 5=Climbing 6=Seated
    // 7=Dead 8=Freefall 9=Flying 10=GettingUp 11=FallingDown 12=Ragdoll
    // 13=StrafingNoWalk 14=Frozen
    int     current_state = 1;
    int     forced_state  = -1;   // -1 = automatic / automático
    bool    was_on_floor  = true;
    float   landed_timer  = 0.0f;
    bool    body_configured = false;   // config del CharacterBody3D una sola vez
    Vector3 move_direction;
    Vector3 npc_move_dir;         // Non-zero = NPC/scripted movement, overrides player input

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("RefreshRig"), &RBXCharacter::RefreshRig);
        ClassDB::bind_method(D_METHOD("EnsureRootPart"), &RBXCharacter::EnsureRootPart);
        ClassDB::bind_method(D_METHOD("GetPhysicsBody"), &RBXCharacter::GetPhysicsBody);
        ClassDB::bind_method(D_METHOD("IsLocalControl"), &RBXCharacter::IsLocalControl);
        ClassDB::bind_method(D_METHOD("SetLocalControl", "enabled"), &RBXCharacter::SetLocalControl);
        ClassDB::bind_method(D_METHOD("SetPresentationOnly", "enabled"), &RBXCharacter::SetPresentationOnly);
        ClassDB::bind_method(D_METHOD("set_lock_first_person", "enabled"), &RBXCharacter::set_lock_first_person);
        ClassDB::bind_method(D_METHOD("get_lock_first_person"), &RBXCharacter::get_lock_first_person);
        ClassDB::bind_method(D_METHOD("set_camera_mode", "mode"), &RBXCharacter::set_camera_mode);
        ClassDB::bind_method(D_METHOD("get_camera_mode"), &RBXCharacter::get_camera_mode);
        ClassDB::bind_method(D_METHOD("SetAcceleration", "value"), &RBXCharacter::SetAcceleration);
        ClassDB::bind_method(D_METHOD("GetAcceleration"), &RBXCharacter::GetAcceleration);
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "Acceleration"), "SetAcceleration", "GetAcceleration");
        ClassDB::bind_method(D_METHOD("SetAirAcceleration", "value"), &RBXCharacter::SetAirAcceleration);
        ClassDB::bind_method(D_METHOD("GetAirAcceleration"), &RBXCharacter::GetAirAcceleration);
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "AirAcceleration"), "SetAirAcceleration", "GetAirAcceleration");
        ClassDB::bind_method(D_METHOD("SetTurnSpeed", "value"), &RBXCharacter::SetTurnSpeed);
        ClassDB::bind_method(D_METHOD("GetTurnSpeed"), &RBXCharacter::GetTurnSpeed);
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "TurnSpeed"), "SetTurnSpeed", "GetTurnSpeed");
        ClassDB::bind_method(D_METHOD("GetVelocity"), &RBXCharacter::GetVelocity);
        ClassDB::bind_method(D_METHOD("IsGrounded"), &RBXCharacter::IsGrounded);
        ClassDB::bind_method(D_METHOD("set_mouse_sensitivity", "value"), &RBXCharacter::set_mouse_sensitivity);
        ClassDB::bind_method(D_METHOD("get_mouse_sensitivity"), &RBXCharacter::get_mouse_sensitivity);
        ClassDB::bind_method(D_METHOD("set_joystick_radius", "value"), &RBXCharacter::set_joystick_radius);
        ClassDB::bind_method(D_METHOD("get_joystick_radius"), &RBXCharacter::get_joystick_radius);
        ClassDB::bind_method(D_METHOD("set_joystick_opacity", "value"), &RBXCharacter::set_joystick_opacity);
        ClassDB::bind_method(D_METHOD("get_joystick_opacity"), &RBXCharacter::get_joystick_opacity);
        ClassDB::bind_method(D_METHOD("set_joystick_dynamic", "value"), &RBXCharacter::set_joystick_dynamic);
        ClassDB::bind_method(D_METHOD("get_joystick_dynamic"), &RBXCharacter::get_joystick_dynamic);
        ClassDB::bind_method(D_METHOD("set_dev_camera_occlusion_mode", "value"), &RBXCharacter::set_dev_camera_occlusion_mode);
        ClassDB::bind_method(D_METHOD("get_dev_camera_occlusion_mode"), &RBXCharacter::get_dev_camera_occlusion_mode);
        ClassDB::bind_method(D_METHOD("set_dev_computer_movement_mode", "value"), &RBXCharacter::set_dev_computer_movement_mode);
        ClassDB::bind_method(D_METHOD("get_dev_computer_movement_mode"), &RBXCharacter::get_dev_computer_movement_mode);
        ClassDB::bind_method(D_METHOD("set_dev_touch_movement_mode", "value"), &RBXCharacter::set_dev_touch_movement_mode);
        ClassDB::bind_method(D_METHOD("get_dev_touch_movement_mode"), &RBXCharacter::get_dev_touch_movement_mode);
        ClassDB::bind_method(D_METHOD("WalkToPoint", "position"), &RBXCharacter::WalkToPoint);
        ClassDB::bind_method(D_METHOD("WalkToPart", "part"), &RBXCharacter::WalkToPart);
        ClassDB::bind_method(D_METHOD("RequestJump"), &RBXCharacter::RequestJump);
        ClassDB::bind_method(D_METHOD("_gl_disconnect", "ref"), &RBXCharacter::_gl_disconnect);
        ClassDB::bind_method(D_METHOD("set_health", "h"),       &RBXCharacter::set_health);
        ClassDB::bind_method(D_METHOD("get_health"),             &RBXCharacter::get_health);
        ClassDB::bind_method(D_METHOD("set_max_health", "h"),   &RBXCharacter::set_max_health);
        ClassDB::bind_method(D_METHOD("get_max_health"),         &RBXCharacter::get_max_health);
        ClassDB::bind_method(D_METHOD("set_walk_speed", "s"),   &RBXCharacter::set_walk_speed);
        ClassDB::bind_method(D_METHOD("get_walk_speed"),         &RBXCharacter::get_walk_speed);
        ClassDB::bind_method(D_METHOD("set_jump_power", "p"),   &RBXCharacter::set_jump_power);
        ClassDB::bind_method(D_METHOD("get_jump_power"),         &RBXCharacter::get_jump_power);
        ClassDB::bind_method(D_METHOD("set_gravity_val", "g"),  &RBXCharacter::set_gravity_val);
        ClassDB::bind_method(D_METHOD("get_gravity_val"),        &RBXCharacter::get_gravity_val);
        ClassDB::bind_method(D_METHOD("take_damage", "amount"), &RBXCharacter::take_damage);
        ClassDB::bind_method(D_METHOD("heal", "amount"),         &RBXCharacter::heal);

        ADD_GROUP("Salud", "");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "Health",
                                  PROPERTY_HINT_RANGE, "0,1000,0.1"),
                     "set_health", "get_health");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "MaxHealth",
                                  PROPERTY_HINT_RANGE, "1,1000,1"),
                     "set_max_health", "get_max_health");






        ADD_GROUP("Movimiento", "");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "WalkSpeed",
                                  PROPERTY_HINT_RANGE, "0,100,0.1"),
                     "set_walk_speed", "get_walk_speed");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "JumpPower",
                                  PROPERTY_HINT_RANGE, "0,200,0.1"),
                     "set_jump_power", "get_jump_power");




        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "Gravity",
                                  PROPERTY_HINT_RANGE, "0,200,0.1"),
                     "set_gravity_val", "get_gravity_val");

        ADD_GROUP("Personaje", "");
        ClassDB::bind_method(D_METHOD("set_auto_rotate","b"),              &RBXCharacter::set_auto_rotate);
        ClassDB::bind_method(D_METHOD("get_auto_rotate"),                  &RBXCharacter::get_auto_rotate);


        ClassDB::bind_method(D_METHOD("set_display_name","n"),             &RBXCharacter::set_display_name);
        ClassDB::bind_method(D_METHOD("get_display_name"),                 &RBXCharacter::get_display_name);
        ClassDB::bind_method(D_METHOD("set_name_display_distance","d"),    &RBXCharacter::set_name_display_distance);
        ClassDB::bind_method(D_METHOD("get_name_display_distance"),        &RBXCharacter::get_name_display_distance);
        ClassDB::bind_method(D_METHOD("set_health_display_distance","d"),  &RBXCharacter::set_health_display_distance);
        ClassDB::bind_method(D_METHOD("get_health_display_distance"),      &RBXCharacter::get_health_display_distance);









        ADD_PROPERTY(PropertyInfo(Variant::BOOL,  "AutoRotate"),            "set_auto_rotate","get_auto_rotate");

        ADD_PROPERTY(PropertyInfo(Variant::STRING,"DisplayName"),           "set_display_name","get_display_name");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "NameDisplayDistance",    PROPERTY_HINT_RANGE,"0,1000,1"), "set_name_display_distance","get_name_display_distance");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "HealthDisplayDistance",  PROPERTY_HINT_RANGE,"0,1000,1"), "set_health_display_distance","get_health_display_distance");





        ClassDB::bind_method(D_METHOD("get_state"),              &RBXCharacter::get_state);
        ClassDB::bind_method(D_METHOD("change_state","s"),       &RBXCharacter::change_state);
        ClassDB::bind_method(D_METHOD("get_move_direction"),     &RBXCharacter::get_move_direction);
        ClassDB::bind_method(D_METHOD("set_npc_move_dir","dir"), &RBXCharacter::set_npc_move_dir);
        ClassDB::bind_method(D_METHOD("get_npc_move_dir"),       &RBXCharacter::get_npc_move_dir);
        ClassDB::bind_method(D_METHOD("stop_npc_movement"),      &RBXCharacter::stop_npc_movement);

        // Roblox-style signals
        //// Señales tipo Roblox
        ADD_SIGNAL(MethodInfo("MoveToFinished", PropertyInfo(Variant::BOOL, "arrived")));
        ADD_SIGNAL(MethodInfo("Running", PropertyInfo(Variant::FLOAT, "speed")));
        ADD_SIGNAL(MethodInfo("Jumping", PropertyInfo(Variant::BOOL, "active")));
        ADD_SIGNAL(MethodInfo("FreeFalling", PropertyInfo(Variant::BOOL, "active")));
        ADD_SIGNAL(MethodInfo("Died"));
        ADD_SIGNAL(MethodInfo("HealthChanged",
            PropertyInfo(Variant::FLOAT, "new_health"),
            PropertyInfo(Variant::FLOAT, "old_health")));
        ADD_SIGNAL(MethodInfo("StateChanged",
            PropertyInfo(Variant::INT, "new_state"),
            PropertyInfo(Variant::INT, "old_state")));
    }

public:

    uint64_t GetActiveTrack() const { return ActiveTrackIdentity; }
    bool OwnsTrack(uint64_t Animator, uint64_t Track) const { return ActiveAnimatorIdentity == Animator && ActiveTrackIdentity == Track; }
    void SetActiveTrack(uint64_t Animator, uint64_t Track) { ActiveAnimatorIdentity = Animator; ActiveTrackIdentity = Track; }
    RBXCharacter() {
        auto Body = memnew(RobloxPlayer);
        Body->set_name("PhysicsBody");
        Body->SetLocalControl(false);
        Body->set_as_top_level(true);
        PhysicsIdentity = static_cast<uint64_t>(Body->get_instance_id());
        auto Shape = memnew(CollisionShape3D);
        Shape->set_name("CollisionShape3D");
        Ref<CapsuleShape3D> Capsule; Capsule.instantiate();
        Capsule->set_radius(0.5f); Capsule->set_height(2.0f);
        Shape->set_shape(Capsule); Body->add_child(Shape);
        add_child(Body, false, Node::INTERNAL_MODE_BACK);
        set_notify_transform(true);
    }
    RobloxPlayer* GetPhysicsBody() const {
        auto Body = Object::cast_to<RobloxPlayer>(ObjectDB::get_instance(PhysicsIdentity));
        return Body && !Body->is_queued_for_deletion() && Body->get_parent() == this ? Body : nullptr;
    }
    void SetLocalControl(bool Enabled) {
        LocalControl = Enabled;
        if (Enabled) PresentationOnly = false;
        if (auto Body = GetPhysicsBody()) Body->SetLocalControl(Enabled);
    }
    bool IsLocalControl() const { return LocalControl; }
    void SetPresentationOnly(bool Enabled) { PresentationOnly = Enabled; }
    bool IsPresentationOnly() const { return PresentationOnly; }

    void ConfigureVisual(Node* Item) {
        if (!Item || Item == GetPhysicsBody() || Item->is_class("RobloxTool") || Item->is_class("RBXCharacter")) return;
        if (auto Part = Object::cast_to<RobloxPart>(Item)) { Part->set_anchored(true); Part->set_can_collide(false); }
        if (auto Body = Object::cast_to<PhysicsBody3D>(Item)) {
            Body->set_collision_layer(0); Body->set_collision_mask(0);
            if (auto Rigid = Object::cast_to<RigidBody3D>(Body)) Rigid->set_freeze_enabled(true);
        }
        for (int Index = 0; Index < Item->get_child_count(); ++Index) ConfigureVisual(Item->get_child(Index));
    }
    void RefreshRig() {
        RigRefreshQueued = false;
        for (int Index = 0; Index < get_child_count(); ++Index) ConfigureVisual(get_child(Index));
    }

    void EnsureRootPart() {
        if (is_queued_for_deletion()) return;
        auto Part = Object::cast_to<Node3D>(get_node_or_null("HumanoidRootPart"));
        if (!Part) {
            Part = memnew(Node3D); Part->set_name("HumanoidRootPart"); add_child(Part);
        }
        Part->set_transform(Transform3D());
        set_primary_part(NodePath("HumanoidRootPart"));
        RefreshRig();
        if (!get_node_or_null("Animator")) {
            auto Animator = memnew(RBXAnimator); Animator->set_name("Animator"); add_child(Animator);
        }
    }
    bool AcceptTransform(const Transform3D& Pose) const override { return ValidPose(Pose); }
    static bool ValidPose(const Transform3D& Pose) {
        if (!Pose.is_finite() || Pose.basis.determinant() <= 0 || Math::abs(Pose.origin.x) > 10000000 || Math::abs(Pose.origin.y) > 10000000 || Math::abs(Pose.origin.z) > 10000000) return false;
        Vector3 Scale = Pose.basis.get_scale();
        if (Scale.x < 0.001f || Scale.x > 100 || !Math::is_equal_approx(Scale.x, Scale.y) ||
            !Math::is_equal_approx(Scale.x, Scale.z)) return false;
        Basis Rotation = Pose.basis.orthonormalized();
        return Rotation.scaled(Scale).is_equal_approx(Pose.basis);
    }
    void SynchronizeBody() {
        if (!is_inside_tree() || Synchronizing) return;
        auto Body = GetPhysicsBody(); if (!Body) return;
        Synchronizing = true;
        Transform3D Pose = get_global_transform();
        if (!ValidPose(Pose)) {
            if (!TransformWarning) { UtilityFunctions::push_warning("[Character:Transform] Rejected nonfinite, singular, sheared or nonuniform Character transform."); TransformWarning = true; }
            set_global_transform(LastPose); force_update_transform();
        } else {
            LastPose = Pose; Body->set_global_transform(Pose); Body->force_update_transform();
        }
        Synchronizing = false;
    }
    void _ready() override {
        RefreshRig();
        if (gl_in_template_container(this)) { set_physics_process(false); if (auto Body = GetPhysicsBody()) { Body->set_collision_layer(0); Body->set_collision_mask(0); } return; }
        SynchronizeBody();
        call_deferred("EnsureRootPart");
    }
    uint64_t DepartureObserver = 0;
public:
    void SetDepartureObserver(uint64_t Identity) { DepartureObserver = Identity; }
    void _notification(int What) {
        if (What == NOTIFICATION_PREDELETE && DepartureObserver) {
            const uint64_t ObserverIdentity = DepartureObserver;
            DepartureObserver = 0;
            if (auto Observer = ObjectDB::get_instance(ObserverIdentity))
                Observer->call("_character_departing", static_cast<uint64_t>(get_instance_id()));
        }
        if (What == NOTIFICATION_TRANSFORM_CHANGED && !Synchronizing) SynchronizeBody();
        if (What == NOTIFICATION_CHILD_ORDER_CHANGED && is_inside_tree() && !RigRefreshQueued) {
            RigRefreshQueued = true; call_deferred("RefreshRig");
        }
    }
    void set_lock_first_person(bool Enabled) { if (auto Body = GetPhysicsBody()) Body->set_lock_first_person(Enabled); }
    bool get_lock_first_person() const { auto Body = GetPhysicsBody(); return Body && Body->get_lock_first_person(); }
    void set_camera_mode(int Mode) { if (auto Body = GetPhysicsBody()) Body->set_camera_mode(Mode); }
    int get_camera_mode() const { auto Body = GetPhysicsBody(); return Body ? Body->get_camera_mode() : 1; }
    void SetAcceleration(float Value) { if (std::isfinite(Value) && Value >= 0 && Value <= 1000000 && !GLExecutionDomain::IsClientExecution()) GroundAcceleration = Value; }
    float GetAcceleration() const { return GroundAcceleration; }
    void SetAirAcceleration(float Value) { if (std::isfinite(Value) && Value >= 0 && Value <= 1000000 && !GLExecutionDomain::IsClientExecution()) AirAcceleration = Value; }
    float GetAirAcceleration() const { return AirAcceleration; }
    void SetTurnSpeed(float Value) { if (std::isfinite(Value) && Value >= 0 && Value <= 1000000 && !GLExecutionDomain::IsClientExecution()) turn_speed = Value; }
    float GetTurnSpeed() const { return turn_speed; }
    bool IsGrounded() const { auto Body = GetPhysicsBody(); return PresentationOnly ? !anim_airborne : Body && Body->is_on_floor(); }
    void set_mouse_sensitivity(float Value) { if (auto Body = GetPhysicsBody()) Body->set_mouse_sensitivity(Value); }
    float get_mouse_sensitivity() const { auto Body = GetPhysicsBody(); return Body ? Body->get_mouse_sensitivity() : 0.0022f; }
    void set_joystick_radius(float Value) { if (auto Body = GetPhysicsBody()) Body->set_joystick_radius(Value); }
    float get_joystick_radius() const { auto Body = GetPhysicsBody(); return Body ? Body->get_joystick_radius() : 80.0f; }
    void set_joystick_opacity(float Value) { if (auto Body = GetPhysicsBody()) Body->set_joystick_opacity(Value); }
    float get_joystick_opacity() const { auto Body = GetPhysicsBody(); return Body ? Body->get_joystick_opacity() : 1.0f; }
    void set_joystick_dynamic(bool Value) { if (auto Body = GetPhysicsBody()) Body->set_joystick_dynamic(Value); }
    bool get_joystick_dynamic() const { auto Body = GetPhysicsBody(); return Body ? Body->get_joystick_dynamic() : true; }
    void set_dev_camera_occlusion_mode(int Value) { if (auto Body = GetPhysicsBody()) Body->set_dev_camera_occlusion_mode(Value); }
    int get_dev_camera_occlusion_mode() const { auto Body = GetPhysicsBody(); return Body ? Body->get_dev_camera_occlusion_mode() : 0; }
    void set_dev_computer_movement_mode(int Value) { if (auto Body = GetPhysicsBody()) Body->set_dev_computer_movement_mode(Value); }
    int get_dev_computer_movement_mode() const { auto Body = GetPhysicsBody(); return Body ? Body->get_dev_computer_movement_mode() : 0; }
    void set_dev_touch_movement_mode(int Value) { if (auto Body = GetPhysicsBody()) Body->set_dev_touch_movement_mode(Value); }
    int get_dev_touch_movement_mode() const { auto Body = GetPhysicsBody(); return Body ? Body->get_dev_touch_movement_mode() : 0; }
    bool CanControlMovement() const { return !PresentationOnly && (!GLExecutionDomain::IsClientExecution() || LocalControl); }
    bool RequestJump() { auto Body = GetPhysicsBody(); if (!CanControlMovement() || is_dead || !Body || !Body->is_on_floor()) return false; JumpRequested = true; return true; }
    bool WalkToPoint(const Vector3& Position) {
        if (!CanControlMovement() || is_dead || !Position.is_finite()) return false;
        MoveTarget = Position; MoveTargetElapsed = 0; MoveTargetIdentity = 0; WalkingToPoint = true;
        return true;
    }
    bool WalkToPart(Node3D* Part) {
        if (!Part || !Part->is_inside_tree() || Part->is_queued_for_deletion() || !WalkToPoint(Part->get_global_position())) return false;
        MoveTargetIdentity = static_cast<uint64_t>(Part->get_instance_id()); return true;
    }
    void FinishMovement(bool Arrived) { WalkingToPoint = false; MoveTargetIdentity = 0; npc_move_dir = Vector3(); PendingMoveResult = Arrived ? 1 : 0;
        if (Arrived) if (auto Body = GetPhysicsBody()) { Vector3 Velocity = Body->get_velocity(); Velocity.x = Velocity.z = 0; Body->set_velocity(Velocity); }
    }
    void UpdateMoveTarget(double Delta) {
        if (!WalkingToPoint) return;
        if (MoveTargetIdentity) {
            auto Target = Object::cast_to<Node3D>(ObjectDB::get_instance(MoveTargetIdentity));
            if (!Target || !Target->is_inside_tree() || Target->is_queued_for_deletion()) { FinishMovement(false); return; }
            MoveTarget = Target->get_global_position();
        }
        Vector3 Direction = MoveTarget - get_global_position(); Direction.y = 0;
        MoveTargetElapsed += Delta;
        if (Direction.length_squared() <= .0625f) FinishMovement(true);
        else if (MoveTargetElapsed >= 8) FinishMovement(false);
        else npc_move_dir = Direction.normalized();
    }
    Vector3 GetVelocity() const { auto Body = GetPhysicsBody(); return PresentationOnly ? ObservedVelocity : Body ? Body->get_velocity() : Vector3(); }
    void SetObservedMovement(float Speed, bool Air, const Vector3& Delta) {
        double Now = Time::get_singleton()->get_ticks_usec() / 1000000.0;
        ObservedVelocity = ObservedAt > 0 ? Delta / Math::max(Now - ObservedAt, 1.0 / 240.0) : Vector3();
        ObservedAt = Now;
        anim_speed01 = Speed; anim_airborne = Air;
        if (is_dead) return;
        Vector3 Horizontal(Delta.x, 0, Delta.z);
        move_direction = Horizontal.length_squared() > .000001f ? Horizontal.normalized() : Vector3();
        InsidePhysics = true;
        _set_state_internal(Air ? (Delta.y > 0 ? 2 : 8) : (current_state == 2 || current_state == 8 ? 3 : Horizontal.length_squared() > .000001f ? 1 : 0));
        float Running = Vector3(ObservedVelocity.x, 0, ObservedVelocity.z).length();
        if (Math::abs(Running - _last_running_speed) > .25f) { _last_running_speed = Running; _pending_running = Running; _has_pending_running = true; }
        if (Air != _last_airborne) { _last_airborne = Air; _pending_airborne = Air; _pending_jumped = Air && Delta.y > 0; _has_pending_air = true; }
        InsidePhysics = false;
    }

    // ── Health ─────────────────────────────────────────────────────
    //// ── Salud ──────────────────────────────────────────────────────
    ~RBXCharacter() {
        for (const auto& Callback : died_cbs) GLUnreference(nullptr, Callback.ref);
        for (const auto& Callback : health_changed_cbs) GLUnreference(nullptr, Callback.ref);
        for (const auto& Callback : state_changed_cbs) GLUnreference(nullptr, Callback.ref);
        for (int Signal = 0; Signal <= 8; ++Signal)
            for (const auto& Callback : *move_signal_list(Signal)) GLUnreference(nullptr, Callback.ref);
    }
    void set_health(float h) {
        if (is_dead || !std::isfinite(h) || GLExecutionDomain::IsClientExecution()) return;
        uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        float old = health;
        health = Math::clamp(h, 0.0f, max_health);
        bool Died = health <= 0.0f;
        if (Died) { is_dead = true; PendingTouchCount = 0; if (auto Body = GetPhysicsBody()) Body->set_velocity(Vector3()); PendingStateCount = 0; _has_pending_running = _has_pending_air = false; if (WalkingToPoint) FinishMovement(false); } // latch before reentrant HealthChanged callbacks

        if (old != health) {
            auto Callbacks = health_changed_cbs;
            emit_signal("HealthChanged", health, old);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            fire_lua_health_changed(Callbacks, health, old, Identity);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            _update_overhead();
        }

        if (Died) {
            _set_state_internal(7); // Dead
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            auto Callbacks = died_cbs;
            emit_signal("Died");
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            fire_lua_died(Callbacks, Identity);
        }
    }
    float get_health() const { return health; }

    void set_max_health(float h) {
        if (!std::isfinite(h) || GLExecutionDomain::IsClientExecution()) return;
        max_health = Math::max(h, 1.0f);
        if (health > max_health) set_health(max_health);
    }
    float get_max_health() const { return max_health; }

    // Equivalent to Roblox RBXCharacter:TakeDamage()
    //// Equivalente a RBXCharacter:TakeDamage() de Roblox
    void take_damage(float amount) {
        if (!std::isfinite(amount) || amount < 0) return;
        set_health(health - amount);
    }

    // Restore health
    //// Curar salud
    void heal(float amount) {
        if (is_dead || !std::isfinite(amount) || amount < 0) return;
        set_health(health + amount);
    }

    bool is_character_dead() const { return is_dead; }

    // ── RBXCharacter State ─────────────────────────────────────────────
    //// ── Estado del RBXCharacter ────────────────────────────────────────
    int     get_state() const          { return current_state; }
    Vector3 get_move_direction() const { return move_direction; }
    void    set_npc_move_dir(Vector3 dir) { if (dir.is_finite() && CanControlMovement()) { if (WalkingToPoint) FinishMovement(false); npc_move_dir = dir.limit_length(1); } }
    Vector3 get_npc_move_dir() const      { return npc_move_dir; }
    void    stop_npc_movement()           { set_npc_move_dir(Vector3()); }

    bool change_state(int s) {
        if (s == 2) return RequestJump();
        if ((s == 0 || s == 1) && CanControlMovement()) { stop_npc_movement(); return true; }
        if (s == 7 && !GLExecutionDomain::IsClientExecution()) { set_health(0); return true; }
        return false;
    }

    // ── Movement ───────────────────────────────────────────────────
    //// ── Movimiento ─────────────────────────────────────────────────
    void  set_walk_speed(float s)   { if (std::isfinite(s) && s <= 1000000 && !GLExecutionDomain::IsClientExecution()) walk_speed = Math::max(s, 0.0f); }
    float get_walk_speed() const    { return walk_speed; }
    void  set_jump_power(float p)   { if (std::isfinite(p) && p <= 1000000 && !GLExecutionDomain::IsClientExecution()) jump_power = Math::max(p, 0.0f); }
    float get_jump_power() const    { return jump_power; }
    void  set_jump_height(float h)  { if (std::isfinite(h) && !GLExecutionDomain::IsClientExecution()) jump_height = Math::max(h, 0.0f); }
    float get_jump_height() const   { return jump_height; }
    void  set_hip_height(float h)   { if (std::isfinite(h) && !GLExecutionDomain::IsClientExecution()) hip_height = Math::max(h, 0.0f); }
    float get_hip_height() const    { return hip_height; }
    void  set_gravity_val(float g)  { if (std::isfinite(g) && g <= 1000000 && !GLExecutionDomain::IsClientExecution()) gravity = Math::max(g, 0.0f); }
    float get_gravity_val() const   { return gravity; }

    // ── Character ──────────────────────────────────────────────────
    //// ── Personaje ──────────────────────────────────────────────────
    void   set_auto_rotate(bool b)              { if (!GLExecutionDomain::IsClientExecution()) auto_rotate = b; }
    bool   get_auto_rotate() const              { return auto_rotate; }
    void   set_auto_jump_enabled(bool b)        { auto_jump_enabled = b; }
    bool   get_auto_jump_enabled() const        { return auto_jump_enabled; }
    void   set_display_name(String n)           { display_name = n; }
    String get_display_name() const             { return display_name; }
    void   set_name_display_distance(float d)   { if (std::isfinite(d) && !GLExecutionDomain::IsClientExecution()) name_display_distance = Math::max(d, 0.0f); }
    float  get_name_display_distance() const    { return name_display_distance; }
    void   set_health_display_distance(float d) { if (std::isfinite(d) && !GLExecutionDomain::IsClientExecution()) health_display_distance = Math::max(d, 0.0f); }
    float  get_health_display_distance() const  { return health_display_distance; }
    void   set_rig_type(int t)                  { rig_type = Math::clamp(t, 0, 1); }
    int    get_rig_type() const                 { return rig_type; }
    void   set_evaluate_state_machine(bool b)   { evaluate_state_machine = b; }
    bool   get_evaluate_state_machine() const   { return evaluate_state_machine; }
    void   set_break_joints_on_death(bool b)    { break_joints_on_death = b; }
    bool   get_break_joints_on_death() const    { return break_joints_on_death; }
    void   set_requires_neck(bool b)            { requires_neck = b; }
    bool   get_requires_neck() const            { return requires_neck; }

    void _set_state_internal(int new_state) {
        if (current_state == new_state) return;
        int old = current_state;
        current_state = new_state;
        if (InsidePhysics) {
            if (PendingStateCount < PendingStates.size()) PendingStates[PendingStateCount++] = {old, new_state};
            else {
                PendingStates.back().second = new_state;
                if (!SignalWarning) { UtilityFunctions::push_warning("[Character:Signals] State transition queue full; coalescing to the latest state."); SignalWarning = true; }
            }
            return;
        }
        uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        auto Callbacks = state_changed_cbs;
        emit_signal("StateChanged", new_state, old);
        if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
        fire_lua_state_changed(Callbacks, new_state, old, Identity);
    }

    // ── _physics_process: all movement logic ───────────────────────
    //// ── _physics_process: toda la lógica de movimiento ─────────────
    // Crea el display sobre la cabeza (nombre + barra de vida), estilo Roblox:
    // el nombre es un Label3D en billboard; la barra es un quad con shader que se
    // llena desde la izquierda (verde→rojo) y se ve a través de paredes (always
    // on top). Se crea una sola vez, colgado del cuerpo del personaje.
    void _ensure_overhead() {
        if (GetOverhead()) return;
        const uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        Node3D* body = this;
        if (!body) return;

        auto _overhead = memnew(Node3D);
        OverheadIdentity = static_cast<uint64_t>(_overhead->get_instance_id());
        _overhead->set_name("Overhead");
        body->add_child(_overhead);
        if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
        _overhead->set_position(Vector3(0, 3.0f, 0));   // sobre la cabeza (R6/R15)

        // Nombre
        auto _name_label = memnew(Label3D);
        NameIdentity = static_cast<uint64_t>(_name_label->get_instance_id());
        _name_label->set_text(display_name.is_empty() ? String(body->get_name()) : display_name);
        _name_label->set_billboard_mode(BaseMaterial3D::BILLBOARD_ENABLED);
        _name_label->set_draw_flag(Label3D::FLAG_DISABLE_DEPTH_TEST, true);
        _name_label->set_font_size(48);
        _name_label->set_pixel_size(0.0065f);   // ~0.3 unidades de alto, escala con distancia
        _name_label->set_outline_size(8);
        _name_label->set_position(Vector3(0, 0.58f, 0));   // nombre arriba, con hueco sobre la barra
        _overhead->add_child(_name_label);

        // Barra de vida: Sprite3D con textura generada (billboard nativo, fiable).
        // La textura se rellena de izquierda a derecha según la vida (verde→rojo),
        // exactamente como una barra de Roblox.
        auto _hp_sprite = memnew(Sprite3D);
        BarIdentity = static_cast<uint64_t>(_hp_sprite->get_instance_id());
        _hp_sprite->set_billboard_mode(BaseMaterial3D::BILLBOARD_ENABLED);
        _hp_sprite->set_draw_flag(SpriteBase3D::FLAG_DISABLE_DEPTH_TEST, true);
        _hp_sprite->set_pixel_size(0.014f);   // 100px * 0.014 = ~1.4 unidades de ancho
        _hp_sprite->set_position(Vector3(0, 0.28f, 0));
        _overhead->add_child(_hp_sprite);

        _update_overhead();
    }

    Ref<ImageTexture> _make_hp_texture(float ratio) {
        const int W = 100, H = 14;
        Ref<Image> img = Image::create_empty(W, H, false, Image::FORMAT_RGBA8);
        if (img.is_null() || img->is_empty()) return Ref<ImageTexture>();
        Color fill = Color(0.9f, 0.15f, 0.15f).lerp(Color(0.15f, 0.9f, 0.2f), ratio);
        Color bg(0.07f, 0.07f, 0.07f, 1.0f);
        Color border(0.0f, 0.0f, 0.0f, 1.0f);
        int fillx = (int)(ratio * W);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++) {
                bool b = (x < 2 || x >= W - 2 || y < 2 || y >= H - 2);
                img->set_pixel(x, y, b ? border : (x < fillx ? fill : bg));
            }
        return ImageTexture::create_from_image(img);
    }

    // Oculta el nombre y la barra cuando la camara esta lejos, usando las
    // distancias de Roblox (NameDisplayDistance / HealthDisplayDistance). Antes
    // esas propiedades existian pero NO se aplicaban: el cartel se dibujaba
    // siempre, a cualquier distancia y para todos los personajes.
    void _update_overhead_distance() {
        auto _overhead = GetOverhead(); auto _name_label = GetNameLabel(); auto _hp_sprite = GetHealthBar();
        if (!_overhead || !_overhead->is_inside_tree()) return;
        Viewport* vp = _overhead->get_viewport();
        Camera3D* cam = vp ? vp->get_camera_3d() : nullptr;
        if (!cam) return;
        const float d = cam->get_global_position().distance_to(_overhead->get_global_position());
        if (_name_label) _name_label->set_visible(d <= name_display_distance);
        if (_hp_sprite) {
            const float ratio = max_health > 0.0f ? (health / max_health) : 0.0f;
            _hp_sprite->set_visible(ratio < 0.999f && d <= health_display_distance);
        }
    }

    void _update_overhead() {
        auto _name_label = GetNameLabel(); auto _hp_sprite = GetHealthBar();
        if (_hp_sprite) {
            float ratio = max_health > 0.0f ? Math::clamp(health / max_health, 0.0f, 1.0f) : 0.0f;
            _hp_sprite->set_texture(_make_hp_texture(ratio));
            // Como Roblox (HealthDisplayType por defecto): solo se ve con daño.
            _hp_sprite->set_visible(ratio < 0.999f);
        }
        if (_name_label) {
            Node* body = this;
            _name_label->set_text(display_name.is_empty() && body ? String(body->get_name()) : display_name);
        }
    }

    void _physics_process(double delta) override {
        if (Engine::get_singleton()->is_editor_hint() || gl_in_template_container(this)) return;
        if (PresentationOnly) { _ensure_overhead(); _update_overhead_distance(); return; }
        const uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        _ensure_overhead();
        if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
        _update_overhead_distance();
        if (is_dead) { _update_overhead(); return; }
        SynchronizeBody();

        CharacterBody3D* body = GetPhysicsBody();
        if (!body) return;

        // Config del cuerpo una sola vez: pegado al suelo (no rebota en rampas/
        // escalones) y angulo de suelo amplio, como un personaje de Roblox.
        if (!body_configured) {
            body->set_up_direction(Vector3(0, 1, 0));
            body->set_floor_snap_length(0.5f);
            body->set_floor_stop_on_slope_enabled(true);
            body->set_floor_max_angle((float)Math::deg_to_rad(50.0));
            body_configured = true;
        }

        UpdateMoveTarget(delta);
        Input* input = Input::get_singleton();
        Vector3 velocity = body->get_velocity();

        // ── 1. Gravity ─────────────────────────────────────────────
        //// ── 1. Gravedad ────────────────────────────────────────────
        if (!body->is_on_floor()) {
            velocity.y -= gravity * (float)delta;
        }

        // ── 2. Jump (teclado + gamepad A + boton tactil) ───────────
        //// ── 2. Salto (teclado + gamepad A + botón táctil) ──────────
        // Vista de Servidor activa (o menú abierto): el input no mueve al
        // personaje (WASD/salto congelados, como en Roblox Studio / menú Esc).
        bool freecam = !LocalControl || gl_freecam().active || gl_menu_open();
        bool jump_pressed = !freecam && (input->is_key_pressed(KEY_SPACE)
            || input->is_joy_button_pressed(0, JOY_BUTTON_A)
            || (gl_mobile().active && gl_mobile().jump));
        bool Requested = JumpRequested; JumpRequested = false;
        if ((jump_pressed || Requested) && body->is_on_floor()) {
            velocity.y = jump_power;
        }

        // ── 3. Direction based on active camera ────────────────────
        //// ── 3. Dirección según la cámara activa ───────────────────
        Camera3D* cam = get_viewport()->get_camera_3d();
        {
            Basis cam_basis = cam ? cam->get_global_transform().basis : Basis();
            // forward: camera -Z axis, projected onto the ground
            //// forward: eje -Z de la cámara, proyectado al suelo
            Vector3 forward = -cam_basis.get_column(2);
            Vector3 right   =  cam_basis.get_column(0);
            forward.y = 0.0f;
            right.y   = 0.0f;
            forward   = forward.normalized();
            right     = right.normalized();

            // Input de movimiento UNIFICADO cross-device: teclado, gamepad y
            // joystick tactil alimentan el mismo vector (como el moveVector del
            // ControlModule de Roblox). Asi el personaje se mueve en PC, movil
            // y consola sin cambiar nada.
            float input_forward = 0.0f;
            float input_right   = 0.0f;
            if (!freecam) {
                // Teclado (WASD + flechas)
                if (input->is_key_pressed(KEY_W) || input->is_key_pressed(KEY_UP))    input_forward += 1.0f;
                if (input->is_key_pressed(KEY_S) || input->is_key_pressed(KEY_DOWN))  input_forward -= 1.0f;
                if (input->is_key_pressed(KEY_D) || input->is_key_pressed(KEY_RIGHT)) input_right   += 1.0f;
                if (input->is_key_pressed(KEY_A) || input->is_key_pressed(KEY_LEFT))  input_right   -= 1.0f;
                // Gamepad: stick izquierdo (zona muerta para evitar deriva)
                {
                    Vector2 ls(input->get_joy_axis(0, JOY_AXIS_LEFT_X),
                               input->get_joy_axis(0, JOY_AXIS_LEFT_Y));
                    if (ls.length() > 0.2f) { input_right += ls.x; input_forward -= ls.y; }
                }
                // Tactil: joystick virtual en pantalla (lo escribe el RobloxPlayer)
                if (gl_mobile().active) {
                    Vector2 tv = gl_mobile().move;
                    if (tv.length() > 0.05f) { input_right += tv.x; input_forward += tv.y; }
                }
            }
            input_forward = Math::clamp(input_forward, -1.0f, 1.0f);
            input_right   = Math::clamp(input_right,   -1.0f, 1.0f);

            Vector3 move_dir = forward * input_forward + right * input_right;

            // NPC/scripted movement overrides player input when set
            if (npc_move_dir.length_squared() > 0.01f) {
                move_dir = npc_move_dir.normalized();
                move_dir.y = 0;
            }

            // Primera persona (1.15): el cuerpo mira SIEMPRE hacia donde apunta
            // la camara, tambien parado y andando hacia atras. Antes giraba hacia
            // la direccion del movimiento tambien aqui, asi que pulsar S te daba
            // la vuelta en vez de andar de espaldas.
            bool first_person = body->has_method("_gl_is_first_person")
                             && (bool)body->call("_gl_is_first_person");

            // Velocidad horizontal OBJETIVO (0 si no hay input).
            Vector3 target_h(0.0f, 0.0f, 0.0f);
            if (move_dir.length_squared() > 0.01f) {
                move_dir = move_dir.normalized();
                // Sprint: Shift (teclado) o click del stick izquierdo (gamepad)
                bool sprint = LocalControl && !freecam && (input->is_key_pressed(KEY_SHIFT)
                    || input->is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK));
                float speed_mult = sprint ? 1.5f : 1.0f;
                target_h = move_dir * (walk_speed * speed_mult);

                // AutoRotate: girar el cuerpo hacia la direccion del movimiento,
                // como Roblox. Suavizado exponencial: independiente de los FPS y
                // SIN sobre-girar (el factor nunca pasa de 1). Antes usaba
                // 16*delta, que con FPS bajos podia pasar de 1 y "latigar".
                if (auto_rotate && !first_person) {
                    float target_angle = (float)Math::atan2((double)-move_dir.x, (double)-move_dir.z);
                    Vector3 cur_rot = body->get_rotation();
                    float t = 1.0f - Math::exp(-turn_speed * (float)delta);
                    cur_rot.y = (float)Math::lerp_angle(
                        (double)cur_rot.y, (double)target_angle, (double)t);
                    body->set_rotation(cur_rot);
                }
            }

            // En primera persona el giro es INSTANTANEO y va pegado a la camara
            // (Roblox lo bloquea ahi); suavizarlo se sentiria como un retraso.
            if (auto_rotate && first_person && body->has_method("_gl_camera_yaw")) {
                Vector3 cur_rot = body->get_rotation();
                cur_rot.y = (float)(double)body->call("_gl_camera_yaw");
                body->set_rotation(cur_rot);
            }

            // Aceleracion/desaceleracion suave hacia la velocidad objetivo, estilo
            // Roblox: arranque y frenada rapidos pero sin tirones, y DELTA-correcto
            // (antes la frenada dependia de los FPS). Menos control en el aire.
            float accel = body->is_on_floor() ? GroundAcceleration : AirAcceleration;
            velocity.x = (float)Math::move_toward((double)velocity.x, (double)target_h.x, (double)(accel * delta));
            velocity.z = (float)Math::move_toward((double)velocity.z, (double)target_h.z, (double)(accel * delta));
        }

        body->set_velocity(velocity);
        body->move_and_slide();
        velocity = body->get_velocity();
        Synchronizing = true;
        set_global_transform(body->get_global_transform());
        force_update_transform();
        LastPose = get_global_transform();
        Synchronizing = false;

        // ── 4. Detect collisions with RobloxParts (Touched event) ──
        //// ── 4. Detectar colisiones con RobloxParts (evento Touched) ─
        for (int i = 0; i < body->get_slide_collision_count(); i++) {
            Ref<KinematicCollision3D> col = body->get_slide_collision(i);
            if (col.is_valid()) {
                Node* collider = Object::cast_to<Node>(col->get_collider());
                if (collider && collider->has_signal("Touched")) {
                    // Se reporta una PARTE del personaje, no el personaje: así
                    // `hit.Parent:FindFirstChild("RBXCharacter")` funciona (1.14.11).
                    Node* Hit = gl_touch_reported_node(body);
                    if (Hit && PendingTouchCount < PendingTouches.size()) PendingTouches[PendingTouchCount++] = {static_cast<uint64_t>(collider->get_instance_id()), static_cast<uint64_t>(Hit->get_instance_id())};
                }
            }
        }

        InsidePhysics = true;
        // ── 5. State machine (HumanoidStateType) ───────────────────
        //// ── 5. Máquina de estados (HumanoidStateType) ─────────────
        if (evaluate_state_machine) {
            bool on_floor = body->is_on_floor();
            Vector3 horiz = Vector3(velocity.x, 0.0f, velocity.z);
            move_direction = horiz.length_squared() > 0.01f ? horiz.normalized() : Vector3();

            if (forced_state >= 0) {
                _set_state_internal(forced_state);
            } else if (on_floor) {
                if (!was_on_floor && (current_state == 8 || current_state == 2)) {
                    // Just landed
                    //// Acaba de aterrizar
                    _set_state_internal(3); // Landed
                    landed_timer = 0.12f;
                } else if (landed_timer > 0.0f) {
                    landed_timer -= (float)delta;
                    if (landed_timer <= 0.0f) _set_state_internal(1); // Running
                } else {
                    _set_state_internal(horiz.length_squared() > 0.01f ? 1 : 0); // observed running/idle
                }
            } else {
                // En el aire
                if (velocity.y > 0.1f) _set_state_internal(2); // Jumping
                else                    _set_state_internal(8); // Freefall
            }
            was_on_floor = on_floor;
        }

        // Animacion de PRUEBA por codigo (placeholder): SOLO si el toggle de
        // Debug 'debug_test_animation' esta activo. Anima la malla visual, no
        // la fisica; sirve para ver el muñeco "vivo" sin animaciones reales aun.
        _drive_animation(body, velocity, delta);
        InsidePhysics = false;
    }

    // ── Animacion del personaje: R6Animator (avatar por partes) o fallback ──
    void _drive_animation(CharacterBody3D* body, const Vector3& velocity, double delta) {
        // Desde 1.14.5.3 el personaje está APLANADO: el nodo "Character" del rig
        // desaparece y el animador queda como hijo DIRECTO. Buscar solo en
        // "Character/R6Animator" dejó las animaciones R6 del jugador local
        // MUERTAS (caían al fallback) sin que nada avisara. Se mira primero el
        // camino aplanado y se conserva el viejo por compatibilidad.
        Node* anim = body ? get_node_or_null(NodePath("R6Animator")) : nullptr;
        if (!anim) {
            Node* character = body ? get_node_or_null(NodePath("Character")) : nullptr;
            anim = character ? character->get_node_or_null(NodePath("R6Animator")) : nullptr;
        }
        Vector3 horiz(velocity.x, 0.0f, velocity.z);
        double speed01 = Math::clamp((double)horiz.length() / (double)Math::max(walk_speed, 0.1f), 0.0, 1.0);
        // Estado REAL de animación (1.14.17): se guarda para que el NetworkService
        // lo replique tal cual. Antes cada máquina lo ADIVINABA del movimiento del
        // muñeco, y por eso el salto de otro jugador duraba más de la cuenta.
        anim_speed01  = (float)speed01;
        anim_airborne = !body->is_on_floor();
        // Senales de Roblox: Running con la velocidad real (studs/s) cada vez que
        // cambia de forma apreciable, y FreeFalling/Jumping al despegar y
        // aterrizar. Es lo que consume Animate.lua para elegir la animacion.
        //
        // OJO: aqui solo se APUNTA lo que hay que avisar. Disparar Lua dentro del
        // paso de fisica reventaba el motor: los manejadores crean y destruyen
        // nodos (AnimationPlayer, tracks) y Godot no admite tocar el arbol de
        // cuerpos a mitad del step. Se emite en _process, ya fuera del step.
        {
            const float spd = horiz.length();
            if (Math::abs(spd - _last_running_speed) > 0.25f) {
                _last_running_speed = spd;
                _pending_running = spd;
                _has_pending_running = true;
            }
            if (anim_airborne != _last_airborne) {
                _last_airborne = anim_airborne;
                _pending_airborne = anim_airborne;
                _pending_jumped = anim_airborne && velocity.y > 0.1f;
                _has_pending_air = true;
            }
        }
        if (anim) {
            anim->call("set_move_state", speed01, anim_airborne);
            return;
        }
        _test_animate(body, velocity, delta);
    }

    // ── Animacion de prueba: como el avatar es una malla unica sin huesos,
    //    animamos su transform (rebote al estar quieto/caminar + giro hacia
    //    la direccion de movimiento). Se restaura sola al apagar el toggle.
    float _last_running_speed = -1.0f;
    bool  _last_airborne = false;
    float _pending_running = 0.0f;
    bool  _has_pending_running = false;
    bool  _has_pending_air = false;
    bool  _pending_airborne = false;
    bool  _pending_jumped = false;

public:
    // Emite las senales de movimiento pendientes FUERA del paso de fisica.
    void _gl_flush_move_signals() {
        const uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        auto Emit = [&](const char* Name, const std::vector<LuaCallback>& List, const Variant& Value) {
            auto Snapshot = List;
            emit_signal(Name, Value);
            auto Live = Object::cast_to<Node>(ObjectDB::get_instance(Identity));
            if (Live != this || Live->is_queued_for_deletion()) return false;
            fire_lua_one(Snapshot, Value, Identity);
            Live = Object::cast_to<Node>(ObjectDB::get_instance(Identity));
            return Live == this && !Live->is_queued_for_deletion();
        };
        if (PendingMoveResult >= 0) {
            bool Arrived = PendingMoveResult == 1; PendingMoveResult = -1;
            if (!Emit("MoveToFinished", moveto_cbs, Arrived)) return;
        }
        if (_has_pending_running) {
            _has_pending_running = false;
            if (!Emit("Running", running_cbs, static_cast<double>(_pending_running))) return;
        }
        if (_has_pending_air) {
            const bool Air = _pending_airborne, Jumped = _pending_jumped;
            _has_pending_air = false;
            if (Air && Jumped && !Emit("Jumping", jumping_cbs, true)) return;
            if (!Emit("FreeFalling", freefalling_cbs, Air)) return;
        }
    }

private:
    float anim_time     = 0.0f;
    float anim_base_y   = 0.0f;
    bool  anim_base_set = false;

    void _test_animate(CharacterBody3D* body, const Vector3& velocity, double delta) {
        Node3D* mesh = body ? Object::cast_to<Node3D>(get_node_or_null(NodePath("Character"))) : nullptr;
        if (!mesh) return;
        bool on = (bool)ProjectSettings::get_singleton()->get_setting("godot_luau/debug_test_animation", false);
        if (!on) {
            if (anim_base_set) {
                Vector3 p = mesh->get_position(); p.y = anim_base_y;
                mesh->set_position(p); mesh->set_rotation(Vector3());
                anim_base_set = false;
            }
            return;
        }
        if (!anim_base_set) { anim_base_y = mesh->get_position().y; anim_base_set = true; }
        anim_time += (float)delta;
        Vector3 horiz(velocity.x, 0.0f, velocity.z);
        bool moving = horiz.length() > 0.5f;
        float freq = moving ? 9.0f : 2.2f;
        float amp  = moving ? 0.12f : 0.04f;
        Vector3 p = mesh->get_position();
        p.y = anim_base_y + Math::abs(Math::sin(anim_time * freq)) * amp;
        mesh->set_position(p);
        float yaw  = moving ? Math::atan2(velocity.x, velocity.z) : mesh->get_rotation().y;
        float sway = moving ? Math::sin(anim_time * freq) * 0.08f : 0.0f;
        mesh->set_rotation(Vector3(0.0f, yaw, sway));
    }

public:
    // Fuera del paso de fisica: aqui SI se puede llamar a Lua (los manejadores
    // de Animate.lua crean y destruyen nodos).
    void _process(double) override {
        uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        const auto Touches = PendingTouches;
        const size_t TouchCount = PendingTouchCount; PendingTouchCount = 0;
        for (size_t Index = 0; Index < TouchCount; ++Index) {
            const auto& Touch = Touches[Index];
            auto Collider = Object::cast_to<Node>(ObjectDB::get_instance(Touch.first));
            auto Hit = Object::cast_to<Node>(ObjectDB::get_instance(Touch.second));
            if (Collider && !Collider->is_queued_for_deletion() && Hit && !Hit->is_queued_for_deletion()) Collider->emit_signal("Touched", Hit);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
        }
        const auto States = PendingStates;
        const size_t StateCount = PendingStateCount; PendingStateCount = 0;
        for (size_t Index = 0; Index < StateCount; ++Index) {
            const auto& State = States[Index];
            auto Callbacks = state_changed_cbs;
            emit_signal("StateChanged", State.second, State.first);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            fire_lua_state_changed(Callbacks, State.second, State.first, Identity);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            if (is_dead) break;
        }
        _gl_flush_move_signals();
    }
};

#endif // RBX_CHARACTER_H
