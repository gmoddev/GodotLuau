extends SceneTree

var Game: Node
var Chat: LineEdit
var MenuPanel: PanelContainer
var Resume: Button
var Failed := false
var Checks := 0
var Graphical := false

func Check(Value: bool, Description: String) -> void:
    Checks += 1
    if not Value:
        Failed = true
        print("[Input:Demo] FAIL ", Description)

func Box(Parent: Node3D, Position: Vector3, Size: Vector3, ColorValue: Color) -> void:
    var Body := StaticBody3D.new()
    Body.position = Position
    var Collision := CollisionShape3D.new()
    var Shape := BoxShape3D.new()
    Shape.size = Size
    Collision.shape = Shape
    Body.add_child(Collision)
    var Mesh := MeshInstance3D.new()
    var Cube := BoxMesh.new()
    Cube.size = Size
    var Material := StandardMaterial3D.new()
    Material.albedo_color = ColorValue
    Cube.material = Material
    Mesh.mesh = Cube
    Body.add_child(Mesh)
    Parent.add_child(Body)

func Key(Code: Key, Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code
    if Code >= KEY_A and Code <= KEY_Z: Event.unicode = int(Code)+32
    Event.pressed = Pressed
    root.push_input(Event,true)

func Press(Code: Key) -> void:
    Key(Code,true)
    Key(Code,false)
    await create_timer(0.05).timeout

func _initialize() -> void:
    call_deferred("Run")

func _process(_Delta: float) -> bool:
    if is_instance_valid(Game) and is_instance_valid(MenuPanel):
        MenuPanel.visible = Game.get_meta("MenuOpen",false)
    return false

func Run() -> void:
    var Fixture := "--fixture" in OS.get_cmdline_user_args()
    Graphical = "--graphical" in OS.get_cmdline_user_args()
    if Graphical: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    Game.set_meta("AutomatedFixture",Fixture)
    root.add_child(Game)
    current_scene = Game
    var World := Node3D.new()
    World.name = "Workspace"
    Game.add_child(World)
    Box(World,Vector3(0,-0.5,0),Vector3(40,1,40),Color(0.22,0.3,0.36))
    Box(World,Vector3(4,1,-5),Vector3(2,2,2),Color(0.85,0.4,0.18))
    Box(World,Vector3(-4,1,-5),Vector3(2,2,2),Color(0.1,0.6,0.8))
    Box(World,Vector3(0,1,-10),Vector3(12,2,0.5),Color(0.5,0.65,0.25))
    var Sun := DirectionalLight3D.new()
    Sun.rotation_degrees = Vector3(-50,-30,0)
    World.add_child(Sun)
    var EnvironmentNode := WorldEnvironment.new()
    var Sky := Environment.new()
    Sky.background_mode = Environment.BG_COLOR
    Sky.background_color = Color(0.12,0.18,0.25)
    Sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    Sky.ambient_light_color = Color.WHITE
    Sky.ambient_light_energy = 0.5
    EnvironmentNode.environment = Sky
    World.add_child(EnvironmentNode)
    var Previous := Camera3D.new()
    Previous.position = Vector3(0,3,9)
    World.add_child(Previous)
    Previous.look_at(Vector3(0,1,0))
    Previous.make_current()
    var Clock: Node = ClassDB.instantiate("RunService")
    Clock.name = "RunService"
    Game.add_child(Clock)
    var Layer := CanvasLayer.new()
    Game.add_child(Layer)
    var Help := Label.new()
    Help.position = Vector2(16,12)
    Help.text = "Luau semantic controller\nWASD / left stick • mouse / right stick • Shift / L3 sprint\nSpace / A jump • Esc / Start menu • F6 remap jump • F8 stop/restart"
    Layer.add_child(Help)
    Chat = LineEdit.new()
    Chat.position = Vector2(16,470)
    Chat.size = Vector2(520,36)
    Chat.placeholder_text = "Click here to type: GUI consumes movement keys"
    Layer.add_child(Chat)
    MenuPanel = PanelContainer.new()
    MenuPanel.position = Vector2(16,110)
    MenuPanel.size = Vector2(300,220)
    Layer.add_child(MenuPanel)
    var Stack := VBoxContainer.new()
    MenuPanel.add_child(Stack)
    var Heading := Label.new()
    Heading.text = "Menu — gameplay context disabled"
    Stack.add_child(Heading)
    Resume = Button.new()
    Resume.text = "Resume"
    Resume.pressed.connect(func() -> void: Game.set_meta("ResumeRequested",true))
    Stack.add_child(Resume)
    var Remap := Button.new()
    Remap.text = "Remap jump: Space ↔ E"
    Remap.pressed.connect(func() -> void: Game.set_meta("RemapRequested",true))
    Stack.add_child(Remap)
    var Restart := Button.new()
    Restart.text = "Stop / restart controller"
    Restart.pressed.connect(func() -> void: Game.set_meta("RestartRequested",true))
    Stack.add_child(Restart)
    MenuPanel.hide()
    var Controller: Node = ClassDB.instantiate("LocalScript")
    var Source: Script = ClassDB.instantiate("LuauScript")
    Source.source_code = FileAccess.get_file_as_string("res://Controller.luau")
    Check(not Source.source_code.is_empty(), "actual example source loaded")
    Controller.name = "SemanticController"
    Controller.call("set_codigo_luau",Source)
    Game.add_child(Controller)
    await create_timer(0.65).timeout
    Check(Game.get_meta("ControllerRunning",false), "actual Luau example starts")
    if not Fixture:
        print("[Input:Demo] Interactive controller ready")
        return
    var Body := World.get_node_or_null("LuauController") as CharacterBody3D
    if Body == null:
        quit(1)
        return
    Check(Body.is_on_floor(), "example ground collision")
    var Before := Body.position
    Key(KEY_W,true)
    await create_timer(0.18).timeout
    Key(KEY_W,false)
    await create_timer(0.04).timeout
    var Walking := Before.z-Body.position.z
    Check(Walking>0.65 and Walking<1.3, "keyboard semantic movement")
    Before = Body.position
    Key(KEY_SHIFT,true)
    Key(KEY_W,true)
    await create_timer(0.18).timeout
    Key(KEY_W,false)
    Key(KEY_SHIFT,false)
    await create_timer(0.04).timeout
    Check(Before.z-Body.position.z>Walking*1.3, "semantic sprint")
    await Press(KEY_SPACE)
    Check(Body.position.y>1.0 and not Body.is_on_floor(), "semantic jump")
    await create_timer(0.5).timeout
    Check(Body.is_on_floor(), "example lands")
    Chat.grab_focus()
    Before = Body.position
    Key(KEY_W,true)
    await create_timer(0.12).timeout
    Key(KEY_W,false)
    await create_timer(0.04).timeout
    Check(Body.position.distance_to(Before)<0.02 and not Chat.text.is_empty(), "native GUI typing consumes movement input")
    Chat.release_focus()
    await Press(KEY_ESCAPE)
    Check(Game.get_meta("MenuOpen",false), "menu context transition")
    Before = Body.position
    Key(KEY_W,true)
    await create_timer(0.1).timeout
    Key(KEY_W,false)
    Check(Body.position.distance_to(Before)<0.02, "menu disables gameplay")
    Resume.pressed.emit()
    await create_timer(0.05).timeout
    Check(not Game.get_meta("MenuOpen",true), "native UI resume command")
    await Press(KEY_F6)
    Check(Game.get_meta("JumpBinding","")=="E", "runtime remap")
    await Press(KEY_SPACE)
    Check(Body.is_on_floor(), "old jump binding no longer activates")
    await Press(KEY_E)
    Check(not Body.is_on_floor(), "remapped jump activates")
    await create_timer(0.5).timeout
    var Pad := InputEventJoypadMotion.new()
    Pad.device = 0
    Pad.axis = JOY_AXIS_LEFT_X
    Pad.axis_value = 0.8
    Before = Body.position
    root.push_input(Pad,true)
    await create_timer(0.15).timeout
    Pad = Pad.duplicate()
    Pad.axis_value = 0
    root.push_input(Pad,true)
    await create_timer(0.04).timeout
    Check(Body.position.x>Before.x+0.3, "semantic gamepad movement")
    var Motion := InputEventMouseMotion.new()
    Motion.position = Vector2(700,300)
    Motion.relative = Vector2(40,-20)
    root.push_input(Motion,true)
    await create_timer(0.05).timeout
    Check(abs(root.get_camera_3d().rotation.y)>0.05 and root.get_camera_3d().rotation.x>0.02, "relative semantic camera look")
    if Graphical:
        Check(DisplayServer.get_name()!="headless" and Engine.get_frames_drawn()>0, "actual rendering host")
        await RenderingServer.frame_post_draw
        var Picture := root.get_texture().get_image()
        Check(not Picture.is_empty() and Picture.save_png("res://controller.png")==OK, "rendered controller screenshot")
        var Colors := {}
        for Y in range(0,Picture.get_height(),20):
            for X in range(0,Picture.get_width(),20): Colors[Picture.get_pixel(X,Y).to_rgba32()]=true
        Check(Colors.size()>16, "rendered world has nonuniform image content")
    var OldId := Body.get_instance_id()
    await Press(KEY_F8)
    Check(not is_instance_id_valid(OldId) and root.get_camera_3d()==Previous, "example teardown restores camera")
    await Press(KEY_F8)
    await create_timer(0.6).timeout
    Body = World.get_node_or_null("LuauController") as CharacterBody3D
    Check(Body!=null and Body.is_on_floor() and Body.get_instance_id()!=OldId, "example restart")
    var NodesBefore := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var MemoryBefore := Performance.get_monitor(Performance.MEMORY_STATIC)
    for Cycle in range(20):
        Game.set_meta("RestartRequested",true)
        await create_timer(0.04).timeout
        Game.set_meta("RestartRequested",true)
        await create_timer(0.04).timeout
    var NodeDelta := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))-NodesBefore
    var MemoryDelta := Performance.get_monitor(Performance.MEMORY_STATIC)-MemoryBefore
    Check(NodeDelta==0 and Game.get_meta("ControllerRunning",false), "twenty restart cycles retain stable native node count")
    Game.free()
    await process_frame
    var Record := {"Result":"FAIL" if Failed else "PASS", "Checks":Checks, "Graphical":Graphical, "WalkingDistance":Walking, "RestartCycles":20, "NodeDelta":NodeDelta, "StaticMemoryDeltaBytes":MemoryDelta}
    FileAccess.open("res://input-demo.json",FileAccess.WRITE).store_string(JSON.stringify(Record))
    print("[Input:Demo] ",JSON.stringify(Record))
    print("[Input:Demo] ","FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
