extends "res://CharacterPresentation.gd"

var Recording := false
var PhysicsBegin := 0
var ProcessBegin := 0
var LastProcess := 0
var PhysicsDispatch := []
var ProcessDispatch := []
var ProcessFrames := []

func Distribution(Values: Array) -> Dictionary:
    var Ordered := Values.duplicate()
    Ordered.sort()
    var Total := 0.0
    for Value in Values: Total += float(Value)
    return {"Mean": Total/Values.size(), "Median": Ordered[Ordered.size()/2], "P95": Ordered[int(ceil(Ordered.size()*0.95))-1], "P99": Ordered[int(ceil(Ordered.size()*0.99))-1], "Samples": Values.size(), "Raw": Values}

func Freeze(Character: Node) -> void:
    Character.set_process(false)
    Character.set_physics_process(false)
    Character.call("GetPhysicsBody").set_process(false)

func ProfileCount(Count: int, SampleCount: int) -> Array:
    var Worlds := [World]
    for Index in range(1, Count):
        var Added := Create("RobloxWorkspace", "BenchmarkWorld" + str(Index))
        Added.set_process(false)
        Worlds.append(Added)
    var Characters := []
    for Index in range(Count):
        var Character: Node3D = Worlds[Index].get_node("LocalPlayer")
        Check(Character.has_node("Torso"), "performance workload requires actual R6")
        Character.global_position = Vector3((Index % 8)*8, 0.1, (Index/8)*8)
        Character.call("SetLocalControl", false)
        Character.call("GetPhysicsBody").set_process(false)
        Character.call("set_npc_move_dir", Vector3.RIGHT)
        Characters.append(Character)
    var Observer := Camera3D.new()
    Game.add_child(Observer)
    Observer.position = Vector3(28, 48, 90)
    Observer.look_at(Vector3(28, 0, 24))
    Observer.make_current()
    var Results := []
    for Mode in (["all", "physics-only", "animation-only", "inactive"] if Count == 16 else ["all"]):
        for Character in Characters:
            Character.set_physics_process(Mode in ["all", "physics-only"])
            Character.set_process(Mode != "inactive")
            Character.get_node("R6Animator").set_process(Mode in ["all", "animation-only"])
        await Ticks(60)
        var Physics := []
        var Process := []
        var Frame := []
        var Harness := []
        var CpuRender := []
        var GpuRender := []
        var Last := Time.get_ticks_usec()
        PhysicsDispatch = []
        ProcessDispatch = []
        ProcessFrames = []
        Recording = true
        var RenderTimes := Graphical and RenderingServer.has_method("viewport_get_measured_render_time_cpu")
        if RenderTimes: RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
        for Tick in range(SampleCount):
            await physics_frame
            var Now := Time.get_ticks_usec()
            Frame.append((Now - Last)/1000000.0)
            Last = Now
            Physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
            Process.append(Performance.get_monitor(Performance.TIME_PROCESS))
            if RenderTimes:
                CpuRender.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
                GpuRender.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
            var Start := Time.get_ticks_usec()
            if Tick % 60 == 0 and Mode in ["all", "physics-only"]:
                for Character in Characters: Character.call("set_npc_move_dir", Vector3.RIGHT if Tick % 120 == 0 else Vector3.LEFT)
            Harness.append(Time.get_ticks_usec()-Start)
        Recording = false
        Check(PhysicsDispatch.size() >= SampleCount-2 and ProcessDispatch.size() >= SampleCount-2, "independent dispatch timing samples")
        Results.append({"Characters": Count, "Mode": Mode, "FrameSeconds": Distribution(ProcessFrames), "PhysicsTickWallSeconds": Distribution(Frame), "PhysicsSeconds": Distribution(PhysicsDispatch), "ProcessSeconds": Distribution(ProcessDispatch), "EnginePhysicsMonitorSeconds": Distribution(Physics), "EngineProcessMonitorSeconds": Distribution(Process), "HarnessMicroseconds": Distribution(Harness), "RenderCpuMilliseconds": Distribution(CpuRender) if RenderTimes else null, "RenderGpuMilliseconds": Distribution(GpuRender) if RenderTimes else null, "DrawCalls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "Objects": Performance.get_monitor(Performance.OBJECT_COUNT), "Nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "Resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "StaticMemoryBytes": Performance.get_monitor(Performance.MEMORY_STATIC)})
    Observer.free()
    for Added in Worlds:
        if Added != World: Added.free()
    Freeze(World.get_node("LocalPlayer"))
    await Ticks(5)
    return Results

func Run() -> void:
    var Counts := [1, 16, 32, 64]
    var SampleCount := 240
    var Args := OS.get_cmdline_user_args()
    for Position in range(Args.size()-1):
        if Args[Position] == "--counts":
            Counts = []
            for Item in Args[Position+1].split(","): Counts.append(int(Item))
        if Args[Position] == "--samples": SampleCount = int(Args[Position+1])
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    for Front in [true, false]:
        var Probe: Node = preload("res://CharacterDispatchProbe.gd").new()
        Probe.Host = self
        Probe.Front = Front
        Probe.process_priority = -100000 if Front else 100000
        Probe.process_physics_priority = Probe.process_priority
        Game.add_child(Probe)
    Players = Create("Players", "Players")
    Create("Node", "SettingsMenu")
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    FloorAndLighting()
    await Ticks(5)
    Freeze(World.get_node("LocalPlayer"))
    var Creation := []
    var Respawn := []
    for Attempt in range(35):
        World.get_node("LocalPlayer").free()
        var Start := Time.get_ticks_usec()
        World.call("build_local_character")
        var Duration := Time.get_ticks_usec()-Start
        Freeze(World.get_node("LocalPlayer"))
        if Attempt >= 5: Creation.append(Duration)
        await process_frame
    for Attempt in range(35):
        var Start := Time.get_ticks_usec()
        Players.call("load_local_character")
        var Duration := Time.get_ticks_usec()-Start
        Freeze(World.get_node("LocalPlayer"))
        if Attempt >= 5: Respawn.append(Duration)
        await process_frame
    var Memory := []
    for Attempt in range(101):
        if Attempt % 25 == 0:
            Memory.append({"Respawns": Attempt, "StaticMemoryBytes": Performance.get_monitor(Performance.MEMORY_STATIC), "Objects": Performance.get_monitor(Performance.OBJECT_COUNT), "Nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "Resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
        if Attempt < 100:
            Players.call("load_local_character")
            Freeze(World.get_node("LocalPlayer"))
            await process_frame
    var Profiles := []
    for Count in Counts: Profiles.append_array(await ProfileCount(Count, SampleCount))
    var Evidence := {"Graphical": Graphical, "Adapter": RenderingServer.get_video_adapter_name(), "TimingScope": "PhysicsSeconds/ProcessSeconds are elapsed wall time between priority probes around actual SceneTree node dispatch; excludes physics-server steps/rendering outside dispatch, includes native controller/animation and engine dispatch; not OS-thread CPU accounting. Engine monitor snapshots update coarsely and are retained only for historical comparison.", "CreationMicroseconds": Distribution(Creation), "RespawnMicroseconds": Distribution(Respawn), "RespawnMemory": Memory, "NativeAllocationCount": null, "AllocationScope": "Godot static-byte and live object/node/resource monitors; no native allocator event count", "Profiles": Profiles, "Checks": Checks}
    FileAccess.open("res://measurements.json", FileAccess.WRITE).store_string(JSON.stringify(Evidence))
    Game.free()
    await process_frame
    print("[Character:Performance] ", "FAIL" if Failed else "PASS", " checks=", Checks)
    quit(1 if Failed else 0)
