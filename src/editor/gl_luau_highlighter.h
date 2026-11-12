#ifndef GL_LUAU_HIGHLIGHTER_H
#define GL_LUAU_HIGHLIGHTER_H
#include <godot_cpp/classes/editor_syntax_highlighter.hpp>
#include <vector>

class GLLuauHighlighter : public godot::EditorSyntaxHighlighter {
    GDCLASS(GLLuauHighlighter,godot::EditorSyntaxHighlighter);
    mutable bool Dirty=true;
    mutable std::vector<godot::Dictionary> Lines;
    void BuildCache() const;
    static void CreateVirtual(GDExtensionClassInstancePtr Instance,const GDExtensionConstTypePtr* Arguments,GDExtensionTypePtr Result);
protected:
    static void _bind_methods();
public:
    godot::Ref<godot::EditorSyntaxHighlighter> Create() const;
    godot::String _get_name() const override { return "Luau"; }
    godot::PackedStringArray _get_supported_languages() const override { godot::PackedStringArray Names;Names.push_back("Luau");return Names; }
    godot::Dictionary _get_line_syntax_highlighting(int32_t Line) const override;
    void _clear_highlighting_cache() override { Lines.clear();Dirty=true; }
    void _update_cache() override { Dirty=true;BuildCache(); }
};
#endif
