#ifndef GL_INPUT_ACTIONS_H
#define GL_INPUT_ACTIONS_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "gl_input_graph.h"
#include "lua.h"

using namespace godot;
class InputService;

// Configuration is serialized; device admission, callbacks and owner guards are
// never serialized or duplicated. Only direct Service/Context/Action/Binding
// chains participate in the disposable graph.
class InputDefinition : public Node {
    GDCLASS(InputDefinition, Node);
    Dictionary Configuration;
    uint64_t Revision = 1, PreviousService = 0;
protected:
    static void _bind_methods();
    void _notification(int What);
    void Define(const char* Key, const Variant& Value) { Configuration[Key] = Value; }
    virtual bool Valid(const String& Key, const Variant& Value) const;
public:
    InputDefinition();
    bool Configure(const Dictionary& Options);
    void SetConfiguration(const Dictionary& Options) { Configure(Options); }
    Dictionary GetConfiguration() const { return Configuration.duplicate(true); }
    Variant GetOption(const String& Key) const { return Configuration.get(Key, Variant()); }
    bool HasOption(const String& Key) const { return Configuration.has(Key); }
    uint64_t GetRevision() const { return Revision; }
    void MarkDirty();
};

class InputContext : public InputDefinition {
    GDCLASS(InputContext, InputDefinition);
    int OwnerGuard = 0;
protected:
    static void _bind_methods() {}
public:
    InputContext();
    ~InputContext();
    void AdoptOwner(lua_State* Thread);
    bool OwnerAlive() const;
};

class InputAction : public InputDefinition {
    GDCLASS(InputAction, InputDefinition);
    struct Callback { int Reference=0, Signal=0; bool Once=false; };
    std::vector<Callback> Callbacks;
    GLInputGraph::Value Current;
protected:
    static void _bind_methods();
public:
    InputAction();
    ~InputAction();
    GLInputGraph::Value GetCurrent() const { return Current; }
    Variant GetValue() const;
    void Commit(GLInputGraph::Value Value) { Current=Value; }
    int Connect(lua_State* Thread, int Index, int Signal, bool Once);
    void _gl_disconnect(int Reference);
    void Publish(const GLInputGraph::Transition& Change);
};

class InputBinding : public InputDefinition {
    GDCLASS(InputBinding, InputDefinition);
protected:
    static void _bind_methods() {}
public:
    InputBinding();
};

class InputService : public Node {
    GDCLASS(InputService, Node);
    GLInputGraph Graph;
    bool Dirty=true, Publishing=false, Active=false;
    uint64_t ViewportId=0, AdapterId=0, Rejections=0;
    void Compile();
    void Publish();
protected:
    static void _bind_methods();
    void _notification(int What);
public:
    InputService();
    void _ready() override;
    void _process(double Delta) override;
    void MarkDirty() { Dirty=true; }
    void Deliver(uint64_t Adapter, const Ref<InputEvent>& Event, bool Processed);
    void Cancel(const String& Reason);
    void DeviceChanged(int Device, bool Connected);
    Dictionary GetDiagnostics() const;
};

bool GLInputAllowed();
bool GLInputIndex(lua_State* Thread, Node* Target, const char* Key);
bool GLInputWrite(lua_State* Thread, Node* Target, const char* Key);
void GLInputAdoptOwner(lua_State* Thread, Node* Target);
void GLInputDeliver(Viewport* View, uint64_t Adapter, const Ref<InputEvent>& Event, bool Processed);
void GLInputCancel(Viewport* View, const char* Reason);
// Reuses the bridge's existing owner-aware connection object.
void GLInputPushConnection(lua_State* Thread, Node* Target, int Reference);
#endif
