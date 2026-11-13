#pragma once
#include "gl_profiler.h"
struct lua_State;
#ifdef GL_RUNTIME_TESTS
// Optional, bounded invocation evidence. Never a gameplay capability or a
// substitute for fixture assertions. SCons products contain no coverage recorder.
void GLCoverageNative(lua_State* Thread,const char* Category,const char* Class,const char* Member);
void GLDumpNativeTrace();
#else
inline void GLDumpNativeTrace() {}
#endif
inline void GLTraceNative(lua_State* Thread,const char* Category,const char* Class,const char* Member) {
    if(GLNativeProfileCollectors)GLRecordNativeProfile(Thread,Category,Class,Member);
#ifdef GL_RUNTIME_TESTS
    GLCoverageNative(Thread,Category,Class,Member);
#endif
}
