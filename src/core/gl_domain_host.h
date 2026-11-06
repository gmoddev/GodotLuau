#ifndef GL_DOMAIN_HOST_H
#define GL_DOMAIN_HOST_H

#include "gl_execution_domain.h"
#include "gl_http.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <array>

class GLDomainHost : public godot::Node {
    GDCLASS(GLDomainHost, godot::Node);
    struct GLChildWait {
        lua_State* Thread;
        lua_State* Anchor;
        uint64_t Parent;
        godot::String Name;
        double Timeout;
        double Elapsed;
        int Reference;
        godot::String Trace;
        bool Warned = false;
    };
    struct GLInvokeWait {
        lua_State* Thread;
        lua_State* Anchor;
        int64_t CallId;
        double Timeout;
        double Elapsed;
        int Reference;
        bool Warned = false;
    };
    std::array<std::unique_ptr<GLExecutionDomain>, 2> Domains;
    std::array<bool, 2> Initialized = {false, false};
    std::unique_ptr<GLHttpManager> Http;
    std::vector<GLChildWait> ChildWaits;
    std::vector<GLInvokeWait> InvokeWaits;
    struct GLChildConnection {
        lua_State* Anchor;
        uint64_t Target;
        godot::StringName Signal;
        godot::Callable Handler;
        int Reference;
    };
    std::vector<GLChildConnection> ChildConnections;
    void InvalidateOwner(lua_State* Anchor);
    void InvalidateThread(lua_State* Thread);
    GLExecutionDomain* WaitingDomain(lua_State* Thread) const;

protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("GetResourceStats", "client"), &GLDomainHost::GetResourceStats);
#ifdef GL_RUNTIME_TESTS
        godot::ClassDB::bind_method(godot::D_METHOD("_gl_test_reset_domain", "client"), &GLDomainHost::ResetDomainForTests);
#endif
    }
    void _notification(int What);

public:
    ~GLDomainHost();
    GLExecutionDomain& GetDomain(GLDomainKind Kind);
    godot::Dictionary GetResourceStats(bool Client) const;
    bool ClaimInitialization(GLDomainKind Kind);
    void InstallHttp(lua_State* Thread,GLExecutionDomain& Domain);
    int BeginHttp(lua_State* Thread,GLExecutionDomain* Domain,int Operation);
    bool InterruptHttp(lua_State* Thread);
    bool ConnectChild(lua_State* Thread, godot::Node* Target, godot::Node* Receiver, bool Added, int Reference);
    void DisconnectChild(int Reference);
#ifdef GL_RUNTIME_TESTS
    // Fixture calls only outside Lua after retiring all executable callers.
    void ResetDomainForTests(bool Client);
#endif
    void WaitForChild(lua_State* Thread, uint64_t Parent, const godot::String& Name, double Timeout, int Reference);
    void WaitForInvoke(lua_State* Thread, int64_t CallId, double Timeout, int Reference);
    void InvalidateModule(uint64_t NativeId);
    void Shutdown();
    void _process(double Delta) override;
};

GLDomainHost* GLGetDomainHost(godot::SceneTree* Tree = nullptr);
bool GLDomainAllowed(GLDomainKind Kind);

#endif
