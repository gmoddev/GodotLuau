#include "gl_project_indexer.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#pragma comment(lib,"psapi.lib")
#else
#include <sys/resource.h>
#endif
using Clock=std::chrono::steady_clock;
void Check(bool Value,const char* Message) {if(!Value)throw std::runtime_error(Message);std::cout<<"[Editor:Index] PASS "<<Message<<'\n';}
std::shared_ptr<const GLProjectIndexer::Result> Wait(GLProjectIndexer& Index,uint64_t Generation) {
    auto Deadline=Clock::now()+std::chrono::seconds(60);
    while(Clock::now()<Deadline) {if(auto Result=Index.Poll(Generation))return Result;std::this_thread::sleep_for(std::chrono::milliseconds(1));}
    throw std::runtime_error("Index request deadline expired");
}
int main(int Count,char** Arguments)try {
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX|SEM_NOOPENFILEERRORBOX);
#endif
    if(Count!=2)return 2;
    auto Root=std::filesystem::absolute(Arguments[1])/("run-"+std::to_string(Clock::now().time_since_epoch().count()));std::filesystem::create_directories(Root);
    auto Write=[&](const std::string& Name,const std::string& Source){std::ofstream File(Root/Name,std::ios::binary);File<<Source;if(!File)throw std::runtime_error("Write failed");};
    Write("Module.luau","local function Build(Value: number): number return Value+1 end\nreturn {Build=Build}\n");
    Write("Consumer.luau","local M=require('res://Module.luau')\nlocal Answer=M.Build(2)\nlocal Alias=M.Build\nAlias(3)\nreturn Answer\n");
    Write("Shadow.luau","local M=require('res://Module.luau')\ndo local M={Build=function() end}; M.Build() end\nreturn M\n");
    Write("Assigned.luau","local M=require('res://Module.luau')\nM={Build=function() end}\nM.Build()\nreturn M\n");
    Write("AssignedFunction.luau","local M=require('res://Module.luau')\nfunction M() return 1 end\nM.Build()\nreturn M\n");
    Write("AssignedCompound.luau","local M=require('res://Module.luau')\nM ..= 'changed'\nM.Build()\nreturn M\n");
    GLProjectIndexer Index;GLProjectIndexer::Request Request;Request.Root=Root.u8string();Request.Query="References";Request.Module="res://Module.luau";Request.Member="Build";
    auto First=Wait(Index,Index.Submit(Request));
    Check(First->Error.empty() && First->Entries.size()==3,"Exact static module references preserve aliases, shadowing and reassignment");
    auto Warm=Wait(Index,Index.Submit(Request));Check(Warm->Parsed==0 && Warm->Cached==First->Files,"Warm index retains all unchanged documents");
    Request.Active="res://Consumer.luau";Request.Query="Definition";Request.Line=2;Request.Column=17;
    auto Definition=Wait(Index,Index.Submit(Request));
    Check(Definition->Entries.size()==1 && Definition->Entries[0].Path=="res://Module.luau" && Definition->Entries[0].Kind=="Definition","Pinned Luau resolves cross-module function definition");
    Request.Query="Complete";Request.Line=2;Request.Column=18;Request.Member="Bu";
    auto Completion=Wait(Index,Index.Submit(Request));
    Check(!Completion->Entries.empty() && Completion->Entries[0].Name=="Build" && !Completion->Entries[0].Type.empty(),"Type-aware completion includes imported function signature");
    Request.Query="Diagnostics";Request.Buffers[Request.Active]="local M=require('res://Module.luau')\nreturn M.Build('bad')\n";
    auto Errors=Wait(Index,Index.Submit(Request));Check(!Errors->Diagnostics.empty() && Errors->Parsed==1,"Changed buffer receives cross-module diagnostics and only one syntax reparse");
    Request.Active="res://Module.luau";Request.Buffers.clear();Request.Query="Rename";Request.Line=1;Request.Column=17;Request.Replacement="Construct";
    auto Rename=Wait(Index,Index.Submit(Request));Check(Rename->Error.empty() && Rename->Entries.size()==2 && Rename->Revisions.count(Request.Active),"Rename preview contains exact lexical definition/reference and source precondition");
    Request.Replacement="Value";auto Collision=Wait(Index,Index.Submit(Request));Check(!Collision->Error.empty() && Collision->Entries.empty(),"Rename refuses potential binding capture");
    Request.Query="References";Request.Active.clear();Request.Module="res://Module.luau";Request.Member="Build";
    Write("Consumer.luau","local M=require('res://Module.luau')\nreturn M.Build(1)\n");
    auto Changed=Wait(Index,Index.Submit(Request));Check(Changed->Entries.size()==1,"Saved edit invalidates removed references");
    std::filesystem::remove(Root/"Consumer.luau");auto Deleted=Wait(Index,Index.Submit(Request));Check(Deleted->Entries.empty(),"Completed discovery evicts deleted documents");
    for(int I=0;I<1200;++I) {
        // A schema/configuration workload: independently typed item records plus
        // a deterministic shared economy dependency, not empty padding modules.
        Write("Item"+std::to_string(I)+".luau","local Economy=require('res://Module.luau')\nexport type Item={Id:number,Price:number,Weight:number}\nlocal Item:Item={Id="+std::to_string(I)+",Price=Economy.Build("+std::to_string(I%97)+"),Weight="+std::to_string(I%13+1)+"}\nreturn Item\n");
    }
    Request.Query="Symbols";Request.Member.clear();auto Start=Clock::now();auto Generation=Index.Submit(Request);
    auto SubmitUs=std::chrono::duration_cast<std::chrono::microseconds>(Clock::now()-Start).count();
    auto Cold=Wait(Index,Generation);Check(Cold->Files>=1203 && Cold->More && Cold->Entries.size()==256,"Thousands-scale workload is indexed with bounded result pages");
    auto Cached=Wait(Index,Index.Submit(Request));Check(Cached->Parsed==0 && Cached->Files==Cold->Files,"Fully warm large cache is not evicted by result pagination");
    Request.Offset=256;auto Page=Wait(Index,Index.Submit(Request));Check(Page->Entries.size()==256 && Page->Parsed==0,"Next page reuses complete document index");
    Request.Query="Dependencies";Request.Offset=0;auto Graph=Wait(Index,Index.Submit(Request));
    size_t Edges=0;for(const auto& Pair:Graph->Dependencies)Edges+=Pair.second.size();
    Check(Graph->More && Graph->Entries.size()==256 && Edges<=256,"Dependency pages bound total edges as well as document count");
    Request.Query="Symbols";
    Request.Offset=0;auto Obsolete=Index.Submit(Request);Request.Query="Search";Request.Member="Economy";auto Current=Index.Submit(Request);
    auto Latest=Wait(Index,Current);Check(!Index.Poll(Obsolete) && Latest->Generation==Current,"Obsolete request cannot publish over current generation");
    Request.Query="Complete";Request.Active="res://Consumer.luau";Request.Line=2;Request.Column=12;Request.Member="Bu";
    Request.Buffers[Request.Active]="local M=require('res://Module.luau')\nreturn M.Build(1)\n";
    auto Interactive=Wait(Index,Index.Submit(Request));
    Check(!Interactive->Entries.empty() && Interactive->Entries[0].Name=="Build" && Interactive->Parsed==1,"Active-buffer completion reuses project snapshot and prioritizes one changed document");
    auto InteractiveWarm=Wait(Index,Index.Submit(Request));Check(InteractiveWarm->Parsed==0 && !InteractiveWarm->Entries.empty(),"Warm semantic completion retains frontend state");
    Request.Active="res://NativeAuthoring.luau";Request.Buffers.clear();Request.Buffers[Request.Active]="local S=Scene.new(script.Parent)\nlocal Style=S:New('Theme',{})\nS:Call(Style,'SetFontSize','font_size','Label',20)\nreturn Style\n";
    Request.Query="Diagnostics";
    auto NativeTypes=Wait(Index,Index.Submit(Request));
    Check(NativeTypes->Error.empty(),"Embedded native declaration frontend initializes");
    bool NativeError=false;for(const auto& Item:NativeTypes->Diagnostics)NativeError|=Item.Path==Request.Active;
    Check(!NativeError,"Actual scoped native authoring resolves against the shipped declaration snapshot");
    Request.Query="Definition";Request.Active="res://Consumer.luau";Request.Line=2;Request.Column=12;
    Request.Buffers.clear();Request.Buffers["res://Settings.luau"]="return {Maximum=42}\n";
    Request.Buffers[Request.Active]="local M=require('res://Settings.luau')\nreturn M.Maximum\n";
    auto Scalar=Wait(Index,Index.Submit(Request));
    Check(Scalar->Entries.size()==1 && Scalar->Entries[0].Kind=="Definition" && Scalar->Entries[0].Path=="res://Settings.luau","Pinned Luau exported-table metadata resolves a scalar member definition");
    Request.Query="Diagnostics";Request.Active="res://TypeFunction.luau";Request.Buffers.clear();
    Request.Buffers[Request.Active]="type function Forever(T) while true do end end\ntype Result=Forever<number>\nreturn 1\n";
    auto TypeFunction=Wait(Index,Index.Submit(Request));bool Refused=false;
    for(const auto& Item:TypeFunction->Diagnostics)Refused|=Item.Kind=="UnsupportedTypeFunction" && Item.Path==Request.Active;
    Check(TypeFunction->Incomplete && Refused,"Analysis refuses user type-function execution without starting a compiler VM");
    Request.Buffers["res://../escape.luau"]="return 1";Check(Index.Submit(Request)==0,"Traversal buffers are refused before enqueue");
    Index.Cancel();
    uint64_t PeakProcessBytes=0;
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS Counters{};Counters.cb=sizeof(Counters);
    if(GetProcessMemoryInfo(GetCurrentProcess(),&Counters,sizeof(Counters)))PeakProcessBytes=Counters.PeakWorkingSetSize;
#else
    rusage Usage{};if(getrusage(RUSAGE_SELF,&Usage)==0)PeakProcessBytes=uint64_t(Usage.ru_maxrss)*1024;
#endif
    std::ofstream Metrics(Root/"results.json");
    Metrics<<"{\"Files\":"<<Cold->Files<<",\"SourceBytes\":"<<Cold->Bytes<<",\"SubmitMicroseconds\":"<<SubmitUs<<",\"ColdWorkerMicroseconds\":"<<Cold->Microseconds<<",\"WarmWorkerMicroseconds\":"<<Cached->Microseconds<<",\"CompletionMicroseconds\":"<<Interactive->Microseconds<<",\"WarmCompletionMicroseconds\":"<<InteractiveWarm->Microseconds<<",\"PeakProcessWorkingSetBytes\":"<<PeakProcessBytes<<"}\n";
    std::cout<<"[Editor:Index] MEASURE SubmitMicroseconds="<<SubmitUs<<" ColdWorkerMicroseconds="<<Cold->Microseconds<<" WarmWorkerMicroseconds="<<Cached->Microseconds<<" CompletionWorkerMicroseconds="<<Interactive->Microseconds<<" WarmCompletionWorkerMicroseconds="<<InteractiveWarm->Microseconds<<" Files="<<Cold->Files<<" Bytes="<<Cold->Bytes<<'\n';
    return 0;
}catch(const std::exception& Error){std::cerr<<"[Editor:Index] FAIL "<<Error.what()<<'\n';return 1;}
