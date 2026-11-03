extends SceneTree

var Checks: Array[Dictionary] = []
var Failed := false
var Mode := "engine"
var Cycles := 5

func _initialize() -> void:
    call_deferred("Run")

func Check(Value: bool, Label: String) -> void:
    Checks.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Runtime:SanitizerLifecycle] FAIL ", Label)

func Script(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var Instance: Node = ClassDB.instantiate(Type)
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source
    Instance.name = Name
    Instance.call("set_codigo_luau", Code)
    Parent.add_child(Instance)
    return Instance

func DomainCycle() -> void:
    var Game := Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    Script("ModuleScript", "SharedModule", "shared.Starts = (shared.Starts or 0) + 1; return {Count=shared.Starts}", Storage)
    for Type in ["ServerScript", "LocalScript"]:
        Script(Type, Type, "local M=require(game.ReplicatedStorage.SharedModule); assert(M.Count==1); game:SetAttribute(script.Name .. 'Ready', true); task.wait(100); game:SetAttribute('StaleResume', true)", Game)
    var Deadline := Time.get_ticks_msec() + 5000
    while (not Game.get_meta("ServerScriptReady", false) or not Game.get_meta("LocalScriptReady", false)) and Time.get_ticks_msec() < Deadline:
        await process_frame
    Check(Game.get_meta("ServerScriptReady", false), "Server domain initializes and requires module")
    Check(Game.get_meta("LocalScriptReady", false), "Client domain initializes and requires module")
    var Identity := Game.get_instance_id()
    Game.queue_free()
    await process_frame
    await process_frame
    Check(not is_instance_id_valid(Identity), "Scene retires domains and pending work before unload")
    current_scene = null

func Run() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(0, Arguments.size(), 2):
        if Arguments[Index] == "--mode": Mode = Arguments[Index + 1]
        if Arguments[Index] == "--cycles": Cycles = int(Arguments[Index + 1])
    Check(Mode in ["engine", "minimal", "minimal-hold", "registration", "vm-cycles"], "Known lifecycle mode")
    Check(Cycles > 0 and Cycles <= 20, "Bounded lifecycle repetitions")
    if Mode == "engine":
        Check(GDExtensionManager.get_loaded_extensions().is_empty(), "Engine baseline has no GDExtension")
        Check(not ClassDB.class_exists("LuauScript"), "Engine baseline has no GodotLuau")
        await process_frame
    else:
        for Index in range(Cycles):
            var Result := GDExtensionManager.load_extension("res://godot_luau.gdextension")
            Check(Result == GDExtensionManager.LOAD_STATUS_OK, "Actual extension load " + str(Index))
            if Result != GDExtensionManager.LOAD_STATUS_OK: break
            Check(GDExtensionManager.is_extension_loaded("res://godot_luau.gdextension"), "Library is loaded")
            if Mode == "vm-cycles": await DomainCycle()
            if Mode == "minimal-hold": break
            if Mode != "minimal": Check(ClassDB.class_exists("LuauScript"), "Production language registered")
            var Unloaded := GDExtensionManager.unload_extension("res://godot_luau.gdextension")
            Check(Unloaded == GDExtensionManager.LOAD_STATUS_OK, "Actual extension unload " + str(Index))
            Check(not GDExtensionManager.is_extension_loaded("res://godot_luau.gdextension"), "Library is unloaded")
            if Mode != "minimal": Check(not ClassDB.class_exists("LuauScript"), "Production language unregistered")
            await process_frame
    var File := FileAccess.open("res://sanitizer-lifecycle.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Mode": Mode, "Cycles": Cycles, "Checks": Checks, "Result": "FAIL" if Failed else "PASS"}))
    File.close()
    print("[Runtime:SanitizerLifecycle] ", "FAIL" if Failed else "PASS", " mode=", Mode)
    quit(1 if Failed else 0)
