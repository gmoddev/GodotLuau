#include "gl_execution_domain.h"
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <new>
#include <string>
#ifdef _WIN32
#include <windows.h>
#endif

// Test executable only. Count C++ new calls; Luau/Godot malloc are excluded.
static bool Counting = false;
static size_t Allocations = 0;
static size_t AllocationBytes = 0;
void* operator new(size_t Size) {
    if (void* Result = std::malloc(Size ? Size : 1)) {
        if (Counting) { ++Allocations; AllocationBytes += Size; }
        return Result;
    }
    throw std::bad_alloc();
}
void* operator new[](size_t Size) { return ::operator new(Size); }
void operator delete(void* Pointer) noexcept { std::free(Pointer); }
void operator delete[](void* Pointer) noexcept { std::free(Pointer); }
void operator delete(void* Pointer, size_t) noexcept { std::free(Pointer); }
void operator delete[](void* Pointer, size_t) noexcept { std::free(Pointer); }

static std::chrono::steady_clock::time_point WallStarted;
static std::clock_t CpuStarted;
static int Mark(lua_State*) {
    Allocations = AllocationBytes = 0;
    WallStarted = std::chrono::steady_clock::now(); CpuStarted = std::clock(); Counting = true;
    return 0;
}
static void Report(const char* Phase, size_t Operations) {
    Counting = false;
    auto Ended = std::chrono::steady_clock::now();
    double CpuMs = 1000.0 * (std::clock() - CpuStarted) / CLOCKS_PER_SEC;
    double WallMs = std::chrono::duration<double, std::milli>(Ended - WallStarted).count();
    std::printf("{\"Phase\":\"%s\",\"Operations\":%zu,\"WallMs\":%.6f,\"CpuMs\":%.6f,\"CppAllocations\":%zu,\"CppAllocationBytes\":%zu}\n",
        Phase, Operations, WallMs, CpuMs, Allocations, AllocationBytes);
}
static int Result(lua_State* Thread) {
    Report(luaL_checkstring(Thread, 1), static_cast<size_t>(luaL_checknumber(Thread, 2))); return 0;
}
int main(int Arguments, char** Values) {
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#endif
    size_t Count = Arguments > 1 ? std::strtoul(Values[1], nullptr, 10) : 1000;
    bool Failed = false;
    GLExecutionDomain Domain(GLDomainKind::Server);
    Domain.SetErrorHandler([&](lua_State*, const std::string& Error) { Failed = true; std::fprintf(stderr, "%s\n", Error.c_str()); });
    lua_pushcfunction(Domain.GetState(), Mark, "Mark"); lua_setglobal(Domain.GetState(), "Mark");
    lua_pushcfunction(Domain.GetState(), Result, "Result"); lua_setglobal(Domain.GetState(), "Result");
    std::string Population = std::to_string(Count);
    auto Owner = Domain.CreateOwner(1);
    auto Run = [&](const std::string& Source) {
        if (!Domain.Execute(Owner, Source, "=HotPaths")) Failed = true;
    };
    Run("Mark(); for Index = 1, " + Population + " do task.spawn(function() end) end; Result('SpawnComplete', " + Population + ")");
    Domain.Tick(0.02);
    Run("shared.Threads = {}; Mark(); for Index = 1, " + Population + " do shared.Threads[Index] = task.defer(function() end) end; Result('DeferCreate', " + Population + "); Mark(); for _, Thread in shared.Threads do task.cancel(Thread) end; Result('Cancel', " + Population + ")");
    Mark(nullptr); Domain.Tick(0.02); Report("CancelledReap", Count);
    Run("Mark(); for Index = 1, " + Population + " do task.defer(function() task.wait(); shared.Done = (shared.Done or 0) + 1 end) end; Result('DeferWaitCreate', " + Population + ")");
    Mark(nullptr); Domain.Tick(0.02); Report("ResumeYield", Count);
    Mark(nullptr); Domain.Tick(0.02); Report("ResumeCompleteReap", Count);
    Run("assert(shared.Done == " + Population + "); Mark(); for Index = 1, " + Population + " do task.delay(1, function() end) end; Result('DelayCreate', " + Population + ")");
    Mark(nullptr); Domain.Tick(0.02); Report("IdlePendingTick", Count);
    Mark(nullptr); Domain.CancelOwner(Owner); Domain.Tick(0.02); Report("OwnerCancelReap", Count);
    Owner = Domain.CreateOwner(1);
    Run("Mark(); for Index = 1, " + Population + " do local Thread = coroutine.create(function() end); assert(coroutine.resume(Thread)) end; Result('ManualResumeComplete', " + Population + ")");
    Domain.Tick(0.02);
    Domain.SetModuleResolver([](lua_State*, int, GLModuleSource& Source) {
        Source = {100, "task.wait(); return {}", "=Module"}; return true;
    });
    Mark(nullptr);
    for (size_t Index = 0; Index < Count; ++Index) Domain.Execute(Domain.CreateOwner(Index + 2), "shared.Value = require(100)", "=Concurrent");
    Report("ConcurrentRequireStart", Count); // Includes compile/owner creation.
    Mark(nullptr); Domain.Tick(0.02); Domain.Tick(0.02); Report("ConcurrentRequireFinish", Count);
    Mark(nullptr); Domain.Shutdown(); Report("Shutdown", Count);
    return Failed ? 1 : 0;
}
