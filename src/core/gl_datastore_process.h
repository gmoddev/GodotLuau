#ifndef GL_DATASTORE_PROCESS_H
#define GL_DATASTORE_PROCESS_H
#include <string>
#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <cerrno>
#include <chrono>
#include <thread>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <signal.h>
#include <spawn.h>
extern char** environ;
#endif

// One trusted companion, no shell and no Lua. Main-thread pipe operations are
// bounded/nonblocking; all regular-file I/O happens inside the companion.
class GLDataStoreProcess {
#ifdef _WIN32
    HANDLE Process=nullptr, Input=nullptr, InputReader=nullptr, Output=nullptr;
    static void Close(HANDLE& Value) { if (Value) CloseHandle(Value); Value=nullptr; }
#else
    pid_t Process=-1;
    int Input=-1,Output=-1;
    static void Close(int& Value) { if (Value>=0) close(Value); Value=-1; }
#endif
public:
    bool Failed=false;
    int Exit=-1;
    GLDataStoreProcess()=default;
    GLDataStoreProcess(const GLDataStoreProcess&)=delete;
    ~GLDataStoreProcess() { Cancel(); Finished();
#ifdef _WIN32
        Close(Process); Close(InputReader);
#endif
        Close(Input); Close(Output);
    }
    bool Start(const std::string& Executable) {
#ifdef _WIN32
        SECURITY_ATTRIBUTES Security{sizeof(Security),nullptr,TRUE};
        HANDLE Reader=nullptr,Writer=nullptr;
        if (!CreatePipe(&Reader,&Writer,&Security,65536)) return false;
        InputReader=Reader; Input=Writer;
        if (!SetHandleInformation(Input,HANDLE_FLAG_INHERIT,0)) return false;
        DWORD Mode=PIPE_READMODE_BYTE|PIPE_NOWAIT;
        if (!SetNamedPipeHandleState(Input,&Mode,nullptr,nullptr)) return false;
        HANDLE ChildOutput=nullptr;
        if (!CreatePipe(&Output,&ChildOutput,&Security,65536)) return false;
        if (!SetHandleInformation(Output,HANDLE_FLAG_INHERIT,0)) { Close(ChildOutput); return false; }
        STARTUPINFOEXW Startup{}; Startup.StartupInfo.cb=sizeof(Startup);
        Startup.StartupInfo.dwFlags=STARTF_USESTDHANDLES;
        Startup.StartupInfo.hStdInput=InputReader;
        Startup.StartupInfo.hStdOutput=ChildOutput;
        Startup.StartupInfo.hStdError=ChildOutput;
        SIZE_T Size=0;
        InitializeProcThreadAttributeList(nullptr,1,0,&Size);
        std::string Attributes(Size,'\0');
        Startup.lpAttributeList=reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(Attributes.data());
        if (!InitializeProcThreadAttributeList(Startup.lpAttributeList,1,0,&Size)) { Close(ChildOutput); return false; }
        HANDLE Inherited[]={InputReader,ChildOutput};
        bool Ready=UpdateProcThreadAttribute(Startup.lpAttributeList,0,PROC_THREAD_ATTRIBUTE_HANDLE_LIST,Inherited,sizeof(Inherited),nullptr,nullptr)!=0;
        std::wstring Command=L"\""+std::filesystem::u8path(Executable).native()+L"\"";
        PROCESS_INFORMATION Info{};
        bool Started=Ready && CreateProcessW(nullptr,Command.data(),nullptr,nullptr,TRUE,
            CREATE_NO_WINDOW|EXTENDED_STARTUPINFO_PRESENT,nullptr,nullptr,&Startup.StartupInfo,&Info);
        DeleteProcThreadAttributeList(Startup.lpAttributeList); Close(ChildOutput);
        if (!Started) return false;
        Process=Info.hProcess; CloseHandle(Info.hThread); Close(InputReader);
        return true;
#else
        int In[2],Out[2];
        if (pipe(In)!=0) return false;
        if (pipe(Out)!=0) { close(In[0]); close(In[1]); return false; }
        for (int File:{In[0],In[1],Out[0],Out[1]}) {
            if (fcntl(File,F_SETFD,FD_CLOEXEC)<0) {
                for (int Open:{In[0],In[1],Out[0],Out[1]}) close(Open);
                return false;
            }
        }
        posix_spawn_file_actions_t Actions;
        posix_spawn_file_actions_init(&Actions);
        posix_spawn_file_actions_adddup2(&Actions,In[0],STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&Actions,Out[1],STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&Actions,Out[1],STDERR_FILENO);
        char* Arguments[]={const_cast<char*>(Executable.c_str()),nullptr};
        int Status=posix_spawn(&Process,Executable.c_str(),&Actions,nullptr,Arguments,environ);
        posix_spawn_file_actions_destroy(&Actions);
        close(In[0]); close(Out[1]);
        Input=In[1]; Output=Out[0];
        if (fcntl(Input,F_SETFL,O_NONBLOCK)<0 || fcntl(Output,F_SETFL,O_NONBLOCK)<0) { Cancel(); return false; }
        if (Status) { Process=-1; return false; }
        return true;
#endif
    }
    size_t Send(const char* Bytes,size_t Count) {
#ifdef _WIN32
        DWORD Written=0;
        // Byte-mode NOWAIT writes can be partial. Preserve the actual count;
        // never peek a read handle shared with the child's blocking fread.
        if (!WriteFile(Input,Bytes,DWORD(Count),&Written,nullptr) && GetLastError()!=ERROR_NO_DATA) Failed=true;
        return Written;
#else
        // Avoid SIGPIPE without changing application-wide signal disposition.
        sigset_t Mask,Old,Pending;
        sigemptyset(&Mask); sigaddset(&Mask,SIGPIPE);
        pthread_sigmask(SIG_BLOCK,&Mask,&Old);
        sigpending(&Pending);
        bool HadSignal=sigismember(&Pending,SIGPIPE)!=0;
        ssize_t Written=write(Input,Bytes,Count);
        int Error=errno;
        if (Written<0 && Error==EPIPE && !HadSignal) {
            timespec Zero{}; sigtimedwait(&Mask,nullptr,&Zero);
        }
        pthread_sigmask(SIG_SETMASK,&Old,nullptr);
        if (Written<0) { if (Error!=EAGAIN && Error!=EWOULDBLOCK && Error!=EINTR) Failed=true; return 0; }
        return size_t(Written);
#endif
    }
    size_t Receive(char* Bytes,size_t Count) {
#ifdef _WIN32
        DWORD Ready=0;
        if (!PeekNamedPipe(Output,nullptr,0,nullptr,&Ready,nullptr)) return 0;
        Count=std::min(Count,size_t(Ready));
        DWORD Received=0;
        if (Count && !ReadFile(Output,Bytes,DWORD(Count),&Received,nullptr)) Failed=true;
        return Received;
#else
        ssize_t Received=read(Output,Bytes,Count);
        if (Received<0) { if (errno!=EAGAIN && errno!=EWOULDBLOCK && errno!=EINTR) Failed=true; return 0; }
        return size_t(Received);
#endif
    }
    void Cancel() {
#ifdef _WIN32
        if (Process && WaitForSingleObject(Process,0)==WAIT_TIMEOUT) TerminateProcess(Process,1);
#else
        if (Process>0) kill(Process,SIGKILL);
#endif
    }
    bool Finished() {
#ifdef _WIN32
        if (!Process) return true;
        if (WaitForSingleObject(Process,0)!=WAIT_OBJECT_0) return false;
        DWORD Code=0; if (GetExitCodeProcess(Process,&Code)) Exit=int(Code);
        return true;
#else
        if (Process<=0) return true;
        int Status=0;
        pid_t Result=waitpid(Process,&Status,WNOHANG);
        if (Result==Process) { Exit=WIFEXITED(Status)?WEXITSTATUS(Status):-1; Process=-1; return true; }
        if (Result<0 && errno==ECHILD) { Process=-1; return true; }
        return false;
#endif
    }
};
#endif
