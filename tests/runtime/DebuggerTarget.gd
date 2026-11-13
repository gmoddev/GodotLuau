extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var World = Node3D.new()
    World.name = "DebuggerFixture"
    root.add_child(World)
    current_scene = World
    var Entry = ClassDB.instantiate("ServerScript")
    Entry.name = "DebuggerServer"
    Entry.set("codigo_luau", load("res://DebuggerMain.luau"))
    World.add_child(Entry)
    var Client = ClassDB.instantiate("LocalScript")
    Client.name = "DebuggerClient"
    Client.set("codigo_luau", load("res://DebuggerClient.luau"))
    World.add_child(Client)
    var Deadline = Time.get_ticks_msec() + 30000
    while not World.get_meta("DebuggerReady", false) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Button = World.find_child("DebugButton", true, false)
    if not Button:
        print("[Debugger:Target] FAIL missing real native signal source")
        quit(1)
        return
    Button.emit_signal("pressed")
    while not World.get_meta("DebuggerDone", false) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Passed = World.get_meta("DebuggerDone", 0) == 42 and World.get_meta("CallbackDone", 0) == 42
    print("[Debugger:Target] %s actual game and native signal completion" % ("PASS" if Passed else "FAIL"))
    World.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
