#include "gl_execution_domain.h"
#include "Luau/Compiler.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace {
struct GLReferenceEntry { GLExecutionOwner* Owner; lua_State* WaitingThread = nullptr; };
std::unordered_map<int, GLReferenceEntry>& GLReferences() {
    static std::unordered_map<int, GLReferenceEntry> Entries;
    return Entries;
}
std::unordered_map<lua_State*, GLExecutionOwner*>& GLAnchors() {
    static std::unordered_map<lua_State*, GLExecutionOwner*> Entries;
    return Entries;
}
int GLNextReference = 0x10000000;
void GLClearWaitReferences(lua_State* Thread) {
    std::vector<int> References;
    for (const auto& Entry : GLReferences()) if (Entry.second.WaitingThread == Thread) References.push_back(Entry.first);
    for (int Reference : References) GLUnreference(nullptr, Reference);
}
const char* GLRequireWrapper = R"LUAU(
local Begin, Poll, Yield = __DomainRequire, __DomainPoll, coroutine.yield
__DomainRequire, __DomainPoll = nil, nil
function require(Target)
    local Ready, Value = Begin(Target)
    while not Ready do
        Yield("__DOMAIN_MODULE__", Value)
        Ready, Value = Poll(Value)
    end
    return Value
end
)LUAU";
}

GLExecutionOwner* GLGetOwner(lua_State* Thread) {
    return Thread ? static_cast<GLExecutionOwner*>(lua_getthreaddata(Thread)) : nullptr;
}
lua_State* GLGetOwnerState(lua_State* Thread) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    return Owner && Owner->Alive ? Owner->Anchor : nullptr;
}
bool GLStateAlive(lua_State* Anchor) {
    auto Found = GLAnchors().find(Anchor);
    return Found != GLAnchors().end() && Found->second->Alive;
}
lua_State* GLReferenceState(int Reference) {
    auto Found = GLReferences().find(Reference);
    return Found != GLReferences().end() && Found->second.Owner->Alive
        ? Found->second.Owner->Anchor : nullptr;
}
bool GLReferenceAlive(lua_State* Anchor, int Reference) {
    return Anchor && GLReferenceState(Reference) == Anchor;
}
int GLReference(lua_State* Thread, int Index) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || Owner->Domain->IsClosing())
        luaL_error(Thread, "[Runtime:Ownership] Cannot retain work for an inactive owner");
    if (GLNextReference == std::numeric_limits<int>::max())
        luaL_error(Thread, "[Runtime:Ownership] Registry reference space exhausted");
    // Never recycle public callback IDs. Old native callbacks cannot alias a new
    // callback if Lua later reuses an anchor address or an internal registry slot.
    int Reference = GLNextReference++;
    lua_pushvalue(Thread, Index);
    lua_rawseti(Thread, LUA_REGISTRYINDEX, Reference);
    GLReferences().emplace(Reference, GLReferenceEntry{Owner});
    return Reference;
}
void GLUnreference(lua_State*, int Reference) {
    auto Found = GLReferences().find(Reference);
    if (Found == GLReferences().end()) return;
    lua_State* State = Found->second.Owner->Domain->GetState();
    if (State) { lua_pushnil(State); lua_rawseti(State, LUA_REGISTRYINDEX, Reference); }
    GLReferences().erase(Found);
}
void GLPushOwnerState(lua_State* Thread) { lua_pushlightuserdata(Thread, GLGetOwnerState(Thread)); }
int GLCaptureWait(lua_State* Thread) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    if (!Owner || !Owner->Domain->RetainExternalWait(Thread))
        luaL_error(Thread, "[Runtime:Scheduler] Cannot wait from an inactive coroutine");
    lua_pushthread(Thread);
    int Reference = GLReference(Thread, -1);
    lua_pop(Thread, 1);
    GLReferences().at(Reference).WaitingThread = Thread;
    return Reference;
}
bool GLIsClient(lua_State* Thread) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    return Owner && Owner->Domain->GetKind() == GLDomainKind::Client;
}
int GLResume(lua_State* Thread, lua_State* From, int Arguments) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    return Owner ? Owner->Domain->Resume(Thread, From, Arguments) : LUA_ERRRUN;
}
int GLResumeError(lua_State* Thread, lua_State* From) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    return Owner ? Owner->Domain->Resume(Thread, From, 1, true) : LUA_ERRRUN;
}

GLExecutionDomain::GLExecutionDomain(GLDomainKind SelectedKind) : Kind(SelectedKind) {
    State = luaL_newstate();
    if (!State) throw std::runtime_error("[Runtime:Domain] Cannot allocate Luau VM");
    luaL_openlibs(State);
    lua_callbacks(State)->userthread = OnThread;
    BootstrapOwner = NewOwner(0, true);
    lua_newtable(State); lua_setglobal(State, "_G");
    lua_newtable(State); lua_setglobal(State, "shared");
    lua_pushboolean(State, Kind == GLDomainKind::Server); lua_setglobal(State, "__IS_SERVER");
    lua_pushboolean(State, Kind == GLDomainKind::Client); lua_setglobal(State, "__IS_CLIENT");
    InstallBuiltins();
}
GLExecutionDomain::~GLExecutionDomain() {
    Shutdown();
    if (State) {
        // The host must never destroy the domain from inside one of its resumes.
        // Shutdown itself is reentrant-safe and only invalidates/cancels admission.
        for (auto& Entry : Owners) {
            auto Found = GLAnchors().find(Entry.second->Anchor);
            if (Found != GLAnchors().end() && Found->second == Entry.second.get()) GLAnchors().erase(Found);
        }
        lua_close(State);
        State = nullptr;
    }
}
void GLExecutionDomain::OnThread(lua_State* Parent, lua_State* Thread) {
    if (Parent) {
        GLExecutionOwner* Owner = GLGetOwner(Parent);
        lua_setthreaddata(Thread, Owner);
        if (Owner) ++Owner->ThreadCount;
    } else {
        GLExecutionOwner* Owner = GLGetOwner(Thread);
        if (Owner && Owner->ThreadCount) --Owner->ThreadCount;
    }
}
GLExecutionOwner* GLExecutionDomain::NewOwner(uint64_t NativeId, bool Bootstrap) {
    if (IsClosing()) return nullptr;
    auto Owner = std::make_unique<GLExecutionOwner>();
    Owner->Domain = this;
    Owner->Token = NextToken++;
    Owner->NativeId = NativeId;
    if (Bootstrap) {
        Owner->Anchor = State;
        Owner->ThreadCount = 1;
    } else {
        Owner->Anchor = lua_newthread(State);
        // lua_newthread inherited the bootstrap owner; transfer that live thread.
        if (GLExecutionOwner* Inherited = GLGetOwner(Owner->Anchor)) --Inherited->ThreadCount;
        Owner->ThreadCount = 1;
        Owner->AnchorRef = lua_ref(State, -1);
        lua_pop(State, 1);
        lua_newtable(Owner->Anchor);
        lua_newtable(Owner->Anchor);
        lua_pushvalue(State, LUA_GLOBALSINDEX);
        lua_xmove(State, Owner->Anchor, 1);
        lua_setfield(Owner->Anchor, -2, "__index");
        lua_setmetatable(Owner->Anchor, -2);
        lua_replace(Owner->Anchor, LUA_GLOBALSINDEX);
    }
    GLExecutionOwner* Result = Owner.get();
    lua_setthreaddata(Owner->Anchor, Result);
    GLAnchors()[Owner->Anchor] = Result;
    Owners.emplace(Owner->Token, std::move(Owner));
    if (!Bootstrap && InitializeEnvironment) InitializeEnvironment(Result->Anchor, NativeId);
    return Result;
}
GLExecutionOwner* GLExecutionDomain::CreateOwner(uint64_t NativeId) {
    if (IsClosing() || !NativeId) return nullptr;
    if (GLExecutionOwner* Previous = FindOwner(NativeId)) CancelOwner(Previous);
    GLExecutionOwner* Owner = NewOwner(NativeId);
    ActiveOwners[NativeId] = Owner;
    return Owner;
}
GLExecutionOwner* GLExecutionDomain::FindOwner(uint64_t NativeId) const {
    auto Found = ActiveOwners.find(NativeId);
    return Found == ActiveOwners.end() ? nullptr : Found->second;
}
void GLExecutionDomain::CancelOwner(GLExecutionOwner* Owner) {
    if (!Owner || Owner->Domain != this || !Owner->Alive) return;
    Owner->Alive = false; // denial precedes callbacks, registry release, and cancellation
    if (InvalidateNative) InvalidateNative(Owner->Anchor);
    auto Found = ActiveOwners.find(Owner->NativeId);
    if (Found != ActiveOwners.end() && Found->second == Owner) ActiveOwners.erase(Found);
    std::vector<int> References;
    for (const auto& Entry : GLReferences())
        if (Entry.second.Owner == Owner) References.push_back(Entry.first);
    for (int Reference : References) GLUnreference(State, Reference);
    for (auto& Entry : Threads)
        if (Entry.second->Owner == Owner) Entry.second->Cancelled = true;
    CloseCallbacks.erase(std::remove_if(CloseCallbacks.begin(), CloseCallbacks.end(),
        [Owner](const GLCloseCallback& Callback) { return Callback.Owner == Owner; }), CloseCallbacks.end());
}
std::shared_ptr<GLExecutionDomain::GLThread> GLExecutionDomain::TrackThread(lua_State* Thread) {
    auto Found = Threads.find(Thread);
    if (Found != Threads.end()) return Found->second;
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || Owner->Domain != this) return {};
    auto Task = std::make_shared<GLThread>();
    Task->State = Thread;
    Task->Owner = Owner;
    lua_pushthread(Thread);
    Task->Root = lua_ref(Thread, -1);
    lua_pop(Thread, 1);
    Threads.emplace(Thread, Task);
    return Task;
}
bool GLExecutionDomain::Execute(GLExecutionOwner* Owner, const std::string& Source, const std::string& ChunkName) {
    if (!Owner || !Owner->Alive || IsClosing()) return false;
    lua_State* Thread = lua_newthread(Owner->Anchor);
    auto Task = TrackThread(Thread);
    std::string Bytecode = Luau::compile(Source);
    int Status = luau_load(Thread, ChunkName.c_str(), Bytecode.data(), Bytecode.size(), 0);
    if (Status == LUA_OK) Status = Resume(Thread, nullptr, 0);
    else FinishThread(Task, Status);
    lua_pop(Owner->Anchor, 1);
    return Status == LUA_OK || Status == LUA_YIELD;
}
bool GLExecutionDomain::Bootstrap(const std::string& Source, const std::string& ChunkName) {
    return Execute(BootstrapOwner, Source, ChunkName);
}
int GLExecutionDomain::Resume(lua_State* Thread, lua_State* From, int Arguments, bool RaiseError) {
    auto Task = TrackThread(Thread);
    if (!Task || Task->Cancelled || !Task->Owner->Alive || Task->Running ||
        (IsClosing() && Thread != ClosingThread) || lua_costatus(State, Thread) != LUA_COSUS)
        return LUA_OK; // cancelled/completed work is a no-op, never a native resume
    if (ResumeDepth >= 8) {
        Task->Arguments = Arguments;
        Task->Started = false;
        Task->Wait = GLWaitKind::Timer;
        Task->Remaining = 0;
        Task->WakeTick = TickNumber + 1;
        Task->RaiseOnWake = RaiseError;
        return LUA_YIELD; // bound C++ nesting without allocating another VM
    }
    Task->Running = true;
    Task->Started = true;
    ++ResumeDepth;
    int Status = RaiseError ? lua_resumeerror(Thread, From) : lua_resume(Thread, From, Arguments);
    --ResumeDepth;
    Task->Running = false;
    if (!Task->Owner->Alive || Task->Cancelled || (IsClosing() && Thread != ClosingThread)) {
        Task->Cancelled = true;
        return Status;
    }
    if (Status != LUA_YIELD) { FinishThread(Task, Status); return Status; }
    Task->Waited = 0;
    Task->WakeTick = TickNumber + 1;
    int Count = lua_gettop(Thread);
    if (Count == 2 && lua_isstring(Thread, -2) &&
        std::string(lua_tostring(Thread, -2)) == "__DOMAIN_MODULE__") {
        Task->Wait = GLWaitKind::Module;
        Task->Module = static_cast<uint64_t>(lua_tonumber(Thread, -1));
    } else if (Count == 1 && lua_isnumber(Thread, -1)) {
        Task->Wait = GLWaitKind::Timer;
        double Delay = lua_tonumber(Thread, -1);
        Task->Remaining = std::isfinite(Delay) ? std::max(0.0, Delay) : 0.0;
    } else if (Count == 0) {
        Task->Wait = GLWaitKind::Timer;
        Task->Remaining = 0;
    } else Task->Wait = GLWaitKind::External;
    lua_settop(Thread, 0);
    return Status;
}
void GLExecutionDomain::FinishThread(const std::shared_ptr<GLThread>& Task, int Status) {
    if (!Task) return;
    if (Task->NativeWait) GLClearWaitReferences(Task->State);
    auto ModuleFound = ModuleTickets.find(Task->Owner->ModuleToken);
    bool IsInitializer = ModuleFound != ModuleTickets.end() && ModuleFound->second->Initializer == Task->State;
    if (IsInitializer) {
        auto Module = ModuleFound->second;
        Module->WaitingOn = 0;
        if (Status != LUA_OK) FailModule(Module, lua_tostring(Task->State, -1) ? lua_tostring(Task->State, -1) : "Module initialization failed");
        else if (lua_gettop(Task->State) != 1 || lua_isnil(Task->State, 1))
            FailModule(Module, "Module code did not return exactly one non-nil value");
        else {
            Module->Result = lua_ref(Task->State, 1);
            Module->Status = GLModuleStatus::Ready;
        }
    }
    if (Status != LUA_OK && ReportError)
        ReportError(Task->State, lua_tostring(Task->State, -1) ? lua_tostring(Task->State, -1) : "Script execution failed");
    Task->Cancelled = true;
    // Reap at the next scheduler boundary, after native dispatchers have popped
    // their temporary anchor stacks and error reporters have inspected the thread.
}
void GLExecutionDomain::CancelThread(lua_State* Thread) {
    auto Found = Threads.find(Thread);
    if (Found == Threads.end() || Found->second->Cancelled) return;
    Found->second->Cancelled = true;
    if (Found->second->NativeWait) {
        if (InvalidateThread) InvalidateThread(Thread);
        GLClearWaitReferences(Thread);
    }
    auto Module = ModuleTickets.find(Found->second->Owner->ModuleToken);
    if (Module != ModuleTickets.end() && Module->second->Initializer == Thread && Module->second->Status == GLModuleStatus::Loading)
        FailModule(Module->second, "Module initialization was cancelled");
}
bool GLExecutionDomain::CanResume(lua_State* Thread) const {
    auto Found = Threads.find(Thread);
    return Found != Threads.end() && !IsClosing() && !Found->second->Cancelled &&
        !Found->second->Running && Found->second->Owner->Alive && lua_costatus(State, Thread) == LUA_COSUS;
}
bool GLExecutionDomain::RetainExternalWait(lua_State* Thread) {
    auto Task = TrackThread(Thread);
    if (!Task || Task->Cancelled || IsClosing()) return false;
    Task->Wait = GLWaitKind::External;
    Task->NativeWait = true;
    Task->Started = true;
    return true;
}
void GLExecutionDomain::ReleaseCancelled() {
    if (ResumeDepth) return;
    for (auto Iterator = Threads.begin(); Iterator != Threads.end();) {
        // Inspect live records without an otherwise unused shared_ptr copy.
        // Retain a strong local root before reset/unref can invoke Lua cleanup.
        if (!Iterator->second->Cancelled && Iterator->second->Owner->Alive) { ++Iterator; continue; }
        auto Task = Iterator->second;
        lua_resetthread(Task->State);
        lua_unref(State, Task->Root);
        Iterator = Threads.erase(Iterator);
    }
    for (auto& Entry : Owners) {
        GLExecutionOwner* Owner = Entry.second.get();
        if (!Owner->Alive && Owner->AnchorRef != LUA_NOREF) {
            GLAnchors().erase(Owner->Anchor);
            // An old coroutine may still be held by Lua. Keep its small native
            // token until userthread destruction, but release its anchor/env root.
            lua_unref(State, Owner->AnchorRef);
            Owner->AnchorRef = LUA_NOREF;
        }
    }
    for (auto Iterator = Owners.begin(); Iterator != Owners.end();) {
        if (!Iterator->second->Alive && Iterator->second->ThreadCount == 0)
            Iterator = Owners.erase(Iterator);
        else ++Iterator;
    }
    for (auto Iterator = ModuleTickets.begin(); Iterator != ModuleTickets.end();) {
        if (Iterator->second->Status != GLModuleStatus::Invalidated) { ++Iterator; continue; }
        bool HasWaiter = false;
        for (const auto& Task : Threads) if (!Task.second->Cancelled && Task.second->Wait == GLWaitKind::Module && Task.second->Module == Iterator->first) {
            HasWaiter = true; break;
        }
        if (!HasWaiter) Iterator = ModuleTickets.erase(Iterator);
        else ++Iterator;
    }
}
void GLExecutionDomain::Tick(double Delta) {
    if (!State || IsClosing() || ResumeDepth || !std::isfinite(Delta) || Delta < 0) return;
    ++TickNumber;
    Elapsed += Delta;
    std::vector<std::shared_ptr<GLThread>> Snapshot;
    Snapshot.reserve(Threads.size());
    for (const auto& Entry : Threads) Snapshot.push_back(Entry.second);
    for (const auto& Task : Snapshot) {
        if (Task->Cancelled || !Task->Owner->Alive || Task->Running || Task->WakeTick > TickNumber) continue;
        if (Task->Started && lua_costatus(State, Task->State) != LUA_COSUS) {
            CancelThread(Task->State);
            continue;
        }
        if (Task->Wait == GLWaitKind::External) continue;
        int Arguments = 0;
        if (Task->Wait == GLWaitKind::Module) {
            auto Found = ModuleTickets.find(Task->Module);
            if (Found != ModuleTickets.end() && Found->second->Status == GLModuleStatus::Loading) continue;
        } else {
            Task->Remaining -= Delta;
            Task->Waited += Delta;
            if (Task->Remaining > 0) continue;
            if (Task->Started) {
                lua_pushnumber(Task->State, Task->Waited);
                lua_pushnumber(Task->State, GetTime ? GetTime() : Elapsed);
                Arguments = 2;
            } else Arguments = Task->Arguments;
        }
        bool RaiseError = Task->RaiseOnWake;
        Task->RaiseOnWake = false;
        Resume(Task->State, nullptr, Arguments, RaiseError);
    }
    ReleaseCancelled();
}
void GLExecutionDomain::FailModule(const std::shared_ptr<GLModule>& Module, const std::string& Error) {
    Module->Status = GLModuleStatus::Failed;
    Module->Error = Error;
    Module->WaitingOn = 0;
}
int GLExecutionDomain::PushModuleResult(lua_State* Thread, const std::shared_ptr<GLModule>& Module) {
    if (Module->Status == GLModuleStatus::Failed || Module->Status == GLModuleStatus::Invalidated)
        luaL_error(Thread, "[Runtime:Require] %s", Module->Error.c_str());
    lua_pushboolean(Thread, Module->Status == GLModuleStatus::Ready);
    if (Module->Status == GLModuleStatus::Ready) lua_rawgeti(Thread, LUA_REGISTRYINDEX, Module->Result);
    else lua_pushnumber(Thread, static_cast<double>(Module->Token));
    return 2;
}
int GLExecutionDomain::BeginRequire(lua_State* Thread) {
    GLExecutionOwner* Caller = GLGetOwner(Thread);
    if (!Caller || !Caller->Alive) luaL_error(Thread, "[Runtime:Require] Inactive execution owner");
    GLModuleSource Source;
    if (!ResolveModule || !ResolveModule(Thread, 1, Source) || !Source.Identity)
        luaL_error(Thread, "[Runtime:Require] Expected a live ModuleScript");
    auto Found = Modules.find(Source.Identity);
    bool MatchingSource = Found != Modules.end() && (Source.ResourceIdentity
        ? Found->second->ResourceIdentity == Source.ResourceIdentity && Found->second->Revision == Source.Revision
        : Found->second->Source == Source.Source);
    if (IsClosing()) {
        if (MatchingSource && Found->second->Status == GLModuleStatus::Ready)
            return PushModuleResult(Thread, Found->second);
        luaL_error(Thread, "[Runtime:Require] Cannot initialize modules during shutdown");
    }
    if (Found != Modules.end() && !MatchingSource) {
        InvalidateModule(Source.Identity);
        Found = Modules.end();
    }
    if (Found != Modules.end() && Found->second->Status == GLModuleStatus::Ready)
        return PushModuleResult(Thread, Found->second);
    std::shared_ptr<GLModule> Module;
    if (Found != Modules.end()) Module = Found->second;
    else {
        if (LoadModule && !LoadModule(Source))
            luaL_error(Thread, "[Runtime:Require] Expected a live ModuleScript");
        Module = std::make_shared<GLModule>();
        Module->Token = NextToken++;
        Module->Identity = Source.Identity;
        Module->Source = Source.Source;
        Module->ResourceIdentity = Source.ResourceIdentity;
        Module->Revision = Source.Revision;
        Module->Owner = NewOwner(Source.Identity);
        Module->Owner->ModuleToken = Module->Token;
        Modules[Source.Identity] = Module;
        ModuleTickets[Module->Token] = Module;
    }
    auto Parent = ModuleTickets.find(Caller->ModuleToken);
    if (Parent != ModuleTickets.end() && Parent->second->Status == GLModuleStatus::Loading && Parent->second->Initializer == Thread) {
        uint64_t Cursor = Module->Token;
        while (Cursor) {
            if (Cursor == Caller->ModuleToken) luaL_error(Thread, "[Runtime:Require] Cyclic module dependency");
            auto Dependency = ModuleTickets.find(Cursor);
            if (Dependency == ModuleTickets.end()) break;
            Cursor = Dependency->second->WaitingOn;
        }
        Parent->second->WaitingOn = Module->Token;
    }
    if (!Module->Initializer) {
        lua_State* Initializer = lua_newthread(Module->Owner->Anchor);
        Module->Initializer = Initializer;
        auto Task = TrackThread(Initializer);
        std::string Bytecode = Luau::compile(Source.Source);
        int Status = luau_load(Initializer, Source.ChunkName.c_str(), Bytecode.data(), Bytecode.size(), 0);
        if (Status == LUA_OK) Resume(Initializer, nullptr, 0);
        else FinishThread(Task, Status);
        lua_pop(Module->Owner->Anchor, 1);
    }
    if (Module->Status == GLModuleStatus::Loading) {
        auto CallerTask = TrackThread(Thread);
        CallerTask->Started = true;
        CallerTask->Wait = GLWaitKind::Module;
        CallerTask->Module = Module->Token;
        CallerTask->WakeTick = TickNumber + 1;
    }
    return PushModuleResult(Thread, Module);
}
int GLExecutionDomain::PollRequire(lua_State* Thread) {
    uint64_t Ticket = static_cast<uint64_t>(luaL_checknumber(Thread, 1));
    auto Found = ModuleTickets.find(Ticket);
    if (Found == ModuleTickets.end()) luaL_error(Thread, "[Runtime:Require] Invalidated module ticket");
    return PushModuleResult(Thread, Found->second);
}
void GLExecutionDomain::InvalidateModule(uint64_t Identity) {
    auto Found = Modules.find(Identity);
    if (Found == Modules.end()) return;
    auto Module = Found->second;
    Module->Status = GLModuleStatus::Invalidated;
    Module->Error = "Module was destroyed or reloaded during initialization";
    Module->WaitingOn = 0;
    if (Module->Result != LUA_NOREF) { lua_unref(State, Module->Result); Module->Result = LUA_NOREF; }
    CancelOwner(Module->Owner);
    Module->Owner = nullptr;
    Module->Initializer = nullptr;
    Module->Source.clear();
    Modules.erase(Found);
}
int GLExecutionDomain::Schedule(lua_State* Thread, int FunctionIndex, double Delay, bool Immediate, GLExecutionOwner* ExplicitOwner) {
    GLExecutionOwner* Owner = ExplicitOwner ? ExplicitOwner : GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || Owner->Domain->IsClosing())
        luaL_error(Thread, "[Runtime:Scheduler] Inactive execution owner");
    if (!std::isfinite(Delay)) luaL_error(Thread, "[Runtime:Scheduler] Delay must be finite");
    if (!lua_isfunction(Thread, FunctionIndex)) {
        if (FunctionIndex == 1 && lua_isthread(Thread, 1)) {
            lua_State* Target = lua_tothread(Thread, 1);
            if (GLGetOwner(Target) != Owner) luaL_error(Thread, "[Runtime:Scheduler] Thread belongs to another owner");
            int Arguments = lua_gettop(Thread) - 1;
            for (int Index = 2; Index <= Arguments + 1; ++Index) lua_pushvalue(Thread, Index);
            lua_xmove(Thread, Target, Arguments);
            Owner->Domain->Resume(Target, Thread, Arguments);
            lua_pushvalue(Thread, 1);
            return 1;
        }
        luaL_error(Thread, "[Runtime:Scheduler] Expected function");
    }
    int Top = lua_gettop(Thread);
    lua_State* Parent = ExplicitOwner ? Owner->Anchor : Thread;
    lua_State* Target = lua_newthread(Parent);
    if (Parent != Thread) lua_xmove(Parent, Thread, 1);
    int ThreadIndex = lua_gettop(Thread);
    lua_pushvalue(Thread, FunctionIndex); lua_xmove(Thread, Target, 1);
    for (int Index = FunctionIndex + 1; Index <= Top; ++Index) lua_pushvalue(Thread, Index);
    int Arguments = Top - FunctionIndex;
    lua_xmove(Thread, Target, Arguments);
    auto Task = Owner->Domain->TrackThread(Target);
    Task->Arguments = Arguments;
    Task->Remaining = std::max(0.0, Delay);
    Task->WakeTick = Owner->Domain->TickNumber + 1;
    if (Immediate) Owner->Domain->Resume(Target, Thread, Arguments);
    lua_settop(Thread, ThreadIndex);
    return 1;
}
int GLExecutionDomain::TaskSpawn(lua_State* Thread) { return Schedule(Thread, 1, 0, true); }
int GLExecutionDomain::TaskDefer(lua_State* Thread) { return Schedule(Thread, 1, 0, false); }
int GLExecutionDomain::TaskDelay(lua_State* Thread) { return Schedule(Thread, 2, luaL_checknumber(Thread, 1), false); }
int GLExecutionDomain::TaskCancel(lua_State* Thread) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    luaL_checktype(Thread, 1, LUA_TTHREAD);
    lua_State* Target = lua_tothread(Thread, 1);
    if (!Owner || GLGetOwner(Target) != Owner) luaL_error(Thread, "[Runtime:Scheduler] Thread belongs to another owner");
    if (Target == Thread) luaL_error(Thread, "[Runtime:Scheduler] Cannot cancel the running coroutine");
    Owner->Domain->TrackThread(Target);
    Owner->Domain->CancelThread(Target);
    return 0;
}
int GLExecutionDomain::BindCallback(lua_State* Thread) {
    luaL_checktype(Thread, 1, LUA_TFUNCTION);
    int Reference = GLReference(Thread, 1);
    lua_pushinteger(Thread, Reference);
    lua_pushcclosure(Thread, [](lua_State* Caller) -> int {
        int Reference = lua_tointeger(Caller, lua_upvalueindex(1));
        lua_State* Anchor = GLReferenceState(Reference);
        if (!Anchor) return 0;
        int Arguments = lua_gettop(Caller);
        lua_State* Callback = lua_newthread(Anchor);
        lua_rawgeti(Callback, LUA_REGISTRYINDEX, Reference);
        for (int Index = 1; Index <= Arguments; ++Index) {
            lua_pushvalue(Caller, Index); lua_xmove(Caller, Callback, 1);
        }
        GLResume(Callback, Caller, Arguments);
        lua_pop(Anchor, 1);
        return 0;
    }, "OwnedCallback", 1);
    lua_pushinteger(Thread, Reference);
    lua_pushcclosure(Thread, [](lua_State* Caller) -> int {
        GLUnreference(nullptr, lua_tointeger(Caller, lua_upvalueindex(1))); return 0;
    }, "ReleaseCallback", 1);
    lua_pushinteger(Thread, Reference);
    lua_pushcclosure(Thread, [](lua_State* Caller) -> int {
        lua_pushboolean(Caller, GLReferenceState(lua_tointeger(Caller, lua_upvalueindex(1))) != nullptr); return 1;
    }, "CallbackAlive", 1);
    return 3;
}
void GLExecutionDomain::ExposeBootstrapSpawner() {
    lua_pushcfunction(State, [](lua_State* Thread) -> int {
        GLExecutionOwner* Owner = GLGetOwner(Thread);
        return Schedule(Thread, 1, 0, true, Owner->Domain->BootstrapOwner);
    }, "DomainServiceSpawn");
    lua_setglobal(State, "_GLDomainSpawn");
}
void GLExecutionDomain::InstallBuiltins() {
    lua_pushcfunction(State, BindCallback, "BindCallback"); lua_setglobal(State, "_GLBindCallback");
    lua_newtable(State);
    lua_pushcfunction(State, TaskSpawn, "spawn"); lua_setfield(State, -2, "spawn");
    lua_pushcfunction(State, TaskDefer, "defer"); lua_setfield(State, -2, "defer");
    lua_pushcfunction(State, TaskDelay, "delay"); lua_setfield(State, -2, "delay");
    lua_pushcfunction(State, TaskCancel, "cancel"); lua_setfield(State, -2, "cancel");
    lua_pushcfunction(State, [](lua_State* Thread) -> int {
        double Delay = luaL_optnumber(Thread, 1, 0);
        if (!std::isfinite(Delay)) luaL_error(Thread, "[Runtime:Scheduler] Wait must be finite");
        GLExecutionOwner* Owner = GLGetOwner(Thread);
        if (!Owner || !Owner->Alive || Owner->Domain->IsClosing())
            luaL_error(Thread, "[Runtime:Scheduler] Cannot wait from an inactive owner");
        auto Task = Owner->Domain->TrackThread(Thread);
        Task->Started = true;
        Task->Wait = GLWaitKind::Timer;
        Task->Remaining = std::max(0.0, Delay);
        Task->Waited = 0;
        Task->WakeTick = Owner->Domain->TickNumber + 1;
        lua_pushnumber(Thread, std::max(0.0, Delay));
        return lua_yield(Thread, 1);
    }, "wait"); lua_setfield(State, -2, "wait");
    lua_setglobal(State, "task");
    lua_getglobal(State, "task"); lua_getfield(State, -1, "wait"); lua_setglobal(State, "wait"); lua_pop(State, 1);
    lua_pushcfunction(State, [](lua_State* Thread) -> int {
        return GLGetOwner(Thread)->Domain->BeginRequire(Thread);
    }, "__DomainRequire"); lua_setglobal(State, "__DomainRequire");
    lua_pushcfunction(State, [](lua_State* Thread) -> int {
        return GLGetOwner(Thread)->Domain->PollRequire(Thread);
    }, "__DomainPoll"); lua_setglobal(State, "__DomainPoll");
    std::string Bytecode = Luau::compile(GLRequireWrapper);
    if (luau_load(State, "=DomainRequire", Bytecode.data(), Bytecode.size(), 0) != LUA_OK || lua_pcall(State, 0, 0, 0) != LUA_OK)
        throw std::runtime_error("[Runtime:Require] Cannot initialize require wrapper");
    lua_pushcfunction(State, [](lua_State* Thread) -> int {
        luaL_checktype(Thread, 1, LUA_TTHREAD);
        lua_State* Target = lua_tothread(Thread, 1);
        GLExecutionOwner* Owner = GLGetOwner(Target);
        bool Alive = Owner && Owner->Alive && !Owner->Domain->IsClosing();
        if (Alive) {
            auto Found = Owner->Domain->Threads.find(Target);
            Alive = Found == Owner->Domain->Threads.end() || !Found->second->Cancelled;
        }
        lua_pushboolean(Thread, Alive);
        return 1;
    }, "CoroutineOwnerAlive"); lua_setglobal(State, "__GLCoroutineAlive");
    Bytecode = Luau::compile(R"LUAU(
local Alive, Resume, Create, Pack, Unpack = __GLCoroutineAlive, coroutine.resume, coroutine.create, table.pack, table.unpack
__GLCoroutineAlive = nil
function coroutine.resume(Thread, ...)
    if not Alive(Thread) then return false, "[Runtime:Scheduler] Inactive coroutine owner" end
    return Resume(Thread, ...)
end
local GuardedResume = coroutine.resume
function coroutine.wrap(Callback)
    local Thread = Create(Callback)
    return function(...)
        local Results = Pack(GuardedResume(Thread, ...))
        if not Results[1] then error(Results[2], 2) end
        return Unpack(Results, 2, Results.n)
    end
end
)LUAU");
    if (luau_load(State, "=DomainCoroutines", Bytecode.data(), Bytecode.size(), 0) != LUA_OK || lua_pcall(State, 0, 0, 0) != LUA_OK)
        throw std::runtime_error("[Runtime:Scheduler] Cannot initialize coroutine ownership guards");
}
void GLExecutionDomain::AddCloseCallback(lua_State* Thread, int Reference) {
    GLExecutionOwner* Owner = GLGetOwner(Thread);
    if (Owner && Owner->Alive && !IsClosing()) CloseCallbacks.push_back({Owner, Reference});
}
void GLExecutionDomain::Shutdown() {
    if (Closing) return;
    Closing = true;
    StopAdmission();
    auto Snapshot = std::move(CloseCallbacks);
    CloseCallbacks.clear();
    for (const auto& Callback : Snapshot) {
        if (!Callback.Owner->Alive || !GLReferenceAlive(Callback.Owner->Anchor, Callback.Reference)) continue;
        lua_State* Thread = lua_newthread(Callback.Owner->Anchor);
        ClosingThread = Thread;
        lua_rawgeti(Thread, LUA_REGISTRYINDEX, Callback.Reference);
        if (lua_isfunction(Thread, -1)) Resume(Thread, nullptr, 0);
        lua_pop(Callback.Owner->Anchor, 1);
    }
    ClosingThread = nullptr;
    std::vector<GLExecutionOwner*> SnapshotOwners;
    SnapshotOwners.reserve(Owners.size());
    for (const auto& Entry : Owners) SnapshotOwners.push_back(Entry.second.get());
    for (GLExecutionOwner* Owner : SnapshotOwners) CancelOwner(Owner);
}
size_t GLExecutionDomain::GetOwnerCount() const {
    size_t Count = 0;
    for (const auto& Entry : Owners) if (Entry.second->Alive && Entry.second.get() != BootstrapOwner) ++Count;
    return Count;
}
size_t GLExecutionDomain::GetReferenceCount() const {
    size_t Count = 0;
    for (const auto& Entry : GLReferences()) if (Entry.second.Owner->Domain == this) ++Count;
    return Count;
}
