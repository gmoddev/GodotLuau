#include "gl_native_editor_plugin.h"
#include "luau_script.h"
#include "gl_execution_domain.h"
#include "gl_scene_authoring.h"
#include "luau_value_bindings.h"
#include "gl_runtime.h"
#include "gl_project_modules.h"
#include "gl_authoring_debugger.h"
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/editor_file_dialog.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/script_editor.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/sub_viewport.hpp>
#include <godot_cpp/classes/sub_viewport_container.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/world2d.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <functional>

using namespace godot;
namespace {
template<class T> T* Resolve(uint64_t Id) { return Object::cast_to<T>(ObjectDB::get_instance(Id)); }
bool NewProjectPath(const String& Path, const char* Extension) {
    for (int Index=0;Index<Path.length();++Index) if (Path[Index]==0) return false;
    return Path.begins_with("res://") && Path.length()<1024 && !Path.contains("..") &&
        !Path.contains("\\") && Path.get_extension()==Extension &&
        !FileAccess::file_exists(Path);
}
void PushPreviewNode(lua_State* Thread, Node* Value) {
    if (!Value) { lua_pushnil(Thread); return; }
    GLPushNodeHandle(Thread,Value); luaL_getmetatable(Thread,"GodotObject"); lua_setmetatable(Thread,-2);
}
Node* PreviewNode(lua_State* Thread, int Index) {
    if (!_gl_has_metatable(Thread,Index,"GodotObject")) luaL_error(Thread,"[Authoring:Preview] Expected owned node");
    Node* Value=gow_node(static_cast<GodotObjectWrapper*>(lua_touserdata(Thread,Index)));
    if (!Value || Value->is_queued_for_deletion()) luaL_error(Thread,"[Authoring:Preview] Retired node");
    return Value;
}
const char* TemplateSource(const String& Profile) {
    if(Profile=="3D")return LUAU_TEMPLATE_NATIVE_3D;
    if(Profile=="2D")return LUAU_TEMPLATE_NATIVE_2D;
    if(Profile=="UI")return LUAU_TEMPLATE_NATIVE_UI;
    if(Profile=="Empty")return LUAU_TEMPLATE_NATIVE_EMPTY;
    return nullptr;
}
}

GLNativeEditorPlugin::GLNativeEditorPlugin() = default;
GLNativeEditorPlugin::~GLNativeEditorPlugin() {
    StopPreview(); PreviewDomain.reset(); PreviewModules.reset();
}

void GLNativeEditorPlugin::ShowStatus(const String& Text) {
    if (auto LabelNode=Resolve<Label>(StatusLabel)) LabelNode->set_text(Text.left(4096));
    UtilityFunctions::print("[Authoring:Editor] ",Text.left(4096));
}

void GLNativeEditorPlugin::SetupAuthoring() {
    auto Panel=memnew(VBoxContainer); PreviewPanel=Panel->get_instance_id();
    Panel->set_custom_minimum_size(Vector2(600,260));
    auto Buttons=memnew(HBoxContainer); Panel->add_child(Buttons);
    auto Profiles=memnew(OptionButton);TemplatePicker=Profiles->get_instance_id();
    for(const char* Name:{"3D","2D","UI","Empty"})Profiles->add_item(Name);
    Profiles->set_tooltip_text("Template for a new Luau scene; existing projects are preserved");Buttons->add_child(Profiles);
    for (auto Entry : {std::pair<const char*,const char*>("New Luau Scene","NewSceneDialog"),
        {"Preview Luau","PreviewSelected"},{"Clear Preview","StopPreview"},{"Save Preview As","SavePreviewDialog"},
        {"Reset Context","ResetPreviewContext"},{"Open Runtime Error","OpenRuntimeError"}}) {
        auto ButtonNode=memnew(Button); ButtonNode->set_text(Entry.first);
        ButtonNode->connect("pressed",Callable(this,Entry.second)); Buttons->add_child(ButtonNode);
    }
    auto Status=memnew(Label); StatusLabel=Status->get_instance_id();
    Status->set_text("Explicit preview only. Runtime services are unavailable here."); Panel->add_child(Status);
    auto Content=memnew(HBoxContainer); Panel->add_child(Content);
    auto Hierarchy=memnew(Tree); PreviewTree=Hierarchy->get_instance_id();
    Hierarchy->set_custom_minimum_size(Vector2(220,200));
    Hierarchy->connect("item_selected",Callable(this,"InspectPreviewNode")); Content->add_child(Hierarchy);
    auto Container=memnew(SubViewportContainer); Container->set_stretch(true);
    Container->set_custom_minimum_size(Vector2(360,200)); Content->add_child(Container);
    auto Viewport=memnew(SubViewport); PreviewViewport=Viewport->get_instance_id();
    Viewport->set_size(Vector2i(600,320)); Viewport->set_use_own_world_3d(true);
    Ref<World2D> PreviewWorld2D;PreviewWorld2D.instantiate();Viewport->set_world_2d(PreviewWorld2D);
    Container->add_child(Viewport);
    add_control_to_bottom_panel(Panel,"Luau Authoring");
    Ref<GLAuthoringDebugger> Capture;Capture.instantiate();Capture->SetReceiver(get_instance_id());
    Debugger=Capture;add_debugger_plugin(Debugger);
    auto Dialog=memnew(EditorFileDialog); PathDialog=Dialog->get_instance_id();
    Dialog->set_access(EditorFileDialog::ACCESS_RESOURCES); Dialog->set_file_mode(EditorFileDialog::FILE_MODE_SAVE_FILE);
    Dialog->add_filter("*.tscn","Native scene"); Dialog->connect("file_selected",Callable(this,"OnAuthoringPath"));
    add_child(Dialog);
}

Dictionary GLNativeEditorPlugin::CreateLuauScene(const String& Path,const String& Profile) {
    Dictionary Result; Result["Passed"]=false;
    String SourcePath=Path.get_basename()+".luau";
    const char* Code=TemplateSource(Profile);
    if (!Code || !Engine::get_singleton()->is_editor_hint() || !NewProjectPath(Path,"tscn") || !NewProjectPath(SourcePath,"luau")) {
        Result["Error"]="Choose fresh project .tscn and .luau paths; existing content is preserved"; return Result;
    }
    Ref<LuauScript> Source; Source.instantiate(); Source->_set_source_code(Code);
    Error Status=ResourceSaver::get_singleton()->save(Source,SourcePath);
    if (Status!=OK) { Result["Error"]="Cannot save Luau source"; return Result; }
    Source->set_path(SourcePath);
    Node* Root=Profile=="3D"?static_cast<Node*>(memnew(Node3D)):memnew(Node);
    Root->set_name(Path.get_file().get_basename());
    auto Entry=memnew(LocalScript); Entry->set_name("Main"); Entry->set_codigo_luau(Source);
    Root->add_child(Entry); Entry->set_owner(Root);
    Ref<PackedScene> Scene; Scene.instantiate(); Status=Scene->pack(Root);
    if (Status==OK) Status=ResourceSaver::get_singleton()->save(Scene,Path);
    memdelete(Root);
    if (Status!=OK) { Result["Error"]="Scene save failed; source is preserved"; return Result; }
    auto Settings=ProjectSettings::get_singleton();
    if (String(Settings->get_setting("application/run/main_scene",String())).is_empty()) {
        Settings->set_setting("application/run/main_scene",Path); Settings->save();
    }
    Result["Passed"]=true; Result["Scene"]=Path; Result["Source"]=SourcePath;Result["Template"]=Profile;
    ShowStatus("Created "+Path+" with Luau entrypoint "+SourcePath); return Result;
}

void GLNativeEditorPlugin::StopPreview() {
    Callable Changed(this,"OnPreviewSourceChanged");
    if (PreviewSource.is_valid() && PreviewSource->is_connected("changed",Changed)) PreviewSource->disconnect("changed",Changed);
    PreviewSource.unref();
    if (PreviewDomain && PreviewOwner) PreviewDomain->CancelOwner(PreviewOwner);
    PreviewOwner=nullptr;
    if (PreviewDomain && PreviewModules) PreviewModules->Retire(*PreviewDomain);
    if (auto Root=Resolve<Node>(PreviewRoot)) memdelete(Root);
    PreviewRoot=0;
    if (auto Hierarchy=Resolve<Tree>(PreviewTree)) Hierarchy->clear();
    if (PreviewDomain && !PreviewDomain->IsClosing()) {
        PreviewDomain->Tick(0);
        PreviewDomain->RunNative([](lua_State* Thread){lua_gc(Thread,LUA_GCCOLLECT,0);});
        PreviewDomain->Tick(0);
    }
}
void GLNativeEditorPlugin::OnPreviewSourceChanged() {
    StopPreview(); ShowStatus("Source changed; use Preview Luau to reconstruct before saving");
}
void GLNativeEditorPlugin::_process(double) {
    if (!PreviewDomain || PreviewDomain->IsClosing()) return;
    if (PreviewDomain->GetPendingTaskCount()) { StopPreview(); ShowStatus("Preview callbacks cannot yield or retain tasks"); }
    else PreviewDomain->Tick(0);
}
void GLNativeEditorPlugin::ResetPreviewContext() {
    StopPreview(); PreviewDomain.reset(); PreviewModules.reset();
    ShowStatus("Preview context reset explicitly; no gameplay domain changed");
}

Dictionary GLNativeEditorPlugin::PreviewScript(const Ref<LuauScript>& Source) {
    Dictionary Result; Result["Passed"]=false; StopPreview(); PreviewError=String(); PreviewLogBytes=0;
    if (!Engine::get_singleton()->is_editor_hint() || Source.is_null() || Source->_get_source_code().utf8().length()>1024*1024) {
        Result["Error"]="Preview requires a bounded Luau source in the editor"; return Result;
    }
    uint64_t Started=Time::get_singleton()->get_ticks_usec();
    if (!PreviewDomain) {
        GLDomainLimits Limits; Limits.ResumeMilliseconds=100; Limits.MaxSafepoints=500000;
        Limits.MemoryBytes=64*1024*1024; Limits.Tasks=512; Limits.Coroutines=1024; Limits.References=2048; Limits.Owners=128;
        PreviewDomain=std::make_unique<GLExecutionDomain>(GLDomainKind::EditorPreview,Limits);
        PreviewModules=std::make_unique<GLProjectModules>();
        PreviewDomain->SetModuleResolver([this](lua_State* Thread,int Argument,GLModuleSource& Module) { return PreviewModules->Resolve(Thread,Argument,Module); });
        PreviewDomain->SetModuleLoader([this](GLModuleSource& Module) { return PreviewModules->Load(Module); });
        PreviewDomain->SetInvalidationHook([](lua_State* Anchor){ GLRetireScenes(Anchor); });
        PreviewDomain->SetErrorHandler([this](lua_State*,const std::string& Error){ PreviewError=String::utf8(Error.c_str()).left(4096); });
        PreviewDomain->InitializeHost([this](lua_State* Thread) {
            RegisterLuauValueMetatables(Thread); RegisterLuauValueGlobals(Thread); GLRegisterScene(Thread);
            GLPushNodeHandle(Thread,this);
            lua_pushcclosure(Thread,[](lua_State* L)->int {
                auto Plugin=Object::cast_to<GLNativeEditorPlugin>(GLNodeUpvalue(L,1));
                if (!Plugin || Plugin->PreviewLogBytes>=8192) return 0;
                String Text;
                for (int Index=1;Index<=lua_gettop(L) && Index<=16;++Index) {
                    if (Index>1) Text+="\t";
                    if (lua_type(L,Index)==LUA_TSTRING || lua_type(L,Index)==LUA_TNUMBER) {
                        size_t Bytes=0;const char* Value=lua_tolstring(L,Index,&Bytes);
                        Text+=String::utf8(Value,int((std::min)(Bytes,size_t(1024))));
                    } else Text+=luaL_typename(L,Index);
                }
                Text=Text.left(int((std::min)(size_t(2048),8192-Plugin->PreviewLogBytes)));
                Plugin->PreviewLogBytes+=Text.utf8().length();
                UtilityFunctions::print("[Authoring:Preview] ",Text);return 0;
            },"PreviewPrint",1);lua_setglobal(Thread,"print");
            // Native UI values use the same public X/Y shape as the generated
            // Scene definitions; gameplay keeps its full existing Vector2 library.
            lua_newtable(Thread);
            lua_pushcfunction(Thread,[](lua_State* L)->int {
                double X=luaL_optnumber(L,1,0);double Y=luaL_optnumber(L,2,0);
                lua_createtable(L,0,2);lua_pushnumber(L,X);lua_setfield(L,-2,"X");
                lua_pushnumber(L,Y);lua_setfield(L,-2,"Y");return 1;
            },"PreviewVector2");lua_setfield(Thread,-2,"new");
            lua_setreadonly(Thread,-1,true);lua_setglobal(Thread,"Vector2");
            luaL_newmetatable(Thread,"GodotObject");
            lua_pushcfunction(Thread,[](lua_State* L)->int {
                Node* Value=PreviewNode(L,1); const char* Key=luaL_checkstring(L,2);
                if (GLSceneIndex(L,Value,Key)) return 1;
                auto Owner=GLGetOwner(L);
                if (Owner && Value->get_instance_id()==Owner->NativeId && String(Key)=="Parent") PushPreviewNode(L,Value->get_parent());
                else lua_pushnil(L);
                return 1;
            },"PreviewIndex"); lua_setfield(Thread,-2,"__index");
            lua_pushcfunction(Thread,[](lua_State* L)->int {
                if (!GLSceneWrite(L,PreviewNode(L,1),luaL_checkstring(L,2))) luaL_error(L,"[Authoring:Preview] Editor objects are not writable");
                return 0;
            },"PreviewWrite"); lua_setfield(Thread,-2,"__newindex"); lua_pop(Thread,1);
        });
        PreviewDomain->SetEnvironmentHook([](lua_State* Thread,uint64_t Id) {
            PushPreviewNode(Thread,Resolve<Node>(Id)); lua_setglobal(Thread,"script");
        });
    }
    if (PreviewDomain->IsClosing()) { Result["Error"]="Preview context is closed after resource exhaustion; use Reset Context"; return Result; }
    auto Root=memnew(Node3D); Root->set_name("LuauPreview"); PreviewRoot=Root->get_instance_id();
    auto Driver=memnew(Node); Driver->set_name("PreviewDriver"); Root->add_child(Driver);
    PreviewOwner=PreviewDomain->CreateOwner(Driver->get_instance_id());
    bool Passed=PreviewOwner && PreviewDomain->Execute(PreviewOwner,Source->_get_source_code().utf8().get_data(),
        (String("@")+Source->get_path()).utf8().get_data());
    if (PreviewDomain->GetPendingTaskCount()) { Passed=false; PreviewError="Preview construction cannot yield or retain tasks"; }
    if (!Passed || !PreviewError.is_empty()) {
        if (PreviewError.is_empty()) PreviewError="Preview execution failed";
        Result["Error"]=PreviewError; StopPreview(); ShowStatus(PreviewError); return Result;
    }
    if (auto Viewport=Resolve<SubViewport>(PreviewViewport)) {
        Viewport->add_child(Root);
        Ref<World3D> World=Viewport->find_world_3d();
        if (World.is_valid()) PhysicsServer3D::get_singleton()->space_set_active(World->get_space(),false);
    }
    Result["Passed"]=true; Result["Nodes"]=Root->find_children("*","",true,false).size();
    PreviewSource=Source; Source->connect("changed",Callable(this,"OnPreviewSourceChanged"));
    Result["Microseconds"]=int64_t(Time::get_singleton()->get_ticks_usec()-Started);
    Result["VMBytes"]=int64_t(PreviewDomain->GetMemoryAccount().Live);
    BuildPreviewTree(); ShowStatus("Preview built; transient content. Save As creates an independent native scene.");
    return Result;
}

void GLNativeEditorPlugin::BuildPreviewTree() {
    auto Hierarchy=Resolve<Tree>(PreviewTree); auto Root=Resolve<Node>(PreviewRoot);
    if (!Hierarchy || !Root) return;
    Hierarchy->clear();
    std::function<void(Node*,TreeItem*)> Add=[&](Node* Value,TreeItem* Parent) {
        auto Item=Hierarchy->create_item(Parent); Item->set_text(0,String(Value->get_name())+" : "+Value->get_class());
        Item->set_metadata(0,int64_t(Value->get_instance_id()));
        for (int Index=0;Index<Value->get_child_count();++Index) Add(Value->get_child(Index),Item);
    }; Add(Root,nullptr);
}
void GLNativeEditorPlugin::InspectPreviewNode() {
    auto Hierarchy=Resolve<Tree>(PreviewTree); auto Item=Hierarchy?Hierarchy->get_selected():nullptr;
    if (Item) if (auto Value=Resolve<Node>(int64_t(Item->get_metadata(0)))) EditorInterface::get_singleton()->edit_node(Value);
}

Error GLNativeEditorPlugin::SavePreview(const String& Path) {
    if (!Engine::get_singleton()->is_editor_hint() || !NewProjectPath(Path,"tscn")) return ERR_INVALID_PARAMETER;
    auto Root=Resolve<Node>(PreviewRoot); if (!Root) return ERR_UNCONFIGURED;
    auto Saved=memnew(Node3D); Saved->set_name("GeneratedScene");
    for (int Index=0;Index<Root->get_child_count();++Index) if (auto Scope=Object::cast_to<SceneScope>(Root->get_child(Index))) {
        auto Branch=memnew(Node3D); Branch->set_name(Scope->get_name()); Branch->set_transform(Scope->get_transform());
        Saved->add_child(Branch); Branch->set_owner(Saved);
        for (int ChildIndex=0;ChildIndex<Scope->get_child_count();++ChildIndex) {
            auto Copy=Scope->get_child(ChildIndex)->duplicate(0); Branch->add_child(Copy);
            std::function<void(Node*)> Own=[&](Node* Value) {
                // Snapshot descendants are saved explicitly. Retaining an instance
                // path would instantiate those children again when Godot reopens it.
                Value->set_scene_file_path(String());
                Value->set_owner(Saved);
                // The private preview viewport selects its camera implicitly.
                // That viewport-local state is not an authored takeover grant.
                if (auto Camera=Object::cast_to<Camera3D>(Value)) Camera->set_current(false);
                for (int N=0;N<Value->get_child_count();++N) Own(Value->get_child(N));
            };
            Own(Copy);
        }
    }
    Ref<PackedScene> Packed; Packed.instantiate(); Error Status=Packed->pack(Saved);
    if (Status==OK) Status=ResourceSaver::get_singleton()->save(Packed,Path);
    memdelete(Saved); ShowStatus(Status==OK?"Saved independent native scene "+Path:"Native scene save failed"); return Status;
}
void GLNativeEditorPlugin::PreviewSelected() {
    auto Editor=EditorInterface::get_singleton()->get_script_editor();
    Ref<LuauScript> Source=Editor->get_current_script(); PreviewScript(Source);
    if (auto Panel=Resolve<Control>(PreviewPanel)) make_bottom_panel_item_visible(Panel);
}
void GLNativeEditorPlugin::NewSceneDialog() {
    SavingPreview=false;
    if (auto Dialog=Resolve<EditorFileDialog>(PathDialog)) { Dialog->set_title("New Luau Scene"); Dialog->set_current_file("Main.tscn"); Dialog->popup_centered_ratio(); }
}
void GLNativeEditorPlugin::SavePreviewDialog() {
    SavingPreview=true;
    if (auto Dialog=Resolve<EditorFileDialog>(PathDialog)) { Dialog->set_title("Save independent preview scene"); Dialog->set_current_file("Generated.tscn"); Dialog->popup_centered_ratio(); }
}
void GLNativeEditorPlugin::OnAuthoringPath(const String& Path) {
    if (SavingPreview) { SavePreview(Path); return; }
    String Profile="3D";
    if(auto Profiles=Resolve<OptionButton>(TemplatePicker))Profile=Profiles->get_item_text(Profiles->get_selected());
    Dictionary Result=CreateLuauScene(Path,Profile);
    if (!(bool)Result["Passed"]) { ShowStatus(Result["Error"]); return; }
    EditorInterface::get_singleton()->open_scene_from_path(Path);
    Ref<Script> Source=ResourceLoader::get_singleton()->load(Result["Source"],"LuauScript");
    EditorInterface::get_singleton()->edit_script(Source);
}
