extends SceneTree

var Game: Node
var Failed := false

func _initialize() -> void:
    call_deferred("Run")

func CreateScript(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var ScriptNode: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    ScriptNode.name = Name
    ScriptNode.call("set_codigo_luau", Resource)
    Parent.add_child(ScriptNode)
    return ScriptNode

func Check(Condition: bool, Message: String) -> void:
    if not Condition:
        Failed = true
        print("[Runtime:Integration] FAIL ", Message)

func Until(Key: String, Frames := 120) -> bool:
    for Index in range(Frames):
        if Game.has_meta(Key):
            return true
        await process_frame
    Check(false, "Timed out waiting for " + Key)
    return false

func Run() -> void:
    var LoadResult := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(LoadResult == GDExtensionManager.LOAD_STATUS_OK or LoadResult == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED, "Extension failed to load")
    if Failed:
        quit(1)
        return
    print("[Runtime:Integration] Extension loaded")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    var Service: Node = ClassDB.instantiate("RunService")
    Service.name = "RunService"
    Game.add_child(Service)
    print("[Runtime:Integration] Fixture services created")
    CreateScript("ModuleScript", "Counter", """
_G.Initializations = (_G.Initializations or 0) + 1
task.wait(0.02)
assert(script.Name == 'Counter')
ModulePrivate = 42
return {Value = 0}
""", Storage)
    print("[Runtime:Integration] Module created")
    for Type in ["ServerScript", "LocalScript"]:
        var Prefix := "Server" if Type == "ServerScript" else "Client"
        CreateScript(Type, Prefix + "A", """
LocalGlobal = 'private'
local Counter = require(game.ReplicatedStorage.Counter)
Counter.Value += 1
shared.Counter = Counter
_G.AFinished = true
game:SetAttribute('%sA', true)
task.wait(0.02)
assert(script.Name == '%sA' and ModulePrivate == nil)
game:SetAttribute('%sIdentity', true)
""" % [Prefix, Prefix, Prefix], Game)
        CreateScript(Type, Prefix + "B", """
local Counter = require(game.ReplicatedStorage.Counter)
while not _G.AFinished do task.wait() end
assert(Counter == shared.Counter and Counter.Value == 1 and _G.Initializations == 1)
assert(LocalGlobal == nil and ModulePrivate == nil)
assert(script.Name == '%sB')
assert(game:GetService('RunService'):IsClient() == %s)
game:GetService('RunService').Heartbeat:Once(function()
    task.wait()
    assert(script.Name == '%sB')
    game:SetAttribute('%sCallback', true)
end)
game:SetAttribute('%sB', true)
""" % [Prefix, "true" if Prefix == "Client" else "false", Prefix, Prefix, Prefix], Game)
    for Key in ["ServerA", "ServerB", "ServerIdentity", "ServerCallback", "ClientA", "ClientB", "ClientIdentity", "ClientCallback"]:
        await Until(Key)
    print("[Runtime:Integration] Shared modules, per-domain caches, script identity and yielding callbacks checked")
    var LocalFunction: Node = ClassDB.instantiate("RemoteFunctionNode")
    LocalFunction.name = "LocalFunction"
    Storage.add_child(LocalFunction)
    var LocalEvent: Node = ClassDB.instantiate("BindableEventNode")
    LocalEvent.name = "LocalEvent"
    Storage.add_child(LocalEvent)
    CreateScript("ServerScript", "LocalHandler", """
game.ReplicatedStorage.LocalFunction.OnServerInvoke = function(Player, Value)
    assert(script.Name == 'LocalHandler')
    return Value + 1
end
game.ReplicatedStorage.LocalEvent.Event:Connect(function(Value)
    task.wait()
    assert(Value == 42 and script.Name == 'LocalHandler')
    game:SetAttribute('BindableDone', true)
end)
game:SetAttribute('LocalHandlerReady', true)
""", Game)
    await Until("LocalHandlerReady")
    CreateScript("ServerScript", "LocalCaller", """
assert(game.ReplicatedStorage.LocalFunction:InvokeServer(41) == 42)
game.ReplicatedStorage.LocalEvent:Fire(42)
game:SetAttribute('LocalInvokeDone', true)
""", Game)
    CreateScript("LocalScript", "LuaServiceHandler", """
game:GetService('CollectionService'):GetInstanceAddedSignal('DomainTest'):Once(function(Target)
    assert(script.Name == 'LuaServiceHandler' and Target.Name == 'LocalFunction')
    game:SetAttribute('TagDone', true)
end)
game:GetService('ContextActionService'):BindAction('DomainTest', function(Name)
    assert(script.Name == 'LuaServiceHandler' and Name == 'DomainTest')
    game:SetAttribute('ActionDone', true)
end, false)
game:SetAttribute('LuaServiceReady', true)
""", Game)
    await Until("LuaServiceReady")
    CreateScript("LocalScript", "LuaServiceCaller", "game:GetService('CollectionService'):AddTag(game.ReplicatedStorage.LocalFunction, 'DomainTest'); game:GetService('ContextActionService'):CallFunction('DomainTest', nil, nil)", Game)
    for Key in ["LocalInvokeDone", "BindableDone", "TagDone", "ActionDone"]:
        await Until(Key)
    var ContextScript: Node = ClassDB.instantiate("ServerScript")
    var ContextResource: Script = ClassDB.instantiate("LuauScript")
    ContextScript.name = "ClientRunContext"
    ContextScript.set_meta("RunContext", 2)
    ContextResource.source_code = "assert(game:GetService('RunService'):IsClient()); __IS_CLIENT = false; __IS_SERVER = true; assert(game:GetService('RunService'):IsClient()); assert(script.Name == 'ClientRunContext'); game:SetAttribute('RunContextDone', true)"
    ContextScript.call("set_codigo_luau", ContextResource)
    Game.add_child(ContextScript)
    await Until("RunContextDone")
    var Templates: Node = ClassDB.instantiate("StarterPlayerScripts")
    Templates.name = "Templates"
    Game.add_child(Templates)
    CreateScript("ServerScript", "ServerTemplate", "game:SetAttribute('TemplateRan', true)", Templates)
    CreateScript("LocalScript", "ClientTemplate", "game:SetAttribute('TemplateRan', true)", Templates)
    await process_frame
    await process_frame
    Check(not Game.has_meta("TemplateRan"), "Starter template executed")
    CreateScript("ServerScript", "CancelledSignal", """
local Service = game:GetService('RunService')
local Pending = task.spawn(function() Service.Heartbeat:Wait(); game:SetAttribute('CancelledSignalRan', true) end)
task.cancel(Pending)
Service.Heartbeat:Once(function() game:SetAttribute('SignalCancellationDone', true) end)
""", Game)
    await Until("SignalCancellationDone")
    Check(not Game.has_meta("CancelledSignalRan"), "Cancelled signal waiter resumed")

    CreateScript("ServerScript", "ChildWait", """
game:SetAttribute('WaitingChild', true)
local Child = game:WaitForChild('FutureChild', 2)
assert(Child and Child.Name == 'FutureChild' and script.Name == 'ChildWait')
game:SetAttribute('ChildResolved', true)
""", Game)
    await Until("WaitingChild")
    var Child := Node.new()
    Child.name = "FutureChild"
    Game.add_child(Child)
    await Until("ChildResolved")

    var Victim := CreateScript("ServerScript", "Victim", """
task.delay(0.05, function() game:SetAttribute('CancelledRan', true) end)
game:SetAttribute('VictimStarted', true)
game:WaitForChild('NeverCreated', 10)
game:SetAttribute('CancelledRan', true)
""", Game)
    await Until("VictimStarted")
    Victim.queue_free()
    await create_timer(0.1).timeout
    Check(not Game.has_meta("CancelledRan"), "Destroyed owner resumed tasks or child wait")
    CreateScript("ServerScript", "Survivor", "assert(require(game.ReplicatedStorage.Counter).Value == 1); game:SetAttribute('Survived', true)", Game)
    await Until("Survived")

    var Toggle := CreateScript("ServerScript", "Toggle", """
_G.ToggleRuns = (_G.ToggleRuns or 0) + 1
game:SetAttribute('ToggleRuns', _G.ToggleRuns)
task.delay(0.05, function() game:SetAttribute('OldToggleRan', true) end)
""", Game)
    await Until("ToggleRuns")
    Toggle.call("set_enabled", false)
    Toggle.call("set_codigo_luau", ClassDB.instantiate("LuauScript"))
    var ReloadResource: Script = Toggle.call("get_codigo_luau")
    ReloadResource.source_code = "_G.ToggleRuns += 1; game:SetAttribute('ReloadRuns', _G.ToggleRuns)"
    Toggle.call("set_enabled", true)
    await Until("ReloadRuns")
    await create_timer(0.1).timeout
    Check(Game.get_meta("ReloadRuns", 0) == 2 and not Game.has_meta("OldToggleRan"), "Disable/reload/re-enable did not isolate runs")

    var Target := Node.new()
    Target.name = "LifetimeTarget"
    Game.add_child(Target)
    CreateScript("ServerScript", "RetainedMethod", """
local Target = game.LifetimeTarget
local Method = Target.WaitForChild
game:SetAttribute('MethodRetained', true)
task.wait(0.05)
local Ok, Result = pcall(Method, Target, 'Missing', 0.01)
assert(Ok and Result == nil)
game:SetAttribute('RetainedSafe', true)
""", Game)
    await Until("MethodRetained")
    Target.queue_free()
    await Until("RetainedSafe")
    CreateScript("ServerScript", "DestroyInCallback", """
game:GetService('RunService').Heartbeat:Once(function()
    task.defer(function() game:SetAttribute('AfterCallbackDestroy', true) end)
    game:SetAttribute('DestroyCallbackEntered', true)
    script:Destroy()
end)
""", Game)
    await Until("DestroyCallbackEntered")
    await create_timer(0.05).timeout
    Check(not Game.has_meta("AfterCallbackDestroy"), "Owner-destroying callback left scheduled work")
    for Index in range(10):
        var Repeated := CreateScript("ServerScript", "Repeated" + str(Index), "task.delay(1, function() game:SetAttribute('RepeatedBad', true) end); game:WaitForChild('NeverCreated', 5)", Game)
        await process_frame
        Repeated.queue_free()
        await process_frame
    Check(not Game.has_meta("RepeatedBad"), "Repeated teardown resumed cancelled work")
    var Counter: Node = Storage.get_node("Counter")
    Counter.name = "CounterRenamed"
    CreateScript("ServerScript", "RenamedModule", "assert(require(game.ReplicatedStorage.CounterRenamed) == shared.Counter); game:SetAttribute('RenameIdentity', true)", Game)
    await Until("RenameIdentity")
    var CounterResource: Script = Counter.call("get_codigo_luau")
    CounterResource.source_code = "return {Value = 20}"
    CreateScript("ServerScript", "ReloadServerModule", "assert(require(game.ReplicatedStorage.CounterRenamed).Value == 20 and shared.Counter.Value == 1); game:SetAttribute('ServerModuleReload', true)", Game)
    CreateScript("LocalScript", "ReloadClientModule", "assert(require(game.ReplicatedStorage.CounterRenamed).Value == 20 and shared.Counter.Value == 1); game:SetAttribute('ClientModuleReload', true)", Game)
    await Until("ServerModuleReload")
    await Until("ClientModuleReload")
    Counter.queue_free()
    await process_frame
    CreateScript("ModuleScript", "CounterRenamed", "return {Value = 30}", Storage)
    CreateScript("ServerScript", "ReplacedModule", "assert(require(game.ReplicatedStorage.CounterRenamed).Value == 30); game:SetAttribute('ModuleReplaced', true)", Game)
    await Until("ModuleReplaced")
    var LuaSubscriber := CreateScript("ServerScript", "LuaSubscriber", """
assert(_GLDomainSpawn == nil)
shared.Signal = _gl_signal()
shared.Subscription = shared.Signal:Connect(function(Value)
    assert(Value == 42 and script.Name == 'LuaSubscriber')
    game:SetAttribute('LuaCallbackStarted', true)
    task.wait(0.08)
    game:SetAttribute('LuaCallbackAfterDestroy', true)
end)
game:SetAttribute('LuaSubscribed', true)
""", Game)
    await Until("LuaSubscribed")
    CreateScript("ServerScript", "LuaPublisher", "shared.Signal:Fire(42)", Game)
    await Until("LuaCallbackStarted")
    LuaSubscriber.queue_free()
    await create_timer(0.1).timeout
    Check(not Game.has_meta("LuaCallbackAfterDestroy"), "Shared Lua signal borrowed the publisher's owner")
    CreateScript("ServerScript", "LuaOwnerVerifier", "assert(not shared.Subscription.Connected); shared.Signal:Fire(42); game:SetAttribute('LuaOwnerVerified', true)", Game)
    await Until("LuaOwnerVerified")
    var DetachedWaiter := CreateScript("ServerScript", "DetachedWaiter", "game:GetService('RunService').Heartbeat:Wait(); game:SetAttribute('DetachedOldWaitRan', true)", Game)
    DetachedWaiter.call("iniciar_corrutina")
    Game.remove_child(Service)
    Game.queue_free()
    await process_frame
    await process_frame
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    CreateScript("ServerScript", "FreshScene", "assert(_G.Initializations == nil and shared.Counter == nil and script.Name == 'FreshScene'); game:SetAttribute('FreshDomain', true)", Game)
    Game.add_child(Service)
    await Until("FreshDomain")
    await process_frame
    Check(not Game.has_meta("DetachedOldWaitRan"), "Detached native signal revived a retired owner")
    CreateScript("ServerScript", "WarnedWait", "game:SetAttribute('WarnWaiting', true); assert(game:WaitForChild('AfterWarning')); game:SetAttribute('WarnWaitDone', true)", Game)
    await Until("WarnWaiting")
    await create_timer(5.1).timeout
    var AfterWarning := Node.new()
    AfterWarning.name = "AfterWarning"
    Game.add_child(AfterWarning)
    await Until("WarnWaitDone")
    print("[Runtime:Integration] Child waits, owner destruction, survivor cache, disable/reload and retained WaitForChild checked")
    print("[Runtime:Integration] ", "FAILED" if Failed else "PASS")
    quit(1 if Failed else 0)
