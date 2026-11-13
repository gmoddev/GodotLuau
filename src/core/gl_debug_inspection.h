#pragma once
#include <cstddef>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
class GLDebugger;
struct lua_State;

GLDebugger* GLGetSuspendedDebugger();
godot::Dictionary GLDebugVariables(int Level, int MaxItems, int MaxDepth, bool Upvalues);
godot::Dictionary GLDebugContext();
godot::Dictionary GLDebugEvaluate(int Level, const godot::String& Expression);
godot::Variant GLDebugCopyValue(lua_State* Thread, int Index, int MaxItems = 32, int MaxDepth = 3);
godot::Dictionary GLDebugSceneHandle(lua_State* Thread, int Index);
bool GLDebugText(const char* Value, size_t Length, size_t Maximum, godot::String& Result);
