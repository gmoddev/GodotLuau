extends SceneTree

var Game: Node
var Network: Node
var Role := "measure"
var Port := 0

func Mark(Name: String, Text := "ready") -> void:
    var File := FileAccess.open("res://character-baseline-" + Name, FileAccess.WRITE)
    File.store_string(Text)
    File.close()

func Wait(Name: String) -> bool:
    var Deadline := Time.get_ticks_msec() + 10000
    while not FileAccess.file_exists("res://character-baseline-" + Name):
        if Time.get_ticks_msec() >= Deadline: return false
        await process_frame
    return true

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Index in range(Args.size() - 1):
        if Args[Index] == "--fixture-role": Role = Args[Index + 1]
        if Args[Index] == "--fixture-port": Port = int(Args[Index + 1])
    call_deferred("Run")

func Create(Type: String, Name: String) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Game.add_child(Result)
    return Result

func Script(Source: String) -> void:
    var Result: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)

func Measure() -> void:
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(10000, 1, 10000)
    Shape.shape = Box
    Floor.add_child(Shape)
    Floor.position.y = -1.5
    Game.add_child(Floor)
    var Camera := Camera3D.new()
    Game.add_child(Camera)
    Camera.make_current()
    var Body := CharacterBody3D.new()
    var Capsule := CollisionShape3D.new()
    Capsule.shape = CapsuleShape3D.new()
    Body.add_child(Capsule)
    Body.position.y = 5
    Game.add_child(Body)
    var Humanoid: Node = ClassDB.instantiate("Humanoid")
    Body.add_child(Humanoid)
    for Tick in range(90): await physics_frame
    Humanoid.call("set_npc_move_dir", Vector3.RIGHT)
    var Walk := 0.0
    for Tick in range(90):
        await physics_frame
        Walk = maxf(Walk, Vector2(Body.velocity.x, Body.velocity.z).length())
    var Shift := InputEventKey.new()
    Shift.keycode = KEY_SHIFT
    Shift.pressed = true
    Input.parse_input_event(Shift)
    var RunSpeed := 0.0
    for Tick in range(90):
        await physics_frame
        RunSpeed = maxf(RunSpeed, Vector2(Body.velocity.x, Body.velocity.z).length())
    var Jump := InputEventKey.new()
    Jump.keycode = KEY_SPACE
    Jump.pressed = true
    Input.parse_input_event(Jump)
    var Up := 0.0
    var Down := 0.0
    var Peak := Body.position.y
    for Tick in range(60):
        await physics_frame
        if Tick == 2:
            Jump.pressed = false
            Input.parse_input_event(Jump)
        Up = maxf(Up, Body.velocity.y)
        Down = minf(Down, Body.velocity.y)
        Peak = maxf(Peak, Body.position.y)
    Shift.pressed = false
    Input.parse_input_event(Shift)
    print("[Character:Baseline] measured ", JSON.stringify({"Walk": Walk, "Run": RunSpeed,
        "JumpVelocity": Up, "FallVelocity": Down, "PeakY": Peak, "PhysicsHz": Engine.physics_ticks_per_second}))
    assert(is_equal_approx(Walk, 16.0) and is_equal_approx(RunSpeed, 24.0))
    assert(Up > 19.0 and Down < -15.0)
    Game.free()
    quit(0)

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    assert(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED])
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    if Role == "measure":
        await Measure()
        return
    Create("Players", "Players")
    Create("RunService", "RunService")
    Network = Create("NetworkService", "NetworkService")
    Game.set_meta("Port", Port)
    await process_frame
    if Role == "server":
        Script("assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4))")
        while not Network.call("is_connected_net"): await process_frame
        Mark("ready")
        assert(await Wait("sent"))
        await create_timer(0.3).timeout
        var Peer := int(FileAccess.get_file_as_string("res://character-baseline-peer"))
        var Character := root.get_node_or_null("RemotePlayer_" + str(Peer))
        assert(Character != null)
        var Humanoid: Node = Character.get_node("Humanoid")
        print("[Character:Baseline] accepted ", JSON.stringify({"PositionX": Character.global_position.x,
            "Health": Humanoid.call("get_health")}))
        assert(Character.global_position.x == 100000.0 and Humanoid.call("get_health") == 1.0)
        Humanoid.call("set_health", 75.0)
        Mark("damage")
        assert(await Wait("overwrite"))
        await create_timer(0.15).timeout
        print("[Character:Baseline] server damage overwritten health=", Humanoid.call("get_health"))
        assert(Humanoid.call("get_health") == 100.0)
        Mark("done")
    else:
        assert(await Wait("ready"))
        Script("assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
        var Deadline := Time.get_ticks_msec() + 10000
        while not Network.call("is_connected_net"):
            assert(Time.get_ticks_msec() < Deadline)
            await process_frame
        await create_timer(0.1).timeout
        Mark("peer", str(Network.call("get_peer_id")))
        Network.rpc_id(1, "_relay_state", Vector3(100000, 0, 0), 0.0, 999, 1.0, 0.0, false)
        Mark("sent")
        assert(await Wait("damage"))
        Network.rpc_id(1, "_relay_state", Vector3(100000, 0, 0), 0.0, 999, 100.0, 0.0, false)
        Mark("overwrite")
        assert(await Wait("done"))
    Script("game:GetService('NetworkService'):Disconnect()")
    await process_frame
    Game.free()
    await process_frame
    print("[Character:Baseline] ", Role, " PASS")
    quit(0)
