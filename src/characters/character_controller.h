#ifndef GL_CHARACTER_CONTROLLER_H
#define GL_CHARACTER_CONTROLLER_H
#include <godot_cpp/classes/node.hpp>
struct lua_State;
bool GLCharacterControllerIndex(lua_State* Thread, godot::Node* Target, const char* Key);
bool GLCharacterControllerWrite(lua_State* Thread, godot::Node* Target, const char* Key);
#endif

