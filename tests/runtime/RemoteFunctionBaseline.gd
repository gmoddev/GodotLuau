extends SceneTree

# Immutable pre-GL-030 product only: observe real nonresponse beyond the old
# sixty-second GC interval. A PASS here means the baseline defect reproduced.
var Game: Node
var Role := "server"
var Port := 0

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

func Until(Predicate: Callable) -> bool:
    var Deadline := Time.get_ticks_msec() + 85000
    while not Predicate.call() and Time.get_ticks_msec() < Deadline: await process_frame
    return bool(Predicate.call())

func Marker(Name: String) -> void:
    var File := FileAccess.open("res://" + Name, FileAccess.WRITE)
    File.store_string("ready")
    File.close()

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded != GDExtensionManager.LOAD_STATUS_OK and Loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        quit(1)
        return
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Create("ReplicatedStorage", "ReplicatedStorage", Game)
    Create("Players", "Players", Game)
    Create("RunService", "RunService", Game)
    Create("RemoteFunctionNode", "Function", Storage)
    if Role == "client": ScriptNode("LocalScript", "Prewarm", "game:SetAttribute('Prewarmed',true)")
    var Network := Create("NetworkService", "NetworkService", Game)
    await process_frame
    var Passed := true
    if Role == "server":
        ScriptNode("ServerScript", "Nonresponding", "game.ReplicatedStorage.Function.OnServerInvoke=function(Player) assert(Player); game:SetAttribute('HandlerEntered',true); task.wait(120); return 42 end; game:SetAttribute('Ready',true)")
        Passed = await Until(func(): return Game.has_meta("Ready"))
        Marker("server.ready")
        Passed = await Until(func(): return Game.has_meta("HandlerEntered")) and Passed
        Marker("handler-entered")
        Passed = await Until(func(): return FileAccess.file_exists("res://baseline-observed.json")) and Passed
    else:
        Passed = await Until(func(): return bool(Network.call("is_connected_net")))
        ScriptNode("LocalScript", "Waiting", "game:SetAttribute('Started',true); local Ok, Value=pcall(function() return game.ReplicatedStorage.Function:InvokeServer() end); game:SetAttribute('Completed',true); game:SetAttribute('Succeeded',Ok)")
        Passed = await Until(func(): return FileAccess.file_exists("res://handler-entered")) and Passed
        var Started := Time.get_ticks_msec()
        await create_timer(70).timeout
        var Elapsed := Time.get_ticks_msec() - Started
        var Completed := Game.has_meta("Completed")
        Passed = Passed and Game.has_meta("Started") and not Completed and Elapsed >= 70000
        var Output := FileAccess.open("res://baseline-observed.json", FileAccess.WRITE)
        Output.store_string(JSON.stringify({"ElapsedMilliseconds": Elapsed, "Completed": Completed, "Result": "REPRODUCED" if Passed else "NOT_REPRODUCED", "Observation": "Valid handler entered; caller remains waiting beyond old sixty-second GC"}))
        Output.close()
    print("[Network:FunctionBaseline] ", Role, " ", "REPRODUCED" if Passed else "FAIL")
    quit(0 if Passed else 1)
