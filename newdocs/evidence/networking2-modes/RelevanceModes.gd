extends "res://ReplicationIntegration.gd"

# Supplemental actual-ENet qualification; the complete native CI count is
# unchanged. Both incompatible project settings must terminate without a replica.
var Mode := "ServerOptIn"

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--mixed-mode": Mode = Arguments[Index + 1]
    super._initialize()

func Until(Predicate: Callable, Label: String) -> void:
    # The protocol's ten-second timeout exceeds the base fixture's eight-second
    # ordinary barrier. This supplemental fixture has its own finite bound.
    var Deadline := Time.get_ticks_msec() + 18000
    while not Predicate.call() and Time.get_ticks_msec() < Deadline: await process_frame
    Check(bool(Predicate.call()), Label)

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension loaded")
    var Enabled := (Role == "server") == (Mode == "ServerOptIn")
    ProjectSettings.set_setting("godot_luau/network/replication_relevance", Enabled)
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    Storage = Create("ReplicatedStorage", "ReplicatedStorage", Game)
    var Players := Create("Players", "Players", Game)
    Players.call("set_character_auto_loads", false)
    Create("RunService", "RunService", Game)
    if Role == "client": ScriptNode("Prewarm", "game:SetAttribute('ClientWarmed',true)")
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    if Role == "server":
        await Until(func(): return int(Network.call("get_mode")) == 1, "native server started")
        ScriptNode("Probe", "local V=Instance.new('IntValue'); V.Name='ProtocolProbe'; V.Value=173; V.Parent=game.ReplicatedStorage; game:SetAttribute('Created',true)")
        await Until(func(): return Game.has_meta("Created"), "production server created source value")
        var NativeIdentity := Storage.get_node("ProtocolProbe").get_instance_id()
        Mark("server.ready")
        await Wait("client.connected")
        await Wait("client.done")
        Check(is_instance_id_valid(NativeIdentity) and Storage.get_node("ProtocolProbe").get_instance_id() == NativeIdentity and int(Storage.get_node("ProtocolProbe").get("Value")) == 173, "incompatible peer cannot mutate or retire authoritative source")
        Check(int(Network.call("GetReplicationState").PendingMessages) == 0, "incompatible session releases structural application queue")
        Mark("server.done")
    else:
        await Until(func(): return bool(Network.call("is_connected_net")), "native client connected")
        Mark("client.connected")
        var Started := Time.get_ticks_msec()
        var Rejected := 0
        var UnexpectedReplica := false
        while bool(Network.call("is_connected_net")) and Time.get_ticks_msec() - Started < 15000:
            var State: Dictionary = Network.call("GetReplicationState")
            Rejected = maxi(Rejected, int(State.Rejected))
            UnexpectedReplica = UnexpectedReplica or Storage.has_node("ProtocolProbe") or int(State.get("ReceivedSequence", 0)) != 0
            await process_frame
        Check(not bool(Network.call("is_connected_net")) and Time.get_ticks_msec() - Started < 15000, "incompatible mode terminates within finite native deadline")
        Check(not UnexpectedReplica and not Storage.has_node("ProtocolProbe"), "incompatible modes never materialize a partial or legacy replica")
        if Mode == "ServerOptIn": Check(Rejected > 0, "non-opted client rejects actual new-protocol carrier")
        Mark("client.done")
        await Wait("server.done")
    Network.call("disconnect_net")
    Game.free(); await process_frame; await process_frame
    var Record := {"Role": Role, "Mode": Mode, "Transport": "ENet", "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases}
    Mark("evidence-" + Role + ".json", JSON.stringify(Record))
    print("[Network:ModeTest] ", Role, " ", Record.Result)
    quit(1 if Failed else 0)
