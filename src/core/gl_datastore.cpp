#include "gl_datastore.h"
#include "gl_datastore_process.h"
#include "gl_datastore_protocol.h"
#include "gl_execution_domain.h"
#include "gl_net_bridge.h"
#include "lua.h"
#include "lualib.h"
#include <godot_cpp/classes/time.hpp>
#include <array>
#include <vector>
#ifndef _WIN32
#include <dlfcn.h>
#endif
namespace {
using namespace GLDataStoreProtocol;
unsigned Slots=0;
std::vector<std::unique_ptr<GLDataStoreProcess>> Retired;
void Reap() {
    Retired.erase(std::remove_if(Retired.begin(),Retired.end(),[](auto& Child) {
        if (!Child->Finished()) return false;
        --Slots; return true;
    }),Retired.end());
}
std::string WorkerPath() {
#ifdef _WIN32
    HMODULE Module=nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        reinterpret_cast<LPCWSTR>(&WorkerPath),&Module)) return {};
    wchar_t Path[32768];
    DWORD Length=GetModuleFileNameW(Module,Path,32768);
    if (!Length || Length>=32768) return {};
    return (std::filesystem::path(Path).parent_path()/L"godot_luau_store_worker.exe").u8string();
#else
    Dl_info Info{};
    if (!dladdr(reinterpret_cast<void*>(&WorkerPath),&Info) || !Info.dli_fname) return {};
    return (std::filesystem::u8path(Info.dli_fname).parent_path()/"godot_luau_store_worker").u8string();
#endif
}
const char* Message(Status Code) {
    switch (Code) {
        case Status::Busy: return "Lock contention";
        case Status::Unavailable: return "Storage/helper unavailable";
        case Status::Invalid: return "Invalid storage record or path";
        case Status::Denied: return "Permission denied";
        case Status::Limit: return "Storage resource limit exceeded";
        case Status::Durability: return "Durability failure before publication";
        case Status::Indeterminate: return "Indeterminate commit outcome; read latest state before retry";
        default: return "Commit/storage I/O failure before publication";
    }
}
uint64_t Now() { return godot::Time::get_singleton()->get_ticks_msec(); }
struct Work {
    lua_State* Thread=nullptr;
    lua_State* Anchor=nullptr;
    int Reference=LUA_NOREF;
    Operation Op=Operation::Read;
    std::unique_ptr<GLDataStoreProcess> Child;
    std::string Input,Output;
    size_t Sent=0;
    uint64_t Deadline=0;
    Result Answer;
    const char* Error=nullptr;
    bool Done=false,OwnSlot=false,Replied=false;
    ~Work() {
        if (Child) {
            Child->Cancel();
            if (!Child->Finished()) { Retired.push_back(std::move(Child)); OwnSlot=false; }
        }
        if (OwnSlot) --Slots;
    }
    void Fail(const char* Reason) {
        Error=Op!=Operation::Read && Sent==Input.size()?Message(Status::Indeterminate):Reason;
        Done=true;
    }
    void Advance(bool StartAllowed=true) {
        if (Replied) {
            // A valid reply does not hide a crashed helper or trailing native
            // diagnostics (including sanitizer failures during process exit).
            bool Finished=Child->Finished();
            char Extra[4096];
            if (Child->Receive(Extra,sizeof(Extra))) { Fail("Unexpected helper diagnostics"); return; }
            if (Finished) {
                if (Child->Exit!=0) Fail("Helper exited unsuccessfully"); else Done=true;
            } else if (Now()>=Deadline) Fail("Helper exit timeout");
            return;
        }
        if (Now()>=Deadline) { Fail("Operation timeout"); return; }
        if (!Child) {
            if (!StartAllowed) return;
            Child=std::make_unique<GLDataStoreProcess>();
            std::string Path=WorkerPath();
            if (Path.empty() || !Child->Start(Path)) { Error=Message(Status::Unavailable); Done=true; return; }
        }
        size_t Budget=1024*1024;
        while (Sent<Input.size() && Budget) {
            size_t Count=Child->Send(Input.data()+Sent,std::min({size_t(65536),Budget,Input.size()-Sent}));
            if (!Count) break;
            Sent+=Count; Budget-=Count;
        }
        Budget=1024*1024;
        bool Empty=false;
        while (Budget) {
            std::array<char,65536> Bytes;
            size_t Count=Child->Receive(Bytes.data(),std::min(Bytes.size(),Budget));
            if (!Count) { Empty=true; break; }
            if (Output.size()+Count>MaxData+24) { Fail("Invalid helper response"); return; }
            Output.append(Bytes.data(),Count); Budget-=Count;
        }
        if (Output.size()>=24) {
            uint32_t Code=Number(Output.data()+8),Found=Number(Output.data()+12),Size=Number(Output.data()+16);
            if (std::memcmp(Output.data(),Magic,8) || Code>uint32_t(Status::Indeterminate) || Found>1 || Size>MaxData || Number(Output.data()+20)!=0 || Output.size()>size_t(Size)+24) { Fail("Incompatible helper response"); return; }
            if (Output.size()==size_t(Size)+24) {
                Answer.Code=Status(Code); Answer.Exists=Found!=0; Answer.Data=Output.substr(24); Replied=true;
                if (Answer.Code!=Status::Ok && Answer.Code!=Status::Conflict) Error=Message(Answer.Code);
                return;
            }
        }
        if (Child->Failed || (Empty && Child->Finished())) Fail("Helper exited without completion");
    }
    int Marshal(lua_State* Thread) {
        if (Error) { lua_pushfstring(Thread,"[Persistence:DataStore] %s",Error); return 1; }
        if (Op==Operation::Read) {
            if (Answer.Exists) lua_pushlstring(Thread,Answer.Data.data(),Answer.Data.size()); else lua_pushnil(Thread);
            lua_pushboolean(Thread,Answer.Exists); return 2;
        }
        lua_pushboolean(Thread,Answer.Code==Status::Ok); return 1;
    }
};
}
struct GLDataStoreManager::State {
    std::vector<std::unique_ptr<Work>> Requests;
    size_t Peak=0;
};
GLDataStoreManager::GLDataStoreManager():Data(std::make_unique<State>()) {}
GLDataStoreManager::~GLDataStoreManager() { CancelAll(); }
int GLDataStoreManager::Begin(lua_State* Thread,GLExecutionDomain* Domain,const std::string& Root,const std::string& Leaf,int Selected,bool Exists,const std::string& Expected,const std::string& Value) {
    Reap();
    auto Owner=GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || Owner->Domain!=Domain || Domain->HasMemoryFailure() || Domain->GetMemoryAccount().Rejections || Domain->GetKind()!=GLDomainKind::Server || gl_net_role()==2)
        luaL_error(Thread,"[Persistence:DataStore] Capability unavailable");
    if (Domain->IsClosing() && !Domain->IsShutdownCallback(Thread)) luaL_error(Thread,"[Persistence:DataStore] Domain closing");
    if (Selected<0 || Selected>2 || Expected.size()>MaxData || Value.size()>MaxData) luaL_error(Thread,"[Persistence:DataStore] Invalid request bounds");
    size_t Count=0;
    for (const auto& Item:Data->Requests) if (Item->Anchor==GLGetOwnerState(Thread)) ++Count;
    if (Slots>=4 || Count>=2) luaL_error(Thread,"[Persistence:DataStore] Request admission limit exceeded");
    Request Input; Input.Root=Root; Input.Leaf=Leaf; Input.Expected=Expected; Input.Data=Value; Input.Op=Operation(Selected); Input.Exists=Exists;
    auto Item=std::make_unique<Work>();
    Item->Thread=Thread; Item->Anchor=GLGetOwnerState(Thread); Item->Op=Input.Op; Item->Input=Encode(Input);
    bool Synchronous=!lua_isyieldable(Thread) || Domain->IsClosing();
    Item->Deadline=Now()+(Synchronous?250:30000);
    if (Synchronous) {
        ++Slots; Item->OwnSlot=true;
        do { Item->Advance(); if (!Item->Done) std::this_thread::sleep_for(std::chrono::milliseconds(1)); } while (!Item->Done);
        Item->Marshal(Thread);
        if (Item->Error) lua_error(Thread);
        return Item->Op==Operation::Read?2:1;
    }
    Item->Reference=GLCaptureWait(Thread);
    ++Slots; Item->OwnSlot=true;
    Data->Requests.push_back(std::move(Item)); Data->Peak=std::max(Data->Peak,Data->Requests.size());
    lua_pushliteral(Thread,"__WAIT_DATASTORE__"); return lua_yield(Thread,1);
}
void GLDataStoreManager::Tick() {
    Reap();
    std::vector<int> Snapshot;
    for (const auto& Item:Data->Requests) Snapshot.push_back(Item->Reference);
    bool Started=false;
    for (int Reference:Snapshot) {
        auto Found=std::find_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& Item) { return Item->Reference==Reference; });
        if (Found==Data->Requests.end()) continue;
        auto& Item=**Found;
        auto Owner=GLReferenceAlive(Item.Anchor,Reference)?GLGetOwner(Item.Thread):nullptr;
        if (!Owner || !Owner->Alive || Owner->Domain->IsClosing() || Owner->Domain->HasMemoryFailure() || !Owner->Domain->CanResume(Item.Thread) || gl_net_role()==2) {
            GLUnreference(nullptr,Reference); Data->Requests.erase(Found); continue;
        }
        bool WasStarted=bool(Item.Child);
        Item.Advance(!Started);
        if (!WasStarted && Item.Child) Started=true;
        if (!Item.Done) continue;
        auto Complete=std::move(*Found); Data->Requests.erase(Found);
        if (Complete->Child && Complete->Child->Finished()) {
            Complete->Child.reset(); --Slots; Complete->OwnSlot=false;
        }
        // Normal completion relinquishes its wait before Lua can enter another.
        Owner->Domain->ResumePrepared(Complete->Thread,[&](lua_State* Thread) { return Complete->Marshal(Thread); },Complete->Error!=nullptr);
        GLUnreference(nullptr,Reference);
    }
}
void GLDataStoreManager::CancelOwner(lua_State* Anchor) {
    Data->Requests.erase(std::remove_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& Item) {
        if (Item->Anchor!=Anchor) return false; GLUnreference(nullptr,Item->Reference); return true;
    }),Data->Requests.end()); Reap();
}
void GLDataStoreManager::CancelThread(lua_State* Thread) {
    Data->Requests.erase(std::remove_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& Item) {
        if (Item->Thread!=Thread) return false; GLUnreference(nullptr,Item->Reference); return true;
    }),Data->Requests.end()); Reap();
}
bool GLDataStoreManager::Interrupt(lua_State* Thread) {
    bool Pending=std::any_of(Data->Requests.begin(),Data->Requests.end(),[&](const auto& Item) { return Item->Thread==Thread; });
    if (Pending) CancelThread(Thread);
    return Pending;
}
void GLDataStoreManager::CancelAll() {
    for (const auto& Item:Data->Requests) GLUnreference(nullptr,Item->Reference);
    Data->Requests.clear(); Reap();
}
size_t GLDataStoreManager::Pending() const { return Data->Requests.size(); }
size_t GLDataStoreManager::Peak() const { return Data->Peak; }
void GLDataStoreManager::DrainRetired() {
    for (auto& Child:Retired) Child->Cancel();
    auto Deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(50);
    do { Reap(); if (!Retired.empty()) std::this_thread::sleep_for(std::chrono::milliseconds(1)); } while (!Retired.empty() && std::chrono::steady_clock::now()<Deadline);
}
void GLDataStoreManager::StopAll() {
    DrainRetired();
    // No child executes extension code or owns Lua state; OS termination may
    // outlast its request on a failed device. There is never an unbounded join.
    Retired.clear(); Slots=0;
}
