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

func Frame(Identity: Dictionary, Text := "Unauthorized", Delivery := 0) -> PackedByteArray:
    var Bytes := PackedByteArray()
    Bytes.resize(40)
    Bytes.encode_u32(0, 0x31524547)
    Bytes.encode_u32(4, Delivery)
    Bytes.encode_u64(8, int(Identity.get("Epoch", 0)))
    Bytes.encode_u64(16, int(Identity.get("User", 0)))
    Bytes.encode_u64(24, int(Identity.get("Endpoint", 0)))
    Bytes.encode_u64(32, int(Identity.get("Generation", 0)))
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
    Network.rpc_id(1, "_re_deliver_server", Frame(Identity, "Unauthorized", 2))
    Network.rpc_id(1, "_re_deliver_server", "wrong wire type")
    Network.rpc_id(1, "_re_deliver_server", PackedByteArray([1, 2, 3]))
    var Oversized := PackedByteArray(); Oversized.resize(65537)
    Network.rpc_id(1, "_re_deliver_server", Oversized)
    var Malformed := Frame(Identity)
    Malformed.encode_u32(41, 0xffffffff) # Reject impossible count before allocation.
    Network.rpc_id(1, "_re_deliver_server", Malformed)
    Malformed = Frame(Identity); Malformed.append(0)
    Network.rpc_id(1, "_re_deliver_server", Malformed)
    Network.rpc_id(1, "_remote_ack", Identity.Epoch, Identity.User + 1, Identity.Endpoint, Identity.Generation)
    Network.rpc_id(1, "_remote_descriptor", [Identity.Epoch, Identity.User, 9000, 9000, 0, str(Storage.get_path()) + "/Reliable", 0, false])
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
    Create("RemoteFunctionNode", "Function", Storage)
    var Unordered: Node = ClassDB.instantiate("RemoteEventNode")
    Check(bool(Unordered.call("SetDeliveryType", 1)), "native unpublished unordered configuration")
    Unordered.name = "Unordered"; Storage.add_child(Unordered)
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
assert(Enum.EventDeliveryType.UnreliableSequenced == nil)
local R = Instance.new('RemoteEvent')
assert(R.DeliveryType == 0 and R.ClassName == 'RemoteEvent' and R:IsA('RemoteEvent'))
assert(require(game.ReplicatedStorage.DeliveryModule)(R) and R.DeliveryType == 1)
R.DeliveryType = 0
local Shadow = Instance.new('Folder'); Shadow.Name = 'DeliveryType'; Shadow.Parent = R
assert(R.DeliveryType == 0)
for _, Value in ipairs({true, '1', 0.5, 2}) do
    pcall(function() R:set('DeliveryType', Value) end)
    assert(R.DeliveryType == 0)
end
for _, Value in ipairs({true, '1', 0.5, 2, math.huge, 0/0}) do
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
for _, Name in ipairs({'Reliable','Unordered','Legacy'}) do
    local Remote = game.ReplicatedStorage[Name]
    Remote.OnServerEvent:Connect(function(Player, Label, A, B, C)
        assert(Player and Player.ClassName == 'Player')
        assert(Label ~= 'Unauthorized')
        if Label == 'Legit' then
            assert(A == nil and B == 12 and C.foo == 9 and C[1] == 3)
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
    Check(int(Network.call("GetRemoteState", null).Delivered) == Before, "malformed, oversized, stale, mode and role rejection has no dispatch")
    Check(int(Network.call("GetRemoteState", null).Rejected) >= Rejected + 26, "native admission rejects malformed and unauthorized traffic")
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
    await Until(func(): return Ready("Reliable") and Ready("Unordered") and Ready("Legacy") and Ready("Dynamic"), "Server descriptors and peer readiness acknowledged")
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
        assert(C.Vector.X == 1 and math.abs(C.Colour.R - 0.1) < 0.000001)
        if R.DeliveryType == 0 then assert(C.Frame.Position.X == 4) else assert(C.Frame == nil) end
        assert(C.Player == game:GetService('Players').LocalPlayer and C.Parent == game.ReplicatedStorage)
        Received += 1; if Received == 3 then game:SetAttribute('Echoes', true) end
    end)
    task.spawn(function()
        local Label, A, B, C = R.OnClientEvent:Wait()
        assert(Label == 'Echo' and A == nil and B == 12 and C.foo == 9)
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
    if R.DeliveryType == 0 then Payload.Frame = CFrame.new(4,5,6) end
    R:FireServer('Legit', nil, 12, Payload)
    if R.DeliveryType == 0 then
        for Number = 1, 16 do R:FireServer('Order', Number) end
        R:FireServer('Large', string.rep('x', 65000))
        R:FireServer('Numeric', 1e100, -1e100)
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
    Check(Game.has_meta("DisconnectNow"), "real event and invocation execute within the controlled ENet poll")
    Network.call("disconnect_net")
    multiplayer_poll = true
    await Until(func(): return Game.has_meta("QueuedCancellationPassed"), "accepted queued Wait cannot resume after service disconnect; sibling callback survives")
    Mark("client" + str(Index) + "-finished")
