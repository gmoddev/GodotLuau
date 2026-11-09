extends SceneTree
## Drives the actual playable project using semantic hardware events.
var Game: Node
var Cases: Array[Dictionary] = []
var Scenario := "local"
var Graphical := false
var MaxGap := 0.0
var Frames := 0
var Elapsed := 0.0
var Started := 0
var Screenshot := ""

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for I in range(Args.size()-1):
        if Args[I] == "--scenario": Scenario = Args[I+1]
    Graphical = "--graphical" in Args
    call_deferred("Run")

func _process(Delta: float) -> bool:
    # The offscreen window must never take the user's OS focus. Supply synthetic
    # focus alongside synthetic hardware input; production focus gates stay intact.
    if Graphical and is_instance_valid(Game):
        Game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    MaxGap = maxf(MaxGap,Delta)
    Frames += 1
    Elapsed += Delta
    return false

func Check(Value: bool, Label: String) -> void:
    Cases.append({"Label":Label,"Passed":Value})
    print("[Game:Playtest] ","PASS " if Value else "FAIL ",Label)

func Until(Test: Callable, Seconds := 12.0) -> bool:
    var Deadline := Time.get_ticks_msec()+int(Seconds*1000)
    while Time.get_ticks_msec()<Deadline:
        if Test.call(): return true
        await process_frame
    return false

func State() -> Dictionary:
    return Game.Snapshot

func Character() -> Node3D:
    return Game.get_node_or_null("Workspace/LocalPlayer") as Node3D

func Key(Code: Key, Down: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code; Event.physical_keycode = Code; Event.pressed = Down
    Input.parse_input_event(Event)

func Press(Code: Key) -> void:
    Key(Code,true)
    await create_timer(0.07).timeout
    Key(Code,false)
    await create_timer(0.1).timeout

func Mouse(Button: MouseButton, Down: bool) -> void:
    var Event := InputEventMouseButton.new()
    Event.button_index = Button; Event.pressed = Down
    Input.parse_input_event(Event)

func StopMove() -> void:
    for Code in [KEY_W,KEY_A,KEY_S,KEY_D]: Key(Code,false)

func GoTo(Target: Vector3, Seconds := 10.0) -> bool:
    # Offscreen NO_FOCUS execution uses synthetic focus, never OS activation.
    Game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    StopMove()
    await process_frame
    var Deadline := Time.get_ticks_msec()+int(Seconds*1000)
    while Character() and Time.get_ticks_msec()<Deadline:
        var C := Character()
        var Direction := Target-C.global_position
        Direction.y = 0
        if Direction.length()<2.2: StopMove(); await create_timer(0.15).timeout; return true
        var Camera := root.get_camera_3d()
        if Camera:
            var Side := Direction.normalized().dot(Camera.global_basis.x)
            var Forward := Direction.normalized().dot(Camera.global_basis.z)
            Key(KEY_D,Side>0.3); Key(KEY_A,Side< -0.3)
            Key(KEY_W,Forward< -0.3); Key(KEY_S,Forward>0.3)
        await create_timer(0.05).timeout
    StopMove()
    print("[Game:Playtest] route timeout target=",Target," position=",Character().global_position if Character() else Vector3.ZERO," focus=",root.gui_get_focus_owner()," window=",root.has_focus()," menu=",Game.get_meta("PlayerControllerMenu",false)," health=",Character().call("get_health") if Character() else -1)
    return false

func Aim(Target: Vector3) -> void:
    Game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    Mouse(MOUSE_BUTTON_RIGHT,true)
    for I in range(45):
        if not Character() or not root.get_camera_3d(): break
        var Desired := (Target-Character().global_position-Vector3(0,1.5,0)).normalized()
        var Forward := -root.get_camera_3d().global_basis.z
        var Yaw := wrapf(atan2(-Desired.x,-Desired.z)-atan2(-Forward.x,-Forward.z),-PI,PI)
        var Pitch := asin(clampf(Desired.y,-1,1))-asin(clampf(Forward.y,-1,1))
        if absf(Yaw)<0.015 and absf(Pitch)<0.015: break
        var Event := InputEventMouseMotion.new()
        Event.relative = Vector2(clampf(-Yaw/0.0022,-200,200),clampf(-Pitch/0.0022,-200,200))
        Input.parse_input_event(Event)
        await create_timer(0.035).timeout

func Run() -> void:
    Started = Time.get_ticks_msec()
    Game = load("res://Main.tscn").instantiate()
    root.add_child(Game)
    current_scene = Game
    await process_frame
    if Scenario == "server":
        Check(await Until(func(): return Game.get_meta("ServerReady",false),12),"actual dedicated game Server ready")
        while not FileAccess.file_exists("res://stop-game"):
            await process_frame
        Check(State().get("Progress",{}).get("Wins",0)>=1,"dedicated server commits actual team victory")
        Finish(); return
    if not Game.Session:
        Check(Game.Menu.visible,"functional main menu")
        for Child in Game.Menu.get_child(0).get_children():
            if Child is Button and Child.text == "PLAY SOLO": Child.pressed.emit(); break
    var Ready := await Until(func(): return Game.get_meta("ClientReady",false) and Game.get_meta("PlayerControllerRunning",false) and State().get("Phase","")=="Active",20)
    Check(Ready,"actual Luau game, native Character and Scripted controller ready")
    if not Ready: Finish(); return
    var Original := Character().get_instance_id()
    Check(Character().call("GetControllerMode")==1,"explicit Scripted opt-in")
    if Scenario == "coop":
        Check(await Until(func(): return State().get("Players",[]).size()==4,20),"four actual ENet players share the arena")
    var Before := Character().global_position
    Key(KEY_W,true); await create_timer(0.35).timeout; Key(KEY_W,false)
    await create_timer(0.15).timeout
    Check(Character().global_position.distance_to(Before)>1,"actual input moves native Character")
    await Press(KEY_SPACE)
    Check(Character().call("GetPhysicsBody").velocity.y>0,"actual input jumps")
    await create_timer(1).timeout
    Game.ScriptRun("SoftBodyVisibility","local C=game.Workspace.PhysicsCanopy; assert(C:IsA('SoftBody3D')); game:SetAttribute('SoftBodyLuauVisible',typeof(C.Position)=='Vector3')",true)
    await create_timer(0.1).timeout
    Check(Game.get_meta("SoftBodyLuauVisible",false),"Luau can observe actual SoftBody3D identity and transform")
    var Canopy: SoftBody3D = Game.World.get_node("PhysicsCanopy")
    var Pinned := Canopy.get_point_transform(0)
    await Press(KEY_O)
    await create_timer(0.4).timeout
    Check(Canopy.get_point_transform(0).distance_to(Pinned)>0.1,"local semantic interaction releases actual native soft-body anchor")
    if Scenario == "combat":
        await Until(func(): return State().get("Bots",[]).size()>0,6)
        var Bot: Dictionary = State().Bots[0]
        await Aim(Vector3(Bot.Position.X,Bot.Position.Y,Bot.Position.Z))
        Mouse(MOUSE_BUTTON_LEFT,true)
        await create_timer(0.2).timeout
        var InputRoot := Game.get_node("InputService")
        print("[Game:Playtest] mouse state ",JSON.stringify({"Shoot":InputRoot.get_node("RelaySiegeWeapon/Shoot").call("GetValue"),"Capture":InputRoot.get_node("PlayerControllerGameplay/Capture").call("GetValue"),"Motion":str(InputRoot.get_node("PlayerControllerGameplay/MouseLook").call("GetValue")),"WeaponEnabled":InputRoot.get_node("RelaySiegeWeapon").get("Enabled"),"MovementEnabled":InputRoot.get_node("PlayerControllerGameplay").get("Enabled"),"Direction":str(-root.get_camera_3d().global_basis.z)}))
        await create_timer(0.8).timeout
        Mouse(MOUSE_BUTTON_LEFT,false)
        print("[Game:Playtest] focused combat localshots=",Game.get_meta("LocalShot",0)," ",JSON.stringify(State()))
        Check(State().get("Shots",0)>=2,"held input submits actual weapon intent")
        Finish(); return
    if Scenario == "recovery":
        Check(State().Progress.Rounds>=2 and State().Progress.Wins>=1,"fresh process recovers acknowledged career progress")
        Finish(); return
    if Scenario == "observer":
        Check(await Until(func(): return State().get("Players",[]).size()>=2,20),"real ENet peer roster")
        var Epoch: int = State().Round
        Check(await Until(func(): return State().get("Phase","")=="Victory",110),"observer receives authoritative victory")
        Check(State().Round==Epoch,"shared round identity")
        Finish(); return
    var Health: float = Character().call("get_health")
    var Epoch: int = State().Round
    Game.ScriptRun("RejectForgedRules","""
local R = game.ReplicatedStorage.Request
local Epoch = %d
pcall(function() game.Players.LocalPlayer.Character.Health=1 end)
R:FireServer('Victory',Epoch,999999)
task.wait(0.06)
R:FireServer('Damage',Epoch,999999)
task.wait(0.06)
R:FireServer('Interact',Epoch+99,1)
task.wait(0.06)
R:FireServer('Shoot',Epoch,{X=1,Y=0,Z=0})
task.wait(0.06)
R:FireServer('Shoot',Epoch,Vector3.new(100,0,0))
game:SetAttribute('InvalidGameRequestsDone',true)
""" % Epoch,true)
    Check(await Until(func(): return Game.get_meta("InvalidGameRequestsDone",false),3),"adversarial requests traverse actual public game endpoint")
    await create_timer(0.3).timeout
    Check(State().Phase=="Active" and State().Round==Epoch and State().Kills==0 and State().Relays==[false,false,false],"clients cannot claim victory, kills, damage or stale-round interactions")
    Check(Character().call("get_health")==Health,"Client cannot overwrite authoritative health")
    Check(await GoTo(Vector3(-16,0,14)),"walk to physics playground")
    var Crate: Node3D = Game.World.get_node_or_null("ImpulseCrate")
    if Crate:
        var CrateBefore := Crate.global_position
        await Press(KEY_P)
        await create_timer(0.25).timeout
        Check(Crate.global_position.distance_to(CrateBefore)>0.5,"Luau interaction applies native rigid-body impulse")
        print("[Game:Playtest] crate before=",CrateBefore," after=",Crate.global_position)
    for Position in [Vector3(-14,0,-10),Vector3(14,0,-10),Vector3(0,0,-20)]:
        Check(await GoTo(Position),"walk to relay "+str(Position))
        await Press(KEY_E)
    Check(await Until(func(): return State().Relays==[true,true,true],3),"three authoritative interactions activate relays")
    var Deadline := Time.get_ticks_msec()+70000
    var Samples := 0
    while State().get("Phase","")=="Active" and Time.get_ticks_msec()<Deadline:
        var Mine: Dictionary = {}
        for P in State().Players:
            if int(P.Id)==int(Game.get_meta("LocalUserId",0)): Mine=P
        if Mine.get("Ammo",0)==0: await Press(KEY_R); await create_timer(1.5).timeout
        if State().Bots.size()>0 and Character() and Character().call("get_health")>0:
            var Bot: Dictionary = State().Bots[0]
            var Target := Vector3(Bot.Position.X,Bot.Position.Y,Bot.Position.Z)
            if Character().global_position.distance_to(Target)>18:
                await GoTo(Target,2.0)
            await Aim(Target)
            Mouse(MOUSE_BUTTON_LEFT,true)
            await create_timer(0.6).timeout
            Mouse(MOUSE_BUTTON_LEFT,false)
            if Samples < 8:
                Samples += 1
                print("[Game:Playtest] combat ",JSON.stringify({"Position":str(Character().global_position),"Forward":str(-root.get_camera_3d().global_basis.z),"Target":str(Target),"Kills":State().Kills,"Shots":State().get("Shots",0),"Ammo":Mine.get("Ammo",0)}))
        else: await create_timer(0.2).timeout
    Mouse(MOUSE_BUTTON_RIGHT,false)
    Check(State().get("Kills",0)>=6,"actual weapon defeats six authoritative drones")
    Check(State().get("Phase","")=="Victory","complete playable victory")
    Check(await Until(func(): return State().get("Save","")=="Saved",8),"round result acknowledged by actual DataStore")
    var ResultPose := Character().global_position
    Key(KEY_W,true)
    await create_timer(0.2).timeout
    Check(Character().global_position.distance_to(ResultPose)<0.03,"results suspend existing movement context")
    if Graphical:
        await RenderingServer.frame_post_draw
        var ImageName := "victory.png" if State().get("Phase","")=="Victory" else "failed-round.png"
        var Saved := root.get_texture().get_image().save_png("res://"+ImageName)==OK
        if Saved: Screenshot = ImageName
        Check(Saved,"rendered game and results captured")
    Game.set_meta("UIRequest","Again")
    Check(await Until(func(): return State().get("Phase","")=="Active",4),"results UI starts another round")
    await create_timer(0.2).timeout
    var StartPose := Character().global_position
    await create_timer(0.15).timeout
    Check(Vector2(Character().global_position.x-StartPose.x,Character().global_position.z-StartPose.z).length()<0.03,"held result-screen input cannot reactivate in the next round")
    Key(KEY_W,false)
    await GoTo(Vector3(6,0,12))
    await GoTo(Vector3(6,0,-9))
    Check(await GoTo(Vector3(0,0,-9)),"walk into marked hazard")
    Check(await Until(func(): return Character() and Character().get_instance_id()!=Original,35),"damage, death and native automatic respawn")
    Check(await Until(func(): return Game.get_meta("PlayerControllerRunning",false),4),"controller follows replacement Character")
    Check(await Until(func(): return State().get("Phase","")=="Defeat",100),"reactor pressure produces real failure condition")
    Check(await Until(func(): return State().get("Save","")=="Saved",8),"failed round also persists")
    Finish()

func Finish() -> void:
    StopMove()
    Mouse(MOUSE_BUTTON_LEFT,false); Mouse(MOUSE_BUTTON_RIGHT,false)
    var Failed := Cases.filter(func(C): return not C.Passed).size()
    var Report := {"Cases":Cases,"Failed":Failed,"Scenario":Scenario,"Graphical":Graphical,"Screenshot":Screenshot,"Seconds":float(Time.get_ticks_msec()-Started)/1000,"Frames":Frames,"MeanFrameMS":Elapsed/maxi(1,Frames)*1000,"PeakFrameMS":MaxGap*1000,"NativeObjects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"Snapshot":State()}
    var File := FileAccess.open("res://gameplay-result.json",FileAccess.WRITE)
    File.store_string(JSON.stringify(Report)); File.close()
    print("[Game:Playtest] ","PASS" if Failed==0 else "FAIL"," scenario=",Scenario," cases=",Cases.size())
    await Game.Shutdown(0 if Failed==0 else 1)
