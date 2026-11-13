extends SceneTree

var Connected = false
var Lost = false

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
    var Deadline = Time.get_ticks_msec() + 20000
    while not FileAccess.file_exists(Shared + "/server-ready") and Time.get_ticks_msec() < Deadline:
        await process_frame
    var API = get_multiplayer()
    API.connected_to_server.connect(func(): Connected = true)
    API.server_disconnected.connect(func(): Lost = true)
    var Peer = ENetMultiplayerPeer.new()
    if Peer.create_client("127.0.0.1", Inputs.NetworkPort) != OK:
        quit(1)
        return
    API.multiplayer_peer = Peer
    while not Connected and Time.get_ticks_msec() < Deadline:
        await process_frame
    if not Connected:
        print("[Debugger:Network] FAIL initial ENet connection")
        quit(1)
        return
    # Explicit fixture limits expose the expected transport timeout in a bounded
    # pause; production timeout configuration remains unchanged.
    Peer.get_peer(1).ping_interval(50)
    Peer.get_peer(1).set_timeout(1, 300, 700)
    Publish(Shared + "/client-connected")
    while not Lost and Time.get_ticks_msec() < Deadline:
        await process_frame
    if not Lost:
        print("[Debugger:Network] FAIL peer did not time out during the server pause")
        quit(1)
        return
    Publish(Shared + "/client-timeout")
    while not FileAccess.file_exists(Shared + "/server-continued") and Time.get_ticks_msec() < Deadline:
        await process_frame
    Peer.close()
    Connected = false
    Peer = ENetMultiplayerPeer.new()
    if Peer.create_client("127.0.0.1", Inputs.NetworkPort) != OK:
        quit(1)
        return
    API.multiplayer_peer = Peer
    while not Connected and Time.get_ticks_msec() < Deadline:
        await process_frame
    if Connected:
        Publish(Shared + "/client-reconnected")
    print("[Debugger:Network] %s fresh ENet connection after native debugger Continue" % ("PASS" if Connected else "FAIL"))
    Peer.close()
    quit(0 if Connected else 1)
