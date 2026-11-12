#include "gl_luau_highlighter.h"
#include "Luau/Lexer.h"
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <algorithm>
#include <cstring>

using namespace godot;
void GLLuauHighlighter::_bind_methods() {
    // The admitted 4.7 editor adds _create beyond the pinned 4.3 headers.
    // Use the normal godot-cpp ptrcall encoder for its Ref return contract.
    ClassDB::bind_virtual_method(get_class_static(),"_create",CreateVirtual);
}
Ref<EditorSyntaxHighlighter> GLLuauHighlighter::Create() const {
    Ref<GLLuauHighlighter> Value;Value.instantiate();return Value;
}
void GLLuauHighlighter::CreateVirtual(GDExtensionClassInstancePtr Instance,const GDExtensionConstTypePtr* Arguments,GDExtensionTypePtr Result) {
    call_with_ptr_args(static_cast<GLLuauHighlighter*>(Instance),&GLLuauHighlighter::Create,Arguments,Result);
}
void GLLuauHighlighter::BuildCache() const {
    Lines.clear();
    auto Edit=get_text_edit();if (!Edit) return;
    Dirty=false;
    String Source=Edit->get_text();
    if (Source.length()>1024*1024) return;
    auto Bytes=Source.utf8();if (Bytes.length()>1024*1024) return;
    auto Rows=Source.split("\n");if (Rows.size()>8192) return;
    Lines.resize(Rows.size());
    // Luau locations count UTF-8 bytes; Godot columns count Unicode characters.
    std::vector<std::vector<int32_t>> Columns(Rows.size());
    for (int Row=0;Row<Rows.size();++Row) {
        String Text=Rows[Row];auto& Map=Columns[Row];
        for (int Column=0;Column<Text.length();++Column) {
            char32_t Point=Text[Column];int Width=Point<0x80?1:Point<0x800?2:Point<0x10000?3:4;
            for (int Byte=0;Byte<Width;++Byte) Map.push_back(Column);
        }
        Map.push_back(Text.length());
    }
    Color Default=Edit->get_theme_color("font_color");
    Luau::Allocator Allocator;Luau::AstNameTable Names(Allocator);
    Luau::Lexer Lexer(Bytes.get_data(),Bytes.length(),Names);
    for (int Count=0;Count<65536;++Count) {
        const auto& Token=Lexer.next();if (Token.type==Luau::Lexeme::Eof) break;
        Color Colour=Default;
        if (Token.type>=Luau::Lexeme::Reserved_BEGIN && Token.type<Luau::Lexeme::Reserved_END)
            Colour=Color(0.95,0.45,0.55);
        else if (Token.type==Luau::Lexeme::Name) {
            if (!strcmp(Token.name,"type") || !strcmp(Token.name,"export") || !strcmp(Token.name,"continue")) Colour=Color(0.95,0.45,0.55);
            else for (const char* Name:{"Scene","Vector2","Vector3","Color3","CFrame","game","script","self"})
                if (!strcmp(Token.name,Name)) { Colour=Color(0.45,0.8,0.9);break; }
        } else if (Token.type==Luau::Lexeme::Comment || Token.type==Luau::Lexeme::BlockComment || Token.type==Luau::Lexeme::BrokenComment)
            Colour=Color(0.55,0.6,0.65);
        else if (Token.type==Luau::Lexeme::Number) Colour=Color(0.65,0.9,0.7);
        else if (Token.type==Luau::Lexeme::QuotedString || Token.type==Luau::Lexeme::RawString || Token.type==Luau::Lexeme::BrokenString ||
                 (Token.type>=Luau::Lexeme::InterpStringBegin && Token.type<=Luau::Lexeme::InterpStringSimple)) Colour=Color(0.9,0.8,0.55);
        if (Colour==Default) continue;
        for (unsigned Row=Token.location.begin.line;Row<=Token.location.end.line && Row<Lines.size();++Row) {
            if (Row>Token.location.begin.line && Row==Token.location.end.line && Token.location.end.column==0) break;
            const auto& Map=Columns[Row];
            unsigned Begin=Row==Token.location.begin.line?Token.location.begin.column:0;
            unsigned End=Row==Token.location.end.line?Token.location.end.column:unsigned(Map.size()-1);
            Dictionary StartColour;StartColour["color"]=Colour;
            Dictionary EndColour;EndColour["color"]=Default;
            Lines[Row][Map[(std::min)(size_t(Begin),Map.size()-1)]]=StartColour;
            Lines[Row][Map[(std::min)(size_t(End),Map.size()-1)]]=EndColour;
        }
    }
}
Dictionary GLLuauHighlighter::_get_line_syntax_highlighting(int32_t Line) const {
    if (Dirty) BuildCache();
    return Line>=0 && size_t(Line)<Lines.size()?Lines[Line]:Dictionary();
}
