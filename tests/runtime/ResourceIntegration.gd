extends SceneTree

var Game: Node
var Failed := false
var Case := ""

func _initialize() -> void:
    Case = OS.get_cmdline_user_args()[0]
    call_deferred("Run")

func Check(Value: bool, Message: String) -> void:
    if not Value:
        Failed = true
        print("[Runtime:Resource] FAIL ", Message)

func ScriptNode(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Parent.add_child(Result)
    return Result

func Until(Key: String) -> void:
    for Index in range(120):
        if Game.has_meta(Key):
            return
        await process_frame
    Check(false, "Missing marker: " + Key)

func Host() -> Node:
    for Child in Game.get_children():
        if Child.is_class("GLDomainHost"):
            return Child
    return null

func Stats(Client := false) -> Dictionary:
    var Runtime := Host()
    Check(Runtime != null and Runtime.has_method("GetResourceStats"), "Resource diagnostics unavailable")
    return Runtime.call("GetResourceStats", Client) if Runtime != null else {}

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded == GDExtensionManager.LOAD_STATUS_OK or Loaded == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED, "Extension load failed")
    if Failed:
        quit(1)
        return
    ProjectSettings.set_setting("godot_luau/server_limits/resume_milliseconds", 25.0)
    ProjectSettings.set_setting("godot_luau/server_limits/vm_memory_bytes", 8 * 1024 * 1024)
    if Case == "invoke":
        ProjectSettings.set_setting("godot_luau/server_limits/resume_milliseconds", 0)
        ProjectSettings.set_setting("godot_luau/client_limits/resume_milliseconds", 25.0)
    if Case == "tasks":
        ProjectSettings.set_setting("godot_luau/server_limits/tasks", 16)
    if Case == "configuration":
        ProjectSettings.set_setting("godot_luau/server_limits/resume_milliseconds", -1.0)
        ProjectSettings.set_setting("godot_luau/server_limits/vm_memory_bytes", 0)
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    ScriptNode("ServerScript", "Baseline", "game:SetAttribute('Baseline',true)", Game)
    await Until("Baseline")
    for Index in range(3):
        await process_frame
    var BaselineTasks: int = Stats().Tasks
    var Owner: Node
    match Case:
        "execution":
            Owner = ScriptNode("ServerScript", "Overrun", "game:SetAttribute('Entered',true); task.defer(function() game:SetAttribute('Stale',true) end); while true do pcall(function() while true do end end) end", Game)
        "module":
            ScriptNode("ModuleScript", "OverrunModule", "game:SetAttribute('Entered',true); while true do end", Storage)
            Owner = ScriptNode("ServerScript", "RequireOverrun", "require(game.ReplicatedStorage.OverrunModule)", Game)
        "callback":
            Owner = ScriptNode("ServerScript", "CallbackOverrun", "game.ChildAdded:Connect(function(Child) if Child.Name=='Trigger' then game:SetAttribute('Entered',true); while true do end end end); game:SetAttribute('Ready',true)", Game)
            await Until("Ready")
            var Trigger := Node.new()
            Trigger.name = "Trigger"
            Game.add_child(Trigger)
        "invoke":
            var Remote: Node = ClassDB.instantiate("RemoteFunctionNode")
            Remote.name = "Function"
            Storage.add_child(Remote)
            Owner = ScriptNode("ServerScript", "InvokeOverrun", "game.ReplicatedStorage.Function.OnServerInvoke=function() game:SetAttribute('Entered',true); while true do end end; game:SetAttribute('Ready',true)", Game)
            await Until("Ready")
            ScriptNode("LocalScript", "Invoker", "game.ReplicatedStorage.Function:InvokeServer()", Game)
        "memory":
            Owner = ScriptNode("ServerScript", "Quota", "game:SetAttribute('Entered',true); pcall(function() shared.Large=table.create(1024*1024) end)", Game)
        "tasks":
            Owner = ScriptNode("ServerScript", "Admission", "local Accepted=0; for Index=1,32 do local Ok=pcall(task.defer,function() end); if Ok then Accepted+=1 end end; assert(Accepted>0 and Accepted<32); game:SetAttribute('Entered',true)", Game)
        "shutdown":
            Owner = ScriptNode("ServerScript", "CloseOverrun", "game:BindToClose(function() game:SetAttribute('Entered',true); while true do end end); game:BindToClose(function() game:SetAttribute('Stale',true) end); game:SetAttribute('Ready',true)", Game)
            await Until("Ready")
            var Runtime := Host()
            Game.remove_child(Runtime)
            var Closing: Dictionary = Runtime.call("GetResourceStats", false)
            Check(Closing.Closing and Closing.References == 0, "Shutdown retained admission or callbacks")
            Runtime.free()
        "configuration":
            var Remote: Node = ClassDB.instantiate("RemoteFunctionNode")
            Remote.name = "Function"
            Storage.add_child(Remote)
            Owner = ScriptNode("ServerScript", "Configuration", """
assert(typeof(game)=='Instance' and typeof(script)=='Instance')
assert(io==nil and package==nil and dofile==nil and loadfile==nil and debug.getregistry==nil and os.execute==nil)
assert(_FileAccess.read and _HTTP.request)
assert(not pcall(function() task.defer=nil end))
_G.Value=42; shared.Value=43
local F=function() return Value end
setfenv(F,{Value=12}); assert(F()==12)
game.ReplicatedStorage.Function.OnServerInvoke=function()
    return setmetatable({Value=42}, setmetatable({}, {__index=function() error('source metadata metamethod must not execute') end})),
        setmetatable({Value=43}, {__type='CFrame'})
end
local Value, Typed=game.ReplicatedStorage.Function:InvokeServer()
assert(Value.Value==42 and Typed.Value==43 and getmetatable(Typed)==CFrame)
local Override={}
getfenv(1).CFrame=Override
Value, Typed=game.ReplicatedStorage.Function:InvokeServer()
assert(Value.Value==42 and getmetatable(Typed)==Override)
game:SetAttribute('Entered',true)
""", Game)
        _:
            Check(false, "Unknown case")
    await Until("Entered")
    for Index in range(3):
        await process_frame
    Check(not Game.has_meta("Stale"), "Retired callback/task resumed")
    if Case != "shutdown":
        var State := Stats()
        print("[Runtime:Resource] Stats ", JSON.stringify(State))
        Check(State.Sandboxed, "Gameplay VM was not sandboxed")
        if Case == "memory":
            Check(State.MemoryFailed and State.Closing and State.References == 0, "Memory exhaustion did not retire VM")
            Check(State.VmPeakBytes <= State.VmLimitBytes and State.AllocationRejections > 0, "Allocator cap not enforced")
            ScriptNode("ServerScript", "NoAutomaticRestart", "game:SetAttribute('Restarted',true)", Game)
            await process_frame
            Check(not Game.has_meta("Restarted"), "Failed domain restarted automatically")
        else:
            Check(not State.MemoryFailed and not State.Closing, "Execution/admission failure retired healthy VM")
            if Case == "configuration":
                Check(State.ResumeMilliseconds == 10000.0 and State.VmLimitBytes == 0, "Invalid/disabled configuration was not explicit")
            if Case == "invoke":
                Check(State.ResumeMilliseconds == 0 and Stats(true).ResumeMilliseconds == 25.0,
                    "Cross-domain invoke did not exercise the ancestor's timer independently")
            if Case == "tasks":
                Check(State.TaskPeak <= 16 and State.Tasks == BaselineTasks, "Task admission/cleanup exceeded cap")
            var Source := "assert(_G.Value==42 and shared.Value==43); " if Case == "configuration" else ""
            if Case == "module":
                Source += "local Ok,Error=pcall(require,game.ReplicatedStorage.OverrunModule); assert(not Ok and string.find(Error,'deadline')); "
            ScriptNode("ServerScript", "Survivor", Source + "game:SetAttribute('Survived',true)", Game)
            await Until("Survived")
    ScriptNode("LocalScript", "IndependentClient", "assert(shared.Large==nil); game:SetAttribute('ClientSurvived',true)", Game)
    await Until("ClientSurvived")
    if is_instance_valid(Owner):
        Owner.call("set_enabled", false)
    Game.queue_free()
    await process_frame
    await process_frame
    # Explicit new scene/domain recovery; no failure-driven restart mechanism.
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    ScriptNode("ServerScript", "Fresh", "assert(shared.Large==nil); game:SetAttribute('Fresh',true)", Game)
    await Until("Fresh")
    Game.queue_free()
    await process_frame
    await process_frame
    if Case == "configuration":
        ProjectSettings.set_setting("godot_luau/server_limits/coroutines", 1)
        Game = Node.new()
        Game.name = "Game"
        root.add_child(Game)
        current_scene = Game
        ScriptNode("ServerScript", "FailedBootstrap", "game:SetAttribute('ShouldNeverStart',true)", Game)
        for Index in range(4):
            await process_frame
        var Unavailable := Stats()
        Check(Unavailable.Closing and not Unavailable.MemoryFailed and Unavailable.has("Failure") and
            not Game.has_meta("ShouldNeverStart"), "Partial bootstrap admitted gameplay or lost failure disposition")
        ScriptNode("LocalScript", "OtherDomain", "game:SetAttribute('OtherDomainReady',true)", Game)
        await Until("OtherDomainReady")
        Game.queue_free()
        await process_frame
        await process_frame
        ProjectSettings.set_setting("godot_luau/server_limits/coroutines", 131072)
        Game = Node.new()
        Game.name = "Game"
        root.add_child(Game)
        current_scene = Game
        ScriptNode("ServerScript", "RecoveredBootstrap", "game:SetAttribute('Recovered',true)", Game)
        await Until("Recovered")
        Game.queue_free()
        await process_frame
        await process_frame
    if not Failed:
        print("[Runtime:Resource] PASS ", Case)
    quit(1 if Failed else 0)
