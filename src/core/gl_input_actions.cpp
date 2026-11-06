#include "input_actions.h"
#include "gl_execution_domain.h"
#include "gl_runtime.h"
#include "roblox_input.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <array>
#include <limits>
#include <map>

namespace {
std::map<uint64_t,uint64_t> Services;
template<class T> T* Resolve(uint64_t Id) { return Object::cast_to<T>(ObjectDB::get_instance(Id)); }
int Integer(const Variant& Value) { return static_cast<int>(static_cast<int64_t>(Value)); }
bool Whole(const Variant& Value, int Minimum, int Maximum) {
    if (Value.get_type()!=Variant::INT && Value.get_type()!=Variant::FLOAT) return false;
    double Number=Value;
    return std::isfinite(Number) && Number>=Minimum && Number<=Maximum && Number==std::floor(Number);
}
int Button(int Code) {
    static const int Buttons[]={0,1,2,3,9,10,-1,-1,7,8,6,4,11,12,13,14};
    return Code>=1000 && Code<=1015?Buttons[Code-1000]:-1;
}
int PhysicalCode(int Source, int Code) { return Source==GLInputGraph::GamepadButton?Button(Code):Code; }
bool KeyCode(int Code) { return Code>0 && Code<512 && roblox_keycode_to_godot(Code)!=KEY_UNKNOWN; }
void PushNode(lua_State* Thread, Node* Target) {
    GLPushNodeHandle(Thread,Target);
    luaL_getmetatable(Thread,"GodotObject"); lua_setmetatable(Thread,-2);
}
void PushValue(lua_State* Thread, int Type, GLInputGraph::Value Value) {
    if (Type==GLInputGraph::Bool) lua_pushboolean(Thread,Value.Down());
    else if (Type==GLInputGraph::Scalar) lua_pushnumber(Thread,Value.X);
    else {
        lua_getglobal(Thread,"Vector2"); lua_getfield(Thread,-1,"new"); lua_remove(Thread,-2);
        lua_pushnumber(Thread,Value.X); lua_pushnumber(Thread,Value.Y); lua_call(Thread,2,1);
    }
}
void RequireClient(lua_State* Thread) {
    if (!GLExecutionDomain::IsClientExecution()) luaL_error(Thread,"[Input:Authority] Input APIs require Client execution");
}
}

bool GLInputAllowed() { return !GLExecutionDomain::IsExecuting() || GLExecutionDomain::IsClientExecution(); }

InputDefinition::InputDefinition() { set_meta("_gl_bridge",true); Define("Enabled",true); }
void InputDefinition::_bind_methods() {
    ClassDB::bind_method(D_METHOD("Configure","Options"),&InputDefinition::Configure);
    ClassDB::bind_method(D_METHOD("SetConfiguration","Options"),&InputDefinition::SetConfiguration);
    ClassDB::bind_method(D_METHOD("GetConfiguration"),&InputDefinition::GetConfiguration);
    ClassDB::bind_method(D_METHOD("GetOption","Key"),&InputDefinition::GetOption);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"Configuration"),"SetConfiguration","GetConfiguration");
}
bool InputDefinition::Valid(const String& Key, const Variant& Value) const {
    if (!HasOption(Key)) return false;
    if (Key=="Enabled" || Key=="Consume" || Key=="ExactModifiers") return Value.get_type()==Variant::BOOL;
    if (Key=="Priority") return Whole(Value,-10000,10000);
    if (Key=="ValueType" || Key=="SourceType") return Whole(Value,0,2);
    if (Key=="KeyCode") return Whole(Value,0,1015);
    if (Key=="Device") return Whole(Value,-1,15);
    if (Key=="Scale") return (Value.get_type()==Variant::INT || Value.get_type()==Variant::FLOAT) && std::isfinite(double(Value)) && std::abs(double(Value))<=1000;
    if (Key=="Vector") { if (Value.get_type()!=Variant::VECTOR2) return false; Vector2 V=Value; return V.is_finite() && V.length()<=1000; }
    if (Key=="Modifiers") {
        if (Value.get_type()!=Variant::PACKED_INT32_ARRAY) return false;
        PackedInt32Array Items=Value; if (Items.size()>4) return false;
        for (int Index=0;Index<Items.size();++Index) {
            if (!GLInputGraph::IsModifier(Items[Index])) return false;
            for (int Previous=0;Previous<Index;++Previous) if (Items[Previous]==Items[Index]) return false;
        }
        return true;
    }
    return false;
}
bool InputDefinition::Configure(const Dictionary& Options) {
    if (!GLInputAllowed() || Options.size()>12 || Revision==std::numeric_limits<uint64_t>::max()) return false;
    Dictionary Next=Configuration.duplicate(true);
    Array Keys=Options.keys();
    bool Changed=false;
    for (int Index=0;Index<Keys.size();++Index) {
        if (Keys[Index].get_type()!=Variant::STRING || !Valid(Keys[Index],Options[Keys[Index]])) return false;
        Changed |= Next[Keys[Index]]!=Options[Keys[Index]];
        Next[Keys[Index]]=Options[Keys[Index]];
    }
    if (Object::cast_to<InputBinding>(this)) {
        int Source=Integer(Next["SourceType"]), Code=Integer(Next["KeyCode"]);
        if ((Source==0 && !KeyCode(Code)) || (Source==1 && (Code<1 || Code>3)) || (Source==2 && Button(Code)<0)) return false;
        PackedInt32Array Mods=Next["Modifiers"];
        if (Source==0) for (int Modifier:Mods) if (Modifier==Code) return false;
    }
    if (Changed) { Configuration=Next; ++Revision; MarkDirty(); }
    return true;
}
void InputDefinition::MarkDirty() {
    if (auto Previous=Resolve<InputService>(PreviousService)) Previous->MarkDirty();
    PreviousService=0;
    for (Node* Parent=get_parent();Parent;Parent=Parent->get_parent()) if (auto Service=Object::cast_to<InputService>(Parent)) {
        PreviousService=Service->get_instance_id(); Service->MarkDirty(); break;
    }
}
void InputDefinition::_notification(int What) {
    if (What==NOTIFICATION_PARENTED || What==NOTIFICATION_UNPARENTED || What==NOTIFICATION_ENTER_TREE || What==NOTIFICATION_EXIT_TREE) MarkDirty();
}
InputContext::InputContext() { Define("Priority",0); Define("Consume",true); }
InputContext::~InputContext() { if (OwnerGuard) GLUnreference(nullptr,OwnerGuard); }
void InputContext::AdoptOwner(lua_State* Thread) {
    if (OwnerGuard) return;
    lua_pushboolean(Thread,true); OwnerGuard=GLReference(Thread,-1); lua_pop(Thread,1);
}
bool InputContext::OwnerAlive() const { return !OwnerGuard || GLReferenceState(OwnerGuard)!=nullptr; }
InputAction::InputAction() { Define("ValueType",0); Callbacks.reserve(128); }
InputBinding::InputBinding() {
    Define("SourceType",0); Define("KeyCode",32); Define("Device",0); Define("Priority",0);
    Define("Consume",false); Define("ExactModifiers",false); Define("Modifiers",PackedInt32Array());
    Define("Scale",1.0); Define("Vector",Vector2(1,0));
}
void InputAction::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_gl_disconnect","Reference"),&InputAction::_gl_disconnect);
    ClassDB::bind_method(D_METHOD("GetValue"),&InputAction::GetValue);
    ADD_SIGNAL(MethodInfo("Pressed")); ADD_SIGNAL(MethodInfo("Released"));
    ADD_SIGNAL(MethodInfo("Changed",PropertyInfo(Variant::NIL,"Value",PROPERTY_HINT_NONE,"",PROPERTY_USAGE_NIL_IS_VARIANT)));
    ADD_SIGNAL(MethodInfo("Canceled",PropertyInfo(Variant::STRING,"Reason")));
}
InputAction::~InputAction() { for (const auto& Item:Callbacks) GLUnreference(nullptr,Item.Reference); }
Variant InputAction::GetValue() const {
    if (!GLInputAllowed()) return Variant();
    int Type=Integer(GetOption("ValueType"));
    if (Type==0) return Current.Down(); if (Type==1) return Current.X;
    return Vector2(Current.X,Current.Y);
}
int InputAction::Connect(lua_State* Thread, int Index, int Signal, bool Once) {
    if (!GLInputAllowed() || Signal<0 || Signal>3) return 0;
    Callbacks.erase(std::remove_if(Callbacks.begin(),Callbacks.end(),[](const Callback& Item){return GLReferenceState(Item.Reference)==nullptr;}),Callbacks.end());
    if (Callbacks.size()>=128) return 0;
    int Reference=GLReference(Thread,Index); Callbacks.push_back({Reference,Signal,Once}); return Reference;
}
void InputAction::_gl_disconnect(int Reference) {
    auto Found=std::find_if(Callbacks.begin(),Callbacks.end(),[&](const Callback& Item){return Item.Reference==Reference;});
    if (Found!=Callbacks.end()) { GLUnreference(nullptr,Reference); Callbacks.erase(Found); }
}
void InputAction::Publish(const GLInputGraph::Transition& Change) {
    const uint64_t Id=get_instance_id();
    auto Send=[&](int Signal)->bool {
        static const char* Names[]={"Pressed","Changed","Released","Canceled"};
        if (Signal==1) emit_signal(Names[Signal],GetValue());
        else if (Signal==3) emit_signal(Names[Signal],String(Change.Reason));
        else emit_signal(Names[Signal]);
        if (Resolve<InputAction>(Id)!=this) return false;
        std::array<Callback,128> Snapshot{}; size_t Count=0;
        for (const auto& Item:Callbacks) if (Item.Signal==Signal) Snapshot[Count++]=Item;
        for (size_t Index=0;Index<Count;++Index) {
            auto Item=Snapshot[Index];
            auto Present=std::find_if(Callbacks.begin(),Callbacks.end(),[&](const Callback& Entry){return Entry.Reference==Item.Reference;});
            if (Present==Callbacks.end() || !GLReferenceState(Item.Reference)) continue;
            if (Item.Once) Callbacks.erase(Present); // disconnect before reentrant dispatch, release after it
            GLDispatch(Item.Reference,[&](lua_State* Thread)->int {
                // GLDispatch has already rooted the function on its owned
                // thread. Retire the public connection before invoking it.
                if (Item.Once) GLUnreference(nullptr,Item.Reference);
                if (Signal==1) { PushValue(Thread,Change.Type,Change.After); return 1; }
                if (Signal==3) { lua_pushstring(Thread,Change.Reason); return 1; }
                return 0;
            });
            if (Item.Once) GLUnreference(nullptr,Item.Reference);
            if (Resolve<InputAction>(Id)!=this) return false;
        }
        return true;
    };
    if (Change.Reason[0] && Change.Before.Down() && !Change.After.Down() && !Send(3)) return;
    if (!Change.Before.Down() && Change.After.Down() && !Send(0)) return;
    if (!Send(1)) return;
    if (Change.Before.Down() && !Change.After.Down()) Send(2);
}

InputService::InputService() { set_meta("_gl_bridge",true); }
void InputService::_bind_methods() {
    ClassDB::bind_method(D_METHOD("GetDiagnostics"),&InputService::GetDiagnostics);
    ClassDB::bind_method(D_METHOD("Cancel","Reason"),&InputService::Cancel);
    ClassDB::bind_method(D_METHOD("DeviceChanged","Device","Connected"),&InputService::DeviceChanged);
}
void InputService::_ready() {
    if (Engine::get_singleton()->is_editor_hint() || !GLInputAllowed()) return;
    ViewportId=get_viewport()->get_instance_id();
    auto Found=Services.find(ViewportId);
    if (Found!=Services.end() && Resolve<InputService>(Found->second)) {
        UtilityFunctions::print("[Input:Routing] Duplicate InputService is inactive"); return;
    }
    if (Services.size()>=16) return;
    Services[ViewportId]=get_instance_id(); Active=true; set_process(true); set_process_priority(-100);
    Input::get_singleton()->connect("joy_connection_changed",Callable(this,"DeviceChanged"));
    // Reuse the raw service as the single Godot event adapter.
    Node* Parent=get_parent(); bool Present=false;
    if (Parent) for (int Index=0;Index<Parent->get_child_count();++Index) if (Object::cast_to<UserInputService>(Parent->get_child(Index))) {
        AdapterId=Parent->get_child(Index)->get_instance_id(); Present=true; break;
    }
    if (Parent && !Present) { auto Raw=memnew(UserInputService); AdapterId=Raw->get_instance_id(); Raw->set_name("UserInputService"); Parent->add_child(Raw); }
}
void InputService::_notification(int What) {
    if (What==NOTIFICATION_APPLICATION_FOCUS_OUT) Cancel("FocusLost");
    if (What==NOTIFICATION_EXIT_TREE && Active) {
        Active=false;
        auto Found=Services.find(ViewportId);
        if (Found!=Services.end() && Found->second==uint64_t(get_instance_id())) Services.erase(Found);
        Cancel("ServiceRetired");
    }
}
void InputService::Compile() {
    if (!Dirty || Publishing) return;
    Dirty=false;
    std::vector<GLInputGraph::Context> Contexts;
    std::vector<GLInputGraph::Action> Actions;
    std::vector<GLInputGraph::Binding> Bindings;
    bool Overflow=false;
    for (int C=0;C<get_child_count() && !Overflow;++C) {
        auto Context=Object::cast_to<InputContext>(get_child(C)); if (!Context) continue;
        if (!Context->OwnerAlive()) { Context->queue_free(); continue; }
        if (Contexts.size()>=GLInputGraph::MaximumContexts) { Overflow=true; break; }
        Contexts.push_back({uint64_t(Context->get_instance_id()),Context->GetRevision(),Integer(Context->GetOption("Priority")),bool(Context->GetOption("Enabled")),bool(Context->GetOption("Consume"))});
        for (int A=0;A<Context->get_child_count() && !Overflow;++A) {
            auto Action=Object::cast_to<InputAction>(Context->get_child(A)); if (!Action) continue;
            if (Actions.size()>=GLInputGraph::MaximumActions) { Overflow=true; break; }
            Actions.push_back({uint64_t(Action->get_instance_id()),Action->GetRevision(),uint64_t(Context->get_instance_id()),Integer(Action->GetOption("ValueType")),bool(Action->GetOption("Enabled"))});
            for (int B=0;B<Action->get_child_count();++B) {
                auto Binding=Object::cast_to<InputBinding>(Action->get_child(B)); if (!Binding) continue;
                if (Bindings.size()>=GLInputGraph::MaximumBindings) { Overflow=true; break; }
                GLInputGraph::Binding Row;
                Row.Id=Binding->get_instance_id(); Row.Revision=Binding->GetRevision(); Row.ActionId=Action->get_instance_id();
                Row.Type=Integer(Binding->GetOption("SourceType")); Row.Code=PhysicalCode(Row.Type,Integer(Binding->GetOption("KeyCode")));
                Row.Device=Integer(Binding->GetOption("Device")); Row.Priority=Integer(Binding->GetOption("Priority"));
                Row.Enabled=Binding->GetOption("Enabled"); Row.Consume=Binding->GetOption("Consume"); Row.ExactModifiers=Binding->GetOption("ExactModifiers");
                Row.Scale=Binding->GetOption("Scale"); Vector2 Direction=Binding->GetOption("Vector"); Row.X=Direction.x; Row.Y=Direction.y;
                PackedInt32Array Mods=Binding->GetOption("Modifiers"); for (int M=0;M<Mods.size();++M) Row.Modifiers[M]=Mods[M];
                Bindings.push_back(Row);
            }
        }
    }
    if (Overflow) { ++Rejections; Contexts.clear(); Actions.clear(); Bindings.clear(); }
    std::array<GLInputGraph::Transition,GLInputGraph::MaximumActions> Removed{}; size_t Count=0;
    for (const auto& Old:Graph.GetStates()) if (Old.Current.Down() && std::none_of(Actions.begin(),Actions.end(),[&](const auto& Item){return Item.Id==Old.Definition.Id;})) {
        Removed[Count++]={Old.Definition.Id,Old.Definition.Type,Old.Current,{},Overflow?"CapacityExceeded":"DefinitionRetired"};
    }
    if (!Graph.Compile(Contexts,Actions,Bindings)) {
        ++Rejections; Graph.Cancel("InvalidDefinition"); Publish(); return;
    }
    for (size_t Index=0;Index<Count;++Index) if (auto Action=Resolve<InputAction>(Removed[Index].Id)) Action->Commit({});
    for (const auto& State:Graph.GetStates()) if (auto Action=Resolve<InputAction>(State.Definition.Id)) Action->Commit(State.Current);
    const uint64_t Id=get_instance_id(); Publishing=true;
    for (size_t Index=0;Index<Count;++Index) {
        if (auto Action=Resolve<InputAction>(Removed[Index].Id)) Action->Publish(Removed[Index]);
        if (Resolve<InputService>(Id)!=this) return;
    }
    Publishing=false; Publish();
}
void InputService::Publish() {
    // Never retain a graph-vector reference across script dispatch.
    std::array<GLInputGraph::Transition,GLInputGraph::MaximumActions> Changes{};
    size_t Count=Graph.GetChanges().size(); std::copy(Graph.GetChanges().begin(),Graph.GetChanges().end(),Changes.begin());
    for (const auto& State:Graph.GetStates()) if (auto Action=Resolve<InputAction>(State.Definition.Id)) Action->Commit(State.Current);
    const uint64_t Id=get_instance_id(); Publishing=true;
    for (size_t Index=0;Index<Count;++Index) {
        if (auto Action=Resolve<InputAction>(Changes[Index].Id)) Action->Publish(Changes[Index]);
        if (Resolve<InputService>(Id)!=this) return;
    }
    Publishing=false;
}
void InputService::_process(double) {
    if (!Active) return;
    for (int Index=0;Index<get_child_count();++Index) if (auto Context=Object::cast_to<InputContext>(get_child(Index))) if (!Context->OwnerAlive()) Dirty=true;
    Compile();
}
void InputService::Cancel(const String& Reason) {
    if (!GLInputAllowed() || Publishing) return;
    // Reason storage must outlive the graph's synchronous publication.
    CharString Text=Reason.utf8(); Graph.Cancel(Text.get_data()); Publish();
}
void InputService::DeviceChanged(int Device, bool Connected) { if (Active && !Connected && !Publishing) { Graph.Disconnect(Device); Publish(); } }
void InputService::Deliver(uint64_t Adapter, const Ref<InputEvent>& Event, bool Processed) {
    if (!Active || Publishing || Adapter!=AdapterId) return;
    const uint64_t Id=get_instance_id(); Compile(); if (Resolve<InputService>(Id)!=this) return;
    if (auto Key=Object::cast_to<InputEventKey>(*Event)) {
        int Code=godot_key_to_roblox(Key->get_keycode());
        if (Key->get_location()==KEY_LOCATION_RIGHT && (Code==304 || Code==306 || Code==308 || Code==310)) --Code;
        Graph.Event(GLInputGraph::Key,Code,0,Key->is_pressed(),Processed,Key->is_echo());
    } else if (auto Mouse=Object::cast_to<InputEventMouseButton>(*Event)) Graph.Event(GLInputGraph::MouseButton,int(Mouse->get_button_index()),0,Mouse->is_pressed(),Processed);
    else if (auto Pad=Object::cast_to<InputEventJoypadButton>(*Event)) Graph.Event(GLInputGraph::GamepadButton,int(Pad->get_button_index()),Pad->get_device(),Pad->is_pressed(),Processed);
    else return;
    Publish();
}
Dictionary InputService::GetDiagnostics() const {
    Dictionary Result; if (!GLInputAllowed()) return Result;
    Result["Active"]=Active; Result["Actions"]=int64_t(Graph.GetStates().size()); Result["Bindings"]=int64_t(Graph.GetBindingCount());
    Result["Revision"]=int64_t(Graph.GetRevision()); Result["EvaluatedBindings"]=int64_t(Graph.GetEvaluatedBindings()); Result["RejectedGraphs"]=int64_t(Rejections);
    return Result;
}
void GLInputDeliver(Viewport* View, uint64_t Adapter, const Ref<InputEvent>& Event, bool Processed) {
    if (!View) return; auto Found=Services.find(View->get_instance_id());
    if (Found!=Services.end()) if (auto Service=Resolve<InputService>(Found->second)) Service->Deliver(Adapter,Event,Processed);
}
void GLInputCancel(Viewport* View, const char* Reason) {
    if (!View) return; auto Found=Services.find(View->get_instance_id());
    if (Found!=Services.end()) if (auto Service=Resolve<InputService>(Found->second)) Service->Cancel(Reason);
}
void GLInputAdoptOwner(lua_State* Thread, Node* Target) {
    if (auto Context=Object::cast_to<InputContext>(Target)) Context->AdoptOwner(Thread);
}

namespace {
Variant ReadOption(lua_State* Thread, const char* Key, int Index) {
    if (!strcmp(Key,"Modifiers")) {
        luaL_checktype(Thread,Index,LUA_TTABLE); int Length=lua_objlen(Thread,Index);
        if (Length>4) luaL_error(Thread,"[Input:Definition] At most four modifiers");
        PackedInt32Array Result;
        for (int I=1;I<=Length;++I) { lua_rawgeti(Thread,Index,I); double V=luaL_checknumber(Thread,-1); if (!std::isfinite(V) || V<303 || V>310 || V!=std::floor(V)) luaL_error(Thread,"[Input:Definition] Invalid modifier"); Result.push_back(int(V)); lua_pop(Thread,1); }
        return Result;
    }
    if (!strcmp(Key,"Vector")) {
        luaL_checktype(Thread,Index,LUA_TTABLE); lua_getfield(Thread,Index,"X"); double X=luaL_checknumber(Thread,-1); lua_pop(Thread,1);
        lua_getfield(Thread,Index,"Y"); double Y=luaL_checknumber(Thread,-1); lua_pop(Thread,1); return Vector2(X,Y);
    }
    if (lua_isboolean(Thread,Index)) return bool(lua_toboolean(Thread,Index));
    if (lua_type(Thread,Index)==LUA_TNUMBER) return lua_tonumber(Thread,Index);
    luaL_error(Thread,"[Input:Definition] Expected a typed input option"); return Variant();
}
Dictionary ReadOptions(lua_State* Thread, int Index) {
    Dictionary Result; if (lua_isnoneornil(Thread,Index)) return Result;
    luaL_checktype(Thread,Index,LUA_TTABLE); lua_pushnil(Thread);
    while (lua_next(Thread,Index)) {
        if (Result.size()>=12 || lua_type(Thread,-2)!=LUA_TSTRING) luaL_error(Thread,"[Input:Definition] Invalid options");
        const char* Key=lua_tostring(Thread,-2); Result[String(Key)]=ReadOption(Thread,Key,lua_gettop(Thread)); lua_pop(Thread,1);
    }
    return Result;
}
int InputMethod(lua_State* Thread) {
    RequireClient(Thread); Node* Target=GLNodeUpvalue(Thread,1);
    if (!Target || Target->is_queued_for_deletion()) luaL_error(Thread,"[Input:Lifetime] Retired input Instance");
    const char* Method=lua_tostring(Thread,lua_upvalueindex(2));
    if (!strcmp(Method,"GetValue")) {
        auto Action=Object::cast_to<InputAction>(Target); PushValue(Thread,Integer(Action->GetOption("ValueType")),Action->GetCurrent()); return 1;
    }
    if (!strcmp(Method,"GetDiagnostics")) {
        Dictionary Values=Object::cast_to<InputService>(Target)->GetDiagnostics(); lua_newtable(Thread); Array Keys=Values.keys();
        for (int I=0;I<Keys.size();++I) { Variant Value=Values[Keys[I]]; if (Value.get_type()==Variant::BOOL) lua_pushboolean(Thread,bool(Value)); else lua_pushnumber(Thread,double(Value)); lua_setfield(Thread,-2,String(Keys[I]).utf8().get_data()); } return 1;
    }
    if (!strcmp(Method,"Configure")) {
        if (!Object::cast_to<InputDefinition>(Target)->Configure(ReadOptions(Thread,2))) luaL_error(Thread,"[Input:Definition] Rejected input configuration"); return 0;
    }
    if (!strcmp(Method,"AddContext") || !strcmp(Method,"AddAction") || !strcmp(Method,"AddBinding")) {
        Dictionary Options=ReadOptions(Thread,3); InputDefinition* Created=nullptr;
        String Name;
        if (!strcmp(Method,"AddBinding")) {
            double Number=luaL_checknumber(Thread,2); if (!std::isfinite(Number) || Number!=std::floor(Number) || Number<1 || Number>1015) luaL_error(Thread,"[Input:Definition] Invalid binding code");
            int Code=int(Number); Options["KeyCode"]=Code;
            if (!Options.has("SourceType")) Options["SourceType"]=Code>=1000?2:Code<=3?1:0;
            Created=memnew(InputBinding); Name="Binding";
        } else {
            size_t Length=0; const char* Text=luaL_checklstring(Thread,2,&Length);
            if (!Length || Length>128 || memchr(Text,0,Length)) luaL_error(Thread,"[Input:Definition] Invalid input name");
            Name=String::utf8(Text,int(Length));
            if (!strcmp(Method,"AddContext")) Created=memnew(InputContext); else Created=memnew(InputAction);
        }
        if (!Created->Configure(Options)) { memdelete(Created); luaL_error(Thread,"[Input:Definition] Rejected input configuration"); }
        gl_track_orphan(Created);
        GLInputAdoptOwner(Thread,Created); Created->set_name(Name);
        const uint64_t Id=Created->get_instance_id(); Target->add_child(Created);
        PushNode(Thread,Resolve<InputDefinition>(Id)); return 1;
    }
    return 0;
}
int SignalConnect(lua_State* Thread) {
    RequireClient(Thread); auto Action=Object::cast_to<InputAction>(GLNodeUpvalue(Thread,1));
    if (!Action || Action->is_queued_for_deletion()) luaL_error(Thread,"[Input:Lifetime] Retired action");
    luaL_checktype(Thread,2,LUA_TFUNCTION);
    int Reference=Action->Connect(Thread,2,int(lua_tointeger(Thread,lua_upvalueindex(2))),lua_toboolean(Thread,lua_upvalueindex(3)));
    if (!Reference) luaL_error(Thread,"[Input:Limit] Action callback limit reached");
    GLInputPushConnection(Thread,Action,Reference); return 1;
}
}
bool GLInputIndex(lua_State* Thread, Node* Target, const char* Key) {
    auto Definition=Object::cast_to<InputDefinition>(Target); auto Service=Object::cast_to<InputService>(Target);
    if (!Definition && !Service) return false;
    if (Definition && Definition->HasOption(Key)) {
        RequireClient(Thread); Variant Value=Definition->GetOption(Key);
        if (Value.get_type()==Variant::BOOL) lua_pushboolean(Thread,bool(Value));
        else if (Value.get_type()==Variant::VECTOR2) { Vector2 V=Value; PushValue(Thread,2,{V.x,V.y}); }
        else if (Value.get_type()==Variant::PACKED_INT32_ARRAY) { PackedInt32Array Values=Value; lua_newtable(Thread); for (int I=0;I<Values.size();++I) {lua_pushinteger(Thread,Values[I]); lua_rawseti(Thread,-2,I+1);} }
        else lua_pushnumber(Thread,double(Value)); return true;
    }
    if (auto Action=Object::cast_to<InputAction>(Target)) {
        if (!strcmp(Key,"Value")) { RequireClient(Thread); PushValue(Thread,Integer(Action->GetOption("ValueType")),Action->GetCurrent()); return true; }
        static const char* Signals[]={"Pressed","Changed","Released","Canceled"};
        for (int Signal=0;Signal<4;++Signal) if (!strcmp(Key,Signals[Signal])) {
            RequireClient(Thread); lua_newtable(Thread);
            for (int Once=0;Once<2;++Once) { GLPushNodeHandle(Thread,Action); lua_pushinteger(Thread,Signal); lua_pushboolean(Thread,Once); lua_pushcclosure(Thread,SignalConnect,Once?"Once":"Connect",3); lua_setfield(Thread,-2,Once?"Once":"Connect"); }
            return true;
        }
    }
    bool Method=(Definition && !strcmp(Key,"Configure")) || (Service && (!strcmp(Key,"AddContext") || !strcmp(Key,"GetDiagnostics"))) ||
        (Object::cast_to<InputContext>(Target) && !strcmp(Key,"AddAction")) || (Object::cast_to<InputAction>(Target) && (!strcmp(Key,"AddBinding") || !strcmp(Key,"GetValue")));
    if (Method) { RequireClient(Thread); GLPushNodeHandle(Thread,Target); lua_pushstring(Thread,Key); lua_pushcclosure(Thread,InputMethod,Key,2); return true; }
    return false;
}
bool GLInputWrite(lua_State* Thread, Node* Target, const char* Key) {
    auto Definition=Object::cast_to<InputDefinition>(Target); if (!Definition && !Object::cast_to<InputService>(Target)) return false;
    // Parenting/name retain the established Instance contract. Every semantic
    // property is closed, typed and checked before generic bridge fallbacks.
    if (!strcmp(Key,"Parent") || !strcmp(Key,"Name")) { RequireClient(Thread); GLInputAdoptOwner(Thread,Target); return false; }
    RequireClient(Thread); Dictionary Options; Options[String(Key)]=ReadOption(Thread,Key,3);
    if (!Definition || !Definition->Configure(Options)) luaL_error(Thread,"[Input:Definition] Unknown, read-only or invalid input property");
    return true;
}
