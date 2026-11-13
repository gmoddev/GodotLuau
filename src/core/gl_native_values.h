#ifndef GL_NATIVE_VALUES_H
#define GL_NATIVE_VALUES_H
#include "gl_native_registry.h"
#include <godot_cpp/variant/variant.hpp>
struct lua_State;

// Pure values only: no native Object, Resource, RID, Callable or Signal capability.
// Object/resource conversion stays at the SceneScope authority boundary.
bool GLReadNativeValue(lua_State* Thread, const GLNative::Property& Item, int Index, godot::Variant& Result);
bool GLValidNativeValue(const GLNative::Property& Item, const godot::Variant& Value);
bool GLPushNativeValue(lua_State* Thread, const godot::Variant& Value);
const char* GLNativeValueName(GLNative::Kind Type);
GLNative::Kind GLNativeValueKind(const char* Name);
#endif
