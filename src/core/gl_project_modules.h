#ifndef GL_PROJECT_MODULES_H
#define GL_PROJECT_MODULES_H
#include "gl_execution_domain.h"
#include <godot_cpp/classes/resource.hpp>
#include <unordered_map>

// Per-domain strong resource lifetime; existing GLExecutionDomain owns evaluation,
// cycles, cached results, caller waits and revision invalidation.
class GLProjectModules {
    std::unordered_map<std::string,godot::Ref<godot::Resource>> Resources;
public:
    bool Resolve(lua_State* Thread,int Argument,GLModuleSource& Module);
    bool Load(GLModuleSource& Module);
    void Retire(GLExecutionDomain& Domain);
};
#endif
