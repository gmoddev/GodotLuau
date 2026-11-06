#include "luau_instance_reflection.h"
#include "luau_variant_bindings.h"

#include "lua.h"
#include "lualib.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

bool HasLuauInstanceProperty(Object* o, const String& pname) {
    if (!o) return false;
    TypedArray<Dictionary> pl = o->get_property_list();
    for (int i = 0; i < pl.size(); i++) {
        Dictionary d = pl[i];
        if (String(d.get("name", String())) == pname) return true;
    }
    return false;
}

bool PushLuauInstanceProperty(lua_State* L, Object* n, const char* key) {
    if (n->has_meta("_gl_bridge")) {
        if (HasLuauInstanceProperty(n, String(key))) {
            Variant gv = n->get(String(key));
            if (gl_variant_to_luau(L, gv)) return true;
        }
        String _mk = String("_glp_") + String(key);
        if (n->has_meta(_mk) && gl_variant_to_luau(L, n->get_meta(_mk))) return true;
    }
    return false;
}

void WriteLuauInstanceProperty(lua_State* L, Object* n, const char* key) {
    if (String(key)=="Modo_Roblox_Studio")
        luaL_error(L,"[Runtime:Capabilities] Editor filesystem property denied");
    if (n->has_meta("_gl_bridge")) {
        Variant gv;
        if (gl_luau_to_variant(L, 3, gv)) {
            if (HasLuauInstanceProperty(n, String(key))) n->set(String(key), gv);
            else n->set_meta(String("_glp_") + String(key), gv);
        } else if (lua_istable(L, 3)) {
            // UDim / UDim2 → usar Offset (p.ej. CornerRadius, Padding numéricos)
            lua_getfield(L, 3, "Offset");
            if (lua_isnumber(L, -1)) {
                int off = (int)lua_tonumber(L, -1);
                if (HasLuauInstanceProperty(n, String(key))) n->set(String(key), off);
                else n->set_meta(String("_glp_") + String(key), off);
            }
            lua_pop(L, 1);
        }
    }
}
