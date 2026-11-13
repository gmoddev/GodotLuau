#include "gl_debug_inspection.h"
#include "gl_debugger.h"
#include "gl_execution_domain.h"
#include "lua.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <map>

using namespace godot;
bool GLDebugText(const char* Value,size_t Length,size_t Maximum,String& Result) {
    size_t Size=(std::min)(Length,Maximum);
    while(Size && Size<Length && (static_cast<unsigned char>(Value[Size])&0xc0)==0x80)--Size;
    for(size_t Index=0;Index<Size;) {
        unsigned char First=Value[Index++];if(First<0x80){if(!First)return false;continue;}
        int Extra=First>=0xc2 && First<=0xdf?1:First>=0xe0 && First<=0xef?2:First>=0xf0 && First<=0xf4?3:-1;
        if(Extra<0 || Index+Extra>Size)return false;
        for(int Offset=0;Offset<Extra;++Offset) {
            unsigned char Next=Value[Index++];if((Next&0xc0)!=0x80)return false;
            if(Offset==0 && ((First==0xe0 && Next<0xa0) || (First==0xed && Next>=0xa0) ||
                (First==0xf0 && Next<0x90) || (First==0xf4 && Next>=0x90)))return false;
        }
    }
    Result=String::utf8(Value,int(Size));return true;
}
namespace {
Dictionary Restricted(const char* Reason) {
    Dictionary Value;Value["Kind"]="Restricted";Value["Reason"]=Reason;Value["Preview"]="<redacted>";return Value;
}
bool Redacted(const String& Name) {
    auto Lower = Name.to_lower();
    for (const char* Key : {"password", "secret", "authorization", "access_token", "accesstoken", "api_key", "apikey", "privatekey"})
        if (Lower.contains(Key)) return true;
    return false;
}
String NameText(const char* Value) {
    size_t Length=0;if(Value)while(Length<128 && Value[Length])++Length;
    return Value?String::utf8(Value,int(Length)):String();
}
struct Reader {
    int Remaining = 256, Items = 32, Depth = 3, NativeRemaining = 4;
    size_t Bytes = 16384;
    std::map<const void*, int> Seen;
    String Text(const char* Value, size_t Length, size_t Maximum = 512) {
        size_t Size = (std::min)({Length, Maximum, Bytes}); Bytes -= Size;
        String Result;return GLDebugText(Value,Length,Size,Result)?Result:String("<binary key/name>");
    }
    Variant Copy(lua_State* Thread, int Index, int Level = 0) {
        if (--Remaining < 0 || !Bytes) return Restricted("Inspection work or string budget");
        if (Index < 0) Index = lua_gettop(Thread) + Index + 1;
        switch (lua_type(Thread, Index)) {
            case LUA_TNIL: return Variant();
            case LUA_TBOOLEAN: return bool(lua_toboolean(Thread, Index));
            case LUA_TNUMBER: { double Value = lua_tonumber(Thread, Index); return std::isfinite(Value) ? Variant(Value) : Variant(String("<non-finite>")); }
            case LUA_TSTRING: {
                size_t Length=0;auto Value=lua_tolstring(Thread,Index,&Length);String Result;
                size_t Maximum=(std::min)(size_t(512),Bytes);Bytes-=(std::min)(Length,Maximum);
                bool Valid=GLDebugText(Value,Length,Maximum,Result);
                if(!Valid || Length>Maximum) {
                    Dictionary Preview;Preview["Kind"]="StringPreview";Preview["Text"]=Valid?Result:String("<binary string>");
                    Preview["Length"]=int64_t(Length);Preview["Truncated"]=Length>Maximum;Preview["Binary"]=!Valid;return Preview;
                }
                return Result;
            }
            case LUA_TTABLE: {
                const void* Identity = lua_topointer(Thread, Index); auto Found = Seen.find(Identity);
                if (Found != Seen.end()) { Dictionary Reference; Reference["Reference"] = Found->second; return Reference; }
                int IdentityNumber = int(Seen.size()) + 1; Seen.emplace(Identity, IdentityNumber);
                Dictionary Table; Table["Kind"] = "Table"; Table["Identity"] = IdentityNumber;Table["Length"]=int64_t(lua_objlen(Thread,Index));
                if (Level >= Depth) { Table["Truncated"] = true; return Table; }
                Array Entries; int Count = 0; bool More = false;
                lua_pushnil(Thread);
                while (lua_next(Thread, Index)) {
                    if (Count++ >= Items || Remaining <= 1 || !Bytes) { lua_pop(Thread, 2); More = true; break; }
                    Dictionary Entry; Variant Key;
                    if (lua_type(Thread, -2) == LUA_TSTRING) { size_t Length=0; auto Data=lua_tolstring(Thread,-2,&Length); Key=Text(Data,Length,128); }
                    else if (lua_type(Thread, -2) == LUA_TNUMBER) Key=lua_tonumber(Thread,-2);
                    else Key=String("<restricted key>");
                    Entry["Key"] = Key;
                    Entry["Value"] = Key.get_type()==Variant::STRING && Redacted(Key) ? Variant(Restricted("Sensitive name")) : Copy(Thread,-1,Level+1);
                    Entries.push_back(Entry); lua_pop(Thread,1);
                }
                Table["Entries"] = Entries; Table["Truncated"] = More; return Table;
            }
            case LUA_TUSERDATA:
                if (--NativeRemaining<0 || Bytes<4096) return Restricted("Native projection budget");
                Bytes-=4096; return GLDebugSceneHandle(Thread, Index);
            default: return Restricted(lua_typename(Thread,lua_type(Thread,Index)));
        }
    }
};
}
Variant GLDebugCopyValue(lua_State* Thread, int Index, int MaxItems, int MaxDepth) {
    if (!Thread || !lua_checkstack(Thread,32)) return String("<inspection unavailable>");
    Reader Read; Read.Items=(std::clamp)(MaxItems,1,64); Read.Depth=(std::clamp)(MaxDepth,0,4);
    return Read.Copy(Thread,Index);
}
Dictionary GLDebugVariables(int Level, int MaxItems, int MaxDepth, bool Upvalues) {
    Dictionary Result; PackedStringArray Names; Array Values;
    auto Debugger=GLGetSuspendedDebugger(); auto Thread=Debugger?Debugger->GetInspectionThread():nullptr;
    const char* Key=Upvalues?"members":"locals";
    Result[Key]=Names; Result["values"]=Values;
    if (!Thread || !Debugger->IsFrameInspectable(Thread,Level) || !lua_checkstack(Thread,32)) return Result;
    lua_Debug FrameKind{};
    if(!lua_getinfo(Thread,Level,"s",&FrameKind) || !FrameKind.what || !std::strcmp(FrameKind.what,"C"))return Result;
    Reader Read; Read.Items=MaxItems<0?32:(std::clamp)(MaxItems,1,64); Read.Depth=MaxDepth<0?3:(std::clamp)(MaxDepth,0,4);
    int Top=lua_gettop(Thread);
    auto Add=[&](const String& Name) {
        Names.push_back(Name.left(128)); Values.push_back(Redacted(Name)?Variant(Restricted("Sensitive name")):Read.Copy(Thread,-1)); lua_pop(Thread,1);
    };
    if (Upvalues) {
        lua_Debug Frame{};
        if (lua_getinfo(Thread,Level,"f",&Frame)) for (int Index=1;Index<=32 && Read.Remaining>0;++Index) {
            const char* Name=lua_getupvalue(Thread,-1,Index); if(!Name)break;
            Add(String("upvalue: ")+NameText(Name));
        }
    } else {
        for (int Index=1;Index<=64 && Read.Remaining>0;++Index) {
            const char* Name=lua_getlocal(Thread,Level,Index); if(!Name)break;
            Add(NameText(Name));
        }
        for (int Index=1;Index<=16 && Read.Remaining>0;++Index) {
            const char* RawName=lua_getlocal(Thread,Level,Index);
            String Name=RawName?NameText(RawName):String::num_int64(Index);
            if(RawName)lua_pop(Thread,1);
            if (!lua_getargument(Thread,Level,Index)) break;
            Add(String("argument: ")+Name);
        }
    }
    lua_settop(Thread,Top);
    Result[Key]=Names; Result["values"]=Values; return Result;
}
Dictionary GLDebugContext() {
    Dictionary Result; auto Debugger=GLGetSuspendedDebugger();
    if(!Debugger || !Debugger->GetInspectionThread()) return Result;
    Result["Domain"]=Debugger->GetDomain().GetKind()==GLDomainKind::Server?"Server":"Client";
    Result["Generation"]=int64_t(Debugger->GetGeneration()); Result["StopId"]=int64_t(Debugger->GetStopId());
    Result["CoroutineId"]=int64_t(Debugger->GetCoroutineId());
    Result["State"]="Suspended"; Result["Reason"]=String::utf8(Debugger->GetReason().c_str());
    return Result;
}
