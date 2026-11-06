#ifndef LUAU_INSTANCE_REFLECTION_H
#define LUAU_INSTANCE_REFLECTION_H

struct lua_State;
namespace godot { class Object; class String; }

// Internal synchronous adapter. The caller resolves ObjectID and supplies a live
// object and a checked key; no object, Lua state, callback or value is retained.
// Membership follows the existing Godot property list, including read-only entries.
bool HasLuauInstanceProperty(godot::Object* Object, const godot::String& Name);
// Only _gl_bridge objects participate. Success pushes one value; false pushes none
// and leaves child/alias/error fallback to the caller. Existing metatables required.
bool PushLuauInstanceProperty(lua_State* L, godot::Object* Object, const char* Key);
// Value is at Lua index 3. Keeps native-property/metadata/Offset precedence and
// ignored unsupported writes; Offset lookup may run a Lua metamethod or raise.
void WriteLuauInstanceProperty(lua_State* L, godot::Object* Object, const char* Key);

#endif // LUAU_INSTANCE_REFLECTION_H
