# Input actions API

Status: development branch, all four campaign slices implemented; see the
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
| InputBinding | `Enabled`, `SourceType`, `KeyCode`, `Device`, `Priority`, `Consume`, `Modifiers`, `ExactModifiers`, `Scale`, `Vector`, `Axis`, `Deadzone` |

`Enum.InputActionValueType` is Bool=0, Scalar=1, Vector2=2. Bool bindings OR;
Scalar bindings sum and clamp to [-1,1]; Vector2 bindings sum and clamp to unit
length. For example four ordinary bindings with Vector2 contributions form WASD.
`Vector` defaults to (1,0), `Scale` to 1. Contexts and bindings have priority 0;
contexts consume by default and bindings do not add consumption by default.
Actions in the same context can cofire. Higher consuming contexts suppress lower
contexts. Equal priorities use native ObjectID order, independent of names.

`Enum.InputBindingSource` contains Key=0, MouseButton=1, GamepadButton=2,
GamepadStick=3 and MouseMotion=4. AddBinding infers keyboard from KeyCode, mouse from buttons 1–3,
and gamepad from ButtonA/B/X/Y/L1/R1/L3/R3/Start/Select or DPadUp/Down/Left/Right.
Gamepad Device defaults to 0; -1 accepts any of the 16 supported device indices.
These semantic button codes map to Godot buttons; existing UserInputService raw
gamepad codes retain their previous meaning. Unsupported digital triggers are
not advertised as implemented. Mouse wheel, touch and analog raw APIs remain
available through UserInputService. Semantic touch gestures and wheel bindings
are not added by this campaign.

```lua
local Move = Gameplay:AddAction("Move", {ValueType = Enum.InputActionValueType.Vector2})
local Keys = Move:BindKeyboardVector2() -- returns Up/Down/Left/Right bindings; WASD defaults
Move:BindGamepadStick(Enum.InputStick.Left, {Device = -1, Deadzone = 0.2})
local Look = Gameplay:AddAction("Look", {ValueType = Enum.InputActionValueType.Vector2})
Look:BindMouseMotion({Scale = 0.002})
```

`BindKeyboardVector2({Up=..., Down=..., Left=..., Right=...})` supports arrows or
other composites through four ordinary InputBindings. `BindGamepadStick` accepts
Enum.InputStick.Left/Right and radially rescales from Deadzone (default 0.2,
bounded [0,0.95]) to unit magnitude. Keyboard and stick contributions may share
an action and sum/clamp together. Device -1 combines admitted devices in ascending
index. Analog suppression, focus loss and device removal require a neutral sample
then a new deadzone crossing; a context cannot inherit an already-held stick.

`BindMouseMotion(Options?)` requires a separate Vector2 action; relative pixel
displacement cannot mix with level sources. It scales and sums without unit
normalization. Individual components are finite and bounded by 8,192 pixels;
accumulated components by 32,768. KeyCode/Vector describe digital contributions,
Axis/Deadzone describe sticks, and motion uses Scale and its two native axes.
GUI-consumed motion never reaches gameplay.

`Value`/`GetValue()` return current level state or the frame's relative sample.
`GetPhysicsValue()` returns the native physics-tick sample. Reads never consume
data. Frame and physics accumulators rotate independently at their native fences.
InputService runs at frame/physics priority -100, before existing RunService
callbacks at 0. Use Stepped for movement and RenderStepped for look. Idle relative
samples become zero at the next fence. Any graph configuration change discards
pending relative deltas, including changes to an unrelated definition. Authoring
ValueType changes immediately, while projected value and kind commit together at
the next safe evaluation. Unpublished actions use their configured neutral type.

Modifiers are a unique array of up to four left/right Shift/Control/Alt/Meta
codes. A chord admits on a fresh primary press after its modifiers, never by
pressing a modifier after an already-held primary. ExactModifiers rejects extra
held modifiers. Focus loss, scene pause, GUI consumption, definition/owner retirement and
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

Retained raw methods/signals resolve ObjectIDs and adapter destruction releases
subscriptions. Canonical adapter replacement cancels old admission before restart.
Direct Server access via `game.UserInputService` now enforces GetService's Client
boundary; old bypass callers must migrate. Raw argument shapes, polling values
(including GetMouseDelta's legacy Vector3) and gamepad numeric conventions remain.

## Independent motor

`Instance.new("KinematicMotor3D", game.Workspace)` creates a local Godot
CharacterBody3D with one private capsule. Scene-authored bodies are inert and
noncolliding until adopted by a Client command. Bodies retire with their creator
or adopting script/module owner. Ownership is a lifetime lease in the shared
Client domain, not per-script security isolation. Commands never target
Player.Character, arbitrary bodies or another peer's state.

| Motor surface | Contract |
| --- | --- |
| `SetMoveVelocity(Vector3)` | Finite horizontal velocity, Y=0, length <=100; latest command consumed for one physics tick, then neutral |
| `Jump(Speed?)` | Grounded only; default 5, finite (0,50], revalidated at tick |
| `Teleport(Vector3)` | Coordinates within +/-100,000; physics-tick application with velocity reset |
| `Position`, `Velocity`, `Grounded`, `FloorNormal` | Read-only last-solver observations; airborne floor normal is zero |
| `AcquireCamera()`, `ReleaseCamera()` | One motor camera lease per viewport; restore the prior ObjectID only while still owning current camera |
| `SetViewAngles(Yaw, Pitch)` | Finite radians; yaw wraps, magnitude <=1,000,000; pitch +/-1.45 |
| `CaptureMouse(Bool)` | Requires current camera lease; focus loss/pause/retirement release capture |
| `Yaw`, `Pitch`, `CameraActive`, `PhysicsTicks` | Read-only diagnostics |

Commands return false on rejection; wrong types, retired views and Server
execution raise Luau errors. Transform/velocity observations are read-only. The
fixed capsule has radius 0.35, height 1.8, collision layer/mask 1, gravity 24,
terminal fall speed 100 and floor snap 0.2, in Godot units. Use a unit-scale
parent. Motor priority 100 consumes commands after established Stepped callbacks;
there is no second fixed-step scheduler. Internal collider/camera children do not
become public handles or copied active clone state. Local input/motor subtrees
are excluded from static network identities, generic replication and remote
reference visibility; the wire format is unchanged.

Legacy camera/input APIs remain available and can change the active camera or
global mouse mode. Motor arbitration covers motor leases and preserves a newer
active camera on release; it does not redesign legacy surfaces. This is not a
camera collision solver or networked Character controller. The
[runnable Luau example](../examples/input-controller/README.md) demonstrates
movement, sprint/jump, camera-relative steering, look, native GUI, remapping and
teardown/restart entirely through semantic input and the narrow motor commands.
