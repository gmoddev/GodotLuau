#include "gl_authoring_debugger.h"
#include "gl_native_editor_plugin.h"
#include "luau_script.h"
#include "gl_asset.h"
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include <godot_cpp/classes/editor_debugger_session.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/option_button.hpp>

using namespace godot;
void GLAuthoringDebugger::_bind_methods() {
    ClassDB::bind_method(D_METHOD("Command","Session","Op"),&GLAuthoringDebugger::Command);
    ClassDB::bind_method(D_METHOD("SelectDomain","Index","Session"),&GLAuthoringDebugger::SelectDomain);
}
void GLAuthoringDebugger::_setup_session(int32_t Session) {
    if(Views.size()>=8 && !Views.count(Session))return;
    auto Native=get_session(Session); if(Native.is_null())return;
    auto Panel=memnew(VBoxContainer); Panel->set_name("Luau");
    auto Buttons=memnew(HBoxContainer); Panel->add_child(Buttons);
    auto Domains=memnew(OptionButton);Domains->add_item("Server");Domains->add_item("Client");Domains->add_item("All domains");
    Domains->connect("item_selected",Callable(this,"SelectDomain").bind(Session));Buttons->add_child(Domains);
    for(const char* Op:{"Pause","Continue","StepInto","StepOver","StepOut","Status","Detach"}) {
        auto ButtonNode=memnew(Button); ButtonNode->set_text(Op);
        ButtonNode->connect("pressed",Callable(this,"Command").bind(Session,String(Op))); Buttons->add_child(ButtonNode);
    }
    auto Status=memnew(Label); Status->set_text("Waiting for an editor-capable Luau runtime; native stack/variables use Godot's Debugger.");
    Panel->add_child(Status); auto TreeNode=memnew(Tree); TreeNode->set_columns(3);
    TreeNode->set_column_title(0,"Source / requested line"); TreeNode->set_column_title(1,"Admitted lines"); TreeNode->set_column_title(2,"Hits");
    TreeNode->set_column_titles_visible(true); TreeNode->set_custom_minimum_size(Vector2(600,150)); Panel->add_child(TreeNode);
    auto& View=Views[Session]; View.Label=Status->get_instance_id(); View.Tree=TreeNode->get_instance_id();
    Native->add_session_tab(Panel);
}
void GLAuthoringDebugger::Send(int Session,const String& Op,const Dictionary& Fields) {
    auto Found=Views.find(Session); auto Native=get_session(Session);
    if(Found==Views.end() || Native.is_null() || !Native->is_active() || Found->second.Nonce.is_empty())return;
    auto& View=Found->second; Dictionary Request=Fields.duplicate();
    Request["Schema"]=1; Request["Session"]=View.Nonce; Request["Request"]=++View.Request;
    Request["Op"]=Op; Request["Domain"]=Op=="Breakpoint" || Op=="Detach"?String("All"):Op=="Pause"?View.PauseDomain:View.Domain;
    Array Data;Data.push_back(Request);Native->send_message("godotluau:command",Data);
}
void GLAuthoringDebugger::SelectDomain(int Index,int Session) {
    auto Found=Views.find(Session);if(Found!=Views.end() && Index>=0 && Index<3)Found->second.PauseDomain=Index==0?"Server":Index==1?"Client":"All";
}
void GLAuthoringDebugger::Command(int Session,const String& Op) {
    auto Native=get_session(Session); if(Native.is_null() || !Native->is_active())return;
    if(Op=="Continue" || Op=="StepInto" || Op=="StepOver") {
        if(Native->is_breaked())Native->send_message(Op=="Continue"?"continue":Op=="StepInto"?"step":"next");
    } else if(Op=="StepOut") {
        if(Native->is_breaked()){Send(Session,Op);Native->send_message("continue");}
    } else {
        Send(Session,Op);
        if(Op=="Detach" && Native->is_breaked())Native->send_message("continue");
    }
}
void GLAuthoringDebugger::RecordBreakpoint(const String& Source,int Line,bool Enabled) {
    if(!GLProjectResourcePath(Source) || Line<1 || Line>1000000 || Source.utf8().length()>1024)return;
    Location Key{Source.utf8().get_data(),Line};
    if(Enabled) {if(Breakpoints.size()>=128 && !Breakpoints.count(Key))return;Breakpoints[Key]=true;}
    else Breakpoints.erase(Key);
    for(auto& Entry:Views)if(Entry.second.Pending.size()<256 || Entry.second.Pending.count(Key))Entry.second.Pending[Key]=Enabled;
}
void GLAuthoringDebugger::_breakpoint_set_in_tree(const Ref<Script>& Script,int32_t Line,bool Enabled) {
    if(Script.is_valid() && Script->is_class("LuauScript"))RecordBreakpoint(Script->get_path(),Line,Enabled);
}
void GLAuthoringDebugger::_breakpoints_cleared_in_tree() {
    auto Previous=Breakpoints; for(const auto& Item:Previous)RecordBreakpoint(String::utf8(Item.first.first.c_str()),Item.first.second,false);
}
void GLAuthoringDebugger::Flush() {
    uint64_t Now=Time::get_singleton()->get_ticks_msec(); if(Now-LastFlush<100)return;LastFlush=Now;
    for(auto& Entry:Views) {
        auto Native=get_session(Entry.first); if(Native.is_null() || !Native->is_active() || Entry.second.Nonce.is_empty())continue;
        for(int Count=0;Count<2 && !Entry.second.Pending.empty();++Count) {
            auto Pending=Entry.second.Pending.begin(); Dictionary Fields;
            Fields["Source"]=String::utf8(Pending->first.first.c_str());Fields["Line"]=Pending->first.second;Fields["Enabled"]=Pending->second;
            Send(Entry.first,"Breakpoint",Fields);Entry.second.Pending.erase(Pending);
        }
    }
}
bool GLAuthoringDebugger::_capture(const String& Message,const Array& Data,int32_t Session) {
    if(Message=="godotluau:debugger") {
        if(Data.size()!=1 || Data[0].get_type()!=Variant::DICTIONARY)return true;
        Dictionary Reply=Data[0]; if(Reply.size()>16 || int(Reply.get("Schema",0))!=1 || Reply.get("Session",Variant()).get_type()!=Variant::STRING)return true;
        String Nonce=Reply["Session"]; if(Nonce.length()!=32)return true;
        if(!Views.count(Session))_setup_session(Session);auto Found=Views.find(Session);if(Found==Views.end())return true;
        auto& View=Found->second;
        if(View.Nonce!=Nonce){View.Nonce=Nonce;View.Request=0;View.Domain="All";View.Pending=Breakpoints;}
        if(String(Reply.get("Event",String()))=="Stopped")View.Domain=Reply.get("Domain",String("All"));
        if(auto Status=Object::cast_to<Label>(ObjectDB::get_instance(View.Label)))
            Status->set_text(String(Reply.get("Domain",String()))+" "+String(Reply.get("State",String()))+" "+String(Reply.get("Reason",String()))+" "+String(Reply.get("Error",String())).left(256));
        if(auto TreeNode=Object::cast_to<Tree>(ObjectDB::get_instance(View.Tree)))if(Reply.get("Breakpoints",Variant()).get_type()==Variant::ARRAY) {
            TreeNode->clear();auto Root=TreeNode->create_item(); Array Locations=Reply["Breakpoints"];
            for(int Index=0;Index<Locations.size() && Index<128;++Index)if(Locations[Index].get_type()==Variant::DICTIONARY) {
                Dictionary Item=Locations[Index];auto Row=TreeNode->create_item(Root);
                Row->set_text(0,String(Item.get("Source",String())).left(1024)+":"+String::num_int64(int64_t(Item.get("Line",0))));
                Row->set_text(1,String(Item.get("AdmittedLines",Array())).left(128));Row->set_text(2,String::num_int64(int64_t(Item.get("Hits",0))));
            }
        }
        return true;
    }
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
    TreeNode->hide();
    if(Data.size()!=4)return;
    Dictionary Snapshot=Data[3];
    if(int(Snapshot.get("Schema",0))!=1 || Snapshot.get("Frames",Variant()).get_type()!=Variant::ARRAY)return;
    TreeNode->show();
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
