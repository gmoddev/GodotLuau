#include "gl_execution_domain.h"
#include "gl_stackguard.h"
#include <cstdio>
#include <functional>
#include <stdexcept>
#include <unordered_map>
#ifdef _WIN32
#include <windows.h>
#endif

namespace {
void Check(bool Condition, const char* Message) {
    if (!Condition) throw std::runtime_error(Message);
}
struct Fixture {
    std::vector<std::string> Errors;
    std::unordered_map<uint64_t, std::string> Sources;
    std::unordered_map<uint64_t, uint64_t> Resources, Revisions;
    int SourceLoads = 0;
    GLExecutionDomain Domain;
    explicit Fixture(GLDomainKind Kind = GLDomainKind::Server) : Domain(Kind) {
        Domain.SetErrorHandler([this](lua_State*, const std::string& Error) { Errors.push_back(Error); });
        Domain.SetEnvironmentHook([](lua_State* State, uint64_t Identity) {
            lua_pushnumber(State, static_cast<double>(Identity)); lua_setglobal(State, "script");
        });
        Domain.SetModuleResolver([this](lua_State* State, int Index, GLModuleSource& Module) {
            if (!lua_isnumber(State, Index)) return false;
            uint64_t Identity = static_cast<uint64_t>(lua_tonumber(State, Index));
            auto Found = Sources.find(Identity);
            if (Found == Sources.end()) return false;
            Module = {Identity, Found->second, "=Module" + std::to_string(Identity)};
            return true;
        });
    }
    GLExecutionOwner* Run(uint64_t Identity, const char* Source) {
        auto Owner = Domain.CreateOwner(Identity);
        Check(Owner != nullptr, "CreateOwner failed");
        Check(Domain.Execute(Owner, Source, "=Script" + std::to_string(Identity)), "Script failed to start/execute");
        return Owner;
    }
    void UseRevisions() {
        Domain.SetModuleResolver([this](lua_State* State, int Index, GLModuleSource& Module) {
            if (!lua_isnumber(State, Index)) return false;
            uint64_t Identity = static_cast<uint64_t>(lua_tonumber(State, Index));
            if (Sources.find(Identity) == Sources.end()) return false;
            Module.Identity = Identity;
            Module.ResourceIdentity = Resources.count(Identity) ? Resources.at(Identity) : Identity + 1000;
            Module.Revision = Revisions.count(Identity) ? Revisions.at(Identity) : 1;
            return true;
        });
        Domain.SetModuleLoader([this](GLModuleSource& Module) {
            ++SourceLoads;
            Module.Source = Sources.at(Module.Identity);
            Module.ChunkName = "=Module" + std::to_string(Module.Identity);
            return true;
        });
    }
    void Tick(int Count = 1) { for (int Index = 0; Index < Count; ++Index) Domain.Tick(0.02); }
    void Verify(const char* Source) {
        size_t Before = Errors.size();
        Check(Domain.Bootstrap(Source, "=Assertion"), "Luau assertion failed");
        Check(Errors.size() == Before, "Asynchronous Luau assertion failed");
    }
    void NoErrors() { if (!Errors.empty()) throw std::runtime_error(Errors.front()); }
};
}

int main() {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#endif
    int Passed = 0, Failed = 0;
    auto Test = [&](const char* Name, const std::function<void()>& Body) {
        try { Body(); ++Passed; std::printf("[Runtime:Test] PASS %s\n", Name); }
        catch (const std::exception& Error) { ++Failed; std::printf("[Runtime:Test] FAIL %s: %s\n", Name, Error.what()); }
    };
    for (GLDomainKind Kind : {GLDomainKind::Server, GLDomainKind::Client}) {
        Test(Kind == GLDomainKind::Server ? "Server module sharing and ordering" : "Client module sharing and ordering", [Kind] {
            Fixture F(Kind);
            F.Sources[100] = "_G.Initializations = (_G.Initializations or 0) + 1; return {Value = 0}";
            F.Run(1, "local Counter = require(100); Counter.Value += 1; shared.Counter = Counter");
            F.Run(2, "local Counter = require(100); assert(Counter == shared.Counter and Counter.Value == 1); assert(_G.Initializations == 1)");
            F.NoErrors();
        });
    }
    Test("Server and Client VMs and caches are distinct", [] {
        Fixture Server, Client(GLDomainKind::Client);
        Check(Server.Domain.GetState() != Client.Domain.GetState(), "VMs alias");
        Server.Sources[100] = Client.Sources[100] = "return {Value = 0}";
        Server.Run(1, "require(100).Value = 7; _G.ServerOnly = true");
        Client.Run(1, "assert(require(100).Value == 0 and _G.ServerOnly == nil); assert(__IS_CLIENT and not __IS_SERVER)");
        Server.NoErrors(); Client.NoErrors();
    });
    Test("Concurrent yielding module initializes exactly once", [] {
        Fixture F;
        F.Sources[100] = "_G.Count = (_G.Count or 0) + 1; task.wait(0.04); assert(script == 100); return {Owner = script}";
        F.Run(1, "shared.A = require(100); shared.AReady = true");
        F.Run(2, "shared.B = require(100); shared.BReady = true");
        F.Verify("assert(_G.Count == 1 and not shared.AReady and not shared.BReady)");
        F.Tick(8);
        F.Verify("assert(shared.AReady and shared.BReady and shared.A == shared.B and shared.A.Owner == 100)");
        F.NoErrors();
    });
    Test("Scalar false, number, string and function results preserve identity", [] {
        Fixture F;
        F.Sources[100] = "return false"; F.Sources[101] = "return 42";
        F.Sources[102] = "return 'value'"; F.Sources[103] = "return function() return script end";
        F.Run(1, "assert(require(100) == false and require(101) == 42 and require(102) == 'value'); shared.F = require(103)");
        F.Run(2, "assert(shared.F == require(103) and shared.F() == 103)"); F.NoErrors();
    });
    Test("Recursive and indirect cyclic requires fail predictably", [] {
        Fixture F;
        F.Sources[100] = "return require(101)"; F.Sources[101] = "return require(100)";
        F.Run(1, "local Ok, Err = pcall(require, 100); assert(not Ok and string.find(Err, 'Cyclic')); shared.Done = true");
        F.Tick(6); F.Verify("assert(shared.Done)");
    });
    Test("Concurrent initializer dependency cycle does not deadlock", [] {
        Fixture F;
        F.Sources[100] = "task.wait(); return require(101)";
        F.Sources[101] = "task.wait(); return require(100)";
        F.Run(1, "shared.AFailed = not pcall(require, 100)");
        F.Run(2, "shared.BFailed = not pcall(require, 101)");
        F.Tick(10); F.Verify("assert(shared.AFailed and shared.BFailed)");
    });
    Test("Module failure is sticky and unrelated execution survives", [] {
        Fixture F;
        F.Sources[100] = "_G.Attempts = (_G.Attempts or 0) + 1; error('expected module failure')";
        F.Run(1, "assert(not pcall(require, 100)); assert(not pcall(require, 100)); assert(_G.Attempts == 1)");
        F.Run(2, "shared.Alive = true"); F.Verify("assert(shared.Alive)");
    });
    Test("Missing and multiple module results fail", [] {
        Fixture F;
        F.Sources[100] = "return"; F.Sources[101] = "return 1, 2";
        F.Run(1, "assert(not pcall(require, 100)); assert(not pcall(require, 101))");
    });
    Test("Source revision and explicit destruction invalidate only that module", [] {
        Fixture F;
        F.Sources[100] = "return {Value = 1}"; F.Sources[101] = "return {}";
        F.Run(1, "shared.Old = require(100); shared.Other = require(101)");
        F.Sources[100] = "return {Value = 2}";
        F.Run(2, "assert(require(100).Value == 2 and shared.Old.Value == 1 and require(101) == shared.Other)");
        F.Domain.InvalidateModule(100);
        F.Sources[100] = "return {Value = 3}";
        F.Run(3, "assert(require(100).Value == 3 and require(101) == shared.Other)"); F.NoErrors();
    });
    Test("Invalidated pending module wakes callers with an error", [] {
        Fixture F;
        F.Sources[100] = "task.wait(10); return {}";
        F.Run(1, "shared.Failed = not pcall(require, 100)");
        F.Domain.InvalidateModule(100); F.Tick(3); F.Verify("assert(shared.Failed)");
    });
    Test("Revision cache loads only on misses and distinguishes replacement resources", [] {
        Fixture F; F.UseRevisions(); F.Sources[100] = "return {Value = 1}";
        F.Run(1, "shared.Old = require(100); for Index = 1, 100 do assert(require(100) == shared.Old) end");
        Check(F.SourceLoads == 1, "Cached require loaded source or path");
        F.Sources[100] = "return {Value = 2}"; F.Revisions[100] = 2;
        F.Run(2, "assert(require(100).Value == 2 and shared.Old.Value == 1)");
        F.Sources[100] = "return {Value = 3}"; F.Resources[100] = 2000; F.Revisions[100] = 2;
        F.Run(3, "assert(require(100).Value == 3)");
        Check(F.SourceLoads == 3, "Source/resource revision change did not initialize once");
        F.Domain.InvalidateModule(100);
        F.Run(4, "assert(require(100).Value == 3)");
        auto Owner = F.Run(5, "shared.Close = function() assert(require(100).Value == 3) end");
        lua_getglobal(Owner->Anchor, "shared"); lua_getfield(Owner->Anchor, -1, "Close");
        int Reference = GLReference(Owner->Anchor, -1); lua_pop(Owner->Anchor, 2);
        F.Domain.AddCloseCallback(Owner->Anchor, Reference);
        F.Domain.Shutdown(); F.NoErrors();
        Check(F.SourceLoads == 4, "Shutdown reloaded a ready revision");
    });
    Test("Revision change cancels pending initialization and wakes all old waiters", [] {
        Fixture F; F.UseRevisions(); F.Sources[100] = "task.wait(10); return {}";
        F.Run(1, "shared.AFailed = not pcall(require, 100)");
        F.Run(2, "shared.BFailed = not pcall(require, 100)");
        Check(F.SourceLoads == 1, "Concurrent revision loaded twice");
        F.Sources[100] = "return {Value = 2}"; F.Revisions[100] = 2;
        F.Run(3, "shared.New = require(100)");
        F.Tick(3); F.Verify("assert(shared.AFailed and shared.BFailed and shared.New.Value == 2)");
        Check(F.SourceLoads == 2, "New revision did not load exactly once"); F.NoErrors();
    });
    Test("Revision loader preserves dependency cycles and sticky failures", [] {
        Fixture F; F.UseRevisions();
        F.Sources[100] = "return require(101)"; F.Sources[101] = "return require(100)";
        F.Run(1, "shared.Failed = not pcall(require, 100)"); F.Tick(6);
        F.Run(2, "assert(shared.Failed and not pcall(require, 100))");
        Check(F.SourceLoads == 2, "Sticky failure loaded source again");
        F.Sources[100] = "return false"; F.Revisions[100] = 2;
        F.Run(3, "assert(require(100) == false)");
        Check(F.SourceLoads == 3, "Recovery revision did not load once");
    });
    Test("Destroying first caller does not cancel shared initialization", [] {
        Fixture F;
        F.Sources[100] = "task.wait(0.04); return {Value = 8}";
        auto First = F.Run(1, "shared.MustNotRun = require(100)");
        F.Run(2, "shared.Result = require(100)");
        F.Domain.CancelOwner(First); F.Tick(8);
        F.Verify("assert(shared.MustNotRun == nil and shared.Result.Value == 8)"); F.NoErrors();
    });
    Test("Script environments and identities survive interleaved yields", [] {
        Fixture F;
        F.Run(1, "OnlyA = 1; assert(script == 1); task.wait(); assert(script == 1 and OnlyB == nil); shared.A = true");
        F.Run(2, "OnlyB = 2; assert(script == 2 and OnlyA == nil); task.wait(); assert(script == 2); shared.B = true");
        F.Tick(3); F.Verify("assert(shared.A and shared.B and OnlyA == nil and OnlyB == nil)"); F.NoErrors();
    });
    Test("Module global assignments do not leak to caller or another module", [] {
        Fixture F;
        F.Sources[100] = "ModuleGlobal = 9; return function() return script, ModuleGlobal end";
        F.Sources[101] = "assert(ModuleGlobal == nil); return script";
        F.Run(1, "local Fn = require(100); local Id, Value = Fn(); assert(Id == 100 and Value == 9 and ModuleGlobal == nil); assert(require(101) == 101)"); F.NoErrors();
    });
    Test("_G and shared are domain-shared but ordinary globals are local", [] {
        Fixture F;
        F.Run(1, "_G.Value = 7; shared.Value = 8; Ordinary = 9");
        F.Run(2, "assert(_G.Value == 7 and shared.Value == 8 and Ordinary == nil)"); F.NoErrors();
    });
    Test("Script errors leave unrelated scripts and domain alive", [] {
        Fixture F;
        auto Bad = F.Domain.CreateOwner(1);
        Check(!F.Domain.Execute(Bad, "error('expected script error')", "=Bad"), "Expected script error was accepted");
        F.Run(2, "shared.Survived = true"); F.Verify("assert(shared.Survived)");
    });
    Test("spawn, defer, delay, wait arguments and reentrant scheduling", [] {
        Fixture F;
        F.Run(1, R"LUAU(
shared.Order = {'main'}
task.spawn(function(Value) table.insert(shared.Order, Value); task.defer(function() shared.Reentrant = true end) end, 'spawn')
task.defer(function(Value) table.insert(shared.Order, Value) end, 'defer')
task.delay(0.04, function(Value) shared.Delayed = Value end, 17)
assert(#shared.Order == 2 and not shared.Delayed)
local Waited, Time = task.wait(0.04)
assert(Waited >= 0.04 and Time >= Waited)
shared.Waited = true
)LUAU");
        F.Tick(8); F.Verify("assert(shared.Order[3] == 'defer' and shared.Delayed == 17 and shared.Reentrant and shared.Waited)"); F.NoErrors();
    });
    Test("Cancel owner suppresses all pending task kinds", [] {
        Fixture F;
        auto Owner = F.Run(1, "task.defer(function() shared.Bad = true end); task.delay(1, function() shared.Bad = true end); task.spawn(function() task.wait(); shared.Bad = true end); task.wait(); shared.Bad = true");
        F.Domain.CancelOwner(Owner); F.Tick(60); F.Verify("assert(not shared.Bad)"); F.NoErrors();
    });
    Test("Cancellation during callback and child task spawn is reentrant-safe", [] {
        Fixture F;
        lua_pushcfunction(F.Domain.GetState(), [](lua_State* Thread) -> int {
            auto Owner = GLGetOwner(Thread); Owner->Domain->CancelOwner(Owner); return 0;
        }, "CancelSelf"); lua_setglobal(F.Domain.GetState(), "CancelSelf");
        F.Run(1, "task.defer(function() task.spawn(function() task.wait(); shared.Bad = true end); CancelSelf() end)");
        F.Tick(5); F.Verify("assert(not shared.Bad)"); F.NoErrors();
    });
    Test("External callbacks that yield remain scheduler-owned", [] {
        Fixture F;
        auto Owner = F.Run(1, "function Callback() task.wait(); shared.CallbackDone = script end");
        lua_State* Thread = lua_newthread(Owner->Anchor);
        lua_getglobal(Thread, "Callback");
        Check(GLResume(Thread, nullptr, 0) == LUA_YIELD, "Callback did not yield");
        lua_pop(Owner->Anchor, 1); F.Tick(3);
        F.Verify("assert(shared.CallbackDone == 1)"); F.NoErrors();
    });
    Test("Cancelled callback references cannot alias new owners", [] {
        Fixture F;
        auto Owner = F.Run(1, "function Callback() shared.Bad = true end");
        lua_getglobal(Owner->Anchor, "Callback"); int Reference = GLReference(Owner->Anchor, -1); lua_pop(Owner->Anchor, 1);
        Check(GLReferenceAlive(Owner->Anchor, Reference), "Reference not tracked");
        F.Domain.CancelOwner(Owner); F.Tick(2);
        F.Run(2, "shared.Good = true");
        Check(GLReferenceState(Reference) == nullptr, "Cancelled reference remained live");
        GLUnreference(nullptr, Reference); // double release must be harmless
        F.Verify("assert(shared.Good and not shared.Bad)"); F.NoErrors();
    });
    Test("Repeated creation cancellation GC and restart", [] {
        Fixture F;
        for (int Index = 0; Index < 100; ++Index) {
            auto Owner = F.Run(1, "task.delay(10, function() error('cancelled task executed') end)");
            F.Domain.CancelOwner(Owner); F.Tick();
            lua_gc(F.Domain.GetState(), LUA_GCCOLLECT, 0); F.Tick();
        }
        Check(F.Domain.GetOwnerCount() == 0 && F.Domain.GetTaskCount() == 0 && F.Domain.GetReferenceCount() == 0, "Owner resources were retained");
        F.Run(1, "shared.Restarted = true"); F.Verify("assert(shared.Restarted)"); F.NoErrors();
    });
    Test("Repeated domain shutdown and no work after shutdown", [] {
        for (int Index = 0; Index < 20; ++Index) {
            Fixture F; F.Run(1, "task.defer(function() error('shutdown task executed') end)");
            F.Domain.Shutdown(); F.Domain.Shutdown(); F.Tick(3);
            Check(!F.Domain.CreateOwner(2), "Shutdown accepted an owner");
            Check(F.Domain.GetReferenceCount() == 0, "Shutdown retained callbacks"); F.NoErrors();
        }
    });
    Test("Context authority is independent of mutable compatibility globals", [] {
        Fixture F(GLDomainKind::Client);
        lua_pushcfunction(F.Domain.GetState(), [](lua_State* Thread) -> int {
            lua_pushboolean(Thread, GLIsClient(Thread)); return 1;
        }, "ActualClient"); lua_setglobal(F.Domain.GetState(), "ActualClient");
        F.Run(1, "__IS_CLIENT = false; __IS_SERVER = true; assert(ActualClient()); task.defer(function() assert(ActualClient()) end)");
        F.Tick(2); F.NoErrors();
    });
    Test("Task cancellation detaches native condition wait ownership", [] {
        Fixture F;
        int Detached = 0;
        F.Domain.SetThreadInvalidationHook([&](lua_State*) { ++Detached; });
        lua_pushcfunction(F.Domain.GetState(), [](lua_State* Thread) -> int {
            GLCaptureWait(Thread);
            lua_pushstring(Thread, "__WAIT_SIGNAL__");
            return lua_yield(Thread, 1);
        }, "NativeWait"); lua_setglobal(F.Domain.GetState(), "NativeWait");
        F.Run(1, "for Index = 1, 32 do task.cancel(task.defer(function() end)) end; local Pending = task.spawn(function() NativeWait(); shared.Bad = true end); task.cancel(Pending); task.cancel(Pending)");
        F.Tick(3); Check(Detached == 1, "Native cancellation hook was missing or duplicated");
        Check(F.Domain.GetReferenceCount() == 0, "Cancelled native wait retained its guard");
        F.Verify("assert(not shared.Bad)"); F.NoErrors();
    });
    Test("Close callbacks run once with admission closed and cached require available", [] {
        Fixture F;
        F.Sources[100] = "return {Value = 12}";
        auto Owner = F.Run(1, "require(100); function Close() shared.Closed = (shared.Closed or 0) + 1; assert(require(100).Value == 12); assert(not pcall(task.defer, function() end)) end");
        lua_getglobal(Owner->Anchor, "Close");
        int Reference = GLReference(Owner->Anchor, -1); lua_pop(Owner->Anchor, 1);
        F.Domain.AddCloseCallback(Owner->Anchor, Reference);
        F.Domain.StopAdmission(); F.Domain.Shutdown(); F.Domain.Shutdown();
        lua_getglobal(F.Domain.GetState(), "shared"); lua_getfield(F.Domain.GetState(), -1, "Closed");
        Check(lua_tonumber(F.Domain.GetState(), -1) == 1, "Close callback did not run exactly once");
        lua_pop(F.Domain.GetState(), 2); F.NoErrors();
    });
    Test("Completed coroutines cannot be resumed a second time", [] {
        Fixture F;
        auto Owner = F.Run(1, "function Callback() shared.Calls = (shared.Calls or 0) + 1 end");
        lua_State* Thread = lua_newthread(Owner->Anchor);
        lua_getglobal(Thread, "Callback");
        Check(GLResume(Thread, nullptr, 0) == LUA_OK, "Initial callback failed");
        Check(GLResume(Thread, nullptr, 0) == LUA_OK, "Completed callback was not safely ignored");
        lua_pop(Owner->Anchor, 1); F.Verify("assert(shared.Calls == 1)"); F.NoErrors();
    });
    Test("A module child task is not a blocking initializer dependency", [] {
        Fixture F;
        F.Sources[100] = "task.spawn(function() require(101); shared.ChildReady = true end); return {}";
        F.Sources[101] = "return require(100)";
        F.Run(1, "require(100)"); F.Tick(5);
        F.Verify("assert(shared.ChildReady)"); F.NoErrors();
    });
    Test("Deep requires and spawn dispatch yield at a bounded native depth", [] {
        Fixture F;
        for (uint64_t Identity = 100; Identity < 355; ++Identity)
            F.Sources[Identity] = "return require(" + std::to_string(Identity + 1) + ")";
        F.Sources[355] = "return 42";
        F.Run(1, "shared.DeepResult = require(100)"); F.Tick(600);
        F.Verify("assert(shared.DeepResult == 42)");
        F.Run(2, "local function Recurse() shared.Spawns = (shared.Spawns or 0) + 1; if shared.Spawns < 200 then task.spawn(Recurse) end end; Recurse()");
        F.Tick(40); F.Verify("assert(shared.Spawns == 200)"); F.NoErrors();
    });
    Test("Service callbacks keep their registering owner across dispatch and yields", [] {
        Fixture F;
        auto Subscriber = F.Run(1, "shared.Run, shared.Release, shared.IsAlive = _GLBindCallback(function(Value) assert(script == 1); shared.Started = Value; task.wait(); shared.MustNotFinish = true end)");
        F.Run(2, "shared.Run(42); assert(shared.Started == 42 and shared.IsAlive())");
        F.Domain.CancelOwner(Subscriber); F.Tick(3);
        F.Run(3, "shared.Run(99); assert(not shared.IsAlive()); shared.Release(); assert(shared.Started == 42 and not shared.MustNotFinish)");
        F.NoErrors();
    });
    Test("Trusted service polling survives its first subscriber and hides its bootstrap hook", [] {
        Fixture F;
        F.Domain.ExposeBootstrapSpawner();
        F.Domain.Bootstrap("local Spawn = _GLDomainSpawn; _GLDomainSpawn = nil; function StartService() Spawn(function() while true do shared.Polls = (shared.Polls or 0) + 1; task.wait() end end) end", "=ServiceBootstrap");
        auto Subscriber = F.Run(1, "assert(_GLDomainSpawn == nil); StartService()");
        F.Domain.CancelOwner(Subscriber); F.Tick(4);
        F.Run(2, "assert(shared.Polls >= 4 and _GLDomainSpawn == nil)"); F.NoErrors();
    });
    Test("Wait guards invalidate independently of an orphaned native source", [] {
        int RetiredGuard = LUA_NOREF;
        {
            Fixture F;
            auto Owner = F.Run(1, "shared.Waiting = coroutine.running(); coroutine.yield('__WAIT_SIGNAL__'); shared.Bad = true");
            lua_getglobal(Owner->Anchor, "shared"); lua_getfield(Owner->Anchor, -1, "Waiting");
            lua_State* Waiting = lua_tothread(Owner->Anchor, -1); lua_pop(Owner->Anchor, 2);
            RetiredGuard = GLCaptureWait(Waiting);
            Check(GLReferenceAlive(Owner->Anchor, RetiredGuard), "Wait guard was not retained");
            F.Domain.CancelThread(Waiting);
            Check(GLReferenceState(RetiredGuard) == nullptr, "Task cancellation retained an orphan wait guard");
            F.Tick(3); F.Verify("assert(not shared.Bad)"); F.NoErrors();
        }
        Fixture Replacement;
        auto Owner = Replacement.Run(1, "shared.New = true");
        Check(!GLReferenceAlive(Owner->Anchor, RetiredGuard), "Retired wait aliased a replacement domain");
    });
    Test("A manually resumed coroutine joins scheduler ownership when it waits externally", [] {
        Fixture F;
        lua_pushcfunction(F.Domain.GetState(), [](lua_State* Thread) -> int {
            lua_pushnumber(Thread, GLCaptureWait(Thread)); return 1;
        }, "CaptureWait"); lua_setglobal(F.Domain.GetState(), "CaptureWait");
        auto Owner = F.Run(1, "shared.Coroutine = coroutine.create(function() shared.Guard = CaptureWait(); coroutine.yield('__WAIT_SIGNAL__'); task.wait(); shared.Done = true end); assert(coroutine.resume(shared.Coroutine))");
        lua_getglobal(Owner->Anchor, "shared"); lua_getfield(Owner->Anchor, -1, "Coroutine");
        lua_State* Thread = lua_tothread(Owner->Anchor, -1); lua_pop(Owner->Anchor, 1);
        lua_getfield(Owner->Anchor, -1, "Guard"); int Guard = static_cast<int>(lua_tonumber(Owner->Anchor, -1)); lua_pop(Owner->Anchor, 2);
        Check(F.Domain.CanResume(Thread), "External waiter was not adopted");
        GLUnreference(nullptr, Guard);
        Check(GLResume(Thread, nullptr, 0) == LUA_YIELD, "Waiter could not continue into a timed wait");
        F.Tick(3); F.Verify("assert(shared.Done)"); F.NoErrors();
    });
    Test("Manual coroutines adopt timed and module waits and cannot revive dead owners", [] {
        Fixture F;
        F.Sources[100] = "task.wait(); return 42";
        auto Owner = F.Run(1, "shared.Manual = coroutine.create(function() task.wait(); shared.Timed = true; assert(require(100) == 42); shared.Required = true end); assert(coroutine.resume(shared.Manual)); shared.Unstarted = coroutine.create(function() shared.Bad = true end); shared.Wrapped = coroutine.wrap(function() shared.Bad = true end)");
        F.Tick(8); F.Verify("assert(shared.Timed and shared.Required)");
        F.Domain.CancelOwner(Owner); F.Tick(1);
        F.Run(2, "assert(not coroutine.resume(shared.Unstarted)); assert(not pcall(shared.Wrapped)); assert(not shared.Bad)");
        F.Run(3, "local Thread = coroutine.create(function() shared.Bad = true end); task.cancel(Thread); assert(not coroutine.resume(Thread)); shared.Cancelled = Thread; local Wrapped = coroutine.wrap(function(Value) return Value, nil, 42 end); local A, B, C = Wrapped(12); assert(A == 12 and B == nil and C == 42)");
        F.Tick(1); F.Run(4, "assert(not coroutine.resume(shared.Cancelled)); assert(not shared.Bad)"); F.NoErrors();
        F.Sources[101] = "task.wait(); return 43";
        F.Run(5, "local Thread = coroutine.create(function() assert(require(101) == 43); shared.ManualRequire = true end); assert(coroutine.resume(Thread))");
        F.Tick(5); F.Verify("assert(shared.ManualRequire)"); F.NoErrors();
    });
    Test("Explicit getfenv and setfenv retain Luau function environment behavior", [] {
        Fixture F;
        F.Run(1, "local function Read() return Value end; local Environment = {Value = 42}; setfenv(Read, Environment); assert(getfenv(Read) == Environment and Read() == 42); Value = 12; shared.Environment = getfenv(1); shared.Read = Read");
        F.Run(2, "assert(Value == nil and shared.Read() == 42 and getfenv(1) ~= shared.Environment and shared.Environment.script == 1)");
        F.NoErrors();
    });
    Test("Native stack guard uses real thread bounds under sanitizer instrumentation", [] {
        Check(!gl_stack_exhausted(GLStackPointer()), "Shallow native call was classified as stack exhaustion");
#if defined(_WIN32) || defined(__linux__)
        char* Floor = gl_stack_floor();
        Check(Floor != nullptr, "OS stack bounds are unavailable");
        Check(gl_stack_exhausted(reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(Floor) + GL_STACK_MARGIN / 2)), "Guard did not reject the reserved stack margin");
#endif
    });
    std::printf("[Runtime:Test] %d passed, %d failed\n", Passed, Failed);
    return Failed == 0 ? 0 : 1;
}
