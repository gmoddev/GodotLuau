#include "gl_authoring_debugger.h"
#include "gl_native_editor_plugin.h"
#include "luau_script.h"
#include "gl_asset.h"
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

using namespace godot;
bool GLAuthoringDebugger::_capture(const String& Message,const Array& Data,int32_t) {
    if (Message!="godotluau:runtime_error" || Data.size()!=3) return false;
    for (int Index=0;Index<3;++Index) if (Data[Index].get_type()!=Variant::STRING) return false;
    auto Plugin=Object::cast_to<GLNativeEditorPlugin>(ObjectDB::get_instance(Receiver));
    if (Plugin) Plugin->ReceiveRuntimeError(Data);return true;
}
void GLNativeEditorPlugin::ReceiveRuntimeError(const Array& Data) {
    if (Data.size()!=3) return;
    LastRuntimeError.clear();
    LastRuntimeError.push_back(String(Data[0]).left(1024));
    LastRuntimeError.push_back(String(Data[1]).left(4096));
    LastRuntimeError.push_back(String(Data[2]).left(8192));
    ShowStatus(String(LastRuntimeError[0])+"\n"+String(LastRuntimeError[1])+"\n"+String(LastRuntimeError[2]));
}
void GLNativeEditorPlugin::OpenRuntimeError() {
    if (LastRuntimeError.size()!=3) { ShowStatus("No captured runtime error");return; }
    String Path=LastRuntimeError[0];
    if (!GLProjectResourcePath(Path) || (Path.get_extension()!="luau" && Path.get_extension()!="lua")) return;
    Ref<Script> Source=ResourceLoader::get_singleton()->load(Path,"LuauScript");
    if (Source.is_null()) return;
    String Message=LastRuntimeError[1];int Offset=Message.find(Path+":");int Line=1;
    if (Offset>=0) Line=Message.substr(Offset+Path.length()+1).to_int();
    EditorInterface::get_singleton()->edit_script(Source,(std::max)(0,Line-1),0,true);
}
