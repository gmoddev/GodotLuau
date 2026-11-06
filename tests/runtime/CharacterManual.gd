extends SceneTree

var Game: Node
var World: Node
var Network: Node
var Players: Node
var Role := "server"
var Index := "0"
var Port := 0
var Failed := false

func Check(Value: bool, Description: String) -> void:
    if not Value:
        Failed = true
        print("[Character:Manual] FAIL ", Description)

func Mark(Name: String) -> void:
    FileAccess.open("res://manual-" + Name, FileAccess.WRITE).store_string("ready")

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 12000
    while not FileAccess.file_exists("res://manual-" + Name):
        if Time.get_ticks_msec() > Deadline:
            Check(false, "barrier " + Name)
            quit(1)
            return
        await process_frame

func Create(Type: String, Name: String) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Game.add_child(Result)
    return Result

func Script(Source: String) -> void:
    var Executable: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    Executable.name = "Probe" + str(Game.get_child_count())
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source
    Executable.call("set_codigo_luau", Code)
    Game.add_child(Executable)

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size()-1):
        if Args[Position] == "--fixture-role": Role = Args[Position+1]
        if Args[Position] == "--fixture-port": Port = int(Args[Position+1])
        if Args[Position] == "--fixture-client-index": Index = Args[Position+1]
    call_deferred("Run")

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Game.set_meta("Port", Port)
    Players = ClassDB.instantiate("Players")
    Players.name = "Players"
    Players.call("set_character_auto_loads", false)
    Game.add_child(Players)
    Create("RunService", "RunService")
    Create("Node", "SettingsMenu")
    Network = Create("NetworkService", "NetworkService")
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    Check(World.get_node_or_null("LocalPlayer") == null, "automatic initial Character is absent")
    var BeforeCharacter := "assert(Player.Character==nil); " if Role == "server" else ""
    Script("local P=game:GetService('Players'); P.PlayerAdded:Connect(function(Player) " + BeforeCharacter + "game:SetAttribute('Added', (game:GetAttribute('Added') or 0)+1); Player.CharacterAdded:Connect(function(C) assert(C:IsA('Character')); game:SetAttribute('Characters', (game:GetAttribute('Characters') or 0)+1) end) end)")
    if Role == "server":
        Mark("ready")
        await Wait("client1.ready")
        await Wait("client2.ready")
        var Deadline := Time.get_ticks_msec() + 8000
        while Game.get_meta("Added", 0) < 2 and Time.get_ticks_msec() < Deadline: await process_frame
        print("[Character:Manual] admission diagnostic added=", Game.get_meta("Added", 0), " roster=", Network.call("get_players_roster"), " states=", Network.call("GetCharacterStates"), " children=", World.get_children(), " local=", Network.call("HasLocalParticipant"))
        Check(Game.get_meta("Added", 0) == 2 and World.find_children("RemotePlayer_*", "", true, false).is_empty(), "two real Players admitted without Characters or a dedicated-server pseudo-player")
        Script("local P=game:GetService('Players'); assert(#P:GetPlayers()==2); for _,Player in P:GetPlayers() do assert(Player.Character==nil); Player:LoadCharacter() end; game:SetAttribute('Loaded', true)")
        Deadline = Time.get_ticks_msec() + 8000
        while not Game.has_meta("Loaded") and Time.get_ticks_msec() < Deadline: await process_frame
        Check(Game.has_meta("Loaded") and Game.get_meta("Characters", 0) == 2, "manual Server LoadCharacter fires one birth for each Player")
        Mark("loaded")
        await Wait("client1.loaded")
        await Wait("client2.loaded")
        Mark("client1.close")
        await Wait("client1.closed")
        while Game.get_multiplayer().get_peers().size() > 1: await process_frame
        await process_frame
        Mark("client2.close")
        await Wait("client2.closed")
        while Game.get_multiplayer().get_peers().size() > 0: await process_frame
        await process_frame
    else:
        await Wait("ready")
        Script("assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
        var Deadline := Time.get_ticks_msec() + 8000
        while not Network.call("is_connected_net") and Time.get_ticks_msec() < Deadline: await process_frame
        var Peer: int = Network.call("get_peer_id")
        while (not Network.call("GetCharacterStates").has(Peer) or int(Network.call("GetCharacterStates")[Peer].Epoch) == 0) and Time.get_ticks_msec() < Deadline: await process_frame
        Check(Network.call("GetCharacterStates").has(Peer) and World.get_node_or_null("LocalPlayer") == null, "native readiness works before any local Character exists")
        if Index == "2":
            while Network.call("get_players_roster").size() < 2 and Time.get_ticks_msec() < Deadline: await process_frame
            Check(Network.call("get_players_roster").size() == 2, "late join restores existing Player without a Character")
        Mark("client" + Index + ".ready")
        await Wait("loaded")
        Deadline = Time.get_ticks_msec() + 8000
        while (World.get_node_or_null("LocalPlayer") == null or World.find_children("RemotePlayer_*", "", true, false).is_empty()) and Time.get_ticks_msec() < Deadline: await process_frame
        Check(World.get_node_or_null("LocalPlayer") != null and World.find_children("RemotePlayer_*", "", true, false).size() == 1, "manual birth reaches actual owner and observer Characters")
        var Character: Node = World.get_node_or_null("LocalPlayer")
        Check(Character != null and Players.call("get_local_player").call("get_character") == Character, "Player.Character references the admitted actual root")
        while Game.get_meta("Characters", 0) < 2 and Time.get_ticks_msec() < Deadline: await process_frame
        await create_timer(0.3).timeout
        Check(Game.get_meta("Characters", 0) == 2, "one CharacterAdded for the local and remote life")
        Mark("client" + Index + ".loaded")
        await Wait("client" + Index + ".close")
        Network.call("disconnect_net")
        Mark("client" + Index + ".closed")
    Game.free()
    await process_frame
    print("[Character:Manual] ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
