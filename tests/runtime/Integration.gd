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
    # Capture the real first bootstrap in each domain, then verify subsequent
    # script starts reuse its globals, wrappers and per-domain module result.
    CreateScript("ModuleScript", "BootstrapContract", """
assert(typeof(game) == 'Instance' and game.Name == 'Game')
assert(typeof(workspace) == 'Instance' and typeof(script) == 'Instance')
assert(type(_G) == 'table' and type(shared) == 'table')
assert(type(task.spawn) == 'function' and type(require) == 'function')
assert(type(Instance.new) == 'function' and type(Vector3.new) == 'function')
assert(type(Color3.new) == 'function' and type(CFrame.new) == 'function')
assert(type(_FileAccess.read) == 'function' and type(_FileAccess.write) == 'function')
assert(type(_HTTP.request) == 'function' and type(_HTTP.get) == 'function' and type(_HTTP.post) == 'function')
assert(type(_GL_NET.call) == 'function' and type(_GL_NET.teleport) == 'function')
assert(type(__gl_rf_serve) == 'function' and type(__gl_rf_respond) == 'function')
assert(type(_GL_VM_ID) == 'function' and _GLDomainSpawn == nil)
local Decoded = _JSON.decode(_JSON.encode({Flag = true, Text = 'bootstrap', Items = {1, 2}}))
assert(Decoded.Flag and Decoded.Text == 'bootstrap' and Decoded.Items[2] == 2)
local Prefix = __IS_CLIENT and 'BootstrapClient' or 'BootstrapServer'
assert(_GL_NET_ROLE() == (__IS_CLIENT and 2 or 0))
assert(_G.BootstrapDomainTag == nil and shared.BootstrapModuleRuns == nil)
_G.BootstrapDomainTag = Prefix
shared.BootstrapModuleRuns = 1
local Meta = getmetatable(game)
assert(Meta == getmetatable(script) and Meta == getmetatable(workspace))
game:GetAttributeChangedSignal('BootstrapAttributeTrigger'):Connect(function()
    assert(_G.BootstrapDomainTag == Prefix and shared.BootstrapModuleRuns == 1)
    game:SetAttribute(Prefix .. 'Attribute', true)
end)
return {Prefix = Prefix, Meta = Meta, Game = game, Workspace = workspace,
    JSON = _JSON, HTTP = _HTTP, InstanceNew = Instance.new, VectorNew = Vector3.new,
    RemoteServe = __gl_rf_serve}
""", Storage)
    for Type in ["ServerScript", "LocalScript"]:
        var Prefix := "BootstrapServer" if Type == "ServerScript" else "BootstrapClient"
        # Distinct native relay targets preserve both-domain coverage without
        # depending on the pre-existing shared-object connection conflict.
        CreateScript("ModuleScript", Prefix + "Relay", """
local Prefix = __IS_CLIENT and 'BootstrapClient' or 'BootstrapServer'
local Meta = getmetatable(game)
game.ChildAdded:Connect(function(Child)
    if Child.Name == 'BootstrapChild' then
        assert(getmetatable(Child) == Meta and Child == game.BootstrapChild)
        game:SetAttribute(Prefix .. 'ModuleChild', true)
    end
end)
return true
""", Storage)
        var Starters: Array[Node] = []
        for Attempt in range(2):
            var Marker := Prefix + str(Attempt)
            var Starter := CreateScript(Type, Marker, """
local Bootstrap = require(game.ReplicatedStorage.BootstrapContract)
assert(require(game.ReplicatedStorage['%sRelay']))
assert(Bootstrap.Prefix == '%s' and _G.BootstrapDomainTag == '%s')
assert(shared.BootstrapModuleRuns == 1 and Bootstrap.Game == game and Bootstrap.Workspace == workspace)
assert(Bootstrap.Meta == getmetatable(script) and script == game:FindFirstChild(script.Name))
assert(Bootstrap.JSON == _JSON and Bootstrap.HTTP == _HTTP)
assert(Bootstrap.InstanceNew == Instance.new and Bootstrap.VectorNew == Vector3.new)
assert(Bootstrap.RemoteServe == __gl_rf_serve and _GLDomainSpawn == nil)
game:SetAttribute('%sRuns', (game:GetAttribute('%sRuns') or 0) + 1)
game:SetAttribute('%s', true)
""" % [Prefix, Prefix, Prefix, Prefix, Prefix, Marker], Game)
            Starters.append(Starter)
            await Until(Marker)
            Starter.call("iniciar_corrutina")
            Starter.call("iniciar_corrutina")
            Check(Game.get_meta(Prefix + "Runs", 0) == Attempt + 1, "Repeated startup duplicated bootstrap or script execution")
        for Starter in Starters:
            Starter.queue_free()
    await process_frame
    var BootstrapChild := Node.new()
    BootstrapChild.name = "BootstrapChild"
    Game.add_child(BootstrapChild)
    await Until("BootstrapServerModuleChild")
    await Until("BootstrapClientModuleChild")
    CreateScript("ServerScript", "BootstrapAttributeTrigger", "game:SetAttribute('BootstrapAttributeTrigger', true)", Game)
    await Until("BootstrapServerAttribute")
    await Until("BootstrapClientAttribute")
    print("[Runtime:Integration] Per-domain bootstrap, shared module wrappers and retired-caller child relays checked")
    # Exercise the native value bindings in both domains through production APIs.
    for Type in ["ServerScript", "LocalScript"]:
        var Prefix := "ValueServer" if Type == "ServerScript" else "ValueClient"
        var NativeBridge: Node = ClassDB.instantiate("Beam")
        NativeBridge.name = Prefix + "Native"
        Game.add_child(NativeBridge)
        NativeBridge.set_meta("_glp_NativeInt", -17)
        NativeBridge.set_meta("_glp_NativeBool", false)
        NativeBridge.set_meta("_glp_NativeFloat", 2.5)
        NativeBridge.set_meta("_glp_NativeString", "héλ")
        NativeBridge.set_meta("_glp_NativeVector", Vector3(8, 9, 10))
        NativeBridge.set_meta("_glp_NativeColor", Color(0.25, 0.5, 0.75))
        NativeBridge.set_meta("_glp_NativeArray", [1, 2])
        NativeBridge.set_meta("_glp_NativeDictionary", {"Value": 1})
        NativeBridge.set_meta("_glp_NativeObject", Game)
        NativeBridge.set_meta("_glp_process_priority", 999)
        NativeBridge.set_meta("_glp_transform", "unsupported-native fallback")
        var NativeMultiplayer = NativeBridge.get("multiplayer")
        CreateScript(Type, Prefix, """
local Value = Vector3.new(3, 4, 0)
assert(Value.X == 3 and Value.y == 4 and Value.Z == 0 and Value.Magnitude == 5)
assert(Vector3.zero == Vector3.new() and Vector3.one == Vector3.new(1, 1, 1))
assert(Value + Vector3.one == Vector3.new(4, 5, 1))
assert(Value - Vector3.one == Vector3.new(2, 3, -1))
assert(Value * 2 == 2 * Value and Value / 2 == Vector3.new(1.5, 2, 0))
assert(Value * Vector3.new(2, 3, 4) == Vector3.new(6, 12, 0))
assert(Value / Vector3.new(3, 2, 1) == Vector3.new(1, 2, 0))
assert(-Value == Vector3.new(-3, -4, 0) and Vector3.zero.Unit == Vector3.zero)
assert(math.abs(Value.Unit.Magnitude - 1) < 0.0001)
assert(Value.Lerp(Vector3.new(5, 6, 2), 0.5) == Vector3.new(4, 5, 1))
assert(Value.Dot(Vector3.one) == 7 and Value.Cross(Vector3.one) == Vector3.new(4, -3, -1))
assert(tostring(Value) == '3.000, 4.000, 0.000' and Value.Unknown == nil)
local Color = Color3.fromRGB(255, 128, 0)
assert(Color.R == 1 and math.abs(Color.g - 128/255) < 0.0001 and Color.B == 0)
assert(Color3.new().R == 0 and Color.Unknown == nil)
assert(Value + Color == nil and Value + game == nil)
local Ok, Message = pcall(Vector3.new, 'invalid')
assert(not Ok and type(Message) == 'string')
local Bridge = Instance.new('Beam')
Bridge.Parent = game
Bridge.TestVector = Value
Bridge.TestColor = Color
assert(Bridge.TestVector == Value and Bridge.TestColor.R == Color.R)
assert(Bridge == game:FindFirstChild(Bridge.Name) and Bridge.Parent == game)
local Native = game:FindFirstChild(script.Name .. 'Native')
assert(Native.NativeInt == -17 and Native.NativeBool == false and Native.NativeFloat == 2.5)
assert(Native.NativeString == 'héλ' and Native.NativeVector == Vector3.new(8, 9, 10))
assert(Native.NativeColor.R == 0.25 and Native.NativeColor.G == 0.5 and Native.NativeColor.B == 0.75)
for _, Key in ipairs({'NativeArray', 'NativeDictionary', 'NativeObject'}) do
    local ReadOk, ReadError = pcall(function() return Native[Key] end)
    assert(not ReadOk and string.find(ReadError, Key .. ' is not a valid member', 1, true))
end
for _, Number in ipairs({0, -3.5, 9007199254740991}) do
    Native.RoundTrip = Number
    assert(Native.RoundTrip == Number)
end
Native.RoundTrip = false
assert(Native.RoundTrip == false)
Native.RoundTrip = true
assert(Native.RoundTrip == true)
Native.RoundTrip = 'héλ'
-- Preserve the existing Godot String(const char*) Latin-1 interpretation.
assert(Native.RoundTrip == 'hÃ©Î»')
Native.RoundTrip = 'scalar string'
assert(Native.RoundTrip == 'scalar string')
Native.RoundTrip = 42
Native.RoundTrip = nil
assert(Native.RoundTrip == 42)
for _, Unsupported in ipairs({{}, {1, 2}, function() end, game, newproxy(true)}) do
    Native.RoundTrip = Unsupported
    assert(Native.RoundTrip == 42)
end
Native.RoundTrip = {Offset = 17}
assert(Native.RoundTrip == 17)
Native.RoundTrip = {Offset = 'invalid'}
assert(Native.RoundTrip == 17)
Native.process_priority = -5
assert(Native.process_priority == -5)
-- Native properties precede metadata; unsupported native values may fall back.
assert(Native.transform == 'unsupported-native fallback')
Native.position = Vector3.new(2, 3, 4)
assert(Native.position == Vector3.new(2, 3, 4))
Native.visible = false
assert(Native.visible == false)
Native.process_priority = {Offset = 6}
assert(Native.process_priority == 6)
Native.process_priority = nil
assert(Native.process_priority == 6)
-- Godot's read-only multiplayer property is not writable metadata.
Native.multiplayer = 7
local ReadOnlyOk, ReadOnlyError = pcall(function() return Native.multiplayer end)
assert(not ReadOnlyOk and string.find(ReadOnlyError, 'is not a valid member', 1, true))
for Index = 1, 20 do
    assert(Native.process_priority == 6 and Native.position.X == 2)
end
local MissingOk, MissingError = pcall(function() return Native.MissingReflectionProperty end)
assert(not MissingOk and string.find(MissingError, 'MissingReflectionProperty is not a valid member', 1, true))
local OffsetOk, OffsetError = pcall(function()
    Native.RoundTrip = setmetatable({}, {__index = function() error('OffsetProbe') end})
end)
assert(not OffsetOk and string.find(OffsetError, 'OffsetProbe', 1, true))
assert(Native.RoundTrip == 17)
local Changed = 0
Native.Changed:Connect(function() Changed += 1 end)
Native.RoundTrip = 17
assert(Changed == 0) -- Generic writes do not synthesize Instance.Changed.
Native:SetAttribute('ReflectionProbe', 1)
assert(Changed == 1)
local Plain = Instance.new('Folder')
Plain.ReflectionProbe = 7
assert(not pcall(function() return Plain.ReflectionProbe end))
Plain:Destroy()
local AddOk, AddError = pcall(function() return Native.RoundTrip + Color end)
assert(not AddOk and type(AddError) == 'string')
Bridge:Destroy()
for Index = 1, 10 do
    if Bridge.Name == nil then break end
    task.wait()
end
assert(Bridge.Name == nil)
Native.RoundTrip = Bridge
assert(Native.RoundTrip == 17)
game:SetAttribute('%s', true)
""" % Prefix, Game)
        await Until(Prefix)
        Check(NativeBridge.get("multiplayer") == NativeMultiplayer, "Read-only native property changed")
        Check(not NativeBridge.has_meta("_glp_multiplayer"), "Read-only write created fallback metadata")
        Check(NativeBridge.get("process_priority") == 6, "Reflected write did not reach Godot")
    # Class identity strings must survive other lookups, callbacks, GC and deletion.
    for Type in ["ServerScript", "LocalScript"]:
        var Prefix := "IdentityServer" if Type == "ServerScript" else "IdentityClient"
        CreateScript(Type, Prefix, """
local Folder = Instance.new('Folder', game)
local Beam = Instance.new('Beam', Folder)
local Trail = Instance.new('Trail', Folder)
local Model = Instance.new('Model', Folder)
local Light = Instance.new('PointLight', Folder)
local Frame = Instance.new('Frame', Folder)
local Value = Instance.new('IntValue', Folder)
local Names = {Folder.ClassName, Beam.ClassName, Trail.ClassName, Model.ClassName, Light.ClassName, Frame.ClassName, Value.ClassName, script.ClassName}
local Expected = {'Folder', 'Beam', 'Trail', 'Node3D', 'PointLight', 'Frame', 'IntValue', script:IsA('Script') and 'Script' or 'LocalScript'}
for Index, Name in ipairs(Names) do assert(Name == Expected[Index]) end
assert(Folder:IsA('Folder') and Folder:IsA('Node') and Folder:IsA('Instance'))
assert(Beam:IsA('Beam') and Beam:IsA('Node3D') and Beam:IsA('Node'))
assert(Light:IsA('PointLight') and Light:IsA('OmniLight3D') and Light:IsA('Light3D'))
assert(Frame:IsA('Frame') and Frame:IsA('GuiObject') and Frame:IsA('GuiBase2d') and Frame:IsA('Control'))
assert(Value:IsA('IntValue') and Value:IsA('ValueBase') and not Value:IsA('NumberValue'))
assert(script:IsA('LuaSourceContainer'))
for _, Query in ipairs({'', 'NoSuchNativeClass', 'Humanoid', 'beam', 'Part'}) do
    assert(not Beam:IsA(Query))
end
assert(Folder:FindFirstChildWhichIsA('Node3D') == Beam)
assert(Beam:FindFirstAncestorWhichIsA('Folder') == Folder)
for Index = 1, 40 do
    assert(Beam.ClassName == 'Beam' and Trail.ClassName == 'Trail' and Model.ClassName == 'Node3D')
    assert(Beam:IsA('Node3D') and not Trail:IsA('Beam'))
    for NameIndex, Name in ipairs(Names) do assert(Name == Expected[NameIndex]) end
end
local ErrorOk, ErrorText = pcall(function() return Beam.MissingClassIdentityMember end)
assert(not ErrorOk and string.find(ErrorText, 'MissingClassIdentityMember is not a valid member of Beam', 1, true))
local CallbackDone = false
Folder:GetAttributeChangedSignal('IdentityProbe'):Connect(function()
    local Before = Beam.ClassName
    local Nested = Trail.ClassName
    assert(Before == 'Beam' and Nested == 'Trail' and Light:IsA('Light3D'))
    Folder:SetAttribute('NestedIdentity', Model.ClassName)
    assert(Before == 'Beam' and Beam.ClassName == Before)
    CallbackDone = true
end)
Folder:SetAttribute('IdentityProbe', 1)
assert(CallbackDone and Folder:GetAttribute('NestedIdentity') == 'Node3D')
local RetainedIsA = Beam.IsA
Beam:Destroy()
for Index = 1, 10 do
    if Beam.ClassName == nil then break end
    task.wait()
end
assert(Beam.ClassName == nil and not RetainedIsA(Beam, 'Instance'))
local Replacement = Instance.new('Trail', Folder)
assert(Replacement ~= Beam and Replacement.ClassName == 'Trail')
assert(Names[2] == 'Beam' and Names[3] == 'Trail')
-- Production Luau exposes gcinfo, not an explicit collectgarbage entry point.
local PreviousMemory = gcinfo()
local ObservedCollection = false
for Index = 1, 20000 do
    local Garbage = {Trail.ClassName, Model.ClassName, string.rep('identity-gc-', 20) .. tostring(Index)}
    local Memory = gcinfo()
    if Memory < PreviousMemory then ObservedCollection = true end
    PreviousMemory = Memory
end
assert(ObservedCollection)
for Index, Name in ipairs(Names) do assert(Name == Expected[Index]) end
Folder:Destroy()
game:SetAttribute('%s', true)
""" % Prefix, Game)
        await Until(Prefix)
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
    # The observer precedes ModuleScript's changed handler. Revision validation
    # must see new source even before that handler explicitly invalidates cache.
    var RevisionResource: Script = ClassDB.instantiate("LuauScript")
    RevisionResource.source_code = "return {Value = 1}"
    RevisionResource.changed.connect(func():
        var Observer := CreateScript("ServerScript", "RevisionObserver", "assert(require(game.ReplicatedStorage.RevisionCounter).Value == 2); game:SetAttribute('RevisionObserved', true)", Game)
        Observer.call("iniciar_corrutina")
        Check(Game.get_meta("RevisionObserved", false), "Earlier changed subscriber read a stale module revision")
    )
    var RevisionModule: Node = ClassDB.instantiate("ModuleScript")
    RevisionModule.name = "RevisionCounter"
    RevisionModule.call("set_codigo_luau", RevisionResource)
    Storage.add_child(RevisionModule)
    CreateScript("ServerScript", "RevisionWarmup", "assert(require(game.ReplicatedStorage.RevisionCounter).Value == 1); game:SetAttribute('RevisionWarmed', true)", Game)
    await Until("RevisionWarmed")
    RevisionResource.source_code = "return {Value = 2}"
    await Until("RevisionObserved")
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
    CreateScript("ServerScript", "FreshScene", "assert(_G.Initializations == nil and shared.Counter == nil and script.Name == 'FreshScene'); assert(script.ClassName == 'Script' and script:IsA('LuaSourceContainer') and game.ClassName == 'Node'); assert(Vector3.new(1, 2, 3) + Vector3.one == Vector3.new(2, 3, 4) and Color3.fromRGB(255, 0, 0).R == 1); game:SetAttribute('FreshDomain', true)", Game)
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
