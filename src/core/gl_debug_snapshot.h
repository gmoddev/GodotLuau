#pragma once
#include <godot_cpp/variant/dictionary.hpp>
struct lua_State;
// Error-time copies only. Never retains a VM, object capability or registry ref.
godot::Dictionary GLCaptureErrorSnapshot(lua_State* Thread);
