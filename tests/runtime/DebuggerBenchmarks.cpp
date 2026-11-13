#include "gl_execution_domain.h"
#ifdef GL_DEBUGGER_BENCHMARK
#include "gl_debugger.h"
#include "gl_profiler.h"
#endif
#include <chrono>
#include <cstdio>
#include <ctime>
#include <cstdlib>
#include <new>
#include <string>
#ifdef _WIN32
#include <windows.h>
#endif

static bool Counting=false;
static uint64_t Allocations=0,AllocationBytes=0;
void* operator new(size_t Size) {
    if(void* Data=std::malloc(Size?Size:1)){if(Counting){++Allocations;AllocationBytes+=Size;}return Data;}
    throw std::bad_alloc();
}
void* operator new[](size_t Size){return ::operator new(Size);}
void operator delete(void* Data)noexcept{std::free(Data);}
void operator delete[](void* Data)noexcept{std::free(Data);}
void operator delete(void* Data,size_t)noexcept{std::free(Data);}
void operator delete[](void* Data,size_t)noexcept{std::free(Data);}
static std::chrono::steady_clock::time_point Started;
static std::clock_t CpuStarted;
static double WallMicroseconds=0,CpuMicroseconds=0;
static int Mark(lua_State*) {
    Allocations=AllocationBytes=0;Started=std::chrono::steady_clock::now();CpuStarted=std::clock();Counting=true;return 0;
}
static int Finish(lua_State*) {
    Counting=false;WallMicroseconds=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-Started).count();
    CpuMicroseconds=1e6*double(std::clock()-CpuStarted)/CLOCKS_PER_SEC;return 0;
}
static int Observe(lua_State* Thread) {
#ifdef GL_DEBUGGER_BENCHMARK
    if(GLNativeProfileCollectors)GLRecordNativeProfile(Thread,"Call","Probe","Observe");
#endif
    return 0;
}
int main() {
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX|SEM_NOOPENFILEERRORBOX);
#endif
    const char* Modes[]={"Disabled"
#ifdef GL_DEBUGGER_BENCHMARK
        ,"Attached","Breakpoint","Step","Inspect","Profile"
#endif
    };
    for(const char* Name:Modes)for(int Trial=-1;Trial<5;++Trial) {
        GLExecutionDomain Domain(GLDomainKind::Server);bool Failed=false;uint64_t Stops=0,Inspections=0;
        Domain.SetErrorHandler([&](lua_State*,const std::string& Error){Failed=true;std::fprintf(stderr,"[Debugger:Benchmark] %s\n",Error.c_str());});
        for(const auto& Entry:{std::make_pair("Mark",Mark),std::make_pair("Finish",Finish),std::make_pair("Observe",Observe)}) {
            lua_pushcfunction(Domain.GetState(),Entry.second,Entry.first);lua_setglobal(Domain.GetState(),Entry.first);
        }
        std::string Mode=Name;
#ifdef GL_DEBUGGER_BENCHMARK
        if(Mode!="Disabled" && Mode!="Profile") {
            auto& Debugger=Domain.EnableDebugger();
            Debugger.Attach([&](GLDebugger& Debug) {
                ++Stops;
                if(Mode=="Inspect") {
                    Inspections+=Debug.GetFrames().size();
                    for(int Local=1;Local<=16;++Local){if(!lua_getlocal(Debug.GetInspectionThread(),0,Local))break;lua_pop(Debug.GetInspectionThread(),1);++Inspections;}
                }
                return Mode=="Step"?GLDebugAction::Into:GLDebugAction::Continue;
            });
            if(Mode!="Attached")Debugger.SetBreakpoint("res://Bench.luau",4,true);
        }
        if(Mode=="Profile")Domain.EnableProfiler().Start();
#endif
        auto Owner=Domain.CreateOwner(1);
        auto Before=std::chrono::steady_clock::now();
        bool Passed=Domain.Execute(Owner,"Mark()\nlocal Total=0\nfor Index=1,100000 do\n Total+=Index; Observe(Index)\nend\nFinish()\nassert(Total==5000050000)","@res://Bench.luau");
        double ExecuteMicroseconds=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-Before).count();
        if(!Passed || Failed)return 1;
        if(Trial>=0)std::printf("{\"Mode\":\"%s\",\"Trial\":%d,\"Operations\":100000,\"WallMicroseconds\":%.3f,\"CpuMicroseconds\":%.3f,\"ExecuteMicroseconds\":%.3f,\"CppAllocations\":%llu,\"CppAllocationBytes\":%llu,\"VmPeakBytes\":%zu,\"Stops\":%llu,\"Inspections\":%llu}\n",Name,Trial,WallMicroseconds,CpuMicroseconds,ExecuteMicroseconds,(unsigned long long)Allocations,(unsigned long long)AllocationBytes,Domain.GetMemoryAccount().Peak,(unsigned long long)Stops,(unsigned long long)Inspections);
        Domain.CancelOwner(Owner);
    }
    return 0;
}
