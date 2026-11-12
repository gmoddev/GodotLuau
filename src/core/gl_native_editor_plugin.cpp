#include "gl_native_editor_plugin.h"
#include <godot_cpp/classes/code_edit.hpp>
#include <godot_cpp/classes/code_highlighter.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/script_editor.hpp>
#include <godot_cpp/classes/script_editor_base.hpp>
#include <godot_cpp/variant/callable.hpp>
#include "luau_script.h"

using namespace godot;

namespace {
ScriptEditor* GetEditor() {
    auto Interface = EditorInterface::get_singleton();
    return Interface ? Interface->get_script_editor() : nullptr;
}
}

void GLNativeEditorPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("OnScriptChanged", "Script"), &GLNativeEditorPlugin::OnScriptChanged);
    ClassDB::bind_method(D_METHOD("ConfigureEditor"), &GLNativeEditorPlugin::ConfigureEditor);
    ClassDB::bind_method(D_METHOD("CreateLuauScene", "Path"), &GLNativeEditorPlugin::CreateLuauScene);
    ClassDB::bind_method(D_METHOD("PreviewScript", "Source"), &GLNativeEditorPlugin::PreviewScript);
    ClassDB::bind_method(D_METHOD("StopPreview"), &GLNativeEditorPlugin::StopPreview);
    ClassDB::bind_method(D_METHOD("ResetPreviewContext"), &GLNativeEditorPlugin::ResetPreviewContext);
    ClassDB::bind_method(D_METHOD("OnPreviewSourceChanged"), &GLNativeEditorPlugin::OnPreviewSourceChanged);
    ClassDB::bind_method(D_METHOD("SavePreview", "Path"), &GLNativeEditorPlugin::SavePreview);
    ClassDB::bind_method(D_METHOD("PreviewSelected"), &GLNativeEditorPlugin::PreviewSelected);
    ClassDB::bind_method(D_METHOD("NewSceneDialog"), &GLNativeEditorPlugin::NewSceneDialog);
    ClassDB::bind_method(D_METHOD("SavePreviewDialog"), &GLNativeEditorPlugin::SavePreviewDialog);
    ClassDB::bind_method(D_METHOD("OnAuthoringPath", "Path"), &GLNativeEditorPlugin::OnAuthoringPath);
    ClassDB::bind_method(D_METHOD("InspectPreviewNode"), &GLNativeEditorPlugin::InspectPreviewNode);
    ClassDB::bind_method(D_METHOD("OpenRuntimeError"), &GLNativeEditorPlugin::OpenRuntimeError);
    ClassDB::bind_method(D_METHOD("GetRuntimeDiagnostics"), &GLNativeEditorPlugin::GetRuntimeDiagnostics);
}

void GLNativeEditorPlugin::_enter_tree() {
    SetupAuthoring();
    if (auto Editor = GetEditor()) Editor->connect("editor_script_changed", Callable(this, "OnScriptChanged"));
    OnScriptChanged(Ref<Script>());
}

void GLNativeEditorPlugin::_exit_tree() {
    StopPreview();
    if (Debugger.is_valid()) { remove_debugger_plugin(Debugger);Debugger.unref(); }
    if (auto Panel=Object::cast_to<Control>(ObjectDB::get_instance(PreviewPanel))) {
        remove_control_from_bottom_panel(Panel);
        Panel->queue_free();
    }
    PreviewPanel=0;
    if (auto Editor = GetEditor()) {
        Callable Handler(this, "OnScriptChanged");
        if (Editor->is_connected("editor_script_changed", Handler)) Editor->disconnect("editor_script_changed", Handler);
    }
}

void GLNativeEditorPlugin::OnScriptChanged(const Ref<Script>&) {
    if (Pending) return;
    Pending = true;
    call_deferred("ConfigureEditor");
}

void GLNativeEditorPlugin::ConfigureEditor() {
    Pending = false;
    if (!is_inside_tree()) return;
    auto Editor = GetEditor();
    if (!Editor) return;
    Callable Handler(this, "OnScriptChanged");
    if (!Editor->is_connected("editor_script_changed", Handler)) Editor->connect("editor_script_changed", Handler);
    Ref<Script> Script = Editor->get_current_script();
    if (Script.is_null() || !Script->is_class("LuauScript")) return;
    auto Tab = Editor->get_current_editor();
    auto Code = Tab ? Object::cast_to<CodeEdit>(Tab->get_base_editor()) : nullptr;
    if (!Code) return;
    if (!Code->has_meta("_godotluau_highlight")) {
        Ref<CodeHighlighter> Highlight;Highlight.instantiate();
        for (const char* Word:{"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","continue","type","export"})
            Highlight->add_keyword_color(Word,Color(0.95,0.45,0.55));
        for (const char* Word:{"Scene","Vector2","Vector3","Color3","CFrame","game","script","self"})
            Highlight->add_keyword_color(Word,Color(0.45,0.8,0.9));
        Highlight->set_number_color(Color(0.65,0.9,0.7));
        Highlight->set_function_color(Color(0.6,0.8,1));
        Highlight->set_symbol_color(Color(0.75,0.75,0.85));
        for (const char* Start:{"--[[","--[=["}) Highlight->add_color_region(Start,String(Start)=="--[["?"]]":"]=]",Color(0.55,0.6,0.65));
        Highlight->add_color_region("--","",Color(0.55,0.6,0.65),true);
        for (const char* Quote:{"\"","'","`"}) Highlight->add_color_region(Quote,Quote,Color(0.9,0.8,0.55));
        Code->set_syntax_highlighter(Highlight);
        Code->set_meta("_godotluau_highlight",true);
    }
    auto Prefixes = Code->get_code_completion_prefixes();
    if (!Prefixes.has(":")) {
        Prefixes.push_back(":");
        Code->set_code_completion_prefixes(Prefixes);
    }
}
