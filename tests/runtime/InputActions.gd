extends SceneTree

var Game: Node
var Failed := false
var Checks := 0

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
Move:AddBinding(Enum.KeyCode.W, {Vector=Vector2.new(0,-1)})
Move:AddBinding(Enum.KeyCode.D, {Vector=Vector2.new(1,0)})
local Scalar = C:AddAction('Scalar', {ValueType=Enum.InputActionValueType.Scalar})
Scalar:AddBinding(Enum.KeyCode.E, {Scale=0.5})
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
shared.Input = {Service=S, Context=C, Jump=Jump, Binding=Binding, Menu=Menu, Confirm=Confirm, Chord=Chord, Pad=Pad, Move=Move, Scalar=Scalar}
shared.Input.RetainedGet=Jump.GetValue
shared.Input.RetainedConnect=Jump.Changed.Connect
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
    var OldContext := Context.get_instance_id()
    Owner.free()
    await process_frame
    await process_frame
    Check(not is_instance_id_valid(OldContext), "Lua creator retirement removes authored context and callbacks")
    await Probe("RetainedSafe", """
assert(not pcall(function() shared.Input.RetainedGet(shared.Input.Jump) end))
assert(not pcall(function() shared.Input.RetainedConnect({}, function() error('stale') end) end))
""")
    Check(not Game.get_meta("CallbackFailed", false) and Game.get_meta("Presses", 0) == 4, "callbacks completed for original and rebound inputs")
    print("[Input:Actions] ", JSON.stringify({"Checks":Checks, "Diagnostics":Service.call("GetDiagnostics")}))
    Game.free()
    await process_frame
    print("[Input:Actions] ", "FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
