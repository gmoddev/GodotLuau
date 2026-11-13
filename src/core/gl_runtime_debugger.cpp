#include "gl_runtime_debugger.h"
#include "gl_debugger.h"
#include "gl_debug_inspection.h"
#include "gl_domain_host.h"
#include "gl_asset.h"
#include "luau_language.h"
#include <godot_cpp/classes/crypto.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

using namespace godot;
namespace {
uint64_t HostId=0, CommandWindow=0, LastRequest=0;
unsigned Commands=0;
std::string Session; // Godot built-in objects cannot initialize before extension binding.
bool Polling=false, Detached=false;
uint64_t AwaitingStop=0;
bool StopAcknowledged=false;
GLDebugger* Suspended=nullptr;
const char* DomainName(const GLExecutionDomain& Domain) { return Domain.GetKind()==GLDomainKind::Server?"Server":"Client"; }
void Poll(bool Immediate=false) {
    if(!GLRuntimeDebuggerAvailable())return;
    bool Before=Polling; Polling=true;
    // Godot's public line_poll itself polls only every 2,048 calls. A bounded
    // burst is needed while no Lua instructions/engine frames can advance.
    for(int Index=0;Index<(Immediate?2048:1);++Index)EngineDebugger::get_singleton()->line_poll();
    Polling=Before;
}
void Send(GLDebugger* Debugger, const String& Event, int64_t Request=0, const String& Error={},const Dictionary& Extra={}) {
    if(!GLRuntimeDebuggerAvailable())return;
    Dictionary Reply; Reply["Schema"]=1; Reply["Session"]=String::utf8(Session.c_str()); Reply["Event"]=Event; Reply["Request"]=Request;
    if(!Error.is_empty())Reply["Error"]=Error.left(256);
    if(Debugger) {
        Reply["Domain"]=DomainName(Debugger->GetDomain()); Reply["State"]=GLDebugger::StateName(Debugger->GetState());
        Reply["Generation"]=int64_t(Debugger->GetGeneration()); Reply["StopId"]=int64_t(Debugger->GetStopId());
        Reply["CoroutineId"]=int64_t(Debugger->GetCoroutineId());
        auto Thread=Debugger->GetInspectionThread();Reply["StackTruncated"]=Thread && lua_stackdepth(Thread)>64;
        auto Frames=Debugger->GetFrames();if(!Frames.empty()){Reply["Source"]=String::utf8(Frames[0].Source.c_str());Reply["Line"]=Frames[0].Line;}
        Reply["Reason"]=String::utf8(Debugger->GetReason().c_str());
        Array Breakpoints; size_t Bytes=0;
        for(const auto& Entry:Debugger->GetBreakpoints()) {
            if((Bytes+=Entry.Source.size())>32768 || Breakpoints.size()>=128){Reply["Truncated"]=true;break;}
            Dictionary Item; Item["Source"]=String::utf8(Entry.Source.c_str()); Item["Line"]=Entry.Line;
            Item["Enabled"]=Entry.Enabled; Item["Hits"]=int64_t(Entry.Hits); Item["BreakOnHit"]=int64_t(Entry.BreakOnHit);
            Array Actual; for(int Line:Entry.AdmittedLines)if(Actual.size()<16)Actual.push_back(Line);
            Item["AdmittedLines"]=Actual; Breakpoints.push_back(Item);
        }
        Reply["Breakpoints"]=Breakpoints;
    }
    Reply.merge(Extra,true);
    if(UtilityFunctions::var_to_bytes(Reply).size()>65536){Reply.erase("Breakpoints");Reply["Truncated"]=true;}
    if(UtilityFunctions::var_to_bytes(Reply).size()>65536){Reply.erase("Value");Reply["Ok"]=false;Reply["Error"]="Diagnostic response exceeds 64 KiB";}
    Array Data; Data.push_back(Reply); EngineDebugger::get_singleton()->send_message("godotluau:debugger",Data);
}
GLDebugAction Stop(GLDebugger& Debugger) {
    if(!GLRuntimeDebuggerAvailable())return GLDebugAction::Detach;
    struct ActiveScope { GLDebugger* Before=Suspended; ~ActiveScope(){Suspended=Before;} } Active;
    Suspended=&Debugger;
    AwaitingStop=Debugger.GetStopId();StopAcknowledged=false;
    Send(&Debugger,"Suspending");
    uint64_t Deadline=Time::get_singleton()->get_ticks_msec()+1000;
    while(!StopAcknowledged && !Detached && Time::get_singleton()->get_ticks_msec()<Deadline) {
        Poll(true);if(!StopAcknowledged)OS::get_singleton()->delay_usec(1000);
    }
    AwaitingStop=0;
    auto Disconnect=[] {
        Detached=true;
        if(auto Host=Object::cast_to<GLDomainHost>(ObjectDB::get_instance(HostId)))
            for(bool Client:{false,true})if(auto Domain=Host->GetExistingDomain(Client))
                if(auto Current=Domain->GetDebugger())Current->Detach();
    };
    if(!StopAcknowledged || Detached){Disconnect();return GLDebugAction::Detach;}
    Send(&Debugger,"Stopped");
    auto EngineDebug=EngineDebugger::get_singleton();
    // A real continue/step command replaces this sentinel. Godot leaves it
    // untouched when its loop exits because the peer disconnected.
    EngineDebug->set_lines_left(-2);
    EngineDebug->script_debug(LuauLanguage::get_singleton(),true,false);
    if(!GLRuntimeDebuggerAvailable() || EngineDebug->get_lines_left()==-2){Disconnect();return GLDebugAction::Detach;}
    GLDebugAction Action=EngineDebug->get_lines_left()>0?
        (EngineDebug->get_depth()<0?GLDebugAction::Into:EngineDebug->get_depth()>0?GLDebugAction::Out:GLDebugAction::Over):GLDebugAction::Continue;
    Send(&Debugger,"Continuing"); return Action;
}
}
bool GLRuntimeDebuggerAvailable() {
    auto Debugger=EngineDebugger::get_singleton(); auto System=OS::get_singleton();
    return Debugger && Debugger->is_active() && System && System->has_feature("editor") &&
        !Engine::get_singleton()->is_editor_hint() && System->get_thread_caller_id()==System->get_main_thread_id();
}
Error GLReloadLuauScripts(const Array& Scripts) {
    auto System=OS::get_singleton();
    if(!System || System->get_thread_caller_id()!=System->get_main_thread_id() ||
        (GLExecutionDomain::IsExecuting() && !Suspended) ||
        (!Engine::get_singleton()->is_editor_hint() && !GLRuntimeDebuggerAvailable()))return ERR_UNAVAILABLE;
    Error Result=OK;
    for(int Index=0;Index<Scripts.size() && Index<256;++Index) {
        if(Scripts[Index].get_type()!=Variant::OBJECT)continue;
        Ref<LuauScript> Source=Scripts[Index];if(Source.is_null())continue;
        Error Status=Source->_reload(false);
        if(Status!=OK){Result=Status;UtilityFunctions::print("[Debugger:Reload] Source reload failed: ",int(Status));}
    }
    if(Scripts.size()>256){Result=ERR_OUT_OF_MEMORY;UtilityFunctions::print("[Debugger:Reload] Selective reload exceeds 256 resources");}
    return Result;
}
GLDebugger* GLGetSuspendedDebugger() { return Suspended && Suspended->GetInspectionThread()?Suspended:nullptr; }
void GLConfigureRuntimeDebugger(GLDomainHost& Host, GLExecutionDomain& Domain) {
    if(!GLRuntimeDebuggerAvailable() || Domain.GetKind()==GLDomainKind::EditorPreview || Detached)return;
    auto EngineDebug=EngineDebugger::get_singleton();
    if(!HostId) {
        Ref<Crypto> Provider; Provider.instantiate(); auto Bytes=Provider->generate_random_bytes(16);
        if(Bytes.size()!=16 || EngineDebug->has_capture("godotluau"))return;
        HostId=Host.get_instance_id(); Session=Bytes.hex_encode().utf8().get_data(); LastRequest=0;
        EngineDebug->register_message_capture("godotluau",Callable(&Host,"CaptureDebuggerCommand"));
    }
    if(HostId!=uint64_t(Host.get_instance_id()))return;
    auto& Debugger=Domain.EnableDebugger(); Debugger.Attach(Stop); Debugger.SetPollHandler([]{Poll();});
    Debugger.SetSourceHandler([&Debugger](const std::string& Source,int Lines) {
        String Path=String::utf8(Source.c_str()); if(!GLProjectResourcePath(Path))return;
        Poll(true); auto EngineDebug=EngineDebugger::get_singleton();
        auto Existing=Debugger.GetBreakpoints();
        for(int Line=1;Line<=(std::min)(65536,Lines);++Line)if(EngineDebug->is_breakpoint(Line,Path)) {
            bool Known=false; for(const auto& Entry:Existing)if(Entry.Source==Source && Entry.Line==Line)Known=true;
            if(!Known)Debugger.SetBreakpoint(Source,Line,true);
        }
    });
    Send(&Debugger,"Hello");
}
void GLRuntimeDebuggerTick(GLDomainHost& Host) {
    if(HostId==uint64_t(Host.get_instance_id()) && GLRuntimeDebuggerAvailable())Poll();
}
void GLRuntimeDebuggerShutdown(GLDomainHost& Host) {
    if(HostId!=uint64_t(Host.get_instance_id()))return;
    if(auto Debugger=EngineDebugger::get_singleton())if(Debugger->has_capture("godotluau"))Debugger->unregister_message_capture("godotluau");
    HostId=0; Session.clear(); LastRequest=0; Detached=false;AwaitingStop=0;StopAcknowledged=false;
}
bool GLCaptureDebuggerCommand(GLDomainHost& Host, const String& Message, const Array& Data) {
    if(Message!="command")return false;
    if(!GLRuntimeDebuggerAvailable() || HostId!=uint64_t(Host.get_instance_id()) ||
        (GLExecutionDomain::IsExecuting() && !Polling && !Suspended))return true;
    uint64_t Now=Time::get_singleton()->get_ticks_msec(); if(Now-CommandWindow>=1000){CommandWindow=Now;Commands=0;}
    if(++Commands>32)return true;
    if(Data.size()!=1 || Data[0].get_type()!=Variant::DICTIONARY){Send(nullptr,"Error",0,"Expected one command dictionary");return true;}
    Dictionary Request=Data[0];
    if(Request.size()>12){Send(nullptr,"Error",0,"Too many debugger fields");return true;}
    Array Keys=Request.keys();
    for(int Index=0;Index<Keys.size();++Index) {
        Variant Key=Keys[Index];
        if(Key.get_type()!=Variant::STRING){Send(nullptr,"Error",0,"Invalid field name");return true;}
        String Name=Key;
        if(Name!="Schema" && Name!="Session" && Name!="Request" && Name!="Op" && Name!="Domain" && Name!="Source" && Name!="Line" && Name!="Enabled" && Name!="BreakOnHit" && Name!="Expression" && Name!="Frame" && Name!="StopId") {
            Send(nullptr,"Error",0,"Unknown debugger field");return true;
        }
        Variant Value=Request[Key];
        if((Name=="Schema" || Name=="Request" || Name=="Line" || Name=="BreakOnHit" || Name=="Frame" || Name=="StopId") && Value.get_type()!=Variant::INT){Send(nullptr,"Error",0,"Expected integer field");return true;}
        if(Name=="Enabled" && Value.get_type()!=Variant::BOOL){Send(nullptr,"Error",0,"Expected boolean field");return true;}
        if(Name=="Session" || Name=="Op" || Name=="Domain" || Name=="Source" || Name=="Expression")
            if(Value.get_type()!=Variant::STRING || String(Value).length()>1024 || String(Value).utf8().length()>1024){Send(nullptr,"Error",0,"Expected bounded string field");return true;}
    }
    if(Request.size()>12 || Request.get("Schema",Variant()).get_type()!=Variant::INT || int(Request["Schema"])!=1 ||
       Request.get("Session",Variant()).get_type()!=Variant::STRING || String(Request["Session"])!=String::utf8(Session.c_str()) ||
       Request.get("Request",Variant()).get_type()!=Variant::INT || Request.get("Op",Variant()).get_type()!=Variant::STRING) {
        Send(nullptr,"Error",0,"Invalid debugger envelope"); return true;
    }
    int64_t Id=Request["Request"]; if(Id<=0 || uint64_t(Id)<=LastRequest){Send(nullptr,"Error",Id,"Stale or duplicate request");return true;}
    LastRequest=uint64_t(Id);
    String Op=Request["Op"]; String Selected=Request.get("Domain",String("All"));
    if(Op.length()>32 || (Selected!="All" && Selected!="Server" && Selected!="Client")){Send(nullptr,"Error",Id,"Unsupported command or domain");return true;}
    if(Op=="AcknowledgeStop") {
        if(Suspended && AwaitingStop && Request.get("StopId",Variant()).get_type()==Variant::INT &&
            int64_t(Request["StopId"])==int64_t(AwaitingStop) && Selected==DomainName(Suspended->GetDomain()))StopAcknowledged=true;
        else Send(nullptr,"Error",Id,"Stale or wrong-domain stop acknowledgment");
        return true;
    }
    String Source=Request.get("Source",String());
    if((Op=="Breakpoint" || Op=="Reload") && (Request.get("Source",Variant()).get_type()!=Variant::STRING || Source.utf8().length()>1024 ||
        !GLProjectResourcePath(Source) || (Source.get_extension()!="luau" && Source.get_extension()!="lua") ||
        (Op=="Breakpoint" && (Request.get("Line",Variant()).get_type()!=Variant::INT || Request.get("Enabled",Variant()).get_type()!=Variant::BOOL)))) {
        Send(nullptr,"Error",Id,"Invalid project breakpoint");return true;
    }
    if(Op=="Detach" && Selected=="All")Detached=true;
    bool Matched=false;
    for(bool Client:{false,true}) {
        auto Domain=Host.GetExistingDomain(Client); auto Debugger=Domain?Domain->GetDebugger():nullptr;
        if(!Debugger || (Selected!="All" && Selected!=DomainName(*Domain)))continue;
        Matched=true; bool Success=true;
        if(Op=="Breakpoint") {
            int64_t Line=Request["Line"],Hit=Request.get("BreakOnHit",0);
            Success=Line>0 && Line<=1000000 && Hit>=0 && Hit<=1000000 && Debugger->SetBreakpoint(Source.utf8().get_data(),int(Line),bool(Request["Enabled"]),uint32_t(Hit));
        } else if(Op=="ClearBreakpoints")Debugger->ClearBreakpoints();
        else if(Op=="Pause")Success=Debugger->RequestPause();
        else if(Op=="StepOut") { Success=Suspended==Debugger; if(Success)Debugger->SetNextAction(GLDebugAction::Out); }
        else if(Op=="Stop") { Success=Suspended==Debugger; if(Success)Debugger->SetNextAction(GLDebugAction::Stop); }
        else if(Op=="Detach")Debugger->Detach();
        else if(Op=="Reload") {
            auto Frames=Debugger->GetFrames();
            Success=Suspended==Debugger && !Frames.empty() && Source==String::utf8(Frames[0].Source.c_str()) && ResourceLoader::get_singleton()->has_cached(Source);
            if(Success) {
                Ref<LuauScript> Resource=ResourceLoader::get_singleton()->load(Source,"LuauScript");
                if(Resource.is_null())Success=false;
                else {Array Scripts;Scripts.push_back(Resource);Success=GLReloadLuauScripts(Scripts)==OK;}
            }
            Send(Debugger,Success?"Reloaded":"Error",Id,Success?String():String("Saved-source reload failed or is unavailable"));
            continue;
        }
        else if(Op=="Watch") {
            if(Suspended!=Debugger || Request.get("Expression",Variant()).get_type()!=Variant::STRING)Send(Debugger,"Error",Id,"Watch requires the selected live suspended domain");
            else {
                int64_t Frame=Request.get("Frame",0);
                Dictionary Result=GLDebugEvaluate(Frame>=0 && Frame<64?int(Frame):-1,Request["Expression"]);
                Send(Debugger,"Watch",Id,String(),Result);
            }
            continue;
        }
        else if(Op!="Status")Success=false;
        Send(Debugger,Success?"Reply":"Error",Id,Success?String():String("Command unavailable in current state"));
    }
    if(!Matched)Send(nullptr,"Error",Id,"No matching live debugger domain");
    return true;
}
