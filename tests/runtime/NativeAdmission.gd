extends SceneTree

var Cases: Array[Dictionary] = []
var Failed := false
var Measurements: Dictionary = {}

func _initialize() -> void:
    call_deferred("Run")

func Check(Value: bool, Label: String) -> void:
    Cases.append({"Label": Label, "Passed": Value})
    if not Value:
        Failed = true
        print("[Network:NativeAdmission] FAIL ", Label)

func Connection(Count: int) -> Dictionary:
    var Server := ENetConnection.new()
    Check(Server.create_host_bound("127.0.0.1", 0, Count, 2) == OK, "raw native server created")
    var Clients: Array[ENetConnection] = []
    var Receivers: Array[ENetPacketPeer] = []
    var Senders: Dictionary = {}
    for Index in range(Count):
        var Client := ENetConnection.new()
        Check(Client.create_host(1, 2) == OK, "raw native client created")
        Clients.append(Client)
        Receivers.append(Client.connect_to_host("127.0.0.1", Server.get_local_port(), 2, Index + 10))
    var Deadline := Time.get_ticks_msec() + 5000
    while Time.get_ticks_msec() < Deadline:
        var Event := Server.service(0)
        if int(Event[0]) == ENetConnection.EVENT_CONNECT:
            Senders[int(Event[2]) - 10] = Event[1]
        var Connected := Senders.size() == Count
        for Index in range(Count):
            Clients[Index].service(0)
            Connected = Connected and Receivers[Index].get_state() == ENetPacketPeer.STATE_CONNECTED
        if Connected:
            return {"Server": Server, "Clients": Clients, "Receivers": Receivers, "Senders": Senders}
        await process_frame
    Check(false, "raw native connections reach ready state")
    return {}

func State(Peer: ENetPacketPeer) -> Dictionary:
    return Peer.call("GetGodotLuauAdmission")

func Close(Pair: Dictionary) -> void:
    for Client in Pair.Clients:
        Client.destroy()
    Pair.Server.destroy()

func Payload(Size: int) -> PackedByteArray:
    var Bytes := PackedByteArray()
    Bytes.resize(Size)
    Bytes.fill(65)
    return Bytes

func Run() -> void:
    var Pair := await Connection(1)
    if Pair.is_empty():
        Finish()
        return
    var Peer: ENetPacketPeer = Pair.Senders[0]
    Check(Peer.has_method("GetGodotLuauAdmission"), "native admission capability exists")
    if not Peer.has_method("GetGodotLuauAdmission"):
        Close(Pair)
        Finish()
        return
    var Initial := State(Peer)
    Check(int(Initial.Version) == 1 and int(Initial.PeerBytes) == 0 and int(Initial.PeerCommands) == 0, "fresh native data ownership is empty")
    Check(int(Initial.UnfragmentedPacketBytes) > 0 and int(Initial.UnfragmentedPacketBytes) < int(Initial.MTU), "native negotiated unfragmented budget reserves protocol overhead")
    var Maximum := Payload(int(Initial.PeerByteLimit))
    Check(Peer.send(0, Maximum, ENetPacketPeer.FLAG_RELIABLE) == OK, "exact peer byte limit is admitted")
    var Full := State(Peer)
    Check(int(Full.PeerBytes) == Maximum.size() and int(Full.PeerPackets) == 1, "whole fragmented packet has one exact data charge")
    Check(int(Full.PeerCommands) > 1 and int(Full.PeerCommands) <= int(Full.PeerCommandLimit), "native fragment commands are charged")
    for Index in range(100):
        Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == ERR_BUSY, "one-over peer admission rejects without ownership")
    Check(State(Peer) == Full, "repeated rejected packets leave prior native ownership unchanged")
    var Partial := State(Peer)
    var PartialDeadline := Time.get_ticks_msec() + 5000
    while int(Partial.PeerCommands) == int(Full.PeerCommands) and Time.get_ticks_msec() < PartialDeadline:
        Pair.Server.flush()
        Pair.Clients[0].service(0)
        Pair.Clients[0].flush()
        Pair.Server.service(0)
        Partial = State(Peer)
        if int(Partial.PeerCommands) < int(Full.PeerCommands):
            break
        await process_frame
    Measurements["FragmentCommandsBefore"] = Full.PeerCommands
    Measurements["FragmentCommandsAfterPartialAck"] = Partial.PeerCommands
    Check(int(Partial.PeerCommands) > 0 and int(Partial.PeerCommands) < int(Full.PeerCommands), "actual partial native ACK retires only some commands")
    Check(int(Partial.PeerBytes) == Maximum.size() and int(Partial.PeerPackets) == 1, "partial ACK retains the entire packet buffer charge")
    var Deadline := Time.get_ticks_msec() + 15000
    var Received := false
    while Time.get_ticks_msec() < Deadline and int(State(Peer).PeerBytes) != 0:
        Pair.Server.service(0)
        var Event: Array = Pair.Clients[0].service(0)
        if int(Event[0]) == ENetConnection.EVENT_RECEIVE:
            Received = true
        await process_frame
    Check(Received and int(State(Peer).PeerBytes) == 0 and int(State(Peer).PeerCommands) == 0, "complete native ACK retires exact retained ownership")
    Check(Peer.send(0, Payload(64), ENetPacketPeer.FLAG_UNSEQUENCED) == OK, "unordered native packet is admitted")
    Check(int(State(Peer).PeerBytes) == 64, "unordered work is charged before native handoff")
    Pair.Server.flush()
    Check(int(State(Peer).PeerBytes) == 0, "unordered native handoff releases its packet charge")
    Check(Peer.send(0, Payload(1024), ENetPacketPeer.FLAG_RELIABLE) == OK, "reliable ownership can be admitted again after retirement")
    Peer.reset()
    Check(not bool(State(Peer).Active) and int(State(Peer).PeerBytes) == 0 and int(State(Peer).PeerCommands) == 0, "native reset retires the exact peer ownership")
    Close(Pair)

    Pair = await Connection(5)
    if Pair.is_empty():
        Finish()
        return
    for Index in range(4):
        Check(Pair.Senders[Index].send(0, Maximum, ENetPacketPeer.FLAG_RELIABLE) == OK, "native host accepts bounded per-peer fanout")
    Peer = Pair.Senders[4]
    var Aggregate := State(Peer)
    Check(int(Aggregate.HostBytes) == int(Aggregate.HostByteLimit), "native host byte limit is exactly full")
    Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == ERR_BUSY, "one-over host admission rejects without charging a new peer")
    Check(State(Peer) == Aggregate and int(Aggregate.PeerBytes) == 0, "aggregate rejection preserves all previous native ownership")
    Pair.Senders[0].reset()
    Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == OK, "one peer reset releases host capacity for another peer")
    var Healthy := State(Peer)
    Check(Pair.Server.broadcast(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == ERR_BUSY, "native partial fanout reports blocked destinations")
    Check(int(State(Peer).PeerBytes) == int(Healthy.PeerBytes) + 1, "healthy fanout recipient proceeds while full peers reject")
    Check(int(State(Pair.Senders[1]).PeerBytes) == Maximum.size(), "blocked broadcast keeps old slow-peer packet ownership")
    var Survivor: ENetPacketPeer = Pair.Senders[4]
    Close(Pair)
    Check(not bool(State(Survivor).Active) and int(State(Survivor).PeerBytes) == 0, "host destruction invalidates retained peer observations safely")
    Pair = await Connection(5)
    if Pair.is_empty():
        Finish()
        return
    for Index in range(4):
        Peer = Pair.Senders[Index]
        # Reach most of the command count with one fragmented buffer. Keep byte
        # headroom for the remaining tiny commands; do not conflate the limits.
        Check(Peer.send(0, Payload(int(State(Peer).PeerByteLimit) - 8192), ENetPacketPeer.FLAG_RELIABLE) == OK, "fragment commands seed the command-boundary fixture")
        var Remaining := int(State(Peer).PeerCommandLimit) - int(State(Peer).PeerCommands)
        for Command in range(Remaining):
            if Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) != OK:
                Check(false, "exact native command-count limit admitted")
                break
        var Commands := State(Peer)
        Check(int(Commands.PeerCommands) == int(Commands.PeerCommandLimit) and int(Commands.PeerBytes) < int(Commands.PeerByteLimit), "small packets reach command ceiling below byte ceiling")
        Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == ERR_BUSY and State(Peer) == Commands, "one-over native command-count rejection preserves ownership")
    Peer = Pair.Senders[4]
    var HostCommands := State(Peer)
    Check(int(HostCommands.HostCommands) == int(HostCommands.HostCommandLimit) and int(HostCommands.HostBytes) < int(HostCommands.HostByteLimit), "aggregate command ceiling is independent of payload byte ceiling")
    Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == ERR_BUSY and State(Peer) == HostCommands, "one-over host command-count rejection does not charge another peer")
    Pair.Senders[0].reset()
    Check(Peer.send(0, Payload(1), ENetPacketPeer.FLAG_RELIABLE) == OK, "native command capacity recovers after peer retirement")
    Close(Pair)
    Finish()

func Finish() -> void:
    var Output := FileAccess.open("res://native-admission.json", FileAccess.WRITE)
    Output.store_string(JSON.stringify({"Result": "FAIL" if Failed else "PASS", "Complete": true, "Cases": Cases, "Measurements": Measurements}, "  "))
    Output.close()
    print("[Network:NativeAdmission] ", "FAIL" if Failed else "PASS", " cases=", Cases.size())
    quit(1 if Failed else 0)
