#include "gl_debug_inspection.h"
#include "gl_debugger.h"
#include "Luau/Parser.h"
#include "Luau/Ast.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <cmath>

using namespace godot;
namespace {
struct Evaluation {
    Dictionary Variables;
    String Error;
    int Remaining=128;
    Variant Fail(const char* Message) { if(Error.is_empty())Error=Message;return Variant(); }
    bool Truth(const Variant& Value) { return Value.get_type()!=Variant::NIL && !(Value.get_type()==Variant::BOOL && !bool(Value)); }
    bool Numeric(const Variant& Value) { return Value.get_type()==Variant::INT || Value.get_type()==Variant::FLOAT; }
    Variant Checked(const Variant& Value) {
        if(Value.get_type()==Variant::DICTIONARY && String(Dictionary(Value).get("Kind",String()))=="Restricted")return Fail("Value is restricted");
        return Value;
    }
    Variant Index(const Variant& Value,const Variant& Key) {
        if(Value.get_type()==Variant::DICTIONARY) {
            Dictionary Map=Value;
            String Kind=Map.get("Kind",String());
            if(Kind=="Table") {
                Array Entries=Map.get("Entries",Array());
                for(int I=0;I<Entries.size() && I<64;++I) {
                    Dictionary Entry=Entries[I];if(Variant(Entry["Key"])==Key)return Checked(Entry["Value"]);
                }
                if(bool(Map.get("Truncated",false)))return Fail("Table lookup exceeds the bounded projection");
                return Variant();
            }
            if(Kind=="Node" || Kind=="Resource") {
                if(String(Map.get("State",String()))!="Alive")return Fail("Native handle is destroyed or restricted");
                if(Key.get_type()!=Variant::STRING)return Fail("Native properties require a name");
                if(String(Key)=="ClassName")return Map.get("ClassName",Variant());
                Dictionary Properties=Map.get("Properties",Dictionary());
                if(Properties.has(Key))return Checked(Properties[Key]);
                return Fail("Property is outside the approved inspection projection");
            }
            return Fail("Cycle/shared reference or restricted value cannot be expanded here");
        }
        if(Key.get_type()==Variant::STRING && (Value.get_type()==Variant::VECTOR2 || Value.get_type()==Variant::VECTOR3 ||
            Value.get_type()==Variant::VECTOR4 || Value.get_type()==Variant::COLOR || Value.get_type()==Variant::QUATERNION)) {
            String Name=Key;
            if(Name.length()!=1)return Fail("Only fixed value components are supported");
            Name=Name.to_lower();bool Valid=false;Variant Result=Value.get_named(Name,Valid);
            return Valid?Result:Fail("Unknown fixed value component");
        }
        return Fail("Indexing requires a projected table or owned native value");
    }
    Variant Eval(const Luau::AstExpr* Node,int Depth=0) {
        if(!Node || --Remaining<0 || Depth>16)return Fail("Watch expression exceeds its work/depth bound");
        if(auto Group=Node->as<Luau::AstExprGroup>())return Eval(Group->expr,Depth+1);
        if(auto Cast=Node->as<Luau::AstExprTypeAssertion>())return Eval(Cast->expr,Depth+1);
        if(Node->is<Luau::AstExprConstantNil>())return Variant();
        if(auto Value=Node->as<Luau::AstExprConstantBool>())return Value->value;
        if(auto Value=Node->as<Luau::AstExprConstantNumber>())return std::isfinite(Value->value)?Variant(Value->value):Fail("Non-finite literal");
        if(auto Value=Node->as<Luau::AstExprConstantString>()) {
            String Text;return GLDebugText(Value->value.data,Value->value.size,1024,Text)?Variant(Text):Fail("Binary string literals are unsupported");
        }
        if(auto Global=Node->as<Luau::AstExprGlobal>()) {
            String Name=String::utf8(Global->name.value);
            if(!Variables.has(Name))return Fail("Name is not a local or upvalue in the selected frame");
            Variant Value=Variables[Name];
            return Checked(Value);
        }
        if(auto Field=Node->as<Luau::AstExprIndexName>())return Index(Eval(Field->expr,Depth+1),String::utf8(Field->index.value));
        if(auto Field=Node->as<Luau::AstExprIndexExpr>())return Index(Eval(Field->expr,Depth+1),Eval(Field->index,Depth+1));
        if(auto Unary=Node->as<Luau::AstExprUnary>()) {
            Variant Value=Eval(Unary->expr,Depth+1);
            if(Unary->op==Luau::AstExprUnary::Not)return !Truth(Value);
            if(Unary->op==Luau::AstExprUnary::Minus && Numeric(Value))return -double(Value);
            if(Unary->op==Luau::AstExprUnary::Len) {
                if(Value.get_type()==Variant::STRING)return int64_t(String(Value).utf8().length());
                if(Value.get_type()==Variant::DICTIONARY) {
                    Dictionary Data=Value;String Kind=Data.get("Kind",String());
                    if(Kind=="Table" || Kind=="StringPreview")return Data.get("Length",Variant());
                }
            }
            return Fail("Unsupported unary operand");
        }
        if(auto Binary=Node->as<Luau::AstExprBinary>()) {
            using Op=Luau::AstExprBinary;
            Variant Left=Eval(Binary->left,Depth+1);
            if(Binary->op==Op::And)return Truth(Left)?Eval(Binary->right,Depth+1):Left;
            if(Binary->op==Op::Or)return Truth(Left)?Left:Eval(Binary->right,Depth+1);
            Variant Right=Eval(Binary->right,Depth+1);
            if(Binary->op==Op::CompareEq || Binary->op==Op::CompareNe) {
                if(Left.get_type()==Variant::DICTIONARY || Right.get_type()==Variant::DICTIONARY)return Fail("Projected object identity equality is unsupported");
                bool Equal=Left==Right;return Binary->op==Op::CompareEq?Equal:!Equal;
            }
            if(Binary->op==Op::Concat && Left.get_type()==Variant::STRING && Right.get_type()==Variant::STRING) {
                String Result=String(Left)+String(Right);return Result.utf8().length()<=1024?Variant(Result):Fail("Concatenation exceeds 1024 bytes");
            }
            if(!Numeric(Left) || !Numeric(Right))return Fail("Operator requires finite numeric operands");
            double A=Left,B=Right,Result=0;
            switch(Binary->op) {
                case Op::Add: Result=A+B;break;
                case Op::Sub: Result=A-B;break;
                case Op::Mul: Result=A*B;break;
                case Op::Div: if(B==0)return Fail("Division by zero");Result=A/B;break;
                case Op::FloorDiv: if(B==0)return Fail("Division by zero");Result=std::floor(A/B);break;
                case Op::Mod: if(B==0)return Fail("Division by zero");Result=A-std::floor(A/B)*B;break;
                case Op::Pow: return Fail("Exponentiation is outside the bounded evaluator");
                case Op::CompareLt: return A<B;
                case Op::CompareLe: return A<=B;
                case Op::CompareGt: return A>B;
                case Op::CompareGe: return A>=B;
                default: return Fail("Unsupported expression operator");
            }
            return std::isfinite(Result)?Variant(Result):Fail("Non-finite arithmetic result");
        }
        return Fail("Calls constructors assignment functions and dynamic execution are forbidden");
    }
};
}
Dictionary GLDebugEvaluate(int Level,const String& Expression) {
    Dictionary Result;Result["Ok"]=false;Result["Frame"]=Level;
    auto Active=GLGetSuspendedDebugger();
    if(!Active || !Active->IsFrameInspectable(Active->GetInspectionThread(),Level) || Expression.is_empty() || Expression.length()>1024 || Expression.utf8().length()>1024) {
        Result["Error"]="A live suspended frame and an expression of at most 1024 bytes are required";return Result;
    }
    auto Code=(String("return (")+Expression+")").utf8();
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    auto Parsed=Luau::Parser::parse(Code.get_data(),Code.length(),Names,Allocator);
    auto Return=Parsed.root && Parsed.root->body.size==1?Parsed.root->body.data[0]->as<Luau::AstStatReturn>():nullptr;
    if(!Parsed.errors.empty() || !Return || Return->list.size!=1){Result["Error"]="Expected one restricted expression";return Result;}
    Evaluation Evaluate;
    for(bool Upvalues:{true,false}) {
        Dictionary Frame=GLDebugVariables(Level,32,3,Upvalues);
        PackedStringArray Keys=Frame.get(Upvalues?"members":"locals",PackedStringArray());Array Values=Frame.get("values",Array());
        for(int Index=0;Index<Keys.size() && Index<Values.size();++Index) {
            String Name=Keys[Index];if(Upvalues && Name.begins_with("upvalue: "))Name=Name.substr(9);
            if(!Name.begins_with("argument: "))Evaluate.Variables[Name]=Values[Index];
        }
    }
    Variant Value=Evaluate.Eval(Return->list.data[0]);
    if(!Evaluate.Error.is_empty())Result["Error"]=Evaluate.Error;
    else {Result["Ok"]=true;Result["Value"]=Value;}
    return Result;
}
