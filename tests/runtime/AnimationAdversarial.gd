extends RefCounted

# Extends the existing animation actors. Barriers only coordinate assertions;
# traffic always uses the real ENet transport and production RPC handlers.
var R
var Cases: Array[Dictionary] = []
var Events: Dictionary = {}
var Watched: Dictionary = {}
var Sent: Array[String] = []
var Observations: Dictionary = {}

func _init(Runner) -> void:
    R = Runner

func Check(Value: bool, Phase: String, Label: String) -> void:
    Cases.append({"Phase": Phase, "Label": Label, "Passed": Value})
    R.Check(Value, "authority " + Phase + " " + Label)
    Save(false)

func Save(Complete: bool) -> void:
    var File := FileAccess.open("res://animation-authority-" + R.Role + str(R.Index) + ".json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Mode": R.Mode, "Role": R.Role, "Index": R.Index,
        "Complete": Complete, "Result": "FAIL" if R.Failed else "PASS", "Cases": Cases,
        "Sent": Sent, "Assertions": R.Assertions, "Observations": Observations}))
    File.close()

func Changed(_Name: StringName, Identity: int) -> void:
    Events[Identity] = int(Events.get(Identity, 0)) + 1

func Watch() -> void:
    for Player in R.root.find_children("*", "AnimationPlayer", true, false):
        var Identity: int = Player.get_instance_id()
        if Watched.has(Identity): continue
        Watched[Identity] = true
        Events[Identity] = 0
        Player.animation_started.connect(Changed.bind(Identity))
        Player.animation_finished.connect(Changed.bind(Identity))

func Snapshot() -> Dictionary:
    Watch()
    var Players: Dictionary = {}
    for Player in R.root.find_children("*", "AnimationPlayer", true, false):
        var Clips: Dictionary = {}
        for Name in Player.get_animation_list():
            var Clip: Animation = Player.get_animation(Name)
            Clips[str(Name)] = [Clip.get_instance_id(), Clip.loop_mode]
        var Parent: Node = Player.get_parent()
        Players[Player.get_instance_id()] = {"Playing": Player.is_playing(),
            "Current": str(Player.current_animation), "Speed": Player.speed_scale,
            "Clips": Clips, "Health": Parent.get("Health") if Parent.is_class("RBXCharacter") else null}
    return {"Cache": R.Cache().duplicate(true), "Players": Players, "Events": Events.duplicate(),
        "Initializer": R.Game.get_meta("UnauthorizedInitializer", 0)}

func Send(Target: int, Method: String, Arguments: Array, Label: String) -> void:
    Sent.append(Label)
    R.Network.callv("rpc_id", [Target, Method] + Arguments)

func ReceivePolicy(Relaxed: bool) -> void:
    for Method in ["_recv_anim", "_recv_anim_v2"]:
        R.Network.rpc_config(Method, {"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER if Relaxed else MultiplayerAPI.RPC_MODE_AUTHORITY,
            "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE, "call_local": false, "channel": 0})

func Setup() -> void:
    if R.Role == "server":
        var Clip := Animation.new()
        Clip.length = 1.0
        var Track := Clip.add_track(Animation.TYPE_METHOD)
        Clip.track_set_path(Track, NodePath("."))
        Clip.track_insert_key(Track, 0.0, {"method": "take_damage", "args": [99.0]})
        R.Check(ResourceSaver.save(Clip, "res://ForbiddenMethod.tres") == OK, "prepare controlled method asset")
        var Attached := GDScript.new()
        Attached.source_code = "extends Animation\nfunc _init():\n    var Tree = Engine.get_main_loop()\n    if Tree is SceneTree and Tree.current_scene != null:\n        Tree.current_scene.set_meta('UnauthorizedInitializer', 1)\n"
        R.Check(Attached.reload() == OK, "prepare controlled initializer")
        R.Check(ResourceSaver.save(Attached, "res://ForbiddenInitializer.gd") == OK, "save controlled initializer")
        var Scripted := Animation.new()
        Scripted.set_script(Attached)
        R.Check(ResourceSaver.save(Scripted, "res://ForbiddenInitializer.tres") == OK, "save unregistered scripted asset")
        R.Game.set_meta("UnauthorizedInitializer", 0)
    if R.Mode == "Local":
        var Before: Dictionary = R.Cache().duplicate(true)
        R.Network.call("_relay_anim_v2", 0, "res://Wave.tres", "LocalForged", 1.0, true, true)
        R.Network.call("_recv_anim_v2", 7, 0, "res://Wave.tres", "LocalForged", 1.0, true, true)
        Check(R.Cache() == Before, "local-role", "sender zero cannot mutate disconnected service")

func Forged(Target: int) -> void:
    var Other: int = int(R.Read("client2.peer"))
    var First: int = int(R.Read("client1.peer"))
    var States: Dictionary = R.Network.call("GetCharacterStates")
    for Who in [First, Other, 1, 0, -1, 2147483647]:
        var Life: int = States.get(Who, {}).get("Life", 0)
        Send(Target, "_recv_anim_v2", [Who, Life, "res://Wave.tres", "Forged", 2.0, true, true], "forged-play-" + str(Who))
        Send(Target, "_recv_anim_v2", [Who, Life, "", "", 1.0, false, false], "forged-stop-" + str(Who))
        Send(Target, "_recv_anim", [Who, "res://Wave.tres", "LegacyForged", 1.0, true, true], "legacy-receive")
    Send(Target, "_relay_anim_v2", [0, "res://Wave.tres", "WrongReceiver", 2.0, true, true], "wrong-role-relay")
    Send(Target, "_relay_anim", ["res://Wave.tres", "LegacyRelay", 1.0, true, true], "legacy-relay")
    Send(Target, "_gl_peer_uid", [Other, 99999], "forged-session-assignment")

func Spawned() -> void:
    if R.Role != "server": await R.Wait("both.spawned")
    await R.Drain()
    for Relaxed in [false, true]:
        var Phase := "relaxed-handler" if Relaxed else "default-authority"
        # A modified sender may change its own RPC configuration. In the second
        # pass receivers deliberately relax filtering to prove native guards.
        ReceivePolicy(Relaxed or (R.Role == "client" and R.Index == 1))
        var Before := Snapshot()
        if R.Role == "server":
            R.Mark(Phase + ".prepare")
            await R.Wait(Phase + ".ready1")
            await R.Wait(Phase + ".ready2")
            for Target in [int(R.Read("client1.peer")), int(R.Read("client2.peer"))]:
                Send(Target, "_relay_anim_v2", [0, "res://Wave.tres", "ServerRelay", 2.0, true, true], "server-to-client-relay")
                for Who in [0, -1, 2147483647]:
                    Send(Target, "_recv_anim_v2", [Who, 0, "res://Wave.tres", "Unmapped", 2.0, true, true], "server-unmapped-target")
            R.Mark(Phase + ".attack")
            await R.Wait(Phase + ".sent")
            await R.Drain()
            Check(Snapshot() == Before, Phase, "server cache players resources health callbacks unchanged")
            R.Mark(Phase + ".observed")
            await R.Wait(Phase + ".checked1")
            await R.Wait(Phase + ".checked2")
        else:
            R.Mark(Phase + ".ready" + str(R.Index))
            await R.Wait(Phase + ".attack")
            if R.Index == 1:
                Forged(1)
                Forged(int(R.Read("client2.peer")))
                R.Mark(Phase + ".sent")
            await R.Wait(Phase + ".observed")
            await R.Drain()
            Check(Snapshot() == Before, Phase, "client cache players resources health callbacks unchanged")
            R.Mark(Phase + ".checked" + str(R.Index))
        await PositiveControl(Phase)
    ReceivePolicy(false)
    await Replay()
    await InvalidInput()
    var Before := Snapshot()
    var Other: Node = R.Puppet(int(R.Read("client2.peer")) if R.Role == "client" and R.Index == 1 else int(R.Read("client1.peer")))
    R.Network.call("net_anim_state", Other, "res://Wave.tres", "WrongCharacter", 1.0, true, true)
    R.Network.call("net_anim_state", null, "res://Wave.tres", "MissingCharacter", 1.0, true, true)
    Check(Snapshot() == Before, "owner", "only current local Character can originate track state")

func WaitClip(Peer: int, Name: String) -> bool:
    var Deadline := Time.get_ticks_msec() + 5000
    while Time.get_ticks_msec() < Deadline:
        if R.Cache().get(Peer, {}).get("Name", "") == Name: return true
        await R.process_frame
    return false

func PositiveControl(Phase: String) -> void:
    var First: int = int(R.Read("client1.peer"))
    if R.Role == "server":
        R.Mark(Phase + ".positive")
        Check(await WaitClip(First, "ControlWave"), Phase, "valid owner packet reaches production relay")
        await R.Wait(Phase + ".positive2")
        R.Mark(Phase + ".restore")
        Check(await WaitClip(First, "Wave"), Phase, "valid owner restores playback after attacks")
        await R.Wait(Phase + ".restored2")
        R.Mark(Phase + ".done")
    elif R.Index == 1:
        await R.Wait(Phase + ".positive")
        var Epoch: int = R.Network.call("GetCharacterStates")[First].Epoch
        Send(1, "_relay_anim_v2", [Epoch, "res://Wave.tres", "ControlWave", 1.0, true, true], "positive-current-owner")
        await R.Wait(Phase + ".restore")
        Send(1, "_relay_anim_v2", [Epoch, "res://Wave.tres", "Wave", 1.0, true, true], "positive-restore-owner")
        await R.Wait(Phase + ".done")
        Check(true, Phase, "legitimate owner remains connected after rejected requests")
    else:
        Check(await WaitClip(First, "ControlWave"), Phase, "observer receives legitimate server replication")
        R.Mark(Phase + ".positive2")
        Check(await WaitClip(First, "Wave"), Phase, "observer receives ordered valid restore")
        R.Mark(Phase + ".restored2")
        await R.Wait(Phase + ".done")

func InvalidPackets(Epoch: int) -> Array:
    var Packets: Array = []
    for Speed in [NAN, INF, -INF, -1.0, 20.01]: Packets.append([Epoch, "res://Wave.tres", "InvalidSpeed", Speed, true, true])
    Packets.append([Epoch - 1, "res://Wave.tres", "StaleEpoch", 1.0, true, true])
    Packets.append([Epoch + 9999, "res://Wave.tres", "FutureEpoch", 1.0, true, true])
    Packets.append([Epoch, "x".repeat(1025), "OversizedIdentity", 1.0, true, true])
    Packets.append([Epoch, "res://Wave.tres", "x".repeat(129), 1.0, true, true])
    Packets.append([Epoch, "res://Wave.tres", "", 1.0, true, true])
    for Name in ["Bad:Name", "Bad,Name", "Bad[Name", "Missing/Clip"]: Packets.append([Epoch, "res://Wave.tres", Name, 1.0, true, true])
    for Asset in ["ForbiddenMethod", "ForbiddenInitializer", "Unregistered"]: Packets.append([Epoch, "res://" + Asset + ".tres", "Forbidden", 1.0, true, true])
    # Preserve original Variant types on the wire; do not stringify in the test.
    Packets.append([Epoch, 123, "MalformedIdentity", 1.0, true, false])
    Packets.append([Epoch, "res://Wave.tres", 456, 1.0, true, false])
    Packets.append([Epoch, "res://Wave.tres", "MalformedSpeed", "1", true, false])
    Packets.append([Epoch, "res://Wave.tres", "MalformedLoop", 1.0, "yes", false])
    Packets.append([Epoch, "res://Wave.tres", "MalformedPlay", 1.0, true, 0])
    Packets.append([float(Epoch) + 0.25, "res://Wave.tres", "MalformedEpoch", 1.0, true, false])
    return Packets

func Replay() -> void:
    var First: int = int(R.Read("client1.peer"))
    var Player: AnimationPlayer = R.Player(R.Puppet(First)) if R.Role == "server" or R.Index == 2 else R.Player(R.Character)
    if R.Role == "server" or R.Index == 2: Player.seek(3.0)
    var Before := Snapshot()
    if R.Role == "server":
        R.Mark("replay.prepare")
        await R.Wait("replay.ready1")
        await R.Wait("replay.ready2")
        R.Mark("replay.attack")
        await R.Wait("replay.sent")
        await R.Drain()
        Check(Snapshot() == Before and Player.current_animation_position >= 3.0, "replay", "duplicate current-owner state preserves playback position and callbacks")
        R.Mark("replay.observed")
        await R.Wait("replay.checked1")
        await R.Wait("replay.checked2")
        R.Mark("replay.done")
    else:
        R.Mark("replay.ready" + str(R.Index))
        await R.Wait("replay.attack")
        if R.Index == 1:
            var Epoch: int = R.Network.call("GetCharacterStates")[First].Epoch
            Send(1, "_relay_anim_v2", [Epoch, "res://Wave.tres", "Wave", 1.0, true, true], "duplicate-current-owner-state")
            R.Mark("replay.sent")
        await R.Wait("replay.observed")
        await R.Drain()
        Check(Snapshot() == Before and (R.Index == 1 or Player.current_animation_position >= 3.0), "replay", "authorized duplicate is idempotent without a new playback callback")
        R.Mark("replay.checked" + str(R.Index))
        await R.Wait("replay.done")

func InvalidInput() -> void:
    var Count: int = InvalidPackets(0).size()
    var First: int = int(R.Read("client1.peer"))
    Observations["InvalidInput"] = []
    if R.Role == "server":
        R.Mark("invalid-input.prepare")
        await R.Wait("invalid-input.ready1")
        await R.Wait("invalid-input.ready2")
        for Position in range(Count):
            var Tag := "invalid-input." + str(Position)
            var Before := Snapshot()
            R.Mark(Tag + ".next")
            await R.Wait(Tag + ".sent")
            await R.create_timer(0.08).timeout
            var After := Snapshot()
            Observations["InvalidInput"].append({"Packet": Position, "Before": Before, "After": After})
            Check(After == Before, "invalid-input", "packet " + str(Position) + " has no mutation resource or callback effects")
            R.Mark(Tag + ".observed")
            await R.Wait(Tag + ".checked1")
            await R.Wait(Tag + ".checked2")
        R.Mark("invalid-input.restore")
        Check(await WaitClip(First, "Wave"), "invalid-input", "legitimate owner playback still recovers after rejection")
        await R.Wait("invalid-input.restored2")
        R.Mark("invalid-input.done")
    else:
        await R.Wait("invalid-input.prepare")
        R.Mark("invalid-input.ready" + str(R.Index))
        for Position in range(Count):
            var Tag := "invalid-input." + str(Position)
            await R.Wait(Tag + ".next")
            var Before := Snapshot()
            if R.Index == 1:
                var Epoch: int = R.Network.call("GetCharacterStates")[First].Epoch
                var Packets := InvalidPackets(Epoch)
                Send(1, "_relay_anim_v2", Packets[Position], "invalid-input-" + str(Position))
                R.Mark(Tag + ".sent")
            await R.Wait(Tag + ".observed")
            await R.create_timer(0.08).timeout
            var After := Snapshot()
            Observations["InvalidInput"].append({"Packet": Position, "Before": Before, "After": After})
            Check(After == Before, "invalid-input", "packet " + str(Position) + " has no rejected relay effects")
            R.Mark(Tag + ".checked" + str(R.Index))
        await R.Wait("invalid-input.restore")
        if R.Index == 1:
            var Epoch: int = R.Network.call("GetCharacterStates")[First].Epoch
            Send(1, "_relay_anim_v2", [Epoch, "res://Wave.tres", "Wave", 1.0, true, true], "post-invalid-valid-owner")
        else:
            Check(await WaitClip(First, "Wave"), "invalid-input", "observer receives valid playback after rejection")
            R.Mark("invalid-input.restored2")
        await R.Wait("invalid-input.done")

func Reconnected(Replacement: int) -> void:
    # The functional fixture already exercises stop/completion, local Character
    # replacement, disconnect and real reconnect. Add actual old-life traffic.
    if R.Role == "server":
        var Before := Snapshot()
        R.Mark("security-reconnect.prepare")
        await R.Wait("security-reconnect.ready1")
        await R.Wait("security-reconnect.ready2")
        for Target in [Replacement, int(R.Read("client2.peer"))]:
            Send(Target, "_recv_anim_v2", [int(R.Read("client1.peer")), 0, "res://Wave.tres", "DisconnectedPeer", 1.0, true, true], "disconnected-peer")
        R.Mark("security-reconnect.sent")
        await R.Wait("security-reconnect.checked1")
        await R.Wait("security-reconnect.checked2")
        Check(Snapshot() == Before, "reconnect", "obsolete session cannot repopulate server cache")
        var Old: Dictionary = R.Network.call("GetCharacterStates")[Replacement].duplicate(true)
        var OldCharacter: Node = R.Puppet(Replacement)
        var OldIdentity: int = OldCharacter.get_instance_id()
        R.Network.call("net_load_character", R.Network.call("player_node_for_peer", Replacement))
        await R.Drain()
        var Current: Dictionary = R.Network.call("GetCharacterStates")[Replacement]
        Check(Current.Life > Old.Life and R.Puppet(Replacement).get_instance_id() != OldIdentity, "life", "trusted replacement changes actual Character and life")
        R.Mark("security-life.old", str(Old.Epoch))
        R.Mark("security-life.life", str(Old.Life))
        R.Mark("security-life.prepare")
        await R.Wait("security-life.ready1")
        await R.Wait("security-life.ready2")
        Before = Snapshot()
        for Target in [Replacement, int(R.Read("client2.peer"))]:
            Send(Target, "_recv_anim_v2", [Replacement, Old.Life, "res://Dance.tres", "OldLife", 1.0, true, true], "old-life-play")
            Send(Target, "_recv_anim_v2", [Replacement, Old.Life, "", "", 1.0, false, false], "old-life-stop")
        R.Mark("security-life.attack")
        await R.Wait("security-life.sent")
        await R.Drain()
        Check(Snapshot() == Before, "life", "replayed old epoch cannot change replacement or callbacks")
        R.Mark("security-life.observed")
        await R.Wait("security-life.checked1")
        await R.Wait("security-life.checked2")
        R.Mark("security-life.done")
    else:
        await R.Wait("reconnect.play.sent")
        await R.Wait("security-reconnect.prepare")
        var Before := Snapshot()
        R.Mark("security-reconnect.ready" + str(R.Index))
        await R.Wait("security-reconnect.sent")
        await R.Drain()
        Check(Snapshot() == Before, "reconnect", "disconnected transport identity cannot restore animation")
        R.Mark("security-reconnect.checked" + str(R.Index))
        await R.Wait("security-life.prepare")
        await R.Drain()
        Before = Snapshot()
        R.Mark("security-life.ready" + str(R.Index))
        await R.Wait("security-life.attack")
        if R.Index == 1:
            Send(1, "_relay_anim_v2", [int(R.Read("security-life.old")), "res://Dance.tres", "OldEpoch", 1.0, true, true], "replayed-pre-replacement-epoch")
            R.Mark("security-life.sent")
        await R.Wait("security-life.observed")
        await R.Drain()
        Check(Snapshot() == Before, "life", "out-of-order old-life play and stop have no effects")
        R.Mark("security-life.checked" + str(R.Index))
        await R.Wait("security-life.done")

func LocalOwnership() -> void:
    R.Track = await R.LoadTrack("Wave")
    R.Track.call("play")
    var Detached: Node = R.Track
    var Holder := Node.new()
    R.Game.add_child(Holder)
    Detached.reparent(Holder)
    var Before := Snapshot()
    Detached.call("play")
    Detached.call("set_speed", 2.0)
    Detached.call("set_looped", true)
    Detached.call("stop")
    Check(Snapshot() == Before and not Detached.call("is_playing"), "owner", "detached track cannot operate former Animator playback")
    Holder.queue_free()
    await R.process_frame
    R.Script("local T=game.LocalPlayer.Animator:LoadAnimation(game.ClipOnce); shared.Cancelled=T.Ended:Connect(function() game:SetAttribute('CancelledAuthorityCallback', true) end); T.Ended:Connect(function() shared.Cancelled:Disconnect(); game:SetAttribute('LiveAuthorityCallback', true) end); T:Play()")
    await R.create_timer(0.2).timeout
    Check(R.Game.get_meta("LiveAuthorityCallback", false) and not R.Game.get_meta("CancelledAuthorityCallback", false), "callback", "disconnect during completion cancels later copied callback")
    R.Script("local T=game.LocalPlayer.Animator:LoadAnimation(game.ClipWave); T.Ended:Connect(function() game:SetAttribute('RetiredAuthorityCallback', true) end); T:Play(); game:SetAttribute('RetireAuthorityReady', true)")
    var Owner: Node = R.Game.get_child(R.Game.get_child_count() - 1)
    var Deadline := Time.get_ticks_msec() + 3000
    while not R.Game.get_meta("RetireAuthorityReady", false) and Time.get_ticks_msec() < Deadline:
        await R.process_frame
    Check(R.Game.get_meta("RetireAuthorityReady", false), "callback", "executable starts before its owner is retired")
    Owner.call("set_enabled", false)
    R.Player(R.Character).seek(59.95)
    await R.create_timer(0.2).timeout
    Check(R.Game.get_meta("RetireAuthorityReady", false) and not R.Game.get_meta("RetiredAuthorityCallback", false), "callback", "retired executable receives no completion callback")

func Finish() -> void:
    Check(not is_instance_valid(R.Game), "teardown", "scene destruction completed before final evidence")
    Save(true)
    print("[Network:AnimationAuthority] ", "FAIL" if R.Failed else "PASS", " mode=", R.Mode, " role=", R.Role, " cases=", Cases.size())
