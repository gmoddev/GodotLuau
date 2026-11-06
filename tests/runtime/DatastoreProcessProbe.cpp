#include "gl_datastore_backend.h"
#include "gl_datastore_process.h"
#include <cstdio>
int main(int Count,char** Arguments) {
#ifdef _WIN32
    SetErrorMode(0x8003);
#endif
    if (Count!=3) return 2;
    using namespace GLDataStoreProtocol;
    auto Root=std::filesystem::absolute(Arguments[2]); std::filesystem::create_directories(Root);
    Request Input; Input.Root=Root.u8string(); Input.Leaf="ds_GL009_prototype.json";
    auto Invoke=[&](const Request& Value)->Result {
        GLDataStoreProcess Child;
        if (!Child.Start(Arguments[1])) throw std::runtime_error("spawn");
        std::string Sent=Encode(Value),Received;
        size_t Position=0;
        auto Deadline=std::chrono::steady_clock::now()+std::chrono::seconds(15);
        while (std::chrono::steady_clock::now()<Deadline) {
            if (Position<Sent.size()) Position+=Child.Send(Sent.data()+Position,std::min(size_t(65536),Sent.size()-Position));
            char Buffer[65536]; size_t Bytes=Child.Receive(Buffer,sizeof(Buffer)); Received.append(Buffer,Bytes);
            if (Received.size()>=24 && Received.size()==24+Number(Received.data()+16)) {
                Result Answer; Answer.Code=Status(Number(Received.data()+8)); Answer.Exists=Number(Received.data()+12)!=0;
                Answer.Data=Received.substr(24);
                while (!Child.Finished() && std::chrono::steady_clock::now()<Deadline) std::this_thread::sleep_for(std::chrono::milliseconds(1));
                char Extra[4096];
                if (!Child.Finished() || Child.Exit!=0 || Child.Receive(Extra,sizeof(Extra))) throw std::runtime_error("helper exit/diagnostics");
                return Answer;
            }
            if (Child.Failed) throw std::runtime_error("pipe");
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
        throw std::runtime_error("timeout");
    };
    try {
        Input.Op=Operation::Set; Input.Data="123";
        auto First=Invoke(Input);
        if (First.Code!=Status::Ok) {
            std::printf("[Persistence:Probe] backend status=%u\n",unsigned(First.Code));
            auto Diagnostic=GLDataStoreBackend::Execute(Input,[](int Stage) { std::printf("[Persistence:Probe] stage=%d\n",Stage); return true; });
#ifdef _WIN32
            std::printf("[Persistence:Probe] diagnostic=%u Win32=%lu\n",unsigned(Diagnostic.Code),GetLastError());
#endif
            return 3;
        }
        Input.Op=Operation::Read; Input.Data.clear();
        auto Snapshot=Invoke(Input);
        if (Snapshot.Code!=Status::Ok || !Snapshot.Exists || Snapshot.Data!="123") return 4;
        Input.Op=Operation::Compare; Input.Exists=true; Input.Expected="0"; Input.Data="456";
        if (Invoke(Input).Code!=Status::Conflict) return 5;
        Input.Expected="123";
        if (Invoke(Input).Code!=Status::Ok) return 6;
        Input.Op=Operation::Set; Input.Expected.clear(); Input.Data="\""+std::string(4*1024*1024,'x')+"\"";
        if (Invoke(Input).Code!=Status::Ok) return 7;
        Input.Op=Operation::Read; Input.Data.clear();
        auto Large=Invoke(Input);
        if (Large.Code!=Status::Ok || Large.Data.size()!=4*1024*1024+2) return 8;
        std::puts("[Persistence:Probe] PASS native helper read/set/CAS/conflict and 4MiB IPC");
    } catch (const std::exception& Error) { std::printf("[Persistence:Probe] FAIL %s\n",Error.what()); return 9; }
    return 0;
}
