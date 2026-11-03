extends SceneTree

# Production Fire/echo workload without Character, renderer or gameplay physics.
var Role := "server"
var Index := 0
var Count := 1
var Port := 0
var Samples := 64
var Warmup := 16
var Game: Node
var Network: Node
var Remote: Node
var Recording := false
var PhysicsBegin := 0
var ProcessBegin := 0
var LastProcess := 0
var PhysicsDispatch := []
var ProcessDispatch := []
var ProcessFrames := []
var ObservationUsec := []
var NativeHighBytes := 0
var NativeHighCommands := 0
var NativeObservationAvailable := false
var Observations := 0

func Mark(Name: String) -> void:
    FileAccess.open("res://bench-" + Name, FileAccess.WRITE).store_string("ready")

func Until(Test: Callable, Label: String) -> void:
    var Deadline := Time.get_ticks_msec() + 120000
    while not Test.call():
        assert(Time.get_ticks_msec() < Deadline, Label)
        await process_frame

func Script(Name: String, Source: String) -> void:
    var Executable: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source; Executable.name = Name
    Executable.call("set_codigo_luau", Code); Game.add_child(Executable)

func Summary(Values: Array) -> Dictionary:
    if Values.is_empty(): return {"Samples": 0}
    var Ordered := Values.duplicate(); Ordered.sort()
    var Total := 0.0
    for Value in Values: Total += float(Value)
    return {"Samples": Values.size(), "Mean": Total / Values.size(), "Median": Ordered[Values.size() / 2], "P95": Ordered[int(ceil(Values.size() * .95)) - 1], "P99": Ordered[int(ceil(Values.size() * .99)) - 1], "Raw": Values}

func Memory() -> Dictionary:
    return {"StaticBytes": Performance.get_monitor(Performance.MEMORY_STATIC), "Objects": Performance.get_monitor(Performance.OBJECT_COUNT), "Nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size() - 1):
        match Args[Position]:
            "--fixture-role": Role = Args[Position + 1]
            "--fixture-client-index": Index = int(Args[Position + 1])
            "--fixture-port": Port = int(Args[Position + 1])
            "--peers": Count = int(Args[Position + 1])
            "--samples": Samples = int(Args[Position + 1])
    call_deferred("Run")

func _process(_Delta: float) -> bool:
    if Recording and is_instance_valid(Network):
        Observations += 1
        if Observations % 10 == 0:
            var Started := Time.get_ticks_usec()
            var Transport := Network.get_multiplayer().get_multiplayer_peer()
            var Peers := Network.get_multiplayer().get_peers()
            if Transport is ENetMultiplayerPeer and not Peers.is_empty():
                var Peer := 1 if Role == "client" else int(Peers[0])
                var Link = Transport.get_peer(Peer)
                if Link.has_method("GetGodotLuauAdmission"):
                    NativeObservationAvailable = true
                    var State: Dictionary = Link.call("GetGodotLuauAdmission")
                    NativeHighBytes = maxi(NativeHighBytes, int(State.HostBytes))
                    NativeHighCommands = maxi(NativeHighCommands, int(State.HostCommands))
            ObservationUsec.append(Time.get_ticks_usec() - Started)
    return false

func AllMarked(Prefix: String) -> bool:
    for Peer in range(1, Count + 1):
        if not FileAccess.file_exists("res://bench-" + Prefix + str(Peer)): return false
    return true

func Run() -> void:
    assert(Count >= 1 and Count <= 64 and Samples >= 32 and Samples <= 256)
    assert(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED])
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    for Type in ["Players", "RunService", "ReplicatedStorage", "NetworkService"]:
        var Object: Node = ClassDB.instantiate(Type); Object.name = Type; Game.add_child(Object)
    Network = Game.get_node("NetworkService")
    Remote = ClassDB.instantiate("RemoteEventNode"); Remote.name = "Bench"; Game.get_node("ReplicatedStorage").add_child(Remote)
    for Front in [true, false]:
        var Probe := preload("res://CharacterDispatchProbe.gd").new()
        Probe.Host = self; Probe.Front = Front; Probe.process_priority = -100000 if Front else 100000; Probe.process_physics_priority = Probe.process_priority
        Game.add_child(Probe)
    Game.set_meta("Port", Port); Game.set_meta("Peers", Count); Game.set_meta("Samples", Samples); Game.set_meta("Warmup", Warmup)
    var Started := Time.get_ticks_usec()
    if Role == "server":
        Script("Setup", """
game:GetService('Players').CharacterAutoLoads = false
_G.BenchFire, _G.BenchCalls = {}, 0
game.ReplicatedStorage.Bench.OnServerEvent:Connect(function(Player, Number, Stamp, Payload)
    assert(#Payload == 1024)
    local Before = os.clock()
    game.ReplicatedStorage.Bench:FireClient(Player, Number, Stamp, #Payload)
    table.insert(_G.BenchFire, os.clock() - Before); _G.BenchCalls += 1
end)
assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), game:GetAttribute('Peers') + 1))
game:SetAttribute('Started', true)
""")
        await Until(func(): return Game.has_meta("Started"), "server startup")
        Mark("server-ready")
        await Until(func(): return AllMarked("ready-"), "all peer warmups")
        await create_timer(.2).timeout
    else:
        Script("Connect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
        await Until(func(): return bool(Network.call("GetRemoteState", Remote).get("Ready", false)), "endpoint readiness")
        var Link = Network.get_multiplayer().get_multiplayer_peer().get_peer(1)
        Link.throttle_configure(5000, 32, 0)
        Script("Warmup", """
_G.BenchRTT, _G.BenchFire, _G.BenchEchoes = {}, {}, 0
_G.BenchLast = 0
game.ReplicatedStorage.Bench.OnClientEvent:Connect(function(Number, Stamp, Bytes)
    assert(Bytes == 1024 and Number == _G.BenchLast + 1)
    _G.BenchLast = Number; _G.BenchEchoes += 1
    if Number > game:GetAttribute('Warmup') then table.insert(_G.BenchRTT, os.clock() - Stamp) end
end)
local R, Payload = game.ReplicatedStorage.Bench, string.rep('x', 1024)
for Number = 1, game:GetAttribute('Warmup') do
    R:FireServer(Number, os.clock(), Payload)
    while _G.BenchLast ~= Number do task.wait() end
end
game:SetAttribute('Warm', true)
""")
        await Until(func(): return Game.has_meta("Warm"), "client warmup")
        Mark("ready-" + str(Index))
        await Until(func(): return FileAccess.file_exists("res://bench-go"), "measurement start")
    var Before := Memory()
    var StartupUsec := Time.get_ticks_usec() - Started
    Recording = true; LastProcess = Time.get_ticks_usec()
    if Role == "server":
        Script("WarmReset", "_G.BenchFire = {}; game:SetAttribute('Reset', true)")
        await Until(func(): return Game.has_meta("Reset"), "server warmed statistics reset")
        Mark("go")
        await Until(func(): return AllMarked("done-"), "all measured peer workloads")
        Script("Report", "assert(_G.BenchCalls == (game:GetAttribute('Warmup') + game:GetAttribute('Samples')) * game:GetAttribute('Peers')); game:SetAttribute('Stats', game:GetService('HttpService'):JSONEncode({Fire = _G.BenchFire, Calls = _G.BenchCalls}))")
    else:
        Script("Measure", """
local R, Payload = game.ReplicatedStorage.Bench, string.rep('x', 1024)
for Number = game:GetAttribute('Warmup') + 1, game:GetAttribute('Warmup') + game:GetAttribute('Samples') do
    local Stamp = os.clock()
    R:FireServer(Number, Stamp, Payload)
    table.insert(_G.BenchFire, os.clock() - Stamp)
    while _G.BenchLast ~= Number do task.wait() end
end
game:SetAttribute('Stats', game:GetService('HttpService'):JSONEncode({RTT = _G.BenchRTT, Fire = _G.BenchFire, Calls = _G.BenchEchoes}))
""")
    await Until(func(): return Game.has_meta("Stats"), "statistics report")
    Recording = false
    var Stats: Dictionary = JSON.parse_string(str(Game.get_meta("Stats")))
    if Role == "client":
        assert(Stats.RTT.size() == Samples and Stats.Fire.size() == Samples)
        Mark("done-" + str(Index))
        await Until(func(): return FileAccess.file_exists("res://bench-close"), "coordinated close")
    var Queue: Dictionary = Network.call("GetRemoteState", null)
    var Result := {"Role": Role, "Index": Index, "Peers": Count, "SamplesPerPeer": Samples, "Warmup": Warmup, "PayloadBytes": 1024, "StartupUsec": StartupUsec, "RTTSeconds": Summary(Stats.get("RTT", [])), "FireCallSeconds": Summary(Stats.Fire), "CallbackStarts": int(Stats.Calls), "NodeDispatchSeconds": Summary(ProcessDispatch), "FrameSeconds": Summary(ProcessFrames), "PhysicsDispatchSeconds": Summary(PhysicsDispatch), "ObservationUsec": Summary(ObservationUsec), "ObservedNativeHighBytes": NativeHighBytes, "ObservedNativeHighCommands": NativeHighCommands, "Application": Queue, "MemoryBefore": Before, "MemoryAfterWork": Memory(), "Graphical": false, "Characters": 0}
    Result["NativeObservationAvailable"] = NativeObservationAvailable
    if not NativeObservationAvailable:
        Result["ObservedNativeHighBytes"] = null
        Result["ObservedNativeHighCommands"] = null
    if Role == "server":
        Mark("close")
        await Until(func(): return AllMarked("closed-"), "ordered client teardown")
    elif Index > 1:
        await Until(func(): return FileAccess.file_exists("res://bench-closed-" + str(Index - 1)), "previous peer teardown")
    Network.call("disconnect_net")
    Game.free(); await process_frame; await process_frame; await process_frame
    Result["MemoryAfterTeardown"] = Memory()
    if Role == "client": Mark("closed-" + str(Index))
    FileAccess.open("res://bench-" + Role + str(Index) + ".json", FileAccess.WRITE).store_string(JSON.stringify(Result))
    print("[Network:DeliveryBenchmark] PASS ", Role, Index)
    quit()
