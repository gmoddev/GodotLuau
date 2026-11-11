#ifndef GL_AUTHORING_DEBUGGER_H
#define GL_AUTHORING_DEBUGGER_H
#include <godot_cpp/classes/editor_debugger_plugin.hpp>

class GLAuthoringDebugger : public godot::EditorDebuggerPlugin {
    GDCLASS(GLAuthoringDebugger,godot::EditorDebuggerPlugin);
    uint64_t Receiver=0;
protected:
    static void _bind_methods() {}
public:
    void SetReceiver(uint64_t Id) { Receiver=Id; }
    bool _has_capture(const godot::String& Name) const override { return Name=="godotluau"; }
    bool _capture(const godot::String& Message,const godot::Array& Data,int32_t Session) override;
};
#endif
