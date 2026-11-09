extends SceneTree

var Game: Node
var World: Node3D
var Players: Node
var Failed := false
var Checks := 0

func Check(Value: bool, Description: String) -> void:
    Checks += 1
    if not Value:
        Failed = true
        print("[Character:V2] FAIL ", Description)

func Create(Type: String, Name: String, Parent: Node = null) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    (Parent if Parent != null else Game).add_child(Result)
    return Result

func Script(Name: String, Source: String, Client := false) -> Node:
    var Result: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func Freeze(Character: Node) -> void:
    Character.set_physics_process(false)
    var Body: Node = Character.call("GetPhysicsBody")
    Body.set_process(false)

func Synchronized(Character: Node3D, Description: String) -> void:
    Character.force_update_transform()
    var Body: Node3D = Character.call("GetPhysicsBody")
    Check(Body.global_transform.is_equal_approx(Character.global_transform), Description + " body")
    var RootPart: Node3D = Character.get_node("HumanoidRootPart")
    Check(RootPart.global_transform.is_equal_approx(Character.global_transform), Description + " root proxy")


func AnimationCases(Character: Node3D) -> void:
    var Probe := Node3D.new()
    Probe.name = "VisualProbe"
    Character.add_child(Probe)
    var Clip := Animation.new()
    Clip.length = 0.12
    var Track := Clip.add_track(Animation.TYPE_POSITION_3D)
    Clip.track_set_path(Track, NodePath("VisualProbe"))
    Clip.track_insert_key(Track, 0.0, Vector3.ZERO)
    Clip.track_insert_key(Track, 0.12, Vector3(0.1, 0, 0))
    Check(ResourceSaver.save(Clip, "res://V2Clip.tres") == OK, "write isolated native animation fixture")
    var ClipObject: Node = Create("AnimationObject", "V2Clip")
    ClipObject.call("set_animation_id", "res://V2Clip.tres")
    ClipObject.call("set_anim_name", "V2Clip")
    Script("Completion", """
local C = game.Workspace.LocalPlayer
local T = C.Animator:LoadAnimation(game.V2Clip)
shared.CompletedTrack = T
shared.RetainedPlay = T.Play
shared.RetainedConnect = T.Ended.Connect
T.Ended:Connect(function() game:SetAttribute('Ended', (game:GetAttribute('Ended') or 0) + 1) end)
T.Stopped:Connect(function(Completed) assert(Completed); game:SetAttribute('Stopped', (game:GetAttribute('Stopped') or 0) + 1) end)
T:Play()
assert(#C.Animator:GetPlayingAnimationTracks() == 1)
game:SetAttribute('AnimationStarted', true)
""")
    await create_timer(0.4).timeout
    Check(Game.get_meta("AnimationStarted", false) and Game.get_meta("Ended", 0) == 1 and Game.get_meta("Stopped", 0) == 1, "actual Luau Ended/Stopped completion exactly once")
    var TrackNode: Node = Character.get_node("Animator").get_child(0)
    var OldTrack := TrackNode.get_instance_id()
    Character.get_node("Animator").queue_free()
    await process_frame
    Check(not is_instance_id_valid(OldTrack), "Animator owns and destroys its tracks")
    Script("RetainedTrack", "shared.RetainedPlay(shared.CompletedTrack); assert(shared.RetainedConnect({}, function() error('stale') end) == nil); game:SetAttribute('RetainedSafe', true)")
    await create_timer(0.05).timeout
    Check(Game.get_meta("RetainedSafe", false), "retained track method and signal view resolve dead ObjectIDs")
    Character.call("EnsureRootPart")
    var LongClip: Animation = Clip.duplicate(true)
    LongClip.length = 1.0
    Check(ResourceSaver.save(LongClip, "res://V2Long.tres") == OK, "write isolated replacement clip")
    var LongAnimation: Node = Create("AnimationObject", "V2Long")
    LongAnimation.call("set_animation_id", "res://V2Long.tres")
    LongAnimation.call("set_anim_name", "V2Long")
    Script("Replacement", """
local A = game.Workspace.LocalPlayer.Animator
shared.FirstTrack = A:LoadAnimation(game.V2Long)
shared.NextTrack = A:LoadAnimation(game.V2Long)
shared.FirstTrack.Stopped:Connect(function(Completed) assert(not Completed); game:SetAttribute('Replaced', true) end)
shared.NextTrack.Ended:Connect(function() game:SetAttribute('CancelledCompletion', true) end)
shared.FirstTrack:Play(); shared.NextTrack:Play()
shared.FirstTrack.Speed = 3; shared.FirstTrack.Looped = true
assert(not shared.FirstTrack.IsPlaying and shared.NextTrack.IsPlaying)
assert(#A:GetPlayingAnimationTracks() == 1)
game:SetAttribute('ReplacementStarted', true)
""")
    await create_timer(0.05).timeout
    var Player: AnimationPlayer = Character.get_node("AnimationPlayer")
    Check(Game.get_meta("ReplacementStarted", false) and Game.get_meta("Replaced", false), "track replacement has one playback owner")
    Check(Player.speed_scale == 1.0 and Player.get_animation("V2Long").loop_mode == Animation.LOOP_NONE, "inactive track settings cannot change current playback")
    Character.get_node("Animator").queue_free()
    await process_frame
    Check(not Player.is_playing() and not Game.has_meta("CancelledCompletion"), "Animator departure cancels owned playback without stale completion")
    Character.call("EnsureRootPart")
    Script("OwnedSafe", "shared.SafeTrack = game.Workspace.LocalPlayer.Animator:LoadAnimation(game.V2Long); shared.SafeTrack:Play(); game:SetAttribute('OwnedSafe', true)")
    await create_timer(0.05).timeout
    Check(Game.get_meta("OwnedSafe", false), "new Animator can load fresh playback")
    var Library := Player.get_animation_library("")
    var Gameplay := Animation.new()
    Gameplay.length = 1.0
    var GameplayTrack := Gameplay.add_track(Animation.TYPE_VALUE)
    Gameplay.track_set_path(GameplayTrack, NodePath(".:Health"))
    Gameplay.track_insert_key(GameplayTrack, 0.0, 100.0)
    Gameplay.track_insert_key(GameplayTrack, 0.5, 70.0)
    Player.stop()
    Library.remove_animation("V2Long")
    Library.add_animation("V2Long", Gameplay)
    Player.play("V2Long")
    Character.get_node("Animator").queue_free()
    await create_timer(0.2).timeout
    Check(Player.is_playing() and Character.call("get_health") < 100.0, "old track cleanup preserves a later trusted gameplay clip")
    Player.stop()
    Library.remove_animation("V2Long")
    Probe.queue_free()
    await process_frame
    Character.call("EnsureRootPart")
    var ReloadProbe := Node3D.new()
    ReloadProbe.name = "VisualProbe"
    Character.add_child(ReloadProbe)
    var Disabled := Script("DisableAnimation", "local T = game.Workspace.LocalPlayer.Animator:LoadAnimation(game.V2Clip); T.Ended:Connect(function() game:SetAttribute('RetiredAnimationCallback', true) end); T:Play(); game:SetAttribute('DisableReady', true)")
    await create_timer(0.03).timeout
    Check(Game.get_meta("DisableReady", false), "animation owner starts before disable")
    Disabled.call("set_enabled", false)
    await create_timer(0.3).timeout
    Check(not Game.has_meta("RetiredAnimationCallback"), "disabled executable cannot receive animation completion")
    var NewCode: Script = ClassDB.instantiate("LuauScript")
    NewCode.source_code = "local T=game.Workspace.LocalPlayer.Animator:LoadAnimation(game.V2Clip); T.Ended:Connect(function() game:SetAttribute('ReloadedAnimationCallback', true) end); T:Play()"
    Disabled.call("set_codigo_luau", NewCode)
    Disabled.call("set_enabled", true)
    await create_timer(0.3).timeout
    Check(Game.get_meta("ReloadedAnimationCallback", false) and not Game.has_meta("RetiredAnimationCallback"), "script reload completes only its fresh animation callback")
    Check(Character.get_node("Animator").is_class("RBXAnimator"), "replacement Animator retains native identity")

func SetKey(Code: int, Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code
    Event.physical_keycode = Code
    Event.pressed = Pressed
    Input.parse_input_event(Event)
    Input.flush_buffered_events()

func InputCases(Character: Node3D) -> void:
    Character.call("set_walk_speed", 16.0)
    var Body: CharacterBody3D = Character.call("GetPhysicsBody")
    Body.set_process(false)
    Character.global_transform = Transform3D(Basis(), Vector3(100, 2, 100))
    Body.velocity = Vector3.ZERO
    Character.set_physics_process(true)
    for Tick in range(60): await physics_frame
    SetKey(KEY_D, true)
    for Tick in range(40): await physics_frame
    Check(Body.velocity.x > 15.9, "native keyboard reaches unchanged walk speed")
    SetKey(KEY_SHIFT, true)
    for Tick in range(40): await physics_frame
    Check(Body.velocity.x > 23.9, "native keyboard sprint retains 1.5 multiplier")
    SetKey(KEY_D, false)
    SetKey(KEY_SHIFT, false)
    var Pivot: Node3D = Body.get_node("CameraPivotH")
    Pivot.rotation.y = PI / 2
    var Camera: Camera3D = Pivot.get_node("CameraPivotV/SpringArm/Camera3D")
    Camera.make_current()
    SetKey(KEY_W, true)
    for Tick in range(40): await physics_frame
    Check(Body.velocity.x < -15.9, "keyboard movement uses actual rotated camera basis")
    SetKey(KEY_W, false)
    Pivot.rotation.y = 0
    var Axis := InputEventJoypadMotion.new()
    Axis.device = 0
    Axis.axis = JOY_AXIS_LEFT_X
    Axis.axis_value = 1.0
    Input.parse_input_event(Axis)
    Input.flush_buffered_events()
    for Tick in range(45): await physics_frame
    Check(Body.velocity.x > 15.9, "native gamepad axis feeds Character movement")
    Axis.axis_value = 0
    Input.parse_input_event(Axis)
    Input.flush_buffered_events()
    FileAccess.open("res://.gl_mp_session", FileAccess.WRITE).store_string("1|Mobile|0")
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Character.global_transform = Transform3D(Basis(), Vector3(0, 2, 0))
    Body = Character.call("GetPhysicsBody")
    Character.call("set_walk_speed", 16.0)
    Check(Body.has_node("TouchControls/JumpButton"), "native mobile mode constructs touch controls")
    for Tick in range(60): await physics_frame
    root.size = Vector2i(1152, 648)
    Input.set_emulate_mouse_from_touch(false)
    var Touch := InputEventScreenTouch.new()
    Touch.index = 0
    Touch.position = Vector2(50, 100)
    Touch.pressed = true
    Input.parse_input_event(Touch)
    Input.flush_buffered_events()
    await process_frame
    var Drag := InputEventScreenDrag.new()
    Drag.index = 0
    Drag.position = Vector2(160, 100)
    Drag.relative = Vector2(110, 0)
    Input.parse_input_event(Drag)
    Input.flush_buffered_events()
    for Tick in range(40): await physics_frame
    print("[Character:V2] Touch diagnostic ", root.get_visible_rect(), " velocity=", Body.velocity)
    Check(Vector3(Body.velocity.x, 0, Body.velocity.z).length() > 15.9, "actual touch drag feeds native movement")
    Touch.pressed = false
    Input.parse_input_event(Touch)
    Input.flush_buffered_events()
    var JumpButton: Button = Body.get_node("TouchControls/JumpButton")
    JumpButton.toggle_mode = true
    JumpButton.set_pressed_no_signal(true)
    for Tick in range(3): await physics_frame
    print("[Character:V2] Input diagnostic ", Body.velocity, " floor=", Body.is_on_floor(), " jump=", JumpButton.button_pressed, " health=", Character.call("get_health"))
    Check(Body.velocity.y > 0, "native mobile jump button requests physics jump")
    JumpButton.set_pressed_no_signal(false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.gl_mp_session"))
    Freeze(Character)


func PhysicsCases(Character: Node3D) -> void:
    var Baseline := "--gl043-baseline" in OS.get_cmdline_user_args()
    var Group := Create("Folder", "PhysicsFilterGroup", World)
    var Near: RigidBody3D = Create("RobloxPart", "PhysicsNear", Group)
    var Far: RigidBody3D = Create("RobloxPart", "PhysicsFar", World)
    for Part in [Near, Far]:
        Part.call("set_anchored", true)
        Part.call("set_size", Vector3(2,2,2))
    Near.global_position = Vector3(0,100,0)
    Far.global_position = Vector3(6,100,0)
    var Body: RigidBody3D = Create("RobloxPart", "PhysicsImpulse", World)
    Body.call("set_anchored", false)
    Body.gravity_scale = 0; Body.mass = 1
    Body.global_position = Vector3(0,200,0)
    await physics_frame; await physics_frame
    Script("PhysicsFilters", """
local W = game.Workspace
local Near, Far = W.PhysicsFilterGroup.PhysicsNear, W.PhysicsFar
local P = RaycastParams.new(); P.MaxDistance = 20
local function Hit(Params)
    return W:Raycast(Vector3.new(-5,100,0), Vector3.new(1,0,0), Params)
end
local function Is(Result, Part) return Result and Result.Instance == Part end
game:SetAttribute('Physics_Unfiltered', Is(Hit(P), Near))
game:SetAttribute('Physics_LegacyRay', Is(W:Raycast({X=-5,Y=100,Z=0},{X=1,Y=0,Z=0},20),Near) and Is(W:FindPartOnRay(Vector3.new(-5,100,0),Vector3.new(1,0,0),20),Near))
P.FilterDescendantsInstances = {W.PhysicsFilterGroup}
game:SetAttribute('Physics_Exclude', Is(Hit(P), Far))
P.FilterType = Enum.RaycastFilterType.Include
P.FilterDescendantsInstances = {Far}
local R = Hit(P)
game:SetAttribute('Physics_Include', Is(R, Far))
game:SetAttribute('Physics_Result', R and math.abs(R.Distance-10)<0.01 and math.abs(R.Position.X-5)<0.01 and R.Normal.X< -0.99)
P.FilterDescendantsInstances = {W.PhysicsFilterGroup}
game:SetAttribute('Physics_Descendant', Is(Hit(P), Near))
P.FilterDescendantsInstances = {Near, Far}
game:SetAttribute('Physics_Nearest', Is(Hit(P), Near))
P.FilterDescendantsInstances = {}
game:SetAttribute('Physics_EmptyInclude', Hit(P) == nil)
P.FilterType = Enum.RaycastFilterType.Exclude
game:SetAttribute('Physics_EmptyExclude', Is(Hit(P), Near))
P.FilterDescendantsInstances = {Near, Near}
game:SetAttribute('Physics_Duplicate', Is(Hit(P), Far))
P.MaxDistance = 3
game:SetAttribute('Physics_Distance', Hit(P) == nil)
game:SetAttribute('PhysicsFiltersDone', true)
""")
    await create_timer(0.1).timeout
    for Name in ["Unfiltered", "LegacyRay", "Exclude", "Include", "Result", "Descendant", "Nearest", "EmptyInclude", "EmptyExclude", "Duplicate", "Distance"]:
        var Passed: bool = Game.get_meta("Physics_"+Name,false)
        print("[Physics:Bindings] ","PASS " if Passed else "FAIL ",Name)
        Check(Passed,"GL-043 raycast "+Name)
    var CharacterBody: Node3D = Character.call("GetPhysicsBody")
    var Origin: Vector3 = CharacterBody.get_node("CollisionShape3D").global_position-Vector3(10,0,0)
    Script("PhysicsCharacterFilter", """
local C=game.Workspace.LocalPlayer
local P=RaycastParams.new(); P.FilterType=0; P.MaxDistance=20; P.FilterDescendantsInstances={C}
local Origin=Vector3.new(%f,%f,%f)
local R=game.Workspace:Raycast(Origin,Vector3.new(1,0,0),P)
game:SetAttribute('PhysicsCharacterInclude',R and R.Instance.Parent==C)
P.FilterType=1
game:SetAttribute('PhysicsCharacterExclude',game.Workspace:Raycast(Origin,Vector3.new(1,0,0),P)==nil)
""" % [Origin.x,Origin.y,Origin.z])
    await create_timer(0.05).timeout
    Check(Game.get_meta("PhysicsCharacterInclude",false) and Game.get_meta("PhysicsCharacterExclude",false),"GL-043 Character root filters include/exclude its actual PhysicsBody")
    Script("PhysicsVectorImpulse", "game.Workspace.PhysicsImpulse:ApplyImpulse(Vector3.new(4,0,0)); game.Workspace.PhysicsImpulse:ApplyAngularImpulse(Vector3.new(0,4,0)); game:SetAttribute('PhysicsImpulseDone',true)")
    await create_timer(0.1).timeout
    var NativeLinear := Body.linear_velocity.x > 1.9
    var NativeAngular := Body.angular_velocity.y > 0.5
    print("[Physics:Bindings] Vector3 linear=",Body.linear_velocity," angular=",Body.angular_velocity)
    Check(NativeLinear,"GL-043 native Vector3 central impulse")
    Check(NativeAngular,"GL-043 native Vector3 angular impulse")
    Body.linear_velocity = Vector3.ZERO; Body.angular_velocity = Vector3.ZERO
    Script("PhysicsTableImpulse", "game.Workspace.PhysicsImpulse:ApplyImpulse({X=0,Y=4,Z=0}); game.Workspace.PhysicsImpulse:ApplyAngularImpulse({X=0,Y=0,Z=4}); game:SetAttribute('PhysicsTableDone',true)")
    await create_timer(0.1).timeout
    Check(Body.linear_velocity.y>1.9 and Body.angular_velocity.z>0.5,"GL-043 legacy component table impulses")
    if not Baseline:
        Body.linear_velocity = Vector3.ZERO; Body.angular_velocity = Vector3.ZERO
        var InvalidOwner := Script("PhysicsInvalid", """
local W, B = game.Workspace, game.Workspace.PhysicsImpulse
local function Ray(P) return W:Raycast(Vector3.new(-5,100,0),Vector3.new(1,0,0),P) end
local P = RaycastParams.new(); P.FilterType = 9
assert(not pcall(function() Ray(P) end))
P.FilterType = 1; P.FilterDescendantsInstances = {Vector3.new()}
assert(not pcall(function() Ray(P) end))
P.FilterDescendantsInstances = {[2]=W}
assert(not pcall(function() Ray(P) end))
P.FilterDescendantsInstances = {}; for I=1,64 do P.FilterDescendantsInstances[I]=W.PhysicsFilterGroup end
assert(Ray(P).Instance==W.PhysicsFar)
P.FilterDescendantsInstances = {}; for I=1,65 do P.FilterDescendantsInstances[I]=W end
assert(not pcall(function() Ray(P) end))
P.FilterDescendantsInstances = {}; P.MaxDistance = math.huge
assert(not pcall(function() Ray(P) end))
assert(not pcall(function() W:Raycast(W,Vector3.new(1,0,0)) end))
assert(not pcall(function() W:Raycast(Vector3.new(0/0,0,0),Vector3.new(1,0,0)) end))
for _, Value in ipairs({W, Color3.new(), {X=1,Y=2}, Vector3.new(0/0,0,0), {X=math.huge,Y=0,Z=0}}) do
    assert(not pcall(function() B:ApplyImpulse(Value) end))
    assert(not pcall(function() B:ApplyAngularImpulse(Value) end))
end
local Called = false
local Proxy = setmetatable({X=1,Y=0}, {__index=function() Called=true; B:Destroy(); return 0 end})
assert(not pcall(function() B:ApplyImpulse(Proxy) end) and not Called)
local Dead = Instance.new('Folder'); Dead:Destroy()
P = RaycastParams.new(); P.MaxDistance=20; P.FilterDescendantsInstances={Dead}
assert(Ray(P).Instance==W.PhysicsFilterGroup.PhysicsNear)
P.FilterType=0; assert(Ray(P)==nil)
shared.PhysicsRetained = B.ApplyImpulse; shared.PhysicsAngularRetained = B.ApplyAngularImpulse
game:SetAttribute('PhysicsInvalidDone',true)
""")
        await create_timer(0.1).timeout
        Check(Game.get_meta("PhysicsInvalidDone",false) and Body.linear_velocity.is_zero_approx() and Body.angular_velocity.is_zero_approx(),"GL-043 invalid input rejects without physics mutation and dead filters are safe")
        InvalidOwner.call("set_enabled",false)
        Script("PhysicsReloadUse", "shared.PhysicsRetained(nil,Vector3.new(4,0,0)); game:SetAttribute('PhysicsReloadDone',true)")
        await create_timer(0.05).timeout
        Check(Game.get_meta("PhysicsReloadDone",false) and Body.linear_velocity.x>1.9,"GL-043 retained method uses a live Part from a fresh execution owner")
        Body.queue_free(); await process_frame
        Script("PhysicsRetired", "shared.PhysicsRetained(nil,Vector3.new(1,0,0)); shared.PhysicsAngularRetained(nil,Vector3.new(1,0,0)); game:SetAttribute('PhysicsRetiredDone',true)")
        await create_timer(0.05).timeout
        Check(Game.get_meta("PhysicsRetiredDone",false),"GL-043 retained impulse methods survive native Part destruction")
        var Blockers := Create("Folder","PhysicsBlockers",World)
        for Index in range(129):
            var Part: RigidBody3D = Create("RobloxPart","Blocker"+str(Index),Blockers)
            Part.call("set_anchored",true); Part.call("set_size",Vector3.ONE)
            Part.global_position = Vector3(Index*2,300,0)
        await physics_frame; await physics_frame
        Script("PhysicsBound", """
local P=RaycastParams.new(); P.MaxDistance=300; P.FilterDescendantsInstances={game.Workspace.PhysicsBlockers}
for I=1,3 do
    local OK,Error=pcall(function() game.Workspace:Raycast(Vector3.new(-2,300,0),Vector3.new(1,0,0),P) end)
    assert(not OK and string.find(Error,'work limit exceeded',1,true))
end
game:SetAttribute('PhysicsBoundDone',true)
""")
        await create_timer(0.1).timeout
        Check(Game.get_meta("PhysicsBoundDone",false),"GL-043 excessive filtered collider work fails explicitly and cleans native query resources")
        Blockers.queue_free()
    else: Body.queue_free()
    Group.queue_free(); Far.queue_free()
    await process_frame

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Players = Create("Players", "Players")
    Create("RunService", "RunService")
    Create("NetworkService", "NetworkService")
    var Settings := Node.new()
    Settings.name = "SettingsMenu"
    Game.add_child(Settings)
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    await process_frame
    var Character: Node3D = World.get_node("LocalPlayer")
    Freeze(Character)
    await PhysicsCases(Character)
    if "--gl043-baseline" in OS.get_cmdline_user_args():
        Game.free(); await process_frame; await process_frame
        print("[Physics:Bindings] Baseline ","FAIL" if Failed else "PASS")
        quit(1 if Failed else 0); return
    var Rig := "R6" if Character.has_node("Torso") else "Fallback"
    Check(Character.is_class("RBXCharacter") and Character.is_class("RBXModel"), "actual native Model inheritance")
    Check(not Character.has_node("Humanoid") and not ClassDB.class_exists("Humanoid"), "separate 3D Humanoid removed")
    Check(Character.has_node("Animator") and Character.get_node("Animator").is_class("RBXAnimator"), "actual Animator identity")
    Check(Players.call("get_local_player").call("get_character") == Character, "Player.Character is the actual root")
    Synchronized(Character, "initial")
    var Legacy := PackedByteArray()
    Legacy.resize(73)
    for Offset in range(8): Legacy[Offset] = "<roblox!".to_ascii_buffer()[Offset]
    Legacy.encode_u32(16, 1)
    Legacy.encode_u32(20, 1)
    for Offset in range(4): Legacy[32+Offset] = "INST".to_ascii_buffer()[Offset]
    Legacy.encode_u32(40, 25)
    Legacy.encode_u32(52, 8)
    for Offset in range(8): Legacy[56+Offset] = "Humanoid".to_ascii_buffer()[Offset]
    Legacy.encode_u32(65, 1)
    Legacy[72] = 2
    var LegacyFile := FileAccess.open("res://LegacyCharacter.rbxl", FileAccess.WRITE)
    LegacyFile.store_buffer(Legacy)
    LegacyFile.close()
    var Importer: RefCounted = ClassDB.instantiate("RBXImporter")
    for Attempt in range(3):
        Check(Importer.call("Begin", "res://LegacyCharacter.rbxl"), "actual binary legacy scene parses before migration gate")
        Importer.call("Step")
        Check(Importer.call("HasFailed") and "Character V2" in Importer.call("GetLastError") and FileAccess.get_file_as_bytes("res://LegacyCharacter.rbxl") == Legacy, "legacy Humanoid import fails explicitly without rewriting the source")
    Importer = null
    Script("ModelAPI", """
local C = game:GetService('Players'):GetPlayers()[1].Character
C.CameraMode = 2
C.MouseSensitivity = 0.003
assert(C.CameraMode == 2 and math.abs(C.MouseSensitivity - 0.003) < 0.000001)
C.CameraMode = 0/0
C.MouseSensitivity = math.huge
assert(C.CameraMode == 2 and math.abs(C.MouseSensitivity - 0.003) < 0.000001)
assert(C.ClassName == 'Character' and C:IsA('Character') and C:IsA('Model') and C:IsA('PVInstance'))
assert(not C:IsA('Player') and not C:IsA('Humanoid'))
assert(C.PrimaryPart.Name == 'HumanoidRootPart' and C:FindFirstChild('Humanoid') == nil)
assert(C.Animator.ClassName == 'Animator' and #C:GetChildren() > 0 and #C:GetDescendants() > 0)
C:PivotTo(CFrame.new(12, 5, 3) * CFrame.Angles(0, math.rad(30), 0))
assert(math.abs(C:GetPivot().X - 12) < 0.001)
C:MoveTo(Vector3.new(18, 5, 4))
assert(math.abs(C:GetPivot().X - 18) < 0.001)
local Center, Size = C:GetBoundingBox()
assert(Size.X > 0 and Size.Y > 0 and C:GetExtentsSize().Y == Size.Y)
assert(not pcall(function() C:PivotTo(CFrame.new(0/0,0,0)) end))
assert(not pcall(function() Instance.new('Humanoid') end))
local Model = Instance.new('Model', game)
assert(Model.ClassName == 'Model' and Model:IsA('Model'))
Model:MoveTo(Vector3.new(2,3,4)); assert(Model:GetPivot().X == 2)
Model:Destroy()
game:SetAttribute('ModelChecked', true)
""")
    await create_timer(0.1).timeout
    Check(Game.get_meta("ModelChecked", false), "Luau Model API, bounds and rejection")
    Synchronized(Character, "Lua PivotTo/MoveTo")
    await AnimationCases(Character)
    var Parent := Node3D.new()
    Parent.name = "CharacterParent"
    World.add_child(Parent)
    Character.reparent(Parent, true)
    Parent.transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.5), Vector3(3, 2, -4))
    Character.force_update_transform()
    await process_frame
    Synchronized(Character, "parent rotation/translation/uniform scale")
    Check(Players.call("get_local_player").call("get_character") == Character, "reparent preserves Player.Character identity")
    Character.reparent(World, true)
    Character.global_transform = Transform3D(Basis(), Vector3(0, 5, 0))
    Character.force_update_transform()
    var Prior := Character.global_transform
    Character.scale = Vector3(2, 1, 1)
    Character.force_update_transform()
    await process_frame
    Check(Character.global_transform.is_equal_approx(Prior), "nonuniform scale rejected without pose mutation")
    Synchronized(Character, "reparent and rejected scale")
    var Body: CharacterBody3D = Character.call("GetPhysicsBody")
    Character.call("set_camera_mode", 1) # exact-follow assertion uses the fixed camera style
    Body.set_process(true)
    Character.call("set_lock_first_person", true)
    await create_timer(0.1).timeout
    Check(Body.call("_gl_is_first_person"), "first-person controller mode")
    Character.call("set_lock_first_person", false)
    await create_timer(0.1).timeout
    Check(not Body.call("_gl_is_first_person"), "third-person controller mode")
    var CameraPivot: Node3D = Body.get_node("CameraPivotH")
    Check(CameraPivot.global_position.distance_to(Body.global_position + Vector3(0, 1.5, 0)) < 0.01, "native camera follows physics pose")
    CameraPivot.free()
    await create_timer(0.05).timeout
    Check(is_instance_valid(Character), "camera component destruction is safe")
    Freeze(Character)
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(1000, 1, 1000)
    Shape.shape = Box
    Floor.position.y = -1.5
    Floor.add_child(Shape)
    Game.add_child(Floor)
    var NPC: Node3D = Create("RBXCharacter", "NPC", World)
    NPC.position = Vector3(20, 5, 0)
    NPC.call("EnsureRootPart")
    Check(not NPC.get_node("PhysicsBody").has_node("CameraPivotH"), "NPC does not acquire a local camera")
    NPC.call("set_npc_move_dir", Vector3.RIGHT)
    var NPCBody: CharacterBody3D = NPC.call("GetPhysicsBody")
    for Tick in range(75): await physics_frame
    Check(is_equal_approx(NPCBody.velocity.x, 16.0) and NPC.call("IsGrounded"), "camera-free NPC movement and grounding")
    Check(NPC.call("get_state") == 1 and NPC.call("get_move_direction").x > 0.99, "observed running and direction")
    Synchronized(NPC, "NPC movement")
    NPC.call("RequestJump")
    var Up := 0.0
    var Down := 0.0
    for Tick in range(100):
        await physics_frame
        Up = maxf(Up, NPCBody.velocity.y)
        Down = minf(Down, NPCBody.velocity.y)
    Check(Up > 19 and Down < -15 and NPC.call("IsGrounded"), "NPC jump/fall/land physics")
    var Destination := NPC.global_position + Vector3(4, 0, 0)
    NPC.connect("MoveToFinished", func(Arrived: bool) -> void: Game.set_meta("Arrived", Arrived))
    Check(NPC.call("WalkToPoint", Destination), "native target request admitted")
    for Tick in range(90): await physics_frame
    Check(Game.get_meta("Arrived", false) and Vector2(NPC.position.x - Destination.x, NPC.position.z - Destination.z).length() <= 0.26, "bounded point movement arrives without overshoot")
    NPC.call("set_npc_move_dir", Vector3.RIGHT)
    var Wall: Node3D = Create("Part", "TouchWall", World)
    Wall.call("set_size", Vector3(2, 8, 8))
    Wall.call("set_anchored", true)
    Wall.global_position = NPC.global_position + Vector3(4, 2, 0)
    Wall.connect("Touched", func(Hit: Node) -> void:
        if is_instance_valid(NPC) and Hit == NPC.get_node("HumanoidRootPart"):
            Game.set_meta("TouchRoot", Hit.get_parent() == NPC))
    for Tick in range(60): await physics_frame
    Check(Game.get_meta("TouchRoot", false), "slide collision reports direct Character root proxy")
    NPC.call("stop_npc_movement")
    NPC.set_physics_process(false)
    NPC.connect("HealthChanged", func(_New: float, _Old: float) -> void: Game.set_meta("HealthEvents", int(Game.get_meta("HealthEvents", 0)) + 1))
    NPC.call("set_max_health", 50.0)
    Check(NPC.call("get_health") == 50.0 and Game.get_meta("HealthEvents", 0) == 1, "MaxHealth clamp emits one health change")
    NPC.call("set_max_health", 100.0)
    NPC.call("heal", 50.0)
    var Health: float = NPC.call("get_health")
    NPC.call("set_health", NAN)
    NPC.call("set_walk_speed", INF)
    NPC.call("SetAcceleration", NAN)
    NPC.call("set_npc_move_dir", Vector3(NAN, 0, 0))
    Check(NPC.call("get_health") == Health and NPC.call("get_walk_speed") == 16.0 and NPC.call("GetAcceleration") == 110.0, "finite numeric validation without mutation")
    var Identity := NPC.get_instance_id()
    NPC.connect("HealthChanged", func(_New: float, _Old: float) -> void: NPC.queue_free())
    NPC.call("take_damage", 10.0)
    Check(NPC.is_queued_for_deletion(), "native health callback queues owner destruction")
    await process_frame
    Check(not is_instance_id_valid(Identity), "destruction during native health callback")
    var TemplateHolder: Node = Create("StarterPlayer", "StarterPlayer")
    var VisualTemplate := Node3D.new()
    VisualTemplate.name = "StarterCharacter"
    var VisualRoot := Node3D.new()
    VisualRoot.name = "HumanoidRootPart"
    VisualTemplate.add_child(VisualRoot)
    var CustomMesh := MeshInstance3D.new()
    CustomMesh.name = "VisualMesh"
    CustomMesh.mesh = BoxMesh.new()
    VisualTemplate.add_child(CustomMesh)
    TemplateHolder.add_child(VisualTemplate)
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Freeze(Character)
    Check(Character.is_class("RBXCharacter") and Character.has_node("HumanoidRootPart") and Character.find_child("VisualMesh", true, false) != null, "legacy Node3D custom visual template has actual Character identity and direct root proxy")
    VisualTemplate.free()
    var Template: Node3D = ClassDB.instantiate("RBXCharacter")
    Template.name = "StarterCharacter"
    Template.call("set_walk_speed", 12.0)
    var Visual := MeshInstance3D.new()
    Visual.name = "CustomVisual"
    Visual.mesh = BoxMesh.new()
    Template.add_child(Visual)
    var LegacyVisual: Node3D = ClassDB.instantiate("Part")
    LegacyVisual.name = "VisualPart"
    LegacyVisual.position.x = 2
    Template.add_child(LegacyVisual)
    TemplateHolder.add_child(Template)
    await process_frame
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Freeze(Character)
    Check(Character.is_class("RBXCharacter") and Character.has_node("CustomVisual") and Character.call("get_walk_speed") == 12.0, "StarterCharacter preserves actual Character and configuration")
    var Bodies := 0
    for Child in Character.get_children(true):
        if Child is CharacterBody3D: Bodies += 1
    Check(Bodies == 1, "template clone has exactly one physics body")
    var VisualPart: RigidBody3D = Character.get_node("VisualPart")
    Check(VisualPart.freeze and VisualPart.collision_layer == 0 and VisualPart.collision_mask == 0, "rig Part is visual, without a competing active collider")
    VisualPart.call("set_anchored", false)
    VisualPart.call("set_can_collide", true)
    Check(VisualPart.freeze and not VisualPart.call("get_can_collide") and VisualPart.collision_layer == 0, "visual Part properties cannot reintroduce duplicate character collision")
    Synchronized(Character, "StarterCharacter clone")
    var Old := Character.get_instance_id()
    var Player: Node = Players.call("get_local_player")
    Script("ReentrantLoad", "local P = game:GetService('Players'):GetPlayers()[1]; P.CharacterAdded:Connect(function(C) game:SetAttribute('AddedCount', (game:GetAttribute('AddedCount') or 0) + 1); if not game:GetAttribute('Reentered') then game:SetAttribute('Reentered', true); P:LoadCharacter() end end); game:SetAttribute('ReentrantReady', true)")
    await create_timer(0.05).timeout
    Check(Game.get_meta("ReentrantReady", false), "reentrant Lua callback registered")
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Freeze(Character)
    Check(Character.get_instance_id() != Old and Players.call("get_local_player") == Player, "reentrant LoadCharacter keeps one player and replaces one life")
    var Roots := 0
    for Child in World.get_children():
        if Child.is_class("RBXCharacter"): Roots += 1
    Check(Roots == 1 and Game.get_meta("AddedCount", 0) == 1, "reentrant LoadCharacter does not duplicate characters")
    for Tick in range(20):
        Players.call("load_local_character")
        Freeze(World.get_node("LocalPlayer"))
        await process_frame
    Check(Players.call("get_local_player") == Player and Player.get_node_or_null("PlayerGui") != null and Player.get_node_or_null("Backpack") != null, "repeated respawn preserves Player containers")
    Players.call("set_character_auto_loads", false)
    Players.call("set_respawn_time", 0.05)
    Character = World.get_node("LocalPlayer")
    var DeadIdentity := Character.get_instance_id()
    Character.call("set_health", 0.0)
    await create_timer(0.2).timeout
    Check(World.get_node("LocalPlayer").get_instance_id() == DeadIdentity, "CharacterAutoLoads false prevents automatic replacement")
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Freeze(Character)
    Check(Character.get_instance_id() != DeadIdentity and Character.call("get_health") == 100.0, "manual LoadCharacter remains available with automatic loads disabled")
    Game.get_node("NetworkService").call("RequestCharacterReset")
    Players.call("load_local_character")
    await process_frame
    Character = World.get_node("LocalPlayer")
    Freeze(Character)
    await create_timer(0.1).timeout
    Check(Character.call("get_health") == 100.0, "pending reset cannot affect a replacement Character identity")
    Script("DepartureObserver", "local P=game:GetService('Players'):GetPlayers()[1]; P.CharacterRemoving:Connect(function(C) assert(C==P.Character and C:IsA('Character')); game:SetAttribute('RemovingIdentityValid', true); game:SetAttribute('RemovingCount', (game:GetAttribute('RemovingCount') or 0)+1) end); game:SetAttribute('DepartureReady', true)")
    while not Game.has_meta("DepartureReady"): await process_frame
    Character.free()
    await process_frame
    Check(Game.get_meta("RemovingIdentityValid", false) and Game.get_meta("RemovingCount", 0) == 1 and Player.call("get_character") == null, "native deletion fires one CharacterRemoving before clearing Player.Character")
    Players.call("load_local_character")
    await process_frame
    Freeze(World.get_node("LocalPlayer"))
    Players.call("set_character_auto_loads", false)
    var Secondary: Node = ClassDB.instantiate("RobloxWorkspace")
    Secondary.name = "NoAutomaticCharacter"
    Game.add_child(Secondary)
    await process_frame
    Check(Secondary.get_node_or_null("LocalPlayer") == null, "initial CharacterAutoLoads false does not create a Character")
    Secondary.queue_free()
    await process_frame
    await InputCases(World.get_node("LocalPlayer"))
    print("[Character:V2] ", JSON.stringify({"Architecture": "CharacterV2", "Rig": Rig, "Checks": Checks, "Jump": Up, "Fall": Down}))
    Game.free()
    await process_frame
    print("[Character:V2] ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
