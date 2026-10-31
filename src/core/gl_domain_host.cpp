#include "gl_domain_host.h"
#include "luau_script.h"
#include "luau_instance_access.h"
#include "gl_runtime.h"
#include "gl_errors.h"
#include "gl_net_bridge.h"
#include "rbx_character.h"
#include "roblox_network.h"
#include "roblox_services.h"
#include "roblox_player.h"
#include "roblox_remote.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/callable_custom.hpp>
#include <algorithm>
#include <functional>
#include <cmath>

namespace {
GLDomainLimits GLLimits(GLDomainKind Kind) {
    GLDomainLimits Limits;
    auto Settings = ProjectSettings::get_singleton();
    String Prefix = Kind == GLDomainKind::Server ? "godot_luau/server_limits/" : "godot_luau/client_limits/";
    auto Read = [&](const char* Name, double Default, double Maximum, bool Integer) -> double {
        String Key = Prefix + Name;
        if (!Settings || !Settings->has_setting(Key)) return Default;
        Variant Value = Settings->get_setting(Key);
        bool ValidType = Value.get_type() == Variant::INT || (!Integer && Value.get_type() == Variant::FLOAT);
        double Number = ValidType ? static_cast<double>(Value) : -1;
        if (!std::isfinite(Number) || Number < 0 || Number > Maximum) {
            UtilityFunctions::print("[Runtime:Configuration] Invalid ", Key, "; using default ", Default);
            return Default;
        }
        return Number;
    };
    Limits.ResumeMilliseconds = Read("resume_milliseconds", Limits.ResumeMilliseconds, 60000, false);
    Limits.MaxSafepoints = static_cast<uint64_t>(Read("max_safepoints", 0, 1000000000, true));
    Limits.MemoryBytes = static_cast<size_t>(Read("vm_memory_bytes", Limits.MemoryBytes, 16.0*1024*1024*1024, true));
    Limits.Tasks = static_cast<size_t>(Read("tasks", Limits.Tasks, 1000000, true));
    Limits.Coroutines = static_cast<size_t>(Read("coroutines", Limits.Coroutines, 2000000, true));
    Limits.References = static_cast<size_t>(Read("references", Limits.References, 1000000, true));
    Limits.Owners = static_cast<size_t>(Read("owners", Limits.Owners, 1000000, true));
    return Limits;
}
uint64_t GLHostIdentity = 0;
// Godot strips bind() arguments when comparing signal slots. The immutable
// callback reference must be part of the base Callable's identity instead.
class GLChildCallable : public CallableCustom {
    uint64_t Receiver;
    int Reference;
    static bool Equal(const CallableCustom* Left, const CallableCustom* Right) {
        auto A = static_cast<const GLChildCallable*>(Left);
        auto B = static_cast<const GLChildCallable*>(Right);
        return A->Reference == B->Reference && A->Receiver == B->Receiver;
    }
    static bool Less(const CallableCustom* Left, const CallableCustom* Right) {
        auto A = static_cast<const GLChildCallable*>(Left);
        auto B = static_cast<const GLChildCallable*>(Right);
        return A->Reference != B->Reference ? A->Reference < B->Reference : A->Receiver < B->Receiver;
    }
public:
    GLChildCallable(uint64_t SelectedReceiver, int SelectedReference) : Receiver(SelectedReceiver), Reference(SelectedReference) {}
    uint32_t hash() const override { return static_cast<uint32_t>(Reference); }
    String get_as_text() const override { return String("[Runtime:ChildRelay] ") + String::num_int64(Reference); }
    CompareEqualFunc get_compare_equal_func() const override { return Equal; }
    CompareLessFunc get_compare_less_func() const override { return Less; }
    ObjectID get_object() const override { return ObjectID(Receiver); }
    bool is_valid() const override { return GLReferenceState(Reference) && ObjectDB::get_instance(Receiver); }
    int get_argument_count(bool& Valid) const override { Valid = true; return 1; }
    void call(const Variant** Arguments, int Count, Variant& Result, GDExtensionCallError& Error) const override {
        Error.error = GDEXTENSION_CALL_OK;
        Result = Variant();
        if (Count != 1 || Arguments[0]->get_type() != Variant::OBJECT) {
            Error.error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
            Error.argument = 0;
            Error.expected = Variant::OBJECT;
            return;
        }
        auto Script = Object::cast_to<ScriptNodeBase>(ObjectDB::get_instance(Receiver));
        Object* ChildObject = *Arguments[0];
        auto Child = Object::cast_to<Node>(ChildObject);
        // Resolve both weak native identity and the live owner at delivery.
        // Do not touch the receiver after user code may destroy it.
        if (Script && Child && GLReferenceState(Reference)) Script->_gl_child_event(Child, Reference);
    }
};
template<class T> void GLEraseWaits(std::vector<T>& Waits, lua_State* Anchor) {
    Waits.erase(std::remove_if(Waits.begin(), Waits.end(), [Anchor](const T& Wait) {
        return Wait.main_L == Anchor;
    }), Waits.end());
}
}

GLDomainHost* GLGetDomainHost(SceneTree* Tree) {
    Node* Scope = Tree ? Tree->get_current_scene() : nullptr;
    if (GLHostIdentity) {
        if (auto Host = Object::cast_to<GLDomainHost>(ObjectDB::get_instance(GLHostIdentity))) {
            if (!Scope || Host->get_parent() == Scope) return Host;
            Host->Shutdown();
            Host->queue_free(); // scene replacement must not close a currently executing VM in-place
        }
        GLHostIdentity = 0;
    }
    if (!Tree || !Tree->get_root()) return nullptr;
    auto Host = memnew(GLDomainHost);
    Host->set_name("GodotLuauRuntime");
    GLHostIdentity = static_cast<uint64_t>(Host->get_instance_id());
    (Scope ? Scope : static_cast<Node*>(Tree->get_root()))->add_child(Host);
    return Host;
}
bool GLDomainAllowed(GLDomainKind Kind) {
    if (Kind == GLDomainKind::Server) return !gl_startup_is_client() && gl_net_role() != 2;
    if (gl_freecam().active) return false;
    if (!gl_startup_is_client() && gl_net_role() == 0 && gl_startup_defer_server()) return false;
    PackedStringArray Arguments = OS::get_singleton()->get_cmdline_user_args();
    for (int Index = 0; Index < Arguments.size(); ++Index) {
        String Argument = Arguments[Index];
        if (Argument == "--glserver" || Argument == "--glhost" || Argument == "--glinstance") return false;
        if (Argument == "--glindex" && Index + 1 < Arguments.size() && String(Arguments[Index + 1]).to_int() == 1) return false;
    }
    return true; // local single-player and a player-host may need both domains
}
GLDomainHost::~GLDomainHost() {
    Shutdown();
    for (const auto& Domain : Domains) if (Domain) gl_unregister_state(Domain->GetState());
    if (GLHostIdentity == static_cast<uint64_t>(get_instance_id())) GLHostIdentity = 0;
}
GLExecutionDomain& GLDomainHost::GetDomain(GLDomainKind Kind) {
    size_t Index = Kind == GLDomainKind::Server ? 0 : 1;
    if (!Domains[Index]) {
        Domains[Index] = std::make_unique<GLExecutionDomain>(Kind, GLLimits(Kind));
        Domains[Index]->SetTimeProvider([]() { return static_cast<double>(Time::get_singleton()->get_ticks_msec()) / 1000.0; });
        Domains[Index]->SetEnvironmentHook([](lua_State* Thread, uint64_t Identity) {
            Node* Script = Object::cast_to<Node>(ObjectDB::get_instance(Identity));
            PushLuauInstance(Thread, Script); lua_setglobal(Thread, "script");
        });
        Domains[Index]->SetModuleResolver([](lua_State* Thread, int Argument, GLModuleSource& Module) {
            auto Wrapper = static_cast<GodotObjectWrapper*>(lua_touserdata(Thread, Argument));
            auto Script = Wrapper ? Object::cast_to<ModuleScript>(gow_node(Wrapper)) : nullptr;
            if (!Script || !Script->is_inside_tree()) return false;
            Ref<LuauScript> Resource = Script->get_codigo_luau();
            if (Resource.is_null()) return false;
            Module.Identity = static_cast<uint64_t>(Script->get_instance_id());
            Module.ResourceIdentity = static_cast<uint64_t>(Resource->get_instance_id());
            Module.Revision = Resource->GetSourceRevision();
            return true;
        });
        Domains[Index]->SetModuleLoader([](GLModuleSource& Module) {
            auto Script = Object::cast_to<ModuleScript>(ObjectDB::get_instance(Module.Identity));
            if (!Script || !Script->is_inside_tree()) return false;
            Ref<LuauScript> Resource = Script->get_codigo_luau();
            if (Resource.is_null() || static_cast<uint64_t>(Resource->get_instance_id()) != Module.ResourceIdentity ||
                Resource->GetSourceRevision() != Module.Revision) return false;
            Module.Source = Resource->_get_source_code().utf8().get_data();
            Module.ChunkName = (String("=") + gl_instance_fullname(Script)).utf8().get_data();
            return true;
        });
        Domains[Index]->SetInvalidationHook([this](lua_State* Anchor) { InvalidateOwner(Anchor); });
        Domains[Index]->SetThreadInvalidationHook([this](lua_State* Thread) { InvalidateThread(Thread); });
        Domains[Index]->SetErrorHandler([](lua_State* Thread, const std::string& Error) {
            auto Owner = GLGetOwner(Thread);
            Node* Script = Owner ? Object::cast_to<Node>(ObjectDB::get_instance(Owner->NativeId)) : nullptr;
            String Context = Script ? gl_instance_fullname(Script) : Owner && Owner->NativeId
                ? String("retired owner ") + String::num_uint64(Owner->Token)
                : String("domain bootstrap");
            UtilityFunctions::print(String("[Runtime:Script] ") + Context + ": " + String::utf8(Error.c_str()));
            // An exhausted VM must not allocate while collecting a Lua trace.
            if (Owner && Owner->Domain->HasMemoryFailure()) gl_unregister_state(Owner->Domain->GetState());
            if (Owner && !Owner->Domain->HasMemoryFailure()) gl_report_script_error(Thread);
        });
        if (Domains[Index]->GetFailure()) UtilityFunctions::print(String::utf8(Domains[Index]->GetFailure()));
    }
    return *Domains[Index];
}
Dictionary GLDomainHost::GetResourceStats(bool Client) const {
    Dictionary Stats;
    const auto& Domain = Domains[Client ? 1 : 0];
    Stats["Created"] = static_cast<bool>(Domain);
    if (!Domain) return Stats;
    const auto& Memory = Domain->GetMemoryAccount();
    const auto& Limits = Domain->GetLimits();
    Stats["Closing"] = Domain->IsClosing();
    Stats["HttpPending"] = int64_t(Http?Http->Pending(Client):0);
    Stats["DataStorePending"] = int64_t(!Client && DataStore?DataStore->Pending():0);
    Stats["DataStorePeak"] = int64_t(!Client && DataStore?DataStore->Peak():0);
    Stats["HttpPeak"] = int64_t(!Client && Http?Http->Peak():0);
    Stats["MemoryFailed"] = Domain->HasMemoryFailure();
    Stats["HostOperationsAvailable"] = Domain->CanRunNative();
    Stats["Sandboxed"] = Domain->IsSandboxed();
    Stats["VmLiveBytes"] = static_cast<int64_t>(Memory.Live);
    Stats["VmPeakBytes"] = static_cast<int64_t>(Memory.Peak);
    Stats["VmLimitBytes"] = static_cast<int64_t>(Memory.Limit);
    Stats["AllocationRejections"] = static_cast<int64_t>(Memory.Rejections);
    Stats["AdmissionRejections"] = static_cast<int64_t>(Domain->GetAdmissionRejections());
    Stats["Tasks"] = static_cast<int64_t>(Domain->GetTaskCount());
    Stats["Coroutines"] = static_cast<int64_t>(Domain->GetCoroutineCount());
    Stats["References"] = static_cast<int64_t>(Domain->GetReferenceCount());
    Stats["Owners"] = static_cast<int64_t>(Domain->GetOwnerCount());
    Stats["TaskPeak"] = static_cast<int64_t>(Domain->GetTaskPeak());
    Stats["CoroutinePeak"] = static_cast<int64_t>(Domain->GetCoroutinePeak());
    Stats["ReferencePeak"] = static_cast<int64_t>(Domain->GetReferencePeak());
    Stats["OwnerPeak"] = static_cast<int64_t>(Domain->GetOwnerPeak());
    Stats["TaskLimit"] = static_cast<int64_t>(Limits.Tasks);
    Stats["CoroutineLimit"] = static_cast<int64_t>(Limits.Coroutines);
    Stats["ReferenceLimit"] = static_cast<int64_t>(Limits.References);
    Stats["OwnerLimit"] = static_cast<int64_t>(Limits.Owners);
    Stats["ResumeMilliseconds"] = Limits.ResumeMilliseconds;
    Stats["MaxSafepoints"] = static_cast<int64_t>(Limits.MaxSafepoints);
    if (Domain->GetFailure()) Stats["Failure"] = String::utf8(Domain->GetFailure());
    return Stats;
}
bool GLDomainHost::ClaimInitialization(GLDomainKind Kind) {
    size_t Index = Kind == GLDomainKind::Server ? 0 : 1;
    if (Initialized[Index]) return false;
    Initialized[Index] = true;
    return true;
}
void GLDomainHost::InstallHttp(lua_State* Thread,GLExecutionDomain& Domain) {
    if (!Http) Http=std::make_unique<GLHttpManager>(*this);
    GLHttpManager::Install(Thread,Domain,uint64_t(get_instance_id()));
}
int GLDomainHost::BeginHttp(lua_State* Thread,GLExecutionDomain* Domain,int Operation) {
    if (!Http) luaL_error(Thread,"[Runtime:HTTP] Capability unavailable");
    return Http->Begin(Thread,Domain,Operation);
}
bool GLDomainHost::InterruptHttp(lua_State* Thread) { return Http && Http->Interrupt(Thread); }
bool GLDomainHost::IsHttpAvailable(lua_State* Thread,GLExecutionDomain* Domain) const { return Http && Http->Available(Thread,Domain); }
int GLDomainHost::BeginDataStore(lua_State* Thread,GLExecutionDomain* Domain,const std::string& Root,const std::string& Leaf,int Operation,bool Exists,const std::string& Expected,const std::string& Value) {
    if (!DataStore) DataStore=std::make_unique<GLDataStoreManager>();
    return DataStore->Begin(Thread,Domain,Root,Leaf,Operation,Exists,Expected,Value);
}
bool GLDomainHost::InterruptDataStore(lua_State* Thread) { return DataStore && DataStore->Interrupt(Thread); }
void GLDomainHost::WaitForChild(lua_State* Thread, uint64_t Parent, const String& Name, double Timeout, int Reference) {
    ChildWaits.push_back({Thread, GLGetOwnerState(Thread), Parent, Name, Timeout, 0, Reference,
        String::utf8(lua_debugtrace(Thread))});
}
void GLDomainHost::WaitForInvoke(lua_State* Thread, int64_t CallId, double Timeout, int Reference) {
    InvokeWaits.push_back({Thread, GLGetOwnerState(Thread), CallId, Timeout, 0, Reference});
}
GLExecutionDomain* GLDomainHost::WaitingDomain(lua_State* Thread) const {
    for (const auto& Domain : Domains) if (Domain && Domain->CanResume(Thread)) return Domain.get();
    return nullptr;
}
void GLDomainHost::InvalidateOwner(lua_State* Anchor) {
    if (DataStore) DataStore->CancelOwner(Anchor);
    if (Http) Http->CancelOwner(Anchor);
    for (size_t Index = ChildConnections.size(); Index > 0; --Index)
        if (ChildConnections[Index - 1].Anchor == Anchor) DisconnectChild(ChildConnections[Index - 1].Reference);
    ChildWaits.erase(std::remove_if(ChildWaits.begin(), ChildWaits.end(), [Anchor](const GLChildWait& Wait) {
        return Wait.Anchor == Anchor;
    }), ChildWaits.end());
    InvokeWaits.erase(std::remove_if(InvokeWaits.begin(), InvokeWaits.end(), [Anchor](const GLInvokeWait& Wait) {
        if (Wait.Anchor != Anchor) return false;
        if (auto Network = Object::cast_to<NetworkService>(ObjectDB::get_instance(gl_net_service_id())))
            Network->CancelInvoke(Wait.CallId);
        gl_net_responses().erase(Wait.CallId);
        return true;
    }), InvokeWaits.end());
    auto& Pending = get_pending_resumes();
    Pending.erase(std::remove_if(Pending.begin(), Pending.end(), [Anchor](const LuauPendingResume& Resume) {
        if (Resume.main_L == Anchor) GLUnreference(nullptr, Resume.Guard);
        return Resume.main_L == Anchor;
    }), Pending.end());
    // Signal waiters hold coroutine pointers, so detach them before the domain
    // releases roots. Ordinary callbacks additionally validate non-recycled refs.
    SceneTree* Tree = get_tree();
    if (!Tree || !Tree->get_root()) return;
    std::function<void(Node*)> Visit = [&](Node* Target) {
        if (auto Service = Object::cast_to<RunService>(Target)) Service->remove_by_state(Anchor);
        if (auto Service = Object::cast_to<Players>(Target)) {
            GLEraseWaits(Service->player_added_waits, Anchor);
            GLEraseWaits(Service->player_removing_waits, Anchor);
        }
        if (auto Player = Object::cast_to<PlayerObject>(Target)) GLEraseWaits(Player->char_added_waits, Anchor);
        if (auto Remote = Object::cast_to<RemoteEventNode>(Target)) Remote->cleanup_state(Anchor);
        if (auto Remote = Object::cast_to<RemoteFunctionNode>(Target)) Remote->cleanup_state(Anchor);
        if (auto Bindable = Object::cast_to<BindableEventNode>(Target)) Bindable->cleanup_state(Anchor);
        for (int Index = 0; Index < Target->get_child_count(); ++Index) Visit(Target->get_child(Index));
    };
    Visit(Tree->get_root());
}
void GLDomainHost::InvalidateModule(uint64_t NativeId) {
    for (const auto& Domain : Domains) if (Domain) Domain->InvalidateModule(NativeId);
}
bool GLDomainHost::ConnectChild(lua_State* Thread, Node* Target, Node* Receiver, bool Added, int Reference) {
    lua_State* Anchor = GLReferenceState(Reference);
    if (!Anchor || Anchor != GLGetOwnerState(Thread) || !Target || !Receiver) return false;
    StringName Signal = Added ? "child_entered_tree" : "child_exiting_tree";
    Callable Handler(memnew(GLChildCallable(static_cast<uint64_t>(Receiver->get_instance_id()), Reference)));
    if (Target->connect(Signal, Handler) != OK) return false;
    ChildConnections.push_back({Anchor, static_cast<uint64_t>(Target->get_instance_id()), Signal, Handler, Reference});
    return true;
}
#ifdef GL_RUNTIME_TESTS
void GLDomainHost::ResetDomainForTests(bool Client) {
    size_t Index = Client ? 1 : 0;
    if (Domains[Index]) {
        Domains[Index]->Shutdown();
        gl_unregister_state(Domains[Index]->GetState());
        Domains[Index].reset();
    }
    Initialized[Index] = false;
}
#endif
void GLDomainHost::DisconnectChild(int Reference) {
    auto Found = std::find_if(ChildConnections.begin(), ChildConnections.end(), [Reference](const GLChildConnection& Connection) {
        return Connection.Reference == Reference;
    });
    if (Found == ChildConnections.end()) return;
    GLChildConnection Connection = *Found;
    ChildConnections.erase(Found); // keep a local Callable root across disconnection
    if (auto Target = Object::cast_to<Node>(ObjectDB::get_instance(Connection.Target)))
        if (Target->is_connected(Connection.Signal, Connection.Handler)) Target->disconnect(Connection.Signal, Connection.Handler);
    GLUnreference(nullptr, Reference);
}
void GLDomainHost::InvalidateThread(lua_State* Thread) {
    if (DataStore) DataStore->CancelThread(Thread);
    if (Http) Http->CancelThread(Thread);
    ChildWaits.erase(std::remove_if(ChildWaits.begin(), ChildWaits.end(), [Thread](const GLChildWait& Wait) {
        if (Wait.Thread != Thread) return false;
        GLUnreference(nullptr, Wait.Reference);
        return true;
    }), ChildWaits.end());
    InvokeWaits.erase(std::remove_if(InvokeWaits.begin(), InvokeWaits.end(), [Thread](const GLInvokeWait& Wait) {
        if (Wait.Thread != Thread) return false;
        if (auto Network = Object::cast_to<NetworkService>(ObjectDB::get_instance(gl_net_service_id()))) Network->CancelInvoke(Wait.CallId);
        GLUnreference(nullptr, Wait.Reference);
        return true;
    }), InvokeWaits.end());
    auto& Pending = get_pending_resumes();
    Pending.erase(std::remove_if(Pending.begin(), Pending.end(), [Thread](const LuauPendingResume& Resume) {
        if (Resume.thread == Thread) GLUnreference(nullptr, Resume.Guard);
        return Resume.thread == Thread;
    }), Pending.end());
    SceneTree* Tree = get_tree();
    if (!Tree || !Tree->get_root()) return;
    auto EraseThread = [Thread](auto& Waits) {
        Waits.erase(std::remove_if(Waits.begin(), Waits.end(), [Thread](const auto& Wait) { return Wait.th == Thread; }), Waits.end());
    };
    std::function<void(Node*)> Visit = [&](Node* Target) {
        if (auto Service = Object::cast_to<RunService>(Target)) {
            auto EraseRunWait = [Thread](auto& Waits) {
                Waits.erase(std::remove_if(Waits.begin(), Waits.end(), [Thread](const auto& Wait) { return Wait.thread == Thread; }), Waits.end());
            };
            EraseRunWait(Service->heartbeat_wait_cbs); EraseRunWait(Service->render_stepped_wait_cbs); EraseRunWait(Service->stepped_wait_cbs);
        }
        if (auto Service = Object::cast_to<Players>(Target)) { EraseThread(Service->player_added_waits); EraseThread(Service->player_removing_waits); }
        if (auto Player = Object::cast_to<PlayerObject>(Target)) EraseThread(Player->char_added_waits);
        if (auto Remote = Object::cast_to<RemoteEventNode>(Target)) { EraseThread(Remote->server_wait_cbs); EraseThread(Remote->client_wait_cbs); }
        for (int Index = 0; Index < Target->get_child_count(); ++Index) Visit(Target->get_child(Index));
    };
    Visit(Tree->get_root());
}
void GLDomainHost::_process(double Delta) {
    if (DataStore) DataStore->Tick();
    if (Http) Http->Tick();
    // Weak native targets may be destroyed while their script/module survives.
    // Reap those registrations before entering Lua, including detached targets.
    for (size_t Index = ChildConnections.size(); Index > 0; --Index) {
        const auto& Connection = ChildConnections[Index - 1];
        if (!GLReferenceAlive(Connection.Anchor, Connection.Reference) ||
            !ObjectDB::get_instance(Connection.Target) || !Connection.Handler.is_valid())
            DisconnectChild(Connection.Reference);
    }
    // Drain condition queues before timed work. Remove entries before resuming:
    // resumed code may destroy an owner or append to the same collections.
    for (size_t Index = 0; Index < ChildWaits.size();) {
        ChildWaits[Index].Elapsed += Delta;
        GLChildWait Wait = ChildWaits[Index];
        GLExecutionDomain* Domain = WaitingDomain(Wait.Thread);
        Node* Parent = Object::cast_to<Node>(ObjectDB::get_instance(Wait.Parent));
        Node* Found = nullptr;
        if (Parent) for (int Child = 0; Child < Parent->get_child_count(); ++Child)
            if (Parent->get_child(Child)->get_name() == StringName(Wait.Name)) { Found = Parent->get_child(Child); break; }
        bool Ready = Found || !Parent || (Wait.Timeout > 0 && Wait.Elapsed >= Wait.Timeout);
        if (Domain && !Ready && Wait.Timeout <= 0 && !Wait.Warned && Wait.Elapsed >= 5.0) {
            ChildWaits[Index].Warned = true;
            UtilityFunctions::print(String("[Runtime:Wait] Infinite yield possible on '") +
                gl_instance_fullname(Parent) + ":WaitForChild(\"" + Wait.Name + "\")'");
            UtilityFunctions::print_rich(gl_format_roblox_stack(Wait.Trace));
        }
        if (!Domain || Ready) {
            ChildWaits.erase(ChildWaits.begin() + Index);
            if (Domain) Domain->ResumePrepared(Wait.Thread, [&](lua_State* Thread) -> int {
                PushLuauInstance(Thread, Found); return 1;
            });
            GLUnreference(nullptr, Wait.Reference);
        } else ++Index;
    }
    auto Pending = std::move(get_pending_resumes());
    get_pending_resumes().clear();
    for (const auto& Resume : Pending) {
        bool Valid = Resume.Guard == LUA_NOREF || GLReferenceAlive(Resume.main_L, Resume.Guard);
        if (!Valid || !WaitingDomain(Resume.thread) || GLGetOwnerState(Resume.thread) != Resume.main_L) {
            GLUnreference(nullptr, Resume.Guard);
            continue;
        }
        GLUnreference(nullptr, Resume.Guard);
        auto Domain = GLGetOwner(Resume.thread)->Domain;
        Domain->ResumePrepared(Resume.thread, [&](lua_State* Thread) -> int {
            if (Resume.use_args) {
                Node* Context = Object::cast_to<Node>(ObjectDB::get_instance(Resume.ctx_id));
                return gl_net_decode_args(Thread, Resume.args, Context);
            }
            if (Resume.NodeId) PushLuauInstance(Thread, Object::cast_to<Node>(ObjectDB::get_instance(Resume.NodeId)));
            else lua_pushnumber(Thread, Resume.delta);
            return 1;
        });
    }
    for (size_t Index = 0; Index < InvokeWaits.size();) {
        InvokeWaits[Index].Elapsed += Delta;
        GLInvokeWait Wait = InvokeWaits[Index];
        GLExecutionDomain* Domain = WaitingDomain(Wait.Thread);
        auto Found = gl_net_responses().find(Wait.CallId);
        bool Ready = Found != gl_net_responses().end() && Found->second.ready;
        bool TimedOut = Wait.Timeout > 0 && Wait.Elapsed >= Wait.Timeout;
        if (Domain && !Ready && !TimedOut && !Wait.Warned && Wait.Elapsed >= 10.0) {
            InvokeWaits[Index].Warned = true;
            UtilityFunctions::print("[Runtime:Wait] Infinite yield possible on RemoteFunction invoke");
        }
        if (Domain && !Ready && !TimedOut) { ++Index; continue; }
        InvokeWaits.erase(InvokeWaits.begin() + Index);
        GLNetResponse Response;
        if (Ready) { Response = Found->second; gl_net_responses().erase(Found); }
        if (Domain) {
            if (Ready && Response.ok) {
                Node* Context = Object::cast_to<Node>(ObjectDB::get_instance(gl_net_service_id()));
                Domain->ResumePrepared(Wait.Thread, [&](lua_State* Thread) -> int {
                    return gl_net_decode_args(Thread, Response.rets, Context);
                });
            } else {
                String Error = Ready && !Response.rets.is_empty() ? String(Response.rets[0]) : String("RemoteFunction invoke timed out");
                Domain->ResumePrepared(Wait.Thread, [&](lua_State* Thread) -> int {
                    lua_pushstring(Thread, Error.utf8().get_data()); return 1;
                }, true);
            }
        }
        GLUnreference(nullptr, Wait.Reference);
    }
    for (const auto& Domain : Domains) if (Domain) Domain->Tick(Delta);
}
void GLDomainHost::Shutdown() {
    for (const auto& Domain : Domains) if (Domain) Domain->StopAdmission();
    if (DataStore) DataStore->CancelAll();
    if (Http) Http->Shutdown();
    GLDataStoreManager::DrainRetired();
    for (const auto& Domain : Domains) if (Domain) Domain->Shutdown();
    if (DataStore) DataStore->CancelAll();
    GLDataStoreManager::DrainRetired();
}
void GLDomainHost::_notification(int What) {
    if (What == NOTIFICATION_EXIT_TREE) Shutdown();
}
