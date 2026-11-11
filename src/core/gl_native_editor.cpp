#include "gl_native_editor_api.h"
#include "gl_native_editor.h"

godot::Dictionary GLInspectNativeCode(const godot::String& Code, const godot::String& Path) {
    return GLNativeEditor::Inspect(Code,Path);
}
