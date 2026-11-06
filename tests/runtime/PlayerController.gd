extends "res://CharacterIntegration.gd"

var Cases: Array[Dictionary] = []
var Chat: LineEdit
var MenuPanel: PanelContainer
var Graphical := false
var Automated := true

func Check(Value: bool, Description: String) -> void:
    Cases.append({"Label":Description,"Passed":Value})
    super.Check(Value,Description)

func Key(Code: Key, Down: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code
    Event.physical_keycode = Code
    Event.pressed = Down
    if Code >= KEY_A and Code <= KEY_Z: Event.unicode = int(Code)+32
    Input.parse_input_event(Event)

func Press(Code: Key) -> void:
    Key(Code,true)
    Key(Code,false)
    await create_timer(0.06).timeout

func Probe(Name: String, Source: String, Client := true) -> Node:
    Script(Name,Source+"\ngame:SetAttribute('"+Name+"',true)",Client)
    await create_timer(0.06).timeout
    Check(Game.get_meta(Name,false),Name)
    return Game.get_node(Name)

func Character() -> Node3D:
    return World.get_node_or_null("LocalPlayer") as Node3D

func SetUp() -> void:
    Game = Node.new()
    Game.name = "Game"
    Game.set_meta("Port",Port)
    Game.set_meta("AutomatedFixture",Automated)
    root.add_child(Game)
    current_scene = Game
    Create("Players","Players")
    Create("RunService","RunService")
    Network = Create("NetworkService","NetworkService")
    Network.get_multiplayer().peer_connected.connect(ConfigurePeer)
    var Settings := Node.new()
    Settings.name = "SettingsMenu"
    Game.add_child(Settings)
    World = ClassDB.instantiate("RobloxWorkspace")
    World.name = "Workspace"
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(1000,1,1000)
    Shape.shape = Box
    Floor.position.y = -1.5
    Floor.add_child(Shape)
    var Mesh := MeshInstance3D.new()
    var Cube := BoxMesh.new()
    Cube.size = Box.size
    var Material := StandardMaterial3D.new()
    Material.albedo_color = Color(0.2,0.35,0.28)
    Cube.material = Material
    Mesh.mesh = Cube
    Floor.add_child(Mesh)
    World.add_child(Floor)
    Game.add_child(World)
    World.set_process(false)
    var Sun := DirectionalLight3D.new()
    Sun.rotation_degrees = Vector3(-50,-30,0)
    Game.add_child(Sun)
    var EnvironmentNode := WorldEnvironment.new()
    var Lighting := Environment.new()
    Lighting.background_mode = Environment.BG_COLOR
    Lighting.background_color = Color(0.25,0.45,0.65)
    Lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    Lighting.ambient_light_color = Color.WHITE
    Lighting.ambient_light_energy = 0.6
    EnvironmentNode.environment = Lighting
    Game.add_child(EnvironmentNode)
    for Position in [Vector3(-6,1,-12),Vector3(6,1,-12),Vector3(0,1,-24)]:
        var Marker := MeshInstance3D.new()
        var Column := CylinderMesh.new()
        Column.height = 4
        Marker.mesh = Column
        Marker.position = Position
        Game.add_child(Marker)
    if Character(): Character().global_position = Vector3.ZERO

func SetUpUI() -> void:
    var Layer := CanvasLayer.new()
    Game.add_child(Layer)
    var Help := Label.new()
    Help.position = Vector2(20,20)
    Help.text = "Actual Player.Character / Luau InputService controller\nWASD / left stick | Shift / L3 sprint | Space / A jump\nRMB + mouse / right stick look | Escape / Start menu\nF6 remap jump | F8 replace controller | F9 Native / Scripted"
    Layer.add_child(Help)
    Chat = LineEdit.new()
    Chat.position = Vector2(20,120)
    Chat.size = Vector2(320,35)
    Chat.placeholder_text = "Type here: gameplay input is suspended"
    Layer.add_child(Chat)
    MenuPanel = PanelContainer.new()
    MenuPanel.position = Vector2(400,100)
    var Buttons := VBoxContainer.new()
    MenuPanel.add_child(Buttons)
    for Pair in [["Resume","PlayerControllerResumeRequested"],["Remap jump","PlayerControllerRemapRequested"],["Replace controller","PlayerControllerReplaceRequested"]]:
        var ButtonNode := Button.new()
        ButtonNode.text = Pair[0]
        ButtonNode.pressed.connect(func(): Chat.release_focus(); Game.set_meta(Pair[1],true))
        Buttons.add_child(ButtonNode)
    Layer.add_child(MenuPanel)

func _process(_Delta: float) -> bool:
    if is_instance_valid(MenuPanel) and is_instance_valid(Game):
        MenuPanel.visible = Game.get_meta("PlayerControllerMenu",false)
    return false

func StartExample() -> Node:
    Script("PlayerController",FileAccess.get_file_as_string("res://PlayerController.luau"),true)
    await create_timer(0.1).timeout
    Check(Game.get_meta("PlayerControllerRunning",false),"actual Luau PlayerController attached")
    return Game.get_node("PlayerController")

func LocalChecks() -> void:
    var C := Character()
    var Body: CharacterBody3D = C.call("GetPhysicsBody")
    await create_timer(0.25).timeout
    Check(C.call("GetControllerMode")==0 and Body.is_on_floor(),"Native default and grounded existing body")
    var Before := C.global_position
    Key(KEY_W,true)
    await create_timer(0.2).timeout
    Key(KEY_W,false)
    await create_timer(0.2).timeout
    Check(C.global_position.distance_to(Before)>1,"default native hardware movement remains compatible")
    var Identity := C.get_instance_id()
    var BodyIdentity := Body.get_instance_id()
    var AnimatorIdentity := C.get_node("Animator").get_instance_id()
    var Owner := await StartExample()
    Check(C.call("GetControllerMode")==1 and C.call("IsControllerActive"),"Scripted mode owns a live local lease")
    var Limb: Node3D = C.find_child("Left Leg",true,false) as Node3D
    var LimbRotation := Limb.rotation if Limb else Vector3.ZERO
    Before = C.global_position
    Key(KEY_W,true)
    await create_timer(0.2).timeout
    if Graphical:
        Check(Limb!=null and not LimbRotation.is_equal_approx(Limb.rotation),"actual R6 animation progresses under scripted movement")
        await RenderingServer.frame_post_draw
        Check(root.get_texture().get_image().save_png("res://player-controller-walking.png")==OK,"rendered scripted walking evidence")
    Key(KEY_W,false)
    await create_timer(0.2).timeout
    var Walking := C.global_position.distance_to(Before)
    Check(Walking>1,"semantic movement controls actual Player.Character")
    Before = C.global_position
    Key(KEY_SHIFT,true)
    Key(KEY_W,true)
    await create_timer(0.2).timeout
    Key(KEY_W,false)
    Key(KEY_SHIFT,false)
    await create_timer(0.2).timeout
    Check(C.global_position.distance_to(Before)>Walking*1.2,"scripted sprint uses native multiplier")
    await Press(KEY_SPACE)
    Check(Body.velocity.y>0 and not Body.is_on_floor(),"scripted grounded jump uses native physics")
    await create_timer(1.0).timeout
    Check(Body.is_on_floor(),"scripted jump falls and lands")
    await Press(KEY_F6)
    Check(Game.get_meta("PlayerControllerJumpBinding","")=="E","custom runtime jump binding")
    await Press(KEY_SPACE)
    Check(Body.is_on_floor(),"old jump binding cannot compete through native polling")
    await Press(KEY_E)
    Check(Body.velocity.y>0,"remapped jump reaches native controller")
    await create_timer(1.0).timeout

    Key(KEY_W,true)
    await create_timer(0.12).timeout
    Chat.grab_focus()
    await create_timer(0.12).timeout
    Before = C.global_position
    await create_timer(0.15).timeout
    Check(C.global_position.distance_to(Before)<0.02,"GUI focus stops an already held gameplay action")
    Chat.release_focus()
    await create_timer(0.15).timeout
    Check(C.global_position.distance_to(Before)<0.02,"GUI release requires fresh semantic admission")
    Key(KEY_W,false)
    await create_timer(0.04).timeout
    Key(KEY_W,true)
    await create_timer(0.12).timeout
    Key(KEY_W,false)
    await create_timer(0.2).timeout
    Check(C.global_position.distance_to(Before)>0.5,"fresh input resumes after GUI focus")

    var Axis := InputEventJoypadMotion.new()
    Axis.device = 0
    Axis.axis = JOY_AXIS_LEFT_X
    Axis.axis_value = 0.7
    Before = C.global_position
    Input.parse_input_event(Axis)
    await create_timer(0.2).timeout
    Check(C.global_position.distance_to(Before)>0.5,"semantic gamepad stick controls actual Character")
    Game.get_node("InputService").call("DeviceChanged",0,false)
    await create_timer(0.2).timeout
    Check(Vector2(Body.velocity.x,Body.velocity.z).length()<0.01,"gamepad disconnection leaves neutral Character intent")
    Axis.axis_value = 0
    Input.parse_input_event(Axis)
    Key(KEY_W,true)
    await create_timer(0.1).timeout
    Game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await create_timer(0.08).timeout
    Before = C.global_position
    await create_timer(0.08).timeout
    Check(C.global_position.distance_to(Before)<0.02,"native focus loss clears held Character input")
    Game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    await create_timer(0.08).timeout
    Check(C.global_position.distance_to(Before)<0.02,"focus restoration does not rearm held input")
    Key(KEY_W,false)
    Key(KEY_W,true)
    await create_timer(0.08).timeout
    paused = true
    await create_timer(0.08).timeout
    paused = false
    Before = C.global_position
    await create_timer(0.15).timeout
    Check(C.global_position.distance_to(Before)<0.02,"scene pause cancels semantic movement before resuming")
    Key(KEY_W,false)

    await Press(KEY_ESCAPE)
    Check(Game.get_meta("PlayerControllerMenu",false),"menu context transition")
    Before = C.global_position
    Key(KEY_W,true)
    await create_timer(0.15).timeout
    Key(KEY_W,false)
    Check(C.global_position.distance_to(Before)<0.02,"scripted menu has no native hardware fallback")
    Game.set_meta("PlayerControllerResumeRequested",true)
    await create_timer(0.08).timeout
    Check(not Game.get_meta("PlayerControllerMenu",true),"native UI resumes gameplay context")

    var Button := InputEventMouseButton.new()
    var BeforeYaw: float = Body.call("_gl_camera_yaw")
    Button.button_index = MOUSE_BUTTON_RIGHT
    Button.pressed = true
    Button.position = Vector2(700,300)
    Input.parse_input_event(Button)
    await create_timer(0.04).timeout
    var Motion := InputEventMouseMotion.new()
    Motion.position = Vector2(700,300)
    Motion.relative = Vector2(80,-20)
    Input.parse_input_event(Motion)
    await create_timer(0.05).timeout
    Button = Button.duplicate()
    Button.pressed = false
    Input.parse_input_event(Button)
    Check(absf(wrapf(float(Body.call("_gl_camera_yaw"))-BeforeYaw,-PI,PI)+0.176)<0.02,"semantic mouse rotates existing camera without native duplication")
    Before = C.global_position
    var Forward := -root.get_camera_3d().global_basis.z
    Forward.y = 0
    Forward = Forward.normalized()
    Key(KEY_W,true)
    await create_timer(0.2).timeout
    Key(KEY_W,false)
    await create_timer(0.2).timeout
    Check((C.global_position-Before).normalized().dot(Forward)>0.98,"actual camera-relative steering")
    Check(C.get_instance_id()==Identity and C.call("GetPhysicsBody").get_instance_id()==BodyIdentity and C.get_node("Animator").get_instance_id()==AnimatorIdentity,"mode changes preserve Model body and Animator identity")

    await Press(KEY_F9)
    Check(C.call("GetControllerMode")==0,"explicit Native restoration")
    Key(KEY_W,true)
    await create_timer(0.15).timeout
    await Press(KEY_F9)
    Before = C.global_position
    await create_timer(0.15).timeout
    Check(C.call("GetControllerMode")==1 and C.global_position.distance_to(Before)<0.02,"Native to Scripted clears held hardware movement")
    Key(KEY_W,false)
    await create_timer(0.04).timeout
    for Cycle in range(10):
        Game.set_meta("PlayerControllerReplaceRequested",true)
        await create_timer(0.04).timeout
    Check(C.get_instance_id()==Identity and C.call("GetPhysicsBody").get_instance_id()==BodyIdentity,"controller replacement never replaces the Character body")

    await LeaseChecks(C)
    Script("RetireQueuedController","""
local C=game.Players.LocalPlayer.Character
C.ControllerMode=Enum.CharacterControllerMode.Scripted
game.RunService.Stepped:Once(function()
    assert(C:Move(Vector3.new(1,0,0)))
    assert(C:Jump())
    game:SetAttribute('QueuedControllerRetired',true)
    script:Destroy()
end)
""",true)
    await create_timer(0.12).timeout
    Check(Game.get_meta("QueuedControllerRetired",false) and Body.is_on_floor() and Body.velocity.length()<0.01,"owner retirement cancels commands queued earlier in the same tick")
    Owner.free()
    Owner = await StartExample()
    var OldIdentity := C.get_instance_id()
    C.call("set_health",0.0)
    await create_timer(0.06).timeout
    Check(not C.call("IsControllerActive"),"death retires scripted input before lifecycle callbacks")
    Game.get_node("Players").call("load_local_character")
    await create_timer(0.3).timeout
    C = Character()
    Body = C.call("GetPhysicsBody")
    Check(C.get_instance_id()!=OldIdentity and C.call("GetControllerMode")==1,"respawn replaces native life and reattaches the Luau controller")
    Owner.free()
    await create_timer(0.05).timeout
    Key(KEY_W,true)
    Before = C.global_position
    await create_timer(0.15).timeout
    Key(KEY_W,false)
    Check(not C.call("IsControllerActive") and Vector2(Body.velocity.x,Body.velocity.z).length()<0.01 and Vector2(C.global_position.x-Before.x,C.global_position.z-Before.z).length()<0.02,"owner teardown leaves Scripted mode neutral without hardware fallback")
    if Graphical:
        await RenderingServer.frame_post_draw
        var Image := root.get_texture().get_image()
        Check(DisplayServer.get_name()!="headless" and Engine.get_frames_drawn()>0 and Image.save_png("res://player-controller.png")==OK,"actual rendered Player.Character evidence")

func LeaseChecks(C: Node3D) -> void:
    var A := await Probe("LeaseA","""
local C = game.Players.LocalPlayer.Character
C.ControllerMode = Enum.CharacterControllerMode.Scripted
shared.OldCharacterMove = C.Move
shared.OldCharacter = C
task.delay(0.2,function()
    assert(not C.ControllerActive)
    assert(not pcall(function() C.ControllerMode = Enum.CharacterControllerMode.Native end))
    game:SetAttribute('OldOwnerRejected',true)
end)
""")
    var B := await Probe("LeaseB","""
local C = game.Players.LocalPlayer.Character
C.ControllerMode = Enum.CharacterControllerMode.Scripted
assert(C.ControllerActive)
assert(not shared.OldCharacterMove(C,Vector3.new(1,0,0)))
assert(not C:Move(Vector3.new(2,0,0)))
assert(not C:Move(Vector3.new(0,1,0)))
assert(not C:Move(Vector3.new(0/0,0,0)))
assert(not pcall(function() C:Move({},true) end))
assert(not pcall(function() C:Move(Vector3.new(),'true') end))
assert(not pcall(function() C:RotateCamera(setmetatable({}, {__index=function() error('proxy executed') end})) end))
assert(not C:RotateCamera(Vector2.new(2,0)))
assert(not C:RotateCamera(Vector2.new(0/0,0)))
assert(not pcall(function() C.ControllerMode = 99 end))
assert(not pcall(function() C.ControllerMode = 'Scripted' end))
assert(not pcall(function() C.ControllerActive = true end))
assert(not pcall(function() C.ControllerInputEnabled = true end))
C:SetAttribute('ControllerMode',0)
assert(C.ControllerMode == Enum.CharacterControllerMode.Scripted)
local Clone = C:Clone()
assert(Clone.ControllerMode == Enum.CharacterControllerMode.Native)
assert(not pcall(function() Clone.ControllerMode = Enum.CharacterControllerMode.Scripted end))
Clone:Destroy()
assert(C:Move(Vector3.new(0.5,0,0)))
""")
    await create_timer(0.2).timeout
    Check(Game.get_meta("OldOwnerRejected",false),"old controller owner cannot stop its replacement")
    var Velocity: Vector3 = C.call("GetVelocity")
    Check(Vector2(Velocity.x,Velocity.z).length()<0.01,"one scripted Move sample does not persist across physics ticks")
    await Probe("ServerControllerRejected","""
local C = game.Players:GetPlayers()[1].Character
assert(not pcall(function() C.ControllerMode = Enum.CharacterControllerMode.Scripted end))
assert(not C:RotateCamera(Vector2.new(0.1,0)))
""",false)
    A.free()
    B.free()
    await create_timer(0.05).timeout
    Check(C.call("GetControllerMode")==1 and not C.call("IsControllerActive"),"controller retirement is dormant Scripted mode")

func Run() -> void:
    Automated = "--fixture" in OS.get_cmdline_user_args()
    Graphical = "--graphical" in OS.get_cmdline_user_args()
    if Graphical: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED],"load production extension")
    SetUp()
    await process_frame
    await process_frame
    if Mode=="Local":
        SetUpUI()
        if not Automated:
            await StartExample()
            return
        await LocalChecks()
    elif Role=="server":
        await ScriptedServer()
    else:
        await ScriptedClient()
    var Result := {"Result":"FAIL" if Failed else "PASS","Complete":true,"Mode":Mode,"Role":Role,"Index":Index,"Cases":Cases,"Graphical":Graphical}
    FileAccess.open("res://player-controller-"+Role+str(Index)+".json",FileAccess.WRITE).store_string(JSON.stringify(Result))
    print("[Character:Controller] ",Role," ","FAIL" if Failed else "PASS")
    Game.free()
    await process_frame
    quit(1 if Failed else 0)

func WaitGrant() -> int:
    var Deadline := Time.get_ticks_msec()+8000
    while Time.get_ticks_msec()<Deadline:
        var Peer: int = Network.call("get_peer_id")
        if Network.call("is_connected_net") and States().has(Peer) and int(States()[Peer].Epoch)>0: return Peer
        await process_frame
    Check(false,"native Character grant deadline")
    return 0

func SyncBaseline(Peer: int) -> void:
    # Reuse CharacterIntegration's production sync handshake. A peer-ready file
    # alone does not establish receipt of the final initial authority baseline.
    var Previous: int = States()[Peer].Epoch
    var Deadline := Time.get_ticks_msec()+8000
    while int(States()[Peer].Epoch)==Previous and Time.get_ticks_msec()<Deadline:
        Network.rpc_id(1,"_character_sync",Previous)
        await create_timer(0.05).timeout
    var Position: Vector3 = States()[Peer].Position
    var C := Character()
    Check(int(States()[Peer].Epoch)>Previous and Vector2(C.global_position.x-Position.x,C.global_position.z-Position.z).length()<0.02 and C.call("IsControllerActive"),"initial native authority baseline agrees before input")
    Mark("client"+str(Index)+".baseline",JSON.stringify({"Epoch":States()[Peer].Epoch,"X":C.global_position.x,"Y":C.global_position.y,"Z":C.global_position.z}))

func ScriptedServer() -> void:
    if Mode!="Listen": Character().free()
    Game.get_node("Players").call("set_respawn_time",0.05)
    Script("SpawnPolicy","game.Players.PlayerAdded:Connect(function(P) P.CharacterAdded:Connect(function(C) C.Position=Vector3.new(P.UserId*20,0,0) end) end)")
    Script("Start","assert(game.NetworkService:StartServer(game:GetAttribute('Port'),4))")
    while not Network.call("is_connected_net"): await process_frame
    if Mode=="Listen": await StartExample()
    Mark("ready")
    await Wait("client1.ready")
    await Wait("client2.ready")
    First = int(Read("client1.ready"))
    Second = int(Read("client2.ready"))
    Mark("baseline")
    await Wait("client1.baseline")
    await Wait("client2.baseline")
    var Baseline: Dictionary = JSON.parse_string(Read("client1.baseline"))
    var BaselinePosition := Vector3(Baseline.X,Baseline.Y,Baseline.Z)
    Check(int(States()[First].Epoch)==int(Baseline.Epoch) and Vector2(States()[First].Position.x-BaselinePosition.x,States()[First].Position.z-BaselinePosition.z).length()<0.02,"initial native authority baseline agrees before input")
    var Original: Vector3 = States()[First].Position
    var InitialEpoch: int = States()[First].Epoch
    var C: Node3D = Puppet(First)
    var Identity := C.get_instance_id()
    var BodyIdentity: int = C.call("GetPhysicsBody").get_instance_id()
    Mark("move")
    await Wait("moved")
    await create_timer(0.3).timeout
    var Sample: Dictionary = JSON.parse_string(Read("moved"))
    var Actual: Vector3 = States()[First].Position
    print("[Character:Controller] movement ",JSON.stringify({"Original":str(Original),"Authoritative":str(Actual),"Client":Sample,"Authority":States()[First]}))
    Check(int(States()[First].Epoch)==InitialEpoch,"movement trial retains its admitted native authority epoch")
    Check(Actual.distance_to(Original)>2 and Actual.distance_to(Vector3(Sample.X,Sample.Y,Sample.Z))<1,"scripted movement reaches authoritative ENet observer")
    Check(C.get_instance_id()==Identity and C.call("GetPhysicsBody").get_instance_id()==BodyIdentity and C.call("get_health")==100,"movement preserves native body and server-owned health")
    Check(C.call("GetControllerMode")==0,"client controller selection does not replicate authority configuration")
    Mark("authority")
    await Wait("authority.checked1")
    await Wait("authority.checked2")
    Check(C.call("get_health")==100 and C.call("get_walk_speed")==16,"scripted mode cannot grant health or speed authority")
    # Use the established trusted correction path; do not send fabricated client poses.
    C.global_position += Vector3(2,0,0)
    await create_timer(0.25).timeout
    Check(int(States()[First].Epoch)>InitialEpoch,"server correction advances existing Character authority epoch")
    Mark("corrected")
    await Wait("correction.checked")
    C.call("set_health",0.0)
    Mark("respawn")
    await Wait("respawn.checked")
    C = Puppet(First)
    Check(is_instance_valid(C) and C.get_instance_id()!=Identity and C.call("get_health")==100,"multiplayer respawn replaces one native life")
    Mark("disconnect")
    await Wait("disconnected")
    var Deadline := Time.get_ticks_msec()+5000
    while States().has(Second) and Time.get_ticks_msec()<Deadline: await process_frame
    Check(not States().has(Second),"disconnect retires authoritative peer Character state")
    Mark("reconnect")
    await Wait("reconnected")
    var NewPeer := int(Read("reconnected"))
    Check(NewPeer!=Second and States().has(NewPeer),"reconnect obtains a fresh native peer and grant")
    Mark("finish")
    await Wait("done1")
    await Wait("done2")
    Check(Network.call("is_connected_net"),"observer remains connected through other peer replacement")

func ScriptedClient() -> void:
    await Wait("ready")
    Script("Connect","assert(game.NetworkService:Connect('127.0.0.1',game:GetAttribute('Port')))",true)
    var Peer := await WaitGrant()
    if not Peer: return
    var Owner := await StartExample()
    var C := Character()
    var Body: CharacterBody3D = C.call("GetPhysicsBody")
    var Identity := C.get_instance_id()
    var BodyIdentity := Body.get_instance_id()
    Mark("client"+str(Index)+".ready",str(Peer))
    await Wait("baseline")
    await SyncBaseline(Peer)
    await Wait("move")
    if Index==1:
        var Observations: Array[Dictionary] = []
        Key(KEY_W,true)
        Key(KEY_SHIFT,true)
        for Tick in range(18):
            await physics_frame
            Observations.append({"Tick":Tick,"Position":str(C.global_position),"Velocity":str(Body.velocity),"Active":C.call("IsControllerActive"),"Running":Game.get_meta("PlayerControllerRunning",false),"Player":Game.get_node("Players").call("get_local_player").get_instance_id(),"Epoch":States()[Peer].Epoch})
        print("[Character:Controller] samples ",JSON.stringify(Observations))
        Key(KEY_W,false)
        Key(KEY_SHIFT,false)
        await create_timer(0.2).timeout
        await Press(KEY_SPACE)
        Check(Body.velocity.y>0,"real ENet client scripted grounded jump")
        await create_timer(1.0).timeout
        Check(Body.is_on_floor(),"real ENet client scripted landing")
        var Position := C.global_position
        Mark("moved",JSON.stringify({"X":Position.x,"Y":Position.y,"Z":Position.z}))
    await Wait("authority")
    await Probe("OtherCharacterRejected","""
local Mine=game.Players.LocalPlayer.Character
for _, P in ipairs(game.Players:GetPlayers()) do
    if P~=game.Players.LocalPlayer and P.Character then
        local Other=P.Character
        assert(not pcall(function() Other.ControllerMode=Enum.CharacterControllerMode.Scripted end))
        Other:Move(Vector3.new(1,0,0))
        Other:Jump()
    end
end
Mine.Health=1
Mine.WalkSpeed=1000
assert(Mine.Health==100 and Mine.WalkSpeed==16)
""")
    Check(C.get_instance_id()==Identity and Body.get_instance_id()==BodyIdentity,"network controller preserves owned Character identity")
    Mark("authority.checked"+str(Index))
    await Wait("corrected")
    if Index==1:
        Check(C.call("IsControllerActive") and C.get_instance_id()==Identity,"trusted correction preserves same local scripted controller")
        Key(KEY_D,true)
        await create_timer(0.15).timeout
        Key(KEY_D,false)
        Mark("correction.checked")
    await Wait("respawn")
    if Index==1:
        var Deadline := Time.get_ticks_msec()+6000
        while (not is_instance_valid(Character()) or Character().get_instance_id()==Identity or not Character().call("IsControllerActive")) and Time.get_ticks_msec()<Deadline: await process_frame
        C = Character()
        Check(is_instance_valid(C) and C.get_instance_id()!=Identity and C.call("IsControllerActive"),"CharacterAdded reattaches scripted controller after network respawn")
        await create_timer(0.6).timeout
        Mark("respawn.checked")
    await Wait("disconnect")
    if Index==2:
        Key(KEY_W,true)
        await create_timer(0.1).timeout
        Script("Disconnect","game.NetworkService:Disconnect()",true)
        await create_timer(0.2).timeout
        Check(not C.call("IsControllerActive") and Vector2(Body.velocity.x,Body.velocity.z).length()<0.01,"disconnect neutralizes held intent without Native fallback")
        Key(KEY_W,false)
        Owner.free()
        Mark("disconnected")
        await Wait("reconnect")
        Script("Reconnect","assert(game.NetworkService:Connect('127.0.0.1',game:GetAttribute('Port')))",true)
        Peer = await WaitGrant()
        if not Peer: return
        Owner = await StartExample()
        Check(Character().call("IsControllerActive"),"fresh controller attaches to reconnected native transport")
        Mark("reconnected",str(Peer))
    await Wait("finish")
    Mark("done"+str(Index))
    # Keep peers alive until both final barriers; server owns session shutdown.
    await Wait("done1")
    await Wait("done2")
