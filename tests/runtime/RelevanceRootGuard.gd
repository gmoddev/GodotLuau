extends "res://ReplicationIntegration.gd"

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension loaded")
    ProjectSettings.set_setting("godot_luau/network/replication_relevance", true)
    Game = Node.new(); Game.name = "Game"; root.add_child(Game); current_scene = Game
    Storage = Create("ReplicatedStorage", "ReplicatedStorage", Game)
    var Players := Create("Players", "Players", Game); Players.call("set_character_auto_loads", false)
    Create("RunService", "RunService", Game)
    var World := Create("RobloxWorkspace", "Workspace", Game); World.set_process(false)
    var Port := 0
    var Arguments := OS.get_cmdline_user_args()
    for Index in range(Arguments.size() - 1):
        if Arguments[Index] == "--fixture-port": Port = int(Arguments[Index + 1])
    Game.set_meta("Port", Port)
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    ScriptNode("Listen", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'),2)); game:SetAttribute('Listening',true)")
    await Until(func(): return Game.has_meta("Listening"), "listen host started through Server API")
    Check(bool(Network.call("GetReplicationState").Enabled) and int(Network.call("GetReplicationState").Catalog) == 0 and Network.call("GetCharacterStates").is_empty(), "opted-in empty catalog has no Character authority fallback")
    var Identity := Game.get_instance_id()
    Role = "client"
    ScriptNode("AncestorAttack", "game:SetAttribute('AttackStarted',true); game:Destroy(); game:SetAttribute('AttackReturned',true)")
    Role = "server"
    await Until(func(): return not is_instance_valid(Game) or not Game.is_inside_tree() or Game.has_meta("AttackReturned"), "actual Client ancestor mutation completed or removed scene")
    await process_frame; await process_frame
    Check(is_instance_valid(Game) and Game.is_inside_tree() and Game.get_instance_id() == Identity, "Client cannot destroy structural ancestor of captured scope roots before first publication")
    Check(is_instance_valid(Game) and Game.has_meta("AttackReturned"), "rejected mutation permits ordinary Client callback completion")
    if is_instance_valid(Network): Network.call("disconnect_net")
    if is_instance_valid(Game): Game.free()
    await process_frame; await process_frame
    var Record := {"Role": "listen", "Transport": "ENet", "Complete": true, "Result": "FAIL" if Failed else "PASS", "Cases": Cases}
    Mark("evidence-root.json", JSON.stringify(Record))
    print("[Network:RootGuardTest] ", Record.Result)
    quit(1 if Failed else 0)
