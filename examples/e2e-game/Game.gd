extends Node
## Scene, UI and presentation adapter. Rules/authority are in Server.luau.

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
var Visuals: Dictionary = {}
var RelayVisuals: Array[MeshInstance3D] = []
var Snapshot: Dictionary = {}
var LastJSON := ""
var Session := false
var Mode := "solo"
var Port := 24870
var Host := "127.0.0.1"
var Auto := false
var Audio: AudioStreamPlayer
var LastShot := 0
var ShuttingDown := false

func _ready() -> void:
    name = "Game"
    get_tree().auto_accept_quit = false
    var Args := OS.get_cmdline_user_args()
    for I in range(Args.size() - 1):
        match Args[I]:
            "--mode": Mode = Args[I + 1]; Auto = true
            "--port": Port = int(Args[I + 1])
            "--address": Host = Args[I + 1]
    set_meta("AutomatedFixture", "--probe" in Args)
    if get_meta("AutomatedFixture"):
        get_window().set_flag(Window.FLAG_NO_FOCUS, true)
    var Extension := "res://godot_luau.gdextension"
    var Loaded := GDExtensionManager.load_extension(Extension)
    if Loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
        push_error("[Game:Bootstrap] Missing staged runtime; use PrepareGame.py")
        return
    BuildUI()
    if Auto: StartSession(Mode)

func Native(Type: String, NodeName: String, Parent: Node = null) -> Node:
    var Value: Node = ClassDB.instantiate(Type)
    Value.name = NodeName
    (Parent if Parent else self).add_child(Value)
    return Value

func ScriptRun(NodeName: String, Source: String, Client := false) -> Node:
    var Value: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Value.name = NodeName
    Value.call("set_codigo_luau", Resource)
    add_child(Value)
    return Value

func ButtonFor(Text: String, Parent: Node, Action: Callable) -> Button:
    var Value := Button.new()
    Value.text = Text
    Value.custom_minimum_size = Vector2(270, 42)
    Value.pressed.connect(Action)
    Parent.add_child(Value)
    return Value

func TextFor(Text: String, Parent: Node, FontSize := 20) -> Label:
    var Value := Label.new()
    Value.text = Text
    Value.add_theme_font_size_override("font_size", FontSize)
    Parent.add_child(Value)
    return Value

func BuildUI() -> void:
    var Layer := CanvasLayer.new()
    add_child(Layer)
    var Back := ColorRect.new()
    Back.color = Color(0.035, 0.055, 0.09)
    Back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    Back.name = "Backdrop"
    Layer.add_child(Back)
    Menu = PanelContainer.new()
    Menu.position = Vector2(65, 65)
    Menu.size = Vector2(440, 540)
    Layer.add_child(Menu)
    var Box := VBoxContainer.new()
    Box.add_theme_constant_override("separation", 13)
    Menu.add_child(Box)
    TextFor("RELAY SIEGE", Box, 42)
    TextFor("Cooperative survival • 1–4 players", Box)
    TextFor("Activate 3 relays. Destroy 6 drones.\nKeep the reactor alive for extraction.", Box, 18)
    ButtonFor("PLAY SOLO", Box, func(): StartSession("solo"))
    ButtonFor("HOST CO-OP", Box, func(): StartSession("host"))
    Address = LineEdit.new()
    Address.text = Host
    Address.placeholder_text = "Server address"
    Box.add_child(Address)
    PortField = LineEdit.new()
    PortField.text = str(Port)
    PortField.placeholder_text = "UDP port (1024–65535)"
    Box.add_child(PortField)
    ButtonFor("JOIN SERVER", Box, func(): StartSession("join"))
    ButtonFor("QUIT", Box, Shutdown)
    HUD = TextFor("", Layer, 22)
    HUD.position = Vector2(22, 18)
    HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE
    Status = TextFor("WASD move • RMB look • Space jump • Shift sprint\nLMB fire • R reload • E relay • P impulse crate • Esc menu", Layer, 17)
    Status.position = Vector2(22, 636)
    Status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    Feedback = TextFor("+", Layer, 28)
    Feedback.position = Vector2(568, 342)
    Feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
    Results = PanelContainer.new()
    Results.position = Vector2(370, 180)
    Results.size = Vector2(470, 300)
    Results.hide()
    Layer.add_child(Results)
    var ResultBox := VBoxContainer.new()
    Results.add_child(ResultBox)
    ResultText = TextFor("", ResultBox, 25)
    ButtonFor("PLAY ANOTHER ROUND", ResultBox, func(): set_meta("UIRequest", "Again"))
    ButtonFor("RETRY SAVE", ResultBox, func(): set_meta("UIRequest", "Save"))
    ButtonFor("QUIT", ResultBox, Shutdown)
    HUD.hide(); Status.hide(); Feedback.hide()

func StartSession(Selected: String) -> void:
    if Session: return
    if not PortField.text.is_valid_int() or int(PortField.text) < 1024 or int(PortField.text) > 65535:
        HUD.text = "Choose a UDP port from 1024 to 65535"; HUD.show(); return
    Port = int(PortField.text)
    Host = Address.text.strip_edges()
    if Host.is_empty() or Host.length() > 253: return
    Mode = Selected
    Session = true
    Menu.hide()
    Menu.get_parent().get_node("Backdrop").hide()
    HUD.show(); Status.show(); Feedback.show()
    Native("Players", "Players")
    Native("RunService", "RunService")
    Native("ReplicatedStorage", "ReplicatedStorage")
    Native("RemoteEventNode", "Request", get_node("ReplicatedStorage"))
    Native("RemoteEventNode", "State", get_node("ReplicatedStorage"))
    Native("Node", "SettingsMenu")
    Network = Native("NetworkService", "NetworkService")
    if Mode == "server":
        ScriptRun("Listen", "assert(game.NetworkService:StartServer(%d,4), '[Game:Session] Server startup failed')" % Port)
    BuildArena()
    await get_tree().process_frame
    if Mode == "host":
        ScriptRun("Listen", "assert(game.NetworkService:StartServer(%d,3), '[Game:Session] Host startup failed')" % Port)
    elif Mode == "join":
        ScriptRun("Connect", "assert(game.NetworkService:Connect(%s,%d), '[Game:Session] Join failed')" % [JSON.stringify(Host), Port], true)
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
        ScriptRun("PlayerController", FileAccess.get_file_as_string("res://PlayerController.luau"), true)
        ScriptRun("GameClient", FileAccess.get_file_as_string("res://Client.luau"), true)
    SetUpAudio()
    print("[Game:Session] Started ", Mode, " port=", Port)

func Material(Colour: Color, Emission := false) -> StandardMaterial3D:
    var Value := StandardMaterial3D.new()
    Value.albedo_color = Colour
    Value.roughness = 0.8
    if Emission:
        Value.emission_enabled = true
        Value.emission = Colour
    return Value

func Block(Position: Vector3, Size: Vector3, Colour: Color, Solid := true) -> MeshInstance3D:
    var Value := MeshInstance3D.new()
    var Mesh := BoxMesh.new()
    Mesh.size = Size
    Value.mesh = Mesh
    Value.material_override = Material(Colour)
    Value.position = Position
    World.add_child(Value)
    if Solid:
        var Body := StaticBody3D.new()
        var Collision := CollisionShape3D.new()
        var Shape := BoxShape3D.new()
        Shape.size = Size
        Collision.shape = Shape
        Body.position = Position
        Body.add_child(Collision)
        World.add_child(Body)
    return Value

func BuildArena() -> void:
    World = ClassDB.instantiate("RobloxWorkspace") as Node3D
    World.name = "Workspace"
    World.child_entered_tree.connect(ConfigureCharacter)
    # Geometry exists before Workspace's native character construction.
    Block(Vector3(0,-1.5,0), Vector3(48,1,56), Color(0.12,0.18,0.23))
    for X in [-24,24]: Block(Vector3(X,2,0),Vector3(1,7,56),Color(0.19,0.28,0.34))
    for Z in [-28,28]: Block(Vector3(0,2,Z),Vector3(48,7,1),Color(0.19,0.28,0.34))
    for X in [-8,8]: Block(Vector3(X,1,0), Vector3(3,4,3), Color(0.25,0.32,0.38))
    Block(Vector3(0,-0.94,-9),Vector3(6,0.1,6),Color(0.9,0.12,0.05),false)
    Block(Vector3(0,1,0),Vector3(3,4,3),Color(0.1,0.55,0.8))
    for Position in [Vector3(-14,0,-10),Vector3(14,0,-10),Vector3(0,0,-20)]:
        RelayVisuals.append(Block(Position+Vector3(0,0.5,0),Vector3(2,3,2),Color(0.95,0.6,0.1)))
        var Sign := Label3D.new()
        Sign.text = "RELAY %d\nE to activate" % RelayVisuals.size()
        Sign.position = Position+Vector3(0,3.5,0)
        Sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        World.add_child(Sign)
    var Spawn: Node3D = ClassDB.instantiate("SpawnLocation")
    Spawn.name = "ArenaSpawn"
    Spawn.position = Vector3(0,-1,16)
    World.add_child(Spawn)
    add_child(World)
    World.set_process(false)
    var Sun := DirectionalLight3D.new()
    Sun.rotation_degrees = Vector3(-45,-30,0)
    World.add_child(Sun)
    var Sky := WorldEnvironment.new()
    var Env := Environment.new()
    Env.background_mode = Environment.BG_COLOR
    Env.background_color = Color(0.07,0.12,0.2)
    Env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    Env.ambient_light_color = Color(0.6,0.8,1)
    Env.ambient_light_energy = 0.8
    Sky.environment = Env
    World.add_child(Sky)
    # Native Godot soft body, local presentation only; no vertex replication.
    var Canopy := SoftBody3D.new()
    Canopy.name = "PhysicsCanopy"
    var Sphere := SphereMesh.new()
    Sphere.radius = 1.4
    Sphere.height = 2.8
    Sphere.radial_segments = 12
    Sphere.rings = 6
    var Mesh := ArrayMesh.new()
    Mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,Sphere.get_mesh_arrays())
    Canopy.mesh = Mesh
    Canopy.material_override = Material(Color(0.15,0.8,0.65))
    Canopy.position = Vector3(10,5,14)
    Canopy.collision_layer = 2
    Canopy.collision_mask = 1
    World.add_child(Canopy)
    Canopy.set_point_pinned(0,true)

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

func SetUpAudio() -> void:
    Audio = AudioStreamPlayer.new()
    var Sound := AudioStreamWAV.new()
    Sound.format = AudioStreamWAV.FORMAT_16_BITS
    Sound.mix_rate = 22050
    var Samples := PackedByteArray()
    Samples.resize(3000)
    for I in range(1500):
        Samples.encode_s16(I*2,int(sin(TAU*220*I/22050.0)*(1.0-I/1500.0)*16000))
    Sound.data = Samples
    Audio.stream = Sound
    Audio.volume_db = -25
    add_child(Audio)

func _process(Delta: float) -> void:
    if not Session: return
    if get_meta("ClothReleaseRequested",false):
        set_meta("ClothReleaseRequested",false)
        var Canopy := World.get_node_or_null("PhysicsCanopy") as SoftBody3D
        if Canopy: Canopy.set_point_pinned(0,false)
    var Raw: String = get_meta("ClientSnapshot",get_meta("ServerSnapshot",""))
    if Raw != "" and Raw != LastJSON:
        LastJSON = Raw
        var Decoded = JSON.parse_string(Raw)
        if Decoded is Dictionary:
            Snapshot = Decoded
            DrawState()
    for Bot in Snapshot.get("Bots",[]):
        var Key := str(int(Bot.Id))
        if Visuals.has(Key):
            var Position: Dictionary = Bot.Position
            Visuals[Key].position = Visuals[Key].position.lerp(Vector3(Position.X,Position.Y,Position.Z),minf(1,Delta*14))
    var Shot := int(get_meta("LocalShot",0))
    if Shot != LastShot:
        LastShot = Shot
        Feedback.modulate = Color(1,0.75,0.25)
        Audio.play()
    else: Feedback.modulate = Feedback.modulate.lerp(Color.WHITE,minf(1,Delta*12))
    if is_instance_valid(Results):
        Results.visible = Snapshot.get("Phase","") in ["Victory","Defeat","StorageError"] or bool(get_meta("PlayerControllerMenu",false))

func DrawState() -> void:
    var PlayerID := int(get_meta("LocalUserId",0))
    var Mine: Dictionary = {}
    for P in Snapshot.get("Players",[]):
        if int(P.Id) == PlayerID: Mine = P
    var Enabled := 0
    for Active in Snapshot.get("Relays",[]):
        if Active: Enabled += 1
    HUD.text = "RELAY SIEGE  |  %s  |  %ds\nHealth %d  |  Ammo %d/12 %s  |  Deaths %d\nRelays %d/3  |  Drones %d/6  |  Reactor %d\nTeam: %d/4  |  Career wins %d  |  Credits %d" % [Snapshot.get("Phase","Connecting"),Snapshot.get("Time",0),Mine.get("Health",0),Mine.get("Ammo",0),"RELOADING" if Mine.get("Reload",false) else "",Mine.get("Deaths",0),Enabled,Snapshot.get("Kills",0),Snapshot.get("Reactor",0),Snapshot.get("Players",[]).size(),Snapshot.get("Progress",{}).get("Wins",0),Snapshot.get("Progress",{}).get("Credits",0)]
    if Mine.get("Health",1) <= 0: HUD.text += "\nDOWN — respawning in 2 seconds"
    ResultText.text = "%s\nReward: %d credits\n%s\nEsc to resume during a round" % [Snapshot.get("Phase","Paused"),Snapshot.get("Reward",0),Snapshot.get("Save","")]
    for I in range(mini(3,Snapshot.get("Relays",[]).size())):
        RelayVisuals[I].material_override = Material(Color(0.1,0.9,0.6) if Snapshot.Relays[I] else Color(0.95,0.6,0.1),true)
    var Present := {}
    for Bot in Snapshot.get("Bots",[]):
        var Key := str(int(Bot.Id))
        Present[Key] = true
        if not Visuals.has(Key):
            var Value := MeshInstance3D.new()
            var Mesh := SphereMesh.new()
            Mesh.radius = 1
            Mesh.height = 2
            Value.mesh = Mesh
            Value.material_override = Material(Color(0.95,0.2,0.18),true)
            Value.position = Vector3(Bot.Position.X,Bot.Position.Y,Bot.Position.Z)
            World.add_child(Value)
            Visuals[Key] = Value
    for Key in Visuals.keys():
        if not Present.has(Key): Visuals[Key].queue_free(); Visuals.erase(Key)

func _exit_tree() -> void:
    if is_instance_valid(Audio):
        Audio.stop()
        Audio.stream = null

func _notification(What: int) -> void:
    if What == NOTIFICATION_WM_CLOSE_REQUEST: Shutdown()

func Shutdown(ExitCode := 0) -> void:
    if ShuttingDown: return
    ShuttingDown = true
    set_meta("PlayerControllerSuspended",true)
    if is_instance_valid(Network):
        Network.call("disconnect_net")
        await get_tree().create_timer(0.35).timeout
    get_tree().quit(ExitCode)
