# Input actions API

Status: development branch, digital slice implemented; see the
[campaign journal](input-action-development.md) for actual qualification.
[ADR-012](adr-012-input-actions.md) records ownership and compatibility decisions.

```lua
local Input = game:GetService("InputService") -- Client execution only
local Gameplay = Input:AddContext("Gameplay", {Priority = 0})
local Jump = Gameplay:AddAction("Jump") -- Bool by default
local Binding = Jump:AddBinding(Enum.KeyCode.Space)
Jump.Pressed:Connect(function() print("Jump") end)
Jump.Changed:Connect(function(Value) print(Value) end)
Jump.Canceled:Connect(function(Reason) print(Reason) end)
Jump.Released:Once(function() print("Released") end)
Binding.KeyCode = Enum.KeyCode.Q
```

The authoring Instances are the configuration. `Instance.new("InputContext")`,
`InputAction` and `InputBinding` also work; parent direct chains beneath
InputService. Native scene authoring serializes their `Configuration` dictionary;
the Luau API exposes its individual typed fields. Duplication copies authoring
configuration, not active input, connections or a script's ownership guard.
Unknown or invalid options raise a Luau error before applying the configuration.
`Configure(Options)` applies several fields atomically. Reapplying identical
configuration has no transition. Contexts created by a script/module retire with
that native execution owner; project-authored contexts remain scene-owned.

| Instance | Fields and methods |
| --- | --- |
| InputService | `AddContext(Name, Options?)`, `GetDiagnostics()` |
| InputContext | `Enabled`, `Priority`, `Consume`; `AddAction(Name, Options?)` |
| InputAction | `Enabled`, `ValueType`; read-only `Value`, `GetValue()`, `AddBinding(Code, Options?)` |
| InputBinding | `Enabled`, `SourceType`, `KeyCode`, `Device`, `Priority`, `Consume`, `Modifiers`, `ExactModifiers`, `Scale`, `Vector` |

`Enum.InputActionValueType` is Bool=0, Scalar=1, Vector2=2. Bool bindings OR;
Scalar bindings sum and clamp to [-1,1]; Vector2 bindings sum and clamp to unit
length. For example four ordinary bindings with Vector2 contributions form WASD.
`Vector` defaults to (1,0), `Scale` to 1. Contexts and bindings have priority 0;
contexts consume by default and bindings do not add consumption by default.
Actions in the same context can cofire. Higher consuming contexts suppress lower
contexts. Equal priorities use native ObjectID order, independent of names.

`Enum.InputBindingSource` initially contains Key=0, MouseButton=1 and
GamepadButton=2. AddBinding infers keyboard from KeyCode, mouse from buttons 1–3,
and gamepad from ButtonA/B/X/Y/L1/R1/L3/R3/Start/Select or DPadUp/Down/Left/Right.
Gamepad Device defaults to 0; -1 accepts any of the 16 supported device indices.
These semantic button codes map to Godot buttons; existing UserInputService raw
gamepad codes retain their previous meaning. Unsupported digital triggers are
not advertised as implemented. Mouse wheel, touch and analog raw APIs remain
available through UserInputService; semantic analog/pointer sources follow in
the next slice.

Modifiers are a unique array of up to four left/right Shift/Control/Alt/Meta
codes. A chord admits on a fresh primary press after its modifiers, never by
pressing a modifier after an already-held primary. ExactModifiers rejects extra
held modifiers. Focus loss, GUI consumption, definition/owner retirement and
device removal clear affected state. Reenabling/rebinding does not synthesize a
press from held hardware. Every changed action commits before any callback;
callback edits affect the next safe evaluation. Nonphysical termination emits
Canceled before Released, in addition to Changed. New action signal views expose
Connect and Once; they do not currently implement Wait. Existing raw signals and
RemoteEvent signal APIs retain their contracts.

Bounds: 32 contexts, 256 actions, 1,024 bindings per evaluated graph, four
modifiers per binding, 128 callbacks per action and 1,024 pending physical events
per raw adapter. Existing GL-004 reference quotas also apply. Invalid/oversized
graphs fail closed to neutral input and increment diagnostics. These are graph
and queue limits, not a new general Godot Node allocation quota. Priorities are
integers within +/-10,000; scales/direction lengths are finite and at most 1,000.

One canonical service and raw adapter evaluate each viewport, with at most 16
registered viewports. A duplicate service stays inactive and reports it. Context
consumption affects semantic actions; it does not undo native Character V2's
independent polling or previously run Godot handlers. No network authority,
replication stream or global Godot InputMap is introduced.

## UserInputService migration

Previously raw callbacks ran in `_input` and always reported gameProcessed=false.
Godot GUI routing follows `_input`; the old flag could not describe GUI handling.
The shared adapter now commits events in arrival order at a deferred post-GUI
barrier, marking events reaching `_unhandled_input` as unconsumed. Raw callback
argument shapes and polling APIs remain compatible, while callback timing moves
within the frame and gameProcessed reflects routing. Code depending on pre-GUI
callbacks must migrate. A later native unhandled handler consuming an event after
the adapter observes it is not retroactively attributed to GUI. Synthetic events
must use Viewport dispatch to exercise GUI; direct raw compatibility helpers do
not inject physical action state.
