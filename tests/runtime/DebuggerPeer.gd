extends SceneTree

# Test-owned editor peer uses Godot's own Variant packet implementation. The
# debuggee is the actual production Luau/Godot implementation, not a debugger mock.
var Listener = TCPServer.new()
var Stream: StreamPeerTCP
var Peer = PacketPeerStream.new()
var Inputs: Dictionary
var Nonce = ""
var RequestId = 0
var ThreadId = 0
var Stops = 0
var VariablesLeft = -1
var Variables: Dictionary = {}
var Expected: Array = []
var Checks: Array = []
var Errors = 0
var CurrentSource = ""
var CurrentLine = 0
var CurrentDomain = ""
var Finished = false

func _initialize() -> void:
    call_deferred("Run")

func Check(Condition: bool, Label: String) -> void:
    if Finished:
        return
    Checks.append({"Label": Label, "Passed": Condition})
    print("[Debugger:Native] %s %s" % ["PASS" if Condition else "FAIL", Label])
    if not Condition:
        Finish(false)

func Finish(Passed: bool) -> void:
    if Finished:
        return
    Finished = true
    var Report = {"Passed": Passed, "Checks": Checks, "Stops": Stops, "ErrorsRejected": Errors, "Graphical": false}
    var File = FileAccess.open("res://results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify(Report, "  "))
    File.close()
    if Stream:
        Stream.disconnect_from_host()
    Listener.stop()
    print("[Debugger:Native] %s protocol qualification" % ("PASS" if Passed else "FAIL"))
    quit(0 if Passed else 1)

func Send(Message: String, Data: Array = []) -> void:
    if Finished:
        return
    Check(Peer.put_var([Message, ThreadId, Data]) == OK, "Native debugger command accepted: " + Message)

func Command(Op: String, Fields: Dictionary = {}) -> void:
    RequestId += 1
    var Request = {"Schema": 1, "Session": Nonce, "Request": RequestId, "Op": Op}
    Request.merge(Fields, true)
    Send("godotluau:command", [Request])

func Value(Name: String) -> Variant:
    return Variables.get(Name)

func AfterVariables() -> void:
    if Finished:
        return
    var ExpectedStop: Dictionary = Expected[Stops]
    Check(CurrentSource == ExpectedStop.Source and CurrentLine == ExpectedStop.Line, "Real source stop %d: %s:%d" % [Stops, CurrentSource, CurrentLine])
    Check(CurrentDomain == ExpectedStop.Domain, "Execution-domain label at stop %d" % Stops)
    if Finished:
        return
    if Stops == 0:
        Check(Value("State") is Dictionary and JSON.stringify(Value("State")).contains("Reference"), "Cyclic table inspection has bounded identity references")
        Check(not JSON.stringify(Variables).contains("GL055-Secret-Sentinel") and JSON.stringify(Value("State")).contains("<redacted>"), "Sensitive named table entries are redacted")
        Check(Value("Box") is Dictionary and Value("Box").get("State") == "Alive" and Value("Box").get("ClassName") == "Node3D", "Real owned native node inspection")
        Check(Value("Material") is Dictionary and Value("Material").get("Kind") == "Resource" and Value("Material").get("State") == "Alive", "Real owned native resource inspection")
        if Inputs.get("Disconnect", false):
            Check(true, "Disconnect while the actual VM is suspended")
            Stops += 1
            Finish(true)
            return
        # Closed types, session identity, sequence and domain rejection. All
        # commands go through the real EngineDebugger capture, without Lua eval.
        Command("Status")
        Command("Status", {"Session": "wrong"})
        Command("Breakpoint", {"Source": ["bad"], "Line": 1, "Enabled": true})
        Command("Status", {"Unexpected": true})
        Send("godotluau:command", [{"Schema": 1, "Session": Nonce, "Request": 1, "Op": "Status"}])
        Send("step")
    elif Stops == 1:
        Check(Value("argument: Value") == 40 and Value("upvalue: Increment") == 1, "Live function arguments and upvalues")
        Send("next")
    elif Stops == 2:
        Check(Value("Current") == 41, "Step over reads the actual current local")
        Command("StepOut", {"Domain": "Server"})
        Send("continue")
    elif Stops == 3:
        Check(Value("Result") == 42, "Step out returns to the actual caller")
        Send("continue")
    elif Stops == 4:
        Check(Value("Value") == 8, "Imported module has its own live frame")
        Send("continue")
    elif Stops == 5:
        Check(Value("Value") == 10, "Client domain stack is separate from Server")
        Send("continue")
    elif Stops == 6:
        Check(Value("upvalue: Result") == 42, "Native signal callback inspects its own captured state")
        Send("continue")
    elif Stops == 7:
        Check(Value("Box") is Dictionary and Value("Box").get("State") == "Destroyed", "Destroyed native handle reports invalidation without a native reference")
        Check(Errors >= 4, "Malformed stale duplicate and wrong-session commands reject")
        Send("continue")
    Stops += 1

func Receive(Message: Array) -> void:
    Check(Message.size() == 3 and Message[0] is String and Message[1] is int and Message[2] is Array, "Native protocol envelope")
    if Finished:
        return
    var Name: String = Message[0]
    ThreadId = Message[1]
    var Data: Array = Message[2]
    if Name == "godotluau:debugger" and Data.size() == 1 and Data[0] is Dictionary:
        var Reply: Dictionary = Data[0]
        Nonce = Reply.get("Session", "")
        if Reply.get("Event") == "Error":
            Errors += 1
        if Reply.get("Event") == "Stopped":
            CurrentDomain = Reply.get("Domain", "")
    elif Name == "debug_enter":
        Check(Stops < Expected.size() and Data.size() >= 3 and Data[0] == true and Data[2] == true, "Godot enters a continuable live Luau stack")
        Send("get_stack_dump")
    elif Name == "stack_dump":
        Check(Data.size() >= 4 and Data[0] >= 3 and Data[0] <= 192, "Bounded native stack dump")
        if Finished:
            return
        CurrentSource = Data[1]
        CurrentLine = Data[2]
        Variables = {}
        Send("get_stack_frame_vars", [0])
    elif Name == "stack_frame_vars":
        Check(Data.size() == 1 and Data[0] > 0 and Data[0] <= 256, "Bounded native variable count")
        VariablesLeft = Data[0]
    elif Name == "stack_frame_var":
        Check(Data.size() == 4 and Data[0] is String, "Native variable payload")
        if Finished:
            return
        Variables[Data[0]] = Data[3]
        VariablesLeft -= 1
        if VariablesLeft == 0:
            AfterVariables()
    elif Name == "output":
        # Target process exit is checked independently by the process runner.
        pass

func Run() -> void:
    Inputs = JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
    Expected = Inputs.Expected
    Check(Listener.listen(Inputs.Port, "127.0.0.1") == OK, "Loopback-only test editor listener")
    if Finished:
        return
    var Ready = FileAccess.open("res://ready.json.pending", FileAccess.WRITE)
    Ready.store_string(JSON.stringify({"Port": Inputs.Port}))
    Ready.close()
    Check(DirAccess.rename_absolute("res://ready.json.pending", "res://ready.json") == OK, "Atomic test-peer readiness")
    var Deadline = Time.get_ticks_msec() + 45000
    while Time.get_ticks_msec() < Deadline and not Finished:
        if not Stream and Listener.is_connection_available():
            Stream = Listener.take_connection()
            Peer.stream_peer = Stream
        if Stream:
            Stream.poll()
            for Index in range(128):
                if Peer.get_available_packet_count() == 0:
                    break
                var Message = Peer.get_var(false)
                if Message is Array:
                    Receive(Message)
                else:
                    Check(false, "Native peer returned an Array")
                if Finished:
                    return
            if FileAccess.file_exists("res://target-finished.json"):
                Check(Stops == Expected.size(), "Every expected breakpoint step import callback and stale-handle stop executed")
                Finish(not Finished)
                return
        await process_frame
    if not Finished:
        Check(false, "Debugger protocol deadline")
