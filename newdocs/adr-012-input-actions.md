# ADR-012: Local semantic input and independent native controller primitives

Status: implemented on `feature/input-action-api-foundation`; qualification is
recorded in the [campaign journal](input-action-development.md). Main is unchanged.

## Ownership and API

InputService, InputContext, InputAction and InputBinding are ordinary native
Nodes, exposed as Instances with the existing ObjectID wrapper, ClassDB
properties, parenting and construction. Direct service/context/action/binding
chains are the authoring source. A disposable native GLInputGraph evaluates
them; no second action map, global InputMap edits or network input stream exists.

Client Luau obtains `game:GetService("InputService")`; Server execution cannot
read hardware or invoke its semantic API. Convenience `AddContext(Name, Options)`,
`AddAction(Name, Options)` and `AddBinding(KeyCode, Options)` construct those same
Instances with closed, validated options. Bool, Scalar and Vector2 action types
have neutral false/zero values. Bool sources OR, Scalar sources sum/clamp, and
Vector2 contributions sum with unit-length clamping. Keyboard/mouse/gamepad
buttons, vector composites, analog sticks and relative pointer sources use this
same implemented evaluator.

Context priority descends, with ObjectID ties; within a context binding priority
descends, with ObjectID ties. Matching actions in one context may cofire. A
consuming higher context suppresses lower contexts for the physical source.
Enabling a context, rebinding or losing a modifier never synthesizes a press.
Digital admission requires a fresh nonrepeat primary press; consumed releases
still retire active state. Definition changes invalidate affected admissions;
unmodified definitions retain theirs. Stable identity does not depend on names.

All changed action values commit before callbacks. Signals are `Pressed()`,
`Changed(Value)`, `Canceled(Reason)` and `Released()`; nonphysical termination
adds Canceled before Released. Signal closures resolve ObjectIDs and callbacks
reuse existing GLReference/GLDispatch owner accounting. Lua-created contexts
retire with their creator; project-authored definitions remain scene-owned.
Loaded/cloned authoring configuration never copies device/transient state.

Initial evaluation bounds are 32 contexts, 256 actions, 1,024 bindings, four
modifier keys and 16 gamepad device indices. These are explicit local limits,
not network authority or total-process memory claims. Diagnostics copy bounded
configuration/state without exposing mutable evaluator objects or native handles.

## Godot routing and compatibility

DockerPC's real Godot 4.7.1 headless viewport probe passed: consumed keyboard
press and release both visit `_input` then focused LineEdit `gui_input`, skipping
`_unhandled_input`. An unconsumed key visits `_input` then `_unhandled_input`.
Handled state inside `_input` is false before the Control accepts the event.
This is synthetic-event/native-Control evidence, not physical-device or GPU proof.

The input adapter observes events in UserInputService `_input`, retains bounded
event identity/order, and marks those reaching `_unhandled_input` as unconsumed.
A post-routing deferred commit handles both consumed and unconsumed events in
arrival order. Raw UserInputService events keep their existing argument shapes
and polling APIs, but their callback timing deliberately moves to this same-frame
post-GUI barrier and gameProcessed becomes meaningful. Document this migration;
do not silently promise the inherited pre-GUI timing. Existing native Character
hardware polling and camera behavior are not replaced by semantic contexts.

Focus loss, definition/owner retirement, queue overflow and device removal must
produce neutral state without resurrecting held input. Callback edits affect the
next safe evaluation boundary. Unsupported multi-viewport routing must be
explicit rather than mixing device admission from unrelated viewports.

## Controller boundary

Vector composites, deadzoned sticks and relative pointer input have distinct
documented frame/physics samples. The independent motor uses Godot's
CharacterBody3D for a separately instantiated, locally owned motor with bounded
commands consumed once per native physics tick. It does not expose arbitrary
move_and_slide, raw RIDs or authority over Player.Character/server objects.
A local owner-scoped camera/capture surface arbitrates motor ownership.
The runnable Luau sample computes intent through actions and uses these narrow
primitives. Character V2 and networking/authority remain unchanged.

Implementation uses `KinematicMotor3D`, not a proxy accepting arbitrary native
body handles. A scene-authored motor starts inert/noncolliding; its first Client
command adopts a lifetime guard. Created/adopted motors stop with that owner.
The shared Client execution domain remains the security boundary; creator guards
do not isolate Client scripts from one another. Internal collider/camera children
are recreated, never public handles or copied active state. Motor priority 100
consumes one bounded command after established RunService.Stepped at priority 0;
input's physics fence is -100. No extra scheduler or physics solver is introduced.

Digital/level values are projected normally. Relative mouse actions are separate
from level sources and have independent frame/physics accumulators with
non-consuming reads. All graph configuration changes discard pending relative
motion. Configuration ValueType and projected value/kind commit at separate
authoring/evaluation boundaries; active values retain their projected kind until
the next evaluation. Stick reconstruction keeps both last physical components
across focus/pause cancellation; admission/output clear, not physical history.
Otherwise an update to one axis could falsely establish full neutral state.

Local input definitions, services and motor subtrees are excluded from static
network stamping, generic replication and remote reference visibility. This is
an additive local-type boundary in existing GL-029/031 machinery, not a wire or
authority redesign. Legacy native Character polling remains independent.
Motor leases arbitrate against other motors and restore a previous camera only
while still owning the active one; legacy camera/mouse APIs remain compatible.
Actual physical device and OS mouse-capture coverage must be distinguished from
synthetic viewport replay and real offscreen rendering.
