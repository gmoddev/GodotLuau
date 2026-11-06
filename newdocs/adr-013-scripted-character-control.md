# ADR-013: Optional script-owned Character movement intent

- Status: Accepted; qualified within the profiles and limitations in the
  [qualification receipt](evidence/player-controller-qualification-2026-11-06.json)
- Date: 2026-11-06
- Depends on: [ADR-006](adr-006-character-authority.md),
  [ADR-007](adr-007-model-character.md), [ADR-012](adr-012-input-actions.md)

## Context

The qualified Input foundation supplies semantic actions and an independent local
motor. Existing Player.Character remains a Model with a single native physics
body and native hardware controller. A Luau game should be able to author that
Character's controller without replacing its body or gaining network authority.

LocalControl also identifies the legitimate local Character for camera/network
ownership. Turning it off would change more than input selection. Legacy Move
is a continuous local/NPC request and is not a script-lifetime-owned frame command.

## Decision

Character.ControllerMode is a local, nonserialized Native (0) / Scripted (1)
selection. Native is the constructor default, including new lives and clones.
It is not replicated gameplay configuration. Only live Client execution bound
to the actual native local Player.Character may select Scripted.

Selecting Scripted takes a fresh private 64-bit generation and an existing
owner-aware GLReference. The lease binds existing Player/Character ObjectIDs,
NetworkService mode and current MultiplayerPeer ObjectID. It does not create
another session registry or authoritative generation. Exhaustion fails closed.
An older lease's method closures cannot command the replacement generation, and
a different execution owner cannot use them. Deliberate fresh Scripted selection
is controller replacement; an old owner cannot switch an active replacement to
Native. No raw native handle or lua_State lifetime is exposed to scripts.

Scripted mode gates native hardware movement/look polling. LocalControl, body
identity, state/health/lifecycle, Animator, collision and replication stay intact.
Move supplies finite horizontal direction of length at most one, camera-relative
option and sprint flag. Latest intent is consumed once per physics tick after
existing RunService.Stepped callbacks; absence is neutral. Analog magnitude is
retained in Scripted mode. Jump is queued and rechecks the native grounded state.
The same existing speed, acceleration, gravity, jump impulse and move_and_slide
implementation runs. Camera rotation/capture use the existing local camera and
bounded owner-scoped commands.

The controller is retired on owner death, Character departure/death or native
connection replacement. Retirement clears intent and owned capture but leaves
dormant Scripted selection, preventing held hardware from taking over. An
explicit Native selection or a fresh Scripted lease restores control. New
Character lives start Native; the example opts in again on CharacterAdded.

Focus loss, scene pause, text focus and native menu/free-camera suspension deny
commands. The example disables its InputService gameplay context during these
transitions and requires fresh admission after re-enabling. This handles text
focus acquired while a key was already held without adding a second evaluator.

## Authority, compatibility and limits

The protocol, transport, dependency pins, shared domains and native movement
admission are unchanged. A controller supplies local predicted movement intent;
server-owned speed/health/configuration and GL-007 pose bounds still apply.
Other Players, presentation puppets, unbound clones and Server scripts cannot
acquire the controller. Generic legacy movement APIs cannot compete with an
active Scripted mode. Native games retain their previous behavior.

Native Move remains continuous with its existing return behavior. Scripted Move
returns admission success and lasts one physics tick; scripts must resubmit from
Stepped. Existing games need no migration unless opting into the new mode.
The independent KinematicMotor3D remains a separate local body; this decision
does not instantiate it for Character control.

The supplied example owns its contexts and disconnects them when superseded.
It supports keyboard/gamepad actions, mouse/gamepad look, jumping/sprinting,
remapping, menu consumption and explicit Native switching. Synthetic replay does
not establish physical-device or OS mouse-capture qualification. Real ENet and
matching sanitizer evidence will be recorded in the
[development journal](player-controller-development.md).
