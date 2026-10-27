extends SceneTree

# File barriers sequence actors; animation/state messages use actual ENet RPCs.
var Game: Node
var Network: Node
var Role := "server"
var Mode := "Local"
var Port := 0
var Index := 0
var Failed := false
var First := 0
var Second := 0
var Character: Node
var Track: Node

func Check(Value: bool, Description: String) -> void:
    if not Value:
        Failed = true
        print("[Network:AnimationTest] FAIL ", Role, " ", Description)

func Mark(Name: String, Value := "ready") -> void:
    var File := FileAccess.open("res://animation-" + Name, FileAccess.WRITE)
    File.store_string(Value)
    File.close()

func Read(Name: String) -> String:
    return FileAccess.get_file_as_string("res://animation-" + Name)

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 15000
    while not FileAccess.file_exists("res://animation-" + Name):
        if Time.get_ticks_msec() > Deadline:
            Check(false, "barrier " + Name)
            quit(1)
            return
        await process_frame

func Drain() -> void:
    await create_timer(0.2).timeout

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func Script(Source: String) -> void:
    var Result: Node = ClassDB.instantiate("LocalScript" if Role == "client" else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = "AnimationScript" + str(Game.get_child_count())
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)

func Cache() -> Dictionary:
    return Network.call("GetAnimationStates")

func Puppet(Peer: int) -> Node:
    return root.get_node_or_null("RemotePlayer_" + str(Peer))

func Player(CharacterNode: Node) -> AnimationPlayer:
    if not is_instance_valid(CharacterNode): return null
    return CharacterNode.get_node_or_null("AnimationPlayer") as AnimationPlayer

func Observe(Peer: int, Name: String, Speed: float, Looped: bool, Playing := true) -> void:
    var State: Dictionary = Cache().get(Peer, {})
    Check(not State.is_empty(), "cached target " + str(Peer))
    Check(State.get("Name", "") == Name and State.get("Play", false) == Playing, "cached playback " + str(Peer))
    Check(is_equal_approx(float(State.get("Speed", -1)), Speed) and State.get("Looped", false) == Looped, "cached settings " + str(Peer))
    Check(int(State.get("UserId", 0)) > 0, "assigned session ownership")
    var Animator := Player(Puppet(Peer))
    Check(is_instance_valid(Animator), "actual AnimationPlayer " + str(Peer))
    if is_instance_valid(Animator):
        Check(Animator.is_playing() == Playing, "actual playback " + str(Peer))
        if Playing:
            Check(Animator.current_animation == Name, "actual clip " + str(Peer))
            Check(is_equal_approx(Animator.speed_scale, Speed), "actual speed " + str(Peer))
            Check(Animator.get_animation(Name).loop_mode == (Animation.LOOP_LINEAR if Looped else Animation.LOOP_NONE), "actual loop " + str(Peer))

func MakeCharacter() -> void:
    Character = Create("RobloxPlayer", "LocalPlayer", Game)
    Character.set_process(false)
    Character.set_physics_process(false)
    if not Character.has_node("Humanoid"): Create("Humanoid", "Humanoid", Character)

func LoadTrack(Name: String) -> Node:
    if not Game.has_node("Clip" + Name):
        var Clip := Create("AnimationObject", "Clip" + Name, Game)
        Clip.call("set_animation_id", "res://" + Name + ".tres")
        Clip.call("set_anim_name", Name)
    Script("local Loaded = game.LocalPlayer.Humanoid:LoadAnimation(game.Clip" + Name + "); game:SetAttribute('Loaded" + Name + "', true)")
    await process_frame
    Check(Game.has_meta("Loaded" + Name), "Humanoid LoadAnimation " + Name)
    var Tracks := Character.get_node("Humanoid").find_children("*", "AnimationTrack", false, false)
    return Tracks.back() if not Tracks.is_empty() else null

func SendState() -> void:
    Network.rpc_id(1, "_relay_state", Vector3(Index * 10, 0, 0), 0.0, 999, 100.0, 0.0, false)

func Finish() -> void:
    print("[Network:AnimationTest] ", Role, " ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Position in range(Arguments.size() - 1):
        if Arguments[Position] == "--fixture-role": Role = Arguments[Position + 1]
        if Arguments[Position] == "--fixture-port": Port = int(Arguments[Position + 1])
        if Arguments[Position] == "--fixture-client-index": Index = int(Arguments[Position + 1])
        if Arguments[Position] == "--animation-mode": Mode = Arguments[Position + 1]
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Game.set_meta("Port", Port)
    Create("Players", "Players", Game)
    Create("RunService", "RunService", Game)
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    Network.set_process(false) # Explicit state sends make pre-puppet ordering deterministic.
    if Role == "server":
        for Name in ["Wave", "Dance", "Once"]:
            var Clip := Animation.new()
            Clip.length = 0.1 if Name == "Once" else 60.0
            Check(ResourceSaver.save(Clip, "res://" + Name + ".tres") == OK, "fixture clip")
    if Mode == "Local":
        MakeCharacter()
        Track = await LoadTrack("Wave")
        Track.call("set_looped", true)
        Track.call("play")
        Check(Player(Character).is_playing(), "single-player play")
        Track.call("set_speed", 1.5)
        Check(is_equal_approx(Player(Character).speed_scale, 1.5), "single-player speed")
        Track.call("stop")
        Check(not Player(Character).is_playing(), "single-player stop")
        Network.call("_relay_anim", "res://Wave.tres", "Wave", 1.0, true, true)
        Network.call("_recv_anim", 7, "res://Wave.tres", "Wave", 1.0, true, true)
        Check(Cache().is_empty(), "local inbound calls have no cache effects")
        Player(Character).free()
        Track.call("play")
        Track.call("set_speed", 2.0)
        Track.call("set_looped", false)
        Track.call("stop")
        Check(not Track.call("is_playing"), "destroyed AnimationPlayer resolves safely")
        Track = await LoadTrack("Dance")
        Track.call("play")
        var Retired := Track
        Track.connect("Stopped", func(_Completed: bool) -> void: Retired.queue_free())
        Track.call("stop")
        await process_frame
        Check(not is_instance_valid(Retired), "stop callback may queue track destruction")
        Track = await LoadTrack("Once")
        Track.call("play")
        var Completed := Track
        Track.connect("Ended", func() -> void: Completed.queue_free())
        await create_timer(0.2).timeout
        Check(not is_instance_valid(Completed), "completion callback may queue track destruction")
        Network.free()
        Network = Create("NetworkService", "NetworkService", Game)
        await process_frame
        Check(Cache().is_empty(), "replacement service cache is fresh")
        Game.queue_free()
        await process_frame
        await process_frame
        Finish()
    elif Role == "server":
        await RunServer()
    else:
        await RunClient()

func RunServer() -> void:
    if Network.call("get_mode") != 1:
        Script("assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4))")
        await process_frame
    Network.set_process(false)
    if Mode == "Listen":
        MakeCharacter()
        Track = await LoadTrack("Wave")
        Track.call("set_looped", true)
        Track.call("play")
    Mark("ready")
    await Wait("client1.play")
    First = int(Read("client1.peer"))
    await Drain()
    Check(Cache().has(First) and Puppet(First) == null, "accepted pre-puppet state cached")
    Mark("latejoin")
    await Wait("client2.joined")
    Second = int(Read("client2.peer"))
    await Drain()
    if Mode == "Listen": Network.rpc("_recv_state", 1, Vector3.ZERO, 0.0, 1, 100.0, 0.0, false)
    Mark("spawn")
    await Wait("both.spawned")
    await Drain()
    Observe(First, "Wave", 1.0, true)
    Observe(Second, "Dance", 1.0, false)
    Player(Puppet(First)).seek(4.0)
    Check(int(Cache()[First]["UserId"]) != int(Cache()[Second]["UserId"]), "independent sessions")
    Mark("settings")
    await Wait("settings.sent")
    await Drain()
    Observe(First, "Wave", 1.75, false)
    Check(Player(Puppet(First)).current_animation_position >= 4.0, "remote updates preserve playback position")
    Observe(Second, "Dance", 1.0, false)
    if Mode == "Listen":
        Check(Player(Character).get_animation("Wave").loop_mode == Animation.LOOP_LINEAR, "host loop configuration independent of remote character")
    Mark("replace")
    await Wait("replace.sent")
    await Drain()
    Observe(First, "Dance", 1.0, true)
    Mark("stop")
    await Wait("stop.sent")
    await Drain()
    Observe(First, "Dance", 1.0, true, false)
    Mark("once")
    await Wait("once.sent")
    await Drain()
    Observe(First, "Once", 1.0, false, false)
    Mark("respawn")
    await Wait("respawn.sent")
    await Drain()
    Check(not Cache()[First]["Play"], "local character exit stopped remote state")
    Mark("respawn.play")
    await Wait("respawn.play.sent")
    await Drain()
    Observe(First, "Wave", 1.0, true)
    # Destroying a remote character forgets its old animation, including late-join cache.
    Puppet(First).free()
    Check(not Cache().has(First), "remote character exit clears cache")
    var Before := Cache().duplicate(true)
    Network.call("_relay_anim", "res://Wave.tres", "Wave", 1.0, true, true)
    Network.call("_recv_anim", Second, "res://Wave.tres", "Wave", 1.0, true, true)
    Check(Cache() == Before, "wrong-role/sender-zero operations have no mutation")
    for Target in [0, -1, 2147483647]:
        Network.rpc("_recv_anim", Target, "res://Wave.tres", "Wave", 1.0, true, true)
    var OldSession: int = 2
    Mark("disconnect")
    await Wait("client1.disconnected")
    await Drain()
    Check(not Cache().has(First), "disconnect clears obsolete server animation")
    Mark("reconnect")
    await Wait("client1.reconnected")
    var Replacement := int(Read("client1.newpeer"))
    await Drain()
    Check(not Cache().get(Replacement, {}).get("Play", false), "reconnect starts without inherited animation")
    Mark("reconnect.play")
    await Wait("reconnect.play.sent")
    await Drain()
    Observe(Replacement, "Dance", 1.0, false)
    Check(int(Cache()[Replacement]["UserId"]) != OldSession, "fresh assigned identity after reconnect")
    Mark("close1")
    await Wait("client1.closed")
    await Drain()
    Mark("close2")
    await Wait("client2.closed")
    await Drain()
    Check(not Cache().has(Replacement) and not Cache().has(Second), "all departed sessions cleaned")
    Network.free()
    Network = Create("NetworkService", "NetworkService", Game)
    await process_frame
    Check(Cache().is_empty(), "service replacement has no animation state")
    Game.queue_free()
    await process_frame
    await process_frame
    Finish()

func RunClient() -> void:
    if Index == 1:
        MakeCharacter()
        Track = await LoadTrack("Wave")
        Track.call("set_looped", true)
        Track.call("play") # A later server UID must recover playback begun before connection.
    if Network.call("get_mode") != 2:
        Script("assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
    var Deadline := Time.get_ticks_msec() + 10000
    while not Network.call("is_connected_net"):
        if Time.get_ticks_msec() > Deadline: Check(false, "client connected"); Finish(); return
        await process_frame
    Network.set_process(false)
    await Drain() # The server's reliable identity assignment precedes animation delivery.
    var Identity: int = Network.call("get_peer_id")
    Mark("client" + str(Index) + ".peer", str(Identity))
    if Index == 1:
        Mark("client1.play")
    else:
        First = int(Read("client1.peer"))
        Check(Cache().has(First) and Puppet(First) == null, "late-join state survives before character spawn")
        Mark("client2.joined")
    await Wait("spawn")
    if Index == 2:
        MakeCharacter()
        Track = await LoadTrack("Dance")
        Track.call("play")
    SendState()
    Mark("client" + str(Index) + ".spawned")
    if Index == 1:
        await Wait("client2.spawned")
        Mark("both.spawned")
    await Wait("settings")
    if Index == 2 and Mode == "Listen": Observe(1, "Wave", 1.0, true)
    if Index == 1:
        var Animator := Player(Character)
        Animator.seek(5.0)
        Track.call("set_speed", 0.0)
        Track.call("set_speed", 20.0)
        Track.call("set_speed", 1.75)
        Track.call("set_looped", false)
        Check(Animator.current_animation_position >= 5.0, "settings do not restart animation")
        # Invalid values must not alter cache or relay over the normal transport.
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "Wave", NAN, true, true)
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "Wave", INF, true, true)
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "Wave", -1.0, true, true)
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "", 1.0, true, true)
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "Wave", 21.0, true, true)
        Network.rpc_id(1, "_relay_anim", "x".repeat(1025), "Wave", 1.0, true, true)
        Network.rpc_id(1, "_relay_anim", "res://Wave.tres", "x".repeat(129), 1.0, true, true)
        Mark("settings.sent")
    await Wait("replace")
    if Index == 2:
        Observe(First, "Wave", 1.75, false)
        var Animator := Player(Puppet(First))
        Check(Animator.current_animation_position > 0.1, "remote settings did not repeatedly restart playback")
    if Index == 1:
        Track = await LoadTrack("Dance")
        Track.call("set_looped", true)
        Track.call("play")
        Mark("replace.sent")
    await Wait("stop")
    if Index == 2: Observe(First, "Dance", 1.0, true)
    if Index == 1: Track.call("stop"); Mark("stop.sent")
    await Wait("once")
    if Index == 2: Observe(First, "Dance", 1.0, true, false)
    if Index == 1:
        Track = await LoadTrack("Once")
        Track.call("play")
        await create_timer(0.2).timeout
        Check(not Track.call("is_playing"), "non-looped completion")
        Mark("once.sent")
    await Wait("respawn")
    if Index == 2: Observe(First, "Once", 1.0, false, false)
    if Index == 1:
        Track = await LoadTrack("Wave")
        Track.call("set_looped", true)
        Track.call("play")
        await Drain()
        Character.free()
        MakeCharacter()
        Mark("respawn.sent")
    await Wait("respawn.play")
    if Index == 1:
        Track = await LoadTrack("Wave")
        Track.call("set_looped", true)
        Track.call("play")
        Mark("respawn.play.sent")
    await Wait("disconnect")
    for Target in [0, -1, 2147483647]: Check(not Cache().has(Target), "missing target mapping rejected")
    if Index == 1:
        Track.call("stop")
        Network.call("disconnect_net")
        Check(Cache().is_empty(), "local disconnect clears cache")
        Mark("client1.disconnected")
        await Wait("reconnect")
        Script("assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
        while not Network.call("is_connected_net"): await process_frame
        Network.set_process(false)
        Track.call("stop") # Explicitly start the replacement session with stopped playback.
        await Drain()
        Identity = Network.call("get_peer_id")
        Mark("client1.newpeer", str(Identity))
        Mark("client1.reconnected")
        await Wait("reconnect.play")
        Track = await LoadTrack("Dance")
        Track.call("play")
        SendState()
        Mark("reconnect.play.sent")
    else:
        await Wait("reconnect")
        Check(not Cache().has(First), "server removal clears client animation cache")
    await Wait("close" + str(Index))
    Network.call("disconnect_net")
    Check(Cache().is_empty(), "final local disconnect cache empty")
    Mark("client" + str(Index) + ".closed")
    Game.queue_free()
    await process_frame
    await process_frame
    Finish()
