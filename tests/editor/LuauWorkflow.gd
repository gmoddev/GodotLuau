@tool
extends EditorPlugin
## Observer only: all authoring/preview/save actions are production native methods.
var Passed := true
var Checks: Array[Dictionary] = []

func _enter_tree() -> void:
    Run.call_deferred()

func Check(Value: bool, Message: String) -> void:
    Passed = Passed and Value
    Checks.append({"Passed": Value, "Message": Message})
    print("[Authoring:Workflow] ", "PASS " if Value else "FAIL ", Message)

func Run() -> void:
    await get_tree().process_frame
    while EditorInterface.get_resource_filesystem().is_scanning():
        await get_tree().process_frame
    var Extensions := ResourceLoader.get_recognized_extensions_for_type("LuauScript")
    if ProjectSettings.get_setting("godot_luau/qualification_baseline", false):
        Check("lua" in Extensions and "luau" not in Extensions, "Baseline only advertises .lua")
        Check(not ClassDB.class_has_method("GLNativeEditorPlugin", "CreateLuauScene"), "Baseline has no native new-scene workflow")
        Check(not ClassDB.class_has_method("GLNativeEditorPlugin", "PreviewScript"), "Baseline has no controlled editor preview")
    else:
        Check("lua" in Extensions and "luau" in Extensions, "Both source extensions are registered")
        var Plugins := get_tree().root.find_children("*", "GLNativeEditorPlugin", true, false)
        Check(Plugins.size() == 1, "Actual native authoring plugin is installed")
        if Plugins.size() == 1:
            var Plugin: Node = Plugins[0]
            var Created: Dictionary = Plugin.call("CreateLuauScene", "res://Fresh.tscn")
            Check(Created.get("Passed", false), "Native action creates scene and .luau entrypoint")
            Check(not Plugin.call("CreateLuauScene", "res://Fresh.tscn").get("Passed", false), "Creation never overwrites an existing project scene")
            var Source: Script = load("res://Fresh.luau")
            Check(Source != null and Source.get_class() == "LuauScript", "Created source uses the real language resource")
            if Source:
                var Original := Source.source_code
                var Result: Dictionary = Plugin.call("PreviewScript", Source)
                Check(Result.get("Passed", false) and Result.get("Nodes", 0) > 0, "Native preview constructs the authored scene")
                Check(Plugin.call("SavePreview", "res://Generated.tscn") == OK, "Explicit native PackedScene save succeeds")
                Check(Plugin.call("SavePreview", "res://Generated.tscn") != OK, "Save refuses to overwrite existing user content")
                var Scene: PackedScene = load("res://Generated.tscn") if ResourceLoader.exists("res://Generated.tscn") else null
                Check(Scene != null and Scene.get_state().get_node_count() > 1, "Saved native content reloads independently")
                if Scene:
                    var NativeOnly := true
                    for Index in range(Scene.get_state().get_node_count()):
                        NativeOnly = NativeOnly and Scene.get_state().get_node_type(Index) != "SceneScope"
                    Check(NativeOnly, "Saved scenes do not serialize live scope capabilities")
                Source.source_code = 'assert(game == nil and _ServiceStorage == nil and _HTTP == nil and _InstanceNew == nil)\nlocal Scope = Scene.new(script.Parent)\nScope:New("Node3D", {})'
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Preview has no gameplay/native-service capability globals")
                Source.source_code = 'error("expected preview failure")'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Explicit preview errors propagate without editor restart")
                Source.source_code = Original
                for Index in range(20):
                    Result = Plugin.call("PreviewScript", Source)
                    if not Result.get("Passed", false): break
                    await get_tree().process_frame
                Check(Result.get("Passed", false), "Repeated preview rebuild recovers after failure")
                Source.source_code = 'while true do end'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Preview infinite loop is interrupted")
                Source.source_code = 'task.wait(1)'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Yielding preview construction is rejected and retired")
                Source.source_code = Original
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Fresh owner succeeds after cancellation")
                Source.source_code = Original + '\nshared.Previous = Scope'
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Preview may retain an ordinary handle in its own domain")
                Source.source_code = 'assert(not pcall(function() shared.Previous:New("Node3D", {}) end))\nlocal Scope = Scene.new(script.Parent)\nScope:New("Node3D", {})'
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Old generation handle cannot mutate the next preview")
                var Module: Script = ClassDB.instantiate("LuauScript")
                Module.source_code = 'return function(Scope) Scope:New("Node3D", {Name="ModuleChild"}) end'
                Check(ResourceSaver.save(Module, "res://Module.luau") == OK, "Native Luau module saves as a project resource")
                Module.take_over_path("res://Module.luau")
                Source.source_code = 'local Scope = Scene.new(script.Parent)\nrequire("res://Module.luau")(Scope)'
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Project module factory composes caller-owned native content")
                Module.source_code = 'return function(Scope) error("revised module observed") end'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Module revisions invalidate cached results")
                Module.source_code = 'task.wait(1)\nreturn {}'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Yielding preview modules are rejected")
                Source.source_code = Original
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Module initializers retire before a fresh preview")
                Source.source_code = 'require("user://outside.luau")'
                Check(not Plugin.call("PreviewScript", Source).get("Passed", false), "Module resolution rejects external storage authority")
                Source.source_code = Original
                Plugin.call("StopPreview")
                await get_tree().process_frame
                var GameSource: Script = load("res://OrbRun.luau")
                var GamePreview: Dictionary = Plugin.call("PreviewScript", GameSource)
                Check(GamePreview.get("Passed", false) and GamePreview.get("Nodes", 0) > 15, "Actual Luau-only game composes in the restricted editor context")
                Check(Plugin.call("SavePreview", "res://OrbSaved.tscn") == OK, "Actual game preview saves as native scene data")
                Plugin.call("StopPreview")
                EditorInterface.set_main_screen_editor("Script")
                EditorInterface.edit_script(Source, -1, 0, true)
                for Index in range(10): await get_tree().process_frame
                var Code := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
                Check(Code != null, "Created .luau opens in the actual native ScriptEditor")
                if Code:
                    Code.text = 'local function Build()\n return 1\nend\n\nBuild()\n'
                    Code.set_caret_line(4)
                    Code.set_caret_column(3)
                    Code.emit_signal("symbol_lookup", "Build", 4, 3)
                    for Index in range(3): await get_tree().process_frame
                    Check(Code.get_caret_line() == 0, "Actual ScriptEditor navigation reaches the Luau declaration")
                    Code.text = Original
    var File := FileAccess.open("res://editor-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks}))
    File.close()
    print("[Bindings:EditorIntegration] ", "PASS" if Passed else "FAIL")
    get_tree().quit(0 if Passed else 1)
