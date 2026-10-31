#ifndef GL_UUID_H
#define GL_UUID_H
#include <array>
#include <cstdint>
#include <string>

// RFC 9562 version 4 / RFC variant formatting. Randomness is supplied by the
// engine Crypto provider; this helper owns no generator or process state.
inline std::string FormatGLUuid(std::array<uint8_t,16> Bytes,bool Braces) {
    Bytes[6]=uint8_t((Bytes[6]&0x0f)|0x40);
    Bytes[8]=uint8_t((Bytes[8]&0x3f)|0x80);
    static constexpr char Hex[]="0123456789abcdef";
    std::string Result;
    Result.reserve(Braces?38:36);
    if (Braces) Result.push_back('{');
    for (size_t Index=0;Index<Bytes.size();++Index) {
        if (Index==4 || Index==6 || Index==8 || Index==10) Result.push_back('-');
        Result.push_back(Hex[Bytes[Index]>>4]); Result.push_back(Hex[Bytes[Index]&15]);
    }
    if (Braces) Result.push_back('}');
    return Result;
}
#endif
