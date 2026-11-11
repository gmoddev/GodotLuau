extends Node
## Native session/lifecycle bootstrap. Arena, UI and audio are authored in Luau.

var World: Node3D
var Network: Node
var Menu: PanelContainer
var HUD: Label
var Status: Label
var Results: PanelContainer
var ResultText: Label
var Address: LineEdit
var PortField: LineEdit
var Feedback: Label
# Keep the existing playtest observation surface without native rendering state.
var Snapshot: Dictionary:
    get:
        var Raw: String = get_meta("ClientSnapshot",get_meta("ServerSnapshot",""))
        var Decoded = JSON.parse_string(Raw) if not Raw.is_empty() else null
        return Decoded if Decoded is Dictionary else {}
var Session := false
var Mode := "solo"
var Port := 24870
var Host := "127.0.0.1"
var Auto := false
var ShuttingDown := false
var SessionAge := 0.0
var SessionError := ""

func _ready() -> void:
    name = "Game"
    get_tree().auto_accept_quit = false
    var Args := OS.get_cmdline_user_args()
    for I in range(Args.size() - 1):
        match Args[I]:
            "--mode": Mode = Args[I + 1]; Auto = true
            "--port": Port = int(Args[I + 1])
            "--address": Host = Args[I + 1]
    if get_tree().get_meta("RelaySiegeMenu",false):
        Auto = false
        get_tree().remove_meta("RelaySiegeMenu")
    set_meta("AutomatedFixture", "--probe" in Args)
    if get_meta("AutomatedFixture"):
        get_window().set_flag(Window.FLAG_NO_FOCUS, true)
    var Extension := "res://godot_luau.gdextension"
    var Loaded := GDExtensionManager.load_extension(Extension)
    if Loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
        push_error("[Game:Bootstrap] Missing staged runtime; use PrepareGame.py")
        return
    # Dedicated mode intentionally does not execute LocalScripts.
    if Auto and Mode == "server":
        StartSession(Mode)
        return
    if not await BuildUI(): return
    if Auto: StartSession(Mode)

func Native(Type: String, NodeName: String, Parent: Node = null) -> Node:
    var Value: Node = ClassDB.instantiate(Type)
    Value.name = NodeName
    (Parent if Parent else self).add_child(Value)
    return Value

func ScriptRun(NodeName: String, Source: String, Client := false, Parent: Node = null, Module := false) -> Node:
    var Value: Node = ClassDB.instantiate("ModuleScript" if Module else ("LocalScript" if Client else "ServerScript"))
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Value.name = NodeName
    Value.call("set_codigo_luau", Resource)
    (Parent if Parent else self).add_child(Value)
    return Value

func BuildUI() -> bool:
    set_meta("UIHost", Host)
    set_meta("UIPort", Port)
    ScriptRun("PresentationAuthor", FileAccess.get_file_as_string("res://Presentation.luau"), true)
    var Deadline := Time.get_ticks_msec() + 5000
    while not get_meta("UIReady", false) and Time.get_ticks_msec() < Deadline:
        await get_tree().process_frame
    if not get_meta("UIReady", false):
        push_error("[Game:Presentation] Luau UI did not become ready within five seconds")
        return false
    # Existing fixtures observe these native controls; their Luau owner writes them.
    Menu = get_node("Presentation/Layer/Menu")
    HUD = get_node("Presentation/Layer/HUD")
    Status = get_node("Presentation/Layer/Status")
    Feedback = get_node("Presentation/Layer/Feedback")
    Results = get_node("Presentation/Layer/Results")
    ResultText = get_node("Presentation/Layer/Results/Box/ResultText")
    Address = get_node("Presentation/Layer/Menu/Box/Address")
    PortField = get_node("Presentation/Layer/Menu/Box/PortField")
    return true

func StartSession(Selected: String) -> void:
    if Session: return
    if Selected == "server":
        if Port < 1024 or Port > 65535:
            push_error("[Game:Session] Choose a UDP port from 1024 to 65535")
            return
    else:
        if not is_instance_valid(PortField) or not is_instance_valid(Address): return
        if not PortField.text.is_valid_int() or int(PortField.text) < 1024 or int(PortField.text) > 65535:
            set_meta("UIMessage", "Choose a UDP port from 1024 to 65535"); return
        Port = int(PortField.text)
        Host = Address.text.strip_edges()
        if Host.is_empty() or Host.length() > 253: return
    Mode = Selected
    Session = true
    remove_meta("UIMessage")
    set_meta("SessionStarted", true)
    Native("Players", "Players")
    Native("RunService", "RunService")
    Native("ReplicatedStorage", "ReplicatedStorage")
    Native("RemoteEventNode", "Request", get_node("ReplicatedStorage"))
    Native("RemoteEventNode", "State", get_node("ReplicatedStorage"))
    Native("Node", "SettingsMenu")
    Network = Native("NetworkService", "NetworkService")
    BuildArena()
    var ArenaDeadline := Time.get_ticks_msec() + 5000
    while not get_meta("ArenaReady", false) and Time.get_ticks_msec() < ArenaDeadline:
        await get_tree().process_frame
    if not get_meta("ArenaReady", false):
        set_meta("SessionStartupFailed", true)
        return
    await get_tree().process_frame
    # NetworkService resolves --glserver through its deferred native startup.
    # Inspect the live role only after that initialization has run.
    if Mode == "server" and int(Network.call("get_mode")) != 1:
        ScriptRun("Listen", "game:SetAttribute('SessionStartupFailed',not game.NetworkService:StartServer(%d,4))" % Port)
    elif Mode == "host":
        ScriptRun("Listen", "game:SetAttribute('SessionStartupFailed',not game.NetworkService:StartServer(%d,3))" % Port)
    elif Mode == "join":
        ScriptRun("Connect", "game:SetAttribute('SessionStartupFailed',not game.NetworkService:Connect(%s,%d)); game:SetAttribute('SessionConnectAttempted',true)" % [JSON.stringify(Host), Port], true)
    if Mode != "join":
        ScriptRun("Rules", FileAccess.get_file_as_string("res://Server.luau"))
        ScriptRun("PhysicsProps", """
local Part = Instance.new('Part')
Part.Name = 'ImpulseCrate'; Part.Size = Vector3.new(2,2,2)
Part.Position = Vector3.new(-18,3,14); Part.Anchored = false
Part.Color = Color3.new(0.3,0.7,1); Part.Parent = game.Workspace
task.wait(0.1)
Part:SetNetworkOwner(nil) -- this interaction is simulated by the authoritative server
""")
    if Mode != "server":
        if Mode == "join":
            var Deadline := Time.get_ticks_msec()+15000
            while (not get_meta("SessionConnectAttempted",false) or str(Network.call("get_connection_state")) == "Connecting") and Time.get_ticks_msec()<Deadline:
                await get_tree().process_frame
            if str(Network.call("get_connection_state")) != "Connected": return
            await get_tree().process_frame
            await get_tree().process_frame
        ScriptRun("PlayerController", FileAccess.get_file_as_string("res://PlayerController.luau"), true)
        ScriptRun("GameClient", FileAccess.get_file_as_string("res://Client.luau"), true)
    print("[Game:Session] Started ", Mode, " port=", Port)

func BuildArena() -> void:
    World = ClassDB.instantiate("RobloxWorkspace") as Node3D
    World.name = "Workspace"
    World.child_entered_tree.connect(ConfigureCharacter)
    # Keep the native spawn available before Workspace constructs its Character.
    var Spawn: Node3D = ClassDB.instantiate("SpawnLocation")
    Spawn.name = "ArenaSpawn"
    Spawn.position = Vector3(0,-1,16)
    World.add_child(Spawn)
    ScriptRun("RelayFactory", FileAccess.get_file_as_string("res://RelayFactory.luau"), false, World, true)
    ScriptRun("ArenaAuthor", FileAccess.get_file_as_string("res://Arena.luau"), false, World)
    add_child(World)
    World.set_process(false)

func ConfigureCharacter(Value: Node) -> void:
    if Value.is_class("RBXCharacter"):
        ConfigureBody.call_deferred(Value.get_instance_id())

func ConfigureBody(Identity: int) -> void:
    var Value := instance_from_id(Identity)
    if not is_instance_valid(Value): return
    var Body = Value.call("GetPhysicsBody")
    if Body:
        # Co-op players do not block one another. Keep the native world mask,
        # body, movement and authority; exclude player hulls from world rays.
        Body.collision_layer = 0

func _process(Delta: float) -> void:
    if not is_instance_valid(Menu): return
    var Action: String = get_meta("UIAction", "")
    if not Action.is_empty():
        remove_meta("UIAction")
        if not ShuttingDown:
            match Action:
                "solo", "host", "join": StartSession(Action)
                "quit": Shutdown()
                "menu": MainMenu()
                "Again", "Save": set_meta("UIRequest", Action)
    if not Session: return
    SessionAge += Delta
    if not ShuttingDown:
        if get_meta("SessionStartupFailed",false): SessionError = "Session startup failed. Check the address/port."
        if Mode == "join":
            var Connection: String = Network.call("get_connection_state")
            if Connection == "Disconnected" and SessionAge > 2: SessionError = "Disconnected from server."
            if Connection == "Connecting" and SessionAge > 15:
                SessionError = "Could not reach server. Check its address and UDP port."
                Network.call("disconnect_net")
    set_meta("SessionError", SessionError)

func _notification(What: int) -> void:
    if What == NOTIFICATION_WM_CLOSE_REQUEST: Shutdown()

func Shutdown(ExitCode := 0) -> void:
    if ShuttingDown: return
    ShuttingDown = true
    set_meta("ShuttingDown", true)
    set_meta("PlayerControllerSuspended",true)
    await RetireInput()
    if is_instance_valid(Network):
        Network.call("disconnect_net")
        await get_tree().create_timer(0.35).timeout
    get_tree().quit(ExitCode)

func MainMenu() -> void:
    if ShuttingDown: return
    ShuttingDown = true
    set_meta("ShuttingDown", true)
    set_meta("PlayerControllerSuspended",true)
    await RetireInput()
    if is_instance_valid(Network):
        Network.call("disconnect_net")
        await get_tree().create_timer(0.35).timeout
    get_tree().set_meta("RelaySiegeMenu",true)
    get_tree().reload_current_scene()

func RetireInput() -> void:
    for NodeName in ["PlayerController","GameClient"]:
        var Owner := get_node_or_null(NodeName)
        if Owner: Owner.queue_free()
    await get_tree().process_frame
