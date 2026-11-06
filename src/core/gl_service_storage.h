#ifndef GL_SERVICE_STORAGE_H
#define GL_SERVICE_STORAGE_H

#include "gl_storage.h"
#include "gl_execution_domain.h"
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <new>
#include <cstring>

inline uint64_t GLStorageVmIdentity() { static uint64_t Next=0; return ++Next; }

struct GLServiceStorage {
    GLExecutionDomain* Domain;
    std::string Root;
    uint64_t Identity;
    enum Operation { Enabled, Mailbox, Topic, DataRead, DataWrite, DataDelete, MemoryRead, MemoryWrite, MessageRead, MessageWrite, MessageList };

    // The inherited bridge used Godot String(const char*) (Latin-1) for both
    // filenames and writes. Preserve its physical encoding; do not silently
    // strand existing non-ASCII service files while enforcing confinement.
    static std::string Legacy(const std::string& Bytes) {
        std::string Result;
        Result.reserve(Bytes.size());
        for (unsigned char Byte:Bytes) {
            if (Byte<128) Result.push_back(char(Byte));
            else { Result.push_back(char(0xc0|(Byte>>6))); Result.push_back(char(0x80|(Byte&63))); }
        }
        return Result;
    }

    static int RawDenied(lua_State* Thread) {
        luaL_error(Thread,"[Runtime:Capabilities] Raw filesystem access denied; use a storage service");
    }
    static std::string Argument(lua_State* Thread,int Index) {
        size_t Size=0;
        const char* Bytes=luaL_checklstring(Thread,Index,&Size);
        if (Size==0 || Size>200) luaL_error(Thread,"[Runtime:Filesystem] Storage name length limit exceeded");
        std::string Name(Bytes,Size);
        // Logical names are embedded inside a prefixed, .json-suffixed flat
        // leaf. Trailing dots/spaces here are not Windows filename aliases.
        if (Name=="." || Name==".." || !GLStorage::Component(Name+"_"))
            luaL_error(Thread,"[Runtime:Filesystem] Invalid storage name");
        // Validate before platform conversion, without logging untrusted bytes.
        if (!GLStorage::Utf8(Name))
            luaL_error(Thread,"[Runtime:Filesystem] Invalid storage name encoding");
        return std::string(Bytes,Size);
    }
    std::string Sender() const {
        godot::String Job=gl_net_role()==0 ? godot::String("local") : gl_ensure_job_id();
        return std::string(Job.utf8().get_data())+"_"+std::to_string(Identity);
    }
    static int Call(lua_State* Thread) {
        auto& Capability=*static_cast<GLServiceStorage*>(lua_touserdata(Thread,lua_upvalueindex(1)));
        auto Op=static_cast<Operation>(lua_tointeger(Thread,lua_upvalueindex(2)));
        auto Owner=GLGetOwner(Thread);
        if (!Owner || !Owner->Alive || Owner->Domain!=Capability.Domain || Capability.Domain->GetMemoryAccount().Rejections)
            luaL_error(Thread,"[Runtime:Capabilities] Storage capability unavailable");
        if (Capability.Domain->IsClosing() && !Capability.Domain->IsShutdownCallback(Thread))
            luaL_error(Thread,"[Runtime:Capabilities] Storage domain closing");
        bool Server=Capability.Domain->GetKind()==GLDomainKind::Server && gl_net_role()!=2;
        if (Op==Enabled) { lua_pushboolean(Thread,Server); return 1; }
        if (Op==Mailbox) { auto Name=Capability.Sender(); lua_pushlstring(Thread,Name.data(),Name.size()); return 1; }
        if (Op==Topic) { Argument(Thread,1); return 0; }
        if (!Server) luaL_error(Thread,"[Runtime:Capabilities] Server storage authority required");
        std::string Name=Argument(Thread,1);
        std::string Leaf;
        unsigned Grant=0;
        bool Writing=Op==DataWrite || Op==MemoryWrite || Op==MessageWrite;
        if (Op==DataRead || Op==DataWrite || Op==DataDelete) Leaf="ds_"+Name+"_"+Argument(Thread,2)+".json";
        else if (Op==MemoryRead || Op==MemoryWrite) Leaf="mem_"+Name+".json";
        else if (Op==MessageRead) {
            auto Sender=Argument(Thread,2);
            if (!GLStorage::Component(Sender) || Sender.find("__")!=std::string::npos) luaL_error(Thread,"[Runtime:Filesystem] Invalid mailbox identity");
            Leaf="msg_"+Name+"__"+Sender+".json";
        }
        else if (Op==MessageWrite) Leaf="msg_"+Name+"__"+Capability.Sender()+".json";
        else if (Op!=MessageList) luaL_error(Thread,"[Runtime:Capabilities] Invalid storage operation");
        Grant=Writing ? GLStorage::Write : Op==DataDelete ? GLStorage::Delete : Op==MessageList ? GLStorage::List : GLStorage::Read;
        std::string Data;
        if (Writing) {
            size_t Size=0;
            const char* Bytes=luaL_checklstring(Thread,Op==DataWrite?3:2,&Size);
            if (Size>GLStorage::MaxBytes) luaL_error(Thread,"[Runtime:Filesystem] Storage size limit exceeded");
            size_t PhysicalSize=0;
            for (size_t Index=0;Index<Size;++Index) PhysicalSize+=static_cast<unsigned char>(Bytes[Index])<128?1:2;
            if (PhysicalSize>GLStorage::MaxBytes || std::memchr(Bytes,0,Size)) luaL_error(Thread,"[Runtime:Filesystem] Invalid or oversized storage payload");
            Data=Legacy(std::string(Bytes,Size));
        }
        Leaf=Legacy(Leaf);
        GLStorage Storage(Capability.Root,Grant);
        GLStorage::Error Status;
        std::vector<std::string> Names;
        std::string Prefix=Legacy("msg_"+Name+"__");
        if (Op==MessageList) Status=Storage.Names(Prefix,Names);
        else if (Writing) Status=Storage.WriteFile(Leaf,Data);
        else if (Op==DataDelete) Status=Storage.Remove(Leaf);
        else Status=Storage.ReadFile(Leaf,Data);
        if (Status==GLStorage::Error::Missing) { lua_pushnil(Thread); return 1; }
        if (Status!=GLStorage::Error::None) {
            const char* Reason=Status==GLStorage::Error::Denied ? "Permission denied" :
                Status==GLStorage::Error::InvalidPath ? "Invalid or unconfined storage path" :
                Status==GLStorage::Error::Unavailable ? "Storage root unavailable" :
                Status==GLStorage::Error::Limit ? "Storage resource limit exceeded" : "Storage I/O failed";
            luaL_error(Thread,"[Runtime:Filesystem] %s",Reason);
        }
        if (Op==MessageList) {
            lua_newtable(Thread);
            int Index=0;
            for (auto& File:Names) {
                if (File.size()<=Prefix.size()+5) continue;
                auto Sender=File.substr(Prefix.size(),File.size()-Prefix.size()-5);
                if (!GLStorage::Component(Sender) || Sender.size()>200 || Sender.find("__")!=std::string::npos) continue;
                lua_pushlstring(Thread,Sender.data(),Sender.size()); lua_rawseti(Thread,-2,++Index);
            }
            return 1;
        }
        if (!Writing && Op!=DataDelete) {
            if (Data.compare(0,3,"\xef\xbb\xbf")==0) Data.erase(0,3);
            lua_pushlstring(Thread,Data.data(),Data.size()); return 1;
        }
        lua_pushboolean(Thread,true); return 1;
    }
    static void Install(lua_State* Thread,GLExecutionDomain& Domain) {
        // Root creation is an engine-owned initialization operation, never
        // requested by a gameplay path. Operations subsequently pin/revalidate it.
        godot::String Root=godot::OS::get_singleton()->get_user_data_dir();
        godot::DirAccess::make_dir_recursive_absolute(Root);
        void* Bytes=lua_newuserdatadtor(Thread,sizeof(GLServiceStorage),[](void* Data) { static_cast<GLServiceStorage*>(Data)->~GLServiceStorage(); });
        new (Bytes) GLServiceStorage{&Domain,Root.utf8().get_data(),GLStorageVmIdentity()};
        int Context=lua_gettop(Thread);
        lua_newtable(Thread);
        const char* Names[]={"Enabled","Mailbox","Topic","DataRead","DataWrite","DataDelete","MemoryRead","MemoryWrite","MessageRead","MessageWrite","MessageList"};
        for (int Index=0;Index<=MessageList;++Index) {
            lua_pushvalue(Thread,Context); lua_pushinteger(Thread,Index);
            lua_pushcclosure(Thread,Call,Names[Index],2); lua_setfield(Thread,-2,Names[Index]);
        }
        lua_setreadonly(Thread,-1,true);
        lua_setglobal(Thread,"_ServiceStorage"); lua_pop(Thread,1);
        lua_newtable(Thread);
        for (const char* Name:{"read","write","exists","delete","list"}) {
            lua_pushcfunction(Thread,RawDenied,Name); lua_setfield(Thread,-2,Name);
        }
        lua_setreadonly(Thread,-1,true); lua_setglobal(Thread,"_FileAccess");
    }
};
#endif
