#include "gl_native_editor_plugin.h"
#include <godot_cpp/classes/code_edit.hpp>
#include "gl_luau_highlighter.h"
#include "gl_authoring_debugger.h"
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/script_editor.hpp>
#include <godot_cpp/classes/script_editor_base.hpp>
#include <godot_cpp/variant/callable.hpp>
#include "luau_script.h"
#include "gl_native_editor_api.h"
#include "gl_execution_domain.h"
#include "gl_project_indexer.h"
#include "gl_runtime_debugger.h"
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>

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
    ClassDB::bind_method(D_METHOD("OnBreakpointToggle","Line","Code","Path"), &GLNativeEditorPlugin::OnBreakpointToggle);
    ClassDB::bind_method(D_METHOD("CreateLuauScene", "Path","Profile"), &GLNativeEditorPlugin::CreateLuauScene,DEFVAL(String("3D")));
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
    ClassDB::bind_method(D_METHOD("OpenRuntimeFrame"), &GLNativeEditorPlugin::OpenRuntimeFrame);
    ClassDB::bind_method(D_METHOD("GetRuntimeDiagnostics"), &GLNativeEditorPlugin::GetRuntimeDiagnostics);
    ClassDB::bind_method(D_METHOD("GetDebuggerSessions"), &GLNativeEditorPlugin::GetDebuggerSessions);
    ClassDB::bind_method(D_METHOD("IndexProject","Module","Member"), &GLNativeEditorPlugin::IndexProject);
    ClassDB::bind_method(D_METHOD("QueryProject","Options"), &GLNativeEditorPlugin::QueryProject);
    ClassDB::bind_method(D_METHOD("PollProject","Generation"), &GLNativeEditorPlugin::PollProject);
    ClassDB::bind_method(D_METHOD("ReloadScripts","Scripts"), &GLNativeEditorPlugin::ReloadScripts);
    ClassDB::bind_method(D_METHOD("FindProjectUses"), &GLNativeEditorPlugin::FindProjectUses);
    ClassDB::bind_method(D_METHOD("ShowProjectSymbols"), &GLNativeEditorPlugin::ShowProjectSymbols);
}

void GLNativeEditorPlugin::_enter_tree() {
    set_process(true);
    SetupAuthoring();
    Ref<GLLuauHighlighter> Highlight;Highlight.instantiate();Highlighter=Highlight;
    if (auto Editor = GetEditor()) {
        Editor->register_syntax_highlighter(Highlighter);
        Editor->connect("editor_script_changed", Callable(this, "OnScriptChanged"));
    }
    OnScriptChanged(Ref<Script>());
}

void GLNativeEditorPlugin::_exit_tree() {
    ProjectIndex.reset();ProjectGeneration=0;
    StopPreview();
    if (Debugger.is_valid()) { remove_debugger_plugin(Debugger);Debugger.unref(); }
    if (auto Panel=Object::cast_to<Control>(ObjectDB::get_instance(PreviewPanel))) {
        remove_control_from_bottom_panel(Panel);
        Panel->queue_free();
    }
    PreviewPanel=0;
    if (auto Editor = GetEditor()) {
        if (Highlighter.is_valid()) Editor->unregister_syntax_highlighter(Highlighter);
        Callable Handler(this, "OnScriptChanged");
        if (Editor->is_connected("editor_script_changed", Handler)) Editor->disconnect("editor_script_changed", Handler);
    }
    Highlighter.unref();
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
    Code->set_draw_breakpoints_gutter(true);
    Callable BreakpointHandler=Callable(this,"OnBreakpointToggle").bind(int64_t(Code->get_instance_id()),Script->get_path());
    if(!Code->is_connected("breakpoint_toggled",BreakpointHandler))Code->connect("breakpoint_toggled",BreakpointHandler);
    if(auto Capture=Object::cast_to<GLAuthoringDebugger>(Debugger.ptr()))
        for(int Line:Code->get_breakpointed_lines())Capture->RecordBreakpoint(Script->get_path(),Line+1,true);
    auto Prefixes = Code->get_code_completion_prefixes();
    if (!Prefixes.has(":")) {
        Prefixes.push_back(":");
        Code->set_code_completion_prefixes(Prefixes);
    }
}
void GLNativeEditorPlugin::OnBreakpointToggle(int64_t Line,int64_t Identity,const String& Path) {
    auto Code=Object::cast_to<CodeEdit>(ObjectDB::get_instance(Identity));
    if(Code && Line>=0 && Line<Code->get_line_count())
        if(auto Capture=Object::cast_to<GLAuthoringDebugger>(Debugger.ptr()))Capture->RecordBreakpoint(Path,int(Line)+1,Code->is_line_breakpointed(int(Line)));
}
Array GLNativeEditorPlugin::GetDebuggerSessions() {
    if(!Engine::get_singleton()->is_editor_hint() || GLExecutionDomain::IsExecuting() || OS::get_singleton()->get_thread_caller_id()!=OS::get_singleton()->get_main_thread_id())return Array();
    auto Capture=Object::cast_to<GLAuthoringDebugger>(Debugger.ptr());return Capture?Capture->DescribeSessions():Array();
}
Dictionary GLNativeEditorPlugin::IndexProject(const String& Module,const String& Member) {
    Dictionary Options;Options["Module"]=Module;Options["Member"]=Member;
    Options["Query"]=Module.is_empty() && Member.is_empty()?"Symbols":"References";
    return QueryProject(Options);
}
int64_t GLNativeEditorPlugin::ReloadScripts(const Array& Scripts) {
    if(!Engine::get_singleton()->is_editor_hint() || GLExecutionDomain::IsExecuting())return ERR_UNAVAILABLE;
    return GLReloadLuauScripts(Scripts);
}
Dictionary GLNativeEditorPlugin::QueryProject(const Dictionary& Options) {
    if(!Engine::get_singleton()->is_editor_hint() || GLExecutionDomain::IsExecuting() || OS::get_singleton()->get_thread_caller_id()!=OS::get_singleton()->get_main_thread_id())return Dictionary();
    GLProjectIndexer::Request Request;
    auto Text=[](const String& Value){return std::string(Value.utf8().get_data());};
    Request.Root=Text(ProjectSettings::get_singleton()->globalize_path("res://"));
    Request.Query=Text(Options.get("Query","Symbols"));Request.Module=Text(Options.get("Module",String()));
    Request.Member=Text(Options.get("Member",String()));Request.Replacement=Text(Options.get("Replacement",String()));
    Request.Line=Options.get("Line",1);Request.Column=Options.get("Column",1);
    int64_t Offset=Options.get("Offset",0);Request.Offset=Offset<0?0:size_t(Offset);
    size_t Bytes=0;
    if(auto Editor=GetEditor()) {
        auto Scripts=Editor->get_open_scripts();
        for(int Index=0;Index<Scripts.size() && Index<64;++Index) {
            Ref<Script> Script=Scripts[Index];
            auto Source=Script.is_valid()?Object::cast_to<LuauScript>(Script.ptr()):nullptr;
            if(Source) {
                auto Buffer=Text(Source->_get_source_code());Bytes+=Buffer.size();
                if(Buffer.size()<=256*1024 && Bytes<=8*1024*1024)Request.Buffers[Text(Source->get_path())]=std::move(Buffer);
            }
        }
        Ref<Script> Current=Editor->get_current_script();auto Tab=Editor->get_current_editor();
        auto Code=Tab?Object::cast_to<CodeEdit>(Tab->get_base_editor()):nullptr;
        if(Current.is_valid() && Current->is_class("LuauScript") && Code) {
            Request.Active=Text(Current->get_path());auto Buffer=Text(Code->get_text());
            if(Buffer.size()<=256*1024)Request.Buffers[Request.Active]=std::move(Buffer);
        }
    }
    if(!ProjectIndex)ProjectIndex=std::make_unique<GLProjectIndexer>();
    ProjectGeneration=ProjectIndex->Submit(std::move(Request));
    Dictionary Report;Report["result"]=ProjectGeneration?OK:ERR_INVALID_PARAMETER;
    Report["Generation"]=int64_t(ProjectGeneration);Report["Pending"]=bool(ProjectGeneration);return Report;
}
void GLNativeEditorPlugin::FindProjectUses() {
    auto Editor=GetEditor();Ref<Script> Current=Editor?Editor->get_current_script():Ref<Script>();
    auto Tab=Editor?Editor->get_current_editor():nullptr;auto Code=Tab?Object::cast_to<CodeEdit>(Tab->get_base_editor()):nullptr;
    if(Current.is_null() || !Current->is_class("LuauScript") || !Code){ShowStatus("Open a Luau module member or export to find its static project uses");return;}
    String Symbol=Code->get_word_under_caret();String Source=Code->get_text();
    auto Lines=Source.split("\n");int Line=Code->get_caret_line(),Column=Code->get_caret_column();
    if(Line<0 || Line>=Lines.size())return;
    Lines[Line]=String(Lines[Line]).insert(Column,String::chr(0xffff));Source=String("\n").join(Lines);
    Dictionary Target=GLNavigateNativeCode(Source,Symbol,Current->get_path());
    String Module=Target.get("script_path",Current->get_path());
    Dictionary Report=IndexProject(Module,Symbol);
    if(int(Report.get("result",ERR_UNAVAILABLE))!=OK){ShowStatus("This selection has no supported static module reference index");return;}
    ProjectUiGeneration=ProjectGeneration;ProjectUiTitle=Module+" :: "+Symbol;
    ShowStatus("Indexing static project uses in background");
}
void GLNativeEditorPlugin::ShowProjectSymbols() {
    Dictionary Report=IndexProject("","");
    if(int(Report.get("result",ERR_UNAVAILABLE))!=OK)return;
    ProjectUiGeneration=ProjectGeneration;ProjectUiTitle="Project symbols and static imports";
    ShowStatus("Indexing project symbols in background");
}
void GLNativeEditorPlugin::FlushProjectQuery() {
    if(!ProjectUiGeneration)return;
    if(ProjectUiGeneration!=ProjectGeneration){ProjectUiGeneration=0;return;}
    Dictionary Report=PollProject(int64_t(ProjectUiGeneration));
    if(bool(Report.get("Pending",false)))return;
    ProjectUiGeneration=0;
    if(int(Report.get("result",ERR_UNAVAILABLE))!=OK){ShowStatus("Project query retired");return;}
    if(!String(Report.get("Error",String())).is_empty()){ShowStatus(Report["Error"]);return;}
    auto TreeNode=Object::cast_to<Tree>(ObjectDB::get_instance(RuntimeTree));if(!TreeNode)return;
    TreeNode->clear();TreeNode->show();auto Root=TreeNode->create_item();Root->set_text(0,ProjectUiTitle);
    Root->set_text(1,bool(Report["Truncated"])?"Bounded result page; more or incomplete results":"Worker index snapshot");
    Array Uses=Report["Entries"];
    for(int Index=0;Index<Uses.size();++Index) {
        Dictionary Use=Uses[Index];auto Row=TreeNode->create_item(Root);
        Row->set_text(0,String(Use["Path"])+":"+String::num_int64(int(Use["Line"]))+" "+String(Use["Name"]));Row->set_text(1,Use["Kind"]);Row->set_metadata(0,Use);
    }
    ShowStatus(String::num_int64(int(Report["Matches"]))+" matches across "+String::num_int64(int(Report["ScannedFiles"]))+" Luau files; "+String::num_int64(int(Report["CachedFiles"]))+" cached. "+String(Report["Scope"]));
}
