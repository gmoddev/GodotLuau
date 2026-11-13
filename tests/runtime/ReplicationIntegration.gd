extends SceneTree

var Role := "server"
var Game: Node
var Storage: Node
var StaticParent: Node
var Network: Node
var Cases: Array = []
var Failed := false

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--fixture-role": Role = Arguments[Index + 1]
    call_deferred("Run")

func Check(Condition: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Condition})
    Failed = Failed or not Condition
    print("[Network:ReplicationTest] ", "PASS " if Condition else "FAIL ", Label)

func Until(Predicate: Callable, Label: String) -> void:
    var Deadline := Time.get_ticks_msec() + 8000
    while not Predicate.call() and Time.get_ticks_msec() < Deadline: await process_frame
    Check(bool(Predicate.call()), Label)

func Mark(Name: String, Value := "ready") -> void:
    var Path := "res://replication-" + Name
    var Pending := Path + ".pending"
    var File := FileAccess.open(Pending, FileAccess.WRITE)
    File.store_string(Value)
    File.close()
    Check(DirAccess.rename_absolute(ProjectSettings.globalize_path(Pending),ProjectSettings.globalize_path(Path))==OK,"publish complete barrier " + Name)

func Wait(Name: String) -> void:
    await Until(func(): return FileAccess.file_exists("res://replication-" + Name), "barrier " + Name)

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func ScriptNode(Name: String, Source: String) -> void:
    var Result: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension loaded")
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    Storage = Create("ReplicatedStorage", "ReplicatedStorage", Game)
    StaticParent = Create("Folder", "StaticParent", Storage)
    StaticParent.owner = Game
    var LocalInput := Create("InputContext","LocalInput",Storage)
    var LocalMotor := Create("KinematicMotor3D","LocalMotor",Storage)
    LocalInput.owner = Game
    LocalMotor.owner = Game
    var StaticIdentity := StaticParent.get_instance_id()
    var Players := Create("Players", "Players", Game)
    Players.call("set_character_auto_loads", false)
    Create("RunService", "RunService", Game)
    if Role == "client": ScriptNode("Prewarm", "game:SetAttribute('ClientWarmed',true)")
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    Check(not LocalInput.has_meta("_gl_netid") and not LocalMotor.has_meta("_gl_netid"), "local input and motor are excluded from static network identities")
    Check(int(LocalMotor.call("GetTicks"))==0, "scene-authored motor is inert until Client adoption")
    if Role == "server": await Server()
    else: await Client()
    Check(is_instance_valid(StaticParent) and StaticParent.get_instance_id() == StaticIdentity, "static parent native identity preserved")
    Network.call("disconnect_net")
    Game.free(); await process_frame; await process_frame
    var Record := {"Role": Role, "Transport": "ENet", "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases}
    Mark("evidence-" + Role + ".json", JSON.stringify(Record))
    print("[Network:ReplicationTest] ", Role, " ", Record.Result)
    quit(1 if Failed else 0)

func Server() -> void:
    await Until(func(): return int(Network.call("get_mode")) == 1, "native server started")
    ScriptNode("CreateBeforeJoin", """
local Storage = game.ReplicatedStorage
local Earlier = Instance.new('Folder')
Earlier.Name = 'EarlierId'; Earlier.Parent = Storage
local Later = Instance.new('Folder')
Later.Name = 'LaterIdParent'; Later.Parent = Storage.StaticParent
Earlier.Parent = Later
local Number = Instance.new('IntValue')
Number.Name = 'Number'; Number.Value = 37; Number.Parent = Earlier
local Control = Instance.new('Folder')
Control.Name = 'RuntimeControl'; Control.Parent = Storage
game:SetAttribute('CreatedBeforeJoin',true)
""")
    await Until(func(): return Game.has_meta("CreatedBeforeJoin"), "production Luau created runtime ancestry before join")
    var Earlier := Storage.get_node("StaticParent/LaterIdParent/EarlierId")
    var Number := Earlier.get_node("Number")
    var Identities := {"Static": str(StaticParent.get_meta("_gl_netid")), "Earlier": str(Earlier.get_meta("_gl_netid")), "Later": str(Earlier.get_parent().get_meta("_gl_netid")), "Number": str(Number.get_meta("_gl_netid"))}
    Check(int(Identities.Earlier) < int(Identities.Later), "runtime parent has a later network identity than its child")
    Mark("identities.json", JSON.stringify(Identities))
    Mark("server.ready")
    await Wait("client.joined")
    ScriptNode("MoveAfterJoin", "local Earlier = game.ReplicatedStorage.StaticParent.LaterIdParent.EarlierId; Earlier.Parent = game.ReplicatedStorage; Earlier.Name = 'MovedEarlierId'; Earlier.Number.Value = 52; game:SetAttribute('Moved',true)")
    await Until(func(): return Game.has_meta("Moved"), "production Luau reparent and property change completed")
    await Wait("client.moved")
    ScriptNode("DestroyAfterJoin", "game.ReplicatedStorage.MovedEarlierId:Destroy(); game:SetAttribute('Removed',true)")
    await Until(func(): return Game.has_meta("Removed"), "production Luau removed runtime subtree")
    await Wait("client.removed")
    ScriptNode("ReplaceAfterJoin", "local Replacement = Instance.new('Folder'); Replacement.Name = 'MovedEarlierId'; Replacement.Parent = game.ReplicatedStorage; game:SetAttribute('Replaced',true)")
    await Until(func(): return Game.has_meta("Replaced"), "production Luau created same-name replacement")
    await Wait("client.replaced")
    Mark("done")
    await Wait("client.done")

func Client() -> void:
    await Until(func(): return bool(Network.call("is_connected_net")), "native client connected")
    await Until(func(): return Storage.has_node("RuntimeControl"), "direct runtime control arrives")
    await Until(func(): return Storage.has_node("StaticParent/LaterIdParent/EarlierId/Number"), "late-join static and runtime parent closure arrives")
    if not Storage.has_node("StaticParent/LaterIdParent/EarlierId/Number"): return
    var Earlier := Storage.get_node("StaticParent/LaterIdParent/EarlierId")
    var Number := Earlier.get_node("Number")
    var EarlierIdentity := Earlier.get_instance_id()
    var NumberIdentity := Number.get_instance_id()
    var Identities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://replication-identities.json"))
    Check(str(StaticParent.get_meta("_gl_netid")) == Identities.Static, "static parent full-width identity matches the server")
    Check(str(Earlier.get_meta("_gl_netid")) == Identities.Earlier and str(Number.get_meta("_gl_netid")) == Identities.Number, "runtime network identities match the server")
    Check(Number.get("Value") == 37, "late-join value snapshot decoded")
    Mark("client.joined")
    await Until(func(): return Storage.has_node("MovedEarlierId/Number") and Storage.get_node("MovedEarlierId/Number").get("Value") == 52, "reparent and current property converge")
    Check(is_instance_id_valid(EarlierIdentity) and Storage.get_node("MovedEarlierId").get_instance_id() == EarlierIdentity, "reparent preserves native runtime identity")
    Check(is_instance_id_valid(NumberIdentity) and Storage.get_node("MovedEarlierId/Number").get_instance_id() == NumberIdentity, "descendant identity survives reparent")
    Mark("client.moved")
    await Until(func(): return not Storage.has_node("MovedEarlierId"), "authoritative subtree removal arrives")
    Check(Network.call("net_node_by_id", int(Identities.Earlier)) == null and Network.call("net_node_by_id", int(Identities.Number)) == null, "removed subtree identities are forgotten")
    Mark("client.removed")
    await Until(func(): return Storage.has_node("MovedEarlierId"), "same-name replacement arrives")
    Check(Storage.get_node("MovedEarlierId").get_instance_id() != EarlierIdentity and str(Storage.get_node("MovedEarlierId").get_meta("_gl_netid")) != Identities.Earlier, "replacement has fresh native and network identities")
    Mark("client.replaced")
    await Wait("done")
    Mark("client.done")
