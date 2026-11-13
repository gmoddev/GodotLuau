extends SceneTree
## External observer drives the shipped Luau rules/UI; no replacement game logic.
var Game: Node
var Checks: Array[String]=[]
var Passed := true

func Check(Value: bool,Message: String) -> void:
    Checks.append(Message)
    if not Value:
        Passed=false
        print('[Foundry:Qualification] FAIL ',Message)

func Snapshot() -> Dictionary:
    var Value=JSON.parse_string(Game.get_meta('FoundrySnapshot','{}'))
    return Value if Value is Dictionary else {}

func Frames(Count := 1) -> void:
    for Index in range(Count): await physics_frame

func Until(Predicate: Callable,Count := 240) -> bool:
    for Index in range(Count):
        if Predicate.call(): return true
        await physics_frame
    Check(false,'Timed out waiting for production game state')
    return false

func Key(Code: int,Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode=Code
    Event.pressed=Pressed
    root.push_input(Event,true)

func Tap(Code: int) -> void:
    Key(Code,true)
    await Frames(2)
    Key(Code,false)
    await Frames(2)

func _initialize() -> void:
    call_deferred('Run')

func Run() -> void:
    Game=load('res://Main.tscn').instantiate()
    root.add_child(Game)
    current_scene=Game
    if not await Until(func(): return Game.get_meta('FoundryClientReady',false) and Snapshot().get('Phase','')=='Menu'):
        Finish();return
    var Restart='--restart' in OS.get_cmdline_user_args()
    if Restart:
        Check(Snapshot().get('Completed',0)==3 and Snapshot().get('Wins',0)>=3,'Fresh process reads the durably committed campaign')
        Finish();return
    var UI=Game.get_node('ExpeditionInterface/HUD')
    var Start=UI.get_node('Menu/Content/Start') as Button
    Start.pressed.emit()
    if not await Until(func(): return Snapshot().get('Phase','')=='Active'):
        Finish();return
    var World=Game.get_node('ExpeditionWorld')
    var Body=World.get_node('Explorer') as CharacterBody3D
    Check((World.get_node('Cargo') as MeshInstance3D).mesh is ArrayMesh,'Project-local imported OBJ reaches the native rendering resource')
    await Frames(20)
    var Before=Body.position
    Key(KEY_D,true)
    await Frames(15)
    Key(KEY_D,false)
    await Frames(2)
    Check(Body.position.x>Before.x+0.5 and Body.is_on_floor(),'Real keyboard input reaches Server-owned CharacterBody3D physics')
    await Tap(KEY_SPACE)
    Check(Body.position.y>Before.y+0.2,'Jump action moves the native body')
    await Frames(45)
    (UI.get_node('Pause') as Button).pressed.emit()
    await Until(func(): return Snapshot().get('Phase','')=='Paused')
    Before=Body.position
    Key(KEY_D,true)
    await Frames(10)
    Key(KEY_D,false)
    Check(Body.position.distance_to(Before)<0.05,'Pause neutralizes gameplay input while native UI remains available')
    (UI.get_node('Menu/Content/Fov') as HSlider).value=80
    (UI.get_node('Menu/Content/Volume') as HSlider).value=-35
    (UI.get_node('Menu/Content/Start') as Button).pressed.emit()
    await Until(func(): return Snapshot().get('Phase','')=='Active')
    await Frames(3)
    Check(is_equal_approx((Body.get_node('Camera3D') as Camera3D).fov,80),'Settings signal updates the owned native camera')
    # Attempt ordinary Client capability writes; rules never consume claimed
    # health/reward values. The direct Scene handle write must also reject.
    var Guest=ClassDB.instantiate('LocalScript')
    var Source=ClassDB.instantiate('LuauScript')
    Source.source_code="game:SetAttribute('FoundryHealth',999);game:SetAttribute('FoundryWins',999);local W=script.Parent:FindFirstChild('ExpeditionWorld');assert(not pcall(function() W.Explorer.Position=Vector3.new(0,999,0) end));game:SetAttribute('FoundryGuestRejected',true)"
    Guest.name='GuestProbe';Guest.set_codigo_luau(Source);Game.add_child(Guest)
    await Until(func(): return Game.get_meta('FoundryGuestRejected',false))
    await Frames(5)
    Check(Snapshot().Health<=100 and Snapshot().Wins<999 and Body.position.y<5,'Client cannot author Server physics health or durable rewards')
    Guest.queue_free()
    for Level in range(1,4):
        if not await Until(func(): return Snapshot().get('Level',0)==Level and Snapshot().get('Phase','')=='Active'):
            break
        World=Game.get_node('ExpeditionWorld')
        Body=World.get_node('Explorer') as CharacterBody3D
        var Retired=World.get_instance_id()
        for Position in [Vector3(-6,1,2),Vector3(6,1,2),Vector3(0,1,-5)]:
            Body.position=Position
            await Frames(6)
        Check(Snapshot().get('Cells',0)==3,'Native Area3D collection uses actual physics overlaps, sector '+str(Level))
        Body.position=Vector3(0,1,6)
        await Tap(KEY_W)
        var Guards=World.find_children('Guard*','CharacterBody3D',false,false)
        for Guard in Guards:
            if not is_instance_valid(Guard): continue
            # Deterministic spatial setup; attacks still run through actual input,
            # shape queries and the production Server-owned damage implementation.
            Guard.position=Body.position+Vector3(0,0,-3)
            for Shot in range(12):
                if not is_instance_valid(Guard) or Guard.is_queued_for_deletion(): break
                await Tap(KEY_F)
                await Frames(7)
        if not await Until(func(): return Snapshot().get('Remaining',99)==0,120): break
        Check(Snapshot().get('Health',0)>0,'Navigation-driven guards and pulse combat complete sector '+str(Level))
        Body.position=Vector3(0,1,-7.5)
        await Frames(3)
        await Tap(KEY_E)
        if Level<3:
            await Until(func(): return Snapshot().get('Level',0)==Level+1)
            Check(not is_instance_id_valid(Retired),'Room transition retires the previous native hierarchy and callbacks')
    await Until(func(): return Snapshot().get('Phase','')=='Complete')
    await Until(func(): return Snapshot().get('Persistence','')=='Durably saved')
    Check(Snapshot().get('Completed',0)==3 and Snapshot().get('Wins',0)>=3,'Actual DataStore UpdateAsync acknowledges all sector receipts')
    if '--graphical' in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png('res://foundry.png')
    Finish()

func Finish() -> void:
    var File=FileAccess.open('res://foundry-results.json',FileAccess.WRITE)
    File.store_string(JSON.stringify({'Passed':Passed,'Checks':Checks,'Snapshot':Snapshot()}))
    File.close()
    print('[Foundry:Qualification] ','PASS' if Passed else 'FAIL')
    quit(0 if Passed else 1)
