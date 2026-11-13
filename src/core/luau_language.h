#ifndef LUAU_LANGUAGE_H
#define LUAU_LANGUAGE_H

#include "luau_script.h"
#include "luau_autocomplete.h"
#include "Luau/Compiler.h"
#include "gl_debugger.h"
#include "gl_debug_inspection.h"
#include "gl_runtime_debugger.h"
#include <godot_cpp/classes/script_language_extension.hpp>
#include <godot_cpp/classes/resource_format_loader.hpp>
#include <godot_cpp/classes/resource_format_saver.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class LuauLanguage : public ScriptLanguageExtension {
    GDCLASS(LuauLanguage, ScriptLanguageExtension);

public:
    inline static LuauLanguage* singleton = nullptr;
    static LuauLanguage* get_singleton() { return singleton; }

    LuauLanguage()  { singleton = this; }
    ~LuauLanguage() { if (singleton == this) singleton = nullptr; }

    // Godot 4.4+ adds this virtual beyond the pinned 4.3 generated interface.
    // Use its actual Array ABI and existing source/generation invalidation.
    static void _call_reload_scripts(GDExtensionClassInstancePtr, const GDExtensionConstTypePtr* Arguments, GDExtensionTypePtr) {
        GLReloadLuauScripts(PtrToArg<Array>::convert(Arguments[0]));
    }
    static void _bind_methods() {
        ClassDB::bind_virtual_method(get_class_static(), "_reload_scripts", _call_reload_scripts);
    }

    String _get_name()      const override { return "Luau"; }
    String _get_type()      const override { return "LuauScript"; }
    String _get_extension() const override { return "luau"; }

    PackedStringArray _get_recognized_extensions() const override {
        PackedStringArray a; a.append("lua"); a.append("luau"); return a;
    }
    Object* _create_script() const override { return memnew(LuauScript); }
    bool    _can_inherit_from_file() const override { return false; }

    PackedStringArray _get_reserved_words() const override {
        PackedStringArray w;
        static const char* words[] = {
            "and","break","do","else","elseif","end","false","for","function",
            "if","in","local","nil","not","or","repeat","return","then","true",
            "until","while","continue","self","type","export",nullptr
        };
        for (int i = 0; words[i]; i++) w.append(words[i]);
        return w;
    }

    PackedStringArray _get_string_delimiters()  const override {
        PackedStringArray a; a.append("\" \""); a.append("' '"); a.append("[[ ]]"); return a;
    }
    PackedStringArray _get_comment_delimiters() const override {
        PackedStringArray a; a.append("--[[ ]]"); a.append("--"); return a;
    }
    PackedStringArray _get_doc_comment_delimiters() const override { return PackedStringArray(); }

    bool _is_control_flow_keyword(const String& kw) const override {
        return kw=="if"||kw=="elseif"||kw=="else"||kw=="for"||kw=="while"||
               kw=="repeat"||kw=="until"||kw=="break"||kw=="return"||kw=="continue";
    }

    Dictionary _complete_code(const String& p_code, const String& p_path, Object* p_owner) const override {
        return LuauAutocomplete::get_suggestions(p_code, p_path, p_owner);
    }

    // Hover documentation — language-aware, with BBCode formatting and Learn More link
    bool _supports_documentation() const override { return true; }

    Dictionary _lookup_code(const String& code, const String& symbol, const String& path, Object* owner) const override {
        return GLNavigateNativeCode(code,symbol,path);
    }
    int32_t _find_function(const String& Name,const String& Code) const override {
        Dictionary Result=GLNavigateNativeCode(Code,Name,String());
        return int(Result["result"])==OK && int(Result["type"])==LOOKUP_RESULT_SCRIPT_LOCATION?int(Result["location"]):-1;
    }
    String _auto_indent_code(const String& Code,int32_t,int32_t) const override { return Code; }

    void _frame()            override {}
    void _thread_enter()     override {}
    void _thread_exit()      override {}
    void _reload_all_scripts() override {}
    void _reload_tool_script(const Ref<Script>& Source, bool) override {
        Array Scripts;Scripts.push_back(Source);GLReloadLuauScripts(Scripts);
    }

    bool _handles_global_class_type(const String& p_type) const override { return p_type == "LuauScript"; }
    Dictionary _get_global_class_name(const String& p_path) const override { return Dictionary(); }
    String _debug_get_error() const override {
        auto Debugger=GLGetSuspendedDebugger();
        if(!Debugger)return String();
        Dictionary Context=GLDebugContext();
        return String("[Debugger:Luau] ")+String(Context.get("Domain",String()))+" generation "+
            String::num_uint64(Debugger->GetGeneration())+" - "+String::utf8(Debugger->GetReason().c_str());
    }
    int32_t _debug_get_stack_level_count() const override {
        auto Debugger=GLGetSuspendedDebugger(); return Debugger?int32_t(Debugger->GetFrames().size()):0;
    }
    int32_t _debug_get_stack_level_line(int32_t Level) const override {
        auto Debugger=GLGetSuspendedDebugger(); auto Frames=Debugger?Debugger->GetFrames():std::vector<GLDebugFrame>();
        return Level>=0 && size_t(Level)<Frames.size()?Frames[Level].Line:0;
    }
    String _debug_get_stack_level_source(int32_t Level) const override {
        auto Debugger=GLGetSuspendedDebugger(); auto Frames=Debugger?Debugger->GetFrames():std::vector<GLDebugFrame>();
        return Level>=0 && size_t(Level)<Frames.size()?String::utf8(Frames[Level].Source.c_str()):String();
    }
    String _debug_get_stack_level_function(int32_t Level) const override {
        auto Debugger=GLGetSuspendedDebugger(); auto Frames=Debugger?Debugger->GetFrames():std::vector<GLDebugFrame>();
        return Level>=0 && size_t(Level)<Frames.size()?String::utf8(Frames[Level].Function.c_str()):String();
    }
    Dictionary _debug_get_stack_level_locals(int32_t Level,int32_t Items,int32_t Depth) override { return GLDebugVariables(Level,Items,Depth,false); }
    Dictionary _debug_get_stack_level_members(int32_t Level,int32_t Items,int32_t Depth) override { return GLDebugVariables(Level,Items,Depth,true); }
    void* _debug_get_stack_level_instance(int32_t) override { return nullptr; }
    Dictionary _debug_get_globals(int32_t,int32_t) override {
        Dictionary Result; PackedStringArray Names; Array Values; auto Context=GLDebugContext();
        Array Keys=Context.keys();
        for(int Index=0;Index<Keys.size();++Index) { Variant Key=Keys[Index];Names.push_back(Key); Values.push_back(Context[Key]); }
        Result["globals"]=Names; Result["values"]=Values; return Result;
    }
    String _debug_parse_stack_level_expression(int32_t Level,const String& Expression,int32_t,int32_t) override {
        Dictionary Result=GLDebugEvaluate(Level,Expression);
        return bool(Result.get("Ok",false))?String(Result.get("Value",Variant())).left(4096):String(Result.get("Error",String()));
    }
    TypedArray<Dictionary> _debug_get_current_stack_info() override {
        TypedArray<Dictionary> Result; auto Debugger=GLGetSuspendedDebugger();
        if(Debugger) for(const auto& Frame:Debugger->GetFrames()) {
            Dictionary Item; Item["file"]=String::utf8(Frame.Source.c_str()); Item["line"]=Frame.Line;
            Item["func"]=String::utf8(Frame.Function.c_str()); Result.push_back(Item);
        }
        return Result;
    }
    TypedArray<Dictionary> _get_public_functions() const override { return TypedArray<Dictionary>(); }
    Dictionary _get_public_constants() const override { return Dictionary(); }
    TypedArray<Dictionary> _get_public_annotations() const override { return TypedArray<Dictionary>(); }

    bool _supports_builtin_mode()  const override { return false; }
    bool _can_make_function()      const override { return false; }
    bool _overrides_external_editor() override    { return false; }
    bool _is_using_templates()     override       { return true; }

    static constexpr const char* DEFAULT_TEMPLATE =
        "-->GodotLuau Developed by PimpoliDev\n"
        "print(\"Hello World\" .. \" the script \" .. script.Name .. \" he was executed\")\n";

    TypedArray<Dictionary> _get_built_in_templates(const StringName& p_object) const override {
        TypedArray<Dictionary> templates;
        Dictionary t;
        t["inherit"]     = String(p_object);
        t["name"]        = "Default";
        t["description"] = "Basic Luau script";
        t["content"]     = String(DEFAULT_TEMPLATE);
        t["id"]          = 0;
        t["origin"]      = 0;
        templates.push_back(t);
        return templates;
    }

    Ref<Script> _make_template(const String& p_template, const String& p_class, const String& p_base) const override {
        Ref<LuauScript> scr;
        scr.instantiate();
        String content = p_template.is_empty() ? String(DEFAULT_TEMPLATE) : p_template;
        content = content.replace("_NAME_", p_class.is_empty() ? String("NewScript") : p_class)
                         .replace("_BASE_", p_base);
        scr->_set_source_code(content);
        return scr;
    }

    // Validación real: compila con Luau y reporta línea y mensaje del error
    Dictionary _validate(const String& s, const String& p, bool pf, bool pe, bool pw, bool psl) const override {
        Dictionary d;
        std::string bc = Luau::compile(s.utf8().get_data());
        // Bytecode de error: byte 0 seguido de ":<línea>: <mensaje>"
        if (!bc.empty() && bc[0] == '\0') {
            String err = String::utf8(bc.c_str() + 1, (int)bc.size() - 1);
            int line = 1;
            String message = err;
            if (err.begins_with(":")) {
                int second = err.find(":", 1);
                if (second > 1) {
                    line = err.substr(1, second - 1).to_int();
                    message = err.substr(second + 1).strip_edges();
                }
            }
            d["valid"] = false;
            if (pe) {
                Array errors;
                Dictionary e;
                e["line"]    = line;
                e["column"]  = 1;
                e["message"] = message;
                e["path"]    = p;
                errors.push_back(e);
                d["errors"] = errors;
            }
            return d;
        }
        d["valid"] = true;
        Dictionary Native=GLInspectNativeCode(s,p);
        Array Diagnostics=Native["Diagnostics"];
        if (!Diagnostics.is_empty()) {
            d["valid"]=false;
            if (pe) d["errors"]=Diagnostics;
        }
        return d;
    }

    void _init()   override {}
    void _finish() override {}
};

class LuauLoader : public ResourceFormatLoader {
    GDCLASS(LuauLoader, ResourceFormatLoader);
protected:
    static void _bind_methods() {}
public:
    PackedStringArray _get_recognized_extensions() const override { PackedStringArray a; a.append("lua"); a.append("luau"); return a; }
    bool _handles_type(const StringName& t) const override { return t == StringName("LuauScript") || t == StringName("Script"); }
    // SOLO los .lua son nuestros. Antes devolvia "LuauScript" para CUALQUIER
    // ruta y el editor intentaba cargar plugin.cfg/README.md/.luau_ids.cfg
    // como recursos → "No loader found for resource" en cada arranque.
    String _get_resource_type(const String& p) const override {
        String Extension=p.get_extension().to_lower();
        return Extension == "lua" || Extension == "luau" ? String("LuauScript") : String();
    }
    Variant _load(const String& p, const String& op, bool st, int cm) const override {
        Ref<LuauScript> s; s.instantiate();
        Ref<FileAccess> f = FileAccess::open(p, FileAccess::READ);
        if (f.is_null()) return ERR_CANT_OPEN;
        if (f->get_length()>16*1024*1024) return ERR_FILE_CORRUPT;
        s->_set_source_code(f->get_as_text()); f->close();
        return s;
    }
};

class LuauSaver : public ResourceFormatSaver {
    GDCLASS(LuauSaver, ResourceFormatSaver);
protected:
    static void _bind_methods() {}
public:
    Error _save(const Ref<Resource>& r, const String& p, uint32_t f) override {
        Ref<LuauScript> s = r;
        if (s.is_null()) return ERR_INVALID_PARAMETER;
        Ref<FileAccess> file = FileAccess::open(p, FileAccess::WRITE);
        if (file.is_null()) return ERR_CANT_OPEN;
        file->store_string(s->_get_source_code()); file->close();
        // Recolección local anónima: qué APIs se usan más (mejora el ranking)
        LuauAutocomplete::record_usage(s->_get_source_code());
        return OK;
    }
    bool _recognize(const Ref<Resource>& r) const override { return Object::cast_to<LuauScript>(r.ptr()) != nullptr; }
    PackedStringArray _get_recognized_extensions(const Ref<Resource>& r) const override { PackedStringArray a; a.append("luau"); a.append("lua"); return a; }
};

#endif
