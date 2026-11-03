extends SceneTree

# GL-029 controlled ENet actors. Files coordinate phases only; event traffic,
# descriptors, readiness and adversarial frames use production RPC handlers.
var Game: Node
var Network: Node
var Storage: Node
var Role := "server"
var Mode := "Listen"
var Index := 0
var Port := 0
var Failed := false
var Cases: Array[Dictionary] = []

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Position in range(Arguments.size() - 1):
        match Arguments[Position]:
            "--fixture-role": Role = Arguments[Position + 1]
            "--fixture-client-index": Index = int(Arguments[Position + 1])
            "--fixture-port": Port = int(Arguments[Position + 1])
            "--remote-mode": Mode = Arguments[Position + 1]
    call_deferred("Run")

func Check(Value: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Network:RemoteTest] FAIL ", Role, Index, " ", Label)

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://remote-" + Name, FileAccess.WRITE)
    File.store_string("ready")
    File.close()

func SaveIdentity() -> void:
    var File := FileAccess.open("res://remote-client" + str(Index) + "-identity.json", FileAccess.WRITE)
    File.store_string(JSON.stringify(State()))
    File.close()

func Until(Test: Callable, Label: String) -> void:
    var Deadline := Time.get_ticks_msec() + 15000
    while not Test.call() and Time.get_ticks_msec() < Deadline:
        if Role == "server" and Game.has_meta("QueueFlush"):
            var User := int(Game.get_meta("QueueFlush"))
            Check(bool(Network.call("QualificationRemoteControl", "DrainOutgoing", true)), "controlled queue handoff precedes native flush")
            Network.get_multiplayer().get_multiplayer_peer().get_host().flush()
            Mark("queue-flushed-" + str(User))
            Game.remove_meta("QueueFlush")
        await process_frame
    Check(bool(Test.call()), Label)

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Object: Node = ClassDB.instantiate(Type)
    Object.name = Name
    Parent.add_child(Object)
    return Object

func PlayerEntering(Child: Node) -> void:
    if Role == "server" and Child.is_class("PlayerObject") and str(Child.name).begins_with("Player_"):
        var Peer := int(str(Child.name).trim_prefix("Player_"))
        Check(Network.call("player_node_for_peer", Peer) == Child, "Player identity is reserved before reentrant native child callbacks")

func ConfigurePeer(Peer: int) -> void:
    # Functional loopback probes need an unthrottled carrier. Instrumented
    # startup can otherwise legitimately throttle one-shot unreliable sends.
    var Transport = Network.get_multiplayer().get_multiplayer_peer()
    if Transport is ENetMultiplayerPeer and (Transport.get_unique_id() == 1 or Peer == 1):
        var Link = Transport.get_peer(Peer)
        if Link:
            Link.throttle_configure(5000, 32, 0)
            Check(int(Link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)) == 0, "functional carrier throttle profile applied to fresh peer")

func ScriptRun(Name: String, Source: String, Client := false) -> Node:
    var Object: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Object.name = Name
    Object.call("set_codigo_luau", Resource)
    Game.add_child(Object)
    return Object

func State(Name := "Reliable") -> Dictionary:
    return Network.call("GetRemoteState", Storage.get_node_or_null(NodePath(Name)))

func Ready(Name: String) -> bool:
    return bool(State(Name).get("Ready", false))

func Frame(Identity: Dictionary, Text := "Unauthorized", Delivery := 0, Sequence := 0) -> PackedByteArray:
    var Bytes := PackedByteArray()
    Bytes.resize(48)
    Bytes.encode_u32(0, 0x32524547)
    Bytes.encode_u32(4, Delivery)
    Bytes.encode_u64(8, int(Identity.get("Epoch", 0)))
    Bytes.encode_u64(16, int(Identity.get("User", 0)))
    Bytes.encode_u64(24, int(Identity.get("Endpoint", 0)))
    Bytes.encode_u64(32, int(Identity.get("Generation", 0)))
    Bytes.encode_u64(40, Sequence)
    Bytes.append(TYPE_ARRAY)
    var Count := PackedByteArray(); Count.resize(4); Count.encode_u32(0, 1); Bytes.append_array(Count)
    Bytes.append(TYPE_STRING)
    Count.encode_u32(0, Text.to_utf8_buffer().size()); Bytes.append_array(Count); Bytes.append_array(Text.to_utf8_buffer())
    return Bytes

func Attack() -> void:
    var Identity := State()
    var Before := int(Identity.Delivered)
    for Field in ["Epoch", "User", "Endpoint", "Generation"]:
        var Forged := Identity.duplicate()
        Forged[Field] = int(Forged[Field]) + 9999
        Network.rpc_id(1, "_re_deliver_server", Frame(Forged))
    Network.rpc_id(1, "_ure_deliver_server", Frame(Identity, "Unauthorized", 1))
    Network.rpc_id(1, "_re_deliver_server", Frame(Identity, "Unauthorized", 3))
    Network.rpc_id(1, "_re_deliver_server", "wrong wire type")
    Network.rpc_id(1, "_re_deliver_server", PackedByteArray([1, 2, 3]))
    var Oversized := PackedByteArray(); Oversized.resize(65537)
    Network.rpc_id(1, "_re_deliver_server", Oversized)
    var Malformed := Frame(Identity)
    Malformed.encode_u32(49, 0xffffffff) # Reject impossible count before allocation.
    Network.rpc_id(1, "_re_deliver_server", Malformed)
    Malformed = Frame(Identity); Malformed.encode_u32(0, 0x31524547)
    Network.rpc_id(1, "_re_deliver_server", Malformed) # GER1 cannot be silently reinterpreted as GER2.
    Malformed = Frame(Identity); Malformed.append(0)
    Network.rpc_id(1, "_re_deliver_server", Malformed)
    Network.rpc_id(1, "_remote_ack", Identity.Epoch, Identity.User + 1, Identity.Endpoint, Identity.Generation)
    Network.rpc_id(1, "_remote_descriptor", [Identity.Epoch, Identity.User, 9000, 9000, 0, str(Storage.get_path()) + "/Reliable", 0, false, 2])
    Network.rpc_id(1, "_re_deliver_client", Frame(Identity))
    var Other := 2 if Index == 1 else 1
    var TargetIdentity: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://remote-client" + str(Other) + "-identity.json"))
    var ForeignSent := 0
    for Peer in Network.get_multiplayer().get_peers():
        if Peer != 1:
            ForeignSent += 1
            Network.rpc_id(Peer, "_re_deliver_client", Frame(TargetIdentity))
            Network.rpc_id(Peer, "_remote_active", TargetIdentity.Epoch, TargetIdentity.User, TargetIdentity.Endpoint, TargetIdentity.Generation)
    Check(ForeignSent == 1, "wrong transport sender reaches the other real ENet Client")
    await create_timer(0.15).timeout
    Check(int(State().Delivered) == Before, "forged traffic produces no local event dispatch")

func CarrierProbe(Identity: Dictionary, DeliveryMode: int, Channel: int, Sequence: int) -> void:
    # Pinned SceneRPC byte-only packet format. Use the actual sorted native RPC
    # name inventory, without assuming a mutable RPC config invalidates its cache.
    var Names := ["_character_grant", "_character_ready", "_character_removed", "_character_reset", "_character_sync", "_gl_assign", "_gl_peer_uid", "_gl_teleport", "_kicked", "_load_character", "_phys_owned", "_phys_owner", "_phys_state", "_ping_report", "_ping_req", "_ping_res", "_re_deliver_client", "_re_deliver_server", "_recv_anim", "_recv_anim_v2", "_recv_character", "_recv_chat", "_recv_remove", "_recv_state", "_recv_state2d", "_relay_anim", "_relay_anim_v2", "_relay_character", "_relay_chat", "_relay_state", "_relay_state2d", "_remote_ack", "_remote_active", "_remote_descriptor", "_remote_retire", "_rep_destroy", "_rep_new", "_rep_prop", "_rep_reparent", "_rf_invoke_client", "_rf_invoke_server", "_rf_return", "_set_char_health", "_set_team", "_time_req", "_time_res", "_ure_deliver_client", "_ure_deliver_server"]
    var Body := Frame(Identity, "Unauthorized", 2, Sequence)
    var Packet := PackedByteArray(); Packet.resize(7)
    Packet[0] = 224 # Remote call, 32-bit full-path offset, 16-bit method, byte-only.
    Packet.encode_u32(1, 0x80000000 | (7 + Body.size()))
    Packet.encode_u16(5, 0x8000 | Names.find("_ure_deliver_server"))
    Packet.append_array(Body)
    var RootNode := root.get_node(Network.get_multiplayer().get_root_path())
    Packet.append_array(str(RootNode.get_path_to(Network)).to_utf8_buffer()); Packet.append(0)
    var Transport := Network.get_multiplayer().get_multiplayer_peer()
    Transport.set_target_peer(1); Transport.set_transfer_mode(DeliveryMode); Transport.set_transfer_channel(Channel)
    Check(Transport.put_packet(Packet) == OK, "wrong-carrier probe reaches actual native transport")

func Sequencing() -> void:
    var Identity := State("Sequenced")
    var Before := int(Network.call("GetRemoteState", null).OutgoingMessages)
    # These are real RPC packets. Their payload stream is intentionally reordered;
    # neither a forged high sequence nor the wrong actual carrier may poison it.
    var Malformed := Frame(Identity, "Unauthorized", 2, 0x7fffffffffffffff)
    Malformed.append(0)
    Network.rpc_id(1, "_ure_deliver_server", Malformed)
    CarrierProbe(Identity, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 100)
    CarrierProbe(Identity, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, 1, 101)
    for Sequence in [3, 1, 2, 3, 4]:
        Network.rpc_id(1, "_ure_deliver_server", Frame(Identity, "Seq" + str(Sequence), 2, Sequence))
    Network.get_multiplayer().get_multiplayer_peer().get_host().flush()
    Check(int(Network.call("GetRemoteState", null).OutgoingMessages) == Before, "wire-order probe does not manufacture Remote queue admission")
    Mark("client" + str(Index) + "-sequence-sent")
    await Until(func(): return FileAccess.file_exists("res://remote-sequence-drained"), "freshness samples dispatched at controlled drain")
    Check(bool(Network.call("QualificationRemoteControl", "SeedSend", {"Remote": Storage.get_node("Sequenced"), "Peer": 1, "Sequence": 4})), "native send counter resumes after controlled wire-order probe")
    Check(bool(Network.call("QualificationRemoteControl", "PauseSend", true)), "outbound supersession barrier established")
    ScriptRun("Supersede", "local R = game.ReplicatedStorage.Sequenced; for N = 5, 7 do R:FireServer('Seq' .. N) end; game:SetAttribute('Superseded', true)", true)
    await Until(func(): return Game.has_meta("Superseded"), "three sequenced samples admitted from production Lua API")
    var Queued: Dictionary = Network.call("GetRemoteState", null)
    Check(int(Queued.OutgoingMessages) == 1 and int(Queued.Superseded) >= 2, "sequenced stream retains only newest unsent sample")
    Check(bool(Network.call("QualificationRemoteControl", "PauseSend", false)), "superseded stream resumes native handoff")
    Mark("client" + str(Index) + "-supersession-ready")
    await Until(func(): return FileAccess.file_exists("res://remote-sequence-complete"), "both independent peer streams retain accepted freshness")

func ServerPressure() -> void:
    await Until(func(): return int(Game.get_meta("UnorderedProbeCount", 0)) == 8, "unordered carrier dispatches reordered and duplicate valid payloads without freshness filtering")
    ScriptRun("CheckUnordered", "local Count = 0; for _, Values in pairs(_G.UnorderedValues) do assert(#Values == 4 and Values[1] == 'UnorderedProbe3' and Values[2] == 'UnorderedProbe1' and Values[3] == 'UnorderedProbe3' and Values[4] == 'UnorderedProbe2'); Count += 1 end; assert(Count == 2); game:SetAttribute('UnorderedVerified', true)")
    await Until(func(): return Game.has_meta("UnorderedVerified"), "unordered duplicate/reorder injection preserves each peer's actual submitted payload order")
    var First: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://remote-client1-identity.json"))
    var Slow := 0
    var Healthy := 0
    var Streams: Dictionary = State().PeerStreams
    for Peer in Streams:
        if int(Streams[Peer].User) == int(First.User): Slow = int(Peer)
        else: Healthy = int(Peer)
    Check(Slow > 1 and Healthy > 1, "pressure targets resolve actual independent peer sessions")
    Game.set_meta("PressureUser", int(First.User))
    ScriptRun("TargetedSequence", "local P; for _, V in ipairs(game:GetService('Players'):GetPlayers()) do if V.UserId == game:GetAttribute('PressureUser') then P = V end end; assert(P); game.ReplicatedStorage.Sequenced:FireClient(P, 'Target'); game:SetAttribute('DirectedSubmitted', true)")
    await Until(func(): return Game.has_meta("DirectedSubmitted"), "targeted sequenced admission completes")
    var Directed: Dictionary = State("Sequenced").PeerStreams
    Check(str(Directed[Slow].SentSequence) == "1" and str(Directed[Healthy].SentSequence) == "0", "targeted send advances only its actual egress peer stream")
    Mark("direction-target")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-direction-target") and FileAccess.file_exists("res://remote-client2-direction-target"), "targeted egress reaches only intended client")
    ScriptRun("BroadcastSequence", "game.ReplicatedStorage.Sequenced:FireAllClients('Broadcast'); game:SetAttribute('BroadcastSubmitted', true)")
    await Until(func(): return Game.has_meta("BroadcastSubmitted"), "sequenced broadcast admits independently per peer")
    Directed = State("Sequenced").PeerStreams
    Check(str(Directed[Slow].SentSequence) == "2" and str(Directed[Healthy].SentSequence) == "1" and str(Directed[Slow].ReceivedSequence) == "7" and str(Directed[Healthy].ReceivedSequence) == "7", "targeted and broadcast egress share each peer stream without sharing ingress freshness")
    Mark("direction-broadcast")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-direction-broadcast") and FileAccess.file_exists("res://remote-client2-direction-broadcast"), "both client freshness streams accept their independent broadcast sequences")
    Check(bool(Network.call("QualificationRemoteControl", "PauseSend", true)) and bool(Network.call("QualificationRemoteControl", "BusyPeer", Slow)), "one peer's native WouldBlock is held at a deterministic handoff barrier")
    var Submitter := ScriptRun("PressureSubmitter", "local R = game.ReplicatedStorage.PressureReliable; for N = 1, 64 do R:FireAllClients('Pressure', N) end; game:SetAttribute('PressureSubmitted', true)")
    await Until(func(): return Game.has_meta("PressureSubmitted"), "reliable fanout is admitted before submitting owner retirement")
    Submitter.free()
    Check(int(Network.call("GetRemoteState", null).OutgoingMessages) == 128, "accepted fanout survives submitting script destruction")
    var Deadline := Time.get_ticks_msec() + 5000
    while int(Network.call("GetRemotePeerState", Healthy).OutgoingMessages) and Time.get_ticks_msec() < Deadline:
        Network.call("QualificationRemoteControl", "DrainOutgoing", true)
        await process_frame
    Check(int(Network.call("GetRemotePeerState", Healthy).OutgoingMessages) == 0 and int(Network.call("GetRemotePeerState", Slow).OutgoingMessages) == 64, "healthy peer progresses while slow peer retains its exact reliable FIFO")
    Mark("pressure-healthy")
    await Until(func(): return FileAccess.file_exists("res://remote-client2-pressure-healthy"), "healthy client receives all accepted events during another peer's congestion")
    Network.call("QualificationRemoteControl", "BusyPeer", 0)
    Network.call("QualificationRemoteControl", "PauseSend", false)
    Mark("pressure-resumed")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-pressure-received") and FileAccess.file_exists("res://remote-client2-pressure-received"), "both FIFO streams complete after bounded backpressure")
    Network.call("QualificationRemoteControl", "PauseSend", true)
    Game.set_meta("PressureUser", int(First.User))
    var Dropped := int(Network.call("GetRemoteState", null).Dropped)
    ScriptRun("UnorderedLimit", "local P; for _, V in ipairs(game:GetService('Players'):GetPlayers()) do if V.UserId == game:GetAttribute('PressureUser') then P = V end end; assert(P); local R = game.ReplicatedStorage.PressureUnordered; for N = 1, 1025 do R:FireClient(P, N) end; game:SetAttribute('UnorderedLimit', true)")
    await Until(func(): return Game.has_meta("UnorderedLimit"), "production unordered API reaches bounded record admission")
    Check(int(Network.call("GetRemotePeerState", Slow).OutgoingMessages) == 1024 and int(Network.call("GetRemoteState", null).Dropped) == Dropped + 1, "exact unordered record ceiling admits and one-over drops without evicting old work")
    Check(int(Network.call("GetRemotePeerState", Healthy).OutgoingMessages) == 0, "unordered overload does not charge another peer")
    Storage.get_node("PressureUnordered").free()
    await Until(func(): return int(Network.call("GetRemoteState", null).OutgoingMessages) == 0, "publication destruction retires exact queued ownership")
    Network.call("QualificationRemoteControl", "PauseSend", false)
    Mark("pressure-complete")
    await Until(func(): return int(Game.get_meta("FinalSequences", 0)) == 2, "independent native streams accept the last positive sequence")
    Mark("final-sequences")

func ClientPressure() -> void:
    for Value in [3, 1, 3, 2]:
        Network.rpc_id(1, "_ure_deliver_server", Frame(State("Unordered"), "UnorderedProbe" + str(Value), 1))
    Network.get_multiplayer().get_multiplayer_peer().get_host().flush()
    await Until(func(): return FileAccess.file_exists("res://remote-direction-target"), "targeted sequenced egress barrier")
    if Index == 1:
        await Until(func(): return Game.has_meta("DirectionTarget"), "targeted sequenced message reaches selected client")
    else:
        Check(not Game.has_meta("DirectionTarget"), "targeted sequenced message does not leak to another peer")
    Mark("client" + str(Index) + "-direction-target")
    await Until(func(): return FileAccess.file_exists("res://remote-direction-broadcast") and Game.has_meta("DirectionBroadcast"), "broadcast sequenced message reaches both clients")
    Check(int(Game.get_meta("DirectionCount", 0)) == (2 if Index == 1 else 1), "client sequenced callback starts match independent targeted/broadcast admission")
    Mark("client" + str(Index) + "-direction-broadcast")
    await Until(func(): return FileAccess.file_exists("res://remote-pressure-healthy"), "fair peer service barrier")
    if Index == 2:
        await Until(func(): return int(Game.get_meta("PressureReceived", 0)) == 64, "healthy receiver preserves reliable callback-start order")
        Mark("client2-pressure-healthy")
    await Until(func(): return FileAccess.file_exists("res://remote-pressure-resumed"), "slow peer handoff resumes")
    await Until(func(): return int(Game.get_meta("PressureReceived", 0)) == 64, "admitted reliable work completes after submitting owner destruction")
    Mark("client" + str(Index) + "-pressure-received")
    await Until(func(): return FileAccess.file_exists("res://remote-pressure-complete"), "record admission and publication retirement complete")
    Check(Ready("Unordered") and Ready("SequenceOther"), "queue-age barrier begins with live unrelated publications")
    var QueueTime := Time.get_ticks_usec()
    Network.call("QualificationRemoteControl", "Clock", QueueTime)
    Network.call("QualificationRemoteControl", "PauseSend", true)
    Check(Ready("Unordered") and Ready("SequenceOther"), "queue clock barrier preserves unrelated publication readiness")
    print("[Network:RemoteTest] AgeBarrier ", Index, " ", JSON.stringify(State("Unordered")))
    var OldDrops := int(Network.call("GetRemoteState", null).Dropped)
    ScriptRun("ExpiredUnordered", "game.ReplicatedStorage.Unordered:FireServer('Unauthorized'); game:SetAttribute('ExpiredUnorderedAdmitted', true)", true)
    await Until(func(): return Game.has_meta("ExpiredUnorderedAdmitted"), "unordered queue-age sample admitted")
    Check(int(Network.call("GetRemoteState", null).OutgoingMessages) == 1, "unordered age fixture owns one unsent record")
    Network.call("QualificationRemoteControl", "Clock", QueueTime + 250001)
    Network.call("QualificationRemoteControl", "DrainOutgoing", true)
    Check(int(Network.call("GetRemoteState", null).OutgoingMessages) == 0 and int(Network.call("GetRemoteState", null).Dropped) == OldDrops + 1 and Ready("Unordered"), "expired unreliable work drops with accounting while its session remains healthy")
    Network.call("QualificationRemoteControl", "PauseSend", true)
    Check(bool(Network.call("QualificationRemoteControl", "SeedSend", {"Remote": Storage.get_node("SequenceOther"), "Peer": 1, "Sequence": 0x7ffffffffffffffe})), "native counter seeds immediately below exhaustion")
    ScriptRun("FinalSequence", "local R = game.ReplicatedStorage.SequenceOther; R:FireServer('Final'); assert(not pcall(function() R:FireServer('Unauthorized') end)); game:SetAttribute('FinalSequenceSubmitted', true)", true)
    await Until(func(): return Game.has_meta("FinalSequenceSubmitted"), "last valid sequence admits and next send fails before mutation")
    Check(str(State("SequenceOther").SentSequence) == "9223372036854775807" and int(Network.call("GetRemoteState", null).OutgoingMessages) == 1 and str(State("Sequenced").SentSequence) == "7", "sequence exhaustion preserves accepted candidate and independent Remote counter")
    Network.call("QualificationRemoteControl", "PauseSend", false)
    await Until(func(): return FileAccess.file_exists("res://remote-final-sequences"), "last positive native sequences arrive without wrapping")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded == GDExtensionManager.LOAD_STATUS_OK or Loaded == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED, "production extension loads")
    Game = Node.new(); Game.name = "Game"; Game.set_meta("Port", Port); root.add_child(Game); current_scene = Game
    Storage = Create("ReplicatedStorage", "ReplicatedStorage", Game)
    Create("Players", "Players", Game)
    Create("RunService", "RunService", Game)
    Create("ServerStorage", "ServerStorage", Game)
    Create("RemoteEventNode", "Reliable", Storage)
    Create("RemoteEventNode", "Cancel", Storage)
    Create("RemoteEventNode", "PressureReliable", Storage)
    Create("RemoteFunctionNode", "Function", Storage)
    var Unordered: Node = ClassDB.instantiate("RemoteEventNode")
    Check(bool(Unordered.call("SetDeliveryType", 1)), "native unpublished unordered configuration")
    Unordered.name = "Unordered"; Storage.add_child(Unordered)
    var Sequenced: Node = ClassDB.instantiate("RemoteEventNode")
    Check(bool(Sequenced.call("SetDeliveryType", 2)), "native unpublished sequenced configuration")
    Sequenced.name = "Sequenced"; Storage.add_child(Sequenced)
    var Other: Node = ClassDB.instantiate("RemoteEventNode")
    Other.call("SetDeliveryType", 2); Other.name = "SequenceOther"; Storage.add_child(Other)
    var Pressure: Node = ClassDB.instantiate("RemoteEventNode")
    Pressure.call("SetDeliveryType", 1); Pressure.name = "PressureUnordered"; Storage.add_child(Pressure)
    var Legacy := Create("UnreliableRemoteEventNode", "Legacy", Storage)
    Check(not bool(Legacy.call("SetDeliveryType", 0)) and int(Legacy.get("DeliveryType")) == 1, "legacy fixed unordered configuration")
    var Saved := PackedScene.new()
    Check(Saved.pack(Unordered) == OK, "native Remote scene serialization")
    var LoadedScene: Node = Saved.instantiate()
    Check(LoadedScene.is_class("RemoteEventNode") and int(LoadedScene.get("DeliveryType")) == 1, "serialized configuration survives a fresh native instance")
    LoadedScene.free()
    var HiddenFolder := Create("Node", "ReplicatedStorage", Game.get_node("ServerStorage"))
    Create("RemoteEventNode", "Hidden", HiddenFolder)
    Network = Create("NetworkService", "NetworkService", Game)
    Network.get_multiplayer().peer_connected.connect(ConfigurePeer)
    var Module := Create("ModuleScript", "DeliveryModule", Storage)
    var ModuleSource: Script = ClassDB.instantiate("LuauScript")
    ModuleSource.source_code = "return function(Remote) return pcall(function() Remote.DeliveryType = 1 end) end"
    Module.call("set_codigo_luau", ModuleSource)
    Game.get_node("Players").child_entered_tree.connect(PlayerEntering)
    # Relax only the receive carrier policy to exercise its native sender check.
    Network.rpc_config("_re_deliver_client", {"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE, "call_local": false, "channel": 0})
    Network.rpc_config("_remote_descriptor", {"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE, "call_local": false, "channel": 0})
    if Role == "server": await Server()
    else: await Client()
    var Result := {"Mode": Mode, "Role": Role, "Index": Index, "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases}
    var File := FileAccess.open("res://remote-" + Role + str(Index) + ".json", FileAccess.WRITE)
    File.store_string(JSON.stringify(Result)); File.close()
    print("[Network:RemoteTest] ", Role, " ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)

func Server() -> void:
    if Mode == "Listen":
        ScriptRun("StartServer", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4)); game:SetAttribute('Started', true)")
        await Until(func(): return Game.has_meta("Started"), "listen server starts")
    await process_frame
    Check(not Network.call("GetRemoteState", Game.get_node("ServerStorage/ReplicatedStorage/Hidden")).has("Endpoint"), "private ancestor prevents publication through a nested scope name")
    var Private := Game.get_node("ServerStorage")
    Private.name = "Secrets"
    await process_frame
    Check(not Network.call("GetRemoteState", Private.get_node("ReplicatedStorage/Hidden")).has("Endpoint"), "native private service type remains private after rename")
    Private.name = "ServerStorage"
    ScriptRun("Setup", """
assert(Enum.EventDeliveryType.ReliableOrdered == 0 and Enum.EventDeliveryType.UnreliableUnordered == 1)
assert(Enum.EventDeliveryType.UnreliableSequenced == 2)
local Allowed, Result = pcall(function() return game:GetService('NetworkService'):QualificationRemoteControl('PauseSend', true) end)
assert(not Allowed or Result == false)
local R = Instance.new('RemoteEvent')
assert(R.DeliveryType == 0 and R.ClassName == 'RemoteEvent' and R:IsA('RemoteEvent'))
assert(require(game.ReplicatedStorage.DeliveryModule)(R) and R.DeliveryType == 1)
R.DeliveryType = 0
local Shadow = Instance.new('Folder'); Shadow.Name = 'DeliveryType'; Shadow.Parent = R
assert(R.DeliveryType == 0)
for _, Value in ipairs({true, '1', 0.5, 3}) do
    pcall(function() R:set('DeliveryType', Value) end)
    assert(R.DeliveryType == 0)
end
for _, Value in ipairs({true, '1', 0.5, 3, math.huge, 0/0}) do
    assert(not pcall(function() R.DeliveryType = Value end) and R.DeliveryType == 0)
end
R.DeliveryType = 1
local Copy = R:Clone(); assert(Copy.DeliveryType == 1); Copy:Destroy()
R.Name = 'Dynamic'; R.Parent = game.ReplicatedStorage
_G.Dynamic = R
local Legacy = Instance.new('UnreliableRemoteEvent')
-- Preserve the inherited native class identity; it has no Roblox-name alias.
assert(Legacy.ClassName == 'UnreliableRemoteEventNode' and Legacy:IsA('UnreliableRemoteEventNode') and Legacy:IsA('RemoteEventNode') and Legacy.DeliveryType == 1)
assert(not pcall(function() Legacy.DeliveryType = 0 end)); Legacy:Destroy()
game.ReplicatedStorage.Reliable:FireAllClients('Warmup')
assert(not pcall(function() game.ReplicatedStorage.Reliable.DeliveryType = 1 end))
local Count = 0
local Orders = {}
_G.UnorderedValues = {}
for _, Name in ipairs({'Reliable','Unordered','Legacy'}) do
    local Remote = game.ReplicatedStorage[Name]
    Remote.OnServerEvent:Connect(function(Player, Label, A, B, C)
        assert(Player and Player.ClassName == 'Player')
        assert(Label ~= 'Unauthorized')
        if Label == 'Legit' then
            assert(A == nil and B == 12 and C.foo == 9 and C[1] == 3)
            assert(C[utf8.char(0x96ea)] == utf8.char(0x1f600))
            assert(C.Vector.X == 1 and math.abs(C.Colour.R - 0.1) < 0.000001)
            if Remote.DeliveryType == 0 then assert(C.Frame.Position.X == 4) else assert(C.Frame == nil) end
            assert(C.Player == Player and C.Parent == game.ReplicatedStorage)
            Count += 1; game:SetAttribute('Received', Count)
            Remote:FireClient(Player, 'Echo', nil, B, C)
        elseif Label == 'Done' then
            game:SetAttribute('Done', (game:GetAttribute('Done') or 0) + 1)
        elseif Label == 'Reconnect' then
            game:SetAttribute('Reconnected', (game:GetAttribute('Reconnected') or 0) + 1)
            Remote:FireClient(Player, 'ReconnectEcho')
        elseif Label == 'HostLocal' then
            game:SetAttribute('HostServer', true)
        elseif Label == 'Order' then
            Orders[Player.UserId] = (Orders[Player.UserId] or 0) + 1
            assert(A == Orders[Player.UserId]); Remote:FireClient(Player, 'Ordered', A)
        elseif Label == 'Large' then
            assert(#A == 65000); Remote:FireClient(Player, 'LargeEcho', #A)
        elseif Label == 'Numeric' then
            assert(A == 1e100 and B == -1e100); Remote:FireClient(Player, 'NumericEcho', A, B)
        elseif string.sub(Label, 1, 14) == 'UnorderedProbe' then
            assert(Remote.DeliveryType == 1)
            local Values = _G.UnorderedValues[Player.UserId] or {}; _G.UnorderedValues[Player.UserId] = Values
            table.insert(Values, Label); game:SetAttribute('UnorderedProbeCount', (game:GetAttribute('UnorderedProbeCount') or 0) + 1)
        end
    end)
end
game.ReplicatedStorage.Cancel.OnServerEvent:Connect(function(Player)
    game.ReplicatedStorage.Cancel:FireClient(Player, 'Queued')
    game:SetAttribute('QueueFlush', Player.UserId)
    local Ok = pcall(function() game.ReplicatedStorage.Function:InvokeClient(Player) end)
    assert(not Ok)
    game:SetAttribute('CancelledInvokes', (game:GetAttribute('CancelledInvokes') or 0) + 1)
end)
_G.SequenceValues = {}
game.ReplicatedStorage.SequenceOther.OnServerEvent:Connect(function(Player, Label)
    assert(Label == 'Final'); game:SetAttribute('FinalSequences', (game:GetAttribute('FinalSequences') or 0) + 1)
end)
game.ReplicatedStorage.Sequenced.OnServerEvent:Connect(function(Player, Label)
    assert(Label ~= 'Unauthorized')
    local Values = _G.SequenceValues[Player.UserId] or {}
    _G.SequenceValues[Player.UserId] = Values
    table.insert(Values, Label)
    game:SetAttribute('SequenceCount', (game:GetAttribute('SequenceCount') or 0) + 1)
end)
game:SetAttribute('Configured', true)
""")
    await Until(func(): return Game.has_meta("Configured"), "Server API defaults, strict enums, frozen configuration and cloning")
    var BeforeFailedStart := State()
    ScriptRun("FailedStart", "assert(not game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4)); game:SetAttribute('FailedStartChecked', true)")
    await Until(func(): return Game.has_meta("FailedStartChecked"), "failed server bind is observed")
    Check(int(State().Epoch) == int(BeforeFailedStart.Epoch) and Network.call("get_peer_id") == 1, "failed server bind preserves the active publication epoch")
    if Mode == "Listen":
        ScriptRun("HostClient", """
local Remote = game.ReplicatedStorage.Reliable
assert(not pcall(function() Remote.DeliveryType = 1 end))
pcall(function() Remote:set('DeliveryType', 1) end)
assert(Remote.DeliveryType == 0)
local Fake = Instance.new('RemoteEvent'); Fake.Name = 'ClientFabricated'; Fake.Parent = game.ReplicatedStorage
assert(not pcall(function() Fake:FireServer('Unauthorized') end))
assert(not pcall(function() game.ServerStorage.ReplicatedStorage.Hidden:FireServer('Unauthorized') end))
Remote:FireServer('HostLocal')
Remote.OnClientEvent:Connect(function(Value) assert(Value == 'Local'); game:SetAttribute('LocalCount', (game:GetAttribute('LocalCount') or 0) + 1) end)
game:SetAttribute('HostConfigured', true)
""", true)
        await Until(func(): return Game.has_meta("HostConfigured"), "listen Client cannot configure shared native Remote")
        await process_frame
        Check(not Network.call("GetRemoteState", Storage.get_node("ClientFabricated")).has("Endpoint"), "listen Client creation cannot publish a native endpoint")
        Check(Game.has_meta("HostServer"), "listen local FireServer receives the real Player")
        ScriptRun("LocalDelivery", """
local R = game.ReplicatedStorage.Reliable
assert(not pcall(function() R:FireAllClients(function() end) end))
assert(game:GetAttribute('LocalCount') == nil)
R:FireAllClients('Local'); assert(game:GetAttribute('LocalCount') == 1)
game:SetAttribute('LocalValidated', true)
""")
        await Until(func(): return Game.has_meta("LocalValidated"), "local validation precedes broadcast side effects")
    Mark("ready")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-ready"), "first client and real ENet delivery")
    Check(int(Game.get_meta("Received", 0)) == 3, "three delivery classes reach Server exactly once")
    await Until(func(): return FileAccess.file_exists("res://remote-client2-ready"), "late join receives frozen configuration and all modes")
    Check(int(Game.get_meta("Received", 0)) == 6, "late join legitimate delivery preserved")
    var Before := int(Network.call("GetRemoteState", null).Delivered)
    var Rejected := int(Network.call("GetRemoteState", null).Rejected)
    Mark("attack")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-attacked") and FileAccess.file_exists("res://remote-client2-attacked"), "both peers exercised adversarial production handlers")
    await Until(func(): return int(Network.call("GetRemoteState", null).Rejected) >= Rejected + 26, "native admission rejects malformed and unauthorized traffic")
    print("[Network:RemoteTest] Rejected adversarial frames=", int(Network.call("GetRemoteState", null).Rejected) - Rejected)
    Check(int(Network.call("GetRemoteState", null).Delivered) == Before, "malformed, oversized, stale, mode and role rejection has no dispatch")
    Check(bool(Network.call("QualificationRemoteControl", "PauseReceive", true)), "freshness admission is separated from dispatch")
    # Freeze only this fixture's queue clock across the cross-process barrier.
    Check(bool(Network.call("QualificationRemoteControl", "Clock", Time.get_ticks_usec())), "bounded native fixture clock established")
    var SequenceRejected := int(Network.call("GetRemoteState", null).Rejected)
    var SequenceStale := int(Network.call("GetRemoteState", null).Stale)
    Mark("sequence-go")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-sequence-sent") and FileAccess.file_exists("res://remote-client2-sequence-sent"), "both real peer streams submit reorder/duplicate probes")
    await Until(func(): return int(Network.call("GetRemoteState", null).IncomingMessages) == 4, "only sequences three and four from each peer enter the dispatch queue")
    Check(int(Network.call("GetRemoteState", null).Rejected) >= SequenceRejected + 6 and int(Network.call("GetRemoteState", null).Stale) >= SequenceStale + 6, "wrong native carriers and invalid high sequences reject before freshness; duplicates remain stale")
    Check(not Game.has_meta("SequenceCount"), "native receive performs no gameplay callback before dispatch")
    Check(bool(Network.call("QualificationRemoteControl", "DrainIncoming", true)), "admitted freshness samples drain without inbound supersession")
    # One bounded drain can yield its between-message time slice after a callback.
    # Keep the receive barrier and drain subsequent slices without new admission.
    var DrainDeadline := Time.get_ticks_msec() + 5000
    while int(Game.get_meta("SequenceCount", 0)) < 4 and Time.get_ticks_msec() < DrainDeadline:
        await process_frame
        Network.call("QualificationRemoteControl", "DrainIncoming", true)
    Check(int(Game.get_meta("SequenceCount", 0)) == 4, "admitted three and four each execute once per independent peer")
    Check(bool(Network.call("QualificationRemoteControl", "PauseReceive", false)), "normal receive scheduling resumes")
    Mark("sequence-drained")
    await Until(func(): return int(Game.get_meta("SequenceCount", 0)) == 6, "newest unsent sample reaches both peer streams")
    ScriptRun("CheckSequences", "local Count = 0; for _, Values in pairs(_G.SequenceValues) do assert(#Values == 3 and Values[1] == 'Seq3' and Values[2] == 'Seq4' and Values[3] == 'Seq7'); Count += 1 end; assert(Count == 2); game:SetAttribute('SequencesVerified', true)")
    await Until(func(): return Game.has_meta("SequencesVerified"), "native watermark and unsent replacement preserve stream order")
    Check(bool(Network.call("QualificationRemoteControl", "Clock", Time.get_ticks_usec())), "fixture clock advances monotonically after freshness barrier")
    Mark("sequence-complete")
    await ServerPressure()
    var Old: Node = Storage.get_node("Dynamic")
    var OldIdentity := Old.get_instance_id()
    ScriptRun("Replace", """
_G.Dynamic:Destroy()
local R = Instance.new('RemoteEvent'); R.DeliveryType = 1; R.Name = 'Dynamic'; R.Parent = game.ReplicatedStorage
R.OnServerEvent:Connect(function() game:SetAttribute('ReplacementCallback', true) end)
_G.Dynamic = R; game:SetAttribute('Replaced', true)
""")
    await Until(func(): return Game.has_meta("Replaced") and not is_instance_id_valid(OldIdentity), "native Remote destruction and replacement")
    Mark("replaced")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-stale") and FileAccess.file_exists("res://remote-client2-stale"), "stale generation and replacement impersonation exercised")
    Check(not Game.has_meta("ReplacementCallback"), "old endpoint packets never target replacement at same path")
    Mark("finish")
    await Until(func(): return FileAccess.file_exists("res://remote-client1-finished") and FileAccess.file_exists("res://remote-client2-finished"), "client lifetime and teardown assertions complete")
    Check(int(Game.get_meta("Reconnected", 0)) == 2, "new assigned sessions preserve legitimate delivery")
    await Until(func(): return int(Game.get_meta("CancelledInvokes", 0)) == 2, "existing RemoteFunction disconnect outcomes preserved")

func Client() -> void:
    ScriptRun("Connect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port'))); game:SetAttribute('Connecting', true)", true)
    await Until(func(): return Game.has_meta("Connecting"), "client connects real ENet")
    await Until(func(): return Ready("Reliable") and Ready("Unordered") and Ready("Legacy") and Ready("Dynamic") and Ready("Sequenced") and Ready("SequenceOther") and Ready("PressureReliable") and Ready("PressureUnordered"), "Server descriptors and peer readiness acknowledged")
    var BeforeFailure := State()
    var BeforePeer: int = Network.call("get_peer_id")
    ScriptRun("FailedConnect", "assert(not game:GetService('NetworkService'):Connect('127.0.0.1', -1)); game:SetAttribute('FailedConnectChecked', true)", true)
    await Until(func(): return Game.has_meta("FailedConnectChecked"), "invalid connection attempt is observed")
    Check(Ready("Reliable") and int(State().Epoch) == int(BeforeFailure.Epoch) and int(State().Endpoint) == int(BeforeFailure.Endpoint) and Network.call("get_peer_id") == BeforePeer, "failed native connection attempt preserves current publication and transport")
    Check(int(Storage.get_node("Dynamic").get("DeliveryType")) == 1, "dynamic configuration replicates before activation")
    var Reparented: Node = Storage.get_node("Unordered")
    var OriginalEndpoint := int(State("Unordered").Endpoint)
    var Folder := Create("Node", "Moved", Storage)
    Reparented.reparent(Folder)
    await process_frame
    Check(int(Network.call("GetRemoteState", Reparented).Endpoint) == OriginalEndpoint, "same-scope reparent preserves endpoint identity")
    Reparented.reparent(Storage)
    Folder.queue_free()
    var OldDynamic := State("Dynamic")
    ScriptRun("ClientAPI", """
local Received, Waited, Ordered = 0, 0, 0
local Allowed, Result = pcall(function() return game:GetService('NetworkService'):QualificationRemoteControl('PauseReceive', true) end)
assert(not Allowed or Result == false)
game.ReplicatedStorage.Sequenced.OnClientEvent:Connect(function(Label)
    assert(Label == 'Target' or Label == 'Broadcast')
    game:SetAttribute('Direction' .. Label, true); game:SetAttribute('DirectionCount', (game:GetAttribute('DirectionCount') or 0) + 1)
end)
local PressureReceived = 0
game.ReplicatedStorage.PressureReliable.OnClientEvent:Connect(function(Label, Number)
    assert(Label == 'Pressure' and Number == PressureReceived + 1)
    PressureReceived += 1; game:SetAttribute('PressureReceived', PressureReceived)
end)
local Temporary = Instance.new('RemoteEvent')
assert(not require(game.ReplicatedStorage.DeliveryModule)(Temporary) and Temporary.DeliveryType == 0)
Temporary:Destroy()
for _, Name in ipairs({'Reliable','Unordered','Legacy'}) do
    local R = game.ReplicatedStorage[Name]
    assert(not pcall(function() R.DeliveryType = 0 end))
    pcall(function() R:set('DeliveryType', 0) end)
    assert(R.DeliveryType == (Name == 'Reliable' and 0 or 1))
    R.OnClientEvent:Connect(function(Label, Number, Other)
        assert(Label ~= 'Unauthorized')
        if Label == 'Ordered' then Ordered += 1; assert(Number == Ordered); if Ordered == 16 then game:SetAttribute('Ordered', true) end end
        if Label == 'LargeEcho' then assert(Number == 65000); game:SetAttribute('LargeEcho', true) end
        if Label == 'NumericEcho' then assert(Number == 1e100 and Other == -1e100); game:SetAttribute('NumericEcho', true) end
    end)
    R.OnClientEvent:Once(function(Label, A, B, C)
        assert(Label == 'Echo' and A == nil and B == 12 and C.foo == 9 and C[1] == 3)
        assert(C[utf8.char(0x96ea)] == utf8.char(0x1f600))
        assert(C.Vector.X == 1 and math.abs(C.Colour.R - 0.1) < 0.000001)
        if R.DeliveryType == 0 then assert(C.Frame.Position.X == 4) else assert(C.Frame == nil) end
        assert(C.Player == game:GetService('Players').LocalPlayer and C.Parent == game.ReplicatedStorage)
        Received += 1; if Received == 3 then game:SetAttribute('Echoes', true) end
    end)
    task.spawn(function()
        local Label, A, B, C = R.OnClientEvent:Wait()
        assert(Label == 'Echo' and A == nil and B == 12 and C.foo == 9)
        assert(C[utf8.char(0x96ea)] == utf8.char(0x1f600))
        Waited += 1; if Waited == 3 then game:SetAttribute('Waits', true) end
    end)
    assert(not pcall(function() R:FireServer(function() end) end))
    assert(not pcall(function() R:FireServer('nul' .. string.char(0)) end))
    assert(not pcall(function() R:FireServer(string.char(255)) end))
    assert(not pcall(function() R:FireServer(math.huge) end))
    assert(not pcall(function() R:FireServer(Vector3.new(math.huge, 0, 0)) end))
    assert(not pcall(function() R:FireServer(setmetatable({}, {__type = '_G'})) end))
    local Cycle = {}; Cycle.Self = Cycle
    assert(not pcall(function() R:FireServer(Cycle) end))
    assert(not pcall(function() R:FireServer(string.rep('x', 65537)) end))
    if R.DeliveryType == 1 then assert(not pcall(function() R:FireServer(string.rep('x', 901)) end)) end
    local Payload = {3, foo = 9, Vector = Vector3.new(1,2,3), Colour = Color3.new(0.1,0.2,0.3), Player = game:GetService('Players').LocalPlayer, Parent = game.ReplicatedStorage}
    Payload[utf8.char(0x96ea)] = utf8.char(0x1f600)
    if R.DeliveryType == 0 then Payload.Frame = CFrame.new(4,5,6) end
    R:FireServer('Legit', nil, 12, Payload)
    if R.DeliveryType == 0 then
        for Number = 1, 16 do R:FireServer('Order', Number) end
        R:FireServer('Large', string.rep('x', 65000))
        R:FireServer('Numeric', 1e100, -1e100)
        -- Functional unordered probes must not compete with this reliable
        -- fragmentation burst: their contract permits loss under congestion.
        local Deadline = os.clock() + 10
        while not (game:GetAttribute('Ordered') and game:GetAttribute('LargeEcho') and game:GetAttribute('NumericEcho')) and os.clock() < Deadline do task.wait() end
        assert(game:GetAttribute('Ordered') and game:GetAttribute('LargeEcho') and game:GetAttribute('NumericEcho'))
    end
end
game:SetAttribute('ClientConfigured', true)
""", true)
    await Until(func(): return Game.has_meta("ClientConfigured") and Game.has_meta("Echoes") and Game.has_meta("Waits") and Game.has_meta("Ordered") and Game.has_meta("LargeEcho") and Game.has_meta("NumericEcho"), "Client authority, payload bounds, Once, Wait, mixed tables and nil arguments")
    Check(Game.has_meta("Ordered"), "reliable stream preserves accepted send and callback-start order")
    Check(Game.has_meta("LargeEcho"), "large reliable payload completes through ENet fragmentation")
    SaveIdentity()
    Mark("client" + str(Index) + "-ready")
    await Until(func(): return FileAccess.file_exists("res://remote-attack"), "adversarial barrier")
    await Attack()
    Mark("client" + str(Index) + "-attacked")
    await Until(func(): return FileAccess.file_exists("res://remote-sequence-go"), "sequenced receive barrier")
    await Sequencing()
    await ClientPressure()
    await Until(func(): return FileAccess.file_exists("res://remote-replaced"), "replacement barrier")
    await Until(func(): return Ready("Dynamic") and int(State("Dynamic").get("Endpoint", 0)) != int(OldDynamic.Endpoint), "replacement has fresh endpoint publication")
    Network.rpc_id(1, "_ure_deliver_server", Frame(OldDynamic, "Unauthorized", 1))
    var Victim: Node = Storage.get_node("Reliable")
    var RetainedState := State()
    Victim.free()
    Create("RemoteEventNode", "Reliable", Storage)
    await process_frame
    Check(not Ready("Reliable"), "same-path Client replacement cannot inherit publication readiness")
    Network.rpc_id(1, "_remote_ack", RetainedState.Epoch, RetainedState.User, RetainedState.Endpoint, RetainedState.Generation)
    Mark("client" + str(Index) + "-stale")
    await Until(func(): return FileAccess.file_exists("res://remote-finish"), "finish barrier")
    var Waiting := ScriptRun("RetainedWait", """
local R = game.ReplicatedStorage.Dynamic
local Wait = R.OnClientEvent.Wait
_G.RetainedFire = R.FireServer
_G.RetainedConnect = R.OnClientEvent.Connect
_G.RetainedRemote = R
game:SetAttribute('Waiting', true)
Wait(); game:SetAttribute('RetiredWaitRan', true)
""", true)
    await Until(func(): return Game.has_meta("Waiting"), "Remote wait registered before retirement")
    Storage.get_node("Dynamic").free()
    await process_frame
    ScriptRun("RetainedMethods", """
_G.RetainedFire(_G.RetainedRemote, 'gone')
_G.RetainedConnect(function() game:SetAttribute('DeadCallback', true) end)
assert(not game:GetAttribute('RetiredWaitRan') and not game:GetAttribute('DeadCallback'))
game:SetAttribute('RetainedSafe', true)
""", true)
    await Until(func(): return Game.has_meta("RetainedSafe"), "retained methods and exact Wait cancellation survive native destruction")
    Waiting.queue_free()
    if Index == 2:
        await Until(func(): return FileAccess.file_exists("res://remote-client1-finished"), "coordinated reconnect preserves the retained GL-017 limitation")
    Network.call("disconnect_net")
    Check(int(Network.call("GetRemoteState", null).Publications) == 0, "service disconnect releases publication state")
    var OldSession := State("Unordered")
    # Capture the actual old assigned identity from the earlier publication.
    OldSession = OldDynamic
    await create_timer(0.15).timeout
    ScriptRun("ConnectAgain", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port'))); game:SetAttribute('Reconnecting', true)", true)
    await Until(func(): return Game.has_meta("Reconnecting"), "reconnect starts a new ENet session")
    await Until(func(): return Ready("Unordered") and Ready("Legacy"), "reconnect requires fresh readiness")
    Check(int(State("Unordered").User) != int(OldSession.User), "reconnect uses new assigned native session")
    Network.rpc_id(1, "_ure_deliver_server", Frame(OldSession, "Unauthorized", 1))
    ScriptRun("Reconnect", """
local R = game.ReplicatedStorage.Unordered
R.OnClientEvent:Once(function(Label) assert(Label == 'ReconnectEcho'); game:SetAttribute('ReconnectEcho', true) end)
R:FireServer('Reconnect')
""", true)
    await Until(func(): return Game.has_meta("ReconnectEcho"), "fresh session legitimate delivery and stale-session rejection")
    await Until(func(): return Ready("Cancel"), "new session cancellation endpoint ready")
    var QueueUser := int(State("Cancel").User)
    multiplayer_poll = false
    ScriptRun("QueuedCancellation", """
local Network = game:GetService('NetworkService')
game.ReplicatedStorage.Function.OnClientInvoke = function()
    game:SetAttribute('DisconnectNow', true)
    task.wait(0.03)
    assert(not game:GetAttribute('QueuedWaitRan'))
    game:SetAttribute('QueuedCancellationPassed', true)
    return true
end
task.spawn(function()
    game.ReplicatedStorage.Cancel.OnClientEvent:Wait()
    game:SetAttribute('QueuedWaitRan', true)
end)
game.ReplicatedStorage.Cancel:FireServer('QueueDisconnect')
game:SetAttribute('QueueRequestSent', true)
""", true)
    await Until(func(): return Game.has_meta("QueueRequestSent"), "queue-cancellation request is registered")
    Network.get_multiplayer().get_multiplayer_peer().get_host().flush()
    await Until(func(): return FileAccess.file_exists("res://remote-queue-flushed-" + str(QueueUser)), "both reliable production RPCs flush before controlled Client poll")
    await create_timer(0.02).timeout
    Network.get_multiplayer().poll()
    Check(Game.has_meta("DisconnectNow"), "real event admission and invocation execute within the controlled ENet poll")
    Check(int(Network.call("GetRemoteState", null).IncomingMessages) == 1, "real poll admits event without running its pending Wait")
    Check(bool(Network.call("QualificationRemoteControl", "DrainIncoming", true)), "controlled native drain queues the accepted Wait resume")
    Network.call("disconnect_net")
    multiplayer_poll = true
    await Until(func(): return Game.has_meta("QueuedCancellationPassed"), "accepted queued Wait cannot resume after service disconnect; sibling callback survives")
    ScriptRun("PressureReconnect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port'))); game:SetAttribute('PressureReconnect', true)", true)
    await Until(func(): return Game.has_meta("PressureReconnect") and Ready("PressureReliable"), "fresh session for terminal reliable admission test")
    Network.call("QualificationRemoteControl", "PauseSend", true)
    ScriptRun("ReliableLimit", "local R = game.ReplicatedStorage.PressureReliable; for N = 1, 1024 do R:FireServer(N) end; assert(not pcall(function() R:FireServer('one-over') end)); game:SetAttribute('ReliableLimit', true)", true)
    await Until(func(): return Game.has_meta("ReliableLimit"), "reliable one-over admission returns an explicit failure")
    var Full: Dictionary = Network.call("GetRemoteState", null)
    Check(int(Full.OutgoingMessages) == 1024 and int(Full.PendingFailures) == 1, "failed reliable admission retains old bounded work until explicit peer failure")
    Network.call("QualificationRemoteControl", "DrainOutgoing", true)
    var Closed: Dictionary = Network.call("GetRemoteState", null)
    Check(int(Closed.OutgoingMessages) == 0 and int(Closed.IncomingMessages) == 0 and int(Closed.Publications) == 0 and int(Closed.PeerFailures) >= 1 and int(Network.call("get_mode")) == 0 and int(Network.call("get_peer_id")) == 0, "reliable exhaustion terminates its session and releases exact queue ownership")
    ScriptRun("AgeReconnect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port'))); game:SetAttribute('AgeReconnect', true)", true)
    await Until(func(): return Game.has_meta("AgeReconnect") and Ready("PressureReliable"), "new session isolates reliable age failure from prior overflow")
    Network.call("QualificationRemoteControl", "PauseSend", true)
    var QueueTime := Time.get_ticks_usec()
    Network.call("QualificationRemoteControl", "Clock", QueueTime)
    ScriptRun("ReliableAge", "game.ReplicatedStorage.PressureReliable:FireServer('expired'); game:SetAttribute('ReliableAgeAdmitted', true)", true)
    await Until(func(): return Game.has_meta("ReliableAgeAdmitted"), "reliable queue-age sample admitted")
    Check(int(Network.call("GetRemoteState", null).OutgoingMessages) == 1, "accepted reliable age fixture retains ownership before failure")
    Network.call("QualificationRemoteControl", "Clock", QueueTime + 10000001)
    Network.call("QualificationRemoteControl", "DrainOutgoing", true)
    Closed = Network.call("GetRemoteState", null)
    Check(int(Closed.OutgoingMessages) == 0 and int(Closed.Publications) == 0 and int(Closed.PeerFailures) > int(Full.PeerFailures) + 1 and int(Network.call("get_mode")) == 0 and int(Network.call("get_peer_id")) == 0, "aged reliable work ends its session explicitly instead of silently expiring")
    Mark("client" + str(Index) + "-finished")
