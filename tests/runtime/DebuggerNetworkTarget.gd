extends SceneTree

func Publish(Path: String) -> void:
    var File = FileAccess.open(Path + ".pending", FileAccess.WRITE)
    File.store_string("ready")
    File.close()
    assert(DirAccess.rename_absolute(Path + ".pending", Path) == OK)

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
    var Shared: String = Inputs.Coordination
    var World = Node3D.new()
    root.add_child(World)
    current_scene = World
    var Peer = ENetMultiplayerPeer.new()
    if Peer.create_server(Inputs.NetworkPort, 2) != OK:
        print("[Debugger:Target] FAIL ENet server admission")
        quit(1)
        return
    get_multiplayer().multiplayer_peer = Peer
    Publish(Shared + "/server-ready")
    var Entry = ClassDB.instantiate("ServerScript")
    Entry.set("codigo_luau", load("res://DebuggerNetwork.luau"))
    World.add_child(Entry)
    var Deadline = Time.get_ticks_msec() + 20000
    while not FileAccess.file_exists(Shared + "/client-connected") and Time.get_ticks_msec() < Deadline:
        await process_frame
    World.set_meta("NetworkReady", true)
    while World.get_meta("NetworkContinued", 0) != 42 and Time.get_ticks_msec() < Deadline:
        await process_frame
    Publish(Shared + "/server-continued")
    while not FileAccess.file_exists(Shared + "/client-reconnected") and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Passed = World.get_meta("NetworkContinued", 0) == 42 and FileAccess.file_exists(Shared + "/client-timeout") and FileAccess.file_exists(Shared + "/client-reconnected")
    print("[Debugger:Target] %s actual ENet timeout and reconnection across a native Luau pause" % ("PASS" if Passed else "FAIL"))
    Peer.close()
    World.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
