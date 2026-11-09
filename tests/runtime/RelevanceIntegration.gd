extends "res://ReplicationIntegration.gd"

var World: Node
var ClientIndex := 0
var FirstPeer := 0
var SecondPeer := 0
var Address := ""
var Mode := "Listen"
var Port := 0

func ConfigurePeer(Peer: int) -> void:
    var Transport = Network.get_multiplayer().get_multiplayer_peer()
    if Transport is ENetMultiplayerPeer and (Transport.get_unique_id() == 1 or Peer == 1):
        var Link = Transport.get_peer(Peer)
        if Link:
            Link.throttle_configure(5000, 32, 0)
            Check(int(Link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)) == 0, "functional physics carrier throttle profile configured")

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--fixture-role": Role = Arguments[Index + 1]
        if Arguments[Index] == "--fixture-client-index": ClientIndex = int(Arguments[Index + 1])
        if Arguments[Index] == "--glconnect": Address = Arguments[Index + 1]
        if Arguments[Index] == "--relevance-mode": Mode = Arguments[Index + 1]
        if Arguments[Index] == "--fixture-port": Port = int(Arguments[Index + 1])
    call_deferred("Run")

func _process(_Delta: float) -> bool:
    if is_instance_valid(World):
        for Value in World.get_children():
            if Value.is_class("RBXCharacter"):
                Value.set_process(false); Value.set_physics_process(false)
                if Value.has_node("PhysicsBody"):
                    Value.get_node("PhysicsBody").set_physics_process(false)
    return false

func ClientScript(Name: String, Source: String) -> void:
    var Result: Node = ClassDB.instantiate("LocalScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name; Result.call("set_codigo_luau", Resource); Game.add_child(Result)

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension loaded")
    ProjectSettings.set_setting("godot_luau/network/replication_relevance", true)
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    Storage = Create("ReplicatedStorage", "ReplicatedStorage", Game)
    Create("Players", "Players", Game); Create("RunService", "RunService", Game)
    Create("RemoteEventNode", "Remote", Storage)
    Create("Node", "SettingsMenu", Game)
    World = Create("RobloxWorkspace", "Workspace", Game); World.set_process(false)
    ClientScript("Prewarm", "game:SetAttribute('ClientWarmed',true)")
    Network = Create("NetworkService", "NetworkService", Game)
    Network.get_multiplayer().peer_connected.connect(ConfigurePeer)
    await process_frame
    if Role == "server" and Mode == "Listen":
        Game.set_meta("Port", Port)
        ScriptNode("StartListen", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'),6)); game:SetAttribute('Listening',true)")
        await Until(func(): return Game.has_meta("Listening"), "listen host started")
    if Role == "server": await Server()
    else: await Client()
    Network.call("disconnect_net")
    Check(int(Network.call("GetReplicationState").PendingMessages) == 0, "retired service queue is empty")
    Game.free(); await process_frame; await process_frame
    var Record := {"Role": Role + str(ClientIndex), "Mode": Mode, "Transport": "ENet", "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases}
    Mark("evidence-" + Role + str(ClientIndex) + ".json", JSON.stringify(Record))
    print("[Network:RelevanceTest] ", Role, ClientIndex, " ", Record.Result)
    quit(1 if Failed else 0)

func View(Peer: int) -> Dictionary:
    return Network.call("GetReplicationState", Peer)

func Entry(Peer: int, Id: int) -> Dictionary:
    for Value in View(Peer).Entries:
        if int(Value.Id) == Id: return Value
    return {}

func Server() -> void:
    await Until(func(): return int(Network.call("get_mode")) == 1, "server started")
    Check(bool(View(0).Enabled), "trusted session opt-in enabled")
    ScriptNode("CreateWorld", """
local World = game:GetService('Workspace')
local Near = Instance.new('Part'); Near.Name = 'Near'; Near.Anchored = true; Near.Position = Vector3.new(0,5,0); Near.Parent = World
local Far = Instance.new('Part'); Far.Name = 'Far'; Far.Anchored = true; Far.Position = Vector3.new(1000,5,0); Far.Parent = World
local Counter = Instance.new('IntValue'); Counter.Name = 'Counter'; Counter.Value = 1; Counter.Parent = game.ReplicatedStorage
local A = Instance.new('Folder'); A.Name = 'ParentA'; A.Parent = game.ReplicatedStorage
local B = Instance.new('Folder'); B.Name = 'ParentB'; B.Parent = game.ReplicatedStorage
local Child = Instance.new('StringValue'); Child.Name = 'Child'; Child.Value = string.rep('p',7500); Child.Parent = A
local Hidden = Instance.new('Folder'); Hidden.Name = 'HiddenDirect'; Hidden.Parent = World
local Inner = Instance.new('Folder'); Inner.Name = 'HiddenChild'; Inner.Parent = Hidden
Hidden.Name = 'ServerStorage'
local Scripts = Instance.new('Folder'); Scripts.Name = 'HiddenScripts'; Scripts.Parent = game.ReplicatedStorage
Scripts.Name = 'ServerScriptService'
local Target = Instance.new('Folder'); Target.Name = 'SweepTarget'; Target.Parent = game.ReplicatedStorage
local Ref = Instance.new('ObjectValue'); Ref.Name = 'SweepReference'; Ref.Value = Target; Ref.Parent = game.ReplicatedStorage
for N=1,96 do
    local Part = Instance.new('Part'); Part.Name = 'SweepDistant_'..N
    Part.Anchored=true; Part.Position=Vector3.new(20000+N*16,0,0); Part.Parent=World
    if N % 4 == 0 then task.wait() end
end
game:SetAttribute('Created',true)
""")
    await Until(func(): return Game.has_meta("Created"), "world created through production Luau")
    var Near := World.get_node("Near"); var Far := World.get_node("Far")
    var NearId: int = Near.get_meta("_gl_netid"); var FarId: int = Far.get_meta("_gl_netid")
    var NearNative := Near.get_instance_id()
    Mark("world.json", JSON.stringify({"Near": str(NearId), "Far": str(FarId)})); Mark("server.ready")
    await Wait("client1.ready"); await Wait("client2.ready")
    FirstPeer = int(FileAccess.get_file_as_string("res://replication-client1.ready")); SecondPeer = int(FileAccess.get_file_as_string("res://replication-client2.ready"))
    await Until(func(): return bool(Entry(FirstPeer, NearId).get("Materialized", false)) and bool(Entry(SecondPeer, NearId).get("Materialized", false)), "two peers acknowledge near entry")
    if Entry(FirstPeer, NearId).is_empty():
        print("[Network:RelevanceTest] Failed view ", View(0)); return
    Check(Entry(FirstPeer, FarId).is_empty(), "far object has no accepted visibility")
    await Until(func(): return int(View(0).Rejected) >= 4, "wrong-session and future structural ACKs rejected")
    var Generation: int = Entry(FirstPeer, NearId).Generation
    if Mode == "Listen":
        ClientScript("ListenAttack", "local P=game.Workspace.Near; P.Position=Vector3.new(9000,0,0); P.Anchored=false; P:SetAttribute('_gl_owner',123); P:ApplyImpulse(Vector3.new(1,0,0)); P:SetNetworkOwner(nil); P:Destroy(); game:SetAttribute('Attacked',true)")
        await Until(func(): return Game.has_meta("Attacked"), "listen Client attack completed")
        Check(is_instance_id_valid(NearNative) and Near.global_position.distance_to(Vector3(0,5,0)) < 0.01 and bool(Near.get("Anchored")) and not Near.has_meta("_gl_owner"), "listen Client cannot mutate projection, ownership or relevance")
    Check(not Network.call("SetReplicationGlobal", null), "invalid global pin rejected")
    Network.call("QualificationRemoteControl", "BusyPeer", FirstPeer)
    ScriptNode("Coalesce", "for N=1,64 do game.ReplicatedStorage.Counter.Value=N end; game:SetAttribute('Coalesced',true)")
    await Until(func(): return Game.has_meta("Coalesced") and int(View(FirstPeer).PendingMessages) > 0, "busy peer owns an admitted bounded frame")
    Mark("healthy.go"); await Wait("client2.healthy")
    Check(int(View(FirstPeer).Deferred) > 0 and int(View(FirstPeer).PendingMessages) <= 256 and int(View(FirstPeer).PendingBytes) <= 262144, "native WouldBlock retains bounded ownership while healthy peer progresses")
    Network.call("QualificationRemoteControl", "BusyPeer", 0)
    Mark("released"); await Wait("client1.healthy")
    Check(int(View(0).Coalesced) >= 63, "property writes coalesce before admission")
    var States: Dictionary = Network.call("GetCharacterStates")
    var Character: Node3D = instance_from_id(int(States[FirstPeer].CharacterId))
    Character.global_position = Vector3(1000,5,0)
    Mark("far.go"); await Wait("client1.far")
    Check(is_instance_id_valid(NearNative) and Near.get_instance_id() == NearNative, "leave preserves authoritative object identity")
    Check(Entry(FirstPeer, NearId).is_empty() and not Entry(SecondPeer, NearId).is_empty(), "per-peer departure does not retire another peer")
    Character.global_position = Vector3(0,5,0)
    Mark("back.go"); await Wait("client1.back")
    await Until(func(): return int(Entry(FirstPeer, NearId).get("Generation", 0)) > Generation, "reentry has a fresh materialization generation")
    var SweepReferenceId: int = Storage.get_node("SweepReference").get_meta("_gl_netid")
    await Until(func(): return int(View(0).RefreshStage) == 1 and int(View(0).RefreshCursor) > SweepReferenceId, "unfinished source sweep has captured the reference before mutation")
    ScriptNode("MoveTwice", "local C=game.ReplicatedStorage.ParentA.Child; for N=1,8 do C.Parent=game.ReplicatedStorage.ParentB; C.Parent=game.ReplicatedStorage.ParentA end; game.ReplicatedStorage.SweepTarget:Destroy(); game:SetAttribute('Reparented',true)")
    await Until(func(): return Game.has_meta("Reparented"), "sixteen structural barriers submitted")
    Mark("reparent.go"); await Wait("client1.reparent"); await Wait("client2.reparent")
    Check(Storage.get_node("SweepReference").get("Value") == null, "native ObjectValue getter returns nil after target destruction")
    ScriptNode("ReadDestroyedReference", "assert(game.ReplicatedStorage.SweepReference.Value == nil); game:SetAttribute('DestroyedReferenceRead',true)")
    await Until(func(): return Game.has_meta("DestroyedReferenceRead"), "Luau ObjectValue getter safely observes target destruction")
    ScriptNode("AddReference", "local Ref=Instance.new('ObjectValue'); Ref.Name='Reference'; Ref.Value=game.Workspace.Far; assert(Ref.Value==game.Workspace.Far); Ref.Parent=game.ReplicatedStorage; game:SetAttribute('Referenced',true)")
    await Until(func(): return Game.has_meta("Referenced"), "global object reference submitted")
    Mark("reference.go"); await Wait("client1.reference"); await Wait("client2.reference")
    print("[Network:RelevanceTest] Reference server view ", View(FirstPeer))
    ScriptNode("ClearReference", "game.ReplicatedStorage.Reference.Value=nil; game:SetAttribute('ReferenceCleared',true)")
    await Until(func(): return Game.has_meta("ReferenceCleared"), "weak object reference cleared")
    Mark("reference.clear"); await Wait("client1.reference.clear"); await Wait("client2.reference.clear")
    ScriptNode("ReferenceCycle", "local A=Instance.new('ObjectValue'); A.Name='CycleA'; A.Parent=game.ReplicatedStorage; local B=Instance.new('ObjectValue'); B.Name='CycleB'; B.Parent=game.ReplicatedStorage; A.Value=B; B.Value=A; game:SetAttribute('CycleCreated',true)")
    await Until(func(): return Game.has_meta("CycleCreated"), "reference cycle created")
    Mark("cycle.go"); await Wait("client1.cycle"); await Wait("client2.cycle")
    ScriptNode("RetireCycle", "game.ReplicatedStorage.CycleA:Destroy(); game.ReplicatedStorage.CycleB:Destroy(); game:SetAttribute('CycleRetired',true)")
    await Until(func(): return Game.has_meta("CycleRetired"), "reference cycle retirement submitted")
    Mark("cycle.retire"); await Wait("client1.cycle.retired"); await Wait("client2.cycle.retired")
    Check(Network.call("SetReplicationGlobal", Far), "trusted native global pin accepted")
    Mark("pin.go"); await Wait("client1.pin"); await Wait("client2.pin")
    ScriptNode("PhysicsBody", "local P=Instance.new('Part'); P.Name='Body'; P.Anchored=false; P.Position=Vector3.new(50,5,0); P.Parent=game.Workspace; game:SetAttribute('PhysicsCreated',true)")
    await Until(func(): return Game.has_meta("PhysicsCreated"), "unanchored global body created")
    var Body: RigidBody3D = World.get_node("Body")
    # This phase tests server-driven physics; transfer to FirstPeer below.
    Network.call("net_set_owner", int(Body.get_meta("_gl_netid")), 0, false)
    Body.gravity_scale = 0; Body.linear_velocity = Vector3(1,0,0); Body.sleeping = false
    Mark("physics.go"); await Wait("client1.physics"); await Wait("client2.physics")
    Network.call("net_set_owner", int(Body.get_meta("_gl_netid")), FirstPeer, false)
    Mark("owner.go"); await Wait("client1.owner"); await Wait("client2.owner")
    await Until(func(): return Body.global_position.x > 51, "authorized client physics reaches the native server body")
    Check(Body.global_position.x < 100, "wrong-generation and wrong-owner physics did not apply forged pose")
    ScriptNode("RemoveNear", "game.Workspace.Near:Destroy(); local P=Instance.new('Part'); P.Name='Near'; P.Anchored=true; P.Position=Vector3.new(0,5,0); P.Parent=game.Workspace; game:SetAttribute('Replaced',true)")
    await Until(func(): return Game.has_meta("Replaced"), "authoritative replacement submitted")
    Mark("replace.go"); await Wait("client1.replace"); await Wait("client2.replace")
    Mark("reconnect.go"); await Wait("client2.reconnected")
    var NewPeer := int(FileAccess.get_file_as_string("res://replication-client2.reconnected"))
    await Until(func(): return not View(NewPeer).Entries.is_empty() and int(View(NewPeer).AckedSequence) > 0, "new session materializes through a fresh acknowledged view")
    Mark("cancel.prepare"); await Wait("client2.cancel.ready")
    ScriptNode("CancelDuringApply", "game.ReplicatedStorage.Counter.Value=777; game:SetAttribute('CancellationSubmitted',true)")
    await Until(func(): return Game.has_meta("CancellationSubmitted"), "callback cancellation frame submitted")
    await Wait("client2.cancelled")
    await Until(func(): return View(NewPeer).Entries.is_empty(), "cancelled peer releases its exact accepted view")
    Check(not View(FirstPeer).Entries.is_empty(), "callback cancellation preserves another peer's projection")
    Check(int(View(0).Failures) == 0 and not bool(View(0).Failed), "no structural failure during valid lifecycle")
    await Until(func(): return int(View(0).RefreshStage) != 0, "service replacement interrupts owned catalog work")
    var PersistentNear := World.get_node("Near")
    var PersistentId: int = PersistentNear.get_meta("_gl_netid")
    var PersistentObject := PersistentNear.get_instance_id()
    Mark("service.retire"); await Wait("client1.service.closed")
    await Until(func(): return Network.get_multiplayer().get_peers().is_empty(), "old server carrier retires its peers")
    var OldService := Network.get_instance_id()
    Network.free()
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    if Mode == "Listen":
        ScriptNode("ReplacementListen", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'),6)); game:SetAttribute('ReplacementListening',true)")
        await Until(func(): return Game.has_meta("ReplacementListening"), "replacement listen server started")
    await Until(func(): return int(Network.call("get_mode")) == 1 and bool(View(0).Enabled), "replacement server restores opted-in authority")
    Check(Network.get_instance_id() != OldService and is_instance_id_valid(PersistentObject) and PersistentNear.get_meta("_gl_netid") == PersistentId, "service replacement preserves canonical native identity without reusing the service")
    Mark("service.reconnect"); await Wait("client1.service.ready")
    FirstPeer = int(FileAccess.get_file_as_string("res://replication-client1.service.ready"))
    await Until(func(): return bool(Entry(FirstPeer, PersistentId).get("Materialized", false)), "fresh service/session acknowledges the retained canonical source")
    Check(int(View(0).Failures) == 0 and not bool(View(0).Failed), "retired sweep cannot deliver into the replacement service")
    ScriptNode("OversizedSnapshot", "local V=Instance.new('StringValue'); V.Name='Oversized'; V.Value=string.rep('x',9000); V.Parent=game.ReplicatedStorage; game:SetAttribute('OversizedSubmitted',true)")
    await Until(func(): return Game.has_meta("OversizedSubmitted") and bool(View(0).Failed), "oversized source snapshot fails explicitly")
    Mark("oversize.go"); await Wait("client1.oversize")
    Check(int(View(0).PendingMessages) == 0 and int(View(0).PendingBytes) == 0, "terminal resource rejection retires queued structural ownership")
    Mark("done"); await Wait("client1.done"); await Wait("client2.done")

func Client() -> void:
    await Until(func(): return bool(Network.call("is_connected_net")), "client connected")
    await Until(func(): return World.has_node("Near") and Storage.has_node("Counter") and Storage.has_node("ParentA/Child"), "initial selected world and dependency closure materialize")
    if not World.has_node("Near"): return
    var Identity := World.get_node("Near").get_instance_id()
    Check(not World.has_node("Far"), "out-of-range Part is absent")
    Check(not World.has_node("ServerStorage") and not Storage.has_node("ServerScriptService"), "direct scope children and their descendants retain server-only name exclusions")
    var ChildIdentity := Storage.get_node("ParentA/Child").get_instance_id()
    var ParentA := Storage.get_node("ParentA"); var ParentB := Storage.get_node("ParentB")
    var Structural: Array = []
    ParentA.child_exiting_tree.connect(func(Value):
        if Value.get_instance_id() == ChildIdentity: Structural.append("A-"))
    ParentB.child_entered_tree.connect(func(Value):
        if Value.get_instance_id() == ChildIdentity: Structural.append("B+"))
    ParentB.child_exiting_tree.connect(func(Value):
        if Value.get_instance_id() == ChildIdentity: Structural.append("B-"))
    ParentA.child_entered_tree.connect(func(Value):
        if Value.get_instance_id() == ChildIdentity: Structural.append("A+"))
    var RemoteState: Dictionary = Network.call("GetRemoteState", null)
    for Offset in [1, 2]:
        var Ack := PackedByteArray(); Ack.resize(28)
        Ack.encode_u32(0, 0x31415247); Ack.encode_s64(4, int(RemoteState.Epoch)); Ack.encode_s64(12, int(RemoteState.User) + Offset); Ack.encode_s64(20, 0x7fffffffffffffff)
        Network.rpc_id(1, "_replication_ack", Ack)
    var Before: int = View(0).ReceivedSequence
    Network.call("_replication_frame", PackedByteArray())
    Network.call("_rep_new", 999, "Folder", "Forged", str(Storage.get_path()), {})
    Check(int(View(0).ReceivedSequence) == Before and not Storage.has_node("Forged"), "local structural and legacy RPC calls cannot apply state")
    Mark("client" + str(ClientIndex) + ".ready", str(Network.call("get_peer_id")))
    await Wait("healthy.go")
    if ClientIndex == 1: await Wait("released")
    await Until(func(): return Storage.get_node("Counter").get("Value") == 64, "latest coalesced property converges")
    Mark("client" + str(ClientIndex) + ".healthy")
    await Wait("far.go")
    if ClientIndex == 1:
        await Until(func(): return not World.has_node("Near") and World.has_node("Far"), "authoritative focus causes leave and enter")
        Check(not is_instance_id_valid(Identity), "departed replica native identity retired")
        Mark("client1.far"); await Wait("back.go")
        await Until(func(): return World.has_node("Near") and not World.has_node("Far"), "return focus reenters with a fresh replica")
        Check(World.get_node("Near").get_instance_id() != Identity, "reentry uses a fresh native identity")
        Identity = World.get_node("Near").get_instance_id(); Mark("client1.back")
    await Wait("reparent.go")
    var ExpectedStructural := []
    for Round in range(8): ExpectedStructural.append_array(["A-","B+","B-","A+"])
    await Until(func(): return Structural == ExpectedStructural, "burst preserves every ordered structural transition")
    Check(Storage.get_node("ParentA/Child").get_instance_id() == ChildIdentity, "reparent preserves child native identity")
    Check(str(Storage.get_node("ParentA/Child").get("Value")) == "p".repeat(7500), "large FIFO barrier payload survives burst splitting intact")
    await Until(func(): return Storage.has_node("SweepReference") and Storage.get_node("SweepReference").get("Value") == null and not Storage.has_node("SweepTarget"), "destruction during an unfinished sweep clears references and retires the exact target")
    Mark("client" + str(ClientIndex) + ".reparent")
    await Wait("reference.go")
    await Until(func(): return World.has_node("Far") and Storage.has_node("Reference") and Storage.get_node("Reference").get("Value") == World.get_node("Far"), "create/reference group materializes its spatial dependency")
    if Storage.has_node("Reference"):
        var Ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://replication-world.json"))
        print("[Network:RelevanceTest] Reference actual=", Storage.get_node("Reference").get("Value"), " expected=", World.get_node_or_null("Far"), " mapped=", Network.call("net_node_by_id", int(Ids.Far)), " state=", View(0))
    Mark("client" + str(ClientIndex) + ".reference")
    await Wait("reference.clear")
    await Until(func(): return Storage.get_node("Reference").get("Value") == null and not World.has_node("Far"), "cleared reference releases the spatial dependency")
    Mark("client" + str(ClientIndex) + ".reference.clear")
    await Wait("cycle.go")
    await Until(func(): return Storage.has_node("CycleA") and Storage.has_node("CycleB") and Storage.get_node("CycleA").get("Value") == Storage.get_node("CycleB") and Storage.get_node("CycleB").get("Value") == Storage.get_node("CycleA"), "cyclic create/reference relationships materialize as a complete group")
    Mark("client" + str(ClientIndex) + ".cycle")
    await Wait("cycle.retire")
    await Until(func(): return not Storage.has_node("CycleA") and not Storage.has_node("CycleB"), "cyclic reference retirement releases both identities")
    Mark("client" + str(ClientIndex) + ".cycle.retired")
    await Wait("pin.go"); await Until(func(): return World.has_node("Far"), "global pin overrides spatial exclusion")
    Mark("client" + str(ClientIndex) + ".pin")
    await Wait("physics.go")
    await Until(func(): return World.has_node("Body") and World.get_node("Body").global_position.x > 50.25, "generation-tagged server physics advances a materialized body")
    Mark("client" + str(ClientIndex) + ".physics")
    await Wait("owner.go")
    var ExpectedOwner := int(FileAccess.get_file_as_string("res://replication-client1.ready"))
    await Until(func(): return int(World.get_node("Body").get_meta("_gl_owner",0)) == ExpectedOwner, "exact owner grant follows materialization")
    if ClientIndex == 1:
        World.get_node("Body").gravity_scale = 0
        World.get_node("Body").linear_velocity = Vector3(1,0,0)
    var BodyIdentity: int = World.get_node("Body").get_meta("_gl_netid")
    var Packet := PackedByteArray(); Packet.resize(180)
    Packet.encode_u32(0,0x31505247); Packet.encode_s64(4,int(RemoteState.Epoch)); Packet.encode_s64(12,int(RemoteState.User)); Packet.encode_s64(20,BodyIdentity); Packet.encode_s64(28,0x7fffffffffffffff)
    for Row in range(3):
        for Column in range(3): Packet.encode_double(36+(Row*3+Column)*8,1.0 if Row==Column else 0.0)
    Packet.encode_double(108,9999.0)
    for Attempt in range(4): Network.rpc_id(1,"_replication_physics",Packet)
    Mark("client" + str(ClientIndex) + ".owner")
    await Wait("replace.go")
    await Until(func(): return World.has_node("Near") and World.get_node("Near").get_instance_id() != Identity, "authoritative destruction and replacement converge")
    Mark("client" + str(ClientIndex) + ".replace")
    await Wait("reconnect.go")
    if ClientIndex == 2:
        var OldSession: int = int(RemoteState.User)
        Network.call("disconnect_net")
        await Until(func(): return not World.has_node("Near") and not Storage.has_node("Counter"), "disconnect retires exact runtime replicas")
        Game.set_meta("Port", int(Address.get_slice(":", 1)))
        ClientScript("Reconnect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1',game:GetAttribute('Port'))); game:SetAttribute('Reconnecting',true)")
        await Until(func(): return Game.has_meta("Reconnecting"), "native reconnect requested through public Luau API")
        await Until(func(): return World.has_node("Near") and World.has_node("Far") and Storage.has_node("Counter"), "reconnect restores current global and spatial views")
        Check(int(Network.call("GetRemoteState", null).User) != OldSession, "reconnect uses a new server-assigned session")
        Mark("client2.reconnected", str(Network.call("get_peer_id")))
    await Wait("cancel.prepare")
    if ClientIndex == 2:
        ClientScript("CancelCallback", "game.ReplicatedStorage.Counter.Changed:Connect(function() game:GetService('NetworkService'):Disconnect(); game:SetAttribute('CallbackCancelled',true) end); game:SetAttribute('CancelReady',true)")
        await Until(func(): return Game.has_meta("CancelReady"), "native property callback cancellation registered")
        Mark("client2.cancel.ready")
        await Until(func(): return Game.has_meta("CallbackCancelled"), "disconnect inside replicated property callback completes")
        Check(int(Network.call("get_mode")) == 0 and not Storage.has_node("Counter"), "interrupted frame does not retain runtime replicas")
        Mark("client2.cancelled")
    if ClientIndex == 1:
        await Wait("service.retire")
        Network.call("disconnect_net")
        await Until(func(): return not World.has_node("Near") and not Storage.has_node("Counter"), "service replacement starts after exact replica retirement")
        Mark("client1.service.closed")
        await Wait("service.reconnect")
        Game.set_meta("Port", int(Address.get_slice(":", 1)))
        ClientScript("ServiceReconnect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1',game:GetAttribute('Port'))); game:SetAttribute('ServiceReconnecting',true)")
        await Until(func(): return Game.has_meta("ServiceReconnecting") and World.has_node("Near") and World.has_node("Far") and Storage.has_node("Counter"), "replacement service restores the retained global pin and fresh spatial view")
        Mark("client1.service.ready", str(Network.call("get_peer_id")))
        await Wait("oversize.go")
        await Until(func(): return not bool(Network.call("is_connected_net")), "oversized source ends its peer session")
        Check(not Storage.has_node("Oversized"), "rejected snapshot never partially materializes")
        Mark("client1.oversize")
    await Wait("done"); Mark("client" + str(ClientIndex) + ".done")
