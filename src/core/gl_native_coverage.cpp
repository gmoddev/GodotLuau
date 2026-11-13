#include "gl_native_coverage.h"
#ifdef GL_RUNTIME_TESTS
#include "gl_execution_domain.h"
#include "gl_native_registry.gen.h"
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <sstream>
#include <iomanip>
#include <limits>
namespace {
bool Enabled() {
    static const bool Selected=[] {const char* Flag=std::getenv("GL_NATIVE_COVERAGE");return Flag && !std::strcmp(Flag,"1");}();
    return Selected;
}
std::map<std::string,uint32_t> Counts;
bool Truncated=false;
}
void GLTraceNative(lua_State* Thread,const char* Category,const char* Class,const char* Member) {
    if (!Enabled()) return;
    auto Owner=GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || !Owner->Domain) return;
    const char* Domain=Owner->Domain->GetKind()==GLDomainKind::Server?"Server":Owner->Domain->GetKind()==GLDomainKind::Client?"Client":"EditorPreview";
    std::string Key=std::string(Domain)+":"+Category+":"+Class+"."+Member;
    auto Found=Counts.find(Key);
    if (Found==Counts.end()) {
        if (Counts.size()>=32768) {Truncated=true;return;}
        Found=Counts.emplace(std::move(Key),0).first;
    }
    if (Found->second<std::numeric_limits<uint32_t>::max()) ++Found->second;
}
void GLDumpNativeTrace() {
    if (!Enabled()) return;
    std::ostringstream Output;
    Output<<"[Bindings:Coverage] {\"Schema\":1,\"PolicySHA256\":"<<std::quoted(GLNative::PolicySHA256)
        <<",\"ApiSHA256\":"<<std::quoted(GLNative::ApiSHA256)<<",\"Truncated\":"<<(Truncated?"true":"false")<<",\"Counts\":{";
    bool First=true;
    for(const auto& Entry:Counts) {if(!First)Output<<',';First=false;Output<<std::quoted(Entry.first)<<':'<<Entry.second;}
    Output<<"}}\n";
    auto Text=Output.str();std::fwrite(Text.data(),1,Text.size(),stdout);std::fflush(stdout);
    Counts.clear();Truncated=false;
}
#endif
