#pragma once
struct lua_State;
#ifdef GL_RUNTIME_TESTS
// Optional, bounded invocation evidence. Never a gameplay capability or a
// substitute for fixture assertions. SCons products contain no recorder.
void GLTraceNative(lua_State* Thread,const char* Category,const char* Class,const char* Member);
void GLDumpNativeTrace();
#else
inline void GLTraceNative(lua_State*,const char*,const char*,const char*) {}
inline void GLDumpNativeTrace() {}
#endif
