#ifndef GL_DATASTORE_PROTOCOL_H
#define GL_DATASTORE_PROTOCOL_H
#include <cstdint>
#include <string>
#include <cstring>
namespace GLDataStoreProtocol {
constexpr uint32_t MaxData=16*1024*1024;
constexpr char Magic[]="GLDS0091";
enum class Status : uint32_t { Ok, Conflict, Busy, Unavailable, Invalid, Denied, IO, Limit, Durability, Indeterminate };
enum class Operation : uint32_t { Read, Set, Compare };
struct Request {
    std::string Root,Leaf,Expected,Data;
    Operation Op=Operation::Read;
    bool Exists=false;
};
struct Result { Status Code=Status::Ok; bool Exists=false; std::string Data; };
inline void Number(std::string& Buffer,uint32_t Value) {
    for (unsigned Index=0;Index<4;++Index) Buffer.push_back(char(Value>>(Index*8)));
}
inline uint32_t Number(const char* Bytes) {
    uint32_t Value=0;
    for (unsigned Index=0;Index<4;++Index) Value|=uint32_t(uint8_t(Bytes[Index]))<<(Index*8);
    return Value;
}
inline std::string Encode(const Request& Value) {
    std::string Bytes(Magic,8);
    for (uint32_t Size:{uint32_t(Value.Root.size()),uint32_t(Value.Leaf.size()),uint32_t(Value.Expected.size()),uint32_t(Value.Data.size()),uint32_t(Value.Op),uint32_t(Value.Exists)}) Number(Bytes,Size);
    return Bytes+Value.Root+Value.Leaf+Value.Expected+Value.Data;
}
inline std::string Encode(const Result& Value) {
    std::string Bytes(Magic,8);
    for (uint32_t Size:{uint32_t(Value.Code),uint32_t(Value.Exists),uint32_t(Value.Data.size()),0u}) Number(Bytes,Size);
    return Bytes+Value.Data;
}
}
#endif
