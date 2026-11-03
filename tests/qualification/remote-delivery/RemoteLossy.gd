extends SceneTree

var Role := "server"
var Index := 0
var Port := 0
var Game: Node
var Network: Node
var Failed := false
var Cases: Array[Dictionary] = []
var Measurements: Dictionary = {}

func Check(Value: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Network:WireFaults] FAIL ", Role, Index, " ", Label)

func Until(Test: Callable, Label: String) -> void:
    var Deadline := Time.get_ticks_msec() + 15000
    while not Test.call() and Time.get_ticks_msec() < Deadline: await process_frame
    Check(bool(Test.call()), Label)

func Mark(Name: String) -> void:
    FileAccess.open("res://wire-" + Name, FileAccess.WRITE).store_string("ready")

func Script(Name: String, Source: String) -> void:
    var Executable: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source; Executable.name = Name
    Executable.call("set_codigo_luau", Code); Game.add_child(Executable)

func ConfigurePeer(Peer: int) -> void:
    var Transport := Network.get_multiplayer().get_multiplayer_peer()
    if Transport is ENetMultiplayerPeer and (Transport.get_unique_id() == 1 or Peer == 1):
        Transport.get_peer(Peer).throttle_configure(5000, 32, 0)

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size() - 1):
        match Args[Position]:
            "--fixture-role": Role = Args[Position + 1]
            "--fixture-client-index": Index = int(Args[Position + 1])
            "--fixture-port": Port = int(Args[Position + 1])
    call_deferred("Run")

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "actual production extension loads")
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    Game.set_meta("Port", Port)
    for Type in ["Players", "RunService", "ReplicatedStorage"]:
        var Object: Node = ClassDB.instantiate(Type); Object.name = Type; Game.add_child(Object)
    var Prefix := Node.new()
    var Bytes := 256 - (str(Game.get_path()) + "//NetworkService").to_utf8_buffer().size()
    Prefix.name = "雪".repeat(Bytes / 3) + "x".repeat(Bytes % 3); Game.add_child(Prefix)
    Network = ClassDB.instantiate("NetworkService"); Network.name = "NetworkService"; Prefix.add_child(Network)
    Check(str(Network.get_path()).to_utf8_buffer().size() == 256, "actual NetworkService uses maximum admitted UTF-8 RPC path")
    Network.get_multiplayer().peer_connected.connect(ConfigurePeer)
    for Pair in [["Reliable", 0], ["Unordered", 1], ["Sequenced", 2]]:
        var Remote: Node = ClassDB.instantiate("RemoteEventNode")
        Remote.name = Pair[0]; Check(bool(Remote.call("SetDeliveryType", Pair[1])), "native mode configuration")
        Game.get_node("ReplicatedStorage").add_child(Remote)
    if Role == "server": await Server()
    else: await Client()
    var State: Dictionary = Network.call("GetRemoteState", null)
    Network.call("disconnect_net")
    Game.free(); await process_frame; await process_frame
    var Result := {"Result": "FAIL" if Failed else "PASS", "Role": Role, "Index": Index, "Complete": true, "Cases": Cases, "State": State, "Measurements": Measurements}
    FileAccess.open("res://wire-" + Role + str(Index) + ".json", FileAccess.WRITE).store_string(JSON.stringify(Result))
    print("[Network:WireFaults] ", Role, " ", Result.Result)
    quit(1 if Failed else 0)

func Server() -> void:
    Script("Setup", """
game:GetService('Players').CharacterAutoLoads = false
_G.ReliableOrder, _G.UnorderedOrder, _G.Duplicates = {}, {}, {}
game.ReplicatedStorage.Reliable.OnServerEvent:Connect(function(Player, Label)
    local Step = _G.ReliableOrder[Player.UserId] or 0
    assert((Step == 0 and Label == 'GL029DropReliableOnce') or (Step == 1 and Label == 'GL029ReliableAfter'))
    _G.ReliableOrder[Player.UserId] = Step + 1
    game.ReplicatedStorage.Reliable:FireClient(Player, Label)
end)
game.ReplicatedStorage.Unordered.OnServerEvent:Connect(function(Player, Label)
    assert(Label ~= 'GL029DropUnordered')
    if #Label == 758 and string.sub(Label, 1, 8) == 'GL029MTU' then
        game.ReplicatedStorage.Unordered:FireClient(Player, 'GL029MTUEcho'); return
    elseif Label == 'GL029ReorderA' or Label == 'GL029ReorderB' then
        local Values = _G.UnorderedOrder[Player.UserId] or {}
        _G.UnorderedOrder[Player.UserId] = Values; table.insert(Values, Label)
    elseif Label == 'GL029Duplicate' then
        _G.Duplicates[Player.UserId] = (_G.Duplicates[Player.UserId] or 0) + 1
    else error('unexpected unordered payload') end
    game.ReplicatedStorage.Unordered:FireClient(Player, Label)
end)
game.ReplicatedStorage.Sequenced.OnServerEvent:Connect(function(Player, Label)
    assert(Label == 'GL029SeqNew')
    game.ReplicatedStorage.Sequenced:FireClient(Player, Label)
    game:SetAttribute('Fresh', (game:GetAttribute('Fresh') or 0) + 1)
end)
game:SetAttribute('Started', true)
""")
    await Until(func(): return Game.has_meta("Started") and int(Network.call("get_mode")) == 1, "server starts through production dedicated CLI")
    Mark("ready")
    await Until(func(): return FileAccess.file_exists("res://wire-done-1") and FileAccess.file_exists("res://wire-done-2"), "both peers finish perturbed wire traffic")
    Script("Validate", """
local Count = 0
for User, Order in pairs(_G.ReliableOrder) do
    assert(Order == 2)
    local Values = _G.UnorderedOrder[User]
    assert(#Values == 2 and Values[1] == 'GL029ReorderB' and Values[2] == 'GL029ReorderA')
    assert(_G.Duplicates[User] >= 1 and _G.Duplicates[User] <= 2)
    Count += 1
end
assert(Count == 2 and game:GetAttribute('Fresh') == 2)
game:SetAttribute('Verified', true)
""")
    await Until(func(): return Game.has_meta("Verified"), "actual reliable retransmission preserves order; unordered reorders without reliable retry")
    Check(int(Network.call("GetRemoteState", null).Stale) >= 2, "actually delayed old sequenced packets reject after newer wire arrival")
    var Streams: Dictionary = Network.call("GetRemoteState", Game.get_node("ReplicatedStorage/Sequenced")).PeerStreams
    Check(Streams.size() == 2, "both independent actual peer streams remain live")
    for Stream in Streams.values(): Check(str(Stream.ReceivedSequence) == "2", "wire freshness remains native and per peer")
    Mark("close")
    await Until(func(): return FileAccess.file_exists("res://wire-closed-1") and FileAccess.file_exists("res://wire-closed-2"), "ordered native peer teardown")

func Client() -> void:
    await Until(func():
        for Name in ["Reliable", "Unordered", "Sequenced"]:
            if not bool(Network.call("GetRemoteState", Game.get_node("ReplicatedStorage/" + Name)).get("Ready", false)): return false
        return true, "peer mode and readiness handshake completes")
    for Attempt in range(3):
        Game.remove_meta("MTUSubmitted")
        Script("MTU" + str(Attempt), "game.ReplicatedStorage.Unordered:FireServer('GL029MTU' .. string.rep('x', 750)); game:SetAttribute('MTUSubmitted', true)")
        await Until(func(): return Game.has_meta("MTUSubmitted") and int(Network.call("GetRemoteState", null).OutgoingMessages) == 0, "maximum body passes production codec and native handoff")
        var Link = Network.get_multiplayer().get_multiplayer_peer().get_peer(1)
        var Native: Dictionary = Link.call("GetGodotLuauAdmission")
        if int(Native.LastSubmittedBytes) >= 816:
            Measurements = {"AbsolutePathUTF8Bytes": str(Network.get_path()).to_utf8_buffer().size(), "EventFrameBytes": 816, "SubmittedPacketBytes": int(Native.LastSubmittedBytes), "SubmittedCommands": int(Native.LastSubmittedCommands), "MTU": int(Native.MTU), "UnfragmentedPacketBytes": int(Native.UnfragmentedPacketBytes)}
            break
    Check(not Measurements.is_empty() and int(Measurements.get("SubmittedCommands", 0)) == 1 and int(Measurements.get("SubmittedPacketBytes", 0)) <= 1200 and int(Measurements.get("SubmittedPacketBytes", 0)) <= int(Measurements.get("UnfragmentedPacketBytes", 0)), "actual maximum native RemoteEvent RPC is unfragmented within reserved allowance")
    Script("Probe", """
local Reliable, Unordered, Sequenced = game.ReplicatedStorage.Reliable, game.ReplicatedStorage.Unordered, game.ReplicatedStorage.Sequenced
Reliable.OnClientEvent:Connect(function(Label) game:SetAttribute(Label, true) end)
Unordered.OnClientEvent:Connect(function(Label) assert(Label ~= 'GL029DropUnordered'); game:SetAttribute(Label, true) end)
Sequenced.OnClientEvent:Connect(function(Label) assert(Label == 'GL029SeqNew'); game:SetAttribute(Label, true) end)
Reliable:FireServer('GL029DropReliableOnce'); Reliable:FireServer('GL029ReliableAfter')
local Deadline = os.clock() + 10
while not game:GetAttribute('GL029ReliableAfter') and os.clock() < Deadline do task.wait() end
assert(game:GetAttribute('GL029DropReliableOnce') and game:GetAttribute('GL029ReliableAfter'))
Unordered:FireServer('GL029DropUnordered')
Unordered:FireServer('GL029ReorderA'); Unordered:FireServer('GL029ReorderB'); Unordered:FireServer('GL029Duplicate')
Sequenced:FireServer('GL029SeqOld')
task.wait(.03)
Sequenced:FireServer('GL029SeqNew')
task.wait(.35)
assert(not game:GetAttribute('GL029DropUnordered') and not game:GetAttribute('GL029SeqOld'))
assert(game:GetAttribute('GL029ReorderA') and game:GetAttribute('GL029ReorderB') and game:GetAttribute('GL029Duplicate') and game:GetAttribute('GL029SeqNew'))
game:SetAttribute('Done', true)
""")
    await Until(func(): return Game.has_meta("Done"), "production APIs survive real UDP loss, reorder and duplicate datagrams")
    Mark("done-" + str(Index))
    await Until(func(): return FileAccess.file_exists("res://wire-close"), "server verifies fault outcomes")
    if Index == 2: await Until(func(): return FileAccess.file_exists("res://wire-closed-1"), "first peer teardown")
    Network.call("disconnect_net"); await process_frame
    Mark("closed-" + str(Index))
