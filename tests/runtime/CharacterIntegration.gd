extends SceneTree

var Game: Node
var Network: Node
var World: Node
var Role := "server"
var Mode := "Dedicated"
var Port := 0
var Index := 0
var Failed := false
var First := 0
var Second := 0
var Sequence := 0
var LastSent := Vector3.ZERO

func Check(Value: bool, Description: String) -> void:
    if not Value:
        Failed = true
        print("[Network:CharacterTest] FAIL ", Role, " ", Description)

func Mark(Name: String, Value := "ready") -> void:
    var File := FileAccess.open("res://character-" + Name, FileAccess.WRITE)
    File.store_string(Value)
    File.close()

func Read(Name: String) -> String:
    return FileAccess.get_file_as_string("res://character-" + Name)

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 12000
    while not FileAccess.file_exists("res://character-" + Name):
        if Time.get_ticks_msec() >= Deadline:
            Check(false, "barrier " + Name)
            quit(1)
            return
        await process_frame

func Drain() -> void:
    await create_timer(1.0 if Mode == "Latency" else 0.25).timeout

func Create(Type: String, Name: String, Parent: Node = null) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    (Parent if Parent != null else Game).add_child(Result)
    return Result

func Script(Name: String, Source: String, Client := false) -> void:
    var Result: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)

func Freeze() -> void:
    for Character in World.get_children():
        if Character.is_class("RBXCharacter") or Character.is_class("RobloxPlayer2D"):
            Character.set_process(false)
            Character.set_physics_process(false)
            if Character.has_node("PhysicsBody"):
                Character.get_node("PhysicsBody").set_process(false)
                Character.get_node("PhysicsBody").set_physics_process(false)

func Puppet(Peer: int) -> Node:
    return World.find_child("RemotePlayer_" + str(Peer), true, false)

func States() -> Dictionary:
    return Network.call("GetCharacterStates")

func Send(Position: Vector3, Speed := 0.0, Air := false, Epoch := -1, Packet := -1) -> void:
    var Peer: int = Network.call("get_peer_id")
    var Grant: Dictionary = States()[Peer]
    LastSent = Position
    Sequence += 1
    Network.rpc_id(1, "_relay_character", Grant.Epoch if Epoch < 0 else Epoch,
        Sequence if Packet < 0 else Packet, Position, 0.0, Speed, Air)

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size() - 1):
        if Args[Position] == "--fixture-role": Role = Args[Position + 1]
        if Args[Position] == "--fixture-port": Port = int(Args[Position + 1])
        if Args[Position] == "--fixture-client-index": Index = int(Args[Position + 1])
        if Args[Position] == "--character-mode": Mode = Args[Position + 1]
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "load")
    Game = Node.new()
    Game.name = "Game"
    Game.set_meta("Port", Port)
    root.add_child(Game)
    current_scene = Game
    Create("Players", "Players")
    Create("RunService", "RunService")
    Network = Create("NetworkService", "NetworkService")
    # Suppress unrelated menu construction without replacing native characters.
    var Settings := Node.new()
    Settings.name = "SettingsMenu"
    Game.add_child(Settings)
    World = Create("RobloxWorkspace2D" if Mode == "TwoD" else "RobloxWorkspace", "Workspace")
    World.set_process(false)
    if Mode in ["Movement", "Latency"]:
        var Floor := StaticBody3D.new()
        var Shape := CollisionShape3D.new()
        var Box := BoxShape3D.new()
        Box.size = Vector3(1000, 1, 1000)
        Shape.shape = Box
        Floor.position.y = -1.5
        Floor.add_child(Shape)
        Game.add_child(Floor)
    if Mode == "TwoD":
        var Floor := StaticBody2D.new()
        var Shape := CollisionShape2D.new()
        var Box := RectangleShape2D.new()
        Box.size = Vector2(10000, 20)
        Shape.shape = Box
        Floor.position = Vector2(0, 300)
        Floor.add_child(Shape)
        Game.add_child(Floor)
    await process_frame
    Freeze()
    if Mode == "Local":
        var Hum := World.get_node("LocalPlayer")
        Hum.call("take_damage", 25.0)
        Check(Hum.call("get_health") == 75.0, "native damage")
        Hum.call("heal", 5.0)
        Check(Hum.call("get_health") == 80.0, "native healing")
        var Player := AnimationPlayer.new()
        var Library := AnimationLibrary.new()
        var GameplayClip := Animation.new()
        GameplayClip.length = 10.0
        var GameplayTrack := GameplayClip.add_track(Animation.TYPE_VALUE)
        GameplayClip.track_set_path(GameplayTrack, NodePath(".:Health"))
        GameplayClip.track_insert_key(GameplayTrack, 0.0, 1.0)
        Library.add_animation("TrustedHealth", GameplayClip)
        Player.add_animation_library("", Library)
        World.get_node("LocalPlayer").add_child(Player)
        Script("ClientHealth", "local H = game:GetService('Players').LocalPlayer.Character; H.Health = 1; H:TakeDamage(10); H.MaxHealth = 1; game:SetAttribute('ClientDone', true)", true)
        Script("ClientTimeline", "local H = game:GetService('Players').LocalPlayer.Character; H:LoadAnimation('TrustedHealth'):Play(); game:SetAttribute('ClientTimelineDone', true)", true)
        Script("ClientCatalog", "assert(not game:GetService('NetworkService'):RegisterCharacterAnimation('res://CharacterAssetScript.gd')); game:SetAttribute('ClientCatalogDone', true)", true)
        await Drain()
        Check(Game.has_meta("ClientDone") and Hum.call("get_health") == 80.0 and Hum.call("get_max_health") == 100.0, "Client VM cannot mutate shared health")
        Hum.call("set_health", NAN)
        Hum.call("take_damage", INF)
        Hum.call("heal", -10.0)
        Check(Hum.call("get_health") == 80.0, "invalid health rejects without effects")
        Check(Game.has_meta("ClientTimelineDone"), "client animation path exercised")
        Check(Game.has_meta("ClientCatalogDone"), "Client VM cannot register catalog assets")
        Script("ServerTimeline", "game:GetService('Workspace').LocalPlayer:LoadAnimation('TrustedHealth'):Play()")
        await Drain()
        Check(Hum.call("get_health") == 1.0, "trusted server gameplay timeline remains supported")
        Script("ClientTrackControls", "local T = game:GetService('Players').LocalPlayer.Character:LoadAnimation('TrustedHealth'); T.Looped = true; T.Speed = 0; T:Stop(); game:SetAttribute('TrackControlsDone', true)", true)
        await Drain()
        Check(Game.has_meta("TrackControlsDone") and Player.is_playing() and Player.speed_scale == 1.0 and GameplayClip.loop_mode == Animation.LOOP_NONE, "Client track settings cannot control a server gameplay timeline")
        Player.stop()
        var DeferredScript := GDScript.new()
        DeferredScript.source_code = "extends Animation\nfunc _init():\n    var Tree = Engine.get_main_loop()\n    if Tree is SceneTree:\n        Tree.current_scene.call_deferred('set_meta', 'UntrustedInitializer', true)\n        var H = Tree.root.find_child('LocalPlayer', true, false)\n        if H != null: H.call_deferred('set_health', 1.0)\n"
        Check(ResourceSaver.save(DeferredScript, "res://CharacterDeferredScript.gd") == OK and DeferredScript.reload() == OK, "deferred initializer source")
        var DeferredClip := Animation.new()
        DeferredClip.set_script(DeferredScript)
        Check(ResourceSaver.save(DeferredClip, "res://CharacterDeferred.tres") == OK, "deferred initializer asset")
        await Drain()
        Game.remove_meta("UntrustedInitializer")
        Hum.call("set_health", 80.0)
        var DeferredObject := Create("AnimationObject", "DeferredClip")
        DeferredObject.call("set_animation_id", "res://CharacterDeferred.tres")
        Script("ClientResourceLoad", "game:GetService('Players').LocalPlayer.Character:LoadAnimation(game.DeferredClip); game:SetAttribute('ClientLoadDone', true)", true)
        await Drain()
        Check(Game.has_meta("ClientLoadDone") and not Game.has_meta("UntrustedInitializer") and Hum.call("get_health") == 80.0, "Client resource selection cannot execute deferred initializer effects")
        var ExportClip := Animation.new()
        Check(ResourceSaver.save(ExportClip, "res://CharacterExported.res") == OK, "exported binary resource")
        var Remap := ConfigFile.new()
        Remap.set_value("remap", "path", "res://CharacterExported.res")
        Check(Remap.save("res://CharacterExported.tres.remap") == OK, "export remap prepared")
        Check(not FileAccess.file_exists("res://CharacterExported.tres") and Network.call("RegisterCharacterAnimation", "res://CharacterExported.tres"), "catalog reads a remapped binary without the source text resource")
        var Temporary := Create("RBXCharacter", "TemporaryHumanoid")
        Script("CallbackLifetime", "local H = game.TemporaryHumanoid; H.Died:Connect(function() end); H.HealthChanged:Connect(function() end); H.StateChanged:Connect(function() end); shared.RetainedHealthConnect = H.HealthChanged.Connect; game:SetAttribute('CallbacksRegistered', true)")
        await Drain()
        Check(Game.has_meta("CallbacksRegistered"), "native signal registrations exercised")
        var Host := Game.get_node("GodotLuauRuntime")
        var RegisteredReferences: int = Host.call("GetResourceStats", false).References
        Temporary.free()
        Check(int(Host.call("GetResourceStats", false).References) == RegisteredReferences - 3, "destroyed Humanoid releases native callback references")
        Script("RetainedSignal", "shared.RetainedHealthConnect(function() error('dead signal dispatched') end); game:SetAttribute('RetainedSignalSafe', true)")
        await Drain()
        Check(Game.has_meta("RetainedSignalSafe"), "retained signal view resolves destroyed native identity")
        var Identity := Hum.get_instance_id()
        Hum.connect("HealthChanged", func(_New: float, _Old: float) -> void: Hum.queue_free())
        Hum.call("set_health", 70.0)
        await process_frame
        Check(not is_instance_id_valid(Identity), "destruction during health callback")
    elif Role == "server":
        await Server()
    else:
        await Client()
    print("[Network:CharacterTest] ", Role, " ", "FAIL" if Failed else "PASS")
    Game.free()
    await process_frame
    quit(1 if Failed else 0)

func Server() -> void:
    if Mode != "Listen": World.get_node("LocalPlayer").free()
    if Mode in ["Movement", "Latency"]:
        Script("SpawnPolicy", "game:GetService('Players').PlayerAdded:Connect(function(P) P.CharacterAdded:Connect(function(C) C.Position = Vector3.new(P.UserId * 10, 5, 0) end) end)")
    Script("Start", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4))")
    while not Network.call("is_connected_net"): await process_frame
    var Clip := Animation.new()
    Clip.length = 0.1
    var Track := Clip.add_track(Animation.TYPE_VALUE)
    Clip.track_set_path(Track, NodePath(".:Health"))
    Clip.track_insert_key(Track, 0.0, 1.0)
    Check(ResourceSaver.save(Clip, "res://CharacterHealthAttack.tres") == OK, "attack asset prepared")
    var MethodClip := Animation.new()
    Track = MethodClip.add_track(Animation.TYPE_METHOD)
    MethodClip.track_set_path(Track, NodePath("."))
    MethodClip.track_insert_key(Track, 0.0, {"method": "take_damage", "args": [50.0]})
    Check(ResourceSaver.save(MethodClip, "res://CharacterMethodAttack.tres") == OK, "method asset prepared")
    var RootClip := Animation.new()
    Track = RootClip.add_track(Animation.TYPE_POSITION_3D)
    RootClip.track_set_path(Track, NodePath("."))
    RootClip.track_insert_key(Track, 0.0, Vector3(9999, 0, 0))
    Check(ResourceSaver.save(RootClip, "res://CharacterRootAttack.tres") == OK, "root asset prepared")
    var Attached := GDScript.new()
    Attached.source_code = "extends Animation\nfunc _init():\n    var Tree = Engine.get_main_loop()\n    if Tree is SceneTree:\n        Tree.current_scene.set_meta('ScriptedLoads', int(Tree.current_scene.get_meta('ScriptedLoads', 0)) + 1)\n        for Body in Tree.root.find_children('RemotePlayer_*', '', true, false):\n            var Hum = Body\n            if Hum != null: Hum.call('set_health', 1.0)\n"
    Check(ResourceSaver.save(Attached, "res://CharacterAssetScript.gd") == OK, "scripted asset source prepared")
    Check(Attached.reload() == OK, "scripted asset compiled")
    var ScriptedClip := Animation.new()
    ScriptedClip.set_script(Attached)
    Check(ResourceSaver.save(ScriptedClip, "res://CharacterScriptedAttack.tres") == OK, "scripted asset prepared")
    var SafeClip := Animation.new()
    SafeClip.length = 2.0
    if Mode != "TwoD":
        Track = SafeClip.add_track(Animation.TYPE_SCALE_3D)
        SafeClip.track_set_path(Track, NodePath("Visual"))
        SafeClip.track_insert_key(Track, 0.0, Vector3.ONE)
        SafeClip.track_insert_key(Track, 1.0, Vector3(0.98, 0.98, 0.98))
    Check(ResourceSaver.save(SafeClip, "res://CharacterSafeRig.tres") == OK, "safe rig asset prepared")
    Check(Network.call("RegisterCharacterAnimation", "res://CharacterSafeRig.tres"), "server catalog registration")
    for Asset in ["HealthAttack", "MethodAttack", "RootAttack", "ScriptedAttack"]:
        Check(not Network.call("RegisterCharacterAnimation", "res://Character" + Asset + ".tres"), "unsafe catalog entry rejected " + Asset)
    var ScriptedLoads := int(Game.get_meta("ScriptedLoads", 0))
    Mark("ready")
    await Wait("client1.protocol2")
    await Wait("client2.protocol2")
    await Drain()
    Check(not States().has(int(Read("client1.protocol2"))) and not States().has(int(Read("client2.protocol2"))), "protocol 2 cannot activate a writer")
    Mark("protocol.checked")
    await Wait("client1.ready")
    await Wait("client2.ready")
    First = int(Read("client1.ready"))
    Second = int(Read("client2.ready"))
    Check(States().has(First) and States().has(Second), "two server-authorized lives")
    var Original: Vector3 = States()[First].Position
    var InitialEpoch: int = States()[First].Epoch
    var Character := Puppet(First)
    var Health := HealthNode(Character)
    if Mode != "TwoD":
        Check(Character.is_class("RBXCharacter") and Character.is_class("RBXModel") and not Character.has_node("Humanoid") and Character.has_node("Animator"), "server remote has actual Character/Model identity")
    Health.call("take_damage", 25.0)
    await Drain()
    var Invalid: Dictionary = States()[First].Contract.duplicate(true)
    if Mode == "TwoD": Invalid.Version = 2
    else: Invalid.Pose = Transform3D(Basis().scaled(Vector3(2, 1, 1)), Original)
    Network.rpc("_recv_character", First, InitialEpoch + 999, 9999, Original, 0.0, 1.0, 100.0, 0.0, false, Mode == "TwoD", InitialEpoch, Invalid)
    Mark("attack")
    await Wait("attacked")
    await Drain()
    print("[Network:CharacterTest] post-attack state ", States()[First])
    Check(States()[First].Position == Original and States()[First].Health == 75.0, "legacy/invalid health and pose rejected")
    Check(States()[First].Sequence == 0, "all rejected inputs leave sequence unchanged")
    Check(Network.call("GetAnimationStates").get(First, {}).get("Name", "") == "SafeRig", "gameplay animation attempts do not replace the safe presentation cache")
    Check(int(Game.get_meta("ScriptedLoads", 0)) == ScriptedLoads, "client packet cannot execute a resource initializer")
    if Mode == "Listen":
        var SharedId := Character.get_instance_id()
        var SharedYaw: Vector3 = Character.global_rotation
        Game.set_meta("SharedTarget", Character.name)
        Script("SharedClientAuthority", "local C = game:GetService('Workspace')[game:GetAttribute('SharedTarget')]; C.Rotation = Vector3.new(0,90,0); C.Scale = Vector3.new(2,2,2); C:PivotTo(CFrame.new(2000,0,0)); C:MoveTo(Vector3.new(2000,0,0)); C:SetAttribute('ClientGameplay', 1); C.Animator:Destroy(); C:ClearAllChildren(); C:Destroy(); game:SetAttribute('SharedAttacksDone', true)", true)
        await Drain()
        Check(Game.has_meta("SharedAttacksDone") and is_instance_id_valid(SharedId) and Character.is_class("RBXCharacter") and Character.has_node("Animator") and not Character.has_meta("ClientGameplay") and Character.global_rotation == SharedYaw, "shared Client cannot rotate or destroy a server character")
    Mark("valid")
    await Wait("valid.sent")
    await Drain()
    Check(States()[First].Position.x > Original.x and States()[First].Position.x < Original.x + (40 if Mode in ["Movement", "Latency"] else 2), "bounded movement admitted")
    if Mode in ["Movement", "Latency"]:
        var Measured: Dictionary = JSON.parse_string(Read("valid.sent"))
        Check(absf(States()[First].Position.x - float(Measured.LastX)) < 1, "native controller samples reach observer baseline")
    var RateBefore: int = States()[First].RateRejectedInputs
    Mark("rate")
    await Wait("rate.sent")
    await Drain()
    Check(int(States()[First].RateRejectedInputs) > RateBefore, "native rate limiter rejects a valid-pose flood")
    var NamedPlayer := Character.get_node("AnimationPlayer") as AnimationPlayer
    var NamedLibrary := AnimationLibrary.new()
    NamedLibrary.add_animation("Walk", SafeClip)
    NamedPlayer.add_animation_library("Rig", NamedLibrary)
    Mark("named")
    await Wait("named.sent")
    await Drain()
    Check(NamedPlayer.current_animation == "Rig/Walk" and Network.call("GetAnimationStates")[First].Name == "Rig/Walk", "safe named-library playback preserves its qualified name")
    Mark("named.observe")
    await Wait("named.observed")
    Mark("aliases")
    await Wait("aliases.sent")
    await Drain()
    var Animator := Character.get_node("AnimationPlayer") as AnimationPlayer
    Check(Animator.get_animation_list().size() <= 2 and NamedLibrary.has_animation("Walk"), "arbitrary names cannot grow libraries or erase the original named clip")
    var Gameplay := Animation.new()
    Gameplay.length = 20.0
    var GameplayTrack := Gameplay.add_track(Animation.TYPE_VALUE)
    Gameplay.track_set_path(GameplayTrack, NodePath(".:Health"))
    Gameplay.track_insert_key(GameplayTrack, 0.0, 75.0)
    var GameplayLibrary := Animator.get_animation_library("")
    GameplayLibrary.add_animation("TrustedTimeline", Gameplay)
    var PriorAnimation: String = Network.call("GetAnimationStates")[First].Name
    Animator.play("TrustedTimeline")
    Mark("gameplay")
    await Wait("gameplay.sent")
    await Drain()
    Check(Animator.current_animation == "TrustedTimeline" and Animator.is_playing() and Network.call("GetAnimationStates")[First].Name == PriorAnimation, "presentation requests cannot stop or replace an active server gameplay timeline")
    Animator.stop()
    Mark("gameplay.inactive")
    await Wait("gameplay.inactive.sent")
    await Drain()
    Check(Animator.get_animation("TrustedTimeline") == Gameplay and Network.call("GetAnimationStates")[First].Name == PriorAnimation, "presentation aliases cannot overwrite an inactive gameplay clip")
    GameplayLibrary.remove_animation("TrustedTimeline")
    Mark("gameplay.checked")
    if Mode == "TwoD":
        Mark("plane")
        await Wait("plane.sent")
        await Drain()
        var Motion: Dictionary = JSON.parse_string(Read("plane.sent"))
        print("[Network:CharacterTest] 2D final admitted ", States()[First], " measured ", Motion)
        Check(absf(States()[First].Position.y - float(Motion.LastY)) < 10 and float(Motion.LastY) < 0, "native 2D platformer and sustained top-down input remain admitted")
    if Mode == "Movement":
        var AscentStart: Vector3 = States()[First].Position
        Mark("ascent")
        await Wait("ascent.sent")
        await Drain()
        var Rise: float = States()[First].Position.y - AscentStart.y
        Check(Rise > 0.1 and Rise < 5.2, "repeated airborne packets cannot accumulate unbounded ascent")
        var LimitedPosition: Vector3 = States()[First].Position
        Mark("ascent.sync")
        await Wait("ascent.sync.sent")
        await Drain()
        Check(States()[First].Position == LimitedPosition, "synchronization cannot grant another airborne jump")
    var Before: Vector3 = States()[First].Position
    var BeforeEpoch: int = States()[First].Epoch
    var Correction := Before + Vector3(1000, 0, 0)
    Character.set("global_position", Vector2(Correction.x, Correction.y) if Mode == "TwoD" else Correction)
    if Mode != "TwoD":
        Character.global_transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.05)).scaled(Vector3.ONE * 1.25), Correction)
        Character.call("SetAcceleration", 130.0)
        Character.call("SetAirAcceleration", 55.0)
        Character.call("SetTurnSpeed", 14.0)
        Character.call("set_auto_rotate", false)
        Character.call("set_max_health", 150.0)
    await Drain()
    Check(States()[First].Position == Correction and States()[First].Epoch > BeforeEpoch, "server correction changes baseline and epoch")
    Mark("corrected", str(BeforeEpoch))
    await Wait("stale.sent")
    await Drain()
    Check(States()[First].Position == Correction, "stale pre-correction input rejected")
    Mark("observe")
    await Wait("client2.observed")
    var OldId := Character.get_instance_id()
    Network.call("net_load_character", Network.call("player_node_for_peer", First))
    await Drain()
    Check(is_instance_valid(Puppet(First)) and Puppet(First).get_instance_id() != OldId, "server respawn replaces native character")
    Check(States()[First].Health == 100.0, "fresh server life resets health")
    Mark("respawn")
    await Wait("respawn.checked")
    var Players := Game.get_node("Players")
    Players.call("set_respawn_time", 0.05)
    Character = Puppet(First)
    OldId = Character.get_instance_id()
    Health = HealthNode(Character)
    Health.connect("Died", func() -> void: Game.set_meta("Died", int(Game.get_meta("Died", 0)) + 1))
    Health.call("set_health", 0.0)
    Health.call("set_health", 0.0)
    var RespawnDeadline := Time.get_ticks_msec() + 4000
    while is_instance_valid(Puppet(First)) and Puppet(First).get_instance_id() == OldId:
        Check(Time.get_ticks_msec() < RespawnDeadline, "automatic respawn deadline")
        if Time.get_ticks_msec() >= RespawnDeadline: break
        await process_frame
    Check(int(Game.get_meta("Died", 0)) == 1 and States()[First].Health == 100.0, "one death and one fresh automatic life")
    await Drain()
    Mark("automatic")
    await Wait("automatic.checked")
    var ResetLife: int = States()[First].Life
    Mark("reset")
    await Wait("reset.sent")
    var ResetDeadline := Time.get_ticks_msec() + 4000
    while States()[First].Life == ResetLife and Time.get_ticks_msec() < ResetDeadline: await process_frame
    Check(States()[First].Life > ResetLife and States()[First].Health == 100.0 and States()[Second].Health == 100.0, "native reset requests only its own server-authorized new life")
    var StableLife: int = States()[First].Life
    Mark("reset.checked", str(States()[First].Epoch))
    await Wait("reset.stale")
    await Drain()
    Check(States()[First].Life == StableLife and States()[First].Health == 100.0, "stale and immediate repeated reset cannot replace a fresh life")
    Mark("reset.done")
    Character = Puppet(First)
    if Mode != "TwoD":
        var Group := Node3D.new()
        Group.name = "CharacterGroup"
        World.add_child(Group)
        var ReparentIdentity := Character.get_instance_id()
        Character.reparent(Group, true)
        await process_frame
        Check(Puppet(First) != null and Puppet(First).get_instance_id() == ReparentIdentity, "same-tree reparent preserves native Character identity")
    Character = Puppet(First)
    Character.free()
    await process_frame
    Mark("destroyed")
    await Wait("destroyed.sent")
    await Drain()
    Check(Puppet(First) == null, "normal input and readiness cannot resurrect destroyed character")
    await Wait("client1.absent")
    await Wait("client2.absent")
    var RemovedState: Dictionary = States()[First]
    Network.rpc("_recv_character", First, RemovedState.Epoch, 99999, RemovedState.Position, 0.0, 100.0, 100.0, 0.0, false, Mode == "TwoD", RemovedState.Life, RemovedState.Contract)
    Network.rpc("_recv_anim_v2", First, RemovedState.Life, "res://CharacterSafeRig.tres", "StaleRemoved", 1.0, true, true)
    Mark("removed.stale")
    await Wait("client1.tombstone")
    await Wait("client2.tombstone")
    Network.call("net_load_character", Network.call("player_node_for_peer", First))
    await Drain()
    Check(Puppet(First) != null and States()[First].Life > RemovedState.Life, "trusted LoadCharacter restores a removed life")
    Mark("restored")
    await Wait("client1.restored")
    await Wait("client2.restored")
    Mark("done")
    await Wait("client1.closed")
    while Game.get_multiplayer().get_peers().has(First): await process_frame
    await process_frame
    Check(not States().has(First) and not Network.call("GetAnimationStates").has(First), "disconnect revokes character and animation state")
    Mark("reconnect")
    await Wait("client1.rejoined")
    var Rejoined := int(Read("client1.rejoined"))
    var RejoinedState: Dictionary = States()[Rejoined]
    Check(int(RejoinedState.Epoch) > InitialEpoch and RejoinedState.Health == 100.0, "reconnect creates a fresh authorized life")
    Mark("prior-session")
    await Wait("prior-session.sent")
    await Drain()
    Check(States()[Rejoined].Position == RejoinedState.Position and States()[Rejoined].Sequence == 0 and not Network.call("GetAnimationStates").has(Rejoined), "prior-session movement and animation cannot cross reconnect")
    var ServiceIdentity := Network.get_instance_id()
    var TargetPlayer: Node = Network.call("player_node_for_peer", Rejoined)
    # Resolve the real Player from the public Luau service; do not mock dispatch.
    Game.set_meta("CallbackTarget", TargetPlayer.name)
    Script("ReplacementCallback", "for _, P in game:GetService('Players'):GetPlayers() do if P.Name == game:GetAttribute('CallbackTarget') then P.CharacterAdded:Connect(function(C) " + ("game:GetService('NetworkService'):Destroy()" if Mode == "Listen" else "C:Destroy()") + " end) end end; game:SetAttribute('ReplacementCallbackReady', true)")
    await Drain()
    Check(Game.has_meta("ReplacementCallbackReady"), "replacement callback installed")
    Network.call("net_load_character", TargetPlayer)
    await Drain()
    if Mode == "Listen":
        Check(not is_instance_id_valid(ServiceIdentity), "service destruction during CharacterAdded is safe")
    else:
        Check(Puppet(Rejoined) == null, "character destruction during CharacterAdded is safe")
    Mark("rejoined.close")
    await Wait("client1.done")
    while Game.get_multiplayer().get_peers().has(Rejoined): await process_frame
    await process_frame
    Mark("client2.close")
    await Wait("client2.done")
    while Game.get_multiplayer().get_peers().size() > 0: await process_frame
    await process_frame

func Client() -> void:
    Network.set_process(false)
    await Wait("ready")
    Script("Connect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))", true)
    while not Network.call("is_connected_net"): await process_frame
    Network.set_process(false)
    var Peer: int = Network.call("get_peer_id")
    Network.rpc_id(1, "_character_ready", 2)
    Mark("client" + str(Index) + ".protocol2", str(Peer))
    await Wait("protocol.checked")
    var Deadline := Time.get_ticks_msec() + 8000
    while not States().has(Peer) or int(States()[Peer].Epoch) == 0:
        Check(Time.get_ticks_msec() < Deadline, "grant deadline")
        if Time.get_ticks_msec() >= Deadline: return
        Network.rpc_id(1, "_character_ready", 3)
        await create_timer(0.05).timeout
    Freeze()
    Network.set_process(false)
    Sequence = int(States()[Peer].Sequence)
    var Original: Vector3 = States()[Peer].Position
    var OldEpoch: int = States()[Peer].Epoch
    Mark("client" + str(Index) + ".ready", str(Peer))
    await Wait("attack")
    if Index == 1:
        Network.rpc_id(1, "_relay_state", Vector3(100000, 0, 0), 0.0, 999, 1.0, 0.0, false)
        Network.rpc_id(1, "_relay_state2d", Vector2(100000, 0), 0.0, 999)
        Send(Vector3(NAN, 0, 0))
        Send(Vector3(INF, 0, 0))
        Send(Original + Vector3(100000, 0, 0))
        Send(Original, NAN)
        Send(Original, 2.0)
        Send(Original, 1.5)
        Send(Original, 0.0, false, OldEpoch - 1)
        Network.rpc_id(1, "_relay_character", OldEpoch, 99, Original, INF, 0.0, false)
        Network.rpc_id(1, "_relay_anim_v2", OldEpoch, "res://CharacterSafeRig.tres", "SafeRig", 1.0, true, true)
        for Asset in ["HealthAttack", "MethodAttack", "RootAttack", "ScriptedAttack"]:
            Network.rpc_id(1, "_relay_anim_v2", OldEpoch, "res://Character" + Asset + ".tres", Asset, 1.0, false, true)
        for Count in range(32): Send(Original + Vector3(100000, 0, 0))
        Mark("attacked")
    await Wait("valid")
    if Index == 1:
        var PriorEpoch: int = States()[Peer].Epoch
        Network.rpc_id(1, "_character_sync", PriorEpoch)
        var SyncDeadline := Time.get_ticks_msec() + 5000
        while int(States()[Peer].Epoch) == PriorEpoch:
            Check(Time.get_ticks_msec() < SyncDeadline, "fresh prediction baseline deadline")
            if Time.get_ticks_msec() >= SyncDeadline: return
            await create_timer(0.05).timeout
        Freeze()
        if Mode in ["Movement", "Latency"]:
            await MoveNative()
        else:
            # Known displacement well inside measured 16/24 or 200/300 motion.
            await create_timer(0.15).timeout
            for Count in range(3):
                Send(Original + Vector3(0.5, 0, 0))
                await create_timer(0.05).timeout
            Mark("valid.sent")
    await Wait("rate")
    if Index == 1:
        for Count in range(500): Send(LastSent)
        Mark("rate.sent")
    await Wait("named")
    if Index == 2:
        var ObservedPlayer := Puppet(int(Read("client1.ready"))).get_node("AnimationPlayer") as AnimationPlayer
        var ObservedLibrary := AnimationLibrary.new()
        ObservedLibrary.add_animation("Walk", ResourceLoader.load("res://CharacterSafeRig.tres"))
        ObservedPlayer.add_animation_library("Rig", ObservedLibrary)
        Mark("named.observer")
        await Wait("named.observe")
        Check(ObservedPlayer.current_animation == "Rig/Walk", "observer receives safe named-library playback")
        Mark("named.observed")
    if Index == 1:
        await Wait("named.observer")
        Network.rpc_id(1, "_relay_anim_v2", States()[Peer].Epoch, "", "Rig/Walk", 1.0, true, true)
        Mark("named.sent")
    await Wait("aliases")
    if Index == 1:
        for Count in range(16):
            Network.rpc_id(1, "_relay_anim_v2", States()[Peer].Epoch, "res://CharacterSafeRig.tres", "Alias" + str(Count), 1.0, true, true)
            await create_timer(0.02).timeout
        Mark("aliases.sent")
    await Wait("gameplay")
    if Index == 1:
        for Name in ["TrustedTimeline", "Interrupt"]:
            Network.rpc_id(1, "_relay_anim_v2", States()[Peer].Epoch, "res://CharacterSafeRig.tres", Name, 1.0, true, true)
        Network.rpc_id(1, "_relay_anim_v2", States()[Peer].Epoch, "", "", 1.0, false, false)
        Mark("gameplay.sent")
    await Wait("gameplay.inactive")
    if Index == 1:
        Network.rpc_id(1, "_relay_anim_v2", States()[Peer].Epoch, "res://CharacterSafeRig.tres", "TrustedTimeline", 1.0, true, true)
        Mark("gameplay.inactive.sent")
    await Wait("gameplay.checked")
    if Mode == "TwoD":
        await Wait("plane")
        if Index == 1:
            var PreviousEpoch: int = States()[Peer].Epoch
            Network.rpc_id(1, "_character_sync", PreviousEpoch)
            var PlaneDeadline := Time.get_ticks_msec() + 5000
            while int(States()[Peer].Epoch) == PreviousEpoch:
                if Time.get_ticks_msec() > PlaneDeadline:
                    Check(false, "2D synchronization deadline")
                    return
                await process_frame
            await MoveNative2D()
    if Mode == "Movement":
        await Wait("ascent")
        if Index == 1:
            var PreviousEpoch: int = States()[Peer].Epoch
            Network.rpc_id(1, "_character_sync", PreviousEpoch)
            var AscentDeadline := Time.get_ticks_msec() + 5000
            while int(States()[Peer].Epoch) == PreviousEpoch:
                if Time.get_ticks_msec() > AscentDeadline:
                    Check(false, "ascent synchronization deadline")
                    return
                await process_frame
            var AscentStart: Vector3 = States()[Peer].Position
            for Count in range(100):
                Send(AscentStart + Vector3(0, (Count + 1) * 0.1, 0), 0.0, true)
                await create_timer(0.017).timeout
            Mark("ascent.sent")
            await Wait("ascent.sync")
            PreviousEpoch = States()[Peer].Epoch
            Network.rpc_id(1, "_character_sync", PreviousEpoch)
            AscentDeadline = Time.get_ticks_msec() + 5000
            while int(States()[Peer].Epoch) == PreviousEpoch:
                if Time.get_ticks_msec() > AscentDeadline:
                    Check(false, "airborne resynchronization deadline")
                    return
                await process_frame
            var LimitedPosition: Vector3 = States()[Peer].Position
            for Count in range(5):
                Send(LimitedPosition + Vector3(0, 0.2, 0), 0.0, true)
                await create_timer(0.035).timeout
            Mark("ascent.sync.sent")
    await Wait("corrected")
    Freeze()
    if Mode != "TwoD":
        var Target: Node3D = World.get_node("LocalPlayer") if Index == 1 else Puppet(int(Read("client1.ready")))
        var Expected := Basis.from_euler(Vector3(0.1, 0.2, 0.05)).scaled(Vector3.ONE * 1.25)
        var ContractDeadline := Time.get_ticks_msec() + 5000
        while (not Target.global_basis.is_equal_approx(Expected) or Target.call("GetAcceleration") != 130.0 or Target.call("get_max_health") != 150.0) and Time.get_ticks_msec() < ContractDeadline:
            await process_frame
        Check(Target.global_basis.is_equal_approx(Expected), "complete server orientation and uniform scale replicated")
        Check(Target.call("GetAcceleration") == 130.0 and Target.call("GetAirAcceleration") == 55.0 and Target.call("GetTurnSpeed") == 14.0 and not Target.call("get_auto_rotate") and Target.call("get_max_health") == 150.0, "server movement configuration and maximum health replicated")
        Check(Target.call("GetPhysicsBody").global_transform.is_equal_approx(Target.global_transform), "replica body shares Character world pose")
    if Index == 1:
        Send(Original, 0.0, false, int(Read("corrected")), 9999)
        Mark("stale.sent")
    await Wait("observe")
    if Index == 2:
        First = int(Read("client1.ready"))
        var Other := Puppet(First)
        Check(is_instance_valid(Other), "observer character exists")
        if is_instance_valid(Other):
            Check(Other.get("global_position").x > 999, "observer sees server correction")
            Check(HealthNode(Other).call("get_health") == 75.0, "observer sees server health")
        Mark("client2.observed")
    await Wait("respawn")
    Freeze()
    if Index == 1:
        Check(HealthNode(World.get_node("LocalPlayer")).call("get_health") == 100.0, "owner receives fresh life health")
        Check(int(States()[Peer].Epoch) > OldEpoch, "owner receives new life epoch")
        Mark("respawn.checked")
    await Wait("automatic")
    Freeze()
    if Index == 1:
        Check(HealthNode(World.get_node("LocalPlayer")).call("get_health") == 100.0, "owner receives automatic server life")
        Mark("automatic.checked")
    await Wait("reset")
    if Index == 1:
        Network.call("RequestCharacterReset")
        Mark("reset.sent")
    await Wait("reset.checked")
    Freeze()
    if Index == 1:
        while int(States()[Peer].Epoch) < int(Read("reset.checked")): await process_frame
        Network.rpc_id(1, "_character_reset", OldEpoch)
        Network.rpc_id(1, "_character_reset", int(States()[Peer].Epoch))
        Mark("reset.stale")
    await Wait("reset.done")
    Check(HealthNode(World.get_node("LocalPlayer")).call("get_health") == 100.0, "native reset receives fresh replica health")
    await Wait("destroyed")
    if Index == 1:
        Send(States()[Peer].Position)
        Network.rpc_id(1, "_character_ready", 3)
        Mark("destroyed.sent")
    await Drain()
    Check(World.get_node_or_null("LocalPlayer") == null if Index == 1 else Puppet(int(Read("client1.ready"))) == null, "server removal removes owner and observer Character")
    Mark("client" + str(Index) + ".absent")
    await Wait("removed.stale")
    await Drain()
    Check(World.get_node_or_null("LocalPlayer") == null if Index == 1 else Puppet(int(Read("client1.ready"))) == null, "late pose cannot recreate a removed life")
    Check(not Network.call("GetAnimationStates").has(int(Read("client1.ready"))), "late animation cannot recreate removed cache")
    Mark("client" + str(Index) + ".tombstone")
    await Wait("restored")
    await Drain()
    Check(World.get_node_or_null("LocalPlayer") != null if Index == 1 else Puppet(int(Read("client1.ready"))) != null, "trusted replacement reaches owner and observer")
    Freeze()
    Mark("client" + str(Index) + ".restored")
    await Wait("done")
    if Index == 2: await Wait("client2.close")
    Network.call("disconnect_net")
    if Index == 1:
        Mark("client1.closed")
        await Wait("reconnect")
        Script("Reconnect", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))", true)
        var RejoinDeadline := Time.get_ticks_msec() + 8000
        while not Network.call("is_connected_net"):
            if Time.get_ticks_msec() > RejoinDeadline:
                Check(false, "reconnect deadline")
                return
            await process_frame
        Network.set_process(false)
        var Rejoined: int = Network.call("get_peer_id")
        while not States().has(Rejoined) or int(States()[Rejoined].Epoch) == 0:
            if Time.get_ticks_msec() > RejoinDeadline:
                Check(false, "reconnect grant deadline")
                return
            Network.rpc_id(1, "_character_ready", 3)
            await create_timer(0.05).timeout
        Freeze()
        Network.set_process(false)
        Mark("client1.rejoined", str(Rejoined))
        await Wait("prior-session")
        Network.rpc_id(1, "_relay_character", OldEpoch, 99999, Original + Vector3(0.1, 0, 0), 0.0, 0.0, false)
        Network.rpc_id(1, "_relay_anim_v2", OldEpoch, "res://CharacterSafeRig.tres", "PriorLife", 1.0, true, true)
        Mark("prior-session.sent")
        await Wait("rejoined.close")
        Network.call("disconnect_net")
    Mark("client" + str(Index) + ".done")

func HealthNode(Character: Node) -> Node:
    return Character if Character.is_class("RBXCharacter") else Character.get_node("Humanoid")

func MoveNative() -> void:
    var Hum: Node = World.get_node("LocalPlayer")
    var Body: CharacterBody3D = Hum.get_node("PhysicsBody")
    Hum.call("set_npc_move_dir", Vector3.RIGHT)
    Hum.set_physics_process(true)
    var Up := 0.0
    var Down := 0.0
    var Walk := 0.0
    var Jump := InputEventKey.new()
    Jump.keycode = KEY_SPACE
    for Tick in range(120):
        await physics_frame
        if Tick == 60 or Tick == 63:
            Jump.pressed = Tick == 60
            Input.parse_input_event(Jump)
        Up = maxf(Up, Body.velocity.y)
        Down = minf(Down, Body.velocity.y)
        Walk = maxf(Walk, Vector2(Body.velocity.x, Body.velocity.z).length())
        if Tick % 2 == 0: Send(Body.global_position, minf(1, Vector2(Body.velocity.x, Body.velocity.z).length() / 16.0), not Body.is_on_floor())
    Hum.set_physics_process(false)
    Hum.call("stop_npc_movement")
    Jump.pressed = false
    Input.parse_input_event(Jump)
    for Count in range(3):
        Send(Body.global_position, 0.0, not Body.is_on_floor())
        await create_timer(0.05).timeout
    var Measured := {"Walk": Walk, "Jump": Up, "Fall": Down, "LastX": Body.global_position.x}
    print("[Network:CharacterTest] native movement ", JSON.stringify(Measured))
    Check(is_equal_approx(Walk, 16.0) and Up > 19 and Down < -15, "actual native walk/jump/fall")
    Mark("valid.sent", JSON.stringify(Measured))

func MoveNative2D() -> void:
    var Body: CharacterBody2D = World.get_node("LocalPlayer")
    Body.call("set_movement_type", 0)
    Body.set_physics_process(true)
    var Right := InputEventKey.new()
    Right.keycode = KEY_D
    Right.pressed = true
    Input.parse_input_event(Right)
    var Jump := InputEventKey.new()
    Jump.keycode = KEY_SPACE
    var Walk := 0.0
    var Up := 0.0
    var Down := 0.0
    for Tick in range(120):
        await physics_frame
        if Tick == 60 or Tick == 63:
            Jump.pressed = Tick == 60
            Input.parse_input_event(Jump)
        Walk = maxf(Walk, absf(Body.velocity.x))
        Up = minf(Up, Body.velocity.y)
        Down = maxf(Down, Body.velocity.y)
        if Tick % 2 == 0: Send(Vector3(Body.global_position.x, Body.global_position.y, 0), 1.0, not Body.is_on_floor())
    Right.pressed = false
    Input.parse_input_event(Right)
    Jump.pressed = false
    Input.parse_input_event(Jump)
    Check(is_equal_approx(Walk, 200.0) and Up < -480 and Down > 200, "actual native 2D platformer walk/jump/fall")
    Body.call("set_movement_type", 1)
    var North := InputEventKey.new()
    North.keycode = KEY_W
    North.pressed = true
    Input.parse_input_event(North)
    for Tick in range(90):
        await physics_frame
        if Tick % 2 == 0: Send(Vector3(Body.global_position.x, Body.global_position.y, 0), 1.0, true)
    North.pressed = false
    Input.parse_input_event(North)
    Body.set_physics_process(false)
    for FinalSample in range(3):
        Send(Vector3(Body.global_position.x, Body.global_position.y, 0), 0.0, true)
        await create_timer(0.05).timeout
    var Motion := {"Walk": Walk, "Jump": Up, "Fall": Down, "LastY": Body.global_position.y}
    print("[Network:CharacterTest] native 2D movement ", JSON.stringify(Motion))
    Mark("plane.sent", JSON.stringify(Motion))
