#include "gl_execution_domain.h"
#include "gl_storage.h"
#include "gl_http_policy.h"
#include "gl_stackguard.h"
#include <cstdio>
#include <functional>
#include <limits>
#include <stdexcept>
#include <thread>
#include <unordered_map>
#include <fstream>
#include <atomic>
#include <cstring>
#ifdef _WIN32
#include <winioctl.h>
#endif
#ifdef _WIN32
#include <windows.h>
#endif

namespace {
void Check(bool Condition, const char* Message) {
    if (!Condition) throw std::runtime_error(Message);
}
struct StorageFixture {
    std::filesystem::path Base,Root,Outside;
    StorageFixture() {
        auto Parent=std::filesystem::absolute(std::filesystem::current_path());
        Base=Parent/("gl003-test-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
        Root=Base/"allowed"; Outside=Base/"outside";
        std::filesystem::create_directories(Root); std::filesystem::create_directory(Outside);
        std::ofstream(Outside/"ds_race.json")<<"sentinel";
    }
    ~StorageFixture() {
        // Only this named disposable test subtree is recursively removed.
        if (Base.parent_path()==std::filesystem::absolute(std::filesystem::current_path())) {
            std::error_code Error; std::filesystem::remove_all(Base,Error);
        }
    }
#ifdef _WIN32
    static bool Tag(HANDLE Handle,const std::filesystem::path& Target,bool Set) {
        struct Mount { DWORD Tag; WORD Length,Reserved,SubOffset,SubLength,PrintOffset,PrintLength; wchar_t Paths[2048]; } Data{};
        Data.Tag=IO_REPARSE_TAG_MOUNT_POINT;
        if (Set) {
            std::wstring Substitute=L"\\??\\"+Target.native(), Print=Target.native();
            if (Substitute.size()+Print.size()+2>2048) return false;
            Data.SubLength=WORD(Substitute.size()*2); Data.PrintOffset=Data.SubLength+2;
            Data.PrintLength=WORD(Print.size()*2); Data.Length=WORD(8+Data.PrintOffset+Data.PrintLength+2);
            std::memcpy(Data.Paths,Substitute.c_str(),Data.SubLength);
            std::memcpy(reinterpret_cast<char*>(Data.Paths)+Data.PrintOffset,Print.c_str(),Data.PrintLength);
        }
        DWORD Written=0;
        return DeviceIoControl(Handle,Set?FSCTL_SET_REPARSE_POINT:FSCTL_DELETE_REPARSE_POINT,&Data,Set?8+Data.Length:8,nullptr,0,&Written,nullptr)!=0;
    }
    static HANDLE DirectoryHandle(const std::filesystem::path& Path) {
        return CreateFileW(Path.c_str(),GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OPEN_REPARSE_POINT,nullptr);
    }
#endif
};
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
        if (!Domain.Execute(Owner, Source, "=Script" + std::to_string(Identity)))
            throw std::runtime_error(Errors.empty() ? "Script failed to start/execute" : Errors.back());
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

static int LimitCase(const std::string& Name) {
    GLDomainLimits Limits;
    Limits.ResumeMilliseconds = 10;
    if (Name == "cross-time" || Name == "cross-reentry") Limits.ResumeMilliseconds = 50;
    if (Name == "cross-count") { Limits.ResumeMilliseconds=0; Limits.MaxSafepoints=32; }
    if (Name == "cross-memory") { Limits.ResumeMilliseconds=0; Limits.MemoryBytes=512*1024; }
    if (Name == "memory-catch") { Limits.ResumeMilliseconds = 0; Limits.MemoryBytes = 512*1024; }
    if (Name == "finite-exceeded") { Limits.ResumeMilliseconds = 1000; Limits.MaxSafepoints = 32; }
    GLExecutionDomain Domain(GLDomainKind::Server, Limits);
    std::vector<std::string> Errors;
    Domain.SetErrorHandler([&](lua_State*, const std::string& Error) { Errors.push_back(Error); });
    auto Owner = Domain.CreateOwner(1);
    Check(Domain.Execute(Owner, "shared.Callback = function() while true do end end; task.defer(function() shared.CancelledRan = true end)", "=Preparation"), "Preparation failed");
    lua_getglobal(Owner->Anchor, "shared"); lua_getfield(Owner->Anchor, -1, "Callback");
    int Reference = GLReference(Owner->Anchor, -1); lua_pop(Owner->Anchor, 2);
    bool Result = false;
    if (Name == "cross-time" || Name == "cross-count" || Name == "cross-reentry" || Name == "cross-memory") {
        GLDomainLimits ChildLimits; ChildLimits.ResumeMilliseconds=0; ChildLimits.MaxSafepoints=0;
        std::vector<std::string> ChildErrors;
        GLExecutionDomain Child(GLDomainKind::Client,ChildLimits);
        Child.SetErrorHandler([&](lua_State*,const std::string& Error){ ChildErrors.push_back(Error); });
        lua_pushinteger(Child.GetState(),Reference);
        lua_pushcclosure(Child.GetState(),[](lua_State* Thread)->int {
            GLDispatch(lua_tointeger(Thread,lua_upvalueindex(1)),[](lua_State*)->int { return 0; });
            return 0;
        },"CrossDomainBounce",1); lua_setglobal(Child.GetState(),"Bounce");
        auto ChildOwner=Child.CreateOwner(10);
        Result=Domain.RunNative([&](lua_State* Parent) {
            if (Name=="cross-memory") {
                int Status=lua_cpcall(Parent,[](lua_State* Thread)->int { lua_newuserdata(Thread,1024*1024); return 0; },nullptr);
                Check(Status==LUA_ERRMEM,"Parent allocation rejection was not exercised"); lua_pop(Parent,1);
            }
            Child.Execute(ChildOwner,Name=="cross-reentry" ? "shared.Entered=true; Bounce()" :
                "shared.Entered=true; while true do end","=CrossDomain");
        });
        Check(!Result && !ChildOwner->Alive && !ChildErrors.empty(),"Child domain bypassed active ancestor budget");
        lua_getglobal(ChildOwner->Anchor,"shared"); lua_getfield(ChildOwner->Anchor,-1,"Entered");
        Check(static_cast<bool>(lua_toboolean(ChildOwner->Anchor,-1))==(Name!="cross-memory"),
            "Cross-domain execution did not respect the active ancestor's allocation state"); lua_pop(ChildOwner->Anchor,2);
        Check(Child.Execute(Child.CreateOwner(11),"shared.Survived=true","=ChildSurvivor"),"Unrelated child-domain owner did not survive");
    } else if (Name == "callback" || Name == "shutdown" || Name == "marshal" || Name == "invoke" || Name == "native") {
        if (Name == "shutdown") { Domain.AddCloseCallback(Owner->Anchor, Reference); Domain.Shutdown(); }
        else if (Name == "native") {
            Result = Domain.RunNative([&](lua_State* Thread) {
                lua_rawgeti(Thread, LUA_REGISTRYINDEX, Reference); lua_call(Thread, 0, 0);
            });
        } else if (Name == "invoke") {
            Result = Domain.Invoke(Reference, [](lua_State*) -> int { return 0; }, [](lua_State*) {}) == LUA_OK;
        } else if (Name == "marshal") {
            Result = GLDispatch(Reference, [&](lua_State* Thread) -> int {
                lua_rawgeti(Thread, LUA_REGISTRYINDEX, Reference);
                lua_call(Thread, 0, 0);
                return 0;
            }) == LUA_OK;
        } else {
            Result = GLDispatch(Reference, [](lua_State*) -> int { return 0; }) == LUA_OK;
        }
    } else {
        std::string Source = "while true do end";
        if (Name == "nested") Source = "coroutine.resume(coroutine.create(function() while true do end end)); while true do end";
        if (Name == "pcall") Source = "while true do pcall(function() while true do end end) end";
        if (Name == "memory-catch") Source = "while true do pcall(function() return table.create(1024*1024) end) end";
        if (Name == "finite-exceeded") Source = "local Sum=0; for Index=1,1000000 do Sum+=Index end; shared.Sum=Sum";
        if (Name == "finite-within") Source = "shared.Finite=123";
        if (Name == "module") {
            Domain.SetModuleResolver([](lua_State*, int, GLModuleSource& Source) { Source={100,"while true do end","=BudgetModule"}; return true; });
            Source = "return require(100)";
        }
        Result = Domain.Execute(Owner, Source, "=BudgetCase");
    }
    if (Name == "finite-within") Check(Result && Errors.empty() && Owner->Alive, "Valid computation rejected");
    else if (Name == "cross-memory") {
        Check(!Result && Domain.HasMemoryFailure() && !Owner->Alive && !GLReferenceState(Reference),
            "Caught parent OOM escaped through a child domain or retained stale work");
    } else if (Name == "cross-time" || Name == "cross-count" || Name == "cross-reentry") {
        Check(!Result && !Errors.empty() && !Domain.CanRunNative(),"Cross-domain ancestor did not receive failure disposition");
        Check(Owner->Alive==(Name!="cross-reentry"),"Cross-domain cancellation affected wrong registering owner");
    } else if (Name == "memory-catch") {
        Check(!Result && !Errors.empty() && !Owner->Alive && Domain.HasMemoryFailure() && Domain.IsClosing(),
            "Caught allocation failure bypassed retirement with elapsed policy disabled");
        Check(Errors.front().find("[Runtime:Memory]")!=std::string::npos && !GLReferenceState(Reference),
            "Quota failure lost category or retained stale callbacks");
    } else if (Name == "native") {
        Check(!Result && !Errors.empty() && !Domain.CanRunNative() && Owner->Alive,
            "Host operation failure did not retire its bootstrap owner independently");
        bool Reentered = false;
        Check(!Domain.RunNative([&](lua_State*) { Reentered = true; }) && !Reentered,
            "Failed host operation owner was revived");
        GLExecutionDomain Reentry(GLDomainKind::Server, Limits);
        auto Target = Reentry.CreateOwner(4);
        Check(Reentry.Execute(Target,"shared.Callback=function() shared.Entered=true end","=ReentrySetup"),"Reentry setup failed");
        lua_getglobal(Target->Anchor,"shared"); lua_getfield(Target->Anchor,-1,"Callback");
        int Callback=GLReference(Target->Anchor,-1); lua_pop(Target->Anchor,2);
        Check(!Reentry.RunNative([&](lua_State*) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            GLDispatch(Callback,[](lua_State*) -> int { return 0; });
        }),"Expired native operation was accepted");
        lua_getglobal(Target->Anchor,"shared"); lua_getfield(Target->Anchor,-1,"Entered");
        Check(lua_isnil(Target->Anchor,-1),"Expired reentry executed gameplay before checking inherited deadline");
        lua_pop(Target->Anchor,2);
    } else {
        Check(!Result && !Errors.empty() && !Owner->Alive, "Resource interruption did not terminate owner");
        Check(Errors.front().find("[Runtime:Execution]") != std::string::npos, "Missing resource error category");
        Check(GLReferenceState(Reference) == nullptr, "Interrupted owner retained callback reference");
    }
    if (Name == "invoke") {
        GLExecutionDomain Copy(GLDomainKind::Client, Limits);
        auto Target = Copy.CreateOwner(4);
        Check(Copy.Execute(Target,"shared.Callback=function() return 1 end","=CopySetup"),"Copy setup failed");
        lua_getglobal(Target->Anchor,"shared"); lua_getfield(Target->Anchor,-1,"Callback");
        int Callback=GLReference(Target->Anchor,-1); lua_pop(Target->Anchor,2);
        Check(Copy.Invoke(Callback,[](lua_State*) -> int { return 0; },[](lua_State*) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        })==LUA_ERRRUN && !Target->Alive && !GLReferenceState(Callback),
            "Post-copy native deadline did not cancel the synchronous callback owner");
        Check(Copy.Execute(Copy.CreateOwner(5),"shared.Survived=true","=CopySurvivor"),
            "Post-copy deadline cancelled an unrelated owner");
    }
    if (Name != "shutdown" && Name != "memory-catch" && Name != "cross-memory") {
        Domain.Tick(0.02);
        auto Survivor = Domain.CreateOwner(2);
        std::string Source = Name == "module" ? "local Ok,Error=pcall(require,100); assert(not Ok and string.find(Error,'budget') or not Ok and string.find(Error,'deadline'))" :
            Name == "native" || Name == "cross-time" || Name == "cross-count" ? "assert(shared.CancelledRan==true)" : "assert(shared.CancelledRan==nil or shared.Finite==123)";
        Check(Domain.Execute(Survivor, Source, "=Survivor"), "Unrelated execution did not survive");
        Domain.Shutdown();
    }
    GLExecutionDomain Fresh(GLDomainKind::Client);
    Check(Fresh.Execute(Fresh.CreateOwner(3), "assert(shared.Callback==nil)", "=Fresh"), "Fresh domain initialization failed");
    std::printf("[Runtime:LimitTest] PASS %s\n", Name.c_str());
    return 0;
}

int main(int Arguments, char** Values) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#endif
    if (Arguments == 3 && std::string(Values[1]) == "--limit-case") {
        try { return LimitCase(Values[2]); }
        catch (const std::exception& Error) { std::fprintf(stderr,"[Runtime:LimitTest] FAIL %s\n",Error.what()); return 1; }
    }
    int Passed = 0, Failed = 0;
    auto Test = [&](const char* Name, const std::function<void()>& Body) {
        try { Body(); ++Passed; std::printf("[Runtime:Test] PASS %s\n", Name); }
        catch (const std::exception& Error) { ++Failed; std::printf("[Runtime:Test] FAIL %s: %s\n", Name, Error.what()); }
    };
    Test("VM allocator accounts growth shrink rejection and frees", [] {
        GLMemoryAccount Account;
        Account.Limit = 4096;
        void* Block = GLMemoryAccount::Allocate(&Account, nullptr, 0, 256);
        Check(Block && Account.Live == 256 && Account.Peak == 256, "Initial allocation not counted");
        Block = GLMemoryAccount::Allocate(&Account, Block, 256, 1024);
        Check(Block && Account.Live == 1024, "Growth not counted");
        void* Extra = GLMemoryAccount::Allocate(&Account, nullptr, 0, 3072);
        Check(Extra && Account.Live==4096 && !GLMemoryAccount::Allocate(&Account,nullptr,0,1),
            "Quota did not include allocations in other live blocks");
        GLMemoryAccount::Allocate(&Account,Extra,3072,0);
        Check(!GLMemoryAccount::Allocate(&Account, Block, 1024, 8192), "Quota did not reject growth");
        Check(Account.Live == 1024, "Rejected realloc changed accounting");
        Account.Limit = 1; // shrinking must remain possible after a reduced cap
        Block = GLMemoryAccount::Allocate(&Account, Block, 1024, 128);
        Check(Block && Account.Live == 128 && Account.Peak == 4096, "Shrink not counted");
        GLMemoryAccount::Allocate(&Account, Block, 128, 0);
        Check(Account.Live == 0 && !Account.InvalidAccounting, "Free accounting invalid");
    });
    Test("VM allocator rejects invalid sizes and arithmetic overflow", [] {
        GLMemoryAccount Account;
        Check(!GLMemoryAccount::Allocate(&Account, nullptr, 1, 1) && Account.InvalidAccounting, "Invalid old size accepted");
        Account = {};
        Account.Live = (std::numeric_limits<size_t>::max)();
        Check(!GLMemoryAccount::Allocate(&Account, nullptr, 0, 1), "Accounting addition overflowed");
        Check(Account.Live == (std::numeric_limits<size_t>::max)(), "Overflow changed accounting");
    });
    Test("Actual VM allocation failure is protected and close releases accounting", [] {
        GLMemoryAccount Account;
        lua_State* State = lua_newstate(GLMemoryAccount::Allocate, &Account);
        Check(State && Account.Live > 0, "VM did not use accounting allocator");
        Account.Limit = Account.Live + 4096;
        int Status = lua_cpcall(State, [](lua_State* Thread) -> int {
            lua_newuserdata(Thread, 1024 * 1024);
            return 0;
        }, nullptr);
        Check(Status == LUA_ERRMEM && Account.Rejections > 0, "Expected protected quota failure");
        lua_close(State);
        Check(Account.Live == 0 && !Account.InvalidAccounting, "VM close did not free accounted allocations");
    });
    Test("Sandbox preserves custom typeof shared facades and function environments", [] {
        Fixture F;
        lua_pushcfunction(F.Domain.GetState(), [](lua_State* Thread) -> int {
            lua_pushstring(Thread, "CustomType"); return 1;
        }, "typeof"); lua_setglobal(F.Domain.GetState(), "typeof");
        F.Sources[100] = "assert(typeof({}) == 'CustomType'); shared.Module = {}; return shared.Module";
        F.Run(1, "assert(io==nil and package==nil and dofile==nil and loadfile==nil and debug.getregistry==nil and os.execute==nil); assert(typeof({}) == 'CustomType'); assert(require(100) == shared.Module); _G.Mutable = 42; shared.Mutable = 43; assert(not pcall(function() table.insert = nil end)); local M = getmetatable(getfenv(1)); assert(not pcall(function() M.__index=nil end)); local F = function() return Value end; setfenv(F, {Value=12}); assert(F()==12)");
        Check(F.Domain.IsSandboxed(), "Gameplay admission did not seal root libraries");
        F.Run(2, "assert(_G.Mutable==42 and shared.Mutable==43); assert(typeof({})=='CustomType'); table.insert({}, 1)");
        F.NoErrors();
    });
    Test("Task quota rejects admission before creating extra coroutine and recovers after tick", [] {
        GLDomainLimits Limits; Limits.Tasks = 8;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        auto Owner = Domain.CreateOwner(1);
        Check(Domain.Execute(Owner, "for Index=1,7 do task.defer(function() end) end; local Ok, Error=pcall(task.defer,function() end); assert(not Ok and string.find(Error,'admission'))", "=TaskQuota"), "Task admission failure escaped protection");
        Check(Domain.GetTaskCount()==8, "Rejected task grew retained scheduler records");
        Domain.Tick(0.02); Domain.Tick(0.02);
        Check(Domain.GetTaskCount()==0, "Completed tasks did not release quota");
        Check(Domain.Execute(Owner, "task.defer(function() shared.Recovered=true end)", "=TaskRecovery"), "Task admission did not recover");
        Domain.Tick(0.02);
    });
    Test("Reference quota and owner quota reject without replacing valid work", [] {
        GLDomainLimits Limits; Limits.References=4; Limits.Owners=2;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        auto Owner = Domain.CreateOwner(1);
        Check(Domain.Execute(Owner, "for Index=1,4 do _GLBindCallback(function() end) end; assert(not pcall(_GLBindCallback,function() end))", "=ReferenceQuota"), "Reference quota escaped Lua protection");
        Check(Domain.GetReferenceCount()==4, "Reference quota was bypassed");
        Check(Domain.CreateOwner(2) && !Domain.CreateOwner(3), "Owner quota was bypassed");
        Check(!Domain.CreateOwner(1) && Owner->Alive && Domain.FindOwner(1)==Owner,
            "Rejected replacement cancelled a valid execution owner");
        Domain.CancelOwner(Owner);
        Check(Domain.GetReferenceCount()==0, "Cancellation did not release reference quota");
        GLDomainLimits ThreadLimits; ThreadLimits.Coroutines=2;
        GLExecutionDomain ThreadDomain(GLDomainKind::Client,ThreadLimits);
        auto Previous=ThreadDomain.CreateOwner(1);
        Check(Previous && !ThreadDomain.CreateOwner(1) && Previous->Alive && ThreadDomain.FindOwner(1)==Previous,
            "Coroutine admission failure cancelled a valid previous owner");
    });
    Test("Live coroutine quota includes untracked manual coroutines and frees on collection", [] {
        GLDomainLimits Limits; Limits.Coroutines=12;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        auto Owner = Domain.CreateOwner(1);
        Check(Domain.Execute(Owner, "shared.Threads={}; for Index=1,9 do table.insert(shared.Threads,coroutine.create(function() end)) end; assert(not pcall(coroutine.create,function() end)); shared.Threads=nil", "=CoroutineQuota"), "Coroutine admission error escaped Lua protection");
        Check(Domain.GetCoroutineCount()==12, "Manual coroutine accounting is incomplete");
        Domain.Tick(0.02); lua_gc(Domain.GetState(), LUA_GCCOLLECT, 0);
        Check(Domain.GetCoroutineCount()==2, "Collected coroutines retained admission quota");
        Check(Domain.Execute(Owner, "assert(coroutine.create(function() end))", "=CoroutineRecovery"), "Coroutine quota did not recover");
    });
    Test("Memory quota retirement covers caught Lua failure and fresh domain recovery", [] {
        for (int Index=0; Index<4; ++Index) {
            GLDomainLimits Limits; Limits.MemoryBytes=512*1024;
            GLExecutionDomain Domain(GLDomainKind::Server, Limits);
            auto Owner=Domain.CreateOwner(1);
            Check(Owner && Domain.Execute(Owner, "shared.Small=table.create(1000); shared.Small=nil", "=WithinMemory"), "Within-quota allocation failed");
            size_t BeforeCollection=Domain.GetMemoryAccount().Live;
            lua_gc(Domain.GetState(), LUA_GCCOLLECT, 0);
            size_t Before=Domain.GetMemoryAccount().Live;
            Check(Before<BeforeCollection,"Garbage collection did not release allocator-accounted memory");
            const char* Source = Index%2 ? "pcall(function() shared.TooLarge={}; for Index=1,128 do table.insert(shared.TooLarge,table.create(1024)) end end)" :
                "pcall(function() shared.TooLarge=table.create(1024*1024) end)";
            Check(!Domain.Execute(Owner, Source, "=MemoryQuota"), "Caught OOM bypassed terminal domain policy");
            Check(Domain.HasMemoryFailure() && Domain.IsClosing() && !Owner->Alive && !Domain.CreateOwner(2), "Exhausted domain remained available");
            Check(Domain.GetMemoryAccount().Live <= Limits.MemoryBytes && Domain.GetMemoryAccount().Peak <= Limits.MemoryBytes && Before>0, "VM exceeded allocator quota");
            Domain.Shutdown(); Domain.Tick(0.02);
            GLExecutionDomain Fresh(GLDomainKind::Client, Limits);
            Check(Fresh.Execute(Fresh.CreateOwner(1), "assert(shared.TooLarge==nil)", "=FreshMemory"), "Explicit fresh domain did not recover");
        }
    });
    Test("Memory failure during callback marshalling retires without unprotected unwind", [] {
        GLDomainLimits Limits; Limits.MemoryBytes=512*1024;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        auto Owner=Domain.CreateOwner(1);
        Check(Domain.Execute(Owner,"function Callback() error('must not execute') end","=CallbackSetup"),"Setup failed");
        lua_getglobal(Owner->Anchor,"Callback"); int Reference=GLReference(Owner->Anchor,-1); lua_pop(Owner->Anchor,1);
        Check(GLDispatch(Reference,[](lua_State* Thread)->int { lua_newuserdata(Thread,1024*1024); return 1; })==LUA_ERRMEM,"Marshaller OOM was not contained");
        Check(Domain.HasMemoryFailure() && !Owner->Alive && !GLReferenceState(Reference),"Marshaller failure retained old callbacks");
        GLExecutionDomain SourceDomain(GLDomainKind::Server,Limits), CallerDomain(GLDomainKind::Client);
        auto SourceOwner=SourceDomain.CreateOwner(1);
        Check(SourceDomain.Execute(SourceOwner,"function Callback() return 42 end","=ReturnSetup"),"Return setup failed");
        lua_getglobal(SourceOwner->Anchor,"Callback"); int SourceReference=GLReference(SourceOwner->Anchor,-1); lua_pop(SourceOwner->Anchor,1);
        Check(!CallerDomain.RunNative([&](lua_State* Caller) {
            SourceDomain.Invoke(SourceReference,[](lua_State*)->int { return 0; },[&](lua_State* Source) {
                int Status=lua_cpcall(Source,[](lua_State* Thread)->int { lua_newuserdata(Thread,1024*1024); return 0; },nullptr);
                Check(Status==LUA_ERRMEM,"Protected source allocation unexpectedly succeeded"); lua_pop(Source,1);
                luaL_error(Caller,"[Runtime:Callback] Destination rejected return copy");
            });
        }),"Cross-domain destination error escaped protection");
        Check(SourceDomain.HasMemoryFailure() && !CallerDomain.HasMemoryFailure() && CallerDomain.CanRunNative(),
            "Source rejection was lost while unwinding a destination error or retired the wrong domain");
    });
    Test("Insufficient VM bootstrap quota produces a controlled unavailable domain", [] {
        GLDomainLimits Limits; Limits.MemoryBytes=4096;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        Check(Domain.IsClosing() && Domain.HasMemoryFailure() && Domain.GetFailure() && !Domain.CreateOwner(1),"Tiny bootstrap quota did not retire domain");
        Check(std::string(Domain.GetFailure()).find("quota")!=std::string::npos,
            "Bootstrap quota rejection was reported as an underlying host allocation failure");
        Domain.Shutdown();
        GLDomainLimits HostLimits; HostLimits.Coroutines=1;
        GLExecutionDomain FailedHost(GLDomainKind::Client,HostLimits);
        bool Caught=false;
        Check(!FailedHost.InitializeHost([&](lua_State* Thread) {
            int Status=lua_cpcall(Thread,[](lua_State* Current)->int { lua_newthread(Current); return 0; },nullptr);
            Caught=Status==LUA_ERRRUN;
            if (Status!=LUA_OK) lua_pop(Thread,1);
        }) && Caught && FailedHost.IsClosing() && !FailedHost.HasMemoryFailure() && FailedHost.GetAdmissionRejections()==1,
            "Caught bootstrap admission failure left a partially initialized domain available");
    });
    Test("Shared module allocations use the domain quota and retire all owners on exhaustion", [] {
        GLDomainLimits Limits; Limits.MemoryBytes=512*1024;
        GLExecutionDomain Domain(GLDomainKind::Server, Limits);
        Domain.SetModuleResolver([](lua_State*, int, GLModuleSource& Source) {
            Source={100,"return table.create(1024*1024)","=MemoryModule"}; return true;
        });
        auto Owner=Domain.CreateOwner(1);
        auto Other=Domain.CreateOwner(2);
        Check(!Domain.Execute(Owner,"pcall(require,100)","=SharedQuota"),"Module bypassed domain quota");
        Check(Domain.HasMemoryFailure() && !Owner->Alive && !Other->Alive,"Module quota failure did not retire shared VM");
        Check(Domain.GetMemoryAccount().Peak<=Limits.MemoryBytes,"Module allocation exceeded hard quota");
    });
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
        bool NumericErrorPreserved = false;
        F.Domain.SetErrorHandler([&](lua_State* Thread, const std::string& Error) {
            NumericErrorPreserved = lua_type(Thread, -1) == LUA_TNUMBER;
            F.Errors.push_back(Error);
        });
        Check(!F.Domain.Execute(Bad, "error(3.14159265, 0)", "=NumericError"), "Expected numeric error was accepted");
        Check(NumericErrorPreserved && F.Errors.back().find("non-string") != std::string::npos,
            "Error reporting allocated/coerced a numeric VM error outside protection");
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
        lua_pushcfunction(F.Domain.GetState(),[](lua_State* Thread)->int {
            auto Owner=GLGetOwner(Thread);
            lua_pushboolean(Thread,Owner && Owner->Domain->IsShutdownCallback(Thread)); return 1;
        },"InShutdown"); lua_setglobal(F.Domain.GetState(),"InShutdown");
        F.Sources[100] = "return {Value = 12}";
        auto Owner = F.Run(1, "assert(not InShutdown()); require(100); function Close() assert(InShutdown()); shared.Closed = (shared.Closed or 0) + 1; assert(require(100).Value == 12); assert(not pcall(task.defer, function() end)) end");
        lua_getglobal(Owner->Anchor, "Close");
        int Reference = GLReference(Owner->Anchor, -1); lua_pop(Owner->Anchor, 1);
        F.Domain.AddCloseCallback(Owner->Anchor, Reference);
        F.Domain.StopAdmission(); F.Domain.Shutdown(); F.Domain.Shutdown();
        Check(!F.Domain.IsShutdownCallback(Owner->Anchor),"Retired anchor retained shutdown authority");
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
    Test("Filesystem native operation grants and bounded storage",[] {
        StorageFixture F;
        GLStorage Store(F.Root.u8string(),GLStorage::Read|GLStorage::Write|GLStorage::Delete|GLStorage::List);
        std::string Data;
        Check(Store.WriteFile("ds_unicode_\xe9\x9b\xaa.json","payload")==GLStorage::Error::None,"Authorized Unicode write failed");
        Check(Store.ReadFile("ds_unicode_\xe9\x9b\xaa.json",Data)==GLStorage::Error::None && Data=="payload","Authorized read failed");
        GLStorage ReadOnly(F.Root.u8string(),GLStorage::Read);
        std::vector<std::string> Names;
        Check(ReadOnly.WriteFile("ds_unicode_\xe9\x9b\xaa.json","changed")==GLStorage::Error::Denied,"Read authority granted write");
        Check(ReadOnly.Remove("ds_unicode_\xe9\x9b\xaa.json")==GLStorage::Error::Denied,"Read authority granted delete");
        Check(ReadOnly.Names("ds_",Names)==GLStorage::Error::Denied,"Read authority granted enumeration");
        Check(Store.WriteFile("ds_unicode_\xe9\x9b\xaa.json",std::string(GLStorage::MaxBytes+1,'x'))==GLStorage::Error::Limit,"Write bound not enforced");
        Check(Store.ReadFile("ds_unicode_\xe9\x9b\xaa.json",Data)==GLStorage::Error::None && Data=="payload","Rejected write mutated data");
        Check(Store.Remove("ds_unicode_\xe9\x9b\xaa.json")==GLStorage::Error::None,"Authorized deletion failed");
        Check(Store.ReadFile("ds_missing.json",Data)==GLStorage::Error::Missing,"Missing file disposition lost");
        Check(Store.WriteFile("ds_capacity.json",std::string(GLStorage::MaxBytes,'y'))==GLStorage::Error::None,"Valid maximum payload rejected");
        Check(Store.ReadFile("ds_capacity.json",Data)==GLStorage::Error::None && Data.size()==GLStorage::MaxBytes && Data.front()=='y' && Data.back()=='y',"Maximum payload did not round trip");
        for (int Index=0;Index<1024;++Index)
            Check(Store.WriteFile("ds_scale_"+std::to_string(Index)+".json","{}")==GLStorage::Error::None,"Representative collection write rejected");
        Check(Store.Names("ds_scale_",Names)==GLStorage::Error::None && Names.size()==1024,"Representative collection enumeration failed");
    });
    Test("Filesystem hostile names and final links reject without mutation",[] {
        StorageFixture F;
        GLStorage Store(F.Root.u8string(),GLStorage::Read|GLStorage::Write|GLStorage::Delete|GLStorage::List);
        std::string Data;
        std::vector<std::string> Bad={"","/ds_abs.json","../outside/ds_race.json","ds_a/../../ds_race.json","ds_a\\..\\ds_race.json","C:ds_x.json","C:\\ds_x.json","\\\\server\\share\\ds_x.json","\\\\?\\C:\\ds_x.json","ds_a.json:stream","ds_x.json.","ds_x.json ","other.json",std::string("ds_a\0b.json",11),"ds_\xc0\xaf.json","ds_\xed\xa0\x80.json","ds_\xf4\x90\x80\x80.json",std::string(250,'x')+".json"};
        auto Time=std::filesystem::last_write_time(F.Outside/"ds_race.json");
        for (const auto& Name:Bad) {
            Check(Store.WriteFile(Name,"bad")!=GLStorage::Error::None,"Hostile write allowed");
            Check(Store.ReadFile(Name,Data)!=GLStorage::Error::None,"Hostile read allowed");
            Check(Store.Remove(Name)!=GLStorage::Error::None,"Hostile delete allowed");
        }
        std::filesystem::create_hard_link(F.Outside/"ds_race.json",F.Root/"ds_alias.json");
        Check(Store.WriteFile("ds_alias.json","bad")==GLStorage::Error::InvalidPath,"Hard-link write allowed");
        Check(Store.ReadFile("ds_alias.json",Data)==GLStorage::Error::InvalidPath,"Hard-link read allowed");
        Check(Store.Remove("ds_alias.json")==GLStorage::Error::InvalidPath,"Hard-link deletion allowed");
#ifdef __linux__
        std::filesystem::create_symlink(F.Outside/"ds_race.json",F.Root/"ds_link.json");
        Check(Store.WriteFile("ds_link.json","bad")!=GLStorage::Error::None,"Symlink write escaped");
        Check(Store.ReadFile("ds_link.json",Data)!=GLStorage::Error::None,"Symlink read escaped");
        Check(mkfifo((F.Root/"ds_pipe.json").c_str(),0600)==0,"FIFO preparation failed");
        Check(Store.ReadFile("ds_pipe.json",Data)==GLStorage::Error::InvalidPath,"Special file accepted");
#endif
        std::ifstream File(F.Outside/"ds_race.json"); File>>Data;
        Check(Data=="sentinel" && Time==std::filesystem::last_write_time(F.Outside/"ds_race.json"),"Protected sentinel changed");
    });
    Test("Filesystem intermediate links and replacement races stay confined",[] {
        StorageFixture F;
        auto Alias=F.Base/"alias";
#ifdef _WIN32
        std::filesystem::create_directory(Alias);
        HANDLE Writer=StorageFixture::DirectoryHandle(Alias);
        struct HandleGuard { HANDLE Value; ~HandleGuard() { if (Value!=INVALID_HANDLE_VALUE) CloseHandle(Value); } } Guard{Writer};
        Check(Writer!=INVALID_HANDLE_VALUE,"Junction handle unavailable");
        bool Tagged=StorageFixture::Tag(Writer,F.Outside,true);
        Check(Tagged,"Junction preparation failed");
#else
        std::filesystem::create_directory_symlink(F.Outside,Alias);
#endif
        GLStorage Store(Alias.u8string(),GLStorage::Read|GLStorage::Write|GLStorage::Delete|GLStorage::List);
        std::string Data;
        Check(Store.ReadFile("ds_race.json",Data)!=GLStorage::Error::None,"Intermediate link read escaped");
        Check(Store.WriteFile("ds_race.json","bad")!=GLStorage::Error::None,"Intermediate link write escaped");
        std::atomic<bool> Stop{false};
        std::thread Peer([&] {
            while (!Stop) {
#ifdef _WIN32
                StorageFixture::Tag(Writer,F.Outside,false);
                GLStorage(Alias.u8string(),GLStorage::Delete).Remove("ds_race.json");
                StorageFixture::Tag(Writer,F.Outside,true);
#else
                std::error_code Error;
                std::filesystem::remove(Alias,Error);
                std::filesystem::create_directory_symlink(F.Outside,Alias,Error);
#endif
            }
        });
        bool Escaped=false;
        for (int Index=0;Index<200;++Index) {
            Data.clear();
            if (Store.ReadFile("ds_race.json",Data)==GLStorage::Error::None && Data=="sentinel") Escaped=true;
            Store.WriteFile("ds_race.json","bad");
        }
        Stop=true; Peer.join();
#ifdef _WIN32
        StorageFixture::Tag(Writer,F.Outside,false);
#endif
        Check(!Escaped,"Concurrent reparse/link replacement escaped");
        std::ifstream File(F.Outside/"ds_race.json"); File>>Data;
        Check(Data=="sentinel","Concurrent replacement modified outside sentinel");
    });
    Test("HTTP production origin parsing separates authority and target",[] {
        GLHttpPolicy::Url Url;
        Check(GLHttpPolicy::Parse("https://Example.COM:0443?value=a%20b",Url),"Valid exact origin rejected");
        Check(Url.Origin=="https://example.com:443" && Url.Target=="/?value=a%20b","Origin or query-only target misparsed");
        Check(GLHttpPolicy::Parse("http://127.0.0.1:7350/echo",Url) && Url.Port==7350 && !Url.Tls,"Explicit local origin rejected");
        for (const std::string& Value:std::vector<std::string>{"", "file:///tmp/x", "http://a@b/", "http://a:0/", "http://a:65536/", "http://a:+80/", "http://a:80:90/", "http://[::1]/", "http://a./", "http://a..b/", "http://-a/", "http://a-.b/", "http://a%2eb/", "http://a/#fragment", "http://a/\\x", "http://a/\r\nx", "http://a/%zz", std::string("http://a/\0tail",14), std::string(4097,'x')})
            Check(!GLHttpPolicy::Parse(Value,Url),"Invalid or ambiguous URL admitted");
        Check(GLHttpPolicy::Parse("https://allowed.test:444/path",Url) && Url.Origin!="https://allowed.test:443","Port omitted from authority");
        Check(GLHttpPolicy::Parse("http://allowed.test/path",Url) && Url.Origin!="https://allowed.test:443","Scheme omitted from authority");
    });
    Test("HTTP production request headers reject injection and framing control",[] {
        Check(GLHttpPolicy::Header("X-Token","value\tvalue") && GLHttpPolicy::Header("Content-Type","application/json"),"Normal header rejected");
        for (const char* Name:{"Host","CONTENT-LENGTH","transfer-encoding","Accept-Encoding","Connection","Proxy-Authorization","Upgrade","Expect","TE"})
            Check(!GLHttpPolicy::Header(Name,"value"),"Caller-controlled framing accepted");
        for (const auto& Entry:std::vector<std::pair<std::string,std::string>>{{"X\r\nY","value"},{"Bad:Name","value"},{"X","value\r\nInjected: yes"},{"X",std::string("a\0b",3)},{std::string(129,'x'),"value"},{"X",std::string(4097,'x')}})
            Check(!GLHttpPolicy::Header(Entry.first,Entry.second),"Invalid header accepted");
        for (const char* Method:{"GET","POST","PUT","PATCH","DELETE","HEAD","OPTIONS"}) Check(GLHttpPolicy::Method(Method),"Supported method rejected");
        Check(!GLHttpPolicy::Method("CONNECT") && !GLHttpPolicy::Method("TRACE") && !GLHttpPolicy::Method("unknown"),"Unsupported method silently allowed");
    });
    Test("HTTP production wire budgets bound cumulative and per tick work",[] {
        GLHttpPolicy::WireBudget Budget;
        Check(Budget.ConsumeWire(65536) && Budget.Read==0,"Normal read allowance lost");
        Budget.Tick();
        Check(Budget.Read==65536 && Budget.Wire==65536,"Tick reset cumulative wire accounting");
        for (size_t Index=1;Index<GLHttpPolicy::MaxWire/65536;++Index) { Check(Budget.ConsumeWire(65536),"Valid wire allowance rejected"); Budget.Tick(); }
        Check(!Budget.ConsumeWire(1) && Budget.Wire==GLHttpPolicy::MaxWire,"Oversized wire mutated accounting");
        GLHttpPolicy::WireBudget Headers;
        for (size_t Index=0;Index<GLHttpPolicy::MaxHeaderBytes/2048;++Index) { Check(Headers.ConsumeHeader(2048),"Valid header allowance rejected"); Headers.Tick(); }
        Check(!Headers.ConsumeHeader(1) && Headers.Headers==GLHttpPolicy::MaxHeaderBytes,"Header bound or no-side-effect rejection failed");
    });
    Test("Native character authority observes synchronous domain and restores nesting", [] {
        Check(!GLExecutionDomain::IsClientExecution(), "Native engine execution misclassified");
        GLExecutionDomain Server(GLDomainKind::Server), Client(GLDomainKind::Client);
        Check(Client.RunNative([&](lua_State*) {
            Check(GLExecutionDomain::IsClientExecution(), "Client native call lost domain");
            Check(Server.RunNative([&](lua_State*) {
                Check(!GLExecutionDomain::IsClientExecution(), "Server callback inherited client authority");
            }), "Nested server callback failed");
            Check(GLExecutionDomain::IsClientExecution(), "Nested callback failed to restore client");
        }), "Client native call failed");
        Check(!GLExecutionDomain::IsClientExecution(), "Domain leaked beyond native return");
    });
    std::printf("[Runtime:Test] %d passed, %d failed\n", Passed, Failed);
    return Failed == 0 ? 0 : 1;
}
