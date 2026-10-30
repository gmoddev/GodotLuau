#ifndef GL_DATASTORE_BACKEND_H
#define GL_DATASTORE_BACKEND_H
#include "gl_storage.h"
#include "gl_datastore_protocol.h"
#include <chrono>
#include <thread>
#include <functional>
#ifdef __linux__
#include <sys/file.h>
#include <sys/vfs.h>
#endif

// Native I/O only. Never called on the Godot frame thread in normal managed use.
#if defined(_WIN32) || defined(__linux__)
class GLDataStoreBackend {
    using Status=GLDataStoreProtocol::Status;
    using Result=GLDataStoreProtocol::Result;
    using Request=GLDataStoreProtocol::Request;
    using Operation=GLDataStoreProtocol::Operation;
    static constexpr const char* LockName="ds_.gl009.lock";
    static constexpr const char* StageName="ds_.gl009.stage";
    static Status Failure(Status Otherwise=Status::IO) {
#ifdef _WIN32
        DWORD Code=GetLastError();
        return Code==ERROR_ACCESS_DENIED || Code==ERROR_WRITE_PROTECT?Status::Denied:Otherwise;
#else
        return errno==EACCES || errno==EPERM || errno==EROFS?Status::Denied:Otherwise;
#endif
    }
    static bool Local(const GLStorage::Handle& Directory) {
#ifdef _WIN32
        wchar_t Name[32]{};
        return GetVolumeInformationByHandleW(Directory.Value,nullptr,0,nullptr,nullptr,nullptr,Name,32) && std::wstring(Name)==L"NTFS";
#elif defined(__linux__)
        struct statfs Info{};
        return fstatfs(Directory.Value,&Info)==0 && (Info.f_type==0xef53 || Info.f_type==0x58465342 || Info.f_type==0x9123683e);
#else
        return false;
#endif
    }
    static bool Sync(const GLStorage::Handle& File) {
#ifdef _WIN32
        return FlushFileBuffers(File.Value)!=0;
#else
        return fsync(File.Value)==0;
#endif
    }
    static bool Bytes(const GLStorage::Handle& File,std::string& Data,bool Writing) {
        size_t Offset=0;
        while (Offset<Data.size()) {
#ifdef _WIN32
            DWORD Count=0;
            BOOL Ok=Writing ? ::WriteFile(File.Value,Data.data()+Offset,DWORD(Data.size()-Offset),&Count,nullptr) :
                ::ReadFile(File.Value,Data.data()+Offset,DWORD(Data.size()-Offset),&Count,nullptr);
            if (!Ok || !Count) return false;
#else
            ssize_t Count=Writing ? write(File.Value,Data.data()+Offset,Data.size()-Offset) : read(File.Value,Data.data()+Offset,Data.size()-Offset);
            if (Count<0 && errno==EINTR) continue;
            if (Count<=0) return false;
#endif
            Offset+=size_t(Count);
        }
        return true;
    }
    static Result Read(const GLStorage::Handle& Directory,const std::string& Leaf) {
        Result Value;
#ifdef _WIN32
        auto File=GLStorage::OpenRelative(Directory.Value,std::filesystem::u8path(Leaf).native(),GENERIC_READ|FILE_READ_ATTRIBUTES,false,false);
        if (!File.Valid()) { Value.Code=GetLastError()==ERROR_FILE_NOT_FOUND?Status::Ok:Failure(); return Value; }
        if (!GLStorage::Regular(File.Value)) { Value.Code=Status::Invalid; return Value; }
        LARGE_INTEGER Size{};
        if (!GetFileSizeEx(File.Value,&Size)) { Value.Code=Status::IO; return Value; }
        if (Size.QuadPart<0 || uint64_t(Size.QuadPart)>GLStorage::MaxBytes) { Value.Code=Status::Limit; return Value; }
        Value.Data.resize(size_t(Size.QuadPart));
#else
        GLStorage::Handle File(openat(Directory.Value,Leaf.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK));
        if (!File.Valid()) { Value.Code=errno==ENOENT?Status::Ok:Failure(); return Value; }
        struct stat Info{};
        if (fstat(File.Value,&Info)!=0) { Value.Code=Status::IO; return Value; }
        if (!S_ISREG(Info.st_mode) || Info.st_nlink!=1) { Value.Code=Status::Invalid; return Value; }
        if (Info.st_size<0 || uint64_t(Info.st_size)>GLStorage::MaxBytes) { Value.Code=Status::Limit; return Value; }
        Value.Data.resize(size_t(Info.st_size));
#endif
        Value.Exists=true;
        if (!Bytes(File,Value.Data,false)) { Value.Code=Status::IO; Value.Data.clear(); }
        return Value;
    }
public:
    // Tests can inject definite failures or pause/terminate at these actual stages.
    // Production callers supply no hook. No path/capability token reaches Lua.
    static Result Execute(const Request& Input,const std::function<bool(int)>& Stage={}) {
        Result Value;
        auto Fail=[&](Status Code) { Value.Code=Code; Value.Data.clear(); return Value; };
        if (!GLStorage::ValidLeaf(Input.Leaf) || Input.Leaf.rfind("ds_",0)!=0 || Input.Expected.size()>GLStorage::MaxBytes || Input.Data.size()>GLStorage::MaxBytes)
            return Fail(Status::Invalid);
        GLStorage Storage(Input.Root,GLStorage::Read|GLStorage::Write);
        GLStorage::Handles Handles;
        if (!Storage.OpenRoot(Handles) || !Local(Handles.back())) return Fail(Status::Unavailable);
        auto& Directory=Handles.back();
#ifdef _WIN32
        auto Lock=GLStorage::OpenRelative(Directory.Value,std::filesystem::u8path(LockName).native(),GENERIC_READ|GENERIC_WRITE|FILE_READ_ATTRIBUTES,true,false,true);
        if (!Lock.Valid()) return Fail(Failure(Status::Invalid));
        if (!GLStorage::Regular(Lock.Value)) return Fail(Status::Invalid);
        OVERLAPPED Position{};
#else
        GLStorage::Handle Lock(openat(Directory.Value,LockName,O_RDWR|O_CREAT|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC,0600));
        struct stat LockInfo{};
        if (!Lock.Valid()) return Fail(Failure(Status::Invalid));
        if (fstat(Lock.Value,&LockInfo)!=0 || !S_ISREG(LockInfo.st_mode) || LockInfo.st_nlink!=1) return Fail(Status::Invalid);
#endif
        auto Deadline=std::chrono::steady_clock::now()+std::chrono::seconds(1);
        while (true) {
#ifdef _WIN32
            if (LockFileEx(Lock.Value,LOCKFILE_EXCLUSIVE_LOCK|LOCKFILE_FAIL_IMMEDIATELY,0,1,0,&Position)) break;
            if (GetLastError()!=ERROR_LOCK_VIOLATION && GetLastError()!=ERROR_IO_PENDING) return Fail(Status::IO);
#else
            if (flock(Lock.Value,LOCK_EX|LOCK_NB)==0) break;
            if (errno!=EWOULDBLOCK && errno!=EAGAIN && errno!=EINTR) return Fail(Status::IO);
#endif
            if (std::chrono::steady_clock::now()>=Deadline) return Fail(Status::Busy);
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
        // Lock owns its stable inode/handle until return/process termination.
        // Never truncate or replace it. No transform executes in this section.
        Value=Read(Directory,Input.Leaf);
        if (Value.Code!=Status::Ok || Input.Op==Operation::Read) return Value;
        if (Input.Op==Operation::Compare && (Value.Exists!=Input.Exists || Value.Data!=Input.Expected)) return Fail(Status::Conflict);
        Value.Data.clear();
#ifdef _WIN32
        auto Temporary=GLStorage::OpenRelative(Directory.Value,std::filesystem::u8path(StageName).native(),GENERIC_WRITE|DELETE|FILE_READ_ATTRIBUTES,true,false,true);
        if (!Temporary.Valid()) return Fail(Failure(Status::Invalid));
        if (!GLStorage::Regular(Temporary.Value)) return Fail(Status::Invalid);
        if (!SetEndOfFile(Temporary.Value)) return Fail(Status::IO);
#else
        GLStorage::Handle Temporary(openat(Directory.Value,StageName,O_WRONLY|O_CREAT|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC,0600));
        struct stat Info{};
        if (!Temporary.Valid()) return Fail(Failure(Status::Invalid));
        if (fstat(Temporary.Value,&Info)!=0 || !S_ISREG(Info.st_mode) || Info.st_nlink!=1) return Fail(Status::Invalid);
        if (ftruncate(Temporary.Value,0)!=0) return Fail(Status::IO);
#endif
        std::string Data=Input.Data;
        if (!Bytes(Temporary,Data,true)) return Fail(Failure());
        if ((Stage && !Stage(1)) || !Sync(Temporary)) return Fail(Status::Durability);
        if (Stage && !Stage(2)) return Fail(Status::IO);
#ifdef _WIN32
        std::wstring Name=std::filesystem::u8path(Input.Leaf).native();
        std::vector<uint8_t> Rename(sizeof(FILE_RENAME_INFO)+Name.size()*sizeof(wchar_t));
        auto Record=reinterpret_cast<FILE_RENAME_INFO*>(Rename.data());
        Record->ReplaceIfExists=TRUE; Record->RootDirectory=Directory.Value;
        Record->FileNameLength=DWORD(Name.size()*sizeof(wchar_t));
        std::memcpy(Record->FileName,Name.data(),Record->FileNameLength);
        // Win32's wrapper rejects a non-null RootDirectory. Use the same native
        // API family as ADR-003, retaining the pinned relative target directory.
        using RenameFunction=NTSTATUS (NTAPI*)(HANDLE,PIO_STATUS_BLOCK,PVOID,ULONG,FILE_INFORMATION_CLASS);
        auto RenameFile=reinterpret_cast<RenameFunction>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"),"NtSetInformationFile"));
        if (!RenameFile) return Fail(Status::Unavailable);
        IO_STATUS_BLOCK RenameStatus{};
        NTSTATUS Renamed=RenameFile(Temporary.Value,&RenameStatus,Record,ULONG(Rename.size()),static_cast<FILE_INFORMATION_CLASS>(10));
        if (Renamed<0) return Fail(uint32_t(Renamed)==0xc0000022?Status::Denied:Status::IO);
#else
        if (renameat(Directory.Value,StageName,Directory.Value,Input.Leaf.c_str())!=0) return Fail(Failure());
#endif
        if (Stage && !Stage(3)) return Fail(Status::Indeterminate);
#ifdef _WIN32
        if (!Sync(Temporary)) return Fail(Status::Indeterminate);
#else
        if (!Sync(Directory)) return Fail(Status::Indeterminate);
#endif
        if (Stage && !Stage(4)) return Fail(Status::Indeterminate);
        Value.Exists=true;
        return Value;
    }
};
#else
class GLDataStoreBackend {
public:
    static GLDataStoreProtocol::Result Execute(const GLDataStoreProtocol::Request&,const std::function<bool(int)>& = {}) {
        GLDataStoreProtocol::Result Value; Value.Code=GLDataStoreProtocol::Status::Unavailable; return Value;
    }
};
#endif
#endif
