extends SceneTree

var Game: Node
var Failed := false
var Checks := 0

class Samples extends Node:
    var Action: Node
    var Capture := false
    var FrameSum := Vector2.ZERO
    var PhysicsSum := Vector2.ZERO
    var Stable := true
    func _process(_Delta: float) -> void:
        if Capture:
            var Value: Vector2 = Action.call("GetValue")
            FrameSum += Value
            Stable = Stable and Value == Action.call("GetValue")
    func _physics_process(_Delta: float) -> void:
        if Capture:
            var Value: Vector2 = Action.call("GetPhysicsValue")
            PhysicsSum += Value
            Stable = Stable and Value == Action.call("GetPhysicsValue")

func Check(Value: bool, Description: String) -> void:
    Checks += 1
    if not Value:
        Failed = true
        print("[Input:Actions] FAIL ", Description)

func Script(Name: String, Source: String, Client := true) -> Node:
    var Result: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func Key(Code: Key, Pressed: bool, Echo := false) -> void:
    var Event := InputEventKey.new()
    Event.keycode = Code
    Event.pressed = Pressed
    Event.echo = Echo
    root.push_input(Event, true)
    await process_frame
    await process_frame

func Probe(Name: String, Source: String) -> void:
    Script(Name, Source + "\ngame:SetAttribute('" + Name + "', true)")
    await create_timer(0.05).timeout
    Check(Game.get_meta(Name, false), "Luau " + Name)

func Axis(Index: JoyAxis, Value: float) -> void:
    var Event := InputEventJoypadMotion.new()
    Event.device = 3
    Event.axis = Index
    Event.axis_value = Value
    root.push_input(Event, true)
    await create_timer(0.04).timeout

func Motion(Delta: Vector2, Position := Vector2(400,400)) -> void:
    var Event := InputEventMouseMotion.new()
    Event.position = Position
    Event.global_position = Position
    Event.relative = Delta
    root.push_input(Event, true)

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Owner := Script("InputOwner", """
local S = game:GetService('InputService')
assert(S and S.ClassName == 'InputService' and S:IsA('Instance'))
local C = S:AddContext('Gameplay', {Priority=0})
local Jump = C:AddAction('Jump')
local Other = C:AddAction('Other')
local Binding = Jump:AddBinding(Enum.KeyCode.Space)
Other:AddBinding(Enum.KeyCode.Space)
local Menu = S:AddContext('Menu', {Priority=100, Enabled=false})
local Confirm = Menu:AddAction('Confirm')
Confirm:AddBinding(Enum.KeyCode.Space)
local Chord = C:AddAction('Chord')
Chord:AddBinding(Enum.KeyCode.F, {Modifiers={Enum.KeyCode.LeftShift}, ExactModifiers=true})
local Pad = C:AddAction('Pad')
Pad:AddBinding(Enum.KeyCode.ButtonA, {Device=-1})
local Move = C:AddAction('Move', {ValueType=Enum.InputActionValueType.Vector2})
local Keys=Move:BindKeyboardVector2()
assert(Keys.Up.KeyCode==Enum.KeyCode.W and Keys.Right.KeyCode==Enum.KeyCode.D)
local Stick=C:AddAction('Stick', {ValueType=Enum.InputActionValueType.Vector2})
Stick:BindGamepadStick(Enum.InputStick.Left, {Device=3, Deadzone=0.2})
local LookContext=S:AddContext('LookContext', {Enabled=false, Priority=20})
local Look=LookContext:AddAction('Look', {ValueType=Enum.InputActionValueType.Vector2})
Look:BindMouseMotion()
assert(not pcall(function() Look:AddBinding(Enum.KeyCode.Q) end))
local Scalar = C:AddAction('Scalar', {ValueType=Enum.InputActionValueType.Scalar})
Scalar:AddBinding(Enum.KeyCode.E, {Scale=0.5})
local Typed = C:AddAction('Typed')
Typed:AddBinding(Enum.KeyCode.T)
Jump.Pressed:Connect(function()
    local Valid=Jump.Value == true and (Binding.KeyCode ~= Enum.KeyCode.Space or Other:GetValue() == true)
    if not Valid then game:SetAttribute('CallbackFailed', true) end
    assert(Valid)
    game:SetAttribute('Presses', (game:GetAttribute('Presses') or 0)+1)
end)
local OnceConnection
OnceConnection=Jump.Pressed:Once(function()
    if OnceConnection.Connected then game:SetAttribute('CallbackFailed', true) end
    game:SetAttribute('Once', (game:GetAttribute('Once') or 0)+1)
end)
Jump.Canceled:Connect(function(Reason) game:SetAttribute('Cancel', Reason) end)
Jump.Released:Connect(function() game:SetAttribute('Releases', (game:GetAttribute('Releases') or 0)+1) end)
game:GetService('UserInputService').InputBegan:Connect(function(Input, Processed)
    if Input.KeyCode == Enum.KeyCode.Space then game:SetAttribute('RawProcessed', Processed) end
end)
game:GetService('UserInputService').InputChanged:Connect(function(Input, Processed)
    if Input.UserInputType==Enum.UserInputType.MouseMovement then game:SetAttribute('MotionProcessed', Processed) end
end)
shared.Input = {Service=S, Context=C, Jump=Jump, Binding=Binding, Menu=Menu, Confirm=Confirm, Chord=Chord, Pad=Pad, Move=Move, Scalar=Scalar}
shared.Input.RetainedGet=Jump.GetValue
shared.Input.RetainedConnect=Jump.Changed.Connect
shared.Input.LookContext=LookContext
shared.Input.Typed=Typed
shared.Input.RawConnect=game:GetService('UserInputService').InputBegan.Connect
shared.Input.RawPoll=game:GetService('UserInputService').IsKeyDown
game:SetAttribute('Ready', true)
""")
    await create_timer(0.15).timeout
    Check(Game.get_meta("Ready", false), "script-visible canonical service and constructors")
    var Service := Game.get_node_or_null("InputService")
    if Service == null:
        Game.free()
        quit(1)
        return
    var Context: Node = Service.get_node("Gameplay")
    var Jump: Node = Context.get_node("Jump")
    await Key(KEY_SPACE, true)
    Check(Jump.call("GetValue") == true and Game.get_meta("Presses", 0) == 1 and Game.get_meta("Once", 0) == 1, "press, cofire, atomic values and Once")
    Check(Game.get_meta("RawProcessed", true) == false, "raw unconsumed event carries false")
    await Probe("OpenMenu", "shared.Input.Menu.Enabled = true")
    Check(Jump.call("GetValue") == false and Game.get_meta("Cancel", "") == "DefinitionChanged", "menu takeover cancels gameplay")
    Check(Service.get_node("Menu/Confirm").call("GetValue") == false, "context enable cannot synthesize press")
    await Key(KEY_SPACE, false)
    await Key(KEY_SPACE, true)
    Check(Service.get_node("Menu/Confirm").call("GetValue") == true and Jump.call("GetValue") == false, "priority and consumption")
    await Probe("CloseMenu", "shared.Input.Menu.Enabled = false")
    Check(Jump.call("GetValue") == false, "closing menu does not resurrect held gameplay")
    await Key(KEY_SPACE, false)
    await Key(KEY_SPACE, true)
    Check(Jump.call("GetValue") == true and Game.get_meta("Once", 0) == 1, "fresh press and Once remains disconnected")
    var Edit := LineEdit.new()
    Game.add_child(Edit)
    Edit.gui_input.connect(func(Event: InputEvent) -> void:
        if Event is InputEventKey: Edit.accept_event())
    Edit.grab_focus()
    await Key(KEY_SPACE, false)
    Check(Jump.call("GetValue") == false and Game.get_meta("Cancel", "") == "GuiConsumed", "GUI-consumed release cancels action")
    await Key(KEY_SPACE, true)
    Check(Jump.call("GetValue") == false and Game.get_meta("RawProcessed", false) == true, "real Control consumption reaches Luau without gameplay admission")
    await Key(KEY_SPACE, false)
    Edit.release_focus()
    Edit.queue_free()
    await Key(KEY_F, true)
    await Key(KEY_SHIFT, true)
    Check(Context.get_node("Chord").call("GetValue") == false, "late modifier cannot activate chord")
    await Key(KEY_F, false)
    await Key(KEY_F, true)
    Check(Context.get_node("Chord").call("GetValue") == true, "fresh primary with modifier")
    await Key(KEY_SHIFT, false)
    Check(Context.get_node("Chord").call("GetValue") == false, "modifier release neutralizes chord")
    await Key(KEY_F, false)
    await Key(KEY_W, true)
    await Key(KEY_D, true)
    var Direction: Vector2 = Context.get_node("Move").call("GetValue")
    Check(Direction.is_equal_approx(Vector2(1,-1).normalized()), "digital Vector2 composite normalizes diagonal")
    await Key(KEY_W, false)
    await Key(KEY_D, false)
    await Key(KEY_E, true)
    Check(Context.get_node("Scalar").call("GetValue") == 0.5, "scalar binding")
    await Key(KEY_E, false)
    await Key(KEY_T, true)
    await Probe("TypeProjection", "local T=shared.Input.Typed; assert(T.Value==true); T.ValueType=Enum.InputActionValueType.Vector2; assert(type(T.Value)=='boolean')")
    Check(Context.get_node("Typed").call("GetValue") == Vector2.ZERO, "value kind changes with projection at next safe boundary")
    await Key(KEY_T, false)
    var Button := InputEventJoypadButton.new()
    Button.device = 3
    Button.button_index = JOY_BUTTON_A
    Button.pressed = true
    root.push_input(Button, true)
    await process_frame
    await process_frame
    Check(Context.get_node("Pad").call("GetValue") == true, "native gamepad device admission")
    Service.call("DeviceChanged", 3, false)
    Check(Context.get_node("Pad").call("GetValue") == false, "disconnect neutral state")
    await Axis(JOY_AXIS_LEFT_X, 0.1)
    Check(Context.get_node("Stick").call("GetValue") == Vector2.ZERO, "native stick deadzone")
    await Axis(JOY_AXIS_LEFT_X, 0.6)
    var StickValue: Vector2 = Context.get_node("Stick").call("GetValue")
    Check(StickValue.is_equal_approx(Vector2(0.5,0)), "native stick rescaled value")
    Check(Context.get_node("Stick").call("GetPhysicsValue").is_equal_approx(StickValue), "level physics sample matches native tick")
    await Axis(JOY_AXIS_LEFT_Y, 0.6)
    Service.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await Axis(JOY_AXIS_LEFT_X, 0.0)
    await Axis(JOY_AXIS_LEFT_X, 0.8)
    Check(Context.get_node("Stick").call("GetValue") == Vector2.ZERO, "held stick cannot reactivate after focus loss")
    await Axis(JOY_AXIS_LEFT_Y, 0.0)
    Check(Context.get_node("Stick").call("GetValue") == Vector2.ZERO, "partial axis updates cannot fake a fully neutral stick")
    await Axis(JOY_AXIS_LEFT_X, 0.0)
    await Axis(JOY_AXIS_LEFT_X, 0.6)
    Check(Context.get_node("Stick").call("GetValue").is_equal_approx(Vector2(0.5,0)), "neutral stick crossing reactivates")
    Service.call("DeviceChanged", 3, false)
    Check(Context.get_node("Stick").call("GetValue") == Vector2.ZERO, "analog disconnect cancellation")
    await Probe("EnableLook", "shared.Input.LookContext.Enabled=true")
    var Observer := Samples.new()
    Observer.Action = Service.get_node("LookContext/Look")
    Game.add_child(Observer)
    Observer.Capture = true
    Motion(Vector2(4,-2))
    Motion(Vector2(1,-3))
    await create_timer(0.12).timeout
    Observer.Capture = false
    Check(Observer.FrameSum.is_equal_approx(Vector2(5,-5)), "relative input consumed once per rendered frame sample")
    Check(Observer.PhysicsSum.is_equal_approx(Vector2(5,-5)), "physics samples retain all deltas independently of frame rotation")
    Check(Observer.Stable, "repeated sample reads are non-consuming")
    var Panel := Control.new()
    Panel.size = Vector2(120,120)
    Panel.mouse_filter = Control.MOUSE_FILTER_STOP
    Game.add_child(Panel)
    Panel.gui_input.connect(func(Event: InputEvent) -> void:
        if Event is InputEventMouseMotion: Panel.accept_event())
    Observer.FrameSum = Vector2.ZERO
    Observer.PhysicsSum = Vector2.ZERO
    Observer.Capture = true
    Motion(Vector2(8,9), Vector2(20,20))
    await create_timer(0.1).timeout
    Observer.Capture = false
    Check(Observer.FrameSum == Vector2.ZERO and Observer.PhysicsSum == Vector2.ZERO and Game.get_meta("MotionProcessed", false), "real GUI consumes pointer motion before semantic sampling")
    Observer.queue_free()
    Panel.queue_free()
    await Probe("DisableLook", "shared.Input.LookContext.Enabled=false")
    await Key(KEY_SPACE, true)
    await Probe("Rebind", "shared.Input.Binding.KeyCode=Enum.KeyCode.Q")
    Check(Jump.call("GetValue") == false, "rebind cancels held primary")
    await Key(KEY_SPACE, false)
    await Key(KEY_Q, true)
    Check(Jump.call("GetValue") == true, "runtime remap admits new primary")
    await Probe("InvalidOptions", """
local I=shared.Input
assert(not pcall(function() I.Binding.KeyCode=0/0 end))
assert(not pcall(function() I.Jump.ValueType=0.5 end))
assert(not pcall(function() I.Service:AddContext('Invalid', {Typo=true}) end))
local Proxy=setmetatable({}, {__index=function() game:SetAttribute('ProxyInvoked',true); return 1 end})
assert(not pcall(function() I.Binding.Vector=Proxy end))
assert(not game:GetAttribute('ProxyInvoked'))
assert(I.Binding.KeyCode==Enum.KeyCode.Q and I.Jump.ValueType==Enum.InputActionValueType.Bool)
local C=Instance.new('InputContext'); C.Name='Manual'; C.Parent=I.Service
local A=Instance.new('InputAction', C); local B=Instance.new('InputBinding', A)
assert(C.ClassName=='InputContext' and A:IsA('InputAction') and B.KeyCode==Enum.KeyCode.Space)
C:Destroy()
""")
    var Server := Script("ServerAuthority", """
assert(not pcall(function() game.InputService:AddContext('Forged') end))
assert(not pcall(function() game.InputService.Gameplay.Enabled=false end))
assert(not pcall(function() game.InputService.Gameplay:Configure({Enabled=false}) end))
game:SetAttribute('ServerRejected', true)
""", false)
    await create_timer(0.05).timeout
    Check(Game.get_meta("ServerRejected", false) and Service.get_node_or_null("Forged") == null, "native Server execution cannot configure or invoke local input")
    Server.free()
    Service.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    Check(Jump.call("GetValue") == false and Game.get_meta("Cancel", "") == "FocusLost", "focus-loss cancellation")
    await Key(KEY_Q, true, true)
    Check(Jump.call("GetValue") == false, "focus-loss echo cannot resurrect held action")
    await Key(KEY_Q, false)
    await Key(KEY_Q, true)
    paused = true
    Check(Jump.call("GetValue") == false and Game.get_meta("Cancel", "") == "Paused", "scene pause cancels semantic state")
    paused = false
    await Key(KEY_Q, true, true)
    Check(Jump.call("GetValue") == false, "unpause cannot revive held echo")
    var Raw := Game.get_node("UserInputService")
    var RawId := Raw.get_instance_id()
    Raw.free()
    await process_frame
    await process_frame
    Check(Game.get_node("UserInputService").get_instance_id() != RawId, "canonical raw adapter restarts after destruction")
    await Probe("RawRetainedSafe", "assert(shared.Input.RawConnect({}, function() error('stale') end)==nil); assert(shared.Input.RawPoll({}, Enum.KeyCode.Q)==false)")
    var OldContext := Context.get_instance_id()
    Owner.free()
    await process_frame
    await process_frame
    Check(not is_instance_id_valid(OldContext), "Lua creator retirement removes authored context and callbacks")
    await Probe("RetainedSafe", """
assert(not pcall(function() shared.Input.RetainedGet(shared.Input.Jump) end))
assert(not pcall(function() shared.Input.RetainedConnect({}, function() error('stale') end) end))
""")
    Check(not Game.get_meta("CallbackFailed", false) and Game.get_meta("Presses", 0) == 5, "callbacks completed for original and rebound inputs")
    var Diagnostics: Dictionary = Service.call("GetDiagnostics")
    await Probe("RetireDuringAdapter", """
game.ChildAdded:Connect(function(Child)
    if Child.ClassName=='UserInputService' then shared.Input.Service:Destroy() end
end)
""")
    var ServiceId := Service.get_instance_id()
    Game.get_node("UserInputService").free()
    await process_frame
    await process_frame
    Check(not is_instance_id_valid(ServiceId), "adapter creation callback can retire service without stale native access")
    print("[Input:Actions] ", JSON.stringify({"Checks":Checks, "DiagnosticsBeforeRetire":Diagnostics}))
    Game.free()
    await process_frame
    print("[Input:Actions] ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
