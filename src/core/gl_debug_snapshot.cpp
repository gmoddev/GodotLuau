#include "gl_debug_snapshot.h"
#include "gl_execution_domain.h"
#include "lua.h"
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <cstring>
#include <cmath>

using namespace godot;
namespace {
String Text(const char* Value,size_t Limit) {
    return Value?String::utf8(Value,int((std::min)(std::strlen(Value),Limit))):String();
}
}
Dictionary GLCaptureErrorSnapshot(lua_State* Thread) {
    Dictionary Snapshot;
    auto Owner=GLGetOwner(Thread);
    if(!Owner || !Owner->Alive || !Owner->Domain || Owner->Domain->HasMemoryFailure())return Snapshot;
    Snapshot["Schema"]=1;
    Snapshot["Mode"]="Error-time snapshot; execution is not suspended";
    Snapshot["Domain"]=Owner->Domain->GetKind()==GLDomainKind::Server?"Server":Owner->Domain->GetKind()==GLDomainKind::Client?"Client":"EditorPreview";
    Snapshot["Generation"]=int64_t(Owner->Token);
    Snapshot["FullDebugInfo"]=Owner->Domain->HasDebugInfo();
    Array Frames;
    const int Top=lua_gettop(Thread);
    if(lua_checkstack(Thread,4))for(int Level=0;Level<16;++Level) {
        lua_Debug Frame{};
        if(!lua_getinfo(Thread,Level,"sln",&Frame))break;
        Dictionary Entry;Entry["Function"]=Text(Frame.name,128);Entry["Line"]=Frame.currentline;
        String Source=Text(Frame.source,1024);if(Source.begins_with("@"))Source=Source.substr(1);
        Entry["Source"]=Source;Array Locals;
        for(int Index=1;Index<=8;++Index) {
            const char* Name=lua_getlocal(Thread,Level,Index);
            if(!Name)break;
            Dictionary Local;Local["Name"]=Text(Name,128);int Type=lua_type(Thread,-1);
            Local["Type"]=Text(lua_typename(Thread,Type),32);
            if(Type==LUA_TSTRING) {
                size_t Bytes=0;const char* Value=lua_tolstring(Thread,-1,&Bytes);
                Local["Value"]=String::utf8(Value,int((std::min)(Bytes,size_t(256))));Local["Truncated"]=Bytes>256;
            } else if(Type==LUA_TNUMBER) {
                double Value=lua_tonumber(Thread,-1);
                Local["Value"]=std::isfinite(Value)?Variant(Value):Variant(String("non-finite number"));
            } else if(Type==LUA_TBOOLEAN)Local["Value"]=bool(lua_toboolean(Thread,-1));
            else if(Type==LUA_TNIL)Local["Value"]=Variant();
            else Local["Value"]="opaque; no object or table traversal";
            lua_pop(Thread,1);Locals.push_back(Local);
        }
        Entry["Locals"]=Locals;Frames.push_back(Entry);
    }
    lua_settop(Thread,Top);
    Snapshot["Frames"]=Frames;Snapshot["FrameLimit"]=16;Snapshot["LocalsPerFrameLimit"]=8;
    return Snapshot;
}
