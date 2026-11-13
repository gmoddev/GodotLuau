@tool
extends EditorPlugin
## Observer only: all authoring/preview/save actions are production native methods.
var Passed := true
var Checks: Array[Dictionary] = []
var Measurements: Dictionary = {}

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
    if OS.get_cmdline_user_args().has("--gl052-reopen"):
        await ReopenSavedScenes()
        return
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
            for Profile in ["Empty","2D","UI"]:
                var TemplatePath: String = "res://Starter"+Profile+".tscn"
                var Template: Dictionary = Plugin.call("CreateLuauScene",TemplatePath,Profile)
                Check(Template.get("Passed",false) and Template.get("Template","")==Profile,"Native editor creates "+Profile+" template")
                var TemplateSource: Script = load(TemplatePath.get_basename()+".luau")
                Check(Plugin.call("PreviewScript",TemplateSource).get("Passed",false),"Native editor previews "+Profile+" template without gameplay services")
                Plugin.call("StopPreview")
            Check(not Plugin.call("CreateLuauScene","res://DeniedTemplate.tscn","Unknown").get("Passed",false) and not FileAccess.file_exists("res://DeniedTemplate.luau"),"Unknown template rejects before creating files")
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
                var RebuildStart := Time.get_ticks_usec()
                var MemoryStart := OS.get_static_memory_usage()
                for Index in range(20):
                    Result = Plugin.call("PreviewScript", Source)
                    if not Result.get("Passed", false): break
                    await get_tree().process_frame
                Check(Result.get("Passed", false), "Repeated preview rebuild recovers after failure")
                Measurements["TwentyPreviewMilliseconds"] = (Time.get_ticks_usec() - RebuildStart) / 1000.0
                Measurements["StaticMemoryBefore"] = MemoryStart
                Measurements["StaticMemoryAfter"] = OS.get_static_memory_usage()
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
                Source.source_code = 'local Scope=Scene.new(script.Parent)\nScope:Instantiate(Scope:Load("PackedScene", "res://Generated.tscn"))'
                Check(Plugin.call("PreviewScript", Source).get("Passed", false), "Saved native content can be composed again through the authorized scene API")
                Plugin.call("StopPreview")
                Source.source_code = Original
                EditorInterface.set_main_screen_editor("Script")
                EditorInterface.edit_script(Source, -1, 0, true)
                for Index in range(10): await get_tree().process_frame
                var Code := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
                Check(Code != null, "Created .luau opens in the actual native ScriptEditor")
                if Code:
                    var Highlight := Code.get_syntax_highlighter() as EditorSyntaxHighlighter
                    Check(Highlight != null and Highlight.get_class() == "GLLuauHighlighter", "Actual Luau CodeEdit uses the registered native editor highlighter")
                    Code.text = 'local Message = "é" --[=[ comment\ncontinued ]=]\nreturn Message\n'
                    if Highlight:
                        Highlight.clear_highlighting_cache()
                        Check(Highlight.get_line_syntax_highlighting(0).has(0) and Highlight.get_line_syntax_highlighting(1).has(0), "Native Luau lexer colors Unicode source and multiline comments in the actual editor")
                    Code.text = 'local function Build()\n return 1\nend\n\nBuild()\n'
                    Code.set_caret_line(4)
                    Code.set_caret_column(3)
                    Code.emit_signal("symbol_lookup", "Build", 4, 3)
                    for Index in range(3): await get_tree().process_frame
                    Check(Code.get_caret_line() == 0, "Actual ScriptEditor navigation reaches the Luau declaration")
                    Code.text = Original
                # Use actual EditorInterface play/stop and debugger transport.
                # These disposable resources are not open in the ScriptEditor,
                # so its normal save-on-play cannot overwrite them with old text.
                Check(Plugin.call("CreateLuauScene", "res://Failure.tscn").get("Passed", false), "Native authoring creates an independent debug scene")
                var Failure: Script = load("res://Failure.luau")
                Failure.source_code = 'local Value=54; local Opaque=game\nerror("expected editor-run diagnostic "..Value)'
                ResourceSaver.save(Failure)
                EditorInterface.play_custom_scene("res://Failure.tscn")
                var Deadline := Time.get_ticks_msec() + 12000
                var Captured: Array = []
                while Time.get_ticks_msec() < Deadline:
                    Captured = Plugin.call("GetRuntimeDiagnostics")
                    if Captured.size() >= 3: break
                    await get_tree().process_frame
                Check(Captured.size() == 4 and str(Captured[0]) == "res://Failure.luau" and str(Captured[1]).contains("expected editor-run diagnostic") and str(Captured[1]).contains(":2:"), "Actual editor-run Luau error reaches native debugger capture with source and line")
                var LocalFound := false
                var OpaqueFound := false
                if Captured.size() == 4:
                    var Snapshot: Dictionary = Captured[3]
                    Check(Snapshot.get("Schema",0)==1 and Snapshot.get("Domain","")=="Client" and Snapshot.get("FullDebugInfo",false),"Editor runtime snapshot identifies the execution domain and full debug compilation")
                    for Frame in Snapshot.get("Frames",[]):
                        for Local in Frame.get("Locals",[]):
                            LocalFound=LocalFound or (Local.Name=="Value" and Local.Value==54)
                            OpaqueFound=OpaqueFound or (Local.Name=="Opaque" and Local.Value=="opaque; no object or table traversal")
                    Check(Snapshot.get("Frames",[]).size()<=16,"Runtime snapshot retains bounded copied frames")
                Check(LocalFound and OpaqueFound,"Actual runtime error copies primitive locals and leaves native handles opaque")
                EditorInterface.stop_playing_scene()
                for Index in range(10): await get_tree().process_frame
                if Captured.size() >= 3:
                    Plugin.call("OpenRuntimeError")
                    for Index in range(5): await get_tree().process_frame
                    var ErrorCode := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
                    Check(ErrorCode != null and ErrorCode.get_caret_line() == 1, "Explicit native error navigation selects the failing source line")
                Check(Plugin.call("CreateLuauScene", "res://Recovery.tscn").get("Passed", false), "A fresh scene can be authored after runtime failure")
                var Recovery: Script = load("res://Recovery.luau")
                Recovery.source_code = Original + '\nprint("[Authoring:RunRecovery] Ready")'
                ResourceSaver.save(Recovery)
                EditorInterface.play_custom_scene("res://Recovery.tscn")
                var RecoveryObserved := false
                Deadline = Time.get_ticks_msec() + 12000
                while Time.get_ticks_msec() < Deadline and not RecoveryObserved:
                    # Godot routes child output to its editor Output control;
                    # Windows does not promise inherited parent stdout handles.
                    for Output in get_tree().root.find_children("*", "RichTextLabel", true, false):
                        if Output.get_parsed_text().contains("[Luau] [Authoring:RunRecovery] Ready"):
                            RecoveryObserved = true
                            break
                    if not RecoveryObserved: await get_tree().process_frame
                Check(EditorInterface.is_playing_scene() and RecoveryObserved, "Actual editor reruns and executes Luau after failure without restart")
                EditorInterface.stop_playing_scene()
                for Index in range(10): await get_tree().process_frame
                Check(not EditorInterface.is_playing_scene(), "Native editor stop retires the second run")
    var File := FileAccess.open("res://editor-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks, "Measurements": Measurements}))
    File.close()
    print("[Bindings:EditorIntegration] ", "PASS" if Passed else "FAIL")
    get_tree().quit(0 if Passed else 1)

func ReopenSavedScenes() -> void:
    for Path in ["res://Generated.tscn", "res://OrbSaved.tscn"]:
        EditorInterface.open_scene_from_path(Path)
        for Index in range(5): await get_tree().process_frame
        var Root := EditorInterface.get_edited_scene_root()
        Check(Root != null and Root.scene_file_path == Path and Root.get_child_count() > 0, "Fresh native editor opens saved scene " + Path)
        if Root != null and Path == "res://OrbSaved.tscn":
            for Index in range(1, 4):
                var Marker := Root.get_node_or_null("Scene/Marker" + str(Index))
                Check(Marker != null and Marker.get_child_count() == 1 and Marker.get_child(0) is MeshInstance3D and Marker.get_child(0).name == "Visual", "Saved marker " + str(Index) + " reopens with exactly one native visual")
            var FloorFound := false
            for Mesh in Root.find_children("*", "MeshInstance3D", true, false):
                var Material := Mesh.material_override as StandardMaterial3D
                if Material != null and Material.albedo_texture != null:
                    FloorFound = Material.albedo_texture.resource_path == "res://Pattern.tres"
            Check(FloorFound, "Saved scene preserves its external native texture")
    # Godot load warnings can live only in an editor dialog. Opening the scene
    # and exiting successfully alone would miss the original duplicate children.
    var LoadWarnings := false
    for Dialog in get_tree().root.find_children("*", "AcceptDialog", true, false):
        if Dialog.visible and Dialog.title == "Load Errors": LoadWarnings = true
    Check(not LoadWarnings, "Saved scenes reopen without native load-warning dialogs")
    var File := FileAccess.open("res://reopen-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks}))
    File.close()
    print("[Bindings:EditorReopen] ", "PASS" if Passed else "FAIL")
    get_tree().quit(0 if Passed else 1)
