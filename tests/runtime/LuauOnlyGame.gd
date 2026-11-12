extends SceneTree
## External qualification observer: gameplay and composition remain production Luau.
var Checks: Array[Dictionary] = []
var Main: Node

func _initialize() -> void:
    if "--graphical" in OS.get_cmdline_user_args():
        DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
    Run.call_deferred()

func Check(Value: bool, Message: String) -> void:
    Checks.append({"Passed": Value, "Message": Message})
    print("[Authoring:Game] ", "PASS " if Value else "FAIL ", Message)

func SendKey(Code: Key, Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.physical_keycode = Code
    Event.keycode = Code
    Event.pressed = Pressed
    Input.parse_input_event(Event)

func Frames(Count: int) -> void:
    for Index in range(Count): await process_frame

func Run() -> void:
    Main = load("res://Main.tscn").instantiate()
    root.add_child(Main)
    current_scene = Main
    await Frames(60)
    var Bodies := Main.find_children("Orb", "RigidBody3D", true, false)
    Check(Bodies.size() == 1, "Real Luau entrypoint creates exactly one native physics player")
    if Bodies.size() == 1:
        var Body := Bodies[0] as RigidBody3D
        Check(Body.position.y > 0.2 and Body.position.y < 0.9, "Native sphere rests on the actual collision floor")
        var Start := Body.position
        SendKey(KEY_W, true)
        await Frames(35)
        SendKey(KEY_W, false)
        await Frames(5)
        Check(Body.position.z < Start.z - 0.2, "Real keyboard input moves the native body through Luau")
        SendKey(KEY_SPACE, true)
        await Frames(5)
        SendKey(KEY_SPACE, false)
        Check(Body.position.y > 0.65, "Luau input action applies a real jump impulse")
        # Move the real body to each target; collection, audio and state remain
        # the production Luau Heartbeat implementation, not observer logic.
        for Index in range(1, 4):
            var Marker := Main.find_child("Marker" + str(Index), true, false) as Node3D
            if Marker:
                Body.position = Marker.position
                Body.linear_velocity = Vector3.ZERO
                await Frames(2)
        Check(Main.find_children("Marker?", "Node3D", true, false).is_empty(), "Actual Luau collection removes all reusable native markers")
        var NextRound: Button
        for ButtonNode in Main.find_children("*", "Button", true, false):
            if ButtonNode.text == "NEXT ROUND": NextRound = ButtonNode
        Check(NextRound != null, "Collection completes the round through production game state")
        if NextRound:
            var OldRound := Body.get_instance_id()
            NextRound.pressed.emit()
            await Frames(5)
            var NewBodies := Main.find_children("Orb", "RigidBody3D", true, false)
            Check(not is_instance_id_valid(OldRound) and NewBodies.size() == 1 and Main.find_children("Marker?", "Node3D", true, false).size() == 3, "Next-round signal replaces physics and restores reusable components")
            if NewBodies.size() == 1: Body = NewBodies[0]
        var Buttons := Main.find_children("*", "Button", true, false)
        var Restart: Button
        for ButtonNode in Buttons:
            if ButtonNode.text == "RESTART": Restart = ButtonNode
        Check(Restart != null, "Native Luau UI supplies restart")
        if Restart:
            var OldId := Body.get_instance_id()
            Restart.pressed.emit()
            await Frames(5)
            var Replacement := Main.find_children("Orb", "RigidBody3D", true, false)
            Check(not is_instance_id_valid(OldId) and Replacement.size() == 1, "Real signal replaces the owned scene without stale native bodies")
    var Entry := Main.get_node("Main")
    Entry.set("Enabled", false)
    await Frames(3)
    Check(Main.find_children("*", "SceneScope", true, false).is_empty(), "Disabling entrypoint retires all authored scopes")
    Entry.set("Enabled", true)
    await Frames(10)
    Check(Main.find_children("Orb", "RigidBody3D", true, false).size() == 1, "Fresh generation reconstructs the actual Luau-only game")
    var Module: Script = load("res://ProbeModule.luau")
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = 'assert(require("res://ProbeModule.luau").Value == 1)\nlocal Scope=Scene.new(script.Parent)\nScope:New("Node3D", {Name="ModuleV1"})'
    var Probe: Node = ClassDB.instantiate("LocalScript")
    Probe.name = "ModuleProbe"
    Probe.set("codigo_luau", Code)
    Main.add_child(Probe)
    await Frames(5)
    Check(Main.find_children("ModuleV1", "Node3D", true, false).size() == 1, "String module initializes through the actual Client domain")
    Module.source_code = 'return {Value=2}'
    Code.source_code = 'assert(require("res://ProbeModule.luau").Value == 2)\nassert(not pcall(require, "user://outside.luau"))\nlocal Scope=Scene.new(script.Parent)\nScope:New("Node3D", {Name="ModuleV2"})'
    await Frames(5)
    Check(Main.find_children("ModuleV2", "Node3D", true, false).size() == 1, "Runtime module cache observes revisions and denies external source paths")
    Probe.queue_free()
    await Frames(3)
    var Passed := true
    for Item in Checks: Passed = Passed and Item.Passed
    if "--graphical" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        Check(root.get_texture().get_image().save_png("res://orb-run.png") == OK, "Real renderer captures the Luau-only native scene")
        Passed = Passed and Checks.back().Passed
    var File := FileAccess.open("res://luau-only-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": Checks}))
    File.close()
    print("[Authoring:GameQualification] ", "PASS" if Passed else "FAIL")
    quit(0 if Passed else 1)
