extends SceneTree

var Game: Node
var Output := ""
var Count := 10
var Samples: Array[float] = []
var ProcessSamples: Array[float] = []

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    Count = int(Arguments[0])
    Output = Arguments[1]
    if Arguments.size() > 2:
        ProjectSettings.set_setting("godot_luau/server_limits/resume_milliseconds", float(Arguments[2]))
    call_deferred("Run")

func ScriptNode(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Parent.add_child(Result)
    return Result

func Phase(Name: String, Values: Dictionary) -> void:
    Values["Phase"] = Name
    Values["Count"] = Count
    Values["GodotBytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
    Values["Resources"] = ResourceStats()
    var File := FileAccess.open(Output, FileAccess.WRITE)
    File.store_string(JSON.stringify(Values))
    File.close()
    var Ack := Output + ".ack"
    while not FileAccess.file_exists(Ack): await process_frame
    DirAccess.remove_absolute(Ack)

func ResourceStats() -> Dictionary:
    if is_instance_valid(Game):
        for Child in Game.get_children():
            if Child.is_class("GLDomainHost") and Child.has_method("GetResourceStats"):
                return Child.call("GetResourceStats", false)
    return {}

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    assert(Loaded == GDExtensionManager.LOAD_STATUS_OK or Loaded == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED)
    Engine.max_fps = 0
    OS.low_processor_usage_mode = false
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    ScriptNode("ModuleScript", "Counter", "game:SetAttribute('ModuleExecutions', (game:GetAttribute('ModuleExecutions') or 0) + 1); local Value = 0; for Index = 1, 100 do Value += Index end; return {Value = Value}", Storage)
    await Phase("Before", {})
    var Started := Time.get_ticks_usec()
    var Nodes: Array[Node] = []
    var Source := """
local Clock = os.clock
local Started = Clock()
local Counter = require(game.ReplicatedStorage.Counter)
assert(Counter.Value == 5050)
local Cold = (Clock() - Started) * 1000
Started = Clock()
for Index = 1, 100 do assert(require(game.ReplicatedStorage.Counter) == Counter) end
local Hot = (Clock() - Started) * 1000
Started = Clock()
for Index = 1, 32 do local Thread = task.defer(function() end); task.cancel(Thread) end
local Coroutines = (Clock() - Started) * 1000
game:SetAttribute('ColdMs', (game:GetAttribute('ColdMs') or 0) + Cold)
game:SetAttribute('HotMs', (game:GetAttribute('HotMs') or 0) + Hot)
game:SetAttribute('CoroutinesMs', (game:GetAttribute('CoroutinesMs') or 0) + Coroutines)
game:SetAttribute('StartedCount', (game:GetAttribute('StartedCount') or 0) + 1)
while not game:GetAttribute('BenchmarkRun') do task.wait() end
for Frame = 1, 20 do task.wait() end
game:SetAttribute('DoneCount', (game:GetAttribute('DoneCount') or 0) + 1)
"""
    for Index in range(Count):
        Nodes.append(ScriptNode("ServerScript", "Bench" + str(Index), Source, Game))
    while Game.get_meta("StartedCount", 0) != Count: await process_frame
    var StartupMs := (Time.get_ticks_usec() - Started) / 1000.0
    await Phase("Startup", {"StartupMs": StartupMs,
        "ColdMs": Game.get_meta("ColdMs", 0), "Hot100Ms": Game.get_meta("HotMs", 0),
        "Coroutine32Ms": Game.get_meta("CoroutinesMs", 0), "ModuleExecutions": Game.get_meta("ModuleExecutions", 0)})
    Game.set_meta("BenchmarkRun", true)
    Engine.max_fps = 0
    OS.low_processor_usage_mode = false
    var Last := Time.get_ticks_usec()
    while Game.get_meta("DoneCount", 0) != Count:
        await process_frame
        var Now := Time.get_ticks_usec()
        Samples.append((Now - Last) / 1000.0)
        ProcessSamples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
        Last = Now
    Samples.sort()
    ProcessSamples.sort()
    await Phase("Scheduler", {"FrameMedianMs": Samples[Samples.size() / 2],
        "FrameP95Ms": Samples[mini(Samples.size() - 1, int(Samples.size() * 0.95))], "Frames": Samples.size(),
        "ProcessMedianMs": ProcessSamples[ProcessSamples.size() / 2], "ProcessP95Ms": ProcessSamples[mini(ProcessSamples.size() - 1, int(ProcessSamples.size() * 0.95))], "MaxFps": Engine.max_fps})
    Started = Time.get_ticks_usec()
    for Target in Nodes: Target.queue_free()
    await process_frame
    await process_frame
    await Phase("Destroy", {"DestroyMs": (Time.get_ticks_usec() - Started) / 1000.0})
    Started = Time.get_ticks_usec()
    Game.queue_free()
    await process_frame
    await process_frame
    await Phase("Shutdown", {"ShutdownMs": (Time.get_ticks_usec() - Started) / 1000.0})
    print("[Runtime:Benchmark] PASS count=", Count)
    quit(0)
