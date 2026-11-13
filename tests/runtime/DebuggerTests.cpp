#include "gl_debugger.h"
#include "gl_execution_domain.h"
#include <cstdio>
#include <stdexcept>
#include <thread>
#include <chrono>
#ifdef _WIN32
#include <windows.h>
#endif

namespace {
void Check(bool Value, const char* Message) { if (!Value) throw std::runtime_error(Message); }
void Run(const char* Name, const std::function<void()>& Test) {
    Test(); std::printf("[Debugger:Test] PASS %s\n", Name);
}
}
int main() {
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#endif
    try {
        Run("real breakpoint and live frame survives continue", [] {
            GLExecutionDomain Domain(GLDomainKind::Server);
            auto Owner = Domain.CreateOwner(1); auto& Debugger = Domain.EnableDebugger(); int Hits = 0;
            Debugger.Attach([&](GLDebugger& Debug) {
                ++Hits; auto Frames = Debug.GetFrames();
                Check(Debug.GetState() == GLDebugState::Suspended && Debug.GetInspectionThread() && Debug.GetGeneration() == Owner->Token, "No live generation");
                Check(!Frames.empty() && Frames[0].Source == "res://Main.luau" && Frames[0].Line == 3, "Incorrect breakpoint source");
                const char* Name = lua_getlocal(Debug.GetInspectionThread(), 0, 1);
                Check(Name && lua_tointeger(Debug.GetInspectionThread(), -1) == 41, "Incorrect live local");
                lua_pop(Debug.GetInspectionThread(), 1); return GLDebugAction::Continue;
            });
            Check(Debugger.SetBreakpoint("res://Main.luau", 3, true), "Breakpoint rejected");
            Check(Domain.Execute(Owner, "local Value=40\nValue+=1\nValue+=1\nassert(Value==42)", "@res://Main.luau"), "Execution failed");
            Check(Hits == 1 && Debugger.GetInspectionThread() == nullptr && Debugger.GetFrames().empty(), "Live context escaped resume");
            Check(Debugger.GetBreakpoints()[0].AdmittedLines == std::vector<int>{3}, "Admission not reported");
            Domain.CancelOwner(Owner); Check(Debugger.GetChunkCount() == 0, "Retired code retained");
        });
        Run("step into over and out preserve ordinary calls", [] {
            GLExecutionDomain Domain(GLDomainKind::Client); auto Owner = Domain.CreateOwner(2);
            auto& Debugger = Domain.EnableDebugger(); std::vector<int> Lines;
            Debugger.Attach([&](GLDebugger& Debug) {
                Lines.push_back(Debug.GetFrames()[0].Line);
                if (Lines.size() == 1) return GLDebugAction::Into;
                if (Lines.size() == 2) return GLDebugAction::Over;
                if (Lines.size() == 3) return GLDebugAction::Out;
                return GLDebugAction::Continue;
            });
            Debugger.SetBreakpoint("res://Steps.luau", 6, true);
            Check(Domain.Execute(Owner, "local function Add(Value)\n local Next=Value+1\n Next+=1\n return Next\nend\nlocal Value=Add(40)\nassert(Value==42)", "@res://Steps.luau"), "Stepping failed");
            for (int Line : Lines) std::printf("[Debugger:Steps] Line=%d\n", Line);
            Check(Lines == std::vector<int>({6,2,3,7}), "Source stepping sequence differs");
        });
        Run("enable disable removal remapping and bounded hit count", [] {
            GLExecutionDomain Domain(GLDomainKind::Server); auto Owner = Domain.CreateOwner(3);
            auto& Debugger = Domain.EnableDebugger(); int Hits=0;
            Debugger.Attach([&](GLDebugger&) { ++Hits; return GLDebugAction::Continue; });
            Check(!Debugger.SetBreakpoint("res://Loop.luau", 0, true), "Invalid line admitted");
            Debugger.SetBreakpoint("res://Loop.luau", 2, true, 1000000);
            Debugger.SetBreakpoint("res://Loop.luau", 4, true, 2);
            Check(Domain.Execute(Owner, "local Value=0\n-- comment\nfor Index=1,4 do\n Value+=1\nend\nassert(Value==4)", "@res://Loop.luau"), "Loop failed");
            Check(Hits == 1, "Hit target not applied");
            Check(!Debugger.GetBreakpoints()[0].AdmittedLines.empty() && Debugger.GetBreakpoints()[0].AdmittedLines[0] == 3, "Executable-line remap missing");
            Debugger.SetBreakpoint("res://Loop.luau", 2, false);
            Debugger.SetBreakpoint("res://Loop.luau", 4, false);
            Check(Domain.Execute(Owner, "local Value=0\n\nValue+=1", "@res://Loop.luau") && Hits == 1, "Disabled breakpoint hit");
            Debugger.ClearBreakpoints(); Check(Debugger.GetBreakpoints().empty(), "Removal failed");
        });
        Run("coroutine and module callbacks use their own live stacks", [] {
            GLExecutionDomain Domain(GLDomainKind::Server); auto Owner = Domain.CreateOwner(4);
            Domain.SetModuleResolver([](lua_State*, int, GLModuleSource& Source) { Source={99,"local Value=8\nreturn Value+1","@res://Module.luau"}; return true; });
            auto& Debugger = Domain.EnableDebugger(); std::vector<std::string> Sources;
            Debugger.Attach([&](GLDebugger& Debug) { Sources.push_back(Debug.GetFrames()[0].Source); return GLDebugAction::Continue; });
            Debugger.SetBreakpoint("res://Coroutine.luau", 2, true); Debugger.SetBreakpoint("res://Module.luau", 2, true);
            Check(Domain.Execute(Owner, "local Thread=coroutine.create(function()\n local Value=4\n return Value\nend)\nlocal Ok,Value=coroutine.resume(Thread)\nassert(Ok and Value==4)\nassert(require(99)==9)", "@res://Coroutine.luau"), "Coroutine/module execution failed");
            Check(Sources == std::vector<std::string>({"res://Coroutine.luau","res://Module.luau"}), "Coroutine/module breakpoint missing");
        });
        Run("retirement during a stop cannot execute the next instruction", [] {
            GLExecutionDomain Domain(GLDomainKind::Server); auto Owner = Domain.CreateOwner(5);
            auto& Debugger = Domain.EnableDebugger(); int Errors=0;
            Domain.SetErrorHandler([&](lua_State*, const std::string&) { ++Errors; });
            Debugger.Attach([&](GLDebugger&) { Domain.CancelOwner(Owner); return GLDebugAction::Continue; });
            Debugger.SetBreakpoint("res://Retire.luau", 1, true);
            Check(!Domain.Execute(Owner, "shared.Unexpected=true", "@res://Retire.luau"), "Retired execution reported success");
            Check(!Owner->Alive, "Retired owner remains alive");
            Check(Errors==0, "Cancellation emitted an ordinary script failure");
            Check(Domain.Bootstrap("assert(shared.Unexpected==nil)", "=Check"), "Mutation after retirement");
            Domain.Tick(0); Check(Debugger.GetChunkCount()==0, "Retired chunks remain");
        });
        Run("debugger wait excludes only paused wall time", [] {
            GLDomainLimits Limits; Limits.ResumeMilliseconds=20;
            GLExecutionDomain Domain(GLDomainKind::Server, Limits); auto Owner=Domain.CreateOwner(6);
            auto& Debugger=Domain.EnableDebugger();
            Debugger.Attach([](GLDebugger&) { std::this_thread::sleep_for(std::chrono::milliseconds(35)); return GLDebugAction::Detach; });
            Debugger.SetBreakpoint("res://Budget.luau",1,true);
            Check(Domain.Execute(Owner,"local Value=1\nassert(Value==1)","@res://Budget.luau"),"Debugger wait consumed execution budget");
            Check(Owner->Alive && !Debugger.IsAttached(), "Detach cancelled valid owner");
        });
        Run("pause and domain isolation remain independent", [] {
            GLExecutionDomain Server(GLDomainKind::Server), Client(GLDomainKind::Client);
            auto SO=Server.CreateOwner(7); auto CO=Client.CreateOwner(8); int Stops=0;
            auto& Debugger=Server.EnableDebugger();
            Debugger.Attach([&](GLDebugger& Debug) { ++Stops; Check(Debug.GetReason()=="Pause", "Incorrect pause reason"); return GLDebugAction::Continue; });
            Check(Debugger.RequestPause(),"Pause rejected");
            Check(Client.Execute(CO,"local Value=1", "@res://Same.luau") && Stops==0,"Cross-domain pause");
            Check(Server.Execute(SO,"local Value=1", "@res://Same.luau") && Stops==1,"Pause not admitted");
        });
        std::puts("[Debugger:Test] 7 passed, 0 failed"); return 0;
    } catch (const std::exception& Error) { std::fprintf(stderr,"[Debugger:Test] FAIL %s\n",Error.what()); return 1; }
}
