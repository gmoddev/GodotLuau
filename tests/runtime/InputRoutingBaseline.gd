extends SceneTree

# Controlled Godot viewport/Control dispatch, not physical-device qualification.
class Observer extends Node:
    var Trace: Array = []
    func _input(Event: InputEvent) -> void:
        if Event is InputEventKey:
            Trace.append({"Stage": "input", "Handled": get_viewport().is_input_handled(), "Pressed": Event.pressed})
    func _unhandled_input(Event: InputEvent) -> void:
        if Event is InputEventKey:
            Trace.append({"Stage": "unhandled", "Handled": get_viewport().is_input_handled(), "Pressed": Event.pressed})

func _initialize() -> void:
    Run.call_deferred()

func Run() -> void:
    root.size = Vector2i(640, 480)
    var Reader := LineEdit.new()
    Reader.size = Vector2(320, 80)
    root.add_child(Reader)
    var Watch := Observer.new()
    root.add_child(Watch)
    Reader.gui_input.connect(func(Event: InputEvent) -> void:
        if Event is InputEventKey:
            Watch.Trace.append({"Stage": "gui", "Handled": Reader.get_viewport().is_input_handled(), "Pressed": Event.pressed})
            Reader.accept_event()
    )
    await process_frame
    Reader.grab_focus()
    await process_frame
    for Pressed in [true, false]:
        var Event := InputEventKey.new()
        Event.keycode = KEY_W
        Event.physical_keycode = KEY_W
        Event.pressed = Pressed
        root.push_input(Event, true)
    var Consumed := Watch.Trace.duplicate(true)
    Watch.Trace.clear()
    Reader.release_focus()
    var Free := InputEventKey.new()
    Free.keycode = KEY_Q
    Free.physical_keycode = KEY_Q
    Free.pressed = true
    root.push_input(Free, true)
    var Unconsumed := Watch.Trace.duplicate(true)
    var Passed := Consumed.size() == 4 and Unconsumed.size() == 2
    if Passed:
        Passed = Consumed[0].Stage == "input" and not Consumed[0].Handled and Consumed[1].Stage == "gui" and Consumed[2].Stage == "input" and Consumed[3].Stage == "gui" and Unconsumed[0].Stage == "input" and Unconsumed[1].Stage == "unhandled"
    var Record := {"Result": "PASS" if Passed else "FAIL", "Consumed": Consumed, "Unconsumed": Unconsumed, "Scope": "Real headless Godot GUI routing; synthetic viewport events, no hardware/GPU claim"}
    var File := FileAccess.open("res://input-routing-baseline.json", FileAccess.WRITE)
    File.store_string(JSON.stringify(Record, "  "))
    File.close()
    print("[Input:RoutingBaseline] ", Record.Result)
    quit(0 if Passed else 1)
