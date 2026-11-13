extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var World = Node3D.new()
    root.add_child(World)
    current_scene = World
    var Entry = ClassDB.instantiate("ServerScript")
    Entry.set("codigo_luau", load("res://DebuggerReload.luau"))
    World.add_child(Entry)
    var Deadline = Time.get_ticks_msec() + 15000
    while not World.get_meta("ReloadPrimed", false) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Box = World.find_child("OldDebugBox", true, false)
    var Button = World.find_child("OldDebugButton", true, false)
    if not Box or not Button:
        print("[Debugger:Target] FAIL old native scope was not admitted")
        quit(1)
        return
    var BoxId = Box.get_instance_id()
    var ButtonId = Button.get_instance_id()
    World.set_meta("ReloadObserved", true)
    while World.get_meta("ReloadDone", 0) != 42 and Time.get_ticks_msec() < Deadline:
        await process_frame
    await create_timer(0.6).timeout
    var Passed = World.get_meta("ReloadDone", 0) == 42 and not World.has_meta("ReloadOldResumed") and not World.has_meta("ReloadOldTimer") and not World.has_meta("ReloadOldSignal") and not is_instance_id_valid(BoxId) and not is_instance_id_valid(ButtonId)
    print("[Debugger:Target] %s reload replaces the generation, cancels old work and destroys old native scope" % ("PASS" if Passed else "FAIL"))
    World.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
