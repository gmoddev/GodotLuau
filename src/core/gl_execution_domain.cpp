#include "gl_execution_domain.h"
#include "Luau/Compiler.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>
#if LUA_USE_LONGJMP
#error GL execution limits require the pinned Luau C++ exception unwinding configuration
#endif

namespace {
constexpr const char* GLDeadlineMessage = "[Runtime:Execution] Resume deadline exceeded";
constexpr const char* GLSafepointMessage = "[Runtime:Execution] VM safepoint budget exceeded";
constexpr const char* GLAncestorAllocationMessage = "[Runtime:Execution] Active domain allocation rejection blocks execution";
thread_local GLExecutionDomain* GLActiveBudget = nullptr;
const char* GLFailureText(lua_State* Thread, const char* Fallback) {
    // lua_tostring converts numbers by allocating. Error reporting is outside
    // VM protection, so only read an existing string here.
    return lua_type(Thread, -1) == LUA_TSTRING ? lua_tostring(Thread, -1) : Fallback;
}
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
    if (!Owner->Domain->CanRetainReference()) {
        ++Owner->Domain->AdmissionRejections;
        luaL_error(Thread, "[Runtime:Scheduler] External reference admission limit exceeded");
    }
    if (GLNextReference == std::numeric_limits<int>::max())
        luaL_error(Thread, "[Runtime:Ownership] Registry reference space exhausted");
    // Never recycle public callback IDs. Old native callbacks cannot alias a new
    // callback if Lua later reuses an anchor address or an internal registry slot.
    int Reference = GLNextReference++;
    lua_pushvalue(Thread, Index);
    lua_rawseti(Thread, LUA_REGISTRYINDEX, Reference);
    GLReferences().emplace(Reference, GLReferenceEntry{Owner});
    ++Owner->Domain->LiveReferences;
    Owner->Domain->ReferencePeak = (std::max)(Owner->Domain->ReferencePeak, Owner->Domain->LiveReferences);
    return Reference;
}
void GLUnreference(lua_State*, int Reference) {
    auto Found = GLReferences().find(Reference);
    if (Found == GLReferences().end()) return;
    lua_State* State = Found->second.Owner->Domain->GetState();
    if (State) { lua_pushnil(State); lua_rawseti(State, LUA_REGISTRYINDEX, Reference); }
    --Found->second.Owner->Domain->LiveReferences;
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
int GLDispatch(int Reference, const std::function<int(lua_State*)>& Marshal) {
    lua_State* Anchor = GLReferenceState(Reference);
    return Anchor ? GLGetOwner(Anchor)->Domain->Dispatch(Reference, Marshal) : LUA_OK;
}

namespace {
struct GLCallbackPreparation {
    int Reference;
    const std::function<int(lua_State*)>& Marshal;
};
struct GLThreadCreation {
    lua_State* Thread = nullptr;
    int Root = LUA_NOREF;
};
struct GLTemporaryRoot {
    lua_State* State;
    int Root;
    ~GLTemporaryRoot() { lua_unref(State, Root); }
};
int GLCreateThread(lua_State* Anchor) {
    auto& Creation = *static_cast<GLThreadCreation*>(lua_touserdata(Anchor, 1));
    Creation.Thread = lua_newthread(Anchor);
    Creation.Root = lua_ref(Anchor, -1);
    return 0;
}
}

bool GLExecutionDomain::IsClientExecution() {
    return GLActiveBudget && GLActiveBudget->GetKind() == GLDomainKind::Client;
}

GLExecutionDomain::BudgetScope::BudgetScope(GLExecutionDomain& Selected) : Domain(Selected) {
    if (Domain.BudgetDepth++ == 0) {
        Pushed = true;
        Domain.BudgetParent = GLActiveBudget;
        GLActiveBudget = &Domain;
        Domain.Safepoints = 0;
        Domain.BudgetError = nullptr;
        Domain.ExecutionDeadline = std::chrono::steady_clock::now() +
            std::chrono::duration_cast<std::chrono::steady_clock::duration>(std::chrono::duration<double, std::milli>(Domain.Limits.ResumeMilliseconds));
    }
}
GLExecutionDomain::BudgetScope::~BudgetScope() {
    --Domain.BudgetDepth;
    if (Pushed) {
        GLActiveBudget = Domain.BudgetParent;
        Domain.BudgetParent = nullptr;
    }
}
bool GLExecutionDomain::CheckExecutionBudget() {
    auto Now = std::chrono::steady_clock::now();
    for (auto Scope = GLActiveBudget; Scope; Scope = Scope->BudgetParent) {
        if (!Scope->BudgetError && (Scope->Memory.Rejections || Scope->MemoryFailed))
            Scope->BudgetError = GLAncestorAllocationMessage;
        if (!Scope->BudgetError && Scope->Limits.ResumeMilliseconds > 0 && Now >= Scope->ExecutionDeadline)
            Scope->BudgetError = GLDeadlineMessage;
        if (Scope->BudgetError && !BudgetError) BudgetError = Scope->BudgetError;
    }
    return BudgetError != nullptr;
}
void GLExecutionDomain::Interrupt(lua_State* Thread, int GC) {
    if (GC >= 0) return; // throwing during a collector callback is not supported
    auto Domain = static_cast<GLExecutionDomain*>(lua_callbacks(Thread)->userdata);
    if (!Domain) return;
    // Allocation rejection is sticky even when Lua catches OOM or elapsed
    // enforcement is explicitly disabled. Retire only at the protected return.
    if (Domain->Memory.Rejections || Domain->MemoryFailed)
        luaL_error(Thread, "[Runtime:Memory] VM allocation rejected");
    if (!Domain->BudgetDepth) return;
    for (auto Scope = GLActiveBudget; Scope; Scope = Scope->BudgetParent) {
        ++Scope->Safepoints;
        if (!Scope->BudgetError && (Scope->Memory.Rejections || Scope->MemoryFailed))
            Scope->BudgetError = GLAncestorAllocationMessage;
        if (!Scope->BudgetError && Scope->Limits.MaxSafepoints && Scope->Safepoints > Scope->Limits.MaxSafepoints)
            Scope->BudgetError = GLSafepointMessage;
    }
    // Check every active ancestor for latched failures on every safepoint;
    // clock sampling remains periodic. Cross-domain calls cannot reset a caller.
    if ((Domain->Safepoints & 63) == 0) Domain->CheckExecutionBudget();
    else for (auto Scope = GLActiveBudget; Scope; Scope = Scope->BudgetParent)
        if (Scope->BudgetError && !Domain->BudgetError) Domain->BudgetError = Scope->BudgetError;
    // Keep the failure latched through protected/reentrant user calls. Only a
    // new outer execution attempt resets it; catching an inner error grants no time.
    if (Domain->BudgetError) luaL_error(Thread, "%s", Domain->BudgetError);
}
GLExecutionDomain::GLExecutionDomain(GLDomainKind SelectedKind, GLDomainLimits SelectedLimits) : Kind(SelectedKind), Limits(SelectedLimits) {
    if (!std::isfinite(Limits.ResumeMilliseconds) || Limits.ResumeMilliseconds < 0 || Limits.ResumeMilliseconds > 60000)
        throw std::invalid_argument("[Runtime:Execution] Resume budget must be finite and between 0 and 60000 milliseconds");
    Memory.Limit = Limits.MemoryBytes;
    State = lua_newstate(GLMemoryAccount::Allocate, &Memory);
    if (!State) {
        LiveCoroutines = CoroutinePeak = 0;
        CheckMemoryFailure(nullptr, LUA_ERRMEM);
        return;
    }
    lua_callbacks(State)->userdata = this;
    lua_callbacks(State)->interrupt = Interrupt;
    lua_callbacks(State)->userthread = OnThread;
    int Status = lua_cpcall(State, [](lua_State* Thread) -> int {
        auto& Domain = *static_cast<GLExecutionDomain*>(lua_touserdata(Thread, 1));
        luaL_openlibs(Thread);
        Domain.BootstrapOwner = Domain.NewOwner(0, true);
        lua_newtable(Thread); lua_setglobal(Thread, "_G");
        lua_newtable(Thread); lua_setglobal(Thread, "shared");
        lua_pushboolean(Thread, Domain.Kind == GLDomainKind::Server); lua_setglobal(Thread, "__IS_SERVER");
        lua_pushboolean(Thread, Domain.Kind == GLDomainKind::Client); lua_setglobal(Thread, "__IS_CLIENT");
        Domain.InstallBuiltins();
        Domain.RootGlobals = lua_ref(Thread, LUA_GLOBALSINDEX);
        lua_pushliteral(Thread, "[Runtime:Execution] Resume deadline exceeded");
        Domain.DeadlineError = lua_ref(Thread, -1); lua_pop(Thread, 1);
        lua_pushliteral(Thread, "[Runtime:Execution] VM safepoint budget exceeded");
        Domain.SafepointError = lua_ref(Thread, -1); lua_pop(Thread, 1);
        lua_pushstring(Thread, GLAncestorAllocationMessage);
        Domain.AncestorAllocationError = lua_ref(Thread, -1); lua_pop(Thread, 1);
        lua_pushcfunction(Thread, [](lua_State* Thread) -> int {
            auto& Preparation = *static_cast<GLCallbackPreparation*>(lua_touserdata(Thread, 1));
            lua_settop(Thread, 0);
            int Function = Preparation.Reference == LUA_NOREF ? 0 : 1;
            if (Function) {
                lua_rawgeti(Thread, LUA_REGISTRYINDEX, Preparation.Reference);
                luaL_checktype(Thread, -1, LUA_TFUNCTION);
            }
            int Arguments = Preparation.Marshal(Thread);
            if (Arguments < 0 || lua_gettop(Thread) != Arguments + Function)
                luaL_error(Thread, "[Runtime:Callback] Invalid argument preparation");
            return Arguments + Function;
        }, "PrepareOwnedCallback");
        Domain.PrepareCallback = lua_ref(Thread, -1);
        return 0;
    }, this);
    if (Status != LUA_OK) {
        if (!CheckMemoryFailure(State, Status))
            FailureMessage = "[Runtime:Bootstrap] Cannot initialize domain VM; domain unavailable";
        StopAdmission();
        lua_pop(State, 1);
    }
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
bool GLExecutionDomain::CheckMemoryFailure(lua_State* Thread, int Status) {
    if (MemoryFailed) return true;
    if (Status != LUA_ERRMEM && Memory.Rejections == 0) return false;
    MemoryFailed = true;
    Closing = true;
    StopAdmission();
    FailureMessage = Memory.LastFailure == GLMemoryAccount::Failure::Quota
        ? "[Runtime:Memory] Domain VM allocation quota exceeded; domain retired"
        : Memory.LastFailure == GLMemoryAccount::Failure::HostAllocation
        ? "[Runtime:Memory] Native allocator failed allocating VM memory; domain retired"
        : Memory.InvalidAccounting || Memory.LastFailure == GLMemoryAccount::Failure::Overflow
        ? "[Runtime:Memory] VM allocator accounting failure; domain retired"
        : "[Runtime:Memory] Domain VM allocation failed; domain retired";
    CloseCallbacks.clear(); // exhausted VMs do not execute shutdown gameplay
    for (auto& Entry : Owners) CancelOwner(Entry.second.get());
    if (ReportError) ReportError(Thread, FailureMessage);
    return true;
}
lua_State* GLExecutionDomain::CreateThread(GLExecutionOwner* Owner, int& Root) {
    GLThreadCreation Creation;
    int Status = lua_cpcall(Owner->Anchor, GLCreateThread, &Creation);
    if (Status != LUA_OK) {
        bool Failed = CheckMemoryFailure(Owner->Anchor, Status);
        if (!Failed && ReportError) ReportError(Owner->Anchor, GLFailureText(Owner->Anchor, "[Runtime:Scheduler] Coroutine creation failed"));
        lua_pop(Owner->Anchor, 1);
        return nullptr;
    }
    Root = Creation.Root;
    return Creation.Thread;
}
bool GLExecutionDomain::InitializeHost(const std::function<void(lua_State*)>& Initialize) {
    if (IsClosing() || Sandboxed) return false;
    size_t Rejections = AdmissionRejections;
    int Status = lua_cpcall(State, [](lua_State* Thread) -> int {
        auto& Initialize = *static_cast<const std::function<void(lua_State*)>*>(lua_touserdata(Thread, 1));
        Initialize(Thread);
        return 0;
    }, const_cast<void*>(static_cast<const void*>(&Initialize)));
    if (Status == LUA_OK && Rejections == AdmissionRejections && !IsClosing() && !CheckMemoryFailure(State, Status)) return true;
    if (!CheckMemoryFailure(State, Status)) {
        FailureMessage = "[Runtime:Bootstrap] Trusted initialization failed; domain unavailable";
        if (ReportError) ReportError(State, FailureMessage);
    }
    if (Status != LUA_OK) lua_pop(State, 1);
    Shutdown();
    return false;
}
int GLExecutionDomain::CreateGuard(GLExecutionOwner* Owner) {
    if (!Owner || !Owner->Alive || IsClosing()) return LUA_NOREF;
    int Reference = LUA_NOREF;
    int Status = lua_cpcall(Owner->Anchor, [](lua_State* Thread) -> int {
        auto Reference = static_cast<int*>(lua_touserdata(Thread, 1));
        lua_pushboolean(Thread, true);
        *Reference = GLReference(Thread, -1);
        return 0;
    }, &Reference);
    if (Status != LUA_OK) {
        if (!CheckMemoryFailure(Owner->Anchor, Status) && ReportError)
            ReportError(Owner->Anchor, GLFailureText(Owner->Anchor, "[Runtime:Scheduler] Cannot retain execution guard"));
        lua_pop(Owner->Anchor, 1);
        CancelOwner(Owner);
        return LUA_NOREF;
    }
    return Reference;
}
void GLExecutionDomain::OnThread(lua_State* Parent, lua_State* Thread) {
    if (Parent) {
        GLExecutionOwner* Owner = GLGetOwner(Parent);
        if (Owner && Owner->Domain->Limits.Coroutines && Owner->Domain->LiveCoroutines >= Owner->Domain->Limits.Coroutines) {
            ++Owner->Domain->AdmissionRejections;
            luaL_error(Parent, "[Runtime:Scheduler] Live coroutine admission limit exceeded");
        }
        lua_setthreaddata(Thread, Owner);
        if (Owner) {
            ++Owner->ThreadCount; ++Owner->Domain->LiveCoroutines;
            Owner->Domain->CoroutinePeak = (std::max)(Owner->Domain->CoroutinePeak, Owner->Domain->LiveCoroutines);
        }
    } else {
        GLExecutionOwner* Owner = GLGetOwner(Thread);
        if (Owner && Owner->ThreadCount) { --Owner->ThreadCount; --Owner->Domain->LiveCoroutines; }
    }
}
GLExecutionOwner* GLExecutionDomain::NewOwner(uint64_t NativeId, bool Bootstrap) {
    if (IsClosing()) return nullptr;
    if (!Bootstrap && Limits.Owners && Owners.size() - 1 >= Limits.Owners) {
        ++AdmissionRejections;
        if (ReportError) ReportError(State, "[Runtime:Scheduler] Owner admission limit exceeded");
        return nullptr;
    }
    auto Owner = std::make_unique<GLExecutionOwner>();
    Owner->Domain = this;
    Owner->Token = NextToken++;
    Owner->NativeId = NativeId;
    if (Bootstrap) {
        Owner->Anchor = State;
        Owner->ThreadCount = 1;
    } else {
        GLThreadCreation Creation;
        int Status = lua_cpcall(State, GLCreateThread, &Creation);
        if (Status != LUA_OK) {
            if (!CheckMemoryFailure(State, Status) && ReportError)
                ReportError(State, GLFailureText(State, "[Runtime:Scheduler] Owner coroutine admission failed"));
            lua_pop(State, 1);
            return nullptr;
        }
        Owner->Anchor = Creation.Thread;
        // lua_newthread inherited the bootstrap owner; transfer that live thread.
        if (GLExecutionOwner* Inherited = GLGetOwner(Owner->Anchor)) --Inherited->ThreadCount;
        Owner->ThreadCount = 1;
        Owner->AnchorRef = Creation.Root;
    }
    GLExecutionOwner* Result = Owner.get();
    lua_setthreaddata(Owner->Anchor, Result);
    GLAnchors()[Owner->Anchor] = Result;
    Owners.emplace(Owner->Token, std::move(Owner));
    if (!Bootstrap) { ++LiveOwners; OwnerPeak = (std::max)(OwnerPeak, LiveOwners); }
    if (!Bootstrap) {
        int Status = lua_cpcall(Result->Anchor, [](lua_State* Thread) -> int {
            auto Owner = static_cast<GLExecutionOwner*>(lua_touserdata(Thread, 1));
            luaL_sandboxthread(Thread);
            // GodotLuau overrides typeof and exposes mutable service facades.
            // Safeenv would allow builtin fastcalls to bypass those contracts.
            lua_setsafeenv(Thread, LUA_GLOBALSINDEX, false);
            if (Owner->Domain->InitializeEnvironment) Owner->Domain->InitializeEnvironment(Thread, Owner->NativeId);
            return 0;
        }, Result);
        if (Status != LUA_OK) {
            if (!CheckMemoryFailure(Result->Anchor, Status) && ReportError)
                ReportError(Result->Anchor, GLFailureText(Result->Anchor, "[Runtime:Environment] Cannot initialize owner environment"));
            lua_pop(Result->Anchor, 1);
            CancelOwner(Result);
            return nullptr;
        }
    }
    return Result;
}
GLExecutionOwner* GLExecutionDomain::CreateOwner(uint64_t NativeId) {
    if (IsClosing() || !NativeId) return nullptr;
    if (!SealEnvironment()) return nullptr;
    if (Limits.Owners && Owners.size() - 1 >= Limits.Owners) {
        ++AdmissionRejections;
        if (ReportError) ReportError(State, "[Runtime:Scheduler] Owner admission limit exceeded");
        return nullptr; // do not cancel a valid previous owner on rejected admission
    }
    GLExecutionOwner* Previous = FindOwner(NativeId);
    GLExecutionOwner* Owner = NewOwner(NativeId);
    if (Owner) {
        CancelOwner(Previous);
        ActiveOwners[NativeId] = Owner;
    }
    return Owner;
}
GLExecutionOwner* GLExecutionDomain::FindOwner(uint64_t NativeId) const {
    auto Found = ActiveOwners.find(NativeId);
    return Found == ActiveOwners.end() ? nullptr : Found->second;
}
void GLExecutionDomain::CancelOwner(GLExecutionOwner* Owner) {
    if (!Owner || Owner->Domain != this || !Owner->Alive) return;
    Owner->Alive = false; // denial precedes callbacks, registry release, and cancellation
    if (Owner != BootstrapOwner) --LiveOwners;
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
    if (Limits.Tasks && Threads.size() >= Limits.Tasks) {
        ++AdmissionRejections;
        if (ReportError) ReportError(Thread, "[Runtime:Scheduler] Task admission limit exceeded");
        return {};
    }
    auto Task = std::make_shared<GLThread>();
    Task->State = Thread;
    Task->Owner = Owner;
    struct RootContext { lua_State* Thread; int Root = LUA_NOREF; } Context{Thread};
    int Status = lua_cpcall(State, [](lua_State* Root) -> int {
        auto& Context = *static_cast<RootContext*>(lua_touserdata(Root, 1));
        if (!lua_checkstack(Context.Thread, 1)) luaL_error(Root, "[Runtime:Scheduler] Cannot root coroutine");
        lua_pushthread(Context.Thread);
        lua_xmove(Context.Thread, Root, 1);
        Context.Root = lua_ref(Root, -1);
        return 0;
    }, &Context);
    if (Status != LUA_OK) {
        CheckMemoryFailure(State, Status);
        lua_pop(State, 1);
        return {};
    }
    Task->Root = Context.Root;
    Threads.emplace(Thread, Task);
    TaskPeak = (std::max)(TaskPeak, Threads.size());
    return Task;
}
bool GLExecutionDomain::Execute(GLExecutionOwner* Owner, const std::string& Source, const std::string& ChunkName) {
    if (!Owner || !Owner->Alive || IsClosing()) return false;
    int Root = LUA_NOREF;
    lua_State* Thread = CreateThread(Owner, Root);
    if (!Thread) return false;
    auto Task = TrackThread(Thread);
    if (!Task) { lua_unref(State, Root); return false; }
    // An owner environment can be reused by several chunks. The pinned sandbox
    // API requires invalidating import optimizations when loading it again.
    lua_setsafeenv(Thread, LUA_GLOBALSINDEX, false);
    std::string Bytecode = Luau::compile(Source);
    int Status = luau_load(Thread, ChunkName.c_str(), Bytecode.data(), Bytecode.size(), 0);
    if (Status == LUA_OK) Status = Resume(Thread, nullptr, 0);
    else if (!CheckMemoryFailure(Thread, Status)) FinishThread(Task, Status);
    lua_unref(State, Root);
    return Status == LUA_OK || Status == LUA_YIELD;
}
bool GLExecutionDomain::Bootstrap(const std::string& Source, const std::string& ChunkName) {
    return Execute(BootstrapOwner, Source, ChunkName);
}
bool GLExecutionDomain::SealEnvironment() {
    if (Sandboxed) return true;
    int Status = lua_cpcall(State, [](lua_State* Thread) -> int {
        // luaL_sandbox freezes every table in the root environment. Custom
        // service facades and _G/shared are intentionally mutable contracts.
        // Preserve those while keeping intrinsic library aliases read-only.
        std::vector<const void*> Libraries;
        for (const char* Name : {"coroutine", "task", "table", "string", "math", "utf8", "bit32", "buffer", "vector", "os", "debug"}) {
            lua_getglobal(Thread, Name);
            if (lua_istable(Thread, -1)) Libraries.push_back(lua_topointer(Thread, -1));
            lua_pop(Thread, 1);
        }
        std::vector<int> MutableTables;
        lua_pushnil(Thread);
        while (lua_next(Thread, LUA_GLOBALSINDEX)) {
            if (lua_istable(Thread, -1) && !lua_getreadonly(Thread, -1) &&
                std::find(Libraries.begin(), Libraries.end(), lua_topointer(Thread, -1)) == Libraries.end())
                MutableTables.push_back(lua_ref(Thread, -1));
            lua_pop(Thread, 1);
        }
        luaL_sandbox(Thread);
        for (int Reference : MutableTables) {
            lua_rawgeti(Thread, LUA_REGISTRYINDEX, Reference);
            lua_setreadonly(Thread, -1, false);
            lua_pop(Thread, 1);
            lua_unref(Thread, Reference);
        }
        // Mutable facades invalidate the safeenv promise even though the root
        // itself is immutable. Per-owner globals remain private proxy tables.
        lua_setsafeenv(Thread, LUA_GLOBALSINDEX, false);
        return 0;
    }, nullptr);
    if (Status != LUA_OK) {
        CheckMemoryFailure(State, Status);
        if (ReportError) ReportError(State, "[Runtime:Sandbox] Cannot initialize sandbox");
        lua_pop(State, 1);
        StopAdmission();
        return false;
    }
    Sandboxed = true;
    return true;
}
int GLExecutionDomain::Resume(lua_State* Thread, lua_State* From, int Arguments, bool RaiseError) {
    auto Task = TrackThread(Thread);
    if (!Task && GLGetOwner(Thread) && GLGetOwner(Thread)->Alive && !IsClosing()) {
        CancelOwner(GLGetOwner(Thread));
        return LUA_ERRRUN;
    }
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
    BudgetScope Budget(*this);
    if (CheckExecutionBudget()) {
        Task->Running = false;
        FinishThread(Task, LUA_ERRRUN, BudgetError);
        CancelOwner(Task->Owner);
        return LUA_ERRRUN;
    }
    ++ResumeDepth;
    int Status = RaiseError ? lua_resumeerror(Thread, From) : lua_resume(Thread, From, Arguments);
    --ResumeDepth;
    Task->Running = false;
    if (CheckMemoryFailure(Thread, Status)) return LUA_ERRMEM;
    if (CheckExecutionBudget()) {
        FinishThread(Task, LUA_ERRRUN, BudgetError);
        CancelOwner(Task->Owner);
        return LUA_ERRRUN;
    }
    if (!Task->Owner->Alive || Task->Cancelled || (IsClosing() && Thread != ClosingThread)) {
        Task->Cancelled = true;
        return Status;
    }
    if (Status != LUA_YIELD) { FinishThread(Task, Status); return MemoryFailed ? LUA_ERRMEM : Status; }
    Task->Waited = 0;
    Task->WakeTick = TickNumber + 1;
    int Count = lua_gettop(Thread);
    if (Count == 2 && lua_type(Thread, -2) == LUA_TSTRING &&
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
int GLExecutionDomain::ProtectedCall(lua_State* Thread, int Arguments, int Results, int Handler) {
    BudgetScope Budget(*this);
    int Prefix = lua_gettop(Thread) - Arguments - 1;
    int Status = CheckExecutionBudget() ? LUA_ERRRUN : lua_pcall(Thread, Arguments, Results, Handler);
    if (CheckMemoryFailure(Thread, Status)) return LUA_ERRMEM;
    if (CheckExecutionBudget()) {
        lua_settop(Thread, Prefix);
        lua_rawgeti(Thread, LUA_REGISTRYINDEX, BudgetError == GLSafepointMessage ? SafepointError :
            BudgetError == GLAncestorAllocationMessage ? AncestorAllocationError : DeadlineError);
        if (auto Owner = GLGetOwner(Thread)) CancelOwner(Owner);
        return LUA_ERRRUN;
    }
    return Status;
}
int GLExecutionDomain::Dispatch(int Reference, const std::function<int(lua_State*)>& Marshal) {
    lua_State* Anchor = GLReferenceState(Reference);
    if (!Anchor || GLGetOwner(Anchor)->Domain != this || IsClosing()) return LUA_OK;
    BudgetScope Budget(*this); // argument conversion may invoke gameplay constructors
    int Root = LUA_NOREF;
    lua_State* Thread = CreateThread(GLGetOwner(Anchor), Root);
    if (!Thread) return MemoryFailed ? LUA_ERRMEM : LUA_ERRRUN;
    GLTemporaryRoot Retain{State, Root};
    int Status = Prepare(Thread, Reference, Marshal);
    if (Status == LUA_OK) Status = Resume(Thread, nullptr, lua_gettop(Thread) - 1);
    return Status;
}
int GLExecutionDomain::Prepare(lua_State* Thread, int Reference, const std::function<int(lua_State*)>& Marshal) {
    GLCallbackPreparation Preparation{Reference, Marshal};
    int Status;
    if (!lua_checkstack(Thread, 2)) Status = LUA_ERRMEM;
    else {
        lua_rawgeti(Thread, LUA_REGISTRYINDEX, PrepareCallback);
        lua_pushlightuserdata(Thread, &Preparation);
        Status = ProtectedCall(Thread, 1, LUA_MULTRET, 0);
        if (Status != LUA_OK && !CheckMemoryFailure(Thread, Status) && ReportError) ReportError(Thread, GLFailureText(Thread, "[Runtime:Callback] Argument preparation failed"));
    }
    CheckMemoryFailure(Thread, Status);
    return Status;
}
int GLExecutionDomain::Invoke(int Reference, const std::function<int(lua_State*)>& Marshal,
    const std::function<void(lua_State*)>& CopyResults) {
    lua_State* Anchor = GLReferenceState(Reference);
    if (!Anchor || GLGetOwner(Anchor)->Domain != this || IsClosing()) return LUA_ERRRUN;
    BudgetScope Budget(*this);
    int Root = LUA_NOREF;
    lua_State* Thread = CreateThread(GLGetOwner(Anchor), Root);
    if (!Thread) return MemoryFailed ? LUA_ERRMEM : LUA_ERRRUN;
    GLTemporaryRoot Retain{State, Root};
    int Status = Prepare(Thread, Reference, Marshal);
    if (Status == LUA_OK) Status = ProtectedCall(Thread, lua_gettop(Thread) - 1, LUA_MULTRET, 0);
    if (Status == LUA_OK) {
        // Destination errors must unwind to the destination's protection. A
        // separately protected source stack reservation can also have rejected
        // allocation, so publish source retirement before either exit path.
        try { CopyResults(Thread); }
        catch (...) { CheckMemoryFailure(Thread, LUA_OK); throw; }
        if (CheckMemoryFailure(Thread, LUA_OK)) return LUA_ERRMEM;
        if (CheckExecutionBudget()) {
            if (ReportError) ReportError(Thread, BudgetError);
            CancelOwner(GLGetOwner(Thread));
            return LUA_ERRRUN;
        }
    }
    else if (!CheckMemoryFailure(Thread, Status) && ReportError)
        ReportError(Thread, GLFailureText(Thread, "[Runtime:Callback] Synchronous callback failed"));
    return Status;
}
int GLExecutionDomain::ResumePrepared(lua_State* Thread, const std::function<int(lua_State*)>& Marshal, bool RaiseError) {
    if (!CanResume(Thread)) return LUA_OK;
    BudgetScope Budget(*this);
    int Root = LUA_NOREF;
    lua_State* Scratch = CreateThread(GLGetOwner(Thread), Root);
    if (!Scratch) return MemoryFailed ? LUA_ERRMEM : LUA_ERRRUN;
    GLTemporaryRoot Retain{State, Root};
    int Status = Prepare(Scratch, LUA_NOREF, Marshal);
    if (Status != LUA_OK) { CancelThread(Thread); return Status; }
    int Arguments = lua_gettop(Scratch);
    if (!lua_checkstack(Thread, Arguments)) {
        if (CheckMemoryFailure(Thread, LUA_ERRRUN)) return LUA_ERRMEM;
        CancelThread(Thread);
        if (ReportError) ReportError(Thread, "[Runtime:Scheduler] Resume argument stack limit exceeded");
        return LUA_ERRRUN;
    }
    lua_xmove(Scratch, Thread, Arguments);
    return Resume(Thread, nullptr, Arguments, RaiseError);
}
bool GLExecutionDomain::RunNative(const std::function<void(lua_State*)>& Operation) {
    if (!CanRunNative()) return false;
    BudgetScope Budget(*this);
    if (CheckExecutionBudget()) {
        CancelOwner(BootstrapOwner);
        if (ReportError) ReportError(State, BudgetError);
        return false;
    }
    int Root = LUA_NOREF;
    lua_State* Thread = CreateThread(BootstrapOwner, Root);
    if (!Thread) return false;
    GLTemporaryRoot Retain{State, Root};
    int Status = lua_cpcall(Thread, [](lua_State* Thread) -> int {
        auto& Operation = *static_cast<const std::function<void(lua_State*)>*>(lua_touserdata(Thread, 1));
        lua_settop(Thread, 0);
        Operation(Thread);
        return 0;
    }, const_cast<void*>(static_cast<const void*>(&Operation)));
    if (CheckMemoryFailure(Thread, Status)) return false;
    if (CheckExecutionBudget()) {
        CancelOwner(BootstrapOwner);
        if (ReportError) ReportError(Thread, BudgetError);
        return false;
    }
    if (Status != LUA_OK && ReportError)
        ReportError(Thread, GLFailureText(Thread, "[Runtime:Native] Native operation failed"));
    return Status == LUA_OK;
}
void GLExecutionDomain::PushGlobalValue(lua_State* Thread, const char* Name) {
    if (lua_rawgetfield(Thread, LUA_GLOBALSINDEX, Name) != LUA_TNIL) return;
    lua_pop(Thread, 1);
    lua_rawgeti(Thread, LUA_REGISTRYINDEX, RootGlobals);
    lua_rawgetfield(Thread, -1, Name);
    lua_remove(Thread, -2);
}
void GLExecutionDomain::FinishThread(const std::shared_ptr<GLThread>& Task, int Status, const char* Failure) {
    if (!Task) return;
    if (Task->NativeWait) GLClearWaitReferences(Task->State);
    auto ModuleFound = ModuleTickets.find(Task->Owner->ModuleToken);
    bool IsInitializer = ModuleFound != ModuleTickets.end() && ModuleFound->second->Initializer == Task->State;
    if (IsInitializer) {
        auto Module = ModuleFound->second;
        Module->WaitingOn = 0;
        if (Status != LUA_OK) FailModule(Module, Failure ? Failure : GLFailureText(Task->State, "Module initialization failed (non-string error)"));
        else if (lua_gettop(Task->State) != 1 || lua_isnil(Task->State, 1))
            FailModule(Module, "Module code did not return exactly one non-nil value");
        else {
            struct ResultContext { lua_State* Source; int Reference = LUA_NOREF; } Context{Task->State};
            int ResultStatus = lua_cpcall(State, [](lua_State* Thread) -> int {
                auto& Context = *static_cast<ResultContext*>(lua_touserdata(Thread, 1));
                if (!lua_checkstack(Context.Source, 1)) luaL_error(Thread, "[Runtime:Memory] Cannot retain module result");
                lua_pushvalue(Context.Source, 1);
                lua_xmove(Context.Source, Thread, 1);
                Context.Reference = lua_ref(Thread, -1);
                return 0;
            }, &Context);
            if (ResultStatus != LUA_OK) {
                CheckMemoryFailure(State, ResultStatus);
                lua_pop(State, 1);
                return;
            }
            Module->Result = Context.Reference;
            Module->Status = GLModuleStatus::Ready;
        }
    }
    if (Status != LUA_OK && ReportError)
        ReportError(Task->State, Failure ? Failure : GLFailureText(Task->State, "Script execution failed (non-string error)"));
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
        if (!Module->Owner) luaL_error(Thread, "[Runtime:Require] Domain cannot admit module owner");
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
        int Root = LUA_NOREF;
        lua_State* Initializer = CreateThread(Module->Owner, Root);
        if (!Initializer) {
            FailModule(Module, "[Runtime:Require] Cannot initialize module coroutine");
            return PushModuleResult(Thread, Module);
        }
        Module->Initializer = Initializer;
        auto Task = TrackThread(Initializer);
        if (!Task) {
            lua_unref(State, Root);
            FailModule(Module, "[Runtime:Scheduler] Cannot admit module initializer");
            return PushModuleResult(Thread, Module);
        }
        std::string Bytecode = Luau::compile(Source.Source);
        int Status = luau_load(Initializer, Source.ChunkName.c_str(), Bytecode.data(), Bytecode.size(), 0);
        if (Status == LUA_OK) Resume(Initializer, nullptr, 0);
        else if (!CheckMemoryFailure(Initializer, Status)) FinishThread(Task, Status);
        lua_unref(State, Root);
    }
    if (Module->Status == GLModuleStatus::Loading) {
        auto CallerTask = TrackThread(Thread);
        if (!CallerTask) luaL_error(Thread, "[Runtime:Scheduler] Cannot admit module waiter");
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
            if (!lua_checkstack(Thread, Arguments) || !lua_checkstack(Target, Arguments))
                luaL_error(Thread, "[Runtime:Scheduler] Argument stack exhausted");
            for (int Index = 2; Index <= Arguments + 1; ++Index) lua_pushvalue(Thread, Index);
            lua_xmove(Thread, Target, Arguments);
            Owner->Domain->Resume(Target, Thread, Arguments);
            lua_pushvalue(Thread, 1);
            return 1;
        }
        luaL_error(Thread, "[Runtime:Scheduler] Expected function");
    }
    int Top = lua_gettop(Thread);
    if (Owner->Domain->Limits.Tasks && Owner->Domain->Threads.size() >= Owner->Domain->Limits.Tasks) {
        ++Owner->Domain->AdmissionRejections;
        luaL_error(Thread, "[Runtime:Scheduler] Task admission limit exceeded");
    }
    if (!lua_checkstack(Thread, Top + 1)) luaL_error(Thread, "[Runtime:Scheduler] Argument stack exhausted");
    int Root = LUA_NOREF;
    lua_State* Target = ExplicitOwner ? Owner->Domain->CreateThread(Owner, Root) : lua_newthread(Thread);
    if (!Target) luaL_error(Thread, "[Runtime:Scheduler] Cannot create coroutine");
    if (ExplicitOwner) {
        lua_pushthread(Target);
        lua_xmove(Target, Thread, 1);
        lua_unref(Thread, Root);
    }
    int ThreadIndex = lua_gettop(Thread);
    lua_pushvalue(Thread, FunctionIndex); lua_xmove(Thread, Target, 1);
    for (int Index = FunctionIndex + 1; Index <= Top; ++Index) lua_pushvalue(Thread, Index);
    int Arguments = Top - FunctionIndex;
    if (!lua_checkstack(Target, Arguments + 1)) luaL_error(Thread, "[Runtime:Scheduler] Argument stack exhausted");
    lua_xmove(Thread, Target, Arguments);
    auto Task = Owner->Domain->TrackThread(Target);
    if (!Task) luaL_error(Thread, "[Runtime:Scheduler] Cannot admit task");
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
        GLDispatch(Reference, [&](lua_State* Callback) -> int {
            if (!lua_checkstack(Callback, Arguments)) luaL_error(Callback, "[Runtime:Callback] Argument stack exhausted");
            for (int Index = 1; Index <= Arguments; ++Index) {
                lua_pushvalue(Caller, Index); lua_xmove(Caller, Callback, 1);
            }
            return Arguments;
        });
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
        if (!Task) luaL_error(Thread, "[Runtime:Scheduler] Cannot admit timed wait");
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
    BudgetScope Budget(*this); // one aggregate deadline for the entire hook snapshot
    Closing = true;
    StopAdmission();
    auto Snapshot = std::move(CloseCallbacks);
    CloseCallbacks.clear();
    for (const auto& Callback : Snapshot) {
        if (BudgetError) break;
        if (!Callback.Owner->Alive || !GLReferenceAlive(Callback.Owner->Anchor, Callback.Reference)) continue;
        int Root = LUA_NOREF;
        lua_State* Thread = CreateThread(Callback.Owner, Root);
        if (!Thread) break;
        ClosingThread = Thread;
        lua_rawgeti(Thread, LUA_REGISTRYINDEX, Callback.Reference);
        if (lua_isfunction(Thread, -1)) Resume(Thread, nullptr, 0);
        lua_unref(State, Root);
    }
    ClosingThread = nullptr;
    std::vector<GLExecutionOwner*> SnapshotOwners;
    SnapshotOwners.reserve(Owners.size());
    for (const auto& Entry : Owners) SnapshotOwners.push_back(Entry.second.get());
    for (GLExecutionOwner* Owner : SnapshotOwners) CancelOwner(Owner);
}
size_t GLExecutionDomain::GetOwnerCount() const {
    return LiveOwners;
}
size_t GLExecutionDomain::GetReferenceCount() const {
    return LiveReferences;
}
