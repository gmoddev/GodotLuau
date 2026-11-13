@tool
extends EditorPlugin

var Checks: Array = []
var Finished = false
var Native: Node
var Graphical = false
var Captures: Array = []

func _enter_tree() -> void:
    call_deferred("Run")

func Check(Value: bool, Label: String) -> bool:
    Checks.append({"Label": Label, "Passed": Value})
    print("[Debugger:Editor] %s %s" % ["PASS" if Value else "FAIL", Label])
    return Value

func Find(From: Node, Class: String, Name: String = "") -> Node:
    var Work: Array = [[From, 0]]
    var Visited = 0
    while not Work.is_empty() and Visited < 12000:
        Visited += 1
        var Item = Work.pop_back()
        var Current: Node = Item[0]
        if Current.is_class(Class) and (Name.is_empty() or Current.name == Name):
            return Current
        if Item[1] < 32:
            for Child in Current.get_children():
                Work.append([Child, Item[1] + 1])
    return null

func Session(Stop: int, Connection: int = 0) -> Dictionary:
    if not is_instance_valid(Native):
        return {}
    for State in Native.call("GetDebuggerSessions"):
        if State.get("Active", false) and State.get("Paused", false) and State.get("StopId", 0) == Stop and State.get("ConnectionGeneration", 0) >= Connection:
            return State
    return {}

func WaitStop(Stop: int, Connection: int = 0) -> Dictionary:
    var Deadline = Time.get_ticks_msec() + 25000
    while Time.get_ticks_msec() < Deadline:
        var State = Session(Stop, Connection)
        if not State.is_empty():
            return State
        await get_tree().process_frame
    return {}

func Tab() -> Node:
    var Root = EditorInterface.get_base_control()
    var Work: Array = [[Root, 0]]
    var Visited = 0
    while not Work.is_empty() and Visited < 12000:
        Visited += 1
        var Entry = Work.pop_back()
        var Current: Node = Entry[0]
        if Current is VBoxContainer and Current.name == "Luau" and Find(Current, "Button"):
            return Current
        if Entry[1] < 32:
            for Child in Current.get_children():
                Work.append([Child, Entry[1] + 1])
    return null

func Press(Op: String) -> bool:
    var Panel = Tab()
    if not Panel:
        return Check(false, "Native Luau debugger session tab exists")
    for Button in Panel.find_children("*", "Button", true, false):
        if Button.text == Op:
            Button.emit_signal("pressed")
            return Check(true, "Actual native debugger control: " + Op)
    return Check(false, "Native control is available: " + Op)

func Capture(Label: String) -> void:
    if not Graphical:
        return
    await RenderingServer.frame_post_draw
    var Image = get_viewport().get_texture().get_image()
    if Check(Image != null and not Image.is_empty(), "Actual rendered debugger image: " + Label):
        var Path = "res://debugger-" + Label + ".png"
        if Check(Image.save_png(Path) == OK, "Saved debugger capture: " + Label):
            Captures.append(Path)

func Watch() -> bool:
    var Panel = Tab()
    if not Panel:
        return Check(false, "Native debugger Watch panel exists")
    var Input: LineEdit
    for Field in Panel.find_children("*", "LineEdit", true, false):
        if Field.placeholder_text.begins_with("Restricted watch:"):
            Input = Field
    if not Check(Input != null, "Actual native restricted Watch input"):
        return false
    Input.text = "Box.ClassName"
    if not Press("Watch"):
        return false
    var Deadline = Time.get_ticks_msec() + 5000
    while Time.get_ticks_msec() < Deadline:
        var State = Session(1)
        if State.get("Event") == "Watch":
            return Check(State.get("Ok", false) and State.get("Value") == "Node3D", "Native editor Watch resolves the owned live Godot node")
        await get_tree().process_frame
    return Check(false, "Actual Watch response arrives")

func Finish(Passed: bool) -> void:
    if Finished:
        return
    Finished = true
    if EditorInterface.is_playing_scene():
        EditorInterface.stop_playing_scene()
    var File = FileAccess.open("res://editor-debugger-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks, "Graphical": Graphical, "Captures": Captures, "PhysicalInput": false}, "  "))
    File.close()
    print("[Debugger:Editor] %s native editor journey" % ("PASS" if Passed else "FAIL"))
    get_tree().quit(0 if Passed else 1)

func Run() -> void:
    Graphical = DisplayServer.get_name() != "headless"
    var Deadline = Time.get_ticks_msec() + 15000
    while not Native and Time.get_ticks_msec() < Deadline:
        Native = Find(get_tree().root, "GLNativeEditorPlugin")
        await get_tree().process_frame
    if not Check(Native != null, "Actual native editor plugin loaded"):
        Finish(false)
        return
    var Source = load("res://Journey.luau")
    EditorInterface.edit_script(Source, 0, 0, false)
    var Editor = EditorInterface.get_script_editor()
    while not Editor.get_current_editor() and Time.get_ticks_msec() < Deadline:
        await get_tree().process_frame
    var Code = Editor.get_current_editor().get_base_editor() as CodeEdit if Editor.get_current_editor() else null
    if not Check(Code != null, "Luau opens in the actual native CodeEdit"):
        Finish(false)
        return
    var EntryLine = -1
    for Line in range(Code.get_line_count()):
        if Code.get_line(Line).contains("GL055:Entry"):
            EntryLine = Line
    if not Check(EntryLine >= 0, "Entrypoint breakpoint source exists"):
        Finish(false)
        return
    Code.set_line_as_breakpoint(EntryLine, true)
    if not Check(Code.is_line_breakpointed(EntryLine), "Actual ScriptEditor breakpoint gutter is set"):
        Finish(false)
        return
    EditorInterface.play_main_scene()
    var State = await WaitStop(1)
    if not Check(not State.is_empty() and State.get("Domain") == "Server" and State.get("Generation", 0) > 0 and State.get("CoroutineId", 0) > 0, "Actual editor session pauses with live owner and coroutine identity"):
        Finish(false)
        return
    var Admitted = false
    for Breakpoint in State.get("Breakpoints", []):
        if Breakpoint.get("Source") == "res://Journey.luau" and Breakpoint.get("AdmittedLines", []).has(EntryLine + 1):
            Admitted = true
    if not Check(Admitted, "Runtime admits the actual gutter breakpoint"):
        Finish(false)
        return
    var Connection: int = State.get("ConnectionGeneration", 0)
    if not await Watch():
        Finish(false)
        return
    await Capture("breakpoint")
    if not Press("StepInto") or (await WaitStop(2)).is_empty():
        Finish(false)
        return
    if not Press("StepOver") or (await WaitStop(3)).is_empty():
        Finish(false)
        return
    if not Press("StepOut") or (await WaitStop(4)).is_empty():
        Finish(false)
        return
    await Capture("stepping")
    if not Press("Continue"):
        Finish(false)
        return
    var Continued = Time.get_ticks_msec() + 5000
    while not Session(4).is_empty() and Time.get_ticks_msec() < Continued:
        await get_tree().process_frame
    Check(Session(4).is_empty() and EditorInterface.is_playing_scene(), "Continue leaves the debugger stop and keeps the application running")
    EditorInterface.stop_playing_scene()
    var Stopped = Time.get_ticks_msec() + 5000
    while EditorInterface.is_playing_scene() and Time.get_ticks_msec() < Stopped:
        await get_tree().process_frame
    Check(not EditorInterface.is_playing_scene(), "Native Stop terminates the debugging application")
    EditorInterface.play_main_scene()
    var Restart = await WaitStop(1, Connection + 1)
    if not Check(not Restart.is_empty(), "A fresh native debugger connection admits the retained gutter breakpoint"):
        Finish(false)
        return
    if not Press("Detach"):
        Finish(false)
        return
    var Detached = Time.get_ticks_msec() + 5000
    while not Session(1, Connection + 1).is_empty() and Time.get_ticks_msec() < Detached:
        await get_tree().process_frame
    Check(Session(1, Connection + 1).is_empty() and EditorInterface.is_playing_scene(), "Detach resumes the stopped application without terminating it")
    EditorInterface.stop_playing_scene()
    Code.set_line_as_breakpoint(EntryLine, false)
    Check(not Code.is_line_breakpointed(EntryLine), "Native editor breakpoint removal")
    Finish(Checks.all(func(Item): return Item.Passed))
