#ifndef GL_NATIVE_EDITOR_PLUGIN_H
#define GL_NATIVE_EDITOR_PLUGIN_H

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/script.hpp>

// Configure the existing Godot editor through public APIs, without owning tabs,
// Script resources or CodeEdit pointers beyond each callback.
class GLNativeEditorPlugin : public godot::EditorPlugin {
    GDCLASS(GLNativeEditorPlugin, godot::EditorPlugin);
    bool Pending = false;
protected:
    static void _bind_methods();
public:
    void _enter_tree() override;
    void _exit_tree() override;
    void OnScriptChanged(const godot::Ref<godot::Script>& Script);
    void ConfigureEditor();
};

#endif
