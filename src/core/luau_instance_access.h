#ifndef LUAU_INSTANCE_ACCESS_H
#define LUAU_INSTANCE_ACCESS_H

struct lua_State;
namespace godot { class Node; }

// Push one GodotObject userdata using the existing ObjectID representation and
// domain metatable, or nil for a null target. The domain must already have its
// GodotObject metatable installed. No native object or VM ownership is retained.
void PushLuauInstance(lua_State* Thread, godot::Node* Target);

#endif // LUAU_INSTANCE_ACCESS_H
