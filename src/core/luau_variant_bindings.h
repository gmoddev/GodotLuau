#ifndef LUAU_VARIANT_BINDINGS_H
#define LUAU_VARIANT_BINDINGS_H

struct lua_State;
namespace godot { class Variant; }

// Existing scalar/Vector3/Color3 conversion contract; no Instance/collection
// conversion or property dispatch. No VM, domain or native object is retained.
// Lua -> Variant leaves the Lua stack unchanged; false leaves Output unchanged.
bool gl_luau_to_variant(lua_State* L, int Index, godot::Variant& Output);
// Variant -> Lua pushes one value on success, none on false. Value metatables
// must already be initialized by the caller's existing per-domain setup.
bool gl_variant_to_luau(lua_State* L, const godot::Variant& Value);

#endif // LUAU_VARIANT_BINDINGS_H
