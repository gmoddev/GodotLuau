extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Args := OS.get_cmdline_user_args()
    ProjectSettings.set_setting("godot_luau/http/enabled", true)
    ProjectSettings.set_setting("godot_luau/http/allowed_origins", PackedStringArray([Args[0]]))
    GDExtensionManager.load_extension("res://godot_luau.gdextension")
    var Game := Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Actor: Node = ClassDB.instantiate("ServerScript")
    Actor.name = "MigratedCallers"
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = FileAccess.get_file_as_string("res://Callers.luau")
    Actor.call("set_codigo_luau", Resource)
    Game.add_child(Actor)
    var Deadline := Time.get_ticks_msec() + 10000
    while not Game.get_meta("CallersDone", false) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Passed := bool(Game.get_meta("CallersDone", false))
    Game.free()
    await process_frame
    print("[Runtime:HttpCallers] ", "PASS " if Passed else "FAIL ", Args[1])
    quit(0 if Passed else 1)
