#ifndef GL_NATIVE_REGISTRY_H
#define GL_NATIVE_REGISTRY_H

// Immutable metadata, never native object ownership or a runtime capability.
namespace GLNative {
enum Kind { Number, Integer, Boolean, Text, Vector, Vector2Value, Colour, ResourceValue, Void };
struct Property {
    const char* Class;
    const char* Name;
    const char* Native;
    Kind Type;
    double Min = 0;
    double Max = 0;
    const char* ResourceClass = nullptr;
};
struct Class { const char* Name; const char* Base; bool Construct; bool Resource; };
struct Method {
    const char* Class;
    const char* Name;
    const char* Native;
    bool Mutates;
    int FirstArgument;
    int Arguments;
    int Required;
    Kind Return;
    const char* ReturnClass;
};
struct Signal { const char* Class; const char* Name; const char* Native; int FirstArgument; int Arguments; };
struct Constant { const char* Class; const char* Enum; const char* Name; int Value; };
struct Operation { const char* Name; const char* Signature; };
}
#endif
