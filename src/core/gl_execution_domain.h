#ifndef GL_EXECUTION_DOMAIN_H
#define GL_EXECUTION_DOMAIN_H

#include "lua.h"
#include "lualib.h"
#include "gl_memory_account.h"
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
#include <chrono>

struct GLDomainLimits {
    double ResumeMilliseconds = 10000;
    uint64_t MaxSafepoints = 0; // optional deterministic VM safepoint budget, not an instruction count
    size_t MemoryBytes = 512 * 1024 * 1024; // VM allocator bytes; zero explicitly disables quota
    size_t Tasks = 65536;
    size_t Coroutines = 131072;
    size_t References = 65536;
    size_t Owners = 16384;
};

enum class GLDomainKind { Server, Client };
class GLExecutionDomain;

struct GLExecutionOwner {
    GLExecutionDomain* Domain = nullptr;
    uint64_t Token = 0;
    uint64_t NativeId = 0;
    uint64_t ModuleToken = 0;
    lua_State* Anchor = nullptr;
    int AnchorRef = LUA_NOREF;
    size_t ThreadCount = 0;
    bool Alive = true;
};

struct GLModuleSource {
    uint64_t Identity = 0;
    std::string Source;
    std::string ChunkName;
    // Nonzero resource identity enables metadata validation; zero preserves
    // content-based resolvers. A loader supplies source/path only on misses.
    uint64_t ResourceIdentity = 0;
    uint64_t Revision = 0;
};

// The core has no Godot dependency so the production scheduler/cache can be
// exercised directly against the pinned Luau VM. Godot supplies identity/env hooks.
class GLExecutionDomain {
public:
    using ModuleResolver = std::function<bool(lua_State*, int, GLModuleSource&)>;
    using ModuleLoader = std::function<bool(GLModuleSource&)>;
    using EnvironmentHook = std::function<void(lua_State*, uint64_t)>;
    using InvalidationHook = std::function<void(lua_State*)>;
    using ErrorHandler = std::function<void(lua_State*, const std::string&)>;

    explicit GLExecutionDomain(GLDomainKind Kind, GLDomainLimits Limits = {});
    ~GLExecutionDomain();
    GLExecutionDomain(const GLExecutionDomain&) = delete;
    GLExecutionDomain& operator=(const GLExecutionDomain&) = delete;

    lua_State* GetState() const { return State; }
    GLDomainKind GetKind() const { return Kind; }
    bool IsClosing() const { return Closing || AdmissionClosed; }
    bool IsShutdownCallback(lua_State* Thread) const { return Closing && Thread && Thread==ClosingThread; }
    void StopAdmission() { AdmissionClosed = true; }
    void SetModuleResolver(ModuleResolver Resolver) { ResolveModule = std::move(Resolver); }
    void SetModuleLoader(ModuleLoader Loader) { LoadModule = std::move(Loader); }
    void SetEnvironmentHook(EnvironmentHook Hook) { InitializeEnvironment = std::move(Hook); }
    void SetInvalidationHook(InvalidationHook Hook) { InvalidateNative = std::move(Hook); }
    void SetThreadInvalidationHook(InvalidationHook Hook) { InvalidateThread = std::move(Hook); }
    void SetErrorHandler(ErrorHandler Handler) { ReportError = std::move(Handler); }
    void SetTimeProvider(std::function<double()> Provider) { GetTime = std::move(Provider); }
    GLExecutionOwner* CreateOwner(uint64_t NativeId);
    GLExecutionOwner* FindOwner(uint64_t NativeId) const;
    void CancelOwner(GLExecutionOwner* Owner);
    bool Execute(GLExecutionOwner* Owner, const std::string& Source, const std::string& ChunkName);
    bool Bootstrap(const std::string& Source, const std::string& ChunkName);
    bool SealEnvironment(); // after trusted registration/bootstrap, before gameplay admission
    bool IsSandboxed() const { return Sandboxed; }
    bool HasMemoryFailure() const { return MemoryFailed; }
    bool CanRunNative() const { return BootstrapOwner && BootstrapOwner->Alive && !IsClosing(); }
    const char* GetFailure() const { return FailureMessage; }
    void ExposeBootstrapSpawner(); // temporary trusted-bootstrap hook; hide before starting user scripts
    int Resume(lua_State* Thread, lua_State* From, int Arguments, bool RaiseError = false);
    int ProtectedCall(lua_State* Thread, int Arguments, int Results, int Handler);
    // Marshal runs on the callback coroutine inside its own protected VM call.
    // It returns only the number of arguments pushed, and must not yield.
    int Dispatch(int Reference, const std::function<int(lua_State*)>& Marshal);
    bool InitializeHost(const std::function<void(lua_State*)>& Initialize);
    int CreateGuard(GLExecutionOwner* Owner);
    int Invoke(int Reference, const std::function<int(lua_State*)>& Marshal,
        const std::function<void(lua_State*)>& CopyResults);
    int ResumePrepared(lua_State* Thread, const std::function<int(lua_State*)>& Marshal, bool RaiseError = false);
    bool RunNative(const std::function<void(lua_State*)>& Operation);
    void PushGlobalValue(lua_State* Thread, const char* Name); // raw local/root lookup for data conversion; no metamethods
    void CancelThread(lua_State* Thread);
    bool CanResume(lua_State* Thread) const;
    bool RetainExternalWait(lua_State* Thread);
    void Tick(double Delta);
    void InvalidateModule(uint64_t Identity);
    void AddCloseCallback(lua_State* Thread, int Reference);
    void Shutdown();
    size_t GetTaskCount() const { return Threads.size(); }
    size_t GetOwnerCount() const;
    size_t GetReferenceCount() const;
    const GLMemoryAccount& GetMemoryAccount() const { return Memory; }
    const GLDomainLimits& GetLimits() const { return Limits; }
    size_t GetCoroutineCount() const { return LiveCoroutines; }
    size_t GetTaskPeak() const { return TaskPeak; }
    size_t GetCoroutinePeak() const { return CoroutinePeak; }
    size_t GetReferencePeak() const { return ReferencePeak; }
    size_t GetOwnerPeak() const { return OwnerPeak; }
    size_t GetAdmissionRejections() const { return AdmissionRejections; }
    bool CanRetainReference() const { return !Limits.References || GetReferenceCount() < Limits.References; }

private:
    enum class GLWaitKind { Timer, External, Module };
    struct GLThread {
        lua_State* State = nullptr;
        GLExecutionOwner* Owner = nullptr;
        int Root = LUA_NOREF;
        GLWaitKind Wait = GLWaitKind::Timer;
        double Remaining = 0;
        double Waited = 0;
        uint64_t WakeTick = 0;
        uint64_t Module = 0;
        int Arguments = 0;
        bool Started = false;
        bool Running = false;
        bool Cancelled = false;
        bool RaiseOnWake = false;
        bool NativeWait = false;
    };
    enum class GLModuleStatus { Loading, Ready, Failed, Invalidated };
    struct GLModule {
        uint64_t Token = 0;
        uint64_t Identity = 0;
        std::string Source;
        uint64_t ResourceIdentity = 0;
        uint64_t Revision = 0;
        GLModuleStatus Status = GLModuleStatus::Loading;
        GLExecutionOwner* Owner = nullptr;
        lua_State* Initializer = nullptr;
        uint64_t WaitingOn = 0;
        int Result = LUA_NOREF;
        std::string Error;
    };
    struct GLCloseCallback { GLExecutionOwner* Owner; int Reference; };

    GLDomainKind Kind;
    GLDomainLimits Limits;
    std::chrono::steady_clock::time_point ExecutionDeadline;
    unsigned BudgetDepth = 0;
    uint64_t Safepoints = 0;
    const char* BudgetError = nullptr;
    GLExecutionDomain* BudgetParent = nullptr; // active synchronous scope only; never retained by tasks
    struct BudgetScope {
        GLExecutionDomain& Domain;
        bool Pushed = false;
        explicit BudgetScope(GLExecutionDomain& Selected);
        ~BudgetScope();
    };
    static void Interrupt(lua_State* Thread, int GC);
    bool CheckExecutionBudget();
    GLMemoryAccount Memory;
    int PrepareCallback = LUA_NOREF;
    int DeadlineError = LUA_NOREF;
    int SafepointError = LUA_NOREF;
    int AncestorAllocationError = LUA_NOREF;
    int RootGlobals = LUA_NOREF;
    lua_State* State = nullptr;
    GLExecutionOwner* BootstrapOwner = nullptr;
    uint64_t NextToken = 1;
    uint64_t TickNumber = 0;
    double Elapsed = 0;
    unsigned ResumeDepth = 0;
    bool Closing = false;
    bool AdmissionClosed = false;
    bool Sandboxed = false;
    bool MemoryFailed = false;
    size_t LiveCoroutines = 1;
    size_t LiveReferences = 0;
    size_t LiveOwners = 0;
    size_t AdmissionRejections = 0;
    size_t TaskPeak = 0, CoroutinePeak = 1, ReferencePeak = 0, OwnerPeak = 0;
    friend int GLReference(lua_State*, int);
    friend void GLUnreference(lua_State*, int);
    const char* FailureMessage = nullptr;
    lua_State* ClosingThread = nullptr;
    std::unordered_map<uint64_t, std::unique_ptr<GLExecutionOwner>> Owners;
    std::unordered_map<uint64_t, GLExecutionOwner*> ActiveOwners;
    std::unordered_map<lua_State*, std::shared_ptr<GLThread>> Threads;
    std::unordered_map<uint64_t, std::shared_ptr<GLModule>> Modules;
    std::unordered_map<uint64_t, std::shared_ptr<GLModule>> ModuleTickets;
    std::vector<GLCloseCallback> CloseCallbacks;
    ModuleResolver ResolveModule;
    ModuleLoader LoadModule;
    EnvironmentHook InitializeEnvironment;
    InvalidationHook InvalidateNative;
    InvalidationHook InvalidateThread;
    ErrorHandler ReportError;
    std::function<double()> GetTime;

    GLExecutionOwner* NewOwner(uint64_t NativeId, bool Bootstrap = false);
    lua_State* CreateThread(GLExecutionOwner* Owner, int& Root);
    bool CheckMemoryFailure(lua_State* Thread, int Status);
    int Prepare(lua_State* Thread, int Reference, const std::function<int(lua_State*)>& Marshal);
    std::shared_ptr<GLThread> TrackThread(lua_State* Thread);
    void FinishThread(const std::shared_ptr<GLThread>& Task, int Status, const char* Failure = nullptr);
    void ReleaseCancelled();
    int BeginRequire(lua_State* Thread);
    int PollRequire(lua_State* Thread);
    int PushModuleResult(lua_State* Thread, const std::shared_ptr<GLModule>& Module);
    void FailModule(const std::shared_ptr<GLModule>& Module, const std::string& Error);
    static void OnThread(lua_State* Parent, lua_State* Thread);
    static int TaskSpawn(lua_State* Thread);
    static int TaskDefer(lua_State* Thread);
    static int TaskDelay(lua_State* Thread);
    static int TaskCancel(lua_State* Thread);
    static int BindCallback(lua_State* Thread);
    static int Schedule(lua_State* Thread, int FunctionIndex, double Delay, bool Immediate, GLExecutionOwner* ExplicitOwner = nullptr);
    void InstallBuiltins();
};

GLExecutionOwner* GLGetOwner(lua_State* Thread);
lua_State* GLGetOwnerState(lua_State* Thread);
lua_State* GLReferenceState(int Reference);
bool GLStateAlive(lua_State* Anchor);
bool GLReferenceAlive(lua_State* Anchor, int Reference);
int GLReference(lua_State* Thread, int Index);
int GLCaptureWait(lua_State* Thread);
void GLUnreference(lua_State* Thread, int Reference);
int GLResume(lua_State* Thread, lua_State* From, int Arguments);
int GLResumeError(lua_State* Thread, lua_State* From);
int GLDispatch(int Reference, const std::function<int(lua_State*)>& Marshal);
void GLPushOwnerState(lua_State* Thread);
bool GLIsClient(lua_State* Thread);

#endif
