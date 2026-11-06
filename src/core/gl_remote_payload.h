#ifndef GL_REMOTE_PAYLOAD_H
#define GL_REMOTE_PAYLOAD_H

// GL-029 event-only codec. RemoteFunction/replication retain their existing
// Variant contract. Container counts are checked before allocation/iteration;
// no Godot object decoder or arbitrary Variant decoder processes event bytes.
#include "gl_net_bridge.h"
#include <cmath>
#include <limits>

namespace GLRemotePayload {
constexpr int MaxBytes = 65536;
constexpr int MaxNodes = 4096;
constexpr int MaxArguments = 64;
constexpr int MaxDepth = 16;
constexpr int UnreliableBytes = 768; // Body + 40-byte identity header; leaves RPC/ENet overhead.
constexpr uint32_t Magic = 0x32524547; // GER2: explicit event protocol, including a native sequence.
constexpr int HeaderBytes = 48;
constexpr int RpcAllowance = 384; // Qualified full-RPC allowance with NetworkService path <=256 UTF-8 bytes.

inline bool ValidUtf8(const char* Text, size_t Length) {
    for (size_t Index = 0; Index < Length;) {
        uint32_t First = uint8_t(Text[Index++]), Code = First;
        int Remaining = 0; uint32_t Minimum = 0;
        if (!First) return false;
        if (First < 0x80) continue;
        if (First >= 0xc2 && First <= 0xdf) { Remaining = 1; Code &= 31; Minimum = 0x80; }
        else if (First >= 0xe0 && First <= 0xef) { Remaining = 2; Code &= 15; Minimum = 0x800; }
        else if (First >= 0xf0 && First <= 0xf4) { Remaining = 3; Code &= 7; Minimum = 0x10000; }
        else return false;
        if (Length - Index < size_t(Remaining)) return false;
        while (Remaining--) {
            uint8_t Next = uint8_t(Text[Index++]); if ((Next & 0xc0) != 0x80) return false;
            Code = (Code << 6) | (Next & 63);
        }
        if (Code < Minimum || Code > 0x10ffff || (Code >= 0xd800 && Code <= 0xdfff)) return false;
    }
    return true;
}
inline bool SupportedType(const String& Name) {
    for (const char* Type : {"Vector2", "CFrame", "UDim", "UDim2", "Ray", "NumberRange", "Vector3int16", "Vector2int16", "Faces", "Axes",
        "PhysicalProperties", "DateTime", "Region3", "Rect", "NumberSequence", "ColorSequence", "NumberSequenceKeypoint", "ColorSequenceKeypoint", "BrickColor"})
        if (Name == Type) return true;
    return false;
}

inline bool CheckLua(lua_State* State, int Index, int& Nodes, size_t& Bytes, int Depth = 0) {
    if (++Nodes > MaxNodes || Depth >= MaxDepth || !lua_checkstack(State, 6)) return false;
    Index = lua_absindex(State, Index);
    switch (lua_type(State, Index)) {
        case LUA_TNIL: case LUA_TBOOLEAN: return true;
        case LUA_TNUMBER: {
            double Value = lua_tonumber(State, Index);
            return std::isfinite(Value); // Event encoder range-checks before any int64 conversion.
        }
        case LUA_TSTRING: {
            size_t Length = 0; const char* Text = lua_tolstring(State, Index, &Length);
            if (Length > MaxBytes || Bytes > MaxBytes - Length || !ValidUtf8(Text, Length)) return false;
            Bytes += Length; return true;
        }
        case LUA_TUSERDATA: {
            if (!lua_getmetatable(State, Index)) return false;
            bool Valid = false;
            for (const char* Name : {"GodotObject", "Vector3", "Color3"}) {
                luaL_getmetatable(State, Name); bool Match = lua_rawequal(State, -1, -2); lua_pop(State, 1);
                if (Match) {
                    Valid = true;
                    if (!strcmp(Name, "GodotObject")) {
                        auto Wrapper = static_cast<GodotObjectWrapper*>(lua_touserdata(State, Index));
                        Node* ObjectValue = Wrapper ? gow_node(Wrapper) : nullptr;
                        Valid = ObjectValue && ObjectValue->is_inside_tree() && !ObjectValue->is_queued_for_deletion();
                    }
                    break;
                }
            }
            lua_pop(State, 1); return Valid;
        }
        case LUA_TTABLE: {
            lua_pushnil(State);
            while (lua_next(State, Index)) {
                bool Valid = (lua_type(State, -2) == LUA_TSTRING || lua_type(State, -2) == LUA_TNUMBER) &&
                    CheckLua(State, -2, Nodes, Bytes, Depth + 1) && CheckLua(State, -1, Nodes, Bytes, Depth + 1);
                lua_pop(State, 1);
                if (!Valid) { lua_pop(State, 1); return false; }
            }
            // Inspect __type without calling a metatable metamethod.
            if (lua_getmetatable(State, Index)) {
                lua_pushstring(State, "__type"); lua_rawget(State, -2);
                bool Valid = lua_isnil(State, -1) || (lua_type(State, -1) == LUA_TSTRING && CheckLua(State, -1, Nodes, Bytes) && SupportedType(String::utf8(lua_tostring(State, -1))));
                lua_pop(State, 2); if (!Valid) return false;
            }
            return true;
        }
        default: return false;
    }
}

struct Codec {
    PackedByteArray Bytes;
    int Position = 0, Nodes = 0;
    bool Valid = true;
    bool Reading = false;

    bool Space(int Count) {
        if (!Valid || Count < 0 || Position > MaxBytes - Count || (Reading && Position > Bytes.size() - Count)) {
            Valid = false; return false;
        }
        if (!Reading && Position + Count > Bytes.size()) Bytes.resize(Position + Count);
        return true;
    }
    uint64_t Word(uint64_t Value = 0, int Width = 8) {
        if (!Space(Width)) return 0;
        if (Reading) {
            Value = 0;
            for (int Index = 0; Index < Width; ++Index) Value |= uint64_t(Bytes[Position++]) << (8 * Index);
        } else for (int Index = 0; Index < Width; ++Index) Bytes.set(Position++, uint8_t(Value >> (8 * Index)));
        return Value;
    }
    double Number(double Value = 0) {
        uint64_t Bits = 0; memcpy(&Bits, &Value, 8); Bits = Word(Bits); memcpy(&Value, &Bits, 8);
        if (!std::isfinite(Value)) Valid = false;
        return Value;
    }
    Variant Value(const Variant& Input = Variant(), int Depth = 0) {
        if (++Nodes > MaxNodes || Depth >= MaxDepth) { Valid = false; return Variant(); }
        int Tag = Reading ? int(Word(0, 1)) : int(Input.get_type());
        if (!Reading) Word(Tag, 1);
        switch (Tag) {
            case Variant::NIL: return Variant();
            case Variant::BOOL: {
                uint64_t Boolean = Word(Reading ? 0 : uint64_t(bool(Input)), 1);
                if (Boolean > 1) Valid = false;
                return bool(Boolean);
            }
            case Variant::INT: return int64_t(Word(Reading ? 0 : uint64_t(int64_t(Input))));
            case Variant::FLOAT: return Number(Reading ? 0 : double(Input));
            case Variant::STRING: {
                CharString Text = (Reading ? String() : String(Input)).utf8();
                int Length = int(Word(Reading ? 0 : Text.length(), 4));
                if (!Space(Length)) return Variant();
                String Result;
                if (Reading) {
                    if (!ValidUtf8(reinterpret_cast<const char*>(Bytes.ptr() + Position), Length)) { Valid = false; return Variant(); }
                    Result = String::utf8(reinterpret_cast<const char*>(Bytes.ptr() + Position), Length);
                    CharString RoundTrip = Result.utf8();
                    if (RoundTrip.length() != Length || memcmp(RoundTrip.get_data(), Bytes.ptr() + Position, Length)) Valid = false;
                } else memcpy(Bytes.ptrw() + Position, Text.get_data(), Length);
                Position += Length; return Reading ? Result : String(Input);
            }
            case Variant::VECTOR3: {
                Vector3 Vector = Reading ? Vector3() : Vector3(Input);
                double X = Number(Vector.x), Y = Number(Vector.y), Z = Number(Vector.z);
                Vector3 Result(X, Y, Z); if (!Result.is_finite()) Valid = false; return Result;
            }
            case Variant::COLOR: {
                Color Colour = Reading ? Color() : Color(Input);
                double R = Number(Colour.r), G = Number(Colour.g), B = Number(Colour.b), A = Number(Colour.a);
                if (std::abs(R) > std::numeric_limits<float>::max() || std::abs(G) > std::numeric_limits<float>::max() ||
                    std::abs(B) > std::numeric_limits<float>::max() || std::abs(A) > std::numeric_limits<float>::max()) Valid = false;
                return Color(R, G, B, A);
            }
            case Variant::ARRAY: {
                Array Result, Source = Reading ? Array() : Array(Input);
                int Count = int(Word(Reading ? 0 : Source.size(), 4));
                if (Count < 0 || Count > MaxNodes - Nodes) { Valid = false; return Variant(); }
                for (int Index = 0; Index < Count && Valid; ++Index) Result.push_back(Value(Reading ? Variant() : Source[Index], Depth + 1));
                return Result;
            }
            case Variant::DICTIONARY: {
                Dictionary Result, Source = Reading ? Dictionary() : Dictionary(Input);
                Array Keys = Source.keys();
                int Count = int(Word(Reading ? 0 : Keys.size(), 4));
                if (Count < 0 || Count > (MaxNodes - Nodes) / 2) { Valid = false; return Variant(); }
                for (int Index = 0; Index < Count && Valid; ++Index) {
                    Variant Key = Value(Reading ? Variant() : Keys[Index], Depth + 1);
                    if (Key.get_type() != Variant::INT && Key.get_type() != Variant::FLOAT && Key.get_type() != Variant::STRING) {
                        Valid = false; break;
                    }
                    Variant Item = Value(Reading ? Variant() : Source[Keys[Index]], Depth + 1);
                    if (Result.has(Key)) { Valid = false; break; }
                    Result[Key] = Item;
                }
                return Result;
            }
            default: Valid = false; return Variant();
        }
    }
};
}
#endif
