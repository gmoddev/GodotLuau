#ifndef GL_STORAGE_H
#define GL_STORAGE_H

#include <string>
#include <vector>
#include <filesystem>
#include <cstdint>
#include <cerrno>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winternl.h>
#elif defined(__linux__)
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#endif

// Flat, pre-existing project user-data root. No VM pointers, ambient cwd,
// directory creation or retained handles. Error strings never contain input.
class GLStorage {
public:
    enum Permission : unsigned { Read=1, Write=2, Delete=4, List=8 };
    enum class Error { None, Denied, InvalidPath, Missing, Unavailable, IO, Limit };
    static constexpr size_t MaxBytes = 16*1024*1024;
    static constexpr size_t MaxEntries = 65536;
    static bool Utf8(const std::string& Value) {
        for (size_t Index=0;Index<Value.size();) {
            uint32_t First=static_cast<unsigned char>(Value[Index++]);
            if (First<128) continue;
            unsigned Count=First>=0xc2 && First<=0xdf ? 1 : First>=0xe0 && First<=0xef ? 2 : First>=0xf0 && First<=0xf4 ? 3 : 0;
            if (!Count || Index+Count>Value.size()) return false;
            uint32_t Code=First&((1u<<(6-Count))-1);
            for (unsigned Byte=0;Byte<Count;++Byte) {
                uint32_t Next=static_cast<unsigned char>(Value[Index++]);
                if ((Next&0xc0)!=0x80) return false;
                Code=(Code<<6)|(Next&63);
            }
            if (Code<(Count==1?0x80u:Count==2?0x800u:0x10000u) || Code>0x10ffff || (Code>=0xd800 && Code<=0xdfff)) return false;
        }
        return true;
    }
    static bool Component(const std::string& Value) {
        if (Value.empty() || Value.size()>240 || Value=="." || Value==".." ||
            Value.back()=='.' || Value.back()==' ') return false;
        for (unsigned char C:Value)
            if (C<32 || C==127 || C=='/' || C=='\\' || C==':' || C=='*' || C=='?' || C=='"' || C=='<' || C=='>' || C=='|') return false;
        return true;
    }
    GLStorage(std::string SelectedRoot, unsigned Grants) : Root(std::move(SelectedRoot)), Grants(Grants) {}
    Error ReadFile(const std::string& Leaf, std::string& Data) const { return File(Leaf,Data,false); }
    Error WriteFile(const std::string& Leaf, const std::string& Data) const {
        if (!(Grants&Write)) return Error::Denied;
        if (Data.size()>MaxBytes) return Error::Limit;
        std::string Copy=Data;
        return File(Leaf,Copy,true);
    }
    Error Remove(const std::string& Leaf) const {
        if (!(Grants&Delete)) return Error::Denied;
        if (!ValidLeaf(Leaf)) return Error::InvalidPath;
        Handles Keep;
        if (!OpenRoot(Keep)) return Error::Unavailable;
#ifdef _WIN32
        Handle Target=OpenRelative(Keep.back().Value,std::filesystem::u8path(Leaf).native(),DELETE|FILE_READ_ATTRIBUTES,false,false);
        if (!Target.Valid()) return GetLastError()==ERROR_FILE_NOT_FOUND ? Error::Missing : Error::IO;
        if (!Regular(Target.Value)) return Error::InvalidPath;
        FILE_DISPOSITION_INFO Info{TRUE};
        return SetFileInformationByHandle(Target.Value,FileDispositionInfo,&Info,sizeof(Info)) ? Error::None : Error::IO;
#elif defined(__linux__)
        struct stat Info{};
        if (fstatat(Keep.back().Value,Leaf.c_str(),&Info,AT_SYMLINK_NOFOLLOW)!=0) return errno==ENOENT ? Error::Missing : Error::IO;
        if (!S_ISREG(Info.st_mode) || Info.st_nlink!=1) return Error::InvalidPath;
        // unlinkat removes this confined entry; it never follows a replacement
        // symlink. It is not a transaction against another authorized writer.
        return unlinkat(Keep.back().Value,Leaf.c_str(),0)==0 ? Error::None : Error::IO;
#else
        return Error::Unavailable;
#endif
    }
    Error Names(const std::string& Prefix,std::vector<std::string>& Result) const {
        if (!(Grants&List)) return Error::Denied;
        if (!Component(Prefix)) return Error::InvalidPath;
        Handles Keep;
        if (!OpenRoot(Keep)) return Error::Unavailable;
        size_t Count=0;
#ifdef _WIN32
        alignas(FILE_ID_BOTH_DIR_INFO) char Buffer[64*1024];
        bool First=true;
        while (GetFileInformationByHandleEx(Keep.back().Value,First?FileIdBothDirectoryRestartInfo:FileIdBothDirectoryInfo,Buffer,sizeof(Buffer))) {
            First=false;
            auto Entry=reinterpret_cast<FILE_ID_BOTH_DIR_INFO*>(Buffer);
            while (true) {
                if (++Count>MaxEntries) return Error::Limit;
                int Size=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,Entry->FileName,int(Entry->FileNameLength/sizeof(wchar_t)),nullptr,0,nullptr,nullptr);
                if (Size>0 && Size<=1024) {
                    std::string Name(size_t(Size),'\0');
                    WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,Entry->FileName,int(Entry->FileNameLength/sizeof(wchar_t)),Name.data(),Size,nullptr,nullptr);
                    if (!(Entry->FileAttributes&(FILE_ATTRIBUTE_DIRECTORY|FILE_ATTRIBUTE_REPARSE_POINT)) && Match(Name,Prefix)) {
                        Handle File=OpenRelative(Keep.back().Value,std::filesystem::u8path(Name).native(),FILE_READ_ATTRIBUTES,false,false);
                        if (File.Valid() && Regular(File.Value)) Result.push_back(Name);
                    }
                }
                if (!Entry->NextEntryOffset) break;
                Entry=reinterpret_cast<FILE_ID_BOTH_DIR_INFO*>(reinterpret_cast<char*>(Entry)+Entry->NextEntryOffset);
            }
        }
        return GetLastError()==ERROR_NO_MORE_FILES ? Error::None : Error::IO;
#elif defined(__linux__)
        int Copy=fcntl(Keep.back().Value,F_DUPFD_CLOEXEC,0);
        if (Copy<0) return Error::IO;
        DIR* Directory=fdopendir(Copy);
        if (!Directory) { close(Copy); return Error::IO; }
        Error Status=Error::None;
        errno=0;
        while (auto Entry=readdir(Directory)) {
            if (++Count>MaxEntries) { Status=Error::Limit; break; }
            std::string Name=Entry->d_name;
            if (Match(Name,Prefix)) {
                struct stat Info{};
                if (fstatat(Keep.back().Value,Name.c_str(),&Info,AT_SYMLINK_NOFOLLOW)==0 && S_ISREG(Info.st_mode) && Info.st_nlink==1) Result.push_back(Name);
            }
            errno=0;
        }
        if (Status==Error::None && errno) Status=Error::IO;
        closedir(Directory);
        return Status;
#else
        return Error::Unavailable;
#endif
    }
private:
    std::string Root;
    unsigned Grants;
    static bool ValidLeaf(const std::string& Leaf) {
        return Leaf.size()<=240 && Component(Leaf) && Utf8(Leaf) &&
            (Leaf.rfind("ds_",0)==0 || Leaf.rfind("msg_",0)==0 || Leaf.rfind("mem_",0)==0) &&
            Leaf.size()>5 && Leaf.compare(Leaf.size()-5,5,".json")==0;
    }
    static bool Match(const std::string& Name,const std::string& Prefix) {
        return ValidLeaf(Name) && Name.rfind(Prefix,0)==0;
    }
#ifdef _WIN32
    struct Handle {
        HANDLE Value=INVALID_HANDLE_VALUE;
        explicit Handle(HANDLE Selected):Value(Selected) {}
        Handle(Handle&& Other) noexcept:Value(Other.Value) { Other.Value=INVALID_HANDLE_VALUE; }
        ~Handle() { if (Valid()) CloseHandle(Value); }
        bool Valid() const { return Value!=INVALID_HANDLE_VALUE; }
    };
    static bool Regular(HANDLE Value) {
        BY_HANDLE_FILE_INFORMATION Info{};
        return GetFileInformationByHandle(Value,&Info) && !(Info.dwFileAttributes&(FILE_ATTRIBUTE_DIRECTORY|FILE_ATTRIBUTE_REPARSE_POINT)) && Info.nNumberOfLinks==1 && GetFileType(Value)==FILE_TYPE_DISK;
    }
    static Handle OpenRelative(HANDLE Parent,const std::wstring& Name,DWORD Access,bool Create,bool Directory) {
        using OpenFunction=NTSTATUS (NTAPI*)(PHANDLE,ACCESS_MASK,POBJECT_ATTRIBUTES,PIO_STATUS_BLOCK,PLARGE_INTEGER,ULONG,ULONG,ULONG,ULONG,PVOID,ULONG);
        auto Open=reinterpret_cast<OpenFunction>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"),"NtCreateFile"));
        if (!Open || Name.empty() || Name.size()>32760) { SetLastError(ERROR_NOT_SUPPORTED); return Handle(INVALID_HANDLE_VALUE); }
        UNICODE_STRING Text{};
        Text.Length=USHORT(Name.size()*sizeof(wchar_t)); Text.MaximumLength=Text.Length;
        Text.Buffer=const_cast<wchar_t*>(Name.data());
        OBJECT_ATTRIBUTES Attributes{};
        Attributes.Length=sizeof(Attributes); Attributes.RootDirectory=Parent;
        Attributes.ObjectName=&Text; Attributes.Attributes=OBJ_CASE_INSENSITIVE|0x1000; // OBJ_DONT_REPARSE
        IO_STATUS_BLOCK Status{};
        HANDLE Result=INVALID_HANDLE_VALUE;
        // FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT plus directory
        // type. Each name is one component; no ambient absolute reopen follows.
        NTSTATUS Code=Open(&Result,Access|SYNCHRONIZE,&Attributes,&Status,nullptr,FILE_ATTRIBUTE_NORMAL,
            FILE_SHARE_READ|FILE_SHARE_WRITE,Create?3:1,0x00200000|0x20|(Directory?1:0x40),nullptr,0);
        if (Code<0) {
            SetLastError(ULONG(Code)==0xc0000034 || ULONG(Code)==0xc000003a ? ERROR_FILE_NOT_FOUND : ERROR_ACCESS_DENIED);
            return Handle(INVALID_HANDLE_VALUE);
        }
        return Handle(Result);
    }
#elif defined(__linux__)
    struct Handle {
        int Value=-1;
        explicit Handle(int Selected):Value(Selected) {}
        Handle(Handle&& Other) noexcept:Value(Other.Value) { Other.Value=-1; }
        ~Handle() { if (Valid()) close(Value); }
        bool Valid() const { return Value>=0; }
    };
#else
    struct Handle {};
#endif
    using Handles=std::vector<Handle>;
    bool OpenRoot(Handles& Keep) const {
        if (Root.empty() || Root.size()>4096 || Root.find('\0')!=std::string::npos) return false;
        auto Path=std::filesystem::u8path(Root);
        if (!Path.is_absolute()) return false;
#ifdef _WIN32
        // Open ancestors relative to already pinned handles. Delete-share
        // restrictions alone cannot prevent in-place reparse-point changes.
        if (Path.root_name().native().size()!=2 || Path.root_name().native()[1]!=L':') return false;
        Keep.emplace_back(CreateFileW(Path.root_path().c_str(),FILE_LIST_DIRECTORY|FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OPEN_REPARSE_POINT,nullptr));
        if (!Keep.back().Valid()) return false;
        for (const auto& Part:Path.relative_path()) {
            if (Part==L"." || Part==L"..") return false;
            if (Part.empty()) continue;
            Keep.push_back(OpenRelative(Keep.back().Value,Part.native(),FILE_LIST_DIRECTORY|FILE_READ_ATTRIBUTES,false,true));
            BY_HANDLE_FILE_INFORMATION Info{};
            if (!Keep.back().Valid() || !GetFileInformationByHandle(Keep.back().Value,&Info) ||
                !(Info.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY) || (Info.dwFileAttributes&FILE_ATTRIBUTE_REPARSE_POINT)) return false;
        }
        return !Keep.empty();
#elif defined(__linux__)
        Keep.emplace_back(open("/",O_RDONLY|O_CLOEXEC|O_DIRECTORY));
        if (!Keep.back().Valid()) return false;
        for (const auto& Part:Path.relative_path()) {
            if (Part=="." || Part=="..") return false;
            Keep.emplace_back(openat(Keep.back().Value,Part.c_str(),O_RDONLY|O_CLOEXEC|O_DIRECTORY|O_NOFOLLOW));
            if (!Keep.back().Valid()) return false;
        }
        return true;
#else
        return false;
#endif
    }
    Error File(const std::string& Leaf,std::string& Data,bool Writing) const {
        if (!(Grants&(Writing?Write:Read))) return Error::Denied;
        if (!ValidLeaf(Leaf)) return Error::InvalidPath;
        Handles Keep;
        if (!OpenRoot(Keep)) return Error::Unavailable;
#ifdef _WIN32
        Handle Target=OpenRelative(Keep.back().Value,std::filesystem::u8path(Leaf).native(),FILE_READ_ATTRIBUTES|(Writing?GENERIC_WRITE:GENERIC_READ),Writing,false);
        if (!Target.Valid()) return GetLastError()==ERROR_FILE_NOT_FOUND ? Error::Missing : Error::IO;
        if (!Regular(Target.Value)) return Error::InvalidPath;
        LARGE_INTEGER Size{};
        if (!GetFileSizeEx(Target.Value,&Size)) return Error::IO;
        if (!Writing && (Size.QuadPart<0 || uint64_t(Size.QuadPart)>MaxBytes)) return Error::Limit;
        if (Writing && !SetEndOfFile(Target.Value)) return Error::IO;
        if (!Writing) Data.resize(size_t(Size.QuadPart));
        DWORD Transferred=0;
        BOOL OK=Writing ? ::WriteFile(Target.Value,Data.data(),DWORD(Data.size()),&Transferred,nullptr) :
            ::ReadFile(Target.Value,Data.data(),DWORD(Data.size()),&Transferred,nullptr);
        return OK && Transferred==Data.size() ? Error::None : Error::IO;
#elif defined(__linux__)
        Handle Target(openat(Keep.back().Value,Leaf.c_str(),O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK|(Writing?(O_WRONLY|O_CREAT):O_RDONLY),0600));
        if (!Target.Valid()) return errno==ENOENT ? Error::Missing : Error::IO;
        struct stat Info{};
        if (fstat(Target.Value,&Info)!=0) return Error::IO;
        if (!S_ISREG(Info.st_mode) || Info.st_nlink!=1) return Error::InvalidPath;
        if (!Writing && (Info.st_size<0 || uint64_t(Info.st_size)>MaxBytes)) return Error::Limit;
        if (Writing && ftruncate(Target.Value,0)!=0) return Error::IO;
        if (!Writing) Data.resize(size_t(Info.st_size));
        size_t Offset=0;
        while (Offset<Data.size()) {
            ssize_t Count=Writing ? write(Target.Value,Data.data()+Offset,Data.size()-Offset) : read(Target.Value,&Data[Offset],Data.size()-Offset);
            if (Count<0 && errno==EINTR) continue;
            if (Count<=0) return Error::IO;
            Offset+=size_t(Count);
        }
        return Error::None;
#else
        return Error::Unavailable;
#endif
    }
};
#endif
