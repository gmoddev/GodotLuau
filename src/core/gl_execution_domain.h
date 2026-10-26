#ifndef GL_EXECUTION_DOMAIN_H
#define GL_EXECUTION_DOMAIN_H

#include "lua.h"
#include "lualib.h"
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

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
};

// The core has no Godot dependency so the production scheduler/cache can be
// exercised directly against the pinned Luau VM. Godot supplies identity/env hooks.
class GLExecutionDomain {
public:
    using ModuleResolver = std::function<bool(lua_State*, int, GLModuleSource&)>;
    using EnvironmentHook = std::function<void(lua_State*, uint64_t)>;
    using InvalidationHook = std::function<void(lua_State*)>;
    using ErrorHandler = std::function<void(lua_State*, const std::string&)>;

    explicit GLExecutionDomain(GLDomainKind Kind);
    ~GLExecutionDomain();
    GLExecutionDomain(const GLExecutionDomain&) = delete;
    GLExecutionDomain& operator=(const GLExecutionDomain&) = delete;

    lua_State* GetState() const { return State; }
    GLDomainKind GetKind() const { return Kind; }
    bool IsClosing() const { return Closing || AdmissionClosed; }
    void StopAdmission() { AdmissionClosed = true; }
    void SetModuleResolver(ModuleResolver Resolver) { ResolveModule = std::move(Resolver); }
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
    void ExposeBootstrapSpawner(); // temporary trusted-bootstrap hook; hide before starting user scripts
    int Resume(lua_State* Thread, lua_State* From, int Arguments, bool RaiseError = false);
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
    };
    enum class GLModuleStatus { Loading, Ready, Failed, Invalidated };
    struct GLModule {
        uint64_t Token = 0;
        uint64_t Identity = 0;
        std::string Source;
        GLModuleStatus Status = GLModuleStatus::Loading;
        GLExecutionOwner* Owner = nullptr;
        lua_State* Initializer = nullptr;
        uint64_t WaitingOn = 0;
        int Result = LUA_NOREF;
        std::string Error;
    };
    struct GLCloseCallback { GLExecutionOwner* Owner; int Reference; };

    GLDomainKind Kind;
    lua_State* State = nullptr;
    GLExecutionOwner* BootstrapOwner = nullptr;
    uint64_t NextToken = 1;
    uint64_t TickNumber = 0;
    double Elapsed = 0;
    unsigned ResumeDepth = 0;
    bool Closing = false;
    bool AdmissionClosed = false;
    lua_State* ClosingThread = nullptr;
    std::unordered_map<uint64_t, std::unique_ptr<GLExecutionOwner>> Owners;
    std::unordered_map<uint64_t, GLExecutionOwner*> ActiveOwners;
    std::unordered_map<lua_State*, std::shared_ptr<GLThread>> Threads;
    std::unordered_map<uint64_t, std::shared_ptr<GLModule>> Modules;
    std::unordered_map<uint64_t, std::shared_ptr<GLModule>> ModuleTickets;
    std::vector<GLCloseCallback> CloseCallbacks;
    ModuleResolver ResolveModule;
    EnvironmentHook InitializeEnvironment;
    InvalidationHook InvalidateNative;
    InvalidationHook InvalidateThread;
    ErrorHandler ReportError;
    std::function<double()> GetTime;

    GLExecutionOwner* NewOwner(uint64_t NativeId, bool Bootstrap = false);
    std::shared_ptr<GLThread> TrackThread(lua_State* Thread);
    void FinishThread(const std::shared_ptr<GLThread>& Task, int Status);
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
void GLPushOwnerState(lua_State* Thread);
bool GLIsClient(lua_State* Thread);

#endif
