extends SceneTree

class Target extends Node:
    var Calls := 0
    @rpc("any_peer", "call_remote", "reliable", 0)
    func _re_deliver_server(_Bytes: PackedByteArray) -> void:
        Calls += 1
    @rpc("any_peer", "call_remote", "reliable", 0)
    func Control() -> void:
        Calls += 1
    @rpc("any_peer", "call_remote", "unreliable", 0)
    func _ure_deliver_server(_Bytes: PackedByteArray) -> void:
        Calls += 1

var Cases: Array[Dictionary] = []
var Failed := false
var Measurements: Dictionary = {}

func _initialize() -> void:
    multiplayer_poll = false
    call_deferred("Run")

func Check(Value: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Network:NativeRPC] FAIL ", Label)

func Run() -> void:
    var Server := ENetMultiplayerPeer.new()
    var Client := ENetMultiplayerPeer.new()
    Check(Server.create_server(0, 1, 2) == OK, "native RPC server created")
    Check(Client.create_client("127.0.0.1", Server.get_host().get_local_port(), 2) == OK, "native RPC client created")
    var ServerRoot := Node.new(); ServerRoot.name = "Server"; root.add_child(ServerRoot)
    var ClientRoot := Node.new(); ClientRoot.name = "Client"; root.add_child(ClientRoot)
    var ServerAPI := SceneMultiplayer.new(); var ClientAPI := SceneMultiplayer.new()
    set_multiplayer(ServerAPI, ServerRoot.get_path()); set_multiplayer(ClientAPI, ClientRoot.get_path())
    ServerAPI.multiplayer_peer = Server; ClientAPI.multiplayer_peer = Client
    var ServerTarget := Target.new(); ServerTarget.name = "Target"; ServerRoot.add_child(ServerTarget)
    var ClientTarget := Target.new(); ClientTarget.name = "Target"; ClientRoot.add_child(ClientTarget)
    var Deadline := Time.get_ticks_msec() + 5000
    while (Client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or ServerAPI.get_peers().size() != 1) and Time.get_ticks_msec() < Deadline:
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    Check(Client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and ServerAPI.get_peers().size() == 1, "production SceneRPC peers connect")
    Check(ClientTarget.rpc_id(1, "_re_deliver_server", PackedByteArray([1])) == OK, "normal RPC handoff succeeds")
    Deadline = Time.get_ticks_msec() + 5000
    while (ServerTarget.Calls != 1 or int(Client.get_peer(1).call("GetGodotLuauAdmission").PeerBytes) != 0) and Time.get_ticks_msec() < Deadline:
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    Check(ServerTarget.Calls == 1, "normal RPC executes on the actual receiver")
    # Finish the path-confirmation handshake before pausing the receiver.
    for Index in range(5):
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    var Link := Client.get_peer(1)
    Link.throttle_configure(5000, 32, 0) # Functional MTU probe; no ambient one-shot throttle loss.
    var PrefixBytes := (str(ClientRoot.get_path()) + "/").to_utf8_buffer().size()
    var NameBytes := 256 - PrefixBytes
    var LongName := "雪".repeat(NameBytes / 3) + "x".repeat(NameBytes % 3)
    var ServerLong := Target.new(); ServerLong.name = LongName; ServerRoot.add_child(ServerLong)
    var ClientLong := Target.new(); ClientLong.name = LongName; ClientRoot.add_child(ClientLong)
    Check(str(ClientLong.get_path()).to_utf8_buffer().size() == 256, "uncached native RPC uses maximum admitted UTF-8 node path")
    var Frame := PackedByteArray(); Frame.resize(816) # 768-byte body + 48-byte GER2 header.
    Check(ClientLong.rpc_id(1, "_ure_deliver_server", Frame) == OK, "maximum unreliable Remote frame submits through uncached RPC path")
    var Packet: Dictionary = Link.call("GetGodotLuauAdmission")
    Measurements = {"NodePathUTF8Bytes": str(ClientLong.get_path()).to_utf8_buffer().size(), "RemoteFrameBytes": Frame.size(), "RetainedNativePacketBytes": int(Packet.PeerBytes), "UncachedSubmittedPacketBytes": int(Packet.LastSubmittedBytes), "UncachedSubmittedCommands": int(Packet.LastSubmittedCommands), "MTU": int(Packet.MTU), "UnfragmentedPacketBytes": int(Packet.UnfragmentedPacketBytes)}
    Check(int(Packet.LastSubmittedCommands) == 1 and int(Packet.LastSubmittedBytes) >= Frame.size() and int(Packet.LastSubmittedBytes) <= Frame.size() + 384 and int(Packet.LastSubmittedBytes) <= int(Packet.UnfragmentedPacketBytes), "complete uncached UTF-8-path RPC packet fits negotiated MTU without native fragmentation")
    Deadline = Time.get_ticks_msec() + 5000
    while (ServerLong.Calls != 1 or int(Link.call("GetGodotLuauAdmission").PeerBytes) != 0) and Time.get_ticks_msec() < Deadline:
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    Check(ServerLong.Calls == 1 and int(Link.call("GetGodotLuauAdmission").PeerBytes) == 0, "maximum UTF-8-path unreliable RPC reaches actual receiver and retires")
    for Index in range(5):
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    Check(ClientLong.rpc_id(1, "_ure_deliver_server", Frame) == OK, "maximum unreliable Remote frame submits through cached RPC path")
    Packet = Link.call("GetGodotLuauAdmission")
    Measurements["CachedSubmittedPacketBytes"] = int(Packet.LastSubmittedBytes)
    Measurements["CachedSubmittedCommands"] = int(Packet.LastSubmittedCommands)
    Check(int(Packet.LastSubmittedCommands) == 1 and int(Packet.LastSubmittedBytes) >= Frame.size() and int(Packet.LastSubmittedBytes) <= Frame.size() + 384 and int(Packet.LastSubmittedBytes) <= int(Packet.UnfragmentedPacketBytes), "complete cached RPC packet fits negotiated MTU without native fragmentation")
    Deadline = Time.get_ticks_msec() + 5000
    while int(Link.call("GetGodotLuauAdmission").PeerBytes) != 0 and Time.get_ticks_msec() < Deadline:
        ServerAPI.poll(); ClientAPI.poll(); await process_frame
    var Bytes := PackedByteArray(); Bytes.resize(int(Link.call("GetGodotLuauAdmission").PeerByteLimit))
    Check(Link.send(0, Bytes, ENetPacketPeer.FLAG_RELIABLE) == OK, "native ownership fills while receiver is paused")
    var Full: Dictionary = Link.call("GetGodotLuauAdmission")
    Check(ClientTarget.rpc_id(1, "_re_deliver_server", PackedByteArray([2])) == ERR_BUSY, "confirmed-path RPC propagates native WouldBlock")
    Check(Link.call("GetGodotLuauAdmission") == Full and Client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "queued Remote RPC rejection retains old ownership and live retry session")
    var ServerFresh := Target.new(); ServerFresh.name = "Fresh"; ServerRoot.add_child(ServerFresh)
    var ClientFresh := Target.new(); ClientFresh.name = "Fresh"; ClientRoot.add_child(ClientFresh)
    Check(ClientFresh.rpc_id(1, "_re_deliver_server", PackedByteArray([3])) == ERR_BUSY, "unconfirmed full-path RPC propagates native WouldBlock")
    Check(Link.call("GetGodotLuauAdmission") == Full, "unconfirmed rejected RPC does not retain candidate ownership")
    Check(ClientTarget.rpc_id(1, "Control") == ERR_BUSY, "unbuffered reliable control RPC reports native exhaustion")
    Check(Client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not bool(Link.call("GetGodotLuauAdmission").Active), "unbuffered reliable control failure terminates affected session explicitly")
    Client.close(); Server.close()
    ServerRoot.free(); ClientRoot.free()
    var Output := FileAccess.open("res://native-rpc-admission.json", FileAccess.WRITE)
    Output.store_string(JSON.stringify({"Result": "FAIL" if Failed else "PASS", "Complete": true, "Cases": Cases, "Measurements": Measurements}, "  ")); Output.close()
    print("[Network:NativeRPC] ", "FAIL" if Failed else "PASS", " cases=", Cases.size())
    quit(1 if Failed else 0)
