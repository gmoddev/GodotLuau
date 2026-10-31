extends SceneTree

# Identical production-factory workload for the qualified parent and candidate.
var Game: Node
var World: Node
var Players: Node
var Samples: Dictionary = {}

func Summary(Values: Array) -> Dictionary:
    var Ordered := Values.duplicate()
    Ordered.sort()
    return {"Median": Ordered[Ordered.size() / 2], "P95": Ordered[int((Ordered.size() - 1) * 0.95)], "Samples": Ordered.size()}

func CountNodes(Target: Node) -> int:
    var Count := 1
    for Child in Target.get_children(true): Count += CountNodes(Child)
    return Count

func Character() -> Node:
    return World.get_node("LocalPlayer")

func Health(Target: Node) -> Node:
    return Target if Target.is_class("RBXCharacter") else Target.get_node("Humanoid")

func Freeze(Target: Node) -> void:
    Target.set_process(false)
    Target.set_physics_process(false)
    var State := Health(Target)
    State.set_process(false)
    State.set_physics_process(false)
    var Body := Target.get_node_or_null("PhysicsBody")
    if Body != null:
        Body.set_process(false)
        Body.set_physics_process(false)

func Profile(Count: int) -> Dictionary:
    var Worlds := [World]
    for Index in range(1, Count):
        var Added: Node = ClassDB.instantiate("RobloxWorkspace")
        Added.name = "BenchmarkWorld" + str(Index)
        Game.add_child(Added)
        Added.set_process(false)
        Worlds.append(Added)
    for Index in range(Worlds.size()):
        var Target: Node = Worlds[Index].get_node("LocalPlayer")
        Freeze(Target)
        Target.global_position = Vector3(Index * 10, 5, 0)
        var State := Health(Target)
        State.call("set_npc_move_dir", Vector3.RIGHT)
        State.set_physics_process(true)
        State.set_process(true)
    for Tick in range(90): await physics_frame
    var Physics := []
    var Process := []
    for Tick in range(120):
        await physics_frame
        Physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
        Process.append(Performance.get_monitor(Performance.TIME_PROCESS))
    var Result := {"Characters": Count, "PhysicsSeconds": Summary(Physics), "ProcessSeconds": Summary(Process), "Objects": Performance.get_monitor(Performance.OBJECT_COUNT), "StaticMemoryBytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
    for Added in Worlds:
        if Added != World: Added.queue_free()
    Freeze(Character())
    for Tick in range(10): await process_frame
    return Result

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    assert(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED])
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Players = ClassDB.instantiate("Players")
    Players.name = "Players"
    Game.add_child(Players)
    var Settings := Node.new()
    Settings.name = "SettingsMenu"
    Game.add_child(Settings)
    World = ClassDB.instantiate("RobloxWorkspace")
    World.name = "Workspace"
    Game.add_child(World)
    World.set_process(false)
    await process_frame
    Freeze(Character())
    Samples["Architecture"] = "CharacterV2" if Character().is_class("RBXCharacter") else "GL007"
    Samples["Rig"] = "R6" if Character().has_node("Torso") else "Fallback"
    var Creation := []
    var Respawn := []
    for Index in range(35):
        var Prior := Character()
        Prior.free()
        var Started := Time.get_ticks_usec()
        World.call("build_local_character")
        var Duration := Time.get_ticks_usec() - Started
        Freeze(Character())
        if Index >= 5: Creation.append(Duration)
        await process_frame
    for Index in range(35):
        var Started := Time.get_ticks_usec()
        Players.call("load_local_character")
        var Duration := Time.get_ticks_usec() - Started
        Freeze(Character())
        if Index >= 5: Respawn.append(Duration)
        await process_frame
    Samples["CreationMicroseconds"] = Summary(Creation)
    Samples["RespawnMicroseconds"] = Summary(Respawn)
    var BeforeMemory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
    var BeforeObjects: float = Performance.get_monitor(Performance.OBJECT_COUNT)
    for Index in range(100):
        Players.call("load_local_character")
        Freeze(Character())
        await process_frame
    for Index in range(10): await process_frame
    Samples["After100Respawns"] = {"StaticMemoryDeltaBytes": Performance.get_monitor(Performance.MEMORY_STATIC) - BeforeMemory, "ObjectDelta": Performance.get_monitor(Performance.OBJECT_COUNT) - BeforeObjects}
    Samples["CharacterNativeNodes"] = CountNodes(Character())
    var Probe := Node3D.new()
    Probe.name = "BenchmarkAnimationProbe"
    Character().add_child(Probe)
    var Playback := AnimationPlayer.new()
    Character().add_child(Playback)
    var Library := AnimationLibrary.new()
    var Clip := Animation.new()
    Clip.length = 1.0
    Clip.loop_mode = Animation.LOOP_LINEAR
    var Track := Clip.add_track(Animation.TYPE_POSITION_3D)
    Clip.track_set_path(Track, NodePath("BenchmarkAnimationProbe"))
    Clip.track_insert_key(Track, 0.0, Vector3.ZERO)
    Clip.track_insert_key(Track, 1.0, Vector3.ONE)
    Library.add_animation("Measure", Clip)
    Playback.add_animation_library("", Library)
    Playback.play("Measure")
    var AnimationTimes := []
    for Batch in range(35):
        var Started := Time.get_ticks_usec()
        for Tick in range(1000): Playback.advance(1.0 / 60.0)
        if Batch >= 5: AnimationTimes.append((Time.get_ticks_usec()-Started)/1000.0)
    Samples["NativeAnimationAdvanceMicroseconds"] = Summary(AnimationTimes)
    Playback.free()
    Probe.free()
    Samples["StaticMemoryBytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
    var Floor := StaticBody3D.new()
    var Shape := CollisionShape3D.new()
    var Box := BoxShape3D.new()
    Box.size = Vector3(10000, 1, 10000)
    Shape.shape = Box
    Floor.position.y = -1.5
    Floor.add_child(Shape)
    Game.add_child(Floor)
    Samples["OneCharacter"] = await Profile(1)
    Samples["SixteenCharacters"] = await Profile(16)
    print("[Character:Benchmark] ", JSON.stringify(Samples))
    Game.free()
    await process_frame
    print("[Character:Benchmark] PASS")
    quit(0)
