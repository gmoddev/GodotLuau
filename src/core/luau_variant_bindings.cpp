#include "luau_variant_bindings.h"
#include "luau_value_bindings.h"

#include "lua.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cstdint>

using namespace godot;

bool gl_luau_to_variant(lua_State* L, int idx, Variant& out) {
    switch (lua_type(L, idx)) {
        case LUA_TNUMBER:  out = (double)lua_tonumber(L, idx); return true;
        case LUA_TBOOLEAN: out = (bool)(lua_toboolean(L, idx) != 0); return true;
        case LUA_TSTRING:  out = String(lua_tostring(L, idx)); return true;
        case LUA_TUSERDATA:
            if (LuauVector3* v = check_vector3(L, idx)) { out = Vector3(v->x, v->y, v->z); return true; }
            if (LuauColor3*  c = check_color3(L, idx))  { out = Color(c->r, c->g, c->b);   return true; }
            return false;
        default: return false;
    }
}
bool gl_variant_to_luau(lua_State* L, const Variant& v) {
    switch (v.get_type()) {
        case Variant::BOOL:    lua_pushboolean(L, (bool)v);              return true;
        case Variant::INT:     lua_pushnumber(L, (double)(int64_t)v);    return true;
        case Variant::FLOAT:   lua_pushnumber(L, (double)v);             return true;
        case Variant::STRING:  { String s = v; lua_pushstring(L, s.utf8().get_data()); return true; }
        case Variant::VECTOR3: { Vector3 q = v; push_vector3(L, q.x, q.y, q.z); return true; }
        case Variant::COLOR:   { Color q = v; push_color3(L, q.r, q.g, q.b);    return true; }
        default: return false;
    }
}
