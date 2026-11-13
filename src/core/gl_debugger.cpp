#include "gl_debugger.h"
#include "gl_execution_domain.h"
#include <algorithm>
#include <cstring>

namespace {
GLDebugger* GetDebugger(lua_State* Thread) {
    auto Owner = GLGetOwner(Thread);
    return Owner && Owner->Domain ? Owner->Domain->GetDebugger() : nullptr;
}
GLDebugFrame GetFrame(lua_State* Thread, int Level) {
    lua_Debug Frame{};
    if (!lua_getinfo(Thread, Level, "sln", &Frame)) return {};
    auto Text = [](const char* Value, size_t Limit) { return Value ? std::string(Value, (std::min)(std::strlen(Value), Limit)) : std::string(); };
    std::string Source = Text(Frame.source, 1024);
    if (!Source.empty() && (Source.front() == '@' || Source.front() == '=')) Source.erase(0, 1);
    return {Source, Text(Frame.name, 128), Frame.currentline};
}
}
GLDebugger::GLDebugger(GLExecutionDomain& Selected) : Domain(Selected) {}
GLDebugger::~GLDebugger() { Shutdown(); }
const char* GLDebugger::StateName(GLDebugState Selected) {
    switch (Selected) {
        case GLDebugState::Detached: return "Detached";
        case GLDebugState::Attached: return "Attached";
        case GLDebugState::Running: return "Running";
        case GLDebugState::PauseRequested: return "PauseRequested";
        case GLDebugState::Suspended: return "Suspended";
        case GLDebugState::Stepping: return "Stepping";
        case GLDebugState::Resuming: return "Resuming";
        case GLDebugState::Terminating: return "Terminating";
        case GLDebugState::Disconnected: return "Disconnected";
        case GLDebugState::Faulted: return "Faulted";
    }
    return "Faulted";
}
void GLDebugger::Attach(StopHandler Handler) {
    if (Enabled || Domain.IsClosing() || !Handler) return;
    Stop = std::move(Handler);
    Enabled = true; State = GLDebugState::Attached;
    OriginalDebugInfo = Domain.HasDebugInfo();
    Domain.SetDebugInfo(true);
    lua_callbacks(Domain.GetState())->debugbreak = OnBreakpoint;
    lua_callbacks(Domain.GetState())->debugstep = OnStep;
}
void GLDebugger::Detach() {
    if (Enabled) Domain.SetDebugInfo(OriginalDebugInfo);
    Enabled = false; State = GLDebugState::Disconnected;
    StepThread = nullptr; Step = GLDebugAction::Continue;
    ClearBreakpoints();
    for (auto& Loaded : Chunks) Release(Loaded);
    Chunks.clear();
    // Callback pointers stay installed until the protected resume returns.
    // Pinned Luau forbids changing callbacks while its VM is executing.
}
void GLDebugger::Shutdown() {
    State = GLDebugState::Terminating;
    Detach();
    InspectionThread = nullptr; Generation = 0;
    State = GLDebugState::Detached;
}
bool GLDebugger::SetBreakpoint(const std::string& Source, int Line, bool Active, uint32_t BreakOnHit) {
    if (!Enabled || Source.empty() || Source.size() > 1024 || Source.find('\0') != std::string::npos ||
        Line < 1 || Line > 1000000 || BreakOnHit > 1000000) return false;
    auto Key = std::make_pair(Source, Line);
    auto Found = Breakpoints.find(Key);
    if (Found == Breakpoints.end() && Breakpoints.size() >= 128) return false;
    GLDebugBreakpoint Entry; Entry.Source = Source; Entry.Line = Line;
    Entry.Enabled = Active; Entry.BreakOnHit = BreakOnHit;
    Breakpoints[Key] = std::move(Entry);
    for (auto& Loaded : Chunks) if (Loaded.Source == Source) Refresh(Loaded);
    return true;
}
void GLDebugger::ClearBreakpoints() {
    Breakpoints.clear();
    for (auto& Loaded : Chunks) Refresh(Loaded);
}
std::vector<GLDebugBreakpoint> GLDebugger::GetBreakpoints() const {
    std::vector<GLDebugBreakpoint> Result;
    for (const auto& Item : Breakpoints) {
        auto Entry = Item.second;
        for (const auto& Loaded : Chunks) if (Loaded.Source == Entry.Source && Loaded.Owner->Alive) {
            auto Found = Loaded.Mappings.find(Entry.Line);
            if (Found != Loaded.Mappings.end() && std::find(Entry.AdmittedLines.begin(), Entry.AdmittedLines.end(), Found->second) == Entry.AdmittedLines.end())
                Entry.AdmittedLines.push_back(Found->second);
        }
        Result.push_back(std::move(Entry));
    }
    return Result;
}
void GLDebugger::Refresh(Chunk& Loaded) {
    lua_State* Anchor = GLReferenceState(Loaded.Reference);
    if (!Anchor || !Loaded.Owner->Alive) return;
    int Top = lua_gettop(Anchor);
    if (!lua_checkstack(Anchor, 2)) return;
    lua_rawgeti(Anchor, LUA_REGISTRYINDEX, Loaded.Reference);
    for (int Line : Loaded.Lines) lua_breakpoint(Anchor, -1, Line, false);
    Loaded.Lines.clear();
    Loaded.Mappings.clear();
    for (auto& Item : Breakpoints) {
        auto& Entry = Item.second;
        if (!Entry.Enabled || Entry.Source != Loaded.Source) continue;
        int Actual = lua_breakpoint(Anchor, -1, Entry.Line, true);
        if (Actual > 0) { Loaded.Lines.push_back(Actual); Loaded.Mappings[Entry.Line] = Actual; }
    }
    lua_settop(Anchor, Top);
}
void GLDebugger::RegisterChunk(lua_State* Thread, const std::string& SourceName) {
    auto Owner = GLGetOwner(Thread);
    if (!Enabled || !Owner || !Owner->Alive || !Owner->NativeId || Chunks.size() >= 256 ||
        !lua_isfunction(Thread, -1) || SourceName.size() > 1025) return;
    std::string Source = SourceName;
    if (!Source.empty() && (Source[0] == '@' || Source[0] == '=')) Source.erase(0, 1);
    struct Context { lua_State* Source; int Reference = LUA_NOREF; } Data{Thread};
    int Status = lua_cpcall(Owner->Anchor, [](lua_State* Anchor) -> int {
        auto& Data = *static_cast<Context*>(lua_touserdata(Anchor, 1));
        if (!lua_checkstack(Data.Source, 1)) return 0;
        lua_pushvalue(Data.Source, -1); lua_xmove(Data.Source, Anchor, 1);
        Data.Reference = GLReference(Anchor, -1);
        return 0;
    }, &Data);
    if (Status != LUA_OK) { lua_pop(Owner->Anchor, 1); State = GLDebugState::Faulted; return; }
    if (Data.Reference == LUA_NOREF) return;
    Chunks.push_back({Owner, Data.Reference, Source, {}, {}});
    Refresh(Chunks.back());
}
void GLDebugger::Release(Chunk& Loaded) {
    if (Loaded.Owner->Anchor) {
        lua_State* Anchor = Loaded.Owner->Anchor;
        int Top = lua_gettop(Anchor);
        if (lua_checkstack(Anchor, 1)) {
            lua_rawgeti(Anchor, LUA_REGISTRYINDEX, Loaded.Reference);
            if (lua_isfunction(Anchor, -1) && !lua_iscfunction(Anchor, -1))
                for (int Line : Loaded.Lines) lua_breakpoint(Anchor, -1, Line, false);
            lua_settop(Anchor, Top);
        }
        GLUnreference(nullptr, Loaded.Reference);
    }
}
void GLDebugger::RetireOwner(GLExecutionOwner* Owner) {
    for (auto It = Chunks.begin(); It != Chunks.end();) {
        if (It->Owner != Owner) { ++It; continue; }
        Release(*It); It = Chunks.erase(It);
    }
    if (StepThread && GLGetOwner(StepThread) == Owner) { StepThread = nullptr; Step = GLDebugAction::Continue; }
}
bool GLDebugger::RequestPause() {
    if (!Enabled || State == GLDebugState::Suspended || Domain.IsClosing()) return false;
    State = GLDebugState::PauseRequested; return true;
}
void GLDebugger::BeginResume(lua_State* Thread) {
    lua_singlestep(Thread, Enabled);
    if (Enabled && State == GLDebugState::Attached) State = GLDebugState::Running;
}
void GLDebugger::EndResume(lua_State* Thread, int) {
    if (StepThread == Thread) { StepThread = nullptr; Step = GLDebugAction::Continue; if (Enabled) State = GLDebugState::Running; }
    if (!Enabled) { lua_singlestep(Thread, false); State = GLDebugState::Detached; }
}
void GLDebugger::OnBreakpoint(lua_State* Thread, lua_Debug*) { if (auto Debugger = GetDebugger(Thread)) Debugger->Hook(Thread, true); }
void GLDebugger::OnStep(lua_State* Thread, lua_Debug*) { if (auto Debugger = GetDebugger(Thread)) Debugger->Hook(Thread, false); }
void GLDebugger::Hook(lua_State* Thread, bool IsBreakpoint) {
    if (!Enabled || State == GLDebugState::Suspended || Domain.IsClosing() || Domain.HasMemoryFailure()) return;
    auto Owner = GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || !Owner->NativeId || Owner->Domain != &Domain || !lua_isyieldable(Thread)) return;
    if (!IsBreakpoint && (++Instructions & 1023) == 0 && Poll) Poll();
    if (!Enabled) return;
    if (State == GLDebugState::PauseRequested) { Suspend(Thread, "Pause"); return; }
    if (IsBreakpoint) {
        auto Frame = GetFrame(Thread, 0);
        bool Admitted = false;
        for (auto& Item : Breakpoints) {
            auto& Entry = Item.second;
            if (!Entry.Enabled || Entry.Source != Frame.Source) continue;
            bool Matches = false;
            for (const auto& Loaded : Chunks) if (Loaded.Source == Frame.Source && Loaded.Owner == Owner) {
                auto Found = Loaded.Mappings.find(Entry.Line);
                if (Found != Loaded.Mappings.end() && Found->second == Frame.Line) Matches = true;
            }
            if (Matches) { if (Entry.Hits < 1000000) ++Entry.Hits; Admitted |= !Entry.BreakOnHit || Entry.Hits == Entry.BreakOnHit; }
        }
        if (Admitted) Suspend(Thread, "Breakpoint");
        return;
    }
    if (StepThread != Thread || Step == GLDebugAction::Continue) return;
    auto Frame = GetFrame(Thread, 0); int Depth = lua_stackdepth(Thread);
    bool Changed = Frame.Line != StepOrigin.Line || Frame.Source != StepOrigin.Source || Depth != StepDepth;
    if (Changed && Frame.Line > 0 && (Step == GLDebugAction::Into ||
        (Step == GLDebugAction::Over && Depth <= StepDepth) || (Step == GLDebugAction::Out && Depth < StepDepth)))
        Suspend(Thread, "Step");
}
void GLDebugger::Suspend(lua_State* Thread, const char* SelectedReason) {
    auto Owner = GLGetOwner(Thread);
    if (!Stop || !Owner || !Owner->Alive) return;
    State = GLDebugState::Suspended; InspectionThread = Thread;
    Generation = Owner->Token; ++StopId; Reason = SelectedReason;
    OverrideAction = false;
    GLDebugAction Action = GLDebugAction::Continue;
    Domain.DebuggerPause([&] { Action = Stop(*this); });
    if (OverrideAction) Action = NextAction;
    InspectionThread = nullptr; Generation = 0;
    if (!Owner->Alive || Domain.IsClosing() || Action == GLDebugAction::Stop) {
        State = GLDebugState::Terminating; Domain.CancelOwner(Owner);
        luaL_error(Thread, "[Debugger:Lifecycle] Suspended execution was retired");
    }
    if (Action == GLDebugAction::Detach || !Enabled) { Detach(); return; }
    State = GLDebugState::Resuming;
    Step = Action; StepThread = Action == GLDebugAction::Continue ? nullptr : Thread;
    StepOrigin = GetFrame(Thread, 0); StepDepth = lua_stackdepth(Thread);
    State = StepThread ? GLDebugState::Stepping : GLDebugState::Running;
}
lua_State* GLDebugger::GetInspectionThread() const {
    auto Owner = GLGetOwner(InspectionThread);
    return State == GLDebugState::Suspended && Owner && Owner->Alive && Owner->Token == Generation &&
        !Domain.HasMemoryFailure() && !Domain.IsClosing() ? InspectionThread : nullptr;
}
std::vector<GLDebugFrame> GLDebugger::GetFrames() const {
    std::vector<GLDebugFrame> Frames;
    auto Thread = GetInspectionThread();
    if (Thread) for (int Level = 0; Level < (std::min)(64, lua_stackdepth(Thread)); ++Level) Frames.push_back(GetFrame(Thread, Level));
    return Frames;
}
