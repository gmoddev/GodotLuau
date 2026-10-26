#ifndef LUAU_SCRIPT_NODE_H
#define LUAU_SCRIPT_NODE_H

// ════════════════════════════════════════════════════════════════════
//  Script templates by node name
//  When ScriptNodeBase creates a .lua file in the editor, it uses the
//  node name to choose the correct template code.
//  e.g. Health → regen code, ControlModule → movement module, etc.
////
//  Templates de scripts por nombre de nodo
//  Cuando ScriptNodeBase crea un archivo .lua en el editor, usa el
//  nombre del nodo para elegir el código plantilla correcto.
//  Así Health → código de regen, ControlModule → módulo de movimiento, etc.
// ════════════════════════════════════════════════════════════════════

// ── De donde salen las plantillas (1.16.12) ─────────────────────────
//  Ya NO son literales dentro de este header: cada plantilla es un .luau
//  de verdad en GodotLuau/DefaultScripts/, colgado en la MISMA ruta que
//  tendra en el arbol de Roblox (StarterPlayer/StarterCharacterScripts/
//  Health.luau, ServerScriptService/GameManager.luau...). Asi se editan
//  con autocompletado y se encuentran de un vistazo, y un colaborador
//  puede bajarse solo el .luau que quiere mejorar.
//
//  luau_templates_gen.h es la copia EMBEBIDA de esos .luau, escrita por
//  tools/generar_plantillas_luau.py, para que la DLL siga funcionando sin
//  la carpeta (juego exportado, instalacion parcial). En ejecucion
//  gl_luau_template() (mas abajo) prefiere el archivo de disco si existe:
//  editas el .luau, arrancas y ves el cambio SIN recompilar.
//
//  Si tocas un .luau:  python tools/generar_plantillas_luau.py
#include "luau_templates_gen.h"   // LUAU_TEMPLATE_* + LUAU_TEMPLATE_*_PATH (generado)

// Default LocalScript / ServerScript template — mínimo estilo Roblox Studio.
// %SCRIPT_ID% se sustituye por el ID único del script al crearlo.
static const char* LUAU_TEMPLATE_LOCAL_SCRIPT =
    "-->GodotLuau Developed by PimpoliDev\n"
    "print(\"Hello World\" .. \" the script \" .. \"%SCRIPT_ID%\" .. \" he was executed\")\n";

static const char* LUAU_TEMPLATE_SERVER_SCRIPT =
    "-->GodotLuau Developed by PimpoliDev\n"
    "print(\"Hello World\" .. \" the script \" .. \"%SCRIPT_ID%\" .. \" he was executed\")\n";

// Default ModuleScript template — mínimo + boilerplate de módulo.
static const char* LUAU_TEMPLATE_MODULE_OOP =
    "-->GodotLuau Developed by PimpoliDev\n"
    "print(\"Hello World\" .. \" the script \" .. \"%SCRIPT_ID%\" .. \" he was executed\")\n"
    "\n"
    "local module = {}\n"
    "\n"
    "return module\n";

// ══════════════════════════════════════════════════════════════════════
//  Menu modular (1.15) — StarterPlayerScripts/Modules/Menu + submódulos.
//  Menu (principal) contiene: MenuUi (todas las UIs), Settings (Config),
//  Players (Personas). TODO editable por el usuario. El PlayerModule hace
//  require(Menu) y Menu.Init(player). El menú se abre con Escape y se ve
//  como el de Roblox.
// ══════════════════════════════════════════════════════════════════════
#include "menu_templates.h"   // LUAU_TEMPLATE_MENU / _UI / _SETTINGS / _PLAYERS

#include "luau_api.h"
#include "roblox_part.h"
#include "humanoid.h"
#include "luau_stdlib.h"
#include "gl_domain_host.h"

#include <godot_cpp/classes/script_extension.hpp>
#include <godot_cpp/classes/script_language.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/http_client.hpp>
#include <godot_cpp/classes/tls_options.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "lua.h"
#include "lualib.h"
#include "Luau/Compiler.h"

#include <godot_cpp/classes/os.hpp>

#include "gl_debug.h"   // GL_DEBUG_PRINT + gl_tr3

#include <vector>
#include <string>
#include <map>

using namespace godot;

// ══════════════════════════════════════════════════════════════════════
//  Carga en caliente de plantillas (1.16.12)
//  Cada plantilla de fábrica es un archivo .luau real en
//  res://GodotLuau/DefaultScripts/<ruta espejo del árbol de Roblox>.
//  gl_luau_template() intenta leer ese archivo y, si no está (juego
//  exportado, instalación sin la carpeta), devuelve el literal embebido de
//  luau_templates_gen.h. Así se edita un .luau, se arranca y se ve el
//  cambio SIN recompilar la extensión.
// ══════════════════════════════════════════════════════════════════════
static const char* GL_TPL_DIR = "res://GodotLuau/DefaultScripts/";

static const char* gl_luau_template(const char* clave, const char* embebido) {
    // Caché por clave (el archivo se lee UNA vez). Guardamos std::string y no
    // String/CharString de Godot a propósito: el const char* que devolvemos
    // tiene que seguir vivo tras el return, y un contenedor estático de tipos
    // de Godot se destruiría al descargar la DLL (destrucción tardía).
    // Valor vacío = no hay archivo en disco → se usa el literal embebido.
    static std::map<std::string, std::string> cache;
    std::map<std::string, std::string>::iterator it = cache.find(clave);
    if (it == cache.end()) {
        std::string leido;
        const String path = String(GL_TPL_DIR) + String(clave);
        if (FileAccess::file_exists(path)) {
            String txt = FileAccess::get_file_as_string(path);
            if (!txt.is_empty()) {
                // Igualar el archivo al literal embebido: éste empieza con un
                // salto de línea (el que abre su raw string) y usa LF, mientras
                // el archivo no trae ese salto y puede venir en CRLF (git).
                txt = String("\n") + txt.replace("\r\n", "\n");
                leido = std::string(txt.utf8().get_data());
                GL_DEBUG_PRINT("[GodotLuau] Plantilla leida de disco: ", path);
            }
        }
        it = cache.insert(std::pair<std::string, std::string>(std::string(clave), leido)).first;
    }
    return it->second.empty() ? embebido : it->second.c_str();
}

// ══════════════════════════════════════════════════════════════════════
//  Plantillas de fábrica: fuente ÚNICA de la verdad (1.15)
//  gl_builtin_template() decide qué código "de fábrica" corresponde a un
//  nodo de script según su NOMBRE y clase. La usan tanto el creador de
//  archivos (ENTER_TREE, más abajo) como el actualizador incremental
//  (roblox_datamodel.h), para no duplicar el mapeo en dos sitios.
// ══════════════════════════════════════════════════════════════════════
// Atajo: cada plantilla se pide por su .luau (con el literal embebido como
// reserva), así el disco manda siempre que el archivo esté.
#define GL_TPL(NOMBRE) String(gl_luau_template(NOMBRE##_PATH, NOMBRE))

static String gl_builtin_template(const String& node_name, const String& cls) {
    if (node_name == "Health")         return GL_TPL(LUAU_TEMPLATE_HEALTH);
    if (node_name == "Animate")        return GL_TPL(LUAU_TEMPLATE_ANIMATE);
    if (node_name == "PlayerModule")   return GL_TPL(LUAU_TEMPLATE_PLAYER_MODULE);
    if (node_name == "ControlModule")  return GL_TPL(LUAU_TEMPLATE_CONTROL_MODULE);
    if (node_name == "PCModule")       return GL_TPL(LUAU_TEMPLATE_PC_MODULE);
    if (node_name == "MobileModule")   return GL_TPL(LUAU_TEMPLATE_MOBILE_MODULE);
    if (node_name == "ConsoleModule")  return GL_TPL(LUAU_TEMPLATE_CONSOLE_MODULE);
    if (node_name == "CameraModule")   return GL_TPL(LUAU_TEMPLATE_CAMERA_MODULE);
    if (node_name == "ChatModule")     return GL_TPL(LUAU_TEMPLATE_CHAT_MODULE);
    if (node_name == "GameManager")    return GL_TPL(LUAU_TEMPLATE_GAME_MANAGER);
    // Menu modular (1.15): Menu principal + submódulos editables. Sus .luau
    // están en DefaultScripts/.../Modules/Menu (ver menu_templates.h).
    if (node_name == "Menu")           return GL_TPL(LUAU_TEMPLATE_MENU);
    if (node_name == "MenuUi")         return GL_TPL(LUAU_TEMPLATE_MENU_UI);
    if (node_name == "Settings")       return GL_TPL(LUAU_TEMPLATE_MENU_SETTINGS);
    if (node_name == "Players")        return GL_TPL(LUAU_TEMPLATE_MENU_PLAYERS);
    // Legado (WIP 1.15): módulo único de ajustes, reemplazado por Menu/*.
    if (node_name == "SettingsModule") return GL_TPL(LUAU_TEMPLATE_SETTINGS_MODULE);
    if (cls == "LocalScript")  return String(LUAU_TEMPLATE_LOCAL_SCRIPT);
    if (cls == "ServerScript") return String(LUAU_TEMPLATE_SERVER_SCRIPT);
    if (cls == "ModuleScript") return String(LUAU_TEMPLATE_MODULE_OOP);
    return String(LUAU_TEMPLATE_LOCAL_SCRIPT);
}
#undef GL_TPL   // atajo local: no se escapa al resto de la extensión

// ¿El nombre corresponde a un script "de fábrica" con plantilla propia? Un
// LocalScript/ModuleScript del usuario con nombre arbitrario NO lo es (cae en el
// template genérico) y el actualizador NO lo toca.
static bool gl_is_managed_template(const String& node_name) {
    static const char* names[] = {
        "Health", "Animate", "PlayerModule", "ControlModule", "PCModule",
        "MobileModule", "ConsoleModule", "CameraModule", "ChatModule",
        "GameManager", "Menu", "MenuUi", "Settings", "Players"
    };
    for (const char* n : names) if (node_name == String(n)) return true;
    return false;
}

// ── Sidecar de "hash base" por script (1.15) ──────────────────────────────
//  Guarda, por script_id, el md5 del ÚLTIMO template de fábrica que ESCRIBIMOS
//  en su archivo. Permite al actualizador distinguir:
//    · archivo == base            → el jugador NO lo tocó  → actualizar en sitio
//    · archivo != base            → el jugador lo tocó     → ofrecer en ScriptUpdate
//  Formato: líneas "script_id\tmd5" en res://GodotLuau/.gl_tpl_base.cfg
static const char* GL_TPL_BASE_PATH = "res://GodotLuau/.gl_tpl_base.cfg";

static Dictionary gl_tpl_base_load() {
    Dictionary d;
    if (!FileAccess::file_exists(GL_TPL_BASE_PATH)) return d;
    Ref<FileAccess> f = FileAccess::open(GL_TPL_BASE_PATH, FileAccess::READ);
    if (f.is_null()) return d;
    while (!f->eof_reached()) {
        String line = f->get_line();
        int tab = line.find("\t");
        if (tab > 0) d[line.substr(0, tab)] = line.substr(tab + 1);
    }
    return d;
}
static void gl_tpl_base_save(const Dictionary& d) {
    Ref<DirAccess> dir = DirAccess::open("res://");
    if (dir.is_valid() && !dir->dir_exists("res://GodotLuau")) dir->make_dir_recursive("res://GodotLuau");
    Ref<FileAccess> f = FileAccess::open(GL_TPL_BASE_PATH, FileAccess::WRITE);
    if (f.is_null()) return;
    Array keys = d.keys();
    for (int i = 0; i < keys.size(); i++) {
        String k = keys[i];
        f->store_line(k + "\t" + String(d[k]));
    }
}
static String gl_tpl_base_get(const String& id) {
    Dictionary d = gl_tpl_base_load();
    return d.has(id) ? String(d[id]) : String();
}
static void gl_tpl_base_set(const String& id, const String& md5) {
    Dictionary d = gl_tpl_base_load();
    d[id] = md5;
    gl_tpl_base_save(d);
}

// ── Helpers for _JSON: Variant ↔ Lua conversion ───────────────────────────
//// ── Helpers para _JSON: conversión Variant ↔ Lua ──────────────────────────
static void _gdluau_variant_to_lua(lua_State* L, const Variant& v) {
    switch (v.get_type()) {
        case Variant::NIL:    lua_pushnil(L); return;
        case Variant::BOOL:   lua_pushboolean(L, (bool)v); return;
        case Variant::INT:    lua_pushnumber(L, (double)(int64_t)v); return;
        case Variant::FLOAT:  lua_pushnumber(L, (double)v); return;
        case Variant::STRING: { String s = v; lua_pushstring(L, s.utf8().get_data()); return; }
        case Variant::ARRAY: {
            Array arr = v; lua_newtable(L);
            for (int i = 0; i < arr.size(); i++) {
                _gdluau_variant_to_lua(L, arr[i]);
                lua_rawseti(L, -2, i + 1);
            }
            return;
        }
        case Variant::DICTIONARY: {
            Dictionary dict = v; lua_newtable(L);
            Array keys = dict.keys();
            for (int i = 0; i < keys.size(); i++) {
                String k = String(keys[i]);
                lua_pushstring(L, k.utf8().get_data());
                _gdluau_variant_to_lua(L, dict[keys[i]]);
                lua_rawset(L, -3);
            }
            return;
        }
        default: lua_pushnil(L); return;
    }
}

static Variant _gdluau_lua_to_variant(lua_State* L, int idx, int depth = 0) {
    if (depth > 20) return Variant();
    if (idx < 0) idx = lua_gettop(L) + idx + 1;
    int t = lua_type(L, idx);
    if (t == LUA_TNIL)     return Variant();
    if (t == LUA_TBOOLEAN) return Variant((bool)lua_toboolean(L, idx));
    if (t == LUA_TNUMBER)  {
        double n = lua_tonumber(L, idx);
        return (n == (int64_t)n) ? Variant((int64_t)n) : Variant(n);
    }
    if (t == LUA_TSTRING)  return Variant(String(lua_tostring(L, idx)));
    if (t == LUA_TTABLE) {
        int seq_len = (int)lua_objlen(L, idx);
        if (seq_len > 0) {
            Array arr;
            for (int i = 1; i <= seq_len; i++) {
                lua_rawgeti(L, idx, i);
                arr.push_back(_gdluau_lua_to_variant(L, -1, depth + 1));
                lua_pop(L, 1);
            }
            return arr;
        }
        Dictionary dict;
        lua_pushnil(L);
        while (lua_next(L, idx) != 0) {
            String key;
            if (lua_type(L, -2) == LUA_TSTRING) key = String(lua_tostring(L, -2));
            else if (lua_type(L, -2) == LUA_TNUMBER) key = String::num(lua_tonumber(L, -2));
            dict[key] = _gdluau_lua_to_variant(L, -1, depth + 1);
            lua_pop(L, 1);
        }
        return dict;
    }
    return Variant();
}

// ── Helpers para _HTTP: cliente HTTP real (bloqueante) sobre HTTPClient ─────
//// Fase 1 de la capa de red: HttpService:GetAsync/PostAsync/RequestAsync ya
//// no son un stub. Bloquea el hilo hasta completar o timeout; contra Nakama
//// local son milisegundos. La versión NO bloqueante (yield) llegará con el
//// NakamaService en C++ (WebSocket + HTTP asíncrono).

struct GLHttpResult {
    int    status = 0;      // código HTTP (200, 404…); 0 = fallo de red/conexión
    String status_msg;      // "OK", "Timeout al conectar"…
    String body;            // cuerpo de la respuesta (o texto de error si status==0)
    bool   ok    = false;   // true si status ∈ [200, 299]
};

// ¿Está presente el argumento idx (no none ni nil)? Evita depender de luaL_opt*.
static bool gl_arg_present(lua_State* L, int idx) {
    int t = lua_type(L, idx);
    return t != LUA_TNONE && t != LUA_TNIL;
}

static HTTPClient::Method gl_http_method_from_string(const String& m) {
    String u = m.to_upper();
    if (u == "GET")     return HTTPClient::METHOD_GET;
    if (u == "POST")    return HTTPClient::METHOD_POST;
    if (u == "PUT")     return HTTPClient::METHOD_PUT;
    if (u == "DELETE")  return HTTPClient::METHOD_DELETE;
    if (u == "PATCH")   return HTTPClient::METHOD_PATCH;
    if (u == "HEAD")    return HTTPClient::METHOD_HEAD;
    if (u == "OPTIONS") return HTTPClient::METHOD_OPTIONS;
    return HTTPClient::METHOD_GET;
}

// Convierte una tabla Luau {["Nombre"]="Valor", …} en el formato "Nombre: Valor"
// que espera HTTPClient::request. Ignora claves/valores no representables.
static PackedStringArray gl_lua_headers_to_array(lua_State* L, int idx) {
    PackedStringArray out;
    if (idx < 0) idx = lua_gettop(L) + idx + 1;
    if (!lua_istable(L, idx)) return out;
    lua_pushnil(L);
    while (lua_next(L, idx) != 0) {
        if (lua_type(L, -2) == LUA_TSTRING) {
            String key = String(lua_tostring(L, -2));
            String val;
            int vt = lua_type(L, -1);
            if (vt == LUA_TSTRING)      val = String(lua_tostring(L, -1));
            else if (vt == LUA_TNUMBER) val = String::num(lua_tonumber(L, -1));
            else { lua_pop(L, 1); continue; }
            out.push_back(key + ": " + val);
        }
        lua_pop(L, 1);  // deja la clave para el próximo lua_next
    }
    return out;
}

// Petición HTTP síncrona. Parsea la URL (http/https, host[:port]/path), conecta,
// envía y lee el body, con un tope de tiempo total (timeout_sec).
static GLHttpResult gl_http_perform(HTTPClient::Method method, const String& url,
                                    const PackedStringArray& headers, const String& body,
                                    double timeout_sec = 10.0) {
    GLHttpResult res;

    // ── Parsear URL: scheme://host[:port]/path?query ──────────────────────
    String u = url.strip_edges();
    bool use_tls = false;
    if (u.begins_with("https://"))     { use_tls = true;  u = u.substr(8); }
    else if (u.begins_with("http://")) { use_tls = false; u = u.substr(7); }
    else { res.status_msg = "URL sin esquema http(s)://"; res.body = res.status_msg; return res; }

    int slash = u.find("/");
    String authority = (slash == -1) ? u : u.substr(0, slash);
    String path      = (slash == -1) ? String("/") : u.substr(slash);
    if (path.is_empty()) path = "/";

    String host = authority;
    int port = use_tls ? 443 : 80;
    int colon = authority.rfind(":");   // host:puerto (no soporta IPv6 con corchetes)
    if (colon != -1) {
        String p = authority.substr(colon + 1);
        if (p.is_valid_int()) { host = authority.substr(0, colon); port = (int)p.to_int(); }
    }

    // ── Conectar ──────────────────────────────────────────────────────────
    Ref<HTTPClient> client; client.instantiate();
    Ref<TLSOptions> tls = use_tls ? TLSOptions::client() : Ref<TLSOptions>();
    if (client->connect_to_host(host, port, tls) != OK) {
        res.status_msg = "connect_to_host falló"; res.body = res.status_msg; return res;
    }

    OS* os = OS::get_singleton();
    Time* clock = Time::get_singleton();   // en Godot 4 get_ticks_msec vive en Time, no en OS
    uint64_t start = clock->get_ticks_msec();
    uint64_t timeout_ms = (uint64_t)(timeout_sec * 1000.0);

    // Esperar a que la conexión quede establecida
    while (true) {
        client->poll();
        HTTPClient::Status st = client->get_status();
        if (st == HTTPClient::STATUS_CONNECTED) break;
        if (st == HTTPClient::STATUS_RESOLVING || st == HTTPClient::STATUS_CONNECTING) {
            if (clock->get_ticks_msec() - start > timeout_ms) {
                res.status_msg = "Timeout al conectar"; res.body = res.status_msg; return res;
            }
            os->delay_msec(1);
            continue;
        }
        res.status_msg = "No se pudo conectar (status " + String::num_int64((int)st) + ")";
        res.body = res.status_msg; return res;
    }

    // ── Enviar petición ───────────────────────────────────────────────────
    if (client->request(method, path, headers, body) != OK) {
        res.status_msg = "request() falló"; res.body = res.status_msg; return res;
    }
    while (true) {
        client->poll();
        HTTPClient::Status st = client->get_status();
        if (st == HTTPClient::STATUS_BODY || st == HTTPClient::STATUS_CONNECTED) break;
        if (st == HTTPClient::STATUS_REQUESTING) {
            if (clock->get_ticks_msec() - start > timeout_ms) {
                res.status_msg = "Timeout esperando respuesta"; res.body = res.status_msg; return res;
            }
            os->delay_msec(1);
            continue;
        }
        res.status_msg = "Error de conexión en la petición (status " + String::num_int64((int)st) + ")";
        res.body = res.status_msg; return res;
    }

    res.status = client->get_response_code();
    res.ok = (res.status >= 200 && res.status < 300);

    // ── Leer el body por trozos ───────────────────────────────────────────
    PackedByteArray data;
    while (client->get_status() == HTTPClient::STATUS_BODY) {
        client->poll();
        PackedByteArray chunk = client->read_response_body_chunk();
        if (chunk.size() == 0) {
            if (clock->get_ticks_msec() - start > timeout_ms) break;
            os->delay_msec(1);
        } else {
            data.append_array(chunk);
        }
    }
    client->close();

    res.body = data.size() > 0 ? String::utf8((const char*)data.ptr(), (int)data.size()) : String();
    if (res.status_msg.is_empty())
        res.status_msg = res.ok ? "OK" : ("HTTP " + String::num_int64(res.status));
    return res;
}

class LuauScript : public ScriptExtension {
    GDCLASS(LuauScript, ScriptExtension);

protected:
    static void _bind_methods() {}
    String source_code;

public:
    String _get_source_code() const override { return source_code; }
    void _set_source_code(const String &p_code) override { if (source_code != p_code) { source_code = p_code; emit_changed(); } }
    bool _is_tool() const override { return false; }
    bool _is_valid() const override { return true; }
    bool _has_source_code() const override { return true; }
    bool _can_instantiate() const override { return true; }
    bool _has_static_method(const StringName &p_method) const override { return false; }
    void _update_exports() override {}
    Ref<Script> _get_base_script() const override { return Ref<Script>(); }
    TypedArray<Dictionary> _get_documentation() const override { return TypedArray<Dictionary>(); }
    StringName _get_instance_base_type() const override { return StringName("Object"); }
    ScriptLanguage *_get_language() const override;
    void *_instance_create(Object *p_for_object) const override { return nullptr; }
    Error _reload(bool p_keep_state) override { return OK; }
};

// ════════════════════════════════════════════════════════════════════
//  ScriptNodeBase — Base class for LocalScript, ServerScript, ModuleScript
////  ScriptNodeBase — Base de LocalScript, ServerScript, ModuleScript
// ════════════════════════════════════════════════════════════════════
class ScriptNodeBase : public Node {
    GDCLASS(ScriptNodeBase, Node);

private:
    Ref<LuauScript> codigo_luau;
    lua_State* L_main = nullptr; // per-run owner anchor, never a separate VM
    GLExecutionDomain* Domain = nullptr;
    GLExecutionOwner* RunOwner = nullptr;
    int RunGuard = LUA_NOREF;

public:
    void StopRun() {
        if (GLReferenceAlive(L_main, RunGuard) && RunOwner) RunOwner->Domain->CancelOwner(RunOwner);
        GLUnreference(nullptr, RunGuard);
        RunGuard = LUA_NOREF;
        L_main = nullptr;
        Domain = nullptr;
        RunOwner = nullptr;
        script_started = false;
    }
    void add_waiting_invoke(lua_State* Thread, lua_State*, int Reference, int64_t CallId, double Timeout) {
        if (auto Host = GLGetDomainHost()) Host->WaitForInvoke(Thread, CallId, Timeout, Reference);
    }
    void add_waiting_child(lua_State* Thread, lua_State*, int Reference, Node* Parent, const String& Name, double Timeout) {
        if (auto Host = GLGetDomainHost()) Host->WaitForChild(Thread,
            Parent ? static_cast<uint64_t>(Parent->get_instance_id()) : 0, Name, Timeout, Reference);
    }
    void resume_external_thread(lua_State* Thread, int Arguments) { GLResume(Thread, nullptr, Arguments); }
    void resume_external_thread_error(lua_State* Thread, const String& Error) {
        lua_pushstring(Thread, Error.utf8().get_data()); GLResumeError(Thread, nullptr);
    }
    void _gl_source_changed() {
        if (Engine::get_singleton()->is_editor_hint()) return;
        if (auto Host = GLGetDomainHost()) Host->InvalidateModule(static_cast<uint64_t>(get_instance_id()));
        StopRun();
        if (is_inside_tree() && script_enabled && get_class() != "ModuleScript") call_deferred("iniciar_corrutina");
    }

    // ID persistente e inmutable del script (ej. "ServerScript_ID_12").
    // Vincula el nodo con su archivo .lua para poder borrarlo/restaurarlo junto al nodo.
    String script_id;

    // Enabled (como Roblox): true por defecto; con false el script NO se
    // ejecuta. Si en runtime vuelve a true y no habia corrido, corre entonces.
    bool script_enabled = true;
    bool script_started = false;

    // Duplicado (Ctrl+D / copiar-pegar) detectado en ENTER_TREE: código heredado
    // del original que se escribe en el archivo NUEVO en vez de un template.
    String _gl_dup_source;
    bool   _gl_is_dup = false;

    // ¿Otro ScriptNodeBase VIVO (distinto de este) ya usa este script_id?
    // Es la señal inequívoca de un DUPLICADO en el editor: Godot copió el
    // script_id exportado y compartió la MISMA Ref<LuauScript> (mismo .lua),
    // por eso "abren el mismo script". Un proyecto recién abierto no dispara
    // esto: cada nodo trae su id único persistido.
    ScriptNodeBase* _gl_find_id_twin() {
        if (!get_tree() || !get_tree()->get_root()) return nullptr;
        ScriptNodeBase* found = nullptr;
        std::function<void(Node*)> rec = [&](Node* n) {
            if (found || !n) return;
            if (n != (Node*)this) {
                ScriptNodeBase* s = Object::cast_to<ScriptNodeBase>(n);
                if (s && !s->script_id.is_empty() && s->script_id == script_id) { found = s; return; }
            }
            for (int i = 0; i < n->get_child_count(); i++) rec(n->get_child(i));
        };
        rec(get_tree()->get_root());
        return found;
    }

public:
    void set_enabled(bool b) {
        if (script_enabled == b) return;
        script_enabled = b;
        if (!b) StopRun();
        if (script_enabled && !script_started && is_inside_tree()
            && !Engine::get_singleton()->is_editor_hint()) {
            call_deferred("iniciar_corrutina");
        }
    }
    bool get_enabled() const { return script_enabled; }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_codigo_luau", "s"), &ScriptNodeBase::set_codigo_luau);
        ClassDB::bind_method(D_METHOD("get_codigo_luau"), &ScriptNodeBase::get_codigo_luau);
        ClassDB::bind_method(D_METHOD("iniciar_corrutina"), &ScriptNodeBase::iniciar_corrutina);
        ClassDB::bind_method(D_METHOD("_gl_source_changed"), &ScriptNodeBase::_gl_source_changed);
        ClassDB::bind_method(D_METHOD("set_script_id", "id"), &ScriptNodeBase::set_script_id);
        ClassDB::bind_method(D_METHOD("get_script_id"), &ScriptNodeBase::get_script_id);
        ClassDB::bind_method(D_METHOD("set_enabled", "b"), &ScriptNodeBase::set_enabled);
        ClassDB::bind_method(D_METHOD("get_enabled"), &ScriptNodeBase::get_enabled);
        // Relay de ChildAdded/ChildRemoved: Godot lo invoca con el hijo + el ref guardado.
        ClassDB::bind_method(D_METHOD("_gl_child_event", "child", "ref"), &ScriptNodeBase::_gl_child_event);

        ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "codigo_luau", PROPERTY_HINT_RESOURCE_TYPE, "LuauScript"),
                     "set_codigo_luau", "get_codigo_luau");
        // NOTA: la propiedad "Enabled" NO se añade aquí a propósito. En Roblox
        // Studio solo Script/LocalScript la tienen; un ModuleScript no. Por eso
        // cada subclase ejecutable la añade en su propio _bind_methods (ver
        // ServerScript/LocalScript abajo) y ModuleScript la omite. Los métodos
        // set_enabled/get_enabled siguen ligados aquí para uso interno.
        // Visible en el inspector pero NO editable por el usuario
        ADD_PROPERTY(PropertyInfo(Variant::STRING, "script_id", PROPERTY_HINT_NONE, "",
                     PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY),
                     "set_script_id", "get_script_id");
    }

    // Contador secuencial por tipo en res://.luau_ids.cfg
    // (NO se usa project.godot: guardarlo hace que el editor recargue los plugins)
    // Cacheado en memoria y con los handles SIEMPRE cerrados antes de reabrir:
    // en Windows, leer y escribir el mismo archivo con el handle abierto
    // produce "archivo en uso, bloqueado" cuando entran varios scripts a la vez.
    static int64_t _next_script_counter(const String& cls_lower) {
        static Dictionary counters;
        static bool loaded = false;
        const String path = "res://.luau_ids.cfg";

        if (!loaded) {
            loaded = true;
            Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
            if (f.is_valid()) {
                while (!f->eof_reached()) {
                    String line = f->get_line().strip_edges();
                    int eq = line.find("=");
                    if (eq > 0) counters[line.substr(0, eq)] = line.substr(eq + 1).to_int();
                }
                f->close();  // cerrar ANTES de cualquier escritura posterior
            }
        }
        // Migración: contadores antiguos guardados en project.godot
        if (!counters.has(cls_lower)) {
            String legacy_key = "godot_luau/script_id_counter_" + cls_lower;
            if (ProjectSettings::get_singleton()->has_setting(legacy_key))
                counters[cls_lower] = (int64_t)ProjectSettings::get_singleton()->get_setting(legacy_key, 0);
        }
        int64_t next = (int64_t)counters.get(cls_lower, 0) + 1;
        counters[cls_lower] = next;

        Ref<FileAccess> w = FileAccess::open(path, FileAccess::WRITE);
        if (w.is_valid()) {
            Array keys = counters.keys();
            for (int i = 0; i < keys.size(); i++)
                w->store_line(String(keys[i]) + "=" + String::num_int64((int64_t)counters[keys[i]]));
            w->close();
        }
        return next;
    }

    void _notification(int p_what) {
        if (Engine::get_singleton()->is_editor_hint()) {
            if (p_what == NOTIFICATION_ENTER_TREE) {
                // ── Detección de DUPLICADO (Ctrl+D / copiar-pegar) ─────────
                // Si otro nodo vivo ya usa este script_id, este es una copia:
                // se le da identidad y archivo PROPIOS copiando el código actual
                // del original, para que dejen de "abrir el mismo script" y cada
                // uno ejecute sus funciones de forma independiente.
                if (!script_id.is_empty() && _gl_find_id_twin()) {
                    if (codigo_luau.is_valid()) {
                        _gl_dup_source = codigo_luau->_get_source_code();
                        if (_gl_dup_source.is_empty() && !codigo_luau->get_path().is_empty()) {
                            Ref<FileAccess> rf = FileAccess::open(codigo_luau->get_path(), FileAccess::READ);
                            if (rf.is_valid()) { _gl_dup_source = rf->get_as_text(); rf->close(); }
                        }
                    }
                    _gl_is_dup = true;
                    script_id = String();               // fuerza id nuevo abajo
                    codigo_luau = Ref<LuauScript>();     // suelta el recurso compartido
                }

                // ── Asignar ID persistente la primera vez ──────────────────
                if (script_id.is_empty()) {
                    String cls_id = get_class();
                    script_id = cls_id + "_ID_" + String::num_int64(_next_script_counter(cls_id.to_lower()));
                }

                bool necesita_archivo = codigo_luau.is_null() ||
                    (!codigo_luau->get_path().is_empty() &&
                     !FileAccess::file_exists(codigo_luau->get_path()));

                // ── Restauración (Ctrl+Z): papelera o memoria, sin crear recursos
                //    duplicados (evita "Another resource is loaded from path") ──
                if (necesita_archivo && codigo_luau.is_valid() && !codigo_luau->get_path().is_empty()) {
                    String path  = codigo_luau->get_path();
                    String trash = "res://.luau_trash/" + script_id + ".lua";
                    Ref<DirAccess> root_dir = DirAccess::open("res://");
                    if (root_dir.is_valid() && !root_dir->dir_exists(path.get_base_dir()))
                        root_dir->make_dir_recursive(path.get_base_dir());
                    if (FileAccess::file_exists(trash)) {
                        // El archivo está en la papelera (nodo borrado + Ctrl+Z) → moverlo de vuelta
                        if (DirAccess::rename_absolute(
                                ProjectSettings::get_singleton()->globalize_path(trash),
                                ProjectSettings::get_singleton()->globalize_path(path)) == OK) {
                            GL_DEBUG_PRINT("[GodotLuau] Script restaurado de la papelera: ", path);
                            necesita_archivo = false;
                        }
                    } else if (!codigo_luau->_get_source_code().is_empty()) {
                        // El recurso aún conserva el código en memoria → reescribirlo a disco
                        Ref<FileAccess> wf = FileAccess::open(path, FileAccess::WRITE);
                        if (wf.is_valid()) {
                            wf->store_string(codigo_luau->_get_source_code());
                            GL_DEBUG_PRINT("[GodotLuau] Script reescrito desde memoria: ", path);
                            necesita_archivo = false;
                        }
                    }
                }

                if (necesita_archivo) {
                    String cls = get_class();
                    // Los scripts van DENTRO de GodotLuau/ (orden pedido por el
                    // usuario): res://GodotLuau/LocalScripts, /ServerScripts, etc.
                    String folder = "res://GodotLuau/" + cls + "s";
                    Ref<DirAccess> dir = DirAccess::open("res://");
                    if (dir.is_valid() && !dir->dir_exists(folder)) {
                        dir->make_dir_recursive(folder);
                    }

                    // El archivo se nombra por el ID → estable entre sesiones
                    String file_path = folder + "/" + script_id + ".lua";

                    Ref<LuauScript> new_script;
                    new_script.instantiate();

                    // ── Template selection based on node name ─────────────────
                    // Fuente ÚNICA de la verdad: gl_builtin_template() (arriba).
                    // La comparte el actualizador incremental (roblox_datamodel.h).
                    //// ── Selección de template según nombre del nodo ────────────
                    String node_name = get_name();
                    String template_code = gl_builtin_template(node_name, cls);

                    // Un duplicado hereda el código EXACTO del original (no un
                    // template): así la copia conserva lo que el usuario escribió.
                    bool is_dup = (_gl_is_dup && !_gl_dup_source.is_empty());
                    if (is_dup)
                        template_code = _gl_dup_source;

                    // Sustituir el ID único del script en la plantilla (para poder
                    // localizarlo al buscar por su ID). Los templates de sistema
                    // (Health/Animate…) no tienen el placeholder → quedan intactos.
                    template_code = template_code.replace("%SCRIPT_ID%", script_id);
                    new_script->_set_source_code(template_code);
                    // take_over_path reclama la ruta aunque haya un recurso viejo cacheado
                    // (evita "Another resource is loaded from path")
                    new_script->take_over_path(file_path);
                    ResourceSaver::get_singleton()->save(new_script, file_path);
                    set_codigo_luau(new_script);
                    // Registrar el hash "base" de fábrica (1.15): permite al
                    // actualizador saber luego si el jugador tocó el archivo. Un
                    // duplicado NO es plantilla de fábrica → no se registra base.
                    if (!is_dup)
                        gl_tpl_base_set(script_id, template_code.md5_text());
                    GL_DEBUG_PRINT("[GodotLuau] Script creado: ", file_path);
                    if (_gl_is_dup)
                        GL_DEBUG_PRINT("[GodotLuau] Duplicado con identidad propia: ", script_id);
                    _gl_is_dup = false;          // consumido: no repetir en re-entradas
                    _gl_dup_source = String();
                }
            }
            // NOTA: el borrado/restauración del archivo al borrar el nodo (con soporte
            // de Ctrl+Z vía papelera res://.luau_trash/) lo gestiona el addon
            // GodotLuauUpdater, que puede distinguir un borrado real de un cierre de escena.
        } else if (p_what == NOTIFICATION_EXIT_TREE) {
            if (auto Host = GLGetDomainHost()) Host->InvalidateModule(static_cast<uint64_t>(get_instance_id()));
            StopRun();
        }
    }

public:
    ScriptNodeBase() {}
    ~ScriptNodeBase() { StopRun(); }

    void set_codigo_luau(const Ref<LuauScript> &s) {
        if (codigo_luau == s) return;
        Callable Changed(this, "_gl_source_changed");
        if (codigo_luau.is_valid() && codigo_luau->is_connected("changed", Changed))
            codigo_luau->disconnect("changed", Changed);
        StopRun();
        codigo_luau = s;
        if (codigo_luau.is_valid() && !codigo_luau->is_connected("changed", Changed))
            codigo_luau->connect("changed", Changed);
        _gl_source_changed();
    }
    Ref<LuauScript> get_codigo_luau() const { return codigo_luau; }

    void set_script_id(const String &p_id) { script_id = p_id; }
    String get_script_id() const { return script_id; }

    void iniciar_corrutina() {
        if (Engine::get_singleton()->is_editor_hint()) return;
        if (get_class() == "ModuleScript") return;
        const int RunContext = has_meta("RunContext") ? static_cast<int>(static_cast<int64_t>(get_meta("RunContext"))) : 0;
        const bool IsClient = get_class() == "LocalScript" || RunContext == 2;
        const GLDomainKind Kind = IsClient ? GLDomainKind::Client : GLDomainKind::Server;
        if (!GLDomainAllowed(Kind)) return;
        // Plantillas (1.15): lo que vive dentro de un Starter* NO se ejecuta, solo
        // su clon. Sin esto corrían los dos: original + clon.
        if (gl_in_template_container(this)) {
            GL_DEBUG_PRINT("[GodotLuau] Script '", get_name(), "' no ejecutado: es una PLANTILLA (dentro de ",
                           get_parent() ? String(get_parent()->get_name()) : String("?"), "). Corre su clon.");
            return;
        }
        // Modelo server-authoritative (1.14.5): un ServerScript solo corre cuando
        // esta ventana es CONFIRMADAMENTE el servidor (gl_net_role()==1). En una
        // sesión de red (cliente O servidor cuyo rol aún se está fijando) se
        // APLAZA y lo ejecuta start_server → gl_run_deferred_server_scripts() con
        // role=1 ya puesto (así el mundo que crea SÍ se replica; y un cliente que
        // nunca es servidor no lo corre — recibe el mundo por replicación). En
        // single-player gl_startup_defer_server()==false → corre de inmediato. No
        // marca script_started para poder re-ejecutarlo al confirmarse el rol.
        if (!IsClient && gl_net_role() != 1 && gl_startup_defer_server()) {
            uint64_t oid = (uint64_t)get_instance_id();
            std::vector<uint64_t>& dl = gl_deferred_server_scripts();
            bool dup = false;
            for (uint64_t x : dl) if (x == oid) { dup = true; break; }
            if (!dup) dl.push_back(oid);
            GL_DEBUG_PRINT("[GodotLuau] ServerScript '", get_name(), "' aplazado (ventana cliente; el mundo llega por replicacion).");
            return;
        }
        if (!script_enabled) {
            // Enabled=false (como Roblox): no ejecutar. Aviso en Modo Debug para
            // que "mi script no corre y no dice nada" se diagnostique solo.
            GL_DEBUG_PRINT("[GodotLuau] Script '", get_name(), "' NO ejecutado: Enabled = false.");
            return;
        }
        if (script_started) return;    // ya corrio (evita doble arranque al re-habilitar)
        script_started = true;

        if (codigo_luau.is_null()) {
            UtilityFunctions::push_error("[GodotLuau] ", gl_tr3("Node '", "El nodo '", "O nó '"), get_name(), gl_tr3(
                "' has no Luau script assigned.",
                "' no tiene un archivo Luau asignado.",
                "' não tem um script Luau atribuído."));
            return;
        }

        auto Host = GLGetDomainHost(get_tree());
        if (!Host) { script_started = false; return; }
        Domain = &Host->GetDomain(Kind);
        if (Host->ClaimInitialization(Kind)) InitializeDomain(*Domain);
        RunOwner = Domain->CreateOwner(static_cast<uint64_t>(get_instance_id()));
        if (!RunOwner) { script_started = false; return; }
        L_main = RunOwner->Anchor;
        lua_pushboolean(L_main, true);
        RunGuard = GLReference(L_main, -1);
        lua_pop(L_main, 1);
        String ChunkName = String("=") + gl_instance_fullname(this);
        Domain->Execute(RunOwner, codigo_luau->_get_source_code().utf8().get_data(), ChunkName.utf8().get_data());
    }

    void InitializeDomain(GLExecutionDomain& Runtime) {
        lua_State* L_main = Runtime.GetState();
        const bool _is_client = Runtime.GetKind() == GLDomainKind::Client;
        const bool _is_server = !_is_client;
        gl_register_state(L_main);
        // ── Metatable: GodotObject ────────────────────────────────────────────
        luaL_newmetatable(L_main, "GodotObject");

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            GodotObjectWrapper* ptr = (GodotObjectWrapper*)lua_touserdata(L, 1);
            String key = luaL_checkstring(L, 2);

            if (ptr && gow_node(ptr)) {
                Node* node = gow_node(ptr);

                if (key == "FindFirstChild") {
                    lua_pushcfunction(L, [](lua_State* pL) -> int {
                        GodotObjectWrapper* pptr = (GodotObjectWrapper*)lua_touserdata(pL, 1);
                        if (!pptr || !gow_node(pptr)) { lua_pushnil(pL); return 1; }
                        const char* cname = luaL_checkstring(pL, 2);
                        bool recursive = lua_isboolean(pL, 3) && lua_toboolean(pL, 3);
                        if (!recursive) {
                            for (int i = 0; i < gow_node(pptr)->get_child_count(); i++) {
                                Node* ch = gow_node(pptr)->get_child(i);
                                if (ch && ch->get_name() == StringName(cname)) { wrap_node(pL, ch); return 1; }
                            }
                        } else {
                            Node* t = gow_node(pptr)->find_child(String(cname), true, false);
                            if (t) { wrap_node(pL, t); return 1; }
                        }
                        lua_pushnil(pL); return 1;
                    }, "FindFirstChild");
                    return 1;
                }
                if (key == "WaitForChild") {
                    lua_pushcfunction(L, [](lua_State* pL) -> int {
                        auto Wrapper = static_cast<GodotObjectWrapper*>(lua_touserdata(pL, 1));
                        Node* parent = gow_node(Wrapper);
                        if (!parent) { lua_pushnil(pL); return 1; }
                        const char* cname = luaL_checkstring(pL, 2);
                        double timeout = lua_isnumber(pL, 3) ? lua_tonumber(pL, 3) : -1.0;
                        // Try immediate find
                        for (int i = 0; i < parent->get_child_count(); i++) {
                            Node* ch = parent->get_child(i);
                            if (ch && ch->get_name() == StringName(cname)) { wrap_node(pL, ch); return 1; }
                        }
                        // Not found — register async wait
                        GLPushScriptNode(pL);
                        ScriptNodeBase* sn = (ScriptNodeBase*)lua_touserdata(pL, -1);
                        lua_pop(pL, 1);
                        if (!sn) { lua_pushnil(pL); return 1; }
                        GLPushOwnerState(pL);
                        lua_State* main_L = (lua_State*)lua_touserdata(pL, -1);
                        lua_pop(pL, 1);
                        if (!main_L) main_L = pL;
                        int ref = GLCaptureWait(pL);
                        sn->add_waiting_child(pL, main_L, ref, parent, String(cname), timeout);
                        lua_pushstring(pL, "__WAIT_CHILD__");
                        return lua_yield(pL, 1);
                    }, "WaitForChild");
                    return 1;
                }

                if (key == "GetChildren") {
                    lua_pushcfunction(L, [](lua_State* pL) -> int {
                        GodotObjectWrapper* pptr = (GodotObjectWrapper*)lua_touserdata(pL, 1);
                        lua_newtable(pL);
                        if (pptr && gow_node(pptr)) {
                            TypedArray<Node> children = gow_node(pptr)->get_children();
                            for (int i = 0; i < children.size(); i++) {
                                wrap_node(pL, Object::cast_to<Node>(children[i]));
                                lua_rawseti(pL, -2, i + 1);
                            }
                        }
                        return 1;
                    }, "GetChildren");
                    return 1;
                }

                Node* child = node->get_node_or_null(NodePath(key));
                if (child) { wrap_node(L, child); return 1; }
            }

            return godot_object_index(L);
        }, "__index");
        lua_setfield(L_main, -2, "__index");

        lua_pushcfunction(L_main, godot_object_newindex, "__newindex");
        lua_setfield(L_main, -2, "__newindex");

        // ── __eq (1.14.17) ────────────────────────────────────────────────────
        // Cada acceso a una propiedad crea un envoltorio NUEVO, asi que sin esto
        // Lua comparaba los userdata y dos referencias al MISMO nodo daban
        // siempre false: `hit.Parent == player.Character`, `p.Character == x`…
        // El idioma mas comun de Roblox no entraba NUNCA, y en silencio.
        // Se comparan los ObjectID, no los punteros: asi dos referencias al mismo
        // nodo son iguales aunque sean envoltorios distintos, y sigue funcionando
        // con nodos ya destruidos (mismo id = misma instancia).
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            GodotObjectWrapper* a = (GodotObjectWrapper*)lua_touserdata(L, 1);
            GodotObjectWrapper* b = (GodotObjectWrapper*)lua_touserdata(L, 2);
            lua_pushboolean(L, (a && b && a->obj_id == b->obj_id) ? 1 : 0);
            return 1;
        }, "__eq");
        lua_setfield(L_main, -2, "__eq");

        // __tostring: en Roblox imprimir una instancia da su Nombre; antes salia
        // "userdata: 0x…", que ademas hacia irreconocibles los prints de depuracion.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            GodotObjectWrapper* w = (GodotObjectWrapper*)lua_touserdata(L, 1);
            Node* n = w ? gow_node(w) : nullptr;
            lua_pushstring(L, n ? String(n->get_name()).utf8().get_data() : "NULL");
            return 1;
        }, "__tostring");
        lua_setfield(L_main, -2, "__tostring");

        lua_pop(L_main, 1);

        // Replicación (1.14.5): instala el aplicador de propiedades del cliente
        // (reentra al __newindex real). Idempotente; el NetworkService lo llama
        // por puntero al recibir _rep_new/_rep_prop.
        gl_apply_prop_hook() = gl_rep_apply_prop;
        // Hook para que InvokeServer/Client (en luau_api.h, sin ver ScriptNodeBase)
        // registre el hilo que cede esperando la respuesta por red.
        gl_add_invoke_wait_hook() = [](Node* n, lua_State* th, lua_State* mL, int ref, int64_t cid, double to) {
            if (ScriptNodeBase* sn = Object::cast_to<ScriptNodeBase>(n))
                sn->add_waiting_invoke(th, mL, ref, cid, to);
        };

        // ── Math metatables ───────────────────────────────────────────────────
        //// ── Metatables matemáticas ────────────────────────────────────────────
        luaL_newmetatable(L_main, "Vector3");
        lua_pushcfunction(L_main, godot_vector3_index, "__index");   lua_setfield(L_main, -2, "__index");
        lua_pushcfunction(L_main, godot_vector3_add,   "__add");     lua_setfield(L_main, -2, "__add");
        lua_pushcfunction(L_main, godot_vector3_sub,   "__sub");     lua_setfield(L_main, -2, "__sub");
        lua_pushcfunction(L_main, godot_vector3_mul,   "__mul");     lua_setfield(L_main, -2, "__mul");
        lua_pushcfunction(L_main, godot_vector3_div,   "__div");     lua_setfield(L_main, -2, "__div");
        lua_pushcfunction(L_main, godot_vector3_unm,   "__unm");     lua_setfield(L_main, -2, "__unm");
        lua_pushcfunction(L_main, godot_vector3_eq,    "__eq");      lua_setfield(L_main, -2, "__eq");
        lua_pushcfunction(L_main, godot_vector3_tostring, "__tostring"); lua_setfield(L_main, -2, "__tostring");
        lua_pop(L_main, 1);

        luaL_newmetatable(L_main, "Color3");
        lua_pushcfunction(L_main, godot_color3_index, "__index"); lua_setfield(L_main, -2, "__index");
        lua_pop(L_main, 1);

        // ── Buscar game y workspace ───────────────────────────────────────────
        Node* game_node = nullptr;
        Node* ws_node = nullptr;
        {
            SceneTree* _st2 = get_tree();
            Node* root = _st2 ? (Node*)_st2->get_root() : nullptr;
            if (!root) return;
            // Buscar nodo "game": RobloxTemplate, RobloxGame3D, RobloxGame2D,
            // o cualquier nodo llamado "Game"
            for (int _i = 0; _i < root->get_child_count() && !game_node; _i++) {
                Node* ch = root->get_child(_i);
                if (ch && (ch->is_class("RobloxTemplate") ||
                            ch->is_class("RobloxGame3D")   ||
                            ch->is_class("RobloxGame2D")   ||
                            ch->get_name() == StringName("Game"))) {
                    game_node = ch;
                } else if (ch) {
                    for (int _j = 0; _j < ch->get_child_count() && !game_node; _j++) {
                        Node* gc = ch->get_child(_j);
                        if (gc && (gc->is_class("RobloxTemplate") ||
                                    gc->is_class("RobloxGame3D")   ||
                                    gc->is_class("RobloxGame2D")   ||
                                    gc->get_name() == StringName("Game"))) {
                            game_node = gc;
                        }
                    }
                }
            }
            if (!game_node) game_node = root;
            ws_node = game_node->get_node_or_null("Workspace");
            if (!ws_node) ws_node = (Node*)get_viewport();
        }
        wrap_node(L_main, game_node); lua_setglobal(L_main, "game");
        wrap_node(L_main, ws_node);   lua_setglobal(L_main, "workspace");
        lua_pushnil(L_main);         lua_setglobal(L_main, "script");

        // ── Instance ──────────────────────────────────────────────────────────
        lua_newtable(L_main);
        lua_pushcfunction(L_main, godot_instance_new, "new");
        lua_setfield(L_main, -2, "new");
        lua_setglobal(L_main, "Instance");

        // ── Vector3 ───────────────────────────────────────────────────────────
        lua_newtable(L_main);
        lua_pushcfunction(L_main, godot_vector3_new,  "new");    lua_setfield(L_main, -2, "new");
        {
            LuauVector3* z = (LuauVector3*)lua_newuserdata(L_main, sizeof(LuauVector3));
            z->x = 0; z->y = 0; z->z = 0;
            luaL_getmetatable(L_main, "Vector3"); lua_setmetatable(L_main, -2);
            lua_setfield(L_main, -2, "zero");

            LuauVector3* o = (LuauVector3*)lua_newuserdata(L_main, sizeof(LuauVector3));
            o->x = 1; o->y = 1; o->z = 1;
            luaL_getmetatable(L_main, "Vector3"); lua_setmetatable(L_main, -2);
            lua_setfield(L_main, -2, "one");
        }
        lua_setglobal(L_main, "Vector3");

        // ── Color3 ────────────────────────────────────────────────────────────
        lua_newtable(L_main);
        lua_pushcfunction(L_main, godot_color3_new,      "new");     lua_setfield(L_main, -2, "new");
        lua_pushcfunction(L_main, godot_color3_from_rgb, "fromRGB"); lua_setfield(L_main, -2, "fromRGB");
        lua_setglobal(L_main, "Color3");

        // task/require are installed once by GLExecutionDomain and resolve the current owner.

        // ── print / warn / error ──────────────────────────────────────────────
        // Visible por defecto; se desactiva con godot_luau/script_output = false
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            if (!(bool)ProjectSettings::get_singleton()->get_setting("godot_luau/script_output", true))
                return 0;
            int n = lua_gettop(L);
            String msg;
            for (int i = 1; i <= n; i++) {
                msg += String(luaL_tolstring(L, i, nullptr));
                if (i < n) msg += "\t";
            }
            UtilityFunctions::print("[Luau] ", msg);
            return 0;
        }, "print");
        lua_setglobal(L_main, "print");

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            if (!(bool)ProjectSettings::get_singleton()->get_setting("godot_luau/script_output", true))
                return 0;
            int n = lua_gettop(L);
            String msg;
            for (int i = 1; i <= n; i++) {
                msg += String(luaL_tolstring(L, i, nullptr));
                if (i < n) msg += "\t";
            }
            UtilityFunctions::push_warning(msg);   // canal de advertencia real (antes era print)
            return 0;
        }, "warn");
        lua_setglobal(L_main, "warn");

        // ── dprint / dwarn: salida de los scripts internos del sistema ────────
        // Solo imprimen si godot_luau/debug_mode esta activo (Modo Debug).
        // Los templates del sistema (PlayerModule, Health, Chat...) los usan
        // para no ensuciar la consola del usuario.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            if (!(bool)ProjectSettings::get_singleton()->get_setting("godot_luau/debug_mode", false))
                return 0;
            int n = lua_gettop(L);
            String msg;
            for (int i = 1; i <= n; i++) {
                msg += String(luaL_tolstring(L, i, nullptr));
                if (i < n) msg += "\t";
            }
            UtilityFunctions::print("[Luau Debug] ", msg);
            return 0;
        }, "dprint");
        lua_setglobal(L_main, "dprint");

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            if (!(bool)ProjectSettings::get_singleton()->get_setting("godot_luau/debug_mode", false))
                return 0;
            int n = lua_gettop(L);
            String msg;
            for (int i = 1; i <= n; i++) {
                msg += String(luaL_tolstring(L, i, nullptr));
                if (i < n) msg += "\t";
            }
            UtilityFunctions::print("[Luau Debug WARN] ", msg);
            return 0;
        }, "dwarn");
        lua_setglobal(L_main, "dwarn");

        // error(message, level) — como en Lua/Roblox: level 0 omite la posición
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            int level = (int)luaL_optinteger(L, 2, 1);
            lua_settop(L, 1);
            if (lua_isstring(L, 1) && level > 0) {
                lua_Debug ar;
                if (lua_getinfo(L, level, "sl", &ar) && ar.currentline > 0) {
                    lua_pushfstring(L, "%s:%d: %s", ar.short_src, ar.currentline, lua_tostring(L, 1));
                    lua_replace(L, 1);
                }
            }
            lua_error(L);
            return 0;
        }, "error");
        lua_setglobal(L_main, "error");

        // ── wait (alias global de task.wait) ─────────────────────────────────
        lua_getglobal(L_main, "task"); lua_getfield(L_main, -1, "wait");
        lua_setglobal(L_main, "wait"); lua_pop(L_main, 1);

        // ── tick — tiempo Unix actual (segundos) ──────────────────────────────
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            lua_pushnumber(L, (double)Time::get_singleton()->get_unix_time_from_system());
            return 1;
        }, "tick");
        lua_setglobal(L_main, "tick");

        // ── time — game execution time (seconds) ─────────────────────────────
        //// ── time — tiempo de ejecución del juego (segundos) ───────────────────
        // En Roblox time() ES workspace.DistributedGameTime: el reloj del SERVIDOR,
        // sincronizado (1.14.8), no el uptime local de esta ventana.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            lua_pushnumber(L, gl_distributed_game_time());
            return 1;
        }, "time");
        lua_setglobal(L_main, "time");

        // ── typeof — tipo extendido (reconoce Vector3, Color3, Instance) ──────
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            int t = lua_type(L, 1);
            if (t == LUA_TUSERDATA && lua_getmetatable(L, 1)) {
                luaL_getmetatable(L, "Vector3");
                if (lua_rawequal(L, -1, -2)) { lua_pop(L, 2); lua_pushstring(L, "Vector3"); return 1; }
                lua_pop(L, 1);
                luaL_getmetatable(L, "Color3");
                if (lua_rawequal(L, -1, -2)) { lua_pop(L, 2); lua_pushstring(L, "Color3"); return 1; }
                lua_pop(L, 1);
                luaL_getmetatable(L, "GodotObject");
                if (lua_rawequal(L, -1, -2)) { lua_pop(L, 2); lua_pushstring(L, "Instance"); return 1; }
                lua_pop(L, 2);
                lua_pushstring(L, "userdata"); return 1;
            }
            // Tipos basados en tabla (Vector2, UDim2, CFrame, TweenInfo...) llevan
            // un campo __type en su metatable (lo pone la stdlib) → como Roblox.
            if (t == LUA_TTABLE && lua_getmetatable(L, 1)) {
                lua_getfield(L, -1, "__type");
                if (lua_isstring(L, -1)) { const char* tn = lua_tostring(L, -1); lua_pushstring(L, tn); return 1; }
                lua_pop(L, 2);
            }
            lua_pushstring(L, lua_typename(L, t));
            return 1;
        }, "typeof");
        lua_setglobal(L_main, "typeof");

        // ── pcall mejorado (ya viene de luaL_openlibs pero lo sobreescribimos) ─
        // El pcall nativo de Luau ya funciona correctamente, solo lo dejamos.

        // ── tostring / tonumber ───────────────────────────────────────────────
        // luaL_tolstring respeta __tostring y SIEMPRE deja un string en la cima
        // (el lua_tostring anterior devolvía la tabla/nil tal cual para no-strings).
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            luaL_tolstring(L, 1, nullptr);
            return 1;
        }, "tostring");
        lua_setglobal(L_main, "tostring");

        // tonumber(v, [base]) — soporta base (2..36) y hex 0x; rechaza basura final.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            if (!lua_isnoneornil(L, 2)) {
                int base = (int)luaL_checkinteger(L, 2);
                const char* s = luaL_checkstring(L, 1);
                if (base < 2 || base > 36) { lua_pushnil(L); return 1; }
                char* endp = nullptr;
                long val = strtol(s, &endp, base);
                // saltar espacios finales
                while (endp && (*endp == ' ' || *endp == '\t' || *endp == '\n')) endp++;
                if (endp && *endp == '\0' && endp != s) { lua_pushnumber(L, (double)val); return 1; }
                lua_pushnil(L); return 1;
            }
            if (lua_type(L, 1) == LUA_TNUMBER) { lua_pushvalue(L, 1); return 1; }
            if (lua_type(L, 1) == LUA_TSTRING) {
                const char* s = luaL_checkstring(L, 1);
                char* endp = nullptr;
                double n = strtod(s, &endp);
                while (endp && (*endp == ' ' || *endp == '\t' || *endp == '\n')) endp++;
                if (endp && *endp == '\0' && endp != s) { lua_pushnumber(L, n); return 1; }
            }
            lua_pushnil(L); return 1;
        }, "tonumber");
        lua_setglobal(L_main, "tonumber");

        // ── UserInputService ─────────────────────────────────────────────────
        lua_newtable(L_main);

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            int n = lua_gettop(L);
            int arg = (n >= 2) ? 2 : 1;
            Input* inp = Input::get_singleton();
            Key code = KEY_UNKNOWN;

            // Accepts Enum.KeyCode (number) OR legacy string ("LeftShift", "W", etc.)
            //// Acepta Enum.KeyCode (número) O string legacy ("LeftShift", "W", etc.)
            if (lua_type(L, arg) == LUA_TNUMBER) {
                code = roblox_keycode_to_godot((int)lua_tonumber(L, arg));
            } else {
                const char* key_name = luaL_checkstring(L, arg);
                if      (strcmp(key_name, "W") == 0 || strcmp(key_name, "Up") == 0)       code = KEY_W;
                else if (strcmp(key_name, "A") == 0 || strcmp(key_name, "Left") == 0)     code = KEY_A;
                else if (strcmp(key_name, "S") == 0 || strcmp(key_name, "Down") == 0)     code = KEY_S;
                else if (strcmp(key_name, "D") == 0 || strcmp(key_name, "Right") == 0)    code = KEY_D;
                else if (strcmp(key_name, "Space") == 0)     code = KEY_SPACE;
                else if (strcmp(key_name, "E") == 0)         code = KEY_E;
                else if (strcmp(key_name, "Q") == 0)         code = KEY_Q;
                else if (strcmp(key_name, "F") == 0)         code = KEY_F;
                else if (strcmp(key_name, "G") == 0)         code = KEY_G;
                else if (strcmp(key_name, "H") == 0)         code = KEY_H;
                else if (strcmp(key_name, "I") == 0)         code = KEY_I;
                else if (strcmp(key_name, "J") == 0)         code = KEY_J;
                else if (strcmp(key_name, "K") == 0)         code = KEY_K;
                else if (strcmp(key_name, "L") == 0)         code = KEY_L;
                else if (strcmp(key_name, "M") == 0)         code = KEY_M;
                else if (strcmp(key_name, "N") == 0)         code = KEY_N;
                else if (strcmp(key_name, "O") == 0)         code = KEY_O;
                else if (strcmp(key_name, "P") == 0)         code = KEY_P;
                else if (strcmp(key_name, "R") == 0)         code = KEY_R;
                else if (strcmp(key_name, "T") == 0)         code = KEY_T;
                else if (strcmp(key_name, "U") == 0)         code = KEY_U;
                else if (strcmp(key_name, "V") == 0)         code = KEY_V;
                else if (strcmp(key_name, "X") == 0)         code = KEY_X;
                else if (strcmp(key_name, "Y") == 0)         code = KEY_Y;
                else if (strcmp(key_name, "Z") == 0)         code = KEY_Z;
                else if (strcmp(key_name, "C") == 0)         code = KEY_C;
                else if (strcmp(key_name, "B") == 0)         code = KEY_B;
                else if (strcmp(key_name, "0") == 0)         code = KEY_0;
                else if (strcmp(key_name, "1") == 0)         code = KEY_1;
                else if (strcmp(key_name, "2") == 0)         code = KEY_2;
                else if (strcmp(key_name, "3") == 0)         code = KEY_3;
                else if (strcmp(key_name, "4") == 0)         code = KEY_4;
                else if (strcmp(key_name, "5") == 0)         code = KEY_5;
                else if (strcmp(key_name, "6") == 0)         code = KEY_6;
                else if (strcmp(key_name, "7") == 0)         code = KEY_7;
                else if (strcmp(key_name, "8") == 0)         code = KEY_8;
                else if (strcmp(key_name, "9") == 0)         code = KEY_9;
                else if (strcmp(key_name, "LeftShift")   == 0 || strcmp(key_name, "RightShift")   == 0) code = KEY_SHIFT;
                else if (strcmp(key_name, "LeftControl") == 0 || strcmp(key_name, "RightControl") == 0) code = KEY_CTRL;
                else if (strcmp(key_name, "LeftAlt")     == 0 || strcmp(key_name, "RightAlt")     == 0) code = KEY_ALT;
                else if (strcmp(key_name, "Return")      == 0 || strcmp(key_name, "Enter")        == 0) code = KEY_ENTER;
                else if (strcmp(key_name, "Escape")      == 0) code = KEY_ESCAPE;
                else if (strcmp(key_name, "Tab")         == 0) code = KEY_TAB;
                else if (strcmp(key_name, "Backspace")   == 0) code = KEY_BACKSPACE;
                else if (strcmp(key_name, "Delete")      == 0) code = KEY_DELETE;
                else if (strcmp(key_name, "Insert")      == 0) code = KEY_INSERT;
                else if (strcmp(key_name, "Home")        == 0) code = KEY_HOME;
                else if (strcmp(key_name, "End")         == 0) code = KEY_END;
                else if (strcmp(key_name, "PageUp")      == 0) code = KEY_PAGEUP;
                else if (strcmp(key_name, "PageDown")    == 0) code = KEY_PAGEDOWN;
                else if (strcmp(key_name, "Up")          == 0) code = KEY_UP;
                else if (strcmp(key_name, "Down")        == 0) code = KEY_DOWN;
                else if (strcmp(key_name, "Left")        == 0) code = KEY_LEFT;
                else if (strcmp(key_name, "Right")       == 0) code = KEY_RIGHT;
                else if (strcmp(key_name, "F1")  == 0) code = KEY_F1;
                else if (strcmp(key_name, "F2")  == 0) code = KEY_F2;
                else if (strcmp(key_name, "F3")  == 0) code = KEY_F3;
                else if (strcmp(key_name, "F4")  == 0) code = KEY_F4;
                else if (strcmp(key_name, "F5")  == 0) code = KEY_F5;
                else if (strcmp(key_name, "F6")  == 0) code = KEY_F6;
                else if (strcmp(key_name, "F7")  == 0) code = KEY_F7;
                else if (strcmp(key_name, "F8")  == 0) code = KEY_F8;
                else if (strcmp(key_name, "F9")  == 0) code = KEY_F9;
                else if (strcmp(key_name, "F10") == 0) code = KEY_F10;
                else if (strcmp(key_name, "F11") == 0) code = KEY_F11;
                else if (strcmp(key_name, "F12") == 0) code = KEY_F12;
            }

            lua_pushboolean(L, inp ? inp->is_key_pressed(code) : false);
            return 1;
        }, "IsKeyDown");
        lua_setfield(L_main, -2, "IsKeyDown");

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            int n = lua_gettop(L);
            int btn = (n >= 2) ? (int)luaL_checknumber(L, 2) : (int)luaL_checknumber(L, 1);
            Input* inp = Input::get_singleton();
            MouseButton mb = (btn == 1) ? MOUSE_BUTTON_LEFT :
                             (btn == 2) ? MOUSE_BUTTON_RIGHT :
                                          MOUSE_BUTTON_MIDDLE;
            lua_pushboolean(L, inp ? inp->is_mouse_button_pressed(mb) : false);
            return 1;
        }, "IsMouseButtonPressed");
        lua_setfield(L_main, -2, "IsMouseButtonPressed");

        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            Input* inp = Input::get_singleton();
            Vector2 delta = inp ? inp->get_last_mouse_velocity() * 0.001f : Vector2();
            lua_newtable(L);
            lua_pushnumber(L, delta.x); lua_setfield(L, -2, "X");
            lua_pushnumber(L, delta.y); lua_setfield(L, -2, "Y");
            return 1;
        }, "GetMouseDelta");
        lua_setfield(L_main, -2, "GetMouseDelta");

        // Un ServerScript no puede leer entrada de hardware (igual que Roblox):
        // sustituimos la tabla por un proxy que lanza un error claro al usarse.
        if (get_class() == "ServerScript") {
            lua_pop(L_main, 1);  // descartar la tabla real de UserInputService
            lua_newtable(L_main);
            lua_newtable(L_main);  // metatable
            lua_pushcfunction(L_main, [](lua_State* L) -> int {
                luaL_error(L, "UserInputService no esta disponible en un ServerScript: "
                              "la entrada (teclado/raton/tactil) solo existe en el cliente (LocalScript).");
                return 0;
            }, "__index");
            lua_setfield(L_main, -2, "__index");
            lua_setmetatable(L_main, -2);
        }
        lua_setglobal(L_main, "UserInputService");

        // ── require ───────────────────────────────────────────────────────────
        setup_remotefunction_system(L_main);

        // ── _FileAccess — I/O de archivos para DataStoreService ───────────────
        lua_newtable(L_main);
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* path = luaL_checkstring(L, 1);
            Ref<FileAccess> f = FileAccess::open(String(path), FileAccess::READ);
            if (f.is_null()) { lua_pushnil(L); return 1; }
            String s = f->get_as_text();
            lua_pushstring(L, s.utf8().get_data());
            return 1;
        }, "read");     lua_setfield(L_main, -2, "read");
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* path = luaL_checkstring(L, 1);
            const char* data = luaL_checkstring(L, 2);
            Ref<FileAccess> f = FileAccess::open(String(path), FileAccess::WRITE);
            if (!f.is_null()) f->store_string(String(data));
            return 0;
        }, "write");    lua_setfield(L_main, -2, "write");
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            lua_pushboolean(L, FileAccess::file_exists(String(luaL_checkstring(L, 1))) ? 1 : 0);
            return 1;
        }, "exists");   lua_setfield(L_main, -2, "exists");
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            DirAccess::remove_absolute(String(luaL_checkstring(L, 1)));
            return 0;
        }, "delete");   lua_setfield(L_main, -2, "delete");
        // Listar archivos de un directorio: lo usa el MessagingService entre
        // instancias (1.14.16) para ver los buzones de los demás servidores.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            Ref<DirAccess> d = DirAccess::open(String(luaL_checkstring(L, 1)));
            lua_newtable(L);
            if (d.is_null()) return 1;
            PackedStringArray files = d->get_files();
            for (int i = 0; i < files.size(); i++) {
                lua_pushstring(L, files[i].utf8().get_data());
                lua_rawseti(L, -2, i + 1);
            }
            return 1;
        }, "list");     lua_setfield(L_main, -2, "list");
        lua_setglobal(L_main, "_FileAccess");

        // ── _GL_NET_ROLE — 0 single-player, 1 servidor/host, 2 cliente ───────
        // Lo usa el DataStoreService del stdlib para no dejar que un cliente
        // toque los datos (en Roblox eso es error). Aquí importa el doble: TODAS
        // las ventanas del proyecto comparten `user://`, así que un cliente
        // escribiendo pisaría literalmente los archivos del servidor.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            lua_pushnumber(L, GLIsClient(L) ? 2.0 : (double)gl_net_role());
            return 1;
        }, "_GL_NET_ROLE");
        lua_setglobal(L_main, "_GL_NET_ROLE");

        // ── _GL_VM_ID — id único de esta VM dentro del proceso (1.14.16) ─────
        // MessagingService owns one mailbox per domain VM. Local subscriptions
        // share its service state; the stdlib asks once during domain bootstrap.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            static int64_t ctr = 0;
            lua_pushnumber(L, (double)(++ctr));
            return 1;
        }, "_GL_VM_ID");
        lua_setglobal(L_main, "_GL_VM_ID");

        // ── _GL_NET — puente al NetworkService para el stdlib (1.14.17) ──────
        // Lo usa TeleportService. Se resuelve por ObjectID y se llama por NOMBRE,
        // asi que el stdlib no depende de roblox_network.h.
        lua_newtable(L_main);
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            Object* ns = ObjectDB::get_instance(gl_net_service_id());
            if (!ns) { lua_pushnil(L); return 1; }
            const char* m = luaL_checkstring(L, 1);
            // (metodo, arg1, arg2, arg3) -> Variant; solo lo que necesita el stdlib
            Variant r;
            if (lua_gettop(L) >= 4)      r = ns->call(StringName(m), (int64_t)luaL_checknumber(L, 2),
                                                     (int64_t)luaL_checknumber(L, 3), String(luaL_checkstring(L, 4)));
            else if (lua_gettop(L) >= 2) r = ns->call(StringName(m), (int64_t)luaL_checknumber(L, 2));
            else                          r = ns->call(StringName(m));
            if (r.get_type() == Variant::STRING)      lua_pushstring(L, String(r).utf8().get_data());
            else if (r.get_type() == Variant::BOOL)   lua_pushboolean(L, (bool)r ? 1 : 0);
            else if (r.get_type() == Variant::INT)    lua_pushnumber(L, (double)(int64_t)r);
            else if (r.get_type() == Variant::PACKED_INT32_ARRAY) {
                PackedInt32Array a = r;
                lua_newtable(L);
                for (int i = 0; i < a.size(); i++) { lua_pushnumber(L, a[i]); lua_rawseti(L, -2, i + 1); }
            }
            else lua_pushnil(L);
            return 1;
        }, "call");
        lua_setfield(L_main, -2, "call");
        // Teleport necesita pasar el NODO del jugador, no un numero.
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            Object* ns = ObjectDB::get_instance(gl_net_service_id());
            GodotObjectWrapper* w = (GodotObjectWrapper*)lua_touserdata(L, 1);
            Node* plr = w ? gow_node(w) : nullptr;
            if (!ns || !plr) { lua_pushnumber(L, 0); return 1; }
            int port = (int)luaL_optnumber(L, 2, 0);
            String data = lua_isstring(L, 3) ? String(lua_tostring(L, 3)) : String();
            Variant r = ns->call("net_teleport_player", (Object*)plr, port, data);
            lua_pushnumber(L, (double)(int64_t)r);
            return 1;
        }, "teleport");
        lua_setfield(L_main, -2, "teleport");
        lua_setglobal(L_main, "_GL_NET");

        // ── _JSON — JSON serialization ────────────────────────────────────────
        //// ── _JSON — serialización JSON ────────────────────────────────────────
        lua_newtable(L_main);
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            Variant v = _gdluau_lua_to_variant(L, 1);
            String result = JSON::stringify(v, "", false, true);
            lua_pushstring(L, result.utf8().get_data());
            return 1;
        }, "encode");   lua_setfield(L_main, -2, "encode");
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* s = luaL_checkstring(L, 1);
            Variant v = JSON::parse_string(String(s));
            _gdluau_variant_to_lua(L, v);
            return 1;
        }, "decode");   lua_setfield(L_main, -2, "decode");
        lua_setglobal(L_main, "_JSON");

        // ── _HTTP — cliente HTTP real (bloqueante, vía HTTPClient) ────────────
        lua_newtable(L_main);
        // _HTTP.request(method, url, body?, headers?) → {Success,StatusCode,StatusMessage,Body}
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            String method = gl_arg_present(L, 1) ? String(luaL_checkstring(L, 1)) : String("GET");
            const char* url = luaL_checkstring(L, 2);
            String body = gl_arg_present(L, 3) ? String(luaL_checkstring(L, 3)) : String();
            PackedStringArray headers = gl_lua_headers_to_array(L, 4);
            GLHttpResult r = gl_http_perform(gl_http_method_from_string(method), String(url), headers, body);
            lua_newtable(L);
            lua_pushboolean(L, r.ok ? 1 : 0);                  lua_setfield(L, -2, "Success");
            lua_pushnumber(L, (double)r.status);               lua_setfield(L, -2, "StatusCode");
            lua_pushstring(L, r.status_msg.utf8().get_data()); lua_setfield(L, -2, "StatusMessage");
            lua_pushstring(L, r.body.utf8().get_data());       lua_setfield(L, -2, "Body");
            return 1;
        }, "request");  lua_setfield(L_main, -2, "request");
        // _HTTP.get(url, headers?) → body
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* url = luaL_checkstring(L, 1);
            PackedStringArray headers = gl_lua_headers_to_array(L, 2);
            GLHttpResult r = gl_http_perform(HTTPClient::METHOD_GET, String(url), headers, String());
            lua_pushstring(L, r.body.utf8().get_data());
            return 1;
        }, "get");     lua_setfield(L_main, -2, "get");
        // _HTTP.post(url, body?, contentType?, headers?) → body
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* url = luaL_checkstring(L, 1);
            String body  = gl_arg_present(L, 2) ? String(luaL_checkstring(L, 2)) : String();
            String ctype = gl_arg_present(L, 3) ? String(luaL_checkstring(L, 3)) : String("application/json");
            PackedStringArray headers = gl_lua_headers_to_array(L, 4);
            headers.push_back(String("Content-Type: ") + ctype);
            GLHttpResult r = gl_http_perform(HTTPClient::METHOD_POST, String(url), headers, body);
            lua_pushstring(L, r.body.utf8().get_data());
            return 1;
        }, "post");    lua_setfield(L_main, -2, "post");
        lua_setglobal(L_main, "_HTTP");

        // ── _InstanceNew — crear instancias en runtime ────────────────────────
        lua_pushcfunction(L_main, [](lua_State* L) -> int {
            const char* class_name = luaL_checkstring(L, 1);
            Object* obj = ClassDB::instantiate(StringName(class_name));
            Node* node  = Object::cast_to<Node>(obj);
            if (!node) { if (obj) memdelete(obj); lua_pushnil(L); return 1; }
            wrap_node(L, node);
            gl_track_orphan(node);   // sin padre = lo libera el cierre (1.15)
            return 1;
        }, "_InstanceNew");
        lua_setglobal(L_main, "_InstanceNew");

        // ── Ejecutar stdlib (servicios Lua, class(), Enum, TweenInfo…) ────────
        Runtime.ExposeBootstrapSpawner();
        {
            std::string sbc = Luau::compile(LUAU_STDLIB_CODE);
            if (luau_load(L_main, "__GodotLuauStdlib", sbc.data(), sbc.size(), 0) == 0) {
                if (lua_pcall(L_main, 0, 0, 0) != LUA_OK) {
                    UtilityFunctions::print("[GodotLuau Stdlib Error] ", lua_tostring(L_main, -1));
                    lua_pop(L_main, 1);
                }
            } else {
                UtilityFunctions::print("[GodotLuau Stdlib Syntax] ", lua_tostring(L_main, -1));
                lua_pop(L_main, 1);
            }
        }
        lua_pushnil(L_main); lua_setglobal(L_main, "_GLDomainSpawn");
    }

    // RemoteFunction por red (1.14.6): corre el handler (OnServerInvoke/
    // OnClientInvoke) en la máquina remota con soporte de yield y devuelve el
    // resultado al invocador. El invocador cede su hilo (add_waiting_invoke) y
    // _process lo reanuda con la respuesta (gl_net_responses).
    void setup_remotefunction_system(lua_State* L) {
        // C: tras correr el handler, empaqueta sus retornos y pide al
        // NetworkService que los mande al invocador. (callId, replyPeer, ok, ...rets)
        lua_pushcfunction(L, [](lua_State* L) -> int {
            int64_t call_id = (int64_t)luaL_checknumber(L, 1);
            int     reply_peer = (int)luaL_checknumber(L, 2);
            bool    ok = lua_toboolean(L, 3) != 0;
            Array rets;
            int top = lua_gettop(L);
            for (int i = 4; i <= top; i++) {
                gl_net_encode_err() = String();
                Variant rv = gl_net_encode(L, i);
                if (!gl_net_encode_err().is_empty()) {
                    // El handler devolvió algo no serializable: en vez de mandar nil
                    // en silencio, el invocador recibe el error.
                    String what = gl_net_encode_err();
                    gl_net_encode_err() = String();
                    ok = false;
                    rets = Array();
                    rets.push_back(String("RemoteFunction handler returned a value that cannot be sent over the network (" + what + ")"));
                    break;
                }
                rets.push_back(rv);
            }
            if (Node* ns = Object::cast_to<Node>(ObjectDB::get_instance(gl_net_service_id())))
                ns->call("net_rf_respond", reply_peer, (int)call_id, ok, rets);
            return 0;
        }, "__gl_rf_respond");
        lua_setglobal(L, "__gl_rf_respond");

        // Lua: corre el handler en un task.spawn (así puede ceder: WaitForChild,
        // task.wait, DataStore...) y al terminar responde. isServer decide si el
        // handler recibe el Player (OnServerInvoke(player,...) vs OnClientInvoke(...)).
        static const char* GL_RF_LUA =
            "function __gl_rf_serve(handler, player, callId, replyPeer, isServer, ...)\n"
            "  local args = table.pack(...)\n"
            "  task.spawn(function()\n"
            "    local packed\n"
            "    if isServer then packed = table.pack(pcall(handler, player, table.unpack(args, 1, args.n)))\n"
            "    else packed = table.pack(pcall(handler, table.unpack(args, 1, args.n))) end\n"
            "    if not packed[1] then warn('RemoteFunction handler error: ' .. tostring(packed[2])) end\n"
            "    __gl_rf_respond(callId, replyPeer, table.unpack(packed, 1, packed.n))\n"
            "  end)\n"
            "end\n";
        std::string bc = Luau::compile(GL_RF_LUA);
        if (luau_load(L, "=__gl_rf", bc.data(), bc.size(), 0) == 0) {
            if (lua_pcall(L, 0, 0, 0) != LUA_OK) { UtilityFunctions::print("[GodotLuau rf setup] ", lua_tostring(L, -1)); lua_pop(L, 1); }
        } else { UtilityFunctions::print("[GodotLuau rf syntax] ", lua_tostring(L, -1)); lua_pop(L, 1); }
    }

    // Godot binds the immutable callback reference; module-owned connections use
    // the same relay without borrowing an executable script's identity.
    void _gl_child_event(Node* Child, int Reference) {
        lua_State* Anchor = GLReferenceState(Reference);
        if (!Anchor || !Child) return;
        lua_State* Thread = lua_newthread(Anchor);
        lua_rawgeti(Thread, LUA_REGISTRYINDEX, Reference);
        if (lua_isfunction(Thread, -1)) {
            wrap_node(Thread, Child);
            GLResume(Thread, nullptr, 1);
        }
        lua_pop(Anchor, 1);
    }

    void _ready() override {
        if (!Engine::get_singleton()->is_editor_hint()) {
            call_deferred("iniciar_corrutina");
        }
    }
};

// ════════════════════════════════════════════════════════════════════
//  Concrete script types
////  Tipos concretos de script
// ════════════════════════════════════════════════════════════════════
class ServerScript : public ScriptNodeBase {
    GDCLASS(ServerScript, ScriptNodeBase);
protected:
    static void _bind_methods() {
        // Como en Roblox Studio: Enabled true por defecto; desmarcado no corre.
        // Solo los scripts ejecutables la exponen (los métodos viven en la base).
        ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Enabled"), "set_enabled", "get_enabled");
    }
};

class LocalScript : public ScriptNodeBase {
    GDCLASS(LocalScript, ScriptNodeBase);
protected:
    static void _bind_methods() {
        ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Enabled"), "set_enabled", "get_enabled");
    }
};

// ModuleScript NO expone "Enabled" (igual que Roblox Studio): un módulo no se
// ejecuta por sí mismo, solo se hace require(). Hereda source/script_id de la base.
class ModuleScript : public ScriptNodeBase {
    GDCLASS(ModuleScript, ScriptNodeBase);
protected:
    static void _bind_methods() {}
};

#endif // LUAU_SCRIPT_NODE_H
