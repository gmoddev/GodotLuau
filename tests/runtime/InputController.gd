extends SceneTree

var Game: Node
var Failed := false
var Checks := 0

func Check(Value: bool, Description: String) -> void:
    Checks += 1
    if not Value:
        Failed = true
        print("[Input:Controller] FAIL ", Description)

func Script(Name: String, Source: String, Client := true) -> Node:
    var Result: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func Probe(Name: String, Source: String) -> void:
    Script(Name, Source + "\ngame:SetAttribute('" + Name + "',true)")
    await create_timer(0.04).timeout
    Check(Game.get_meta(Name,false), "Luau " + Name)

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var World := Node3D.new()
    World.name = "Workspace"
    Game.add_child(World)
    var Floor := StaticBody3D.new()
    var Shape := BoxShape3D.new()
    Shape.size = Vector3(50,1,50)
    var Collider := CollisionShape3D.new()
    Collider.shape = Shape
    Floor.add_child(Collider)
    Floor.position.y = -0.5
    World.add_child(Floor)
    var Previous := Camera3D.new()
    World.add_child(Previous)
    Previous.make_current()
    var Clock: Node = ClassDB.instantiate("RunService")
    Clock.name = "RunService"
    Game.add_child(Clock)
    var Owner := Script("MotorOwner", """
local M=Instance.new('KinematicMotor3D',game.Workspace)
M.Name='Motor'
assert(M:IsA('KinematicMotor3D') and not M:IsA('Character'))
assert(M:Teleport(Vector3.new(0,2,0)))
assert(M:AcquireCamera() and M.CameraActive)
assert(M:SetViewAngles(0.5,0.2))
assert(not M:SetMoveVelocity(Vector3.new(0,1,0)))
assert(not M:SetMoveVelocity(Vector3.new(101,0,0)))
assert(not M:Teleport(Vector3.new(math.huge,0,0)))
assert(not M:SetViewAngles(0,2))
assert(not pcall(function() M.Velocity=Vector3.new(0,100,0) end))
shared.Motor=M; shared.MoveMethod=M.SetMoveVelocity
shared.Drive=false
shared.Step=game:GetService('RunService').Stepped:Connect(function()
    if shared.Drive then assert(M:SetMoveVelocity(Vector3.new(3,0,0))) end
end)
game:SetAttribute('MotorReady',true)
""")
    await create_timer(0.6).timeout
    Check(Game.get_meta("MotorReady",false), "bounded Luau motor and camera commands")
    var Motor := World.get_node_or_null("Motor") as CharacterBody3D
    if Motor == null:
        Game.free()
        quit(1)
        return
    Check(Motor.is_on_floor() and abs(Motor.position.y-0.9)<0.08, "Godot capsule collision and grounded observation")
    Check(root.get_camera_3d()!=Previous and Motor.call("CameraActive"), "viewport camera ownership")
    await Probe("CameraCompetition", "local Other=Instance.new('KinematicMotor3D',game.Workspace); assert(not Other:AcquireCamera()); Other:Destroy()")
    var Before := Motor.global_position
    await Probe("Drive", "shared.Drive=true")
    await create_timer(0.2).timeout
    Check(Motor.global_position.x>Before.x+0.4 and Motor.is_on_floor(), "Stepped commands drive production collision body")
    await Probe("StopDrive", "shared.Drive=false")
    await create_timer(0.04).timeout
    Before = Motor.global_position
    await create_timer(0.1).timeout
    Check(abs(Motor.global_position.x-Before.x)<0.001, "unrefreshed move command becomes neutral next tick")
    await Probe("Jump", "assert(shared.Motor:Jump(5)); assert(shared.Motor.Grounded)")
    await create_timer(0.07).timeout
    Check(Motor.position.y>1.1 and not Motor.is_on_floor(), "native jump and airborne observation")
    await Probe("AirJumpDenied", "assert(not shared.Motor:Jump(5))")
    await create_timer(0.5).timeout
    Check(Motor.is_on_floor(), "fall and landing")
    await Probe("Warp", "local M=shared.Motor; local Old=M.Position; assert(M:Teleport(Vector3.new(2,3,1))); assert(M.Position==Old)")
    await create_timer(0.05).timeout
    Check(abs(Motor.position.x-2)<0.001 and abs(Motor.position.z-1)<0.001 and Motor.position.y<3, "teleport executes at physics boundary")
    await Probe("Clone", "local C=shared.Motor:Clone(); C.Name='Clone'; C.Parent=game.Workspace; assert(not C.CameraActive and C.Velocity==Vector3.new(0,0,0)); shared.Clone=C")
    var Copy := World.get_node_or_null("Clone")
    var Colliders := 0
    if Copy != null:
        for Child in Copy.get_children(true):
            if Child is CollisionShape3D: Colliders += 1
    Check(Colliders==1, "clone recreates one internal collider and no active camera lease")
    var Server := Script("MotorAuthority", """
assert(not pcall(function() Instance.new('KinematicMotor3D',game.Workspace) end))
assert(not pcall(function() game.Workspace.Motor:SetMoveVelocity(Vector3.new(1,0,0)) end))
game:SetAttribute('MotorServerRejected',true)
""",false)
    await create_timer(0.04).timeout
    Check(Game.get_meta("MotorServerRejected",false), "Server cannot construct or command local motor")
    Server.free()
    var MotorId := Motor.get_instance_id()
    Owner.free()
    await create_timer(0.04).timeout
    Check(not is_instance_id_valid(MotorId) and root.get_camera_3d()==Previous, "creator retirement destroys motor and restores prior camera")
    await Probe("RetiredMotor", "assert(not pcall(function() shared.MoveMethod(shared.Motor,Vector3.new(1,0,0)) end))")
    Game.free()
    await process_frame
    print("[Input:Controller] ", JSON.stringify({"Checks":Checks}))
    print("[Input:Controller] ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
