extends SceneTree
var Role := "server"
var Port := 0
var Game: Node

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--fixture-role": Role = Arguments[Index + 1]
        if Arguments[Index] == "--fixture-port": Port = int(Arguments[Index + 1])
    call_deferred("Run")

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func ScriptNode(Type: String, Name: String, Source: String) -> void:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)

func Until(Predicate: Callable, Seconds := 8.0) -> bool:
    var Deadline := Time.get_ticks_msec() + int(Seconds * 1000)
    while not Predicate.call() and Time.get_ticks_msec() < Deadline: await process_frame
    return bool(Predicate.call())

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://" + Name, FileAccess.WRITE)
    File.store_string("ready")
    File.close()

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded != GDExtensionManager.LOAD_STATUS_OK and Loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        quit(1)
        return
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    var Storage := Create("ReplicatedStorage", "ReplicatedStorage", Game)
    var StaticParent := Create("Folder", "StaticParent", Storage)
    StaticParent.owner = Game
    Create("Players", "Players", Game)
    Create("RunService", "RunService", Game)
    if Role == "client": ScriptNode("LocalScript", "Prewarm", "game:SetAttribute('ClientWarmed',true)")
    var Network := Create("NetworkService", "NetworkService", Game)
    await process_frame
    var Passed := true
    if Role == "server":
        Passed = await Until(func(): return int(Network.call("get_mode")) == 1)
        ScriptNode("ServerScript", "CreateBeforeJoin", """
local Broken = Instance.new('Folder')
Broken.Name = 'RuntimeChild'; Broken.Parent = game.ReplicatedStorage.StaticParent
local Control = Instance.new('Folder')
Control.Name = 'RuntimeControl'; Control.Parent = game.ReplicatedStorage
game:SetAttribute('CreatedBeforeJoin',true)
""")
        Passed = await Until(func(): return Game.has_meta("CreatedBeforeJoin")) and Passed
        Passed = Passed and StaticParent.has_meta("_gl_netid") and StaticParent.has_node("RuntimeChild") and Storage.has_node("RuntimeControl")
        var Identity := FileAccess.open("res://static-parent-id.txt", FileAccess.WRITE)
        Identity.store_string(str(StaticParent.get_meta("_gl_netid", 0))); Identity.close()
        Mark("server.ready")
        Passed = await Until(func(): return FileAccess.file_exists("res://replication-observed.json")) and Passed
    else:
        Passed = await Until(func(): return bool(Network.call("is_connected_net")))
        Passed = await Until(func(): return Storage.has_node("RuntimeControl")) and Passed
        var Appeared := await Until(func(): return StaticParent.has_node("RuntimeChild"), 2.0)
        var SameIdentity := str(StaticParent.get_meta("_gl_netid", 0)) == FileAccess.get_file_as_string("res://static-parent-id.txt")
        Passed = Passed and SameIdentity and not Appeared
        var Report := {"Result": "REPRODUCED" if Passed else "NOT_REPRODUCED", "RootControlArrived": Storage.has_node("RuntimeControl"), "ChildUnderStaticParentArrived": Appeared, "SameStaticParentIdentity": SameIdentity, "StaticParentId": str(StaticParent.get_meta("_gl_netid", 0))}
        var Output := FileAccess.open("res://replication-observed.json", FileAccess.WRITE)
        Output.store_string(JSON.stringify(Report)); Output.close()
    print("[Network:ReplicationBaseline] ", Role, " ", "REPRODUCED" if Passed else "FAIL")
    quit(0 if Passed else 1)
