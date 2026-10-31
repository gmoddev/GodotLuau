#ifndef GL_HTTP_H
#define GL_HTTP_H
#include <memory>
#include <cstddef>
#include <cstdint>
struct lua_State;
class GLExecutionDomain;
class GLDomainHost;

class GLHttpManager {
    struct State;
    std::unique_ptr<State> Data;
public:
    explicit GLHttpManager(GLDomainHost& Host);
    ~GLHttpManager();
    static void Install(lua_State* Thread,GLExecutionDomain& Domain,uint64_t Host);
    int Begin(lua_State* Thread,GLExecutionDomain* Domain,int Operation);
    bool Available(lua_State* Thread,GLExecutionDomain* Domain) const;
    void Tick();
    void CancelOwner(lua_State* Anchor);
    void CancelThread(lua_State* Thread);
    bool Interrupt(lua_State* Thread);
    void Shutdown();
    size_t Pending(bool Client) const;
    size_t Peak() const;
};
void RegisterGLHttpTypes();
#endif
