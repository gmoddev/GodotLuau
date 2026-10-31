#ifndef ROBLOX_ANIMATION_H
#define ROBLOX_ANIMATION_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/animation_player.hpp>
#include <godot_cpp/classes/animation.hpp>
#include <godot_cpp/classes/animation_library.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include "gl_asset.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>
#include <cstring>

#include "lua.h"
#include "lualib.h"
#include "gl_errors.h"
#include "gl_runtime.h"

using namespace godot;

// ────────────────────────────────────────────────────────────────────
//  AnimationTrack — equivalent to Roblox's AnimationTrack
//  Returned by Humanoid:LoadAnimation(animation)
//  Usage from Luau:
//    local anim = humanoid:LoadAnimation(animObject)
//    anim:Play()
//    anim:Stop()
//    anim.Looped = true
//    anim.Speed = 1.5
//    anim.Ended:Connect(function() end)
////
//  AnimationTrack — equivalente a Roblox AnimationTrack
//  Devuelto por Humanoid:LoadAnimation(animation)
//  Uso desde Luau:
//    local anim = humanoid:LoadAnimation(animObject)
//    anim:Play()
//    anim:Stop()
//    anim.Looped = true
//    anim.Speed = 1.5
//    anim.Ended:Connect(function() end)
// ────────────────────────────────────────────────────────────────────
// Reproduce (o para) una animación en un personaje CUALQUIERA —típicamente el
// muñeco de otro jugador—, cargando el recurso si hace falta. Es el mismo camino
// que Humanoid:LoadAnimation, para que se vea exactamente lo que hizo su dueño
// (1.14.12).
// Client-selected animation is presentation, never a second gameplay channel.
// Keep one checked clip per peer; the caller owns the immutable native copy.
static inline bool GLPresentationAnimation(const Ref<Animation>& Clip, Node* Character = nullptr, AnimationPlayer* Player = nullptr) {
    if (Clip.is_null() || Clip->get_script().get_type() != Variant::NIL || !Math::is_finite(Clip->get_length()) || Clip->get_length() <= 0 || Clip->get_track_count() > 256) return false;
    Node* Root = Player ? Player->get_node_or_null(Player->get_root_node()) : Character;
    if (Character && (!Root || (Root != Character && !Character->is_ancestor_of(Root)))) return false;
    int Keys = 0;
    for (int Track = 0; Track < Clip->get_track_count(); ++Track) {
        auto Type = Clip->track_get_type(Track);
        if (Type != Animation::TYPE_POSITION_3D && Type != Animation::TYPE_ROTATION_3D &&
            Type != Animation::TYPE_SCALE_3D && Type != Animation::TYPE_BLEND_SHAPE) return false;
        NodePath Path = Clip->track_get_path(Track);
        if (Path.is_absolute() || Path.get_name_count() == 0) return false;
        for (int Index = 0; Index < Path.get_name_count(); ++Index) {
            String Name = Path.get_name(Index);
            if (Name == "." || Name == ".." || Name == "HumanoidRootPart" || Name == "PhysicsBody" || Name == "Humanoid") return false;
        }
        if (Character) {
            Node* Target = Root->get_node_or_null(NodePath(Path.get_concatenated_names()));
            if (!Target || Target == Character || !Character->is_ancestor_of(Target) ||
                Target->is_class("CharacterBody3D") || Target->is_class("AnimatableBody3D")) return false;
        }
        int Count = Clip->track_get_key_count(Track);
        if (Count > 16384 - Keys) return false;
        Keys += Count;
        for (int Key = 0; Key < Count; ++Key) {
            if (!Math::is_finite(Clip->track_get_key_time(Track, Key))) return false;
            Variant Value = Clip->track_get_key_value(Track, Key);
            if (Type == Animation::TYPE_BLEND_SHAPE) {
                if ((Value.get_type() != Variant::FLOAT && Value.get_type() != Variant::INT) || !Math::is_finite(static_cast<double>(Value))) return false;
            } else if (Type == Animation::TYPE_ROTATION_3D) {
                if (Value.get_type() != Variant::QUATERNION || !static_cast<Quaternion>(Value).is_finite()) return false;
            } else if (Value.get_type() != Variant::VECTOR3 || !static_cast<Vector3>(Value).is_finite()) return false;
        }
    }
    return true;
}
static inline Ref<Animation> GLCopyPresentationAnimation(const Ref<Animation>& Source) {
    // Copy only validated track data. Resource::duplicate(true) can duplicate
    // scripted metadata/subresources and execute resource initializers.
    Ref<Animation> Copy;
    if (!GLPresentationAnimation(Source)) return Copy;
    Copy.instantiate();
    Copy->set_length(Source->get_length());
    Copy->set_loop_mode(Source->get_loop_mode());
    Copy->set_step(Source->get_step());
    for (int Track = 0; Track < Source->get_track_count(); ++Track) Source->copy_track(Track, Copy);
    return Copy;
}
static inline Ref<Animation> GLPresentationClip(const String& Identity, const String& Name, Node* Character = nullptr) {
    AnimationPlayer* Player = nullptr;
    if (Character) for (int Index = 0; Index < Character->get_child_count(); ++Index)
        if ((Player = Object::cast_to<AnimationPlayer>(Character->get_child(Index)))) break;
    Ref<Animation> Loaded;
    if (Identity.is_empty()) {
        if (Player && Player->has_animation(Name)) Loaded = Player->get_animation(Name);
    } else {
        String Path = gl_is_roblox_asset(Identity) ? gl_local_asset_path(Identity) : Identity;
        auto Loader = ResourceLoader::get_singleton();
        if (!Loader || !GLProjectResourcePath(Path) || !Loader->exists(Path, "Animation")) return Loaded;
        Loaded = Loader->load(Path, "Animation");
    }
    if (!GLPresentationAnimation(Loaded, Character, Player)) return Ref<Animation>();
    return GLCopyPresentationAnimation(Loaded);
}

static inline bool GLPresentationPlayer(AnimationPlayer* Player, Node* Character, const String& Name, bool Play);
static inline bool GLLoadAnimation(AnimationPlayer* Player, const String& Identity, const String& Name) {
    if (!Player || Name.is_empty()) return false;
    if (GLExecutionDomain::IsClientExecution() && !GLPresentationPlayer(Player, Player->get_parent(), Name, true)) return false;
    uint64_t PlayerIdentity = static_cast<uint64_t>(Player->get_instance_id());
    Dictionary Resources = Player->get_meta("_gl_animation_resources", Dictionary());
    if (Player->has_animation(StringName(Name)) &&
        (Identity.is_empty() || String(Resources.get(Name, Identity)) == Identity))
        return !GLExecutionDomain::IsClientExecution() || GLPresentationAnimation(Player->get_animation(Name), Player->get_parent(), Player);
    Ref<Animation> Loaded;
    if (GLExecutionDomain::IsClientExecution()) {
        Object* Service = ObjectDB::get_instance(gl_net_service_id());
        // Local animation can be prepared before Connect assigns the active
        // transport service. Resolve the owning scene's startup catalog.
        if (!Service) for (Node* Scope = Player->get_parent(); Scope && !Service; Scope = Scope->get_parent())
            for (int Index = 0; Index < Scope->get_child_count(); ++Index)
                if (Scope->get_child(Index)->is_class("NetworkService")) { Service = Scope->get_child(Index); break; }
        if (!Service || !Service->has_method("GetCharacterAnimation")) return false;
        Loaded = Service->call("GetCharacterAnimation", Identity);
    } else {
        ResourceLoader* Loader = ResourceLoader::get_singleton();
        String Path = gl_is_roblox_asset(Identity) ? gl_local_asset_path(Identity) : Identity;
        if (!Loader || !GLProjectResourcePath(Path) || !Loader->exists(Path, "Animation")) return false;
        Loaded = Loader->load(Path, "Animation");
    }
    if (Loaded.is_null()) return false;
    if (ObjectDB::get_instance(PlayerIdentity) != Player || Player->is_queued_for_deletion()) return false;
    if (GLExecutionDomain::IsClientExecution() && !GLPresentationAnimation(Loaded, Player->get_parent(), Player)) return false;
    // Loop mode belongs to this character, not ResourceLoader's shared cache.
    Ref<Animation> Clip = GLExecutionDomain::IsClientExecution() ? GLCopyPresentationAnimation(Loaded) : Ref<Animation>(Loaded->duplicate(true));
    if (ObjectDB::get_instance(PlayerIdentity) != Player || Player->is_queued_for_deletion()) return false;
    Ref<AnimationLibrary> Library;
    if (Player->has_animation_library(StringName(""))) Library = Player->get_animation_library(StringName(""));
    else {
        Library.instantiate();
        Player->add_animation_library(StringName(""), Library);
    }
    if (Library->has_animation(StringName(Name))) {
        if (Player->get_current_animation() == StringName(Name)) Player->stop();
        Library->remove_animation(StringName(Name));
    }
    if (Library->add_animation(StringName(Name), Clip) != OK) return false;
    Resources[Name] = Identity;
    Player->set_meta("_gl_animation_resources", Resources);
    return true;
}

struct GLPresentationPlayback {
    String Name, Slot;
    Ref<AnimationLibrary> Library;
    Ref<Animation> Checked, Original;
};

static inline bool GLPresentationName(const String& Name, AnimationPlayer* Player) {
    if (Name.is_empty() || Name.contains(":") || Name.contains(",") || Name.contains("[")) return false;
    int Slash = Name.find("/");
    if (Slash < 0) return true;
    return Slash > 0 && Slash < Name.length() - 1 && Name.find("/", Slash + 1) < 0 &&
        (!Player || Player->has_animation_library(Name.substr(0, Slash)));
}

static inline bool GLPresentationPlayer(AnimationPlayer* Player, Node* Character, const String& Name, bool Play) {
    if (!Player) return true;
    if (Player->is_playing() && !GLPresentationAnimation(Player->get_animation(Player->get_current_animation()), Character, Player)) return false;
    return !Play || !Player->has_animation(Name) || GLPresentationAnimation(Player->get_animation(Name), Character, Player);
}

static inline void gl_anim_apply(Node* character, const String& anim_id, const String& anim_name,
                                 float speed, bool looped, bool play, Ref<Animation> Checked = Ref<Animation>(),
                                 GLPresentationPlayback* Playback = nullptr) {
    if (!character) return;
    AnimationPlayer* ap = nullptr;
    for (int i = 0; i < character->get_child_count(); i++) {
        ap = Object::cast_to<AnimationPlayer>(character->get_child(i));
        if (ap) break;
    }
    if (!GLPresentationPlayer(ap, character, anim_name, play)) return;
    if (!play) { if (ap) ap->stop(); return; }
    if (!GLPresentationName(anim_name, ap)) return;
    if (Checked.is_null()) Checked = GLPresentationClip(anim_id, anim_name, character);
    if (Checked.is_null() || !GLPresentationAnimation(Checked, character, ap)) return;
    if (!ap) {
        ap = memnew(AnimationPlayer);
        ap->set_name("AnimationPlayer");
        uint64_t CharacterIdentity = static_cast<uint64_t>(character->get_instance_id());
        uint64_t PlayerIdentity = static_cast<uint64_t>(ap->get_instance_id());
        character->add_child(ap);
        if (ObjectDB::get_instance(CharacterIdentity) != character || character->is_queued_for_deletion() ||
            ObjectDB::get_instance(PlayerIdentity) != ap || ap->is_queued_for_deletion()) return;
    }
    uint64_t CharacterIdentity = static_cast<uint64_t>(character->get_instance_id());
    uint64_t PlayerIdentity = static_cast<uint64_t>(ap->get_instance_id());
    if (!ap->has_animation(anim_name) || ap->get_animation(anim_name) != Checked) {
        int Slash = anim_name.find("/");
        String LibraryName = Slash < 0 ? String() : anim_name.substr(0, Slash);
        String Slot = Slash < 0 ? anim_name : anim_name.substr(Slash + 1);
        Ref<AnimationLibrary> Library;
        if (ap->has_animation_library(LibraryName)) Library = ap->get_animation_library(LibraryName);
        else {
            if (!LibraryName.is_empty()) return;
            Library.instantiate(); ap->add_animation_library(LibraryName, Library);
        }
        // A peer owns one temporary library slot. Restore a pre-existing scene
        // clip when changing names, rather than retaining arbitrary new aliases.
        ap->stop();
        if (Playback && !Playback->Name.is_empty()) {
            if (Playback->Library.is_valid() && Playback->Library->has_animation(Playback->Slot) &&
                Playback->Library->get_animation(Playback->Slot) == Playback->Checked) {
                Playback->Library->remove_animation(Playback->Slot);
                if (Playback->Original.is_valid()) Playback->Library->add_animation(Playback->Slot, Playback->Original);
            }
            Playback->Name = ""; Playback->Library.unref(); Playback->Original.unref(); Playback->Checked.unref();
        }
        if (Playback && Library->has_animation(Slot)) Playback->Original = Library->get_animation(Slot);
        if (Library->has_animation(Slot)) Library->remove_animation(Slot);
        if (Library->add_animation(Slot, Checked) != OK) return;
        if (Playback) { Playback->Library = Library; Playback->Slot = Slot; }
    }
    if (ObjectDB::get_instance(CharacterIdentity) != character || character->is_queued_for_deletion() ||
        ObjectDB::get_instance(PlayerIdentity) != ap || ap->is_queued_for_deletion()) return;
    if (Playback) { Playback->Name = anim_name; Playback->Checked = Checked; }
    Ref<Animation> a = ap->get_animation(StringName(anim_name));
    if (a.is_valid()) a->set_loop_mode(looped ? Animation::LOOP_LINEAR : Animation::LOOP_NONE);
    ap->set_speed_scale(speed);
    if (!ap->is_playing() || ap->get_current_animation() != StringName(anim_name))
        ap->play(StringName(anim_name));
}

class AnimationTrack : public Node {
    GDCLASS(AnimationTrack, Node);

public:
    struct LuaCallback { lua_State* main_L; int ref; bool active = true; };

    std::vector<LuaCallback> ended_cbs;
    std::vector<LuaCallback> stopped_cbs;

private:
    String            anim_name    = "";
    String            anim_id      = "";   // ruta del recurso (para replicar, 1.14.12)
    bool              looped       = false;
    float             speed        = 1.0f;
    float             weight       = 1.0f;
    bool              playing      = false;
    uint64_t AnimationPlayerIdentity = 0;

    AnimationPlayer* GetAnimationPlayer() const {
        AnimationPlayer* Player = Object::cast_to<AnimationPlayer>(ObjectDB::get_instance(AnimationPlayerIdentity));
        if (!Player || Player->is_queued_for_deletion()) return nullptr;
        if (GLExecutionDomain::IsClientExecution()) {
            if (!Player->has_animation(anim_name) || !GLPresentationAnimation(Player->get_animation(anim_name), Player->get_parent(), Player)) return nullptr;
            if (Player->is_playing() && !GLPresentationAnimation(Player->get_animation(Player->get_current_animation()), Player->get_parent(), Player)) return nullptr;
        }
        return Player;
    }

public:
    void set_anim_id(const String& id) { anim_id = id; }

private:
    // Replicación (1.14.12): al reproducir/parar una animación en MI personaje,
    // avisar al NetworkService para que los demás la vean en mi muñeco. Se
    // resuelve por ObjectID + call() para no depender de roblox_network.h.
    void _net_notify(bool play_flag) {
        if (!is_inside_tree() || is_queued_for_deletion() || !gl_net_service_id()) return;
        Object* ns = ObjectDB::get_instance(gl_net_service_id());
        if (!ns) return;
        Node* hum = get_parent();                       // AnimationTrack > Humanoid
        Node* character = hum ? hum->get_parent() : nullptr;
        if (!character) return;
        ns->call("net_anim_state", (Object*)character, anim_id, anim_name, speed, looped, play_flag);
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("_gl_disconnect", "ref"), &AnimationTrack::_gl_disconnect);
        ClassDB::bind_method(D_METHOD("play"),  &AnimationTrack::play);
        ClassDB::bind_method(D_METHOD("stop"),  &AnimationTrack::stop);
        ClassDB::bind_method(D_METHOD("is_playing"), &AnimationTrack::is_playing);
        ClassDB::bind_method(D_METHOD("set_looped", "v"),  &AnimationTrack::set_looped);
        ClassDB::bind_method(D_METHOD("get_looped"),       &AnimationTrack::get_looped);
        ClassDB::bind_method(D_METHOD("set_speed", "v"),   &AnimationTrack::set_speed);
        ClassDB::bind_method(D_METHOD("get_speed"),        &AnimationTrack::get_speed);
        ClassDB::bind_method(D_METHOD("set_weight", "v"),  &AnimationTrack::set_weight);
        ClassDB::bind_method(D_METHOD("get_weight"),       &AnimationTrack::get_weight);
        ClassDB::bind_method(D_METHOD("get_length"),       &AnimationTrack::get_length);
        ClassDB::bind_method(D_METHOD("get_time_position"), &AnimationTrack::get_time_position);
        ClassDB::bind_method(D_METHOD("adjust_speed", "v"), &AnimationTrack::adjust_speed);

        ADD_PROPERTY(PropertyInfo(Variant::BOOL,  "Looped"), "set_looped", "get_looped");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "Speed",  PROPERTY_HINT_RANGE, "0,10,0.01"), "set_speed", "get_speed");
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "WeightCurrent", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_weight", "get_weight");
        ADD_SIGNAL(MethodInfo("Ended"));
        ADD_SIGNAL(MethodInfo("Stopped", PropertyInfo(Variant::BOOL, "was_completed")));
    }

public:
    void setup(const String& name, AnimationPlayer* player) {
        anim_name   = name;
        AnimationPlayerIdentity = player ? static_cast<uint64_t>(player->get_instance_id()) : 0;
        if (player) player->connect("animation_finished",
            callable_mp(this, &AnimationTrack::_on_finished));
    }

    // Session initialization replays already-running local tracks after UID assignment.
    void ReplicateState() { if (is_playing()) _net_notify(true); }

    void play() {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player || anim_name.is_empty()) return;
        if (!anim_player->has_animation(StringName(anim_name))) return;
        if (GLExecutionDomain::IsClientExecution() && !GLPresentationAnimation(anim_player->get_animation(anim_name), anim_player->get_parent(), anim_player)) return;
        anim_player->set_speed_scale(speed);
        anim_player->play(StringName(anim_name));
        playing = true;
        _update_loop();
        _net_notify(true);
    }

    void stop() {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player) return;
        anim_player->stop();
        playing = false;
        _net_notify(false);
        auto Callbacks = GetCallbacks(stopped_cbs);
        emit_signal("Stopped", false);
        _fire_noarg(Callbacks);
    }

    bool is_playing() const {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player) return false;
        return anim_player->is_playing() && anim_player->get_current_animation() == StringName(anim_name);
    }

    void set_looped(bool v) {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (GLExecutionDomain::IsClientExecution() && !anim_player) return;
        looped = v;
        if (anim_player && !anim_name.is_empty()) _update_loop();
        if (is_playing()) _net_notify(true);
    }
    bool get_looped() const { return looped; }

    void set_speed(float v) {
        if (!Math::is_finite(v)) return;
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (GLExecutionDomain::IsClientExecution() && !anim_player) return;
        speed = Math::clamp(v, 0.0f, 20.0f);
        if (anim_player) anim_player->set_speed_scale(speed);
        if (is_playing()) _net_notify(true);
    }
    float get_speed() const { return speed; }

    void set_weight(float v) { weight = Math::clamp(v, 0.0f, 1.0f); }
    float get_weight() const { return weight; }

    void adjust_speed(float v) { set_speed(v); }

    float get_length() const {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player || anim_name.is_empty()) return 0.0f;
        Ref<Animation> a = anim_player->get_animation(StringName(anim_name));
        if (!a.is_valid()) return 0.0f;
        return (float)a->get_length();
    }

    float get_time_position() const {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player || !is_playing()) return 0.0f;
        return (float)anim_player->get_current_animation_position();
    }

    void add_ended_cb(lua_State* L, int ref)   { ended_cbs.push_back({L,ref,true}); }
    void add_stopped_cb(lua_State* L, int ref) { stopped_cbs.push_back({L,ref,true}); }

    void remove_callbacks_for_state(lua_State* L) {
        for (auto& cb : ended_cbs)   if (cb.main_L==L) cb.active=false;
        for (auto& cb : stopped_cbs) if (cb.main_L==L) cb.active=false;
    }
    void _gl_disconnect(int ref) {
        for (auto& cb : ended_cbs)   if (cb.ref==ref) cb.active=false;
        for (auto& cb : stopped_cbs) if (cb.ref==ref) cb.active=false;
    }

private:
    void _update_loop() {
        AnimationPlayer* anim_player = GetAnimationPlayer();
        if (!anim_player || anim_name.is_empty()) return;
        Ref<Animation> a = anim_player->get_animation(StringName(anim_name));
        if (!a.is_valid()) return;
        a->set_loop_mode(looped ? Animation::LOOP_LINEAR : Animation::LOOP_NONE);
    }

    void _on_finished(StringName name) {
        if (name != StringName(anim_name) || !playing) return;
        playing = false;
        _net_notify(false);
        auto Ended = GetCallbacks(ended_cbs);
        auto Stopped = GetCallbacks(stopped_cbs);
        uint64_t Identity = static_cast<uint64_t>(get_instance_id());
        emit_signal("Ended");
        AnimationTrack* Track = Object::cast_to<AnimationTrack>(ObjectDB::get_instance(Identity));
        if (Track && !Track->is_queued_for_deletion()) Track->emit_signal("Stopped", true);
        _fire_noarg(Ended);
        _fire_noarg(Stopped);
    }

    static std::vector<LuaCallback> GetCallbacks(std::vector<LuaCallback>& List) {
        // Reap retired entries in the owner before taking the dispatch snapshot.
        // The snapshot survives callbacks that queue or destroy the track.
        for (size_t Index = List.size(); Index > 0; --Index)
            if (!List[Index - 1].active || !GLReferenceAlive(List[Index - 1].main_L, List[Index - 1].ref))
                List.erase(List.begin() + Index - 1);
        return List;
    }

    static void _fire_noarg(const std::vector<LuaCallback>& list) {
        for (int i=(int)list.size()-1; i>=0; --i) {
            const auto& cb=list[i];
            if (!cb.active || !GLReferenceAlive(cb.main_L, cb.ref)) continue;
            GLDispatch(cb.ref, [](lua_State*) -> int { return 0; });
        }
    }
};

// ────────────────────────────────────────────────────────────────────
//  AnimationObject — animation object referenceable from Luau
//  Usage: local anim = Instance.new("Animation")
//         anim.AnimationId = "res://anims/idle.anim"
//         humanoid:LoadAnimation(anim)
////
//  AnimationObject — objeto de animación referenciable desde Luau
//  Uso: local anim = Instance.new("Animation")
//       anim.AnimationId = "res://anims/idle.anim"
//       humanoid:LoadAnimation(anim)
// ────────────────────────────────────────────────────────────────────
class AnimationObject : public Node {
    GDCLASS(AnimationObject, Node);

    String anim_id   = "";
    String anim_name = "default";

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_animation_id", "id"), &AnimationObject::set_animation_id);
        ClassDB::bind_method(D_METHOD("get_animation_id"),       &AnimationObject::get_animation_id);
        ClassDB::bind_method(D_METHOD("set_anim_name", "n"),    &AnimationObject::set_anim_name);
        ClassDB::bind_method(D_METHOD("get_anim_name"),          &AnimationObject::get_anim_name);
        ADD_PROPERTY(PropertyInfo(Variant::STRING, "AnimationId"), "set_animation_id", "get_animation_id");
        ADD_PROPERTY(PropertyInfo(Variant::STRING, "Name"),        "set_anim_name",    "get_anim_name");
    }

public:
    void set_animation_id(const String& id)  { anim_id = id; }
    String get_animation_id() const          { return anim_id; }
    void set_anim_name(const String& n)      { anim_name = n; }
    String get_anim_name() const             { return anim_name; }
};

#endif // ROBLOX_ANIMATION_H
