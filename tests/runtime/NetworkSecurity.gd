extends SceneTree

# File barriers coordinate processes; every attack and positive network control
# still traverses the real ENet / SceneMultiplayer RPC dispatch.
var Game: Node
var Network: Node
var Role := "server"
var Mode := "Dedicated"
var Port := 0
var Index := 0
var Failed := false
var Messages: Array[String] = []
var Removed := 0
var First := 0
var Second := 0

func Capture(Name: String, Text: String) -> void:
    # Observe displayed Unicode directly; legacy Luau SetAttribute converts
    # UTF-8 with a Latin-1 constructor and is not a Unicode observation channel.
    Messages.append(Name + ": " + Text)
    print("[Network:SecurityTest] displayed ", Name, " characters=", Text.length(), " preview=", Text.substr(0, 24))
    Game.set_meta("Messages", "\n".join(Messages))

func Check(Value: bool, Description: String) -> void:
    if not Value:
        Failed = true
        print("[Network:SecurityTest] FAIL ", Role, " ", Description)

func Mark(Name: String, Value := "ready") -> void:
    var File := FileAccess.open("res://security-" + Name, FileAccess.WRITE)
    File.store_string(Value)
    File.close()

func Read(Name: String) -> String:
    return FileAccess.get_file_as_string("res://security-" + Name)

func Wait(Name: String) -> void:
    var Deadline := Time.get_ticks_msec() + 12000
    while not FileAccess.file_exists("res://security-" + Name):
        if Time.get_ticks_msec() > Deadline:
            Check(false, "barrier " + Name)
            quit(1)
            return
        await process_frame

func Drain() -> void:
    await create_timer(0.25).timeout

func Create(Type: String, Name: String) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Game.add_child(Result)
    return Result

func Script(Name: String, Source: String) -> Node:
    var Result: Node = ClassDB.instantiate("ServerScript" if Role == "server" else "LocalScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Position in range(Arguments.size() - 1):
        if Arguments[Position] == "--fixture-role": Role = Arguments[Position + 1]
        if Arguments[Position] == "--fixture-port": Port = int(Arguments[Position + 1])
        if Arguments[Position] == "--fixture-client-index": Index = int(Arguments[Position + 1])
        if Arguments[Position] == "--security-mode": Mode = Arguments[Position + 1]
    call_deferred("Run")

func Puppet(Peer: int) -> Node:
    return root.get_node_or_null("RemotePlayer_" + str(Peer))

func SendState() -> void:
    if Index == 1:
        Network.rpc_id(1, "_relay_state", Vector3(10, 0, 0), 0.0, 999, 100.0, 0.0, false)
    else:
        Network.rpc_id(1, "_relay_state2d", Vector2(20, 0), 0.0, 999)

func Attack(Target: int) -> void:
    # A modified client can alter its own RPC configuration. This never alters
    # the remote service's configuration or its handler guards.
    for Method in ["_recv_state", "_recv_state2d", "_recv_remove", "_recv_chat"]:
        Network.rpc_config(Method, {"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER,
            "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE if Method in ["_recv_remove", "_recv_chat"] else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,
            "call_local": false, "channel": 0})
    for Who in [First, Second, -1, 0, 2147483647]:
        Network.rpc_id(Target, "_recv_state", Who, Vector3(9999, 9999, 9999), 0.0, 888, 1.0, 0.0, false)
        Network.rpc_id(Target, "_recv_state2d", Who, Vector2(9999, 9999), 0.0, 888)
        Network.rpc_id(Target, "_recv_remove", Who)
    Network.rpc_id(Target, "_recv_chat", 1, "SYSTEM", "FORGED_RECEIVE")
    if Target != 1:
        Network.rpc_id(Target, "_relay_state", Vector3(9999, 9999, 9999), 0.0, 888, 1.0, 0.0, false)
        Network.rpc_id(Target, "_relay_state2d", Vector2(9999, 9999), 0.0, 888)
        Network.rpc_id(Target, "_relay_chat", "SYSTEM", "FORGED_RELAY")

func ObserveStable() -> void:
    for Peer in [First, Second]:
        if Peer == Network.call("get_peer_id"): continue
        var Character := Puppet(Peer)
        Check(is_instance_valid(Character), "player survived unauthorized removal " + str(Peer))
        if is_instance_valid(Character):
            var Expected := 10.0 if Peer == First else 20.0
            Check(is_equal_approx(Character.get("global_position").x, Expected), "presentation unchanged " + str(Peer))
            if Peer == First:
                Check(is_equal_approx(float(Character.get_node("Humanoid").get("Health")), 100.0), "health unchanged")
        Check(is_instance_valid(Network.call("player_node_for_peer", Peer)), "player registry retained")
    for Peer in [-1, 0, 2147483647]: Check(Puppet(Peer) == null, "no forged target " + str(Peer))
    Check(int(Game.get_meta("Removed", 0)) == 0, "no removal callback")
    Check(not str(Game.get_meta("Messages", "")).contains("FORGED"), "no forged chat display/callback")

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
    Create("TextChatService", "TextChatService")
    Game.get_node("TextChatService/ChatWindow").connect("MessageSent", Capture)
    Network = Create("NetworkService", "NetworkService")
    await process_frame
    Script("Observations", """
game:GetService('TextChatService').MessageReceived:Connect(function(Message)
    game:SetAttribute('ChatCallbacks', (game:GetAttribute('ChatCallbacks') or 0) + 1)
    game:SetAttribute('Messages', (game:GetAttribute('Messages') or '') .. Message .. '\\n')
end)
game:GetService('Players').PlayerRemoving:Connect(function(Player)
    game:SetAttribute('Removed', (game:GetAttribute('Removed') or 0) + 1)
end)
game:SetAttribute('Observing', true)
""")
    while not Game.has_meta("Observing"): await process_frame
    if Mode == "Local":
        Network.call("_recv_state", 7, Vector3.ZERO, 0.0, 7, 100.0, 0.0, false)
        Network.call("_recv_state2d", 8, Vector2.ZERO, 0.0, 8)
        Network.call("_recv_remove", 1)
        Network.call("_recv_chat", 1, "SYSTEM", "FORGED_LOCAL")
        Network.call("_relay_chat", "SYSTEM", "FORGED_LOCAL_RELAY")
        Check(Puppet(7) == null and Puppet(8) == null, "inbound handlers reject sender zero")
        Check(not Game.has_meta("Messages"), "inbound local chat rejected")
        Network.call("gl_send_chat", "Local", "LOCAL_OK")
        Check(str(Game.get_meta("Messages", "")).contains("Local: LOCAL_OK"), "single-player local chat")
        var Chat := Game.get_node("TextChatService/ChatWindow")
        var Input: LineEdit = Chat.find_children("*", "LineEdit", true, false)[0]
        Input.text = "UI_LOCAL_OK"
        Chat.call("_on_send_pressed")
        Check(str(Game.get_meta("Messages", "")).contains("UI_LOCAL_OK"), "single-player chat UI")
        Game.get_node("Players").free()
        Input.text = "NO_PLAYERS_OK"
        Chat.call("_on_send_pressed")
        Check(str(Game.get_meta("Messages", "")).contains("NO_PLAYERS_OK"), "local chat without Players service")
    elif Role == "server":
        if Network.call("get_mode") != 1:
            Script("StartHost", "assert(game:GetService('NetworkService'):StartServer(game:GetAttribute('Port'), 4))")
            while not Network.call("is_connected_net"): await process_frame
        Mark("ready")
        await Wait("client1.peer")
        await Wait("client2.peer")
        First = int(Read("client1.peer"))
        Second = int(Read("client2.peer"))
        if Mode == "Handler": ConfigureHandlerProbe()
        await Wait("preinit.sent")
        await Drain()
        Check(not Game.has_meta("Messages"), "pre-initialization chat rejected")
        Mark("initialize")
        await Wait("client1.initialized")
        await Wait("client2.initialized")
        await Drain()
        ObserveStable()
        var Player: Node = Network.call("player_node_for_peer", First)
        Script("IdentityCheck", "for _, Player in ipairs(game:GetService('Players'):GetPlayers()) do if Player.Name == '" + str(Player.name) + "' then assert(Player.Name == 'Player' .. tostring(Player.UserId)); game:SetAttribute('IdentityChecked', true) end end")
        await process_frame
        Check(Game.has_meta("IdentityChecked"), "first state index cannot choose identity")
        var ExpectedName := str(Player.name)
        Mark("expected", ExpectedName)
        Mark("attack")
        await Wait("attacks.sent")
        await Drain()
        ObserveStable()
        Mark("observed")
        await Wait("client2.observed")
        Mark("chat")
        await Wait("chat.sent")
        await Drain()
        CheckChat(ExpectedName)
        Mark("recover")
        await Wait("recovered.sent")
        await Drain()
        Check(str(Game.get_meta("Messages", "")).contains("RECOVERED_OK"), "rate refill permits later valid chat")
        Network.call("gl_send_chat", "SYSTEM", "SERVER_OK")
        Check(str(Game.get_meta("Messages", "")).contains("SYSTEM: SERVER_OK"), "server-local chat")
        # Valid server-origin updates and bounds still work after rejection.
        Network.rpc("_recv_state", First, Vector3(11, 0, 0), 0.0, 2, 95.0, 0.0, false)
        Network.rpc("_recv_state2d", Second, Vector2(21, 0), 0.0, 3)
        Network.rpc("_recv_state", -9, Vector3.ZERO, 0.0, 1, 100.0, 0.0, false)
        Mark("positive")
        await Wait("client2.positive")
        await Drain()
        Check(str(Game.get_meta("Messages", "")).contains("SECOND_OK"), "independent client allowance")
        Mark("disconnect")
        await Wait("client1.disconnected")
        await Drain()
        Check(Puppet(First) == null, "disconnect removes character")
        Check(Network.call("player_node_for_peer", First) == null, "disconnect removes session player")
        Check(int(Game.get_meta("Removed", 0)) == 1, "one legitimate removal callback")
        Mark("reconnect")
        await Wait("client1.reconnected")
        await Drain()
        var Reconnected := int(Read("reconnected.peer"))
        Check(is_instance_valid(Network.call("player_node_for_peer", Reconnected)), "reconnect registered")
        Check(str(Game.get_meta("Messages", "")).contains("RECONNECT_OK"), "fresh session chat/rate allowance")
        Check(not str(Game.get_meta("Messages", "")).contains("RECONNECT_EARLY"), "reconnect before identity rejected")
        var SessionPlayer: Node = Network.call("player_node_for_peer", Reconnected)
        SessionPlayer.queue_free()
        await process_frame
        Mark("invalidrecord")
        await Wait("invalidrecord.sent")
        await Drain()
        Check(not str(Game.get_meta("Messages", "")).contains("MISSING_RECORD"), "invalidated ObjectID rejected")
        Puppet(Reconnected).queue_free()
        await process_frame
        Mark("restore")
        await Wait("restored.sent")
        await Drain()
        Check(str(Game.get_meta("Messages", "")).contains("RESTORED_OK"), "replacement player record accepted")
        Mark("done")
        await Wait("client1.done")
        while Game.get_multiplayer().get_peers().has(Reconnected): await process_frame
        await process_frame # finish the transport poll before the second close
        Mark("client2.close")
        await Wait("client2.done")
        while Game.get_multiplayer().get_peers().size() > 0: await process_frame
        await process_frame
    else:
        Script("ConnectClient", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
        while not Network.call("is_connected_net"): await process_frame
        Mark("client" + str(Index) + ".peer", str(Network.call("get_peer_id")))
        await Wait("client1.peer")
        await Wait("client2.peer")
        First = int(Read("client1.peer"))
        Second = int(Read("client2.peer"))
        if Mode == "Handler": ConfigureHandlerProbe()
        if Index == 1:
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "PREINIT_FORGED")
            Mark("preinit.sent")
        await Wait("initialize")
        SendState()
        await Drain()
        Mark("client" + str(Index) + ".initialized")
        await Wait("attack")
        if Index == 1:
            Attack(1)
            Attack(Second)
            Mark("attacks.sent")
        await Wait("observed")
        if Index == 2:
            ObserveStable()
            Mark("client2.observed")
        await Wait("chat")
        if Index == 1:
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "OVERSIZE".repeat(200))
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "BAD\nCONTROL")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "BAD" + String.chr(127) + "CONTROL")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", ["MALFORMED"])
            Network.rpc_id(1, "_relay_chat", "SYSTEM", " ")
            Network.rpc_id(1, "_relay_chat", "Player3", "SPOOF_OTHER")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "SPOOF_SYSTEM")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "界".repeat(256))
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "界".repeat(257))
            for Count in range(12): Network.rpc_id(1, "_relay_chat", "SYSTEM", "BURST_" + str(Count))
            Mark("chat.sent")
        await Wait("recover")
        if Index == 1:
            await create_timer(1.1).timeout
            var Chat := Game.get_node("TextChatService/ChatWindow")
            var Input: LineEdit = Chat.find_children("*", "LineEdit", true, false)[0]
            var CountBefore := Messages.size()
            Input.text = "RECOVERED_OK"
            Chat.call("_on_send_pressed")
            Check(Messages.size() == CountBefore, "no optimistic network UI echo")
            Mark("recovered.sent")
        await Wait("positive")
        await Drain()
        CheckChat(Read("expected"))
        Check(str(Game.get_meta("Messages", "")).contains("SYSTEM: SERVER_OK"), "receive valid server chat")
        if Index == 2:
            var Character := Puppet(First)
            Check(is_instance_valid(Character) and is_equal_approx(Character.get("global_position").x, 11.0), "valid subsequent 3D state")
            Check(Puppet(-9) == null, "server invalid target rejected")
            Network.rpc_id(1, "_relay_chat", "Other", "SECOND_OK")
            Mark("client2.positive")
        else:
            var Character := Puppet(Second)
            Check(is_instance_valid(Character) and is_equal_approx(Character.get("global_position").x, 21.0), "valid subsequent 2D state")
        await Wait("disconnect")
        if Index == 1:
            Attack(1)
            Network.call("disconnect_net")
            Network.call("_relay_chat", "SYSTEM", "DISCONNECTED_FORGED")
            Mark("client1.disconnected")
            await Wait("reconnect")
            Script("ReconnectClient", "assert(game:GetService('NetworkService'):Connect('127.0.0.1', game:GetAttribute('Port')))")
            while not Network.call("is_connected_net"): await process_frame
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "RECONNECT_EARLY")
            await Drain()
            SendState()
            await Drain()
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "RECONNECT_OK")
            Mark("reconnected.peer", str(Network.call("get_peer_id")))
            Mark("client1.reconnected")
            await Wait("invalidrecord")
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "MISSING_RECORD")
            Mark("invalidrecord.sent")
            await Wait("restore")
            SendState()
            await Drain()
            Network.rpc_id(1, "_relay_chat", "SYSTEM", "RESTORED_OK")
            Mark("restored.sent")
        await Wait("done")
        if Index == 2:
            Check(int(Game.get_meta("Removed", 0)) == 1, "victim sees only real disconnect callback")
            Check(str(Game.get_meta("Messages", "")).contains("RECONNECT_OK"), "victim sees reconnected chat")
            await Wait("client2.close")
        Mark("client" + str(Index) + ".done")
    Check(int(Game.get_meta("ChatCallbacks", 0)) == Messages.size(), "display and Lua callback counts agree")
    print("[Network:SecurityTest] ", Role, " ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)

func ConfigureHandlerProbe() -> void:
    for Method in ["_recv_state", "_recv_state2d", "_recv_remove", "_recv_chat"]:
        Network.rpc_config(Method, {"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER,
            "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE if Method in ["_recv_remove", "_recv_chat"] else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,
            "call_local": false, "channel": 0})

func CheckChat(ExpectedName: String) -> void:
    var Text := str(Game.get_meta("Messages", ""))
    Check(Text.contains(ExpectedName + ": SPOOF_OTHER"), "spoofed player name replaced")
    Check(Text.contains(ExpectedName + ": SPOOF_SYSTEM"), "spoofed system name replaced")
    Check(not Text.contains("SYSTEM: SPOOF"), "no system impersonation")
    Check(not Text.contains("OVERSIZE") and not Text.contains("BAD") and not Text.contains("FORGED") and not Text.contains("MALFORMED"), "invalid text has no display side effects")
    Check(Text.contains("界".repeat(256)) and not Text.contains("界".repeat(257)), "Unicode message bounds")
    Check(Text.count("BURST_") == 2, "five-token session burst bound")
