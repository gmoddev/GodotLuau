#ifndef GL_DATASTORE_H
#define GL_DATASTORE_H
#include <memory>
#include <string>
#include <cstddef>
struct lua_State;
class GLExecutionDomain;
int GLDataStoreEncode(lua_State* Thread);
int GLDataStoreDecode(lua_State* Thread);
class GLDataStoreManager {
    struct State;
    std::unique_ptr<State> Data;
public:
    GLDataStoreManager();
    ~GLDataStoreManager();
    int Begin(lua_State* Thread,GLExecutionDomain* Domain,const std::string& Root,const std::string& Leaf,int Operation,bool Exists,const std::string& Expected,const std::string& Value);
    void Tick();
    void CancelOwner(lua_State* Anchor);
    void CancelThread(lua_State* Thread);
    bool Interrupt(lua_State* Thread);
    void CancelAll();
    size_t Pending() const;
    size_t Peak() const;
    static void StopAll();
    static void DrainRetired();
};
#endif
