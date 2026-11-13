#include "gl_authoring_debugger.h"
#include "gl_native_editor_plugin.h"
#include "luau_script.h"
#include "gl_asset.h"
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>

using namespace godot;
bool GLAuthoringDebugger::_capture(const String& Message,const Array& Data,int32_t) {
    if (Message!="godotluau:runtime_error" || (Data.size()!=3 && Data.size()!=4)) return false;
    for (int Index=0;Index<3;++Index) if (Data[Index].get_type()!=Variant::STRING) return false;
    if(Data.size()==4 && Data[3].get_type()!=Variant::DICTIONARY)return false;
    auto Plugin=Object::cast_to<GLNativeEditorPlugin>(ObjectDB::get_instance(Receiver));
    if (Plugin) Plugin->ReceiveRuntimeError(Data);return true;
}
void GLNativeEditorPlugin::ReceiveRuntimeError(const Array& Data) {
    if (Data.size()!=3 && Data.size()!=4) return;
    LastRuntimeError.clear();
    LastRuntimeError.push_back(String(Data[0]).left(1024));
    LastRuntimeError.push_back(String(Data[1]).left(4096));
    LastRuntimeError.push_back(String(Data[2]).left(8192));
    if(Data.size()==4)LastRuntimeError.push_back(Dictionary(Data[3]).duplicate(true));
    ShowStatus(String(LastRuntimeError[0])+"\n"+String(LastRuntimeError[1])+"\n"+String(LastRuntimeError[2]));
    auto TreeNode=Object::cast_to<Tree>(ObjectDB::get_instance(RuntimeTree));
    if(!TreeNode)return;
    TreeNode->clear();
    if(Data.size()!=4)return;
    Dictionary Snapshot=Data[3];
    if(int(Snapshot.get("Schema",0))!=1 || Snapshot.get("Frames",Variant()).get_type()!=Variant::ARRAY)return;
    auto Root=TreeNode->create_item();Root->set_text(0,String(Snapshot.get("Domain",String()))+" error snapshot");
    Root->set_text(1,"Not suspended; opaque values are not retained");
    Array Frames=Snapshot["Frames"];
    for(int Index=0;Index<Frames.size() && Index<16;++Index) {
        if(Frames[Index].get_type()!=Variant::DICTIONARY)continue;
        Dictionary Frame=Frames[Index];auto Row=TreeNode->create_item(Root);
        String Path=String(Frame.get("Source",String())).left(1024);int Line=Frame.get("Line",0);
        Row->set_text(0,Path+":"+String::num_int64(Line));Row->set_text(1,String(Frame.get("Function",String())).left(128));
        Dictionary Location;Location["Path"]=Path;Location["Line"]=Line;Row->set_metadata(0,Location);
        Variant Values=Frame.get("Locals",Variant());if(Values.get_type()!=Variant::ARRAY)continue;
        Array Locals=Values;
        for(int LocalIndex=0;LocalIndex<Locals.size() && LocalIndex<8;++LocalIndex) {
            if(Locals[LocalIndex].get_type()!=Variant::DICTIONARY)continue;
            Dictionary Local=Locals[LocalIndex];auto Child=TreeNode->create_item(Row);
            Child->set_text(0,String(Local.get("Name",String())).left(128)+" : "+String(Local.get("Type",String())).left(32));
            Variant Value=Local.get("Value",Variant());
            Child->set_text(1,Value.get_type()<=Variant::STRING?String(Value).left(256):String("opaque"));
        }
    }
}
void GLNativeEditorPlugin::OpenRuntimeError() {
    if (LastRuntimeError.size()<3) { ShowStatus("No captured runtime error");return; }
    String Path=LastRuntimeError[0];
    if (!GLProjectResourcePath(Path) || (Path.get_extension()!="luau" && Path.get_extension()!="lua")) return;
    Ref<Script> Source=ResourceLoader::get_singleton()->load(Path,"LuauScript");
    if (Source.is_null()) return;
    String Message=LastRuntimeError[1];int Offset=Message.find(Path+":");int Line=1;
    if (Offset>=0) Line=Message.substr(Offset+Path.length()+1).to_int();
    EditorInterface::get_singleton()->edit_script(Source,(std::max)(1,Line),0,true);
}
void GLNativeEditorPlugin::OpenRuntimeFrame() {
    auto TreeNode=Object::cast_to<Tree>(ObjectDB::get_instance(RuntimeTree));
    auto Selected=TreeNode?TreeNode->get_selected():nullptr;if(!Selected)return;
    Variant Metadata=Selected->get_metadata(0);if(Metadata.get_type()!=Variant::DICTIONARY)return;
    Dictionary Location=Metadata;String Path=Location.get("Path",String());
    if(!GLProjectResourcePath(Path) || (Path.get_extension()!="luau" && Path.get_extension()!="lua"))return;
    Ref<Script> Source=ResourceLoader::get_singleton()->load(Path,"LuauScript");
    if(Source.is_valid())EditorInterface::get_singleton()->edit_script(Source,(std::max)(1,int(Location.get("Line",1))),0,true);
}
