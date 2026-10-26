extends SceneTree

var Server: SceneMultiplayer
var Disconnections := 0
var Dispatch := "none"

func _initialize() -> void:
    multiplayer_poll = false
    call_deferred("Run")

func OnDisconnected(Identity: int) -> void:
    Disconnections += 1
    print("[Network:Probe] Disconnect ", Identity, " remaining API peers=", Server.get_peers())
    if Dispatch != "none" and not Server.get_peers().is_empty():
        Server.send_bytes(PackedByteArray([42]), 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE)

func Run() -> void:
    var Arguments := OS.get_cmdline_user_args()
    var Port := int(Arguments[0])
    var Relay := Arguments.size() < 2 or Arguments[1] != "false"
    Dispatch = Arguments[2] if Arguments.size() > 2 else "none"
    Server = SceneMultiplayer.new()
    Server.root_path = NodePath("/root")
    Server.server_relay = Relay
    Server.peer_disconnected.connect(OnDisconnected, CONNECT_DEFERRED if Dispatch == "deferred" else 0)
    var Transport := ENetMultiplayerPeer.new()
    assert(Transport.create_server(Port, 4) == OK)
    Server.multiplayer_peer = Transport
    var Clients: Array[SceneMultiplayer] = []
    for Index in range(2):
        var Peer := ENetMultiplayerPeer.new()
        assert(Peer.create_client("127.0.0.1", Port) == OK)
        var Client := SceneMultiplayer.new()
        Client.root_path = NodePath("/root")
        Client.multiplayer_peer = Peer
        Clients.append(Client)
    for Index in range(200):
        Server.poll()
        for Client in Clients: Client.poll()
        if Server.get_peers().size() == 2: break
        await create_timer(0.005).timeout
    if Server.get_peers().size() != 2:
        print("[Network:Probe] FAIL connect")
        quit(1)
        return
    # Both disconnect datagrams arrive before one server poll. There are no
    # extension classes, scripts, RPC callbacks or Luau VMs in this probe.
    for Client in Clients: Client.multiplayer_peer.close()
    await create_timer(0.05).timeout
    for Index in range(50):
        Server.poll()
        if Disconnections == 2: break
        await create_timer(0.005).timeout
    Transport.close()
    print("[Network:Probe] ", "PASS" if Disconnections == 2 else "FAIL", " relay=", Relay)
    quit(0 if Disconnections == 2 else 1)
