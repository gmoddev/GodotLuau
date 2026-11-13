#ifndef GL_AUTHORING_DEBUGGER_H
#define GL_AUTHORING_DEBUGGER_H
#include <godot_cpp/classes/editor_debugger_plugin.hpp>
#include <godot_cpp/classes/script.hpp>
#include <map>
#include <string>

class GLAuthoringDebugger : public godot::EditorDebuggerPlugin {
    GDCLASS(GLAuthoringDebugger,godot::EditorDebuggerPlugin);
    uint64_t Receiver=0;
    using Location=std::pair<std::string,int>;
    struct SessionView {
        godot::String Nonce, Domain="All", PauseDomain="Server";
        int64_t Request=0;
        uint64_t Label=0, Tree=0, WatchInput=0, WatchFrame=0, WatchResult=0;
        std::map<Location,bool> Pending;
    };
    std::map<int,SessionView> Views;
    std::map<Location,bool> Breakpoints;
    uint64_t LastFlush=0;
    void Send(int Session,const godot::String& Op,const godot::Dictionary& Fields={});
protected:
    static void _bind_methods();
public:
    void SetReceiver(uint64_t Id) { Receiver=Id; }
    bool _has_capture(const godot::String& Name) const override { return Name=="godotluau"; }
    bool _capture(const godot::String& Message,const godot::Array& Data,int32_t Session) override;
    void _setup_session(int32_t Session) override;
    void _breakpoint_set_in_tree(const godot::Ref<godot::Script>& Script,int32_t Line,bool Enabled) override;
    void _breakpoints_cleared_in_tree() override;
    void RecordBreakpoint(const godot::String& Source,int Line,bool Enabled);
    void Command(int Session,const godot::String& Op);
    void SelectDomain(int Index,int Session);
    void Flush();
};
#endif
