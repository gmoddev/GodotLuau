extends SceneTree

# Uses the production factories, controller, inputs, physics and ENet transport.
# Headless execution exercises assertions only; Graphical requires pixel readback.
var Game: Node
var World: Node3D
var Players: Node
var Network: Node
var Case := "r6"
var Role := "single"
var Index := "0"
var Port := 0
var Graphical := false
var Failed := false
var Checks := 0
var Captures := []
var States := {}
var Assertions := []

func Check(Value: bool, Label: String) -> void:
    Checks += 1
    Assertions.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Character:Presentation] FAIL ", Label)

func Create(Type: String, Name: String, Parent: Node = null) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    (Game if Parent == null else Parent).add_child(Result)
    return Result

func Script(Name: String, Source: String) -> void:
    var Actor: Node = ClassDB.instantiate("ServerScript" if Role != "client" else "LocalScript")
    Actor.name = Name
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = Source
    Actor.call("set_codigo_luau", Code)
    Game.add_child(Actor)

func Ticks(Count: int) -> void:
    for Tick in range(Count): await physics_frame

func Key(Code: Key, Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code
    Event.pressed = Pressed
    Input.parse_input_event(Event)
    Input.flush_buffered_events()

func Axis(Code: JoyAxis, Value: float) -> void:
    var Event := InputEventJoypadMotion.new()
    Event.device = 0
    Event.axis = Code
    Event.axis_value = Value
    Input.parse_input_event(Event)
    Input.flush_buffered_events()

func Wheel(Code: MouseButton, Count: int) -> void:
    for Tick in range(Count):
        var Event := InputEventMouseButton.new()
        Event.button_index = Code
        Event.pressed = true
        Input.parse_input_event(Event)
    Input.flush_buffered_events()

func Synchronized(Character: Node3D, Label: String) -> void:
    Character.force_update_transform()
    var Body: Node3D = Character.call("GetPhysicsBody")
    Check(Body.global_transform.is_equal_approx(Character.global_transform), Label + " body follows Model")
    Check(Character.get_node("HumanoidRootPart").global_transform.is_equal_approx(Character.global_transform), Label + " root proxy follows Model")
    States[Label] = {"Character": str(Character.global_transform), "Body": str(Body.global_transform), "RootPart": str(Character.get_node("HumanoidRootPart").global_transform)}

func Capture(Label: String) -> void:
    var Entry := {"Label": Label, "PhysicsSeconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), "ProcessSeconds": Performance.get_monitor(Performance.TIME_PROCESS), "DrawCalls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "DrawnFrames": Engine.get_frames_drawn()}
    if Graphical:
        await RenderingServer.frame_post_draw
        var Image := root.get_texture().get_image()
        Check(not Image.is_empty(), "GPU image " + Label)
        var Colors := {}
        for Y in range(0, Image.get_height(), 20):
            for X in range(0, Image.get_width(), 20): Colors[Image.get_pixel(X, Y).to_rgba32()] = true
        Check(Colors.size() > 8, "rendered scene has spatial detail " + Label)
        var File := "presentation-" + Case + "-" + Role + Index + "-" + Label + ".png"
        Check(Image.save_png("res://" + File) == OK, "write screenshot " + Label)
        Entry["Screenshot"] = File
        Entry["SampledColors"] = Colors.size()
    var Camera := root.get_camera_3d()
    if Camera != null: Entry["Camera"] = str(Camera.global_transform)
    Captures.append(Entry)

func FloorAndLighting() -> void:
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(1000, 1, 1000)
    Shape.shape = Box
    Floor.position.y = -1.5
    Floor.add_child(Shape)
    var Mesh := MeshInstance3D.new()
    var Geometry := BoxMesh.new()
    Geometry.size = Box.size
    var Material := StandardMaterial3D.new()
    Material.albedo_color = Color(0.22, 0.29, 0.38)
    Geometry.material = Material
    Mesh.mesh = Geometry
    Floor.add_child(Mesh)
    Game.add_child(Floor)
    var Light := DirectionalLight3D.new()
    Light.rotation_degrees = Vector3(-45, -35, 0)
    Game.add_child(Light)
    var EnvironmentNode := WorldEnvironment.new()
    var Settings := Environment.new()
    Settings.background_mode = Environment.BG_COLOR
    Settings.background_color = Color(0.25, 0.45, 0.65)
    Settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    Settings.ambient_light_color = Color.WHITE
    Settings.ambient_light_energy = 0.6
    EnvironmentNode.environment = Settings
    Game.add_child(EnvironmentNode)
    # Visible reference columns make movement and real image readback observable.
    for Position in [Vector3(-7, 1, -8), Vector3(7, 1, -8), Vector3(0, 1, -20)]:
        var Marker := MeshInstance3D.new()
        var Cylinder := CylinderMesh.new()
        Cylinder.height = 4
        Marker.mesh = Cylinder
        Marker.position = Position
        Game.add_child(Marker)

func CustomRig() -> void:
    var Holder := Create("StarterPlayer", "StarterPlayer")
    var Template := Node3D.new()
    Template.name = "StarterCharacter"
    for Pair in [["Torso", Vector3.ZERO, Vector3(1.4, 1.8, 0.7)], ["Head", Vector3(0, 1.5, 0), Vector3.ONE], ["Left Arm", Vector3(1.2, 0.5, 0), Vector3(0.6, 1.6, 0.6)], ["Right Arm", Vector3(-1.2, 0.5, 0), Vector3(0.6, 1.6, 0.6)], ["Left Leg", Vector3(0.4, -1.2, 0), Vector3(0.6, 1.2, 0.6)], ["Right Leg", Vector3(-0.4, -1.2, 0), Vector3(0.6, 1.2, 0.6)]]:
        var Pivot := Node3D.new()
        Pivot.name = Pair[0]
        Pivot.position = Pair[1]
        var Mesh := MeshInstance3D.new()
        var Box := BoxMesh.new()
        Box.size = Pair[2]
        var Material := StandardMaterial3D.new()
        Material.albedo_color = Color(0.7, 0.3, 0.85)
        Box.material = Material
        Mesh.mesh = Box
        Pivot.add_child(Mesh)
        Template.add_child(Pivot)
    var Animator: Node = ClassDB.instantiate("GLR6Animator")
    Animator.name = "R6Animator"
    Template.add_child(Animator)
    Holder.add_child(Template)

func Single() -> void:
    var Character: Node3D = World.get_node("LocalPlayer")
    Check(Character.is_class("RBXCharacter") and Character.is_class("RBXModel"), "real Model inheritance")
    Check(not Character.has_node("Humanoid"), "no separate 3D Humanoid")
    Check(Character.has_node("Torso") if Case == "r6" else Character.has_node("Character/Torso"), "requested rig did not fall back")
    await Ticks(90)
    var Body: CharacterBody3D = Character.call("GetPhysicsBody")
    var Camera: Camera3D = Body.get_node("CameraPivotH/CameraPivotV/SpringArm/Camera3D")
    var Pivot: Node3D = Body.get_node("CameraPivotH")
    var Arm: SpringArm3D = Body.get_node("CameraPivotH/CameraPivotV/SpringArm")
    Check(Camera == root.get_camera_3d() and Character.call("IsGrounded"), "local camera and physical grounding")
    var Stable := Character.global_position
    Body.global_position += Vector3(3, 0, 0)
    await Ticks(2)
    Check(absf(Character.global_position.x-Stable.x) < 0.1, "unchanged root repairs independently changed live body")
    Synchronized(Character, "repaired body")
    await Capture("third-person")
    var Original := Character.global_position
    var Rig: Node = Character if Case == "r6" else Character.get_node("Character")
    var Limb: Node3D = Rig.get_node("Left Leg")
    var Before := Limb.rotation
    Key(KEY_W, true)
    await Ticks(35)
    var Walk := Vector2(Body.velocity.x, Body.velocity.z).length()
    Check(Walk > 15.9 and Character.global_position.distance_to(Original) > 5, "keyboard walking actual physics")
    Check(not Before.is_equal_approx(Limb.rotation), "walking animation progresses")
    await Capture("walking")
    Key(KEY_SHIFT, true)
    await Ticks(25)
    Check(Vector2(Body.velocity.x, Body.velocity.z).length() > 23.9, "keyboard sprint")
    Key(KEY_SHIFT, false)
    Key(KEY_W, false)
    await Ticks(20)
    var Mouse := InputEventMouseButton.new()
    # The dummy display cannot capture a mouse. Exercise the supported native
    # first-person mouse path there; rendered runs retain third-person RMB drag.
    if not Graphical: Character.call("set_lock_first_person", true)
    Mouse.button_index = MOUSE_BUTTON_RIGHT
    Mouse.pressed = true
    Input.parse_input_event(Mouse)
    var Motion := InputEventMouseMotion.new()
    Motion.relative = Vector2(120, 20)
    Input.parse_input_event(Motion)
    Input.flush_buffered_events()
    await Ticks(2)
    Check(absf(Pivot.rotation.y) > 0.1, "mouse rotates production camera")
    Mouse.pressed = false
    Input.parse_input_event(Mouse)
    Input.flush_buffered_events()
    if not Graphical: Character.call("set_lock_first_person", false)
    Axis(JOY_AXIS_RIGHT_X, 1)
    var PriorYaw := Pivot.rotation.y
    await Ticks(20)
    Check(absf(Pivot.rotation.y - PriorYaw) > 0.1, "controller camera rotation")
    Axis(JOY_AXIS_RIGHT_X, 0)
    Pivot.rotation = Vector3.ZERO
    Axis(JOY_AXIS_LEFT_X, 1)
    await Ticks(30)
    Check(Body.velocity.x > 15.9, "controller movement")
    Check(absf(wrapf(Body.rotation.y + PI/2, -PI, PI)) < 0.15, "Character rotates toward actual movement")
    Synchronized(Character, "walking controller")
    Axis(JOY_AXIS_LEFT_X, 0)
    await Ticks(20)
    var PadJump := InputEventJoypadButton.new()
    PadJump.device = 0
    PadJump.button_index = JOY_BUTTON_A
    PadJump.pressed = true
    Input.parse_input_event(PadJump)
    Input.flush_buffered_events()
    await Ticks(3)
    Check(Body.velocity.y > 18, "controller jump reaches real physics")
    PadJump.pressed = false
    Input.parse_input_event(PadJump)
    Input.flush_buffered_events()
    await Ticks(100)
    Character.global_transform = Transform3D(Basis(), Vector3(0, 0.1, 0))
    Body.velocity = Vector3.ZERO
    await Ticks(10)
    Key(KEY_SPACE, true)
    await Ticks(2)
    Key(KEY_SPACE, false)
    Check(Body.velocity.y > 18 and Character.call("get_state") == 2, "jumping state and velocity")
    await Capture("jumping")
    var SawFall := false
    var SawLand := false
    for Tick in range(100):
        await physics_frame
        SawFall = SawFall or Character.call("get_state") == 8
        SawLand = SawLand or Character.call("get_state") == 3
    Check(SawFall and SawLand and Character.call("IsGrounded"), "falling and landing state transitions")
    await Capture("landed")
    Character.call("set_lock_first_person", true)
    await Ticks(45)
    var Meshes := Character.find_children("*", "MeshInstance3D", true, false)
    var Faded := 0
    for Mesh in Meshes:
        if Mesh.material_override is ShaderMaterial and float(Mesh.material_override.get_shader_parameter("dissolve")) > 0.95: Faded += 1
    Check(Faded >= 6 and Arm.spring_length < 0.6, "first-person rig transparency and zoom")
    Synchronized(Character, "first-person")
    Check(absf(Body.rotation.y - Pivot.rotation.y) < 0.01, "first-person Character faces camera")
    await Capture("first-person")
    Character.call("set_lock_first_person", false)
    Wheel(MOUSE_BUTTON_WHEEL_DOWN, 25)
    await Ticks(45)
    Check(Arm.spring_length > 6, "wheel returns to third-person zoom")
    var Restored := true
    for Mesh in Meshes: Restored = Restored and Mesh.material_override == null
    Check(Restored, "third-person restores rig materials")
    # Wall intersects the actual boom, without intersecting the movement capsule.
    Pivot.rotation = Vector3.ZERO
    Body.get_node("CameraPivotH/CameraPivotV").rotation = Vector3.ZERO
    var Wall := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(8, 8, 1)
    Shape.shape = Box
    Wall.add_child(Shape)
    Wall.position = Character.global_position + Vector3(0, 1.5, 3)
    Game.add_child(Wall)
    await Ticks(10)
    Check(Arm.get_hit_length() < Arm.spring_length - 1, "camera boom collides with wall")
    Check(Camera.global_position.z < Wall.global_position.z, "camera stays in front of wall")
    await Capture("camera-collision")
    Wall.free()
    var Parent := Node3D.new()
    World.add_child(Parent)
    Character.reparent(Parent, true)
    Parent.transform = Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 1.2), Vector3(5, 0, 2))
    Synchronized(Character, "parent transform")
    Character.reparent(World, true)
    Parent.free()
    Script("Pivot", "local C=game:GetService('Players'):GetPlayers()[1].Character; C:PivotTo(CFrame.new(0,2,0)); game:SetAttribute('PivotDone',true)")
    await Ticks(3)
    Check(Game.get_meta("PivotDone", false), "public PivotTo executes")
    Synchronized(Character, "teleport")
    await Capture("teleported")
    var Probe := MeshInstance3D.new()
    Probe.name = "AnimationProbe"
    Probe.mesh = BoxMesh.new()
    Probe.position.y = 3
    Character.add_child(Probe)
    var Clip := Animation.new()
    Clip.length = 0.6
    var Track := Clip.add_track(Animation.TYPE_POSITION_3D)
    Clip.track_set_path(Track, NodePath("AnimationProbe"))
    Clip.track_insert_key(Track, 0, Vector3(0, 3, 0))
    Clip.track_insert_key(Track, 0.6, Vector3(2, 3, 0))
    ResourceSaver.save(Clip, "res://PresentationClip.tres")
    var Asset := Create("AnimationObject", "PresentationClip")
    Asset.call("set_animation_id", "res://PresentationClip.tres")
    Asset.call("set_anim_name", "PresentationClip")
    Script("Playback", "local T=game.Workspace.LocalPlayer.Animator:LoadAnimation(game.PresentationClip); T.Ended:Connect(function() game:SetAttribute('ClipEnded',true) end); T:Play(); game:SetAttribute('ClipStarted',T.IsPlaying)")
    # AnimationPlayer advances on process frames, not physics catch-up ticks.
    var AnimationDeadline := Time.get_ticks_msec() + 3000
    while Probe.position.x < 0.5 and Time.get_ticks_msec() < AnimationDeadline: await process_frame
    Check(Game.get_meta("ClipStarted", false) and Probe.position.x >= 0.5, "AnimationPlayer advances visual track")
    await Capture("animation")
    while not Game.get_meta("ClipEnded", false) and Time.get_ticks_msec() < AnimationDeadline: await process_frame
    Check(Game.get_meta("ClipEnded", false), "animation completion callback")
    Players.call("set_respawn_time", 0.2)
    var Identity := Character.get_instance_id()
    Character.call("take_damage", 1000)
    Check(Character.call("get_health") == 0 and Character.call("get_state") == 7, "death latched")
    await Ticks(35)
    Character = World.get_node("LocalPlayer")
    Check(Character.get_instance_id() != Identity and Character.call("get_health") > 0, "automatic respawn replaces rendered life")
    await Capture("respawn")
    Players.call("set_character_auto_loads", false)
    Identity = Character.get_instance_id()
    Character.call("take_damage", 1000)
    await Ticks(30)
    Check(World.get_node("LocalPlayer").get_instance_id() == Identity, "manual loading suppresses auto respawn")
    Players.call("load_local_character")
    await Ticks(3)
    Check(World.get_node("LocalPlayer").get_instance_id() != Identity, "manual LoadCharacter creates new life")
    # Supported touch simulation, without claiming physical-device ergonomics.
    FileAccess.open("res://.gl_mp_session", FileAccess.WRITE).store_string("1|Mobile|0")
    Players.call("load_local_character")
    await Ticks(75)
    Character = World.get_node("LocalPlayer")
    Body = Character.call("GetPhysicsBody")
    Check(Body.has_node("TouchControls/JumpButton"), "mobile simulation creates native controls")
    root.size = Vector2i(960, 540)
    await process_frame
    Input.set_emulate_mouse_from_touch(false)
    var Touch := InputEventScreenTouch.new()
    Touch.index = 0
    Touch.position = Vector2(50, 100)
    Touch.pressed = true
    Input.parse_input_event(Touch)
    Input.flush_buffered_events()
    var Drag := InputEventScreenDrag.new()
    Drag.index = 0
    Drag.position = Vector2(160, 100)
    Drag.relative = Vector2(110, 0)
    Input.parse_input_event(Drag)
    Input.flush_buffered_events()
    await Ticks(30)
    print("[Character:Presentation] Touch diagnostic viewport=", root.get_visible_rect(), " velocity=", Body.velocity, " local=", Character.call("IsLocalControl"))
    Check(Vector2(Body.velocity.x, Body.velocity.z).length() > 15.9, "touch simulation moves Character")
    await Capture("mobile-simulation")
    Touch.pressed = false
    Input.parse_input_event(Touch)
    Input.flush_buffered_events()
    await Ticks(20)
    var JumpButton: Button = Body.get_node("TouchControls/JumpButton")
    var Click := InputEventMouseButton.new()
    Click.button_index = MOUSE_BUTTON_LEFT
    Click.position = JumpButton.get_global_rect().get_center()
    Click.global_position = Click.position
    Click.pressed = true
    Input.parse_input_event(Click)
    Input.flush_buffered_events()
    var JumpDeadline := Time.get_ticks_msec() + 1000
    while Body.velocity.y <= 0 and Time.get_ticks_msec() < JumpDeadline: await process_frame
    print("[Character:Presentation] Mobile jump diagnostic rect=", JumpButton.get_global_rect(), " pressed=", JumpButton.button_pressed, " velocity=", Body.velocity)
    Check(Body.velocity.y > 18, "mobile simulation GUI jump reaches real physics")
    Click.pressed = false
    Input.parse_input_event(Click)
    Input.flush_buffered_events()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.gl_mp_session"))

func Mark(Name: String) -> void:
    FileAccess.open("res://presentation-" + Name, FileAccess.WRITE).store_string("ready")

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 15000
    while not FileAccess.file_exists("res://presentation-" + Name):
        if Time.get_ticks_msec() > Deadline:
            Check(false, "bounded network barrier " + Name)
            return
        await process_frame

func Multiplayer() -> void:
    Game.set_meta("Port", Port)
    if Role == "server":
        var StartupDeadline := Time.get_ticks_msec() + 15000
        if Case == "dedicated":
            # --glserver owns startup and removes the observer's local Character.
            while not Network.call("is_server") and Time.get_ticks_msec() < StartupDeadline: await process_frame
            Check(Network.call("is_server"), "native dedicated startup")
        else:
            Script("Start", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'),4)); game:SetAttribute('Listening',true)")
            while not Game.has_meta("Listening") and Time.get_ticks_msec() < StartupDeadline: await process_frame
            Check(Game.has_meta("Listening"), "native listen startup")
        Mark("ready")
    else:
        await Wait("ready")
        Script("Connect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1',game:GetAttribute('Port')))")
    var Deadline := Time.get_ticks_msec() + 15000
    var Expected := 2 if Case == "listen" or Role == "server" else 1
    while World.find_children("RemotePlayer_*", "", true, false).size() < Expected and Time.get_ticks_msec() < Deadline: await process_frame
    Check(World.find_children("RemotePlayer_*", "", true, false).size() >= Expected, "real ENet remote Characters created")
    var Character: Node3D = World.get_node_or_null("LocalPlayer")
    if Case == "dedicated" and Role == "server":
        Check(Character == null, "dedicated observer has no local Character")
        var Remotes := World.find_children("RemotePlayer_*", "", true, false)
        if Remotes.is_empty(): return
        Character = Remotes[0]
        var Spectator := Camera3D.new()
        Game.add_child(Spectator)
        Spectator.position = Character.global_position + Vector3(8, 6, 15)
        Spectator.look_at(Character.global_position)
        Spectator.make_current()
    else:
        Check(Character != null, "participant owns a local Character")
        if Character == null: return
        Character.call("set_npc_move_dir", Vector3.RIGHT)
    await Ticks(90)
    var RemoteLimbs := {}
    for Remote in World.find_children("RemotePlayer_*", "", true, false):
        Check(Remote.is_class("RBXCharacter") and Remote.is_class("RBXModel"), "remote has real Model identity")
        Check(Remote.has_node("Torso") and Remote.has_node("R6Animator"), "remote uses actual R6 rig")
        if Remote.has_node("Left Leg"): RemoteLimbs[Remote.get_instance_id()] = Remote.get_node("Left Leg").rotation
        Synchronized(Remote, "replicated puppet " + Remote.name)
        Check(not Remote.call("GetPhysicsBody").has_node("CameraPivotH"), "puppet has no local camera/input")
    var Start := Character.global_position
    await Ticks(60)
    Check(Character.global_position.distance_to(Start) > 10, "owner or replicated Character moves during real transport")
    for Identity in RemoteLimbs:
        var Remote: Node3D = instance_from_id(Identity)
        Check(is_instance_valid(Remote) and not Remote.get_node("Left Leg").rotation.is_equal_approx(RemoteLimbs[Identity]), "remote procedural animation progresses")
    await Capture("owner-camera")
    # An explicit fixture spectator view captures every rendered participant.
    var OwnerCamera := root.get_camera_3d()
    var Observer := Camera3D.new()
    Game.add_child(Observer)
    Observer.global_position = Character.global_position + Vector3(12, 10, 22)
    Observer.look_at(Character.global_position)
    Observer.make_current()
    await Ticks(3)
    await Capture("multiplayer-overview")
    Observer.free()
    if is_instance_valid(OwnerCamera): OwnerCamera.make_current()
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

func _initialize() -> void:
    root.size = Vector2i(960, 540)
    var Args := OS.get_cmdline_user_args()
    Graphical = "--graphical" in Args
    for Position in range(Args.size()-1):
        if Args[Position] == "--case": Case = Args[Position+1]
        if Args[Position] == "--role": Role = Args[Position+1]
        if Args[Position] == "--index": Index = Args[Position+1]
        if Args[Position] == "--port": Port = int(Args[Position+1])
    if Graphical: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
    call_deferred("Run")

func Run() -> void:
    Check(not Graphical or DisplayServer.get_name() != "headless", "real display required for graphical evidence")
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension loads")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Players = Create("Players", "Players")
    Create("RunService", "RunService")
    Network = Create("NetworkService", "NetworkService")
    Create("Node", "SettingsMenu")
    if Case == "custom": CustomRig()
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    FloorAndLighting()
    if Role == "single": await Single()
    else: await Multiplayer()
    var Evidence := {"Case": Case, "Role": Role+Index, "Graphical": Graphical, "Checks": Checks, "Result": "FAIL" if Failed else "PASS", "Display": DisplayServer.get_name(), "Adapter": RenderingServer.get_video_adapter_name(), "Renderer": RenderingServer.get_current_rendering_method(), "Driver": RenderingServer.get_current_rendering_driver_name(), "Captures": Captures, "Transforms": States, "Assertions": Assertions}
    FileAccess.open("res://evidence-" + Role + Index + ".json", FileAccess.WRITE).store_string(JSON.stringify(Evidence))
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    Game.free()
    await process_frame
    print("[Character:Presentation] ", "FAIL" if Failed else "PASS", " ", Case, " ", Role, Index, " checks=", Checks, " graphical=", Graphical)
    quit(1 if Failed else 0)
