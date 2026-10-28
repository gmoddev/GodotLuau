#include "luau_value_bindings.h"

#include "lua.h"
#include "lualib.h"

#include <cmath>
#include <cstdio>
#include <cstring>

float LuauVector3::magnitude() const { return std::sqrt(x*x + y*y + z*z); }
LuauVector3 LuauVector3::unit() const {
    float m = magnitude();
    if (m < 0.0001f) return {0.0f, 0.0f, 0.0f};
    return {x/m, y/m, z/m};
}
LuauVector3 LuauVector3::lerp(const LuauVector3& to, float alpha) const {
    return {x + (to.x - x)*alpha, y + (to.y - y)*alpha, z + (to.z - z)*alpha};
}
float LuauVector3::dot(const LuauVector3& b) const { return x*b.x + y*b.y + z*b.z; }
LuauVector3 LuauVector3::cross(const LuauVector3& b) const {
    return {y*b.z - z*b.y, z*b.x - x*b.z, x*b.y - y*b.x};
}

LuauVector3* push_vector3(lua_State* L, float x, float y, float z) {
    LuauVector3* v = (LuauVector3*)lua_newuserdata(L, sizeof(LuauVector3));
    v->x = x; v->y = y; v->z = z;
    luaL_getmetatable(L, "Vector3");
    lua_setmetatable(L, -2);
    return v;
}

LuauColor3* push_color3(lua_State* L, float r, float g, float b) {
    LuauColor3* c = (LuauColor3*)lua_newuserdata(L, sizeof(LuauColor3));
    c->r = r; c->g = g; c->b = b;
    luaL_getmetatable(L, "Color3");
    lua_setmetatable(L, -2);
    return c;
}

bool _gl_has_metatable(lua_State* L, int idx, const char* mt) {
    if (lua_type(L, idx) != LUA_TUSERDATA) return false;
    if (!lua_getmetatable(L, idx)) return false;
    luaL_getmetatable(L, mt);
    bool ok = lua_rawequal(L, -1, -2);
    lua_pop(L, 2);
    return ok;
}
LuauVector3* check_vector3(lua_State* L, int idx) {
    return _gl_has_metatable(L, idx, "Vector3") ? (LuauVector3*)lua_touserdata(L, idx) : nullptr;
}
LuauColor3* check_color3(lua_State* L, int idx) {
    return _gl_has_metatable(L, idx, "Color3") ? (LuauColor3*)lua_touserdata(L, idx) : nullptr;
}

static int godot_vector3_new(lua_State* L) {
    float x = (float)luaL_optnumber(L, 1, 0.0);
    float y = (float)luaL_optnumber(L, 2, 0.0);
    float z = (float)luaL_optnumber(L, 3, 0.0);
    push_vector3(L, x, y, z);
    return 1;
}

static int godot_vector3_index(lua_State* L) {
    LuauVector3* vec = check_vector3(L, 1);
    const char* key  = luaL_checkstring(L, 2);
    if (!vec) { lua_pushnil(L); return 1; }

    if (strcmp(key, "X") == 0 || strcmp(key, "x") == 0) { lua_pushnumber(L, vec->x); return 1; }
    if (strcmp(key, "Y") == 0 || strcmp(key, "y") == 0) { lua_pushnumber(L, vec->y); return 1; }
    if (strcmp(key, "Z") == 0 || strcmp(key, "z") == 0) { lua_pushnumber(L, vec->z); return 1; }

    if (strcmp(key, "Magnitude") == 0) { lua_pushnumber(L, vec->magnitude()); return 1; }

    if (strcmp(key, "Unit") == 0) {
        LuauVector3 u = vec->unit();
        push_vector3(L, u.x, u.y, u.z);
        return 1;
    }

    if (strcmp(key, "Lerp") == 0) {
        lua_pushlightuserdata(L, vec);
        lua_pushcclosure(L, [](lua_State* pL) -> int {
            LuauVector3* self = (LuauVector3*)lua_touserdata(pL, lua_upvalueindex(1));
            LuauVector3* goal = check_vector3(pL, 1);
            float alpha = (float)luaL_checknumber(pL, 2);
            if (!self || !goal) { lua_pushnil(pL); return 1; }
            LuauVector3 r = self->lerp(*goal, alpha);
            push_vector3(pL, r.x, r.y, r.z);
            return 1;
        }, "Lerp", 1);
        return 1;
    }

    if (strcmp(key, "Dot") == 0) {
        lua_pushlightuserdata(L, vec);
        lua_pushcclosure(L, [](lua_State* pL) -> int {
            LuauVector3* self = (LuauVector3*)lua_touserdata(pL, lua_upvalueindex(1));
            LuauVector3* other = check_vector3(pL, 1);
            if (!self || !other) { lua_pushnumber(pL, 0); return 1; }
            lua_pushnumber(pL, self->dot(*other));
            return 1;
        }, "Dot", 1);
        return 1;
    }

    if (strcmp(key, "Cross") == 0) {
        lua_pushlightuserdata(L, vec);
        lua_pushcclosure(L, [](lua_State* pL) -> int {
            LuauVector3* self = (LuauVector3*)lua_touserdata(pL, lua_upvalueindex(1));
            LuauVector3* other = check_vector3(pL, 1);
            if (!self || !other) { lua_pushnil(pL); return 1; }
            LuauVector3 c = self->cross(*other);
            push_vector3(pL, c.x, c.y, c.z);
            return 1;
        }, "Cross", 1);
        return 1;
    }

    lua_pushnil(L); return 1;
}

static int godot_vector3_add(lua_State* L) {
    LuauVector3* a = check_vector3(L, 1);
    LuauVector3* b = check_vector3(L, 2);
    if (a && b) { push_vector3(L, a->x+b->x, a->y+b->y, a->z+b->z); return 1; }
    lua_pushnil(L); return 1;
}

static int godot_vector3_sub(lua_State* L) {
    LuauVector3* a = check_vector3(L, 1);
    LuauVector3* b = check_vector3(L, 2);
    if (a && b) { push_vector3(L, a->x-b->x, a->y-b->y, a->z-b->z); return 1; }
    lua_pushnil(L); return 1;
}

static int godot_vector3_mul(lua_State* L) {
    if (lua_isnumber(L, 1)) {
        float s = (float)lua_tonumber(L, 1);
        LuauVector3* v = check_vector3(L, 2);
        if (v) { push_vector3(L, v->x*s, v->y*s, v->z*s); return 1; }
    } else {
        LuauVector3* v = check_vector3(L, 1);
        if (lua_isnumber(L, 2)) {
            float s = (float)lua_tonumber(L, 2);
            if (v) { push_vector3(L, v->x*s, v->y*s, v->z*s); return 1; }
        } else {
            LuauVector3* b = check_vector3(L, 2);
            if (v && b) { push_vector3(L, v->x*b->x, v->y*b->y, v->z*b->z); return 1; }
        }
    }
    lua_pushnil(L); return 1;
}

static int godot_vector3_unm(lua_State* L) {
    LuauVector3* v = check_vector3(L, 1);
    if (v) { push_vector3(L, -v->x, -v->y, -v->z); return 1; }
    lua_pushnil(L); return 1;
}

// Vector3 / number  ó  Vector3 / Vector3 (componente a componente), como Roblox
static int godot_vector3_div(lua_State* L) {
    LuauVector3* a = check_vector3(L, 1);
    if (a && lua_isnumber(L, 2)) {
        float s = (float)lua_tonumber(L, 2);
        push_vector3(L, a->x/s, a->y/s, a->z/s); return 1;
    }
    LuauVector3* b = check_vector3(L, 2);
    if (a && b) { push_vector3(L, a->x/b->x, a->y/b->y, a->z/b->z); return 1; }
    lua_pushnil(L); return 1;
}

// Vector3 == Vector3 por valor (sin esto, == comparaba identidad de userdata)
static int godot_vector3_eq(lua_State* L) {
    LuauVector3* a = check_vector3(L, 1);
    LuauVector3* b = check_vector3(L, 2);
    lua_pushboolean(L, (a && b && a->x == b->x && a->y == b->y && a->z == b->z) ? 1 : 0);
    return 1;
}

static int godot_vector3_tostring(lua_State* L) {
    LuauVector3* v = check_vector3(L, 1);
    if (v) {
        char buf[64];
        snprintf(buf, sizeof(buf), "%.3f, %.3f, %.3f", v->x, v->y, v->z);
        lua_pushstring(L, buf);
        return 1;
    }
    lua_pushstring(L, "Vector3(nil)"); return 1;
}

// ════════════════════════════════════════════════════════════════════
//  Color3
// ════════════════════════════════════════════════════════════════════

static int godot_color3_new(lua_State* L) {
    float r = (float)luaL_optnumber(L, 1, 0.0);
    float g = (float)luaL_optnumber(L, 2, 0.0);
    float b = (float)luaL_optnumber(L, 3, 0.0);
    push_color3(L, r, g, b);
    return 1;
}

static int godot_color3_from_rgb(lua_State* L) {
    float r = (float)luaL_optnumber(L, 1, 0.0) / 255.0f;
    float g = (float)luaL_optnumber(L, 2, 0.0) / 255.0f;
    float b = (float)luaL_optnumber(L, 3, 0.0) / 255.0f;
    push_color3(L, r, g, b);
    return 1;
}

static int godot_color3_index(lua_State* L) {
    LuauColor3* col = check_color3(L, 1);
    const char* key = luaL_checkstring(L, 2);
    if (!col) { lua_pushnil(L); return 1; }
    if (strcmp(key, "R") == 0 || strcmp(key, "r") == 0) { lua_pushnumber(L, col->r); return 1; }
    if (strcmp(key, "G") == 0 || strcmp(key, "g") == 0) { lua_pushnumber(L, col->g); return 1; }
    if (strcmp(key, "B") == 0 || strcmp(key, "b") == 0) { lua_pushnumber(L, col->b); return 1; }
    lua_pushnil(L); return 1;
}

void RegisterLuauValueMetatables(lua_State* L) {
    luaL_newmetatable(L, "Vector3");
    lua_pushcfunction(L, godot_vector3_index, "__index");   lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, godot_vector3_add,   "__add");     lua_setfield(L, -2, "__add");
    lua_pushcfunction(L, godot_vector3_sub,   "__sub");     lua_setfield(L, -2, "__sub");
    lua_pushcfunction(L, godot_vector3_mul,   "__mul");     lua_setfield(L, -2, "__mul");
    lua_pushcfunction(L, godot_vector3_div,   "__div");     lua_setfield(L, -2, "__div");
    lua_pushcfunction(L, godot_vector3_unm,   "__unm");     lua_setfield(L, -2, "__unm");
    lua_pushcfunction(L, godot_vector3_eq,    "__eq");      lua_setfield(L, -2, "__eq");
    lua_pushcfunction(L, godot_vector3_tostring, "__tostring"); lua_setfield(L, -2, "__tostring");
    lua_pop(L, 1);

    luaL_newmetatable(L, "Color3");
    lua_pushcfunction(L, godot_color3_index, "__index"); lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
}

void RegisterLuauValueGlobals(lua_State* L) {
    // ── Vector3 ───────────────────────────────────────────────────────────
    lua_newtable(L);
    lua_pushcfunction(L, godot_vector3_new,  "new");    lua_setfield(L, -2, "new");
    {
        LuauVector3* z = (LuauVector3*)lua_newuserdata(L, sizeof(LuauVector3));
        z->x = 0; z->y = 0; z->z = 0;
        luaL_getmetatable(L, "Vector3"); lua_setmetatable(L, -2);
        lua_setfield(L, -2, "zero");

        LuauVector3* o = (LuauVector3*)lua_newuserdata(L, sizeof(LuauVector3));
        o->x = 1; o->y = 1; o->z = 1;
        luaL_getmetatable(L, "Vector3"); lua_setmetatable(L, -2);
        lua_setfield(L, -2, "one");
    }
    lua_setglobal(L, "Vector3");

    // ── Color3 ────────────────────────────────────────────────────────────
    lua_newtable(L);
    lua_pushcfunction(L, godot_color3_new,      "new");     lua_setfield(L, -2, "new");
    lua_pushcfunction(L, godot_color3_from_rgb, "fromRGB"); lua_setfield(L, -2, "fromRGB");
    lua_setglobal(L, "Color3");
}
