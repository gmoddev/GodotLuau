#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <cstring>
#include <limits>
#include <new>

// Trusted development instrumentation. Records contain copied identifiers only,
// never Lua/native roots. Timings are inclusive protected-execution wall time.
inline unsigned GLNativeProfileCollectors=0;
enum class GLProfileEvent { Resume, ProtectedCall, Compile, ModuleCompile, Callback, Require, Coroutine };
struct GLScriptProfile {
    uint64_t Generation=0,NativeId=0,Resumes=0,ProtectedCalls=0,ExecutionNanoseconds=0;
    uint64_t Compilations=0,CompileNanoseconds=0,ModuleCompilations=0,Callbacks=0,Requires=0,Coroutines=0;
    std::string Source;
    bool Retired=false;
};
class GLProfiler {
    bool Enabled=false,Native=false,Truncated=false;
    uint64_t Epoch=0;
    std::map<uint64_t,GLScriptProfile> Scripts;
    std::map<std::string,uint64_t,std::less<>> NativeCalls;
    GLScriptProfile* Entry(uint64_t Generation,uint64_t NativeId) {
        auto Found=Scripts.find(Generation);
        if(Found==Scripts.end()) {
            if(Scripts.size()>=128){Truncated=true;return nullptr;}
            try {Found=Scripts.emplace(Generation,GLScriptProfile{}).first;}
            catch(const std::bad_alloc&){Truncated=true;return nullptr;}
            Found->second.Generation=Generation;Found->second.NativeId=NativeId;
        }
        return &Found->second;
    }
    static void Add(uint64_t& Target,uint64_t Value=1) {
        Target=Value>std::numeric_limits<uint64_t>::max()-Target?std::numeric_limits<uint64_t>::max():Target+Value;
    }
public:
    ~GLProfiler(){Stop();}
    void Start(bool NativeCallsEnabled=true) {
        Stop();++Epoch;Scripts.clear();NativeCalls.clear();Truncated=false;
        Enabled=true;Native=NativeCallsEnabled;if(Native)++GLNativeProfileCollectors;
    }
    void Stop(){if(Enabled && Native)--GLNativeProfileCollectors;Enabled=false;Native=false;}
    bool IsEnabled()const{return Enabled;}
    bool IsTruncated()const{return Truncated;}
    uint64_t GetEpoch()const{return Epoch;}
    const std::map<uint64_t,GLScriptProfile>& GetScripts()const{return Scripts;}
    const auto& GetNativeCalls()const{return NativeCalls;}
    void Define(uint64_t Generation,uint64_t NativeId,const std::string& Source) {
        if(Enabled)if(auto Row=Entry(Generation,NativeId)) {
            try {Row->Source=Source.substr(0,1024);if(Source.size()>1024)Truncated=true;}
            catch(const std::bad_alloc&){Truncated=true;}
        }
    }
    void Record(uint64_t Generation,uint64_t NativeId,GLProfileEvent Event,uint64_t Nanoseconds=0) {
        if(!Enabled)return;auto Row=Entry(Generation,NativeId);if(!Row)return;
        switch(Event) {
            case GLProfileEvent::Resume:Add(Row->Resumes);Add(Row->ExecutionNanoseconds,Nanoseconds);break;
            case GLProfileEvent::ProtectedCall:Add(Row->ProtectedCalls);Add(Row->ExecutionNanoseconds,Nanoseconds);break;
            case GLProfileEvent::Compile:Add(Row->Compilations);Add(Row->CompileNanoseconds,Nanoseconds);break;
            case GLProfileEvent::ModuleCompile:Add(Row->Compilations);Add(Row->ModuleCompilations);Add(Row->CompileNanoseconds,Nanoseconds);break;
            case GLProfileEvent::Callback:Add(Row->Callbacks);break;
            case GLProfileEvent::Require:Add(Row->Requires);break;
            case GLProfileEvent::Coroutine:Add(Row->Coroutines);break;
        }
    }
    void Retire(uint64_t Generation){if(Enabled){auto Found=Scripts.find(Generation);if(Found!=Scripts.end())Found->second.Retired=true;}}
    void NativeCall(const char* Category,const char* Class,const char* Member) {
        if(!Enabled || !Native)return;
        size_t Bytes=2;
        size_t Lengths[3];size_t Index=0;
        for(const char* Part:{Category,Class,Member}) {
            if(!Part){Truncated=true;return;}
            size_t Length=0;while(Length<=256 && Part[Length])++Length;
            Bytes+=Length;if(Bytes>256){Truncated=true;return;}
            Lengths[Index++]=Length;
        }
        char Buffer[256];size_t Offset=0;Index=0;
        for(const char* Part:{Category,Class,Member}) {
            std::memcpy(Buffer+Offset,Part,Lengths[Index]);Offset+=Lengths[Index];
            if(Index<2)Buffer[Offset++]=Index==0?':':'.';
            ++Index;
        }
        std::string_view Key(Buffer,Offset);
        try {
            auto Found=NativeCalls.find(Key);
            if(Found==NativeCalls.end()) {if(NativeCalls.size()>=256){Truncated=true;return;}Found=NativeCalls.emplace(std::string(Key),0).first;}
            Add(Found->second);
        } catch(const std::bad_alloc&){Truncated=true;}
    }
};
struct lua_State;
void GLRecordNativeProfile(lua_State* Thread,const char* Category,const char* Class,const char* Member);
