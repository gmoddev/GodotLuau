#include "gl_datastore_backend.h"
#include <fstream>
#include <iostream>
#include <stdexcept>
using namespace GLDataStoreProtocol;
static void Require(bool Value,const char* Text) { if (!Value) throw std::runtime_error(Text); }
int main(int Count,char** Arguments) {
#ifdef _WIN32
    SetErrorMode(0x8003);
#endif
    if (Count<3) return 2;
    try {
        std::filesystem::path Root=std::filesystem::absolute(Arguments[1]);
        std::filesystem::create_directories(Root);
        Request Input; Input.Root=Root.u8string(); Input.Leaf="ds_GL009_probe.json";
        std::string Mode=Arguments[2];
        if (Mode=="pause") {
            if (Count!=4) return 2;
            Input.Op=Operation::Set; Input.Data="999";
            int Target=std::stoi(Arguments[3]);
            auto Answer=GLDataStoreBackend::Execute(Input,[&](int Stage) {
                if (Stage==Target) {
                    std::ofstream Marker(Root/"stage.marker"); Marker<<Stage; Marker.close();
                    std::this_thread::sleep_for(std::chrono::seconds(10));
                }
                return true;
            });
            Require(Answer.Code==Status::Ok,"paused commit");
        } else if (Mode=="increment") {
            for (int Iteration=0;Iteration<20;++Iteration) {
                bool Done=false;
                for (int Attempt=0;Attempt<100 && !Done;++Attempt) {
                    Input.Op=Operation::Read;
                    auto Current=GLDataStoreBackend::Execute(Input);
                    Require(Current.Code==Status::Ok,"increment read");
                    Input.Op=Operation::Compare; Input.Exists=Current.Exists; Input.Expected=Current.Data;
                    Input.Data=std::to_string((Current.Exists?std::stoi(Current.Data):0)+1);
                    auto Next=GLDataStoreBackend::Execute(Input);
                    Require(Next.Code==Status::Ok || Next.Code==Status::Conflict,"increment commit");
                    Done=Next.Code==Status::Ok;
                }
                Require(Done,"increment retry bound");
            }
        } else if (Mode=="verify-increments") {
            Require(GLDataStoreBackend::Execute(Input).Data=="40","independent increments");
        } else {
            Input.Op=Operation::Set; Input.Data="123";
            Require(GLDataStoreBackend::Execute(Input).Code==Status::Ok,"seed");
            if (Mode=="seed") return 0;
            for (int Stage=1;Stage<=4;++Stage) {
                Input.Data="123"; Require(GLDataStoreBackend::Execute(Input).Code==Status::Ok,"reset");
                Input.Data="456";
                auto Failure=GLDataStoreBackend::Execute(Input,[&](int Point) { return Point!=Stage; });
                Require(Failure.Code==(Stage==1?Status::Durability:Stage==2?Status::IO:Status::Indeterminate),"fault disposition");
                Request Read=Input; Read.Op=Operation::Read;
                Require(GLDataStoreBackend::Execute(Read).Data==(Stage<3?"123":"456"),"fault state");
            }
            Input.Op=Operation::Compare; Input.Exists=true; Input.Expected="wrong"; Input.Data="777";
            Require(GLDataStoreBackend::Execute(Input).Code==Status::Conflict,"stale snapshot");
            Input.Op=Operation::Read; Require(GLDataStoreBackend::Execute(Input).Data=="456","conflict nonmutation");
            Input.Leaf="../escape.json"; Require(GLDataStoreBackend::Execute(Input).Code==Status::Invalid,"path rejection");
            Input.Leaf="ds_GL009_probe.json"; Input.Expected.assign(MaxData+1,'x');
            Require(GLDataStoreBackend::Execute(Input).Code==Status::Invalid,"bounds rejection");
            Input.Expected.clear(); Input.Op=Operation::Set; Input.Data="777";
            auto Outside=Root.parent_path()/(Root.filename().u8string()+"-sentinel.json");
            { std::ofstream File(Outside); File<<"12345"; }
            auto Retained=[&]() { std::ifstream File(Outside); std::string Text; File>>Text; Require(Text=="12345","outside sentinel changed"); };
            for (const char* Leaf:{"ds_GL009_link.json","ds_.gl009.stage","ds_.gl009.lock"}) {
                auto Link=Root/Leaf;
                // Disposable, quiescent probe root only. Never unlink a live
                // production lock as a recovery operation.
                std::filesystem::remove(Link);
                std::filesystem::create_hard_link(Outside,Link);
                Input.Leaf=std::string(Leaf)=="ds_GL009_link.json"?Leaf:"ds_GL009_probe.json";
                Require(GLDataStoreBackend::Execute(Input).Code!=Status::Ok,"hard-link transaction accepted");
                Retained(); std::filesystem::remove(Link);
            }
#ifdef __linux__
            auto Link=Root/"ds_GL009_symlink.json";
            std::filesystem::create_symlink(Outside,Link); Input.Leaf=Link.filename().u8string();
            Require(GLDataStoreBackend::Execute(Input).Code!=Status::Ok,"symlink transaction accepted");
            Retained(); std::filesystem::remove(Link);
            auto Alias=Root.parent_path()/(Root.filename().u8string()+"-alias");
            std::filesystem::create_directory_symlink(Root,Alias); Input.Root=Alias.u8string(); Input.Leaf="ds_GL009_probe.json";
            Require(GLDataStoreBackend::Execute(Input).Code==Status::Unavailable,"root alias accepted");
            std::filesystem::remove(Alias); Input.Root=Root.u8string();
#endif
            Input.Leaf="ds_GL009_probe.json";
            Require(GLDataStoreBackend::Execute(Input).Code==Status::Ok,"recovery after rejected aliases");
        }
        std::cout<<"[Persistence:Backend] PASS "<<Mode<<std::endl;
        return 0;
    } catch (const std::exception& Error) { std::cerr<<"[Persistence:Backend] FAIL "<<Error.what()<<std::endl; return 1; }
}
