extends SceneTree

var Game: Node
var Network: Node
var Function: Node
var Event: Node
var Role := "server"
var Port := 0
var ClientIndex := 0
var Failed := false
var Cases: Array = []
var Mode := "Dedicated"
var AttackSent := false
var LateSent := false
var ReplaySent := false

func _process(_Delta: float) -> bool:
    if Role != "client" or not is_instance_valid(Network): return false
    if not ReplaySent and not State().Requests.is_empty():
        ReplaySent = true
        var Header: Array = State().Requests[0].Header.duplicate()
        Network.rpc_id(1, "_rf_invoke_server", Header + [["Replay"]])
    if not AttackSent and FileAccess.file_exists("res://function-attack.json"):
        AttackSent = true
        var Attack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://function-attack.json"))
        var Header: Array = Attack.Header
        # JSON numbers cannot carry this protocol's complete int64 identities.
        for Index in range(Header.size()): Header[Index] = int(str(Header[Index]))
        var Wrong := Header.duplicate()
        Wrong[2] += 1
        Network.rpc_id(1, "_rf_return", Wrong + [true, [666]])
        Wrong = Header.duplicate(); Wrong[4] += 1
        Network.rpc_id(1, "_rf_return", Wrong + [true, [666]])
        if int(Network.call("get_peer_id")) != int(Attack.Peer):
            Network.rpc_id(1, "_rf_return", Header + [true, [666]])
        Mark("attacked-" + str(ClientIndex))
    if AttackSent and not LateSent and Marked("send-late"):
        LateSent = true
        var Attack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://function-attack.json"))
        if int(Network.call("get_peer_id")) == int(Attack.Peer):
            var Header: Array = Attack.Header
            for Index in range(Header.size()): Header[Index] = int(str(Header[Index]))
            Network.rpc_id(1, "_rf_return", Header + [true, [777]])
            Network.rpc_id(1, "_rf_return", Header + [true, [777]])
        Mark("late-" + str(ClientIndex))
    return false

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        match Arguments[Index]:
            "--fixture-role": Role = Arguments[Index + 1]
            "--fixture-port": Port = int(Arguments[Index + 1])
            "--fixture-client-index": ClientIndex = int(Arguments[Index + 1])
            "--remote-mode": Mode = Arguments[Index + 1]
    call_deferred("Run")

func Check(Condition: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Condition})
    print("[Network:FunctionTest] ", "PASS " if Condition else "FAIL ", Label)
    Failed = Failed or not Condition

func Until(Predicate: Callable, Label: String, Seconds := 8.0) -> bool:
    var Deadline := Time.get_ticks_msec() + int(Seconds * 1000)
    while not Predicate.call() and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Result := bool(Predicate.call())
    Check(Result, Label)
    return Result

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func ScriptNode(Type: String, Name: String, Source: String) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Result.name = Name
    Resource.source_code = Source
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func State() -> Dictionary:
    return Network.call("GetFunctionState")

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://function-" + Name + ".json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Role": Role, "Index": ClientIndex}))
    File.close()

func Marked(Name: String) -> bool:
    return FileAccess.file_exists("res://function-" + Name + ".json")

func Run() -> void:
    ProjectSettings.set_setting("godot_luau/network/remote_function_timeout_seconds", 0.4)
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded != GDExtensionManager.LOAD_STATUS_OK and Loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        Check(false, "extension load")
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
    Function = Create("RemoteFunctionNode", "Function", Storage)
    Create("RemoteFunctionNode", "Empty", Storage)
    Event = Create("RemoteEventNode", "Event", Storage)
    if Role == "client":
        ScriptNode("LocalScript", "Prewarm", "game:SetAttribute('Prewarmed', true)")
    Network = Create("NetworkService", "NetworkService", Game)
    Check(not Network.has_method("net_invoke_server") and not Network.has_method("net_invoke_client"), "reflection cannot allocate ownerless request slots")
    await process_frame
    if Role == "server":
        if Mode == "Listen":
            ScriptNode("ServerScript", "Start", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'),4)); game:SetAttribute('Started',true)")
            await Until(func(): return Game.has_meta("Started"), "listen server starts existing transport")
        ScriptNode("ServerScript", "ServerHandlers", """
local Function = game.ReplicatedStorage.Function
assert(not pcall(function() Function.OnClientInvoke = function() end end))
Function.OnServerInvoke = function(Player, Kind, ...)
    assert(Player and Player:IsA('Player'))
    if Kind == 'Replay' then game:SetAttribute('ReplaySideEffects',true) end
    if Kind == 'Success' then
        local Values = table.pack(...)
        assert(Values.n == 3 and Values[1] == 41 and Values[2] == nil and Values[3] == 'tail')
        task.wait(0.02)
        return 42, nil, {Nested = {Value = 43}}, Vector3.new(1,2,3)
    elseif Kind == 'Error' then error('controlled transform error')
    elseif Kind == 'Block' then task.wait(10); return 'late'
    elseif Kind == 'Delayed' then task.wait(0.15); return 'old'
    elseif Kind == 'Fresh' then task.wait(0.1); return 'fresh'
    elseif Kind == 'Retire' then game:SetAttribute('RetireRequested', true); task.wait(10)
    end
    return Kind
end
game:SetAttribute('HandlersReady', true)
""")
        await Until(func(): return Game.has_meta("HandlersReady"), "server yielding handler installed")
        var Ready := FileAccess.open("res://server.ready", FileAccess.WRITE)
        Ready.store_string("ready")
        Ready.close()
        await Until(func(): return Marked("ready-1") and Marked("ready-2"), "both clients published function endpoints")
        await Until(func(): return Marked("basic-1") and Marked("basic-2"), "both clients completed success error timeout manual-resume cases")
        var Peer := 0
        for Player in Game.get_node("Players").get_children():
            var Candidate := int(Network.call("peer_for_player_node", Player))
            if Candidate > 1:
                Peer = Candidate
                break
        Check(Peer > 1, "authoritative Player resolves a real peer")
        var TargetPlayer: Node
        for Player in Game.get_node("Players").get_children():
            if int(Network.call("peer_for_player_node", Player)) == Peer: TargetPlayer = Player
        var Streams: Dictionary = Network.call("GetRemoteState", Function).PeerStreams
        for Identity in Streams:
            if int(Identity) == Peer: Game.set_meta("TargetUser", int(Streams[Identity].User))
        var Rejected := int(State().Rejected)
        ScriptNode("ServerScript", "BlockedReverse", """
local Player
for _, Candidate in game:GetService('Players'):GetPlayers() do
    if Candidate.UserId == game:GetAttribute('TargetUser') then Player = Candidate end
end
assert(Player)
local Ok, Message = pcall(function() game.ReplicatedStorage.Function:InvokeClient(Player, 'Block') end)
assert(not Ok and string.find(tostring(Message),'timed out',1,true))
game:SetAttribute('BlockedReverseDone',true)
""")
        await Until(func(): return int(State().Pending) == 1, "reverse request retained before adversarial transport")
        var Attack: Dictionary = State().Requests[0]
        var EncodedHeader: Array = []
        for Value in Attack.Header: EncodedHeader.append(str(Value))
        var AttackFile := FileAccess.open("res://function-attack.json", FileAccess.WRITE)
        AttackFile.store_string(JSON.stringify({"Peer": Attack.Peer, "Header": EncodedHeader}))
        AttackFile.close()
        await Until(func(): return Marked("attacked-1") and Marked("attacked-2"), "both actual ENet peers submitted adversarial responses")
        await Until(func(): return Game.has_meta("BlockedReverseDone"), "wrong sender session and generation cannot settle an invocation")
        Mark("send-late")
        await Until(func(): return Marked("late-1") and Marked("late-2"), "expected peer submitted duplicate late responses")
        await Until(func(): return int(State().Rejected) >= Rejected + 7, "wrong-peer stale-session generation and duplicate late frames rejected")
        ScriptNode("ServerScript", "InvokeClient", """
local Player
for _, Candidate in game:GetService('Players'):GetPlayers() do
    if Candidate.UserId == game:GetAttribute('TargetUser') then Player = Candidate end
end
assert(Player)
local Values = table.pack(game.ReplicatedStorage.Function:InvokeClient(Player, 41))
assert(Values.n == 1 and Values[1] == 42, 'InvokeClient returns: '..tostring(Values.n)..' '..tostring(Values[1])..' '..tostring(Values[2]))
game:SetAttribute('InvokeClientDone', true)
""")
        await Until(func(): return Game.has_meta("InvokeClientDone"), "InvokeClient preserves yielding success")
        Mark("client-call-done")
        await Until(func(): return Game.has_meta("RetireRequested") and int(State().Serving) == 2, "both requests reached handlers before endpoint retirement")
        var OldId := Function.get_instance_id()
        Function.free()
        Function = Create("RemoteFunctionNode", "Function", Storage)
        Check(Function.get_instance_id() != OldId, "same path replacement has fresh native identity")
        await Until(func(): return Marked("retired-1") and Marked("retired-2"), "retirement completes exact pending requests on both peers")
        await Until(func(): return int(State().Pending) == 0 and int(State().Serving) == 0, "server retires all serving and pending records")
        Check(not Game.has_meta("ReplaySideEffects"), "duplicate requests cannot execute a second handler")
        Mark("done")
    else:
        await Until(func(): return bool(Network.call("GetRemoteState", Function).get("Ready", false)), "function publication acknowledged and activated")
        Check(bool(Network.call("QualificationFunctionCounter", 9007199254740992 + ClientIndex * 1000)), "request identity seeded above exact Lua number range")
        ScriptNode("LocalScript", "ClientHandler", "assert(not pcall(function() game.ReplicatedStorage.Function.OnServerInvoke=function() end end)); game.ReplicatedStorage.Function.OnClientInvoke=function(Value) if Value=='Block' then task.wait(10) end; task.wait(0.02); return Value+1 end; game:SetAttribute('ClientHandlerReady',true)")
        await Until(func(): return Game.has_meta("ClientHandlerReady"), "client yielding handler installed")
        Mark("ready-" + str(ClientIndex))
        ScriptNode("LocalScript", "Basic", """
local Function = game.ReplicatedStorage.Function
local Values = table.pack(Function:InvokeServer('Success',41,nil,'tail'))
assert(Values.n == 4 and Values[1] == 42 and Values[2] == nil and Values[3].Nested.Value == 43 and Values[4].X == 1, 'InvokeServer returns: '..tostring(Values.n)..' '..tostring(Values[1])..' '..tostring(Values[2])..' '..tostring(Values[3]))
local Ok, Message = pcall(function() Function:InvokeServer('Error') end)
assert(not Ok and string.find(tostring(Message),'controlled transform error',1,true))
Ok, Message = pcall(function() game.ReplicatedStorage.Empty:InvokeServer() end)
assert(not Ok and string.find(tostring(Message),'handler is not set',1,true))
Ok, Message = pcall(function() Function:InvokeServer('Block') end)
assert(not Ok and string.find(tostring(Message),'timed out',1,true))
for _, Resume in {coroutine.resume, task.spawn} do
    local Done = false
    local Thread = task.spawn(function()
        local Accepted, Error = pcall(function() Function:InvokeServer('Delayed') end)
        assert(not Accepted and string.find(tostring(Error),'outside completion',1,true))
        assert(Function:InvokeServer('Fresh') == 'fresh')
        Done = true
    end)
    task.wait(0.03)
    Resume(Thread, 'forged')
    while not Done do task.wait() end
end
assert(not pcall(function() Function:InvokeServer(string.rep('x',65536)) end))
assert(Function:InvokeServer('final') == 'final')
game:SetAttribute('BasicDone', true)
""")
        await Until(func(): return Game.has_meta("BasicDone"), "success nil slots nested payload error timeout manual-resume and bounds")
        await Until(func(): return int(State().Pending) == 0 and int(State().Responses) == 0, "client terminal outcomes release exact correlation records")
        Engine.time_scale = 20.0
        var DeadlineStarted := Time.get_ticks_msec()
        ScriptNode("LocalScript", "MonotonicDeadline", "local Ok, Message=pcall(function() game.ReplicatedStorage.Function:InvokeServer('Block') end); assert(not Ok and string.find(tostring(Message),'timed out',1,true)); game:SetAttribute('MonotonicDeadlineDone',true)")
        await Until(func(): return Game.has_meta("MonotonicDeadlineDone"), "deadline completes under accelerated simulation time")
        var DeadlineElapsed := Time.get_ticks_msec() - DeadlineStarted
        Engine.time_scale = 1.0
        Check(DeadlineElapsed >= 390 and DeadlineElapsed < 3000, "native deadline uses wall time instead of scaled frame delta")
        multiplayer_poll = false
        ScriptNode("LocalScript", "Bounds", """
local Pending = {}
for Index=1,64 do
    Pending[Index] = task.spawn(function() pcall(function() game.ReplicatedStorage.Function:InvokeServer('Block') end) end)
end
local Ok, Message = pcall(function() game.ReplicatedStorage.Function:InvokeServer('Block') end)
assert(not Ok and string.find(tostring(Message),'pending limit',1,true))
game:SetAttribute('BoundFull',true)
while not game:GetAttribute('ReleaseBounds') do task.wait() end
for _, Thread in Pending do task.cancel(Thread) end
game:SetAttribute('BoundDone',true)
""")
        await Until(func(): return Game.has_meta("BoundFull"), "exact pending ceiling admits and one-over rejects")
        Check(int(State().Pending) == 64, "per-peer pending accounting retains exactly sixty-four requests")
        Game.set_meta("ReleaseBounds", true)
        await Until(func(): return Game.has_meta("BoundDone") and int(State().Pending) == 0 and int(State().Responses) == 0, "task cancellation detaches all pending records")
        multiplayer_poll = true
        var Before := int(State().Rejected)
        Network.call("_rf_return", [1,1,1,1,1,1,true,[666]])
        Check(int(State().Rejected) == Before + 1, "reflected response cannot establish transport provenance")
        Mark("basic-" + str(ClientIndex))
        await Until(func(): return Marked("client-call-done"), "server completed reverse invoke")
        ScriptNode("LocalScript", "Retiring", """
_G.RetainedFunctionInvoke = game.ReplicatedStorage.Function.InvokeServer
_G.RetainedFunctionObject = game.ReplicatedStorage.Function
local Ok, Message = pcall(function() game.ReplicatedStorage.Function:InvokeServer('Retire') end)
assert(not Ok)
game:SetAttribute('PendingRetired',true)
while not game:GetAttribute('LocalDestroyed') do task.wait() end
assert(not pcall(function() _G.RetainedFunctionInvoke(_G.RetainedFunctionObject, 'replacement') end))
game:SetAttribute('RetiredDone',true)
""")
        await Until(func(): return Game.has_meta("PendingRetired"), "server retirement settles the in-flight call")
        var OldId := Function.get_instance_id()
        Function.free()
        Function = Create("RemoteFunctionNode", "Function", Storage)
        Check(Function.get_instance_id() != OldId and not bool(Network.call("GetRemoteState", Function).get("Ready", false)), "Client replacement has fresh ObjectID and cannot inherit function readiness")
        Game.set_meta("LocalDestroyed", true)
        await Until(func(): return Game.has_meta("RetiredDone"), "endpoint retirement and retained closure reject replacement")
        Check(bool(Network.call("QualificationFunctionCounter", 9223372036854775806)), "checked identity reaches final positive boundary")
        ScriptNode("LocalScript", "Exhaustion", """
pcall(function() game.ReplicatedStorage.Function:InvokeServer() end)
local Ok, Message = pcall(function() game.ReplicatedStorage.Function:InvokeServer() end)
assert(not Ok and string.find(tostring(Message),'identity exhausted',1,true))
game:SetAttribute('Exhausted',true)
""")
        await Until(func(): return Game.has_meta("Exhausted"), "request identity exhaustion fails before wrap or reuse")
        Mark("retired-" + str(ClientIndex))
        await Until(func(): return Marked("done"), "server final barrier")
    var Report := {"Mode": Mode, "Role": Role, "ClientIndex": ClientIndex, "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases, "State": State()}
    var Output := FileAccess.open("res://function-" + Role + str(ClientIndex) + "-result.json", FileAccess.WRITE)
    Output.store_string(JSON.stringify(Report))
    Output.close()
    print("[Network:FunctionTest] ", Role, " ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
