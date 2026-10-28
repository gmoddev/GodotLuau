#ifndef LUAU_VALUE_BINDINGS_H
#define LUAU_VALUE_BINDINGS_H

struct lua_State;

// Native value userdata layout is shared with the Instance/property bridge.
// VM allocation/collection owns these values; this layer owns no domain state.
struct LuauVector3 {
    float x, y, z;
    float magnitude() const;
    LuauVector3 unit() const;
    LuauVector3 lerp(const LuauVector3& to, float alpha) const;
    float dot(const LuauVector3& b) const;
    LuauVector3 cross(const LuauVector3& b) const;
};

struct LuauColor3 { float r, g, b; };

// Existing native bridge names and stack contracts are preserved.
LuauVector3* push_vector3(lua_State* L, float x, float y, float z);
LuauColor3* push_color3(lua_State* L, float r, float g, float b);
bool _gl_has_metatable(lua_State* L, int idx, const char* mt);
LuauVector3* check_vector3(lua_State* L, int idx);
LuauColor3* check_color3(lua_State* L, int idx);

// Called at the existing per-domain initialization points; stack balanced.
// Metatables must precede globals; no process-global registration state exists.
void RegisterLuauValueMetatables(lua_State* L);
void RegisterLuauValueGlobals(lua_State* L);

#endif // LUAU_VALUE_BINDINGS_H
