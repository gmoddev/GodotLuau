extends SceneTree

# Identical real ENet/factory/frame workload for the retained GL-007 product and V2.
var Game: Node
var World: Node
var Network: Node
var Role := "server"
var Index := "0"
var Port := 0
var Recording := false
var PhysicsBegin := 0
var ProcessBegin := 0
var LastProcess := 0
var PhysicsDispatch := []
var ProcessDispatch := []
var ProcessFrames := []

func Mark(Name: String) -> void:
    FileAccess.open("res://network-benchmark-" + Name, FileAccess.WRITE).store_string("ready")

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 15000
    while not FileAccess.file_exists("res://network-benchmark-" + Name):
        assert(Time.get_ticks_msec() < Deadline, "bounded network benchmark barrier " + Name)
        await process_frame

func Create(Type: String, Name: String) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Game.add_child(Result)
    return Result

func Script(Source: String) -> void:
    var Executable: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    Executable.name = "ConnectScript"
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source
    Executable.call("set_codigo_luau", Code)
    Game.add_child(Executable)

func Summary(Values: Array) -> Dictionary:
    Values.sort()
    var Total := 0.0
    for Value in Values: Total += float(Value)
    return {"Mean": Total/Values.size(), "Median": Values[Values.size() / 2], "P95": Values[int(ceil(Values.size()*0.95))-1], "P99": Values[int(ceil(Values.size()*0.99))-1], "Samples": Values.size(), "Raw": Values}

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size()-1):
        if Args[Position] == "--fixture-role": Role = Args[Position+1]
        if Args[Position] == "--fixture-port": Port = int(Args[Position+1])
        if Args[Position] == "--fixture-client-index": Index = Args[Position+1]
    call_deferred("Run")

func Run() -> void:
    assert(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED])
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    for Front in [true, false]:
        var Probe: Node = preload("res://CharacterDispatchProbe.gd").new()
        Probe.Host = self
        Probe.Front = Front
        Probe.process_priority = -100000 if Front else 100000
        Probe.process_physics_priority = Probe.process_priority
        Game.add_child(Probe)
    Game.set_meta("Port", Port)
    Create("Players", "Players")
    Create("RunService", "RunService")
    Network = Create("NetworkService", "NetworkService")
    Create("Node", "SettingsMenu")
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(10000, 1, 10000)
    Shape.shape = Box
    Floor.position.y = -1.5
    Floor.add_child(Shape)
    Game.add_child(Floor)
    if Role == "server":
        Script("assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4)); game:SetAttribute('Listening', true)")
        while not Game.has_meta("Listening"): await process_frame
        Mark("ready")
    else:
        await Wait("ready")
        Script("assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
    var Deadline := Time.get_ticks_msec() + 15000
    while World.find_children("RemotePlayer_*", "", true, false).size() < 2:
        assert(Time.get_ticks_msec() < Deadline, "two actual remote Characters required")
        await process_frame
    var Character: Node = World.get_node("LocalPlayer")
    var Health: Node = Character if Character.is_class("RBXCharacter") else Character.get_node("Humanoid")
    Health.call("set_npc_move_dir", Vector3.RIGHT)
    for Tick in range(90): await physics_frame
    var Process := []
    var Physics := []
    Recording = true
    for Tick in range(240):
        await physics_frame
        Process.append(Performance.get_monitor(Performance.TIME_PROCESS))
        Physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
    Recording = false
    print("[Character:NetworkBenchmark] ", JSON.stringify({"Architecture": "CharacterV2" if Character.is_class("RBXCharacter") else "GL007", "Role": Role+Index, "ProcessSeconds": Summary(Process), "PhysicsSeconds": Summary(Physics), "DispatchProcessSeconds": Summary(ProcessDispatch), "DispatchPhysicsSeconds": Summary(PhysicsDispatch), "FrameSeconds": Summary(ProcessFrames), "TimingScope": "priority probes bracket SceneTree dispatch; engine monitor snapshots are coarse; dispatch includes networking/controller/harness and is not isolated networking CPU", "RemoteCharacters": World.find_children("RemotePlayer_*", "", true, false).size(), "Objects": Performance.get_monitor(Performance.OBJECT_COUNT), "StaticMemoryBytes": Performance.get_monitor(Performance.MEMORY_STATIC)}))
    Mark(Role + Index + ".measured")
    if Role == "server":
        await Wait("client1.measured")
        await Wait("client2.measured")
        Mark("client1.close")
        await Wait("client1.closed")
        while Game.get_multiplayer().get_peers().size() > 1: await process_frame
        await create_timer(0.2).timeout
        Mark("client2.close")
        await Wait("client2.closed")
        while Game.get_multiplayer().get_peers().size() > 0: await process_frame
        await create_timer(0.2).timeout
    else:
        await Wait("client" + Index + ".close")
    Network.call("disconnect_net")
    if Role == "client": Mark("client" + Index + ".closed")
    Game.free()
    await process_frame
    print("[Character:NetworkBenchmark] PASS")
    quit(0)
