extends SceneTree

var Game: Node
var Role := "server"
var Port := 0
var Failed := false
var CoordinatedClose := false
var ClientIndex := 0
var ClosedPeers := 0

func PeerClosed(_Identity: int) -> void:
    ClosedPeers += 1
    var Marker := FileAccess.open("res://client" + str(ClosedPeers) + ".closed", FileAccess.WRITE)
    Marker.store_string("transport poll completed")
    Marker.close()
    if ClosedPeers == 2: Game.set_meta("BothClosed", true)

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--fixture-role": Role = Arguments[Index + 1]
        if Arguments[Index] == "--fixture-port": Port = int(Arguments[Index + 1])
        if Arguments[Index] == "--fixture-client-index": ClientIndex = int(Arguments[Index + 1])
    CoordinatedClose = Arguments.has("--coordinated-close")
    call_deferred("Run")

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func CreateScript(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Parent.add_child(Result)
    return Result

func Until(Key: String, Frames := 600) -> bool:
    for Index in range(Frames):
        if Game.has_meta(Key): return true
        await process_frame
    Failed = true
    print("[Runtime:NetworkTest] FAIL ", Role, " waiting for ", Key)
    return false

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded != GDExtensionManager.LOAD_STATUS_OK and Loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        print("[Runtime:NetworkTest] FAIL load")
        quit(1)
        return
    Game = Node.new()
    Game.name = "Game"
    Game.set_meta("Port", Port)
    root.add_child(Game)
    current_scene = Game
    var Storage := Create("ReplicatedStorage", "ReplicatedStorage", Game)
    Create("Players", "Players", Game)
    Create("RunService", "RunService", Game)
    Create("ServerStorage", "ServerStorage", Game)
    Create("RemoteEventNode", "Event", Storage)
    Create("RemoteFunctionNode", "Function", Storage)
    CreateScript("ModuleScript", "Counter", "_G.Inits = (_G.Inits or 0) + 1; task.wait(0.02); return {Value = 0}", Storage)
    if Role == "client": CreateScript("LocalScript", "Prewarm", "assert(game:GetService('RunService'):IsClient()); game:SetAttribute('Prewarmed', true)", Game)
    var Network := Create("NetworkService", "NetworkService", Game)
    if CoordinatedClose and Role == "server":
        Game.get_multiplayer().peer_disconnected.connect(PeerClosed, CONNECT_DEFERRED)
    await process_frame
    if Role == "client":
        CreateScript("ServerScript", "ForbiddenServer", "game:SetAttribute('WrongRole', true)", Game)
        for Index in range(600):
            if Network.call("is_connected_net"): break
            await process_frame
        var Victim := CreateScript("LocalScript", "PendingInvokeVictim", "game:SetAttribute('VictimWaiting', true); game.ReplicatedStorage.Function:InvokeServer(-1); game:SetAttribute('CancelledInvokeRan', true)", Game)
        await Until("VictimWaiting")
        await process_frame
        Victim.queue_free()
        CreateScript("LocalScript", "ClientA", """
assert(game:GetService('RunService'):IsClient())
assert(game:GetService('ServerStorage') == nil)
local Counter = require(game.ReplicatedStorage.Counter)
Counter.Value += 1; shared.Counter = Counter; _G.ADone = true
game.ReplicatedStorage.Event.OnClientEvent:Once(function(Value)
    task.wait(0.02)
    assert(Value == 42 and script.Name == 'ClientA')
    game:SetAttribute('EventDone', true)
end)
assert(game.ReplicatedStorage.Function:InvokeServer(41) == 42)
assert(script.Name == 'ClientA')
local Marker = game.ReplicatedStorage:WaitForChild('ReplicationMarker', 2)
assert(Marker and Marker:WaitForChild('ReplicatedValue', 2).Value == 42)
game:SetAttribute('FunctionDone', true)
game.ReplicatedStorage.Event:FireServer(32)
""", Game)
        CreateScript("LocalScript", "ClientB", "local Counter = require(game.ReplicatedStorage.Counter); while not _G.ADone do task.wait() end; assert(Counter == shared.Counter and Counter.Value == 1 and _G.Inits == 1); game:SetAttribute('CacheDone', true)", Game)
        for Key in ["EventDone", "FunctionDone", "CacheDone"]: await Until(Key)
        await create_timer(0.3).timeout
        if Game.has_meta("CancelledInvokeRan"): Failed = true
        if CoordinatedClose and ClientIndex == 2:
            while not FileAccess.file_exists("res://client1.closed"): await process_frame
        if OS.get_cmdline_user_args().has("--fixture-teardown"):
            CreateScript("LocalScript", "ServicePendingInvoke", """
game:SetAttribute('ServiceInvokeWaiting', true)
local Ok, Message = pcall(function() return game.ReplicatedStorage.Function:InvokeServer(-1) end)
assert(not Ok and string.find(tostring(Message), 'left the game', 1, true))
game:SetAttribute('ServiceInvokeCancelled', true)
""", Game)
            await Until("ServiceInvokeWaiting")
            await process_frame
            Network.queue_free()
            await Until("ServiceInvokeCancelled")
    else:
        if Role == "server":
            CreateScript("LocalScript", "ForbiddenClient", "game:SetAttribute('WrongRole', true)", Game)
        var Start := ""
        if Role == "listen": Start = "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4))\n"
        CreateScript("ServerScript", "ServerA", Start + """
assert(game:GetService('RunService'):IsServer())
local Marker = Instance.new('Folder')
Marker.Name = 'ReplicationMarker'; Marker.Parent = game.ReplicatedStorage
local ReplicatedValue = Instance.new('IntValue')
ReplicatedValue.Name = 'ReplicatedValue'; ReplicatedValue.Value = 42; ReplicatedValue.Parent = Marker
local Counter = require(game.ReplicatedStorage.Counter)
Counter.Value += 1; shared.Counter = Counter; _G.ADone = true
game.ReplicatedStorage.Function.OnServerInvoke = function(Player, Value)
    if Value < 0 then task.wait(0.15); return 0 end
    task.wait(0.02)
    assert(script.Name == 'ServerA' and game:GetService('RunService'):IsServer())
    return Value + 1
end
game.ReplicatedStorage.Event.OnServerEvent:Connect(function(Player, Value)
    task.wait(0.02)
    assert(Value == 32 and script.Name == 'ServerA')
    game.ReplicatedStorage.Event:FireClient(Player, Value + 10)
    _G.Events = (_G.Events or 0) + 1
    if _G.Events == 2 then game:SetAttribute('BothClients', true) end
end)
game:SetAttribute('ServerReady', true)
""", Game)
        CreateScript("ServerScript", "ServerB", "local Counter = require(game.ReplicatedStorage.Counter); while not _G.ADone do task.wait() end; assert(Counter == shared.Counter and Counter.Value == 1 and _G.Inits == 1); game:SetAttribute('ServerCache', true)", Game)
        await Until("ServerReady")
        await Until("ServerCache")
        if Role == "listen":
            CreateScript("LocalScript", "ListenClient", "assert(game:GetService('RunService'):IsClient()); local Counter = require(game.ReplicatedStorage.Counter); assert(Counter.Value == 0 and _G.Inits == 1); Counter.Value = 9; game:SetAttribute('ListenDone', true)", Game)
            await Until("ListenDone")
            CreateScript("ServerScript", "ListenVerifier", "assert(require(game.ReplicatedStorage.Counter).Value == 1); game:SetAttribute('ListenSeparate', true)", Game)
            await Until("ListenSeparate")
            CreateScript("ServerScript", "RetainedService", """
local Network = game:GetService('NetworkService')
local Getter, Disconnect = Network.GetPeerId, Network.Disconnect
game:SetAttribute('ServiceRetained', true)
task.wait(0.05)
assert(Getter(Network) == 0)
Disconnect(Network)
while not game:GetAttribute('ReplacementReady') do task.wait() end
assert(game:GetService('NetworkService'):GetPeerId() == 1)
game:SetAttribute('ServiceReleasedSafely', true)
""", Game)
            await Until("ServiceRetained")
            Network.queue_free()
            await process_frame
            Network = Create("NetworkService", "NetworkService", Game)
            CreateScript("ServerScript", "ReplacementService", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4)); game:SetAttribute('ReplacementReady', true)", Game)
            await Until("ServiceReleasedSafely")
        else:
            var Ready := FileAccess.open("res://server.ready", FileAccess.WRITE)
            Ready.store_string("ready")
            Ready.close()
            await Until("BothClients")
            if CoordinatedClose: await Until("BothClosed")
            else: await create_timer(0.4).timeout
    if Game.has_meta("WrongRole"): Failed = true
    print("[Runtime:NetworkTest] ", Role, " ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
