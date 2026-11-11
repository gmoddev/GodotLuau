#ifndef GL_NATIVE_EDITOR_PLUGIN_H
#define GL_NATIVE_EDITOR_PLUGIN_H

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/script.hpp>
#include <memory>
class GLExecutionDomain;
struct GLExecutionOwner;
class LuauScript;

// Configure the existing Godot editor through public APIs, without owning tabs,
// Script resources or CodeEdit pointers beyond each callback.
class GLNativeEditorPlugin : public godot::EditorPlugin {
    GDCLASS(GLNativeEditorPlugin, godot::EditorPlugin);
    bool Pending = false;
    std::unique_ptr<GLExecutionDomain> PreviewDomain;
    GLExecutionOwner* PreviewOwner = nullptr;
    uint64_t PreviewRoot = 0, PreviewViewport = 0, PreviewPanel = 0;
    uint64_t PreviewTree = 0, StatusLabel = 0, PathDialog = 0;
    bool SavingPreview = false;
    godot::String PreviewError;
    void SetupAuthoring();
    void ShowStatus(const godot::String& Text);
    void BuildPreviewTree();
protected:
    static void _bind_methods();
public:
    GLNativeEditorPlugin();
    ~GLNativeEditorPlugin();
    void _enter_tree() override;
    void _exit_tree() override;
    void _process(double Delta) override;
    void OnScriptChanged(const godot::Ref<godot::Script>& Script);
    void ConfigureEditor();
    godot::Dictionary CreateLuauScene(const godot::String& Path);
    godot::Dictionary PreviewScript(const godot::Ref<LuauScript>& Source);
    void StopPreview();
    godot::Error SavePreview(const godot::String& Path);
    void PreviewSelected();
    void NewSceneDialog();
    void SavePreviewDialog();
    void OnAuthoringPath(const godot::String& Path);
    void InspectPreviewNode();
};

#endif
