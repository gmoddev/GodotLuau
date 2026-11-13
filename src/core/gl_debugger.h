#pragma once
#include "lua.h"
#include <cstdint>
#include <functional>
#include <map>
#include <string>
#include <vector>

class GLExecutionDomain;
struct GLExecutionOwner;

enum class GLDebugState { Detached, Attached, Running, PauseRequested, Suspended, Stepping, Resuming, Terminating, Disconnected, Faulted };
enum class GLDebugAction { Continue, Into, Over, Out, Detach, Stop };
struct GLDebugFrame { std::string Source, Function; int Line = 0; };
struct GLDebugBreakpoint {
    std::string Source;
    int Line = 0;
    bool Enabled = true;
    uint32_t BreakOnHit = 0, Hits = 0;
    std::vector<int> AdmittedLines;
};

// Host-only execution control. It runs at live Luau opcode hooks; the host owns
// its supported debugger command loop. No extra scheduler or public Lua API.
class GLDebugger {
public:
    using StopHandler = std::function<GLDebugAction(GLDebugger&)>;
    explicit GLDebugger(GLExecutionDomain& Domain);
    ~GLDebugger();
    void Attach(StopHandler Handler);
    void Detach();
    bool IsAttached() const { return Enabled; }
    GLDebugState GetState() const { return State; }
    static const char* StateName(GLDebugState State);
    bool SetBreakpoint(const std::string& Source, int Line, bool Enabled, uint32_t BreakOnHit = 0);
    void ClearBreakpoints();
    std::vector<GLDebugBreakpoint> GetBreakpoints() const;
    bool RequestPause();
    void SetPollHandler(std::function<void()> Handler) { Poll = std::move(Handler); }
    void SetSourceHandler(std::function<void(const std::string&,int)> Handler) { SourceLoaded = std::move(Handler); }
    void RegisterChunk(lua_State* Thread, const std::string& Source, int Lines = 0);
    void RetireOwner(GLExecutionOwner* Owner);
    void RetireThread(lua_State* Thread);
    void BeginResume(lua_State* Thread);
    void EndResume(lua_State* Thread, int Status);
    void Shutdown();
    std::vector<GLDebugFrame> GetFrames() const;
    lua_State* GetInspectionThread() const;
    bool IsFrameInspectable(lua_State* Thread,int Level) const;
    uint64_t GetStopId() const { return StopId; }
    uint64_t GetGeneration() const { return Generation; }
    uint64_t GetCoroutineId() const { return CoroutineId; }
    const std::string& GetReason() const { return Reason; }
    size_t GetChunkCount() const { return Chunks.size(); }
    GLExecutionDomain& GetDomain() const { return Domain; }
    void SetNextAction(GLDebugAction Action) { NextAction = Action; OverrideAction = true; }

private:
    struct Chunk {
        GLExecutionOwner* Owner;
        int Reference;
        std::string Source;
        std::vector<int> Lines;
        std::map<int,int> Mappings;
    };
    GLExecutionDomain& Domain;
    GLDebugState State = GLDebugState::Detached;
    bool Enabled = false, OverrideAction = false, OriginalDebugInfo = false;
    StopHandler Stop;
    std::function<void()> Poll;
    std::function<void(const std::string&,int)> SourceLoaded;
    std::map<std::pair<std::string,int>, GLDebugBreakpoint> Breakpoints;
    std::vector<Chunk> Chunks;
    lua_State* InspectionThread = nullptr;
    lua_State* StepThread = nullptr;
    GLDebugAction Step = GLDebugAction::Continue, NextAction = GLDebugAction::Continue;
    GLDebugFrame StepOrigin;
    int StepDepth = 0;
    uint64_t StopId = 0, Generation = 0, Instructions = 0;
    uint64_t CoroutineId=0, NextCoroutineId=1;
    std::map<lua_State*,uint64_t> CoroutineIds; // bounded weak labels; destruction callback erases them
    std::string Reason;
    static void OnBreakpoint(lua_State* Thread, lua_Debug* Frame);
    static void OnStep(lua_State* Thread, lua_Debug* Frame);
    void Hook(lua_State* Thread, bool Breakpoint);
    void Suspend(lua_State* Thread, const char* Reason);
    void Refresh(Chunk& Loaded);
    void Release(Chunk& Loaded);
};
