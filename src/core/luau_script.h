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

#include "gl_domain_host.h"
#include "gl_runtime.h"
#include "gl_errors.h"

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
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "lua.h"
#include "lualib.h"

#include "gl_debug.h"   // GL_DEBUG_PRINT + gl_tr3

#include <godot_cpp/core/class_db.hpp>

#include <functional>
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

class LuauScript : public ScriptExtension {
    GDCLASS(LuauScript, ScriptExtension);

protected:
    static void _bind_methods() {}
    String source_code;
    uint64_t SourceRevision = 0;

public:
    String _get_source_code() const override { return source_code; }
    uint64_t GetSourceRevision() const { return SourceRevision; }
    void _set_source_code(const String &p_code) override {
        if (source_code != p_code) {
            source_code = p_code;
            ++SourceRevision; // visible before any changed-signal subscriber can require
            emit_changed();
        }
    }
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

    void InitializeDomain(GLExecutionDomain& Runtime);

    // RemoteFunction por red (1.14.6): corre el handler (OnServerInvoke/
    // OnClientInvoke) en la máquina remota con soporte de yield y devuelve el
    // resultado al invocador. El invocador cede su hilo (add_waiting_invoke) y
    // _process lo reanuda con la respuesta (gl_net_responses).
    void setup_remotefunction_system(lua_State* L);

    // Godot binds the immutable callback reference; module-owned connections use
    // the same relay without borrowing an executable script's identity.
    void _gl_child_event(Node* Child, int Reference);

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
