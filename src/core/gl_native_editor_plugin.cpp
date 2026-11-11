#include "gl_native_editor_plugin.h"
#include <godot_cpp/classes/code_edit.hpp>
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
    auto Prefixes = Code->get_code_completion_prefixes();
    if (!Prefixes.has(":")) {
        Prefixes.push_back(":");
        Code->set_code_completion_prefixes(Prefixes);
    }
}
