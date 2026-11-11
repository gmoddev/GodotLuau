#ifndef GL_SCENE_AUTHORING_H
#define GL_SCENE_AUTHORING_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <memory>
#include <vector>
struct lua_State;

struct GLSceneResource {
    godot::Ref<godot::Resource> Value;
    uint64_t Scope = 0;
    bool ReadOnly = false;
};

// Ownership bookkeeping only. ObjectDB remains the sole native identity resolver.
class SceneScope : public godot::Node3D {
    GDCLASS(SceneScope, godot::Node3D)
public:
    struct Subscription {
        uint64_t Source;
        godot::StringName Signal;
        godot::Callable Handler;
        int Reference;
    };
    lua_State* Anchor = nullptr; // equality only; never dereferenced after retirement
    int Guard = 0;
    bool Retired = false;
    std::vector<uint64_t> Nodes;
    std::vector<std::weak_ptr<GLSceneResource>> Resources;
    std::vector<Subscription> Subscriptions;
    SceneScope();
    ~SceneScope();
    bool CanUse(lua_State* Thread) const;
    void Retire(bool Delete = true);
    void Disconnect(int Reference);
    void OnSignal(int Reference, int Signature, const std::vector<godot::Variant>& Arguments);
protected:
    static void _bind_methods();
    void _notification(int What);
};

void GLRegisterScene(lua_State* Thread);
void GLRetireScenes(lua_State* Anchor);
bool GLSceneLocal(godot::Node* Target);
bool GLSceneMutation(lua_State* Thread, godot::Node* Target, bool Clone = false);
bool GLSceneIndex(lua_State* Thread, godot::Node* Target, const char* Key);
bool GLSceneWrite(lua_State* Thread, godot::Node* Target, const char* Key);
#endif
