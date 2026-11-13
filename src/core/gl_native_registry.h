#ifndef GL_NATIVE_REGISTRY_H
#define GL_NATIVE_REGISTRY_H

// Immutable metadata, never native object ownership or a runtime capability.
namespace GLNative {
enum Kind { Number, Integer, Boolean, Text, Vector, Vector2Value, Colour, ResourceValue, Void,
    NodeValue, Vector2Integer, Vector3Integer, Vector4Value, Vector4Integer,
    Rectangle, RectangleInteger, Rotation, BasisValue, Transform2Value, Transform3Value,
    PlaneValue, BoundsValue, Colour4, VariantValue, ArrayValue, DictionaryValue,
    BytesValue, IntegersValue, LongsValue, FloatsValue, DoublesValue, StringsValue,
    Vectors2Value, Vectors3Value, ColoursValue, Vectors4Value, PathValue };
struct Property {
    const char* Class;
    const char* Name;
    const char* Native;
    Kind Type;
    double Min = 0;
    double Max = 0;
    const char* ResourceClass = nullptr;
    const char* Default = nullptr;
    bool ReadOnly = false;
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
    const char* CountQuery = nullptr;
    int IndexArgument = -1;
    bool AllowEnd = false;
    bool AllowNegativeOne = false;
    const char* KeyQuery = nullptr;
    int KeyArgument = -1;
    bool KeyAbsent = false;
    int CountArgument = -1;
    int CountLimit = -1;
};
struct Signal { const char* Class; const char* Name; const char* Native; int FirstArgument; int Arguments; };
struct Constant { const char* Class; const char* Enum; const char* Name; int Value; };
struct Operation { const char* Name; const char* Signature; };
}
#endif
