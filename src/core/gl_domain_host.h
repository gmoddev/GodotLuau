#ifndef GL_DOMAIN_HOST_H
#define GL_DOMAIN_HOST_H

#include "gl_execution_domain.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/variant/string.hpp>
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
    std::vector<GLChildWait> ChildWaits;
    std::vector<GLInvokeWait> InvokeWaits;
    void InvalidateOwner(lua_State* Anchor);
    void InvalidateThread(lua_State* Thread);
    GLExecutionDomain* WaitingDomain(lua_State* Thread) const;

protected:
    static void _bind_methods() {}
    void _notification(int What);

public:
    ~GLDomainHost();
    GLExecutionDomain& GetDomain(GLDomainKind Kind);
    bool ClaimInitialization(GLDomainKind Kind);
    void WaitForChild(lua_State* Thread, uint64_t Parent, const godot::String& Name, double Timeout, int Reference);
    void WaitForInvoke(lua_State* Thread, int64_t CallId, double Timeout, int Reference);
    void InvalidateModule(uint64_t NativeId);
    void Shutdown();
    void _process(double Delta) override;
};

GLDomainHost* GLGetDomainHost(godot::SceneTree* Tree = nullptr);
bool GLDomainAllowed(GLDomainKind Kind);

#endif
