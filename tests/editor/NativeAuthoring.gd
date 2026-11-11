@tool
extends EditorPlugin
## Exercise the actual registered Luau editor, without running a game script.

var Passed := true
var Checks: Array[Dictionary] = []

func _enter_tree() -> void:
    Run.call_deferred()

func Check(Condition: bool, Message: String) -> void:
    Checks.append({"Passed": Condition, "Message": Message})
    Passed = Passed and Condition
    print("[Bindings:Editor] ", "PASS " if Condition else "FAIL ", Message)

func Run() -> void:
    await get_tree().process_frame
    var Resource: Script = load("res://NativeEditor.lua")
    Check(Resource != null and Resource.get_class()=="LuauScript", "Project .lua resolves through the registered native language loader")
    if Resource:
        var Original := Resource.source_code
        load("res://NativeEditorCases.gd").new().Run(self)
        EditorInterface.edit_script(Resource, -1, 0, false)
        for Index in range(10):
            await get_tree().process_frame
        var Editor := EditorInterface.get_script_editor().get_current_editor()
        Check(Editor != null, "Godot ScriptEditor opens the native Luau resource")
        if Editor:
            var Controls := Editor.get_base_editor().find_children("*", "CodeEdit", true, false)
            Check(Controls.size()==1, "Godot exposes its normal native-script CodeEdit")
            if Controls.size()==1:
                var Code := Controls[0] as CodeEdit
                Code.text="local Scope = Scene.new(script.Parent)\nScope:"
                Code.set_caret_line(1)
                Code.set_caret_column(6)
                Code.request_code_completion(true)
                await get_tree().create_timer(0.5).timeout
                var Names: Array[String] = []
                for Option in Code.get_code_completion_options():
                    Names.append(str(Option.insert_text))
                Check("New" in Names and "Instantiate" in Names and "Call" in Names and "free" not in Names,
                    "Actual ScriptLanguage completion reaches the generated native policy")
                Code.text="math."
                Code.set_caret_line(0)
                Code.set_caret_column(5)
                Code.request_code_completion(true)
                await get_tree().create_timer(0.5).timeout
                var MathCompletion := false
                for Option in Code.get_code_completion_options():
                    MathCompletion = MathCompletion or str(Option.insert_text).contains("abs") or str(Option.insert_text).contains("floor")
                Check(MathCompletion, "Actual ScriptLanguage completion preserves the legacy math path")
                # Restore a valid source before editor shutdown; no script is run.
                Code.text=Original
    var File := FileAccess.open("res://editor-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks}))
    File.close()
    print("[Bindings:EditorIntegration] ", "PASS" if Passed else "FAIL")
    get_tree().quit(0 if Passed else 1)
