#include "gl_native_values.h"
#include "luau_value_bindings.h"
#include "luau_variant_bindings.h"
#include "lua.h"
#include "lualib.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <cmath>
#include <cstring>
#include <vector>

using namespace godot;
using namespace GLNative;
namespace {
constexpr int MaxDepth=8, MaxCells=4096, MaxCollection=1024, MaxText=8192;
struct ValueType { Kind Type; const char* Name; Variant::Type Native; };
const ValueType ValueTypes[]={
    {Vector2Integer,"Vector2i",Variant::VECTOR2I},{Vector3Integer,"Vector3i",Variant::VECTOR3I},
    {Vector4Value,"Vector4",Variant::VECTOR4},{Vector4Integer,"Vector4i",Variant::VECTOR4I},
    {Rectangle,"Rect2",Variant::RECT2},{RectangleInteger,"Rect2i",Variant::RECT2I},
    {Rotation,"Quaternion",Variant::QUATERNION},{BasisValue,"Basis",Variant::BASIS},
    {Transform2Value,"Transform2D",Variant::TRANSFORM2D},{Transform3Value,"Transform3D",Variant::TRANSFORM3D},
    {PlaneValue,"Plane",Variant::PLANE},{BoundsValue,"AABB",Variant::AABB},
    {Colour4,"Color",Variant::COLOR},{VariantValue,"Variant",Variant::NIL},
    {ArrayValue,"Array",Variant::ARRAY},{DictionaryValue,"Dictionary",Variant::DICTIONARY},
    {BytesValue,"PackedByteArray",Variant::PACKED_BYTE_ARRAY},{IntegersValue,"PackedInt32Array",Variant::PACKED_INT32_ARRAY},
    {LongsValue,"PackedInt64Array",Variant::PACKED_INT64_ARRAY},{FloatsValue,"PackedFloat32Array",Variant::PACKED_FLOAT32_ARRAY},
    {DoublesValue,"PackedFloat64Array",Variant::PACKED_FLOAT64_ARRAY},{StringsValue,"PackedStringArray",Variant::PACKED_STRING_ARRAY},
    {Vectors2Value,"PackedVector2Array",Variant::PACKED_VECTOR2_ARRAY},{Vectors3Value,"PackedVector3Array",Variant::PACKED_VECTOR3_ARRAY},
    {ColoursValue,"PackedColorArray",Variant::PACKED_COLOR_ARRAY},{Vectors4Value,"PackedVector4Array",Variant::PACKED_VECTOR4_ARRAY},
    {Vector2Value,"Vector2",Variant::VECTOR2},{GLNative::Vector,"Vector3",Variant::VECTOR3},
    {PathValue,"NodePath",Variant::NODE_PATH}
};
Array Elements(const Variant& Value) {
    switch(Value.get_type()) {
#define GL_ELEMENTS(Type, Class) case Variant::Type:return Array(Class(Value));
        GL_ELEMENTS(PACKED_BYTE_ARRAY,PackedByteArray)
        GL_ELEMENTS(PACKED_INT32_ARRAY,PackedInt32Array)
        GL_ELEMENTS(PACKED_INT64_ARRAY,PackedInt64Array)
        GL_ELEMENTS(PACKED_FLOAT32_ARRAY,PackedFloat32Array)
        GL_ELEMENTS(PACKED_FLOAT64_ARRAY,PackedFloat64Array)
        GL_ELEMENTS(PACKED_STRING_ARRAY,PackedStringArray)
        GL_ELEMENTS(PACKED_VECTOR2_ARRAY,PackedVector2Array)
        GL_ELEMENTS(PACKED_VECTOR3_ARRAY,PackedVector3Array)
        GL_ELEMENTS(PACKED_COLOR_ARRAY,PackedColorArray)
        GL_ELEMENTS(PACKED_VECTOR4_ARRAY,PackedVector4Array)
#undef GL_ELEMENTS
        default:return Array(Value);
    }
}
bool NumberAt(lua_State* Thread,int Index,const char* Field,double& Number,const Property& Item,bool Integer=false) {
    lua_rawgetfield(Thread,Index,Field);
    bool Valid=lua_type(Thread,-1)==LUA_TNUMBER;
    Number=lua_tonumber(Thread,-1);lua_pop(Thread,1);
    return Valid && std::isfinite(Number) && Number>=Item.Min && Number<=Item.Max &&
        (!Integer || (Number==std::floor(Number) && Number>=INT32_MIN && Number<=INT32_MAX));
}
bool Read(lua_State*,const Property&,int,Variant&,int,int&,std::vector<const void*>&);
bool Field(lua_State* Thread,const Property& Item,int Index,const char* Name,Kind Type,Variant& Result,int Depth,int& Cells,std::vector<const void*>& Seen) {
    lua_rawgetfield(Thread,Index,Name);Property Child=Item;Child.Type=Type;
    bool Valid=Read(Thread,Child,lua_gettop(Thread),Result,Depth+1,Cells,Seen);lua_pop(Thread,1);return Valid;
}
bool TextAt(lua_State* Thread,int Index,String& Result,int Maximum=MaxText) {
    if (lua_type(Thread,Index)!=LUA_TSTRING) return false;
    size_t Size=0;const char* Text=lua_tolstring(Thread,Index,&Size);
    if (Size>size_t(Maximum) || std::memchr(Text,0,Size)) return false;
    Result=String::utf8(Text,int64_t(Size));return true;
}
bool Read(lua_State* Thread,const Property& Item,int Index,Variant& Result,int Depth,int& Cells,std::vector<const void*>& Seen) {
    if (Depth>MaxDepth || ++Cells>MaxCells) return false;
    if (Index<0) Index=lua_gettop(Thread)+1+Index;
    if (Item.Type==VariantValue) {
        switch (lua_type(Thread,Index)) {
            case LUA_TNIL: Result=Variant();return true;
            case LUA_TBOOLEAN: Result=bool(lua_toboolean(Thread,Index));return true;
            case LUA_TNUMBER: {
                double N=lua_tonumber(Thread,Index);if (!std::isfinite(N) || std::abs(N)>1e12) return false;
                Result=N;return true;
            }
            case LUA_TSTRING: {String Text;if (!TextAt(Thread,Index,Text)) return false;Result=Text;return true;}
            case LUA_TTABLE: {
                lua_rawgetfield(Thread,Index,"__NativeType");String Tag;bool Tagged=TextAt(Thread,-1,Tag,64);bool Invalid=!lua_isnil(Thread,-1)&&!Tagged;lua_pop(Thread,1);
                if (Invalid) return false;
                Property Typed=Item;
                if (Tagged) {Typed.Type=GLNativeValueKind(Tag.utf8().get_data());if (Typed.Type==Void || Typed.Type==VariantValue) return false;}
                else Typed.Type=lua_objlen(Thread,Index)>0?ArrayValue:DictionaryValue;
                return Read(Thread,Typed,Index,Result,Depth+1,Cells,Seen);
            }
            case LUA_TUSERDATA:
                if (auto V=check_vector3(Thread,Index)) {Result=Vector3(V->x,V->y,V->z);return GLValidNativeValue(Item,Result);}
                if (auto V=check_color3(Thread,Index)) {Result=Color(V->r,V->g,V->b);return GLValidNativeValue(Item,Result);}
                return false;
            default: return false;
        }
    }
    if (Item.Type==GLNative::Vector) {
        if (auto V=check_vector3(Thread,Index)) {Result=Vector3(V->x,V->y,V->z);return GLValidNativeValue(Item,Result);}
    }
    if(Item.Type==PathValue) {
        String Text;if(!TextAt(Thread,Index,Text,1024))return false;
        Result=NodePath(Text);return true;
    }
    if (!lua_istable(Thread,Index)) return false;
    if (Item.Type==Vector2Value || Item.Type==Vector2Integer || Item.Type==Vector3Integer || Item.Type==Vector4Value || Item.Type==Vector4Integer || Item.Type==Rotation || Item.Type==Colour4) {
        bool Integral=Item.Type==Vector2Integer || Item.Type==Vector3Integer || Item.Type==Vector4Integer;
        double X=0,Y=0,Z=0,W=0;
        const bool Colour=Item.Type==Colour4;
        if (!NumberAt(Thread,Index,Colour?"R":"X",X,Item,Integral) || !NumberAt(Thread,Index,Colour?"G":"Y",Y,Item,Integral)) return false;
        if (Item.Type!=Vector2Value && Item.Type!=Vector2Integer && !NumberAt(Thread,Index,Colour?"B":"Z",Z,Item,Integral)) return false;
        if ((Item.Type==Vector4Value || Item.Type==Vector4Integer || Item.Type==Rotation || Colour) && !NumberAt(Thread,Index,Colour?"A":"W",W,Item,Integral)) return false;
        if (Item.Type==Vector2Value) Result=Vector2(X,Y);
        else if (Item.Type==Vector2Integer) Result=Vector2i(int(X),int(Y));
        else if (Item.Type==Vector3Integer) Result=Vector3i(int(X),int(Y),int(Z));
        else if (Item.Type==Vector4Value) Result=Vector4(X,Y,Z,W);
        else if (Item.Type==Vector4Integer) Result=Vector4i(int(X),int(Y),int(Z),int(W));
        else if (Item.Type==Rotation) Result=Quaternion(X,Y,Z,W);
        else Result=Color(X,Y,Z,W);
        return GLValidNativeValue(Item,Result);
    }
    if (Item.Type==Rectangle || Item.Type==RectangleInteger || Item.Type==BoundsValue) {
        Kind Element=Item.Type==Rectangle?Vector2Value:(Item.Type==RectangleInteger?Vector2Integer:GLNative::Vector);
        Variant Position,Size;
        if (!Field(Thread,Item,Index,"Position",Element,Position,Depth,Cells,Seen) || !Field(Thread,Item,Index,"Size",Element,Size,Depth,Cells,Seen)) return false;
        if (Item.Type==Rectangle) Result=Rect2(Vector2(Position),Vector2(Size));
        else if (Item.Type==RectangleInteger) Result=Rect2i(Vector2i(Position),Vector2i(Size));
        else Result=AABB(Vector3(Position),Vector3(Size));return true;
    }
    if (Item.Type==BasisValue || Item.Type==Transform2Value || Item.Type==Transform3Value || Item.Type==PlaneValue) {
        Variant X,Y,Z,Origin;
        if (Item.Type==Transform3Value) {
            if (!Field(Thread,Item,Index,"Basis",BasisValue,X,Depth,Cells,Seen) || !Field(Thread,Item,Index,"Origin",GLNative::Vector,Origin,Depth,Cells,Seen)) return false;
            Result=Transform3D(Basis(X),Vector3(Origin));return true;
        }
        if (Item.Type==PlaneValue) {
            double D;if (!Field(Thread,Item,Index,"Normal",GLNative::Vector,X,Depth,Cells,Seen) || !NumberAt(Thread,Index,"D",D,Item)) return false;
            Result=Plane(Vector3(X),D);return true;
        }
        Kind Element=Item.Type==Transform2Value?Vector2Value:GLNative::Vector;
        if (!Field(Thread,Item,Index,"X",Element,X,Depth,Cells,Seen) || !Field(Thread,Item,Index,"Y",Element,Y,Depth,Cells,Seen)) return false;
        if (Item.Type==Transform2Value) {
            if (!Field(Thread,Item,Index,"Origin",Element,Origin,Depth,Cells,Seen)) return false;
            Result=Transform2D(Vector2(X),Vector2(Y),Vector2(Origin));return true;
        }
        if (!Field(Thread,Item,Index,"Z",Element,Z,Depth,Cells,Seen)) return false;
        Result=Basis(Vector3(X),Vector3(Y),Vector3(Z));return true;
    }
    const void* Identity=lua_topointer(Thread,Index);
    for (auto Existing:Seen) if (Identity==Existing) return false;
    Seen.push_back(Identity);
    const int Top=lua_gettop(Thread);bool Valid=true;
    Array Values;Dictionary Map;
    const int Count=int(lua_objlen(Thread,Index));
    if (Count>MaxCollection) Valid=false;
    if (Item.Type==DictionaryValue) {
        lua_pushnil(Thread);int Keys=0;
        while (Valid && lua_next(Thread,Index)) {
            String Key;Variant Child;Property Dynamic=Item;Dynamic.Type=VariantValue;
            if (!TextAt(Thread,-2,Key,128) || ++Keys>MaxCollection) {Valid=false;break;}
            if (Key=="__NativeType") {String Tag;if(!TextAt(Thread,-1,Tag,64)||Tag!="Dictionary"){Valid=false;break;}}
            else {
                if (!Read(Thread,Dynamic,lua_gettop(Thread),Child,Depth+1,Cells,Seen)) {Valid=false;break;}
                Map[Key]=Child;
            }
            lua_pop(Thread,1);
        }
        Result=Map;
    } else {
        for (int I=1;Valid && I<=Count;++I) {
            lua_rawgeti(Thread,Index,I);Variant Child;Property Dynamic=Item;Dynamic.Type=VariantValue;
            if(Item.Type==Vectors2Value)Dynamic.Type=Vector2Value;
            else if(Item.Type==Vectors3Value)Dynamic.Type=GLNative::Vector;
            else if(Item.Type==ColoursValue)Dynamic.Type=Colour4;
            else if(Item.Type==Vectors4Value)Dynamic.Type=Vector4Value;
            if (!Read(Thread,Dynamic,lua_gettop(Thread),Child,Depth+1,Cells,Seen)) Valid=false;
            lua_pop(Thread,1);if (Valid) Values.push_back(Child);
        }
        lua_pushnil(Thread);
        while (Valid && lua_next(Thread,Index)) {
            if (lua_type(Thread,-2)==LUA_TSTRING) {String Key;Valid=TextAt(Thread,-2,Key,64) && Key=="__NativeType";}
            else if (lua_type(Thread,-2)!=LUA_TNUMBER || lua_tonumber(Thread,-2)<1 || lua_tonumber(Thread,-2)>Count || std::floor(lua_tonumber(Thread,-2))!=lua_tonumber(Thread,-2)) Valid=false;
            lua_pop(Thread,1);
        }
        Result=Values;
        for (const auto& Type:ValueTypes) if (Type.Type==Item.Type && Type.Native!=Variant::ARRAY) {
            for (int I=0;Valid && I<Values.size();++I) {
                Variant V=Values[I];
                if (Item.Type==BytesValue || Item.Type==IntegersValue || Item.Type==LongsValue || Item.Type==FloatsValue || Item.Type==DoublesValue) {
                    if (V.get_type()!=Variant::INT && V.get_type()!=Variant::FLOAT) {Valid=false;break;}
                    double N=V;Valid=std::isfinite(N) && N>=Item.Min && N<=Item.Max;
                    if (Item.Type<=LongsValue) Valid=Valid && N==std::floor(N) && std::abs(N)<=9007199254740991.0;
                    if (Item.Type==BytesValue) Valid=Valid && N>=0 && N<=255;
                    if (Item.Type==IntegersValue) Valid=Valid && N>=INT32_MIN && N<=INT32_MAX;
                } else {
                    Variant::Type Expected=Item.Type==StringsValue?Variant::STRING:Item.Type==Vectors2Value?Variant::VECTOR2:Item.Type==Vectors3Value?Variant::VECTOR3:Item.Type==ColoursValue?Variant::COLOR:Variant::VECTOR4;
                    Valid=V.get_type()==Expected;
                }
            }
            if (Valid) switch(Item.Type) {
#define GL_PACK(KindValue, Class, Element) case KindValue:{Class Packed;Packed.resize(Values.size());for(int I=0;I<Values.size();++I)Packed.set(I,Element(Values[I]));Result=Packed;break;}
                GL_PACK(BytesValue,PackedByteArray,int64_t)
                GL_PACK(IntegersValue,PackedInt32Array,int64_t)
                GL_PACK(LongsValue,PackedInt64Array,int64_t)
                GL_PACK(FloatsValue,PackedFloat32Array,double)
                GL_PACK(DoublesValue,PackedFloat64Array,double)
                GL_PACK(StringsValue,PackedStringArray,String)
                GL_PACK(Vectors2Value,PackedVector2Array,Vector2)
                GL_PACK(Vectors3Value,PackedVector3Array,Vector3)
                GL_PACK(ColoursValue,PackedColorArray,Color)
                GL_PACK(Vectors4Value,PackedVector4Array,Vector4)
#undef GL_PACK
                default:break;
            }
        }
    }
    lua_settop(Thread,Top);Seen.pop_back();return Valid && GLValidNativeValue(Item,Result);
}
bool Valid(const Property& Item,const Variant& Value,int Depth,int& Cells) {
    if (Depth>MaxDepth || ++Cells>MaxCells) return false;
    auto Number=[&](double N){return std::isfinite(N) && N>=Item.Min && N<=Item.Max;};
    switch (Value.get_type()) {
        case Variant::NIL: case Variant::BOOL:return true;
        case Variant::INT:case Variant::FLOAT:return Number(double(Value));
        case Variant::STRING:case Variant::STRING_NAME:{String S=Value;auto B=S.utf8();return B.length()<=MaxText && !std::memchr(B.get_data(),0,B.length());}
        case Variant::NODE_PATH:{NodePath P=Value;String S=P;auto B=S.utf8();return B.length()<=1024 && !std::memchr(B.get_data(),0,B.length());}
        case Variant::VECTOR2:{Vector2 V=Value;return Number(V.x)&&Number(V.y);}
        case Variant::VECTOR2I:{Vector2i V=Value;return Number(V.x)&&Number(V.y);}
        case Variant::VECTOR3:{Vector3 V=Value;return Number(V.x)&&Number(V.y)&&Number(V.z);}
        case Variant::VECTOR3I:{Vector3i V=Value;return Number(V.x)&&Number(V.y)&&Number(V.z);}
        case Variant::VECTOR4:{Vector4 V=Value;return Number(V.x)&&Number(V.y)&&Number(V.z)&&Number(V.w);}
        case Variant::VECTOR4I:{Vector4i V=Value;return Number(V.x)&&Number(V.y)&&Number(V.z)&&Number(V.w);}
        case Variant::COLOR:{Color V=Value;return Number(V.r)&&Number(V.g)&&Number(V.b)&&Number(V.a)&&V.r>=0&&V.r<=1&&V.g>=0&&V.g<=1&&V.b>=0&&V.b<=1&&V.a>=0&&V.a<=1;}
        case Variant::RECT2:{Rect2 V=Value;return Valid(Item,V.position,Depth+1,Cells)&&Valid(Item,V.size,Depth+1,Cells);}
        case Variant::RECT2I:{Rect2i V=Value;return Valid(Item,V.position,Depth+1,Cells)&&Valid(Item,V.size,Depth+1,Cells);}
        case Variant::AABB:{AABB V=Value;return V.size.x>=0&&V.size.y>=0&&V.size.z>=0&&Valid(Item,V.position,Depth+1,Cells)&&Valid(Item,V.size,Depth+1,Cells);}
        case Variant::QUATERNION:{Quaternion V=Value;return Number(V.x)&&Number(V.y)&&Number(V.z)&&Number(V.w);}
        case Variant::PLANE:{Plane V=Value;return Valid(Item,V.normal,Depth+1,Cells)&&Number(V.d);}
        case Variant::BASIS:{Basis V=Value;return Valid(Item,V.get_column(0),Depth+1,Cells)&&Valid(Item,V.get_column(1),Depth+1,Cells)&&Valid(Item,V.get_column(2),Depth+1,Cells);}
        case Variant::TRANSFORM2D:{Transform2D V=Value;return Valid(Item,V[0],Depth+1,Cells)&&Valid(Item,V[1],Depth+1,Cells)&&Valid(Item,V[2],Depth+1,Cells);}
        case Variant::TRANSFORM3D:{Transform3D V=Value;return Valid(Item,V.basis,Depth+1,Cells)&&Valid(Item,V.origin,Depth+1,Cells);}
        case Variant::DICTIONARY:{Dictionary D=Value;if (D.size()>MaxCollection || D.has("__NativeType")) return false;Array Keys=D.keys();for(int I=0;I<Keys.size();++I){if(Keys[I].get_type()!=Variant::STRING && Keys[I].get_type()!=Variant::STRING_NAME)return false;if(!Valid(Item,Keys[I],Depth+1,Cells)||!Valid(Item,D[Keys[I]],Depth+1,Cells))return false;}return true;}
        case Variant::ARRAY:{Array A=Value;if(A.size()>MaxCollection)return false;for(int I=0;I<A.size();++I)if(!Valid(Item,A[I],Depth+1,Cells))return false;return true;}
        default:
            for(const auto& T:ValueTypes) if(T.Native==Value.get_type() && T.Type>=BytesValue && T.Type<=Vectors4Value){Array A=Elements(Value);return Valid(Item,A,Depth+1,Cells);}
            return false;
    }
}
void NumberField(lua_State* Thread,const char* Name,double Value){lua_pushnumber(Thread,Value);lua_setfield(Thread,-2,Name);}
void Push(lua_State* Thread,const Variant& Value) {
    switch(Value.get_type()) {
        case Variant::VECTOR3:{Vector3 V=Value;push_vector3(Thread,V.x,V.y,V.z);return;}
        case Variant::STRING:case Variant::STRING_NAME:{String Text=Value;lua_pushstring(Thread,Text.utf8().get_data());return;}
        case Variant::NODE_PATH:{NodePath Path=Value;String Text=Path;lua_pushstring(Thread,Text.utf8().get_data());return;}
        case Variant::NIL:case Variant::BOOL:case Variant::INT:case Variant::FLOAT:gl_variant_to_luau(Thread,Value);return;
        default:break;
    }
    lua_newtable(Thread);
    auto Child=[&](const char* Name,const Variant& V){Push(Thread,V);lua_setfield(Thread,-2,Name);};
    switch(Value.get_type()) {
        case Variant::VECTOR2:{Vector2 V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);break;}
        case Variant::VECTOR2I:{Vector2i V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);break;}
        case Variant::VECTOR3I:{Vector3i V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);NumberField(Thread,"Z",V.z);break;}
        case Variant::VECTOR4:{Vector4 V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);NumberField(Thread,"Z",V.z);NumberField(Thread,"W",V.w);break;}
        case Variant::VECTOR4I:{Vector4i V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);NumberField(Thread,"Z",V.z);NumberField(Thread,"W",V.w);break;}
        case Variant::QUATERNION:{Quaternion V=Value;NumberField(Thread,"X",V.x);NumberField(Thread,"Y",V.y);NumberField(Thread,"Z",V.z);NumberField(Thread,"W",V.w);break;}
        case Variant::COLOR:{Color V=Value;NumberField(Thread,"R",V.r);NumberField(Thread,"G",V.g);NumberField(Thread,"B",V.b);NumberField(Thread,"A",V.a);break;}
        case Variant::RECT2:{Rect2 V=Value;Child("Position",V.position);Child("Size",V.size);break;}
        case Variant::RECT2I:{Rect2i V=Value;Child("Position",V.position);Child("Size",V.size);break;}
        case Variant::AABB:{AABB V=Value;Child("Position",V.position);Child("Size",V.size);break;}
        case Variant::PLANE:{Plane V=Value;Child("Normal",V.normal);NumberField(Thread,"D",V.d);break;}
        case Variant::BASIS:{Basis V=Value;Child("X",V.get_column(0));Child("Y",V.get_column(1));Child("Z",V.get_column(2));break;}
        case Variant::TRANSFORM2D:{Transform2D V=Value;Child("X",V[0]);Child("Y",V[1]);Child("Origin",V[2]);break;}
        case Variant::TRANSFORM3D:{Transform3D V=Value;Child("Basis",V.basis);Child("Origin",V.origin);break;}
        case Variant::DICTIONARY:{Dictionary D=Value;Array Keys=D.keys();for(int I=0;I<Keys.size();++I){String K=Keys[I];Push(Thread,D[Keys[I]]);lua_setfield(Thread,-2,K.utf8().get_data());}break;}
        default:{Array A=Elements(Value);for(int I=0;I<A.size();++I){Push(Thread,A[I]);lua_rawseti(Thread,-2,I+1);}break;}
    }
    for(const auto& T:ValueTypes)if(T.Native==Value.get_type()){lua_pushstring(Thread,T.Name);lua_setfield(Thread,-2,"__NativeType");break;}
    lua_setreadonly(Thread,-1,true);
}
}
const char* GLNativeValueName(Kind Type){for(const auto& T:ValueTypes)if(T.Type==Type)return T.Name;return nullptr;}
Kind GLNativeValueKind(const char* Name){for(const auto& T:ValueTypes)if(!strcmp(T.Name,Name))return T.Type;return Void;}
bool GLReadNativeValue(lua_State* Thread,const Property& Item,int Index,Variant& Result){int Cells=0;std::vector<const void*> Seen;return Read(Thread,Item,Index,Result,0,Cells,Seen)&&GLValidNativeValue(Item,Result);}
bool GLValidNativeValue(const Property& Item,const Variant& Value){
    if(Item.Type!=VariantValue){bool Found=false;for(const auto& T:ValueTypes)if(T.Type==Item.Type){Found=T.Native==Value.get_type();break;}if(!Found)return false;}
    int Cells=0;return Valid(Item,Value,0,Cells);
}
bool GLPushNativeValue(lua_State* Thread,const Variant& Value){Property Item{"","","",VariantValue,-1e12,1e12};if(!GLValidNativeValue(Item,Value))return false;Push(Thread,Value);return true;}
