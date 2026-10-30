# ADR-007: Model-based Character ownership

Status: selected design under implementation on `runtime/character-v2-model`.
The measured parent and preparation CI are verified; candidate production
behavior is not qualified yet. See the [work record](character-v2-development.md).

## Preparation and ancestry

The branch starts at qualified GL-007 tip
`514d12f1bf1add924214492248a459e0763d4ca0`, preserving source `3bb641a` and its
[qualification evidence](character-authority-validation.md). Main remains
`4ea5311`. Neither development branch is authorized for merge, release publication
or updater distribution. GL-003/004/005/009/020/022 contracts remain in force.

The source baseline is explicit: `RBXModel` is a Node3D in `rbx_instances.h`;
`RobloxPlayer` is a CharacterBody3D containing camera/input behavior; `Humanoid`
is a separate Node with health, movement and animation signal state. Its active
movement constants are walking 16, sprint multiplier 1.5, jump velocity 20,
gravity 45, floor/air acceleration 110/45 and turn rate 11. Remote characters
currently use an AnimatableBody3D plus a real separate Humanoid.

## Selected composition

`RBXCharacter : RBXModel` is the actual public object in Player.Character, for
local players, remote players and NPCs. ClassName is Character, and native
inheritance supplies Model identity. PlayerObject remains the separate player.
No separate 3D Humanoid object or renamed compatibility shim is planned.

The Character owns health, configuration, observed state, lifecycle and the rig.
One internal CharacterBody3D component handles collision/movement. Camera/input
remain components of that body for the local owner; NPCs and remote presentation
do not acquire another active local camera or keyboard controller.

The body is top-level in Godot transform space. During local/NPC physics its
world pose drives the Character's world pose; an explicit Character transform
change instead synchronizes the body before further movement. A guarded update
prevents parent/child feedback or double application. Remote presentation uses
the same Character identity, with autonomous physics/input disabled and the
admitted server pose driving its body and visuals. There is still one body.

HumanoidRootPart remains a direct child and transform proxy for the Character
root. It is neither health state nor a second body. Model PivotTo/MoveTo and
teleports must move physics and presentation together. Parent rotation/scaling,
reparenting, nonfinite transforms and destruction require native regressions.
Unsupported transform cases must be rejected explicitly rather than silently
desynchronizing the capsule and rig.

## Gameplay and presentation ownership

Character health/damage/death preserve GL-007 native Server authority and
exactly-once death per life. Movement configuration remains distinct from
physics-observed idle/running/jumping/falling/landed state. Movement requests
cannot directly claim grounded state or authoritative health.

The mechanical controller migration preserves the measured movement algorithm;
any algorithm correction must have separate evidence. Legacy stored-only
JumpHeight/HipHeight, neck/joint and unsupported swimming/climbing flags must be
classified in the public API migration table instead of being advertised as
implemented physics.

An actual Animator owns playback/track operations in the Character hierarchy;
tracks no longer depend on Humanoid ancestry. Native ObjectIDs, GL-020's current
session/life guards, checked assets and existing replication mechanism remain.
Trusted gameplay timelines retain the GL-007 protection from client presentation.
Default R6, StarterCharacter and the currently supported custom-rig path remain
separate from animation-importer expansion.

## Compatibility and qualification

This is intentionally a breaking 3D API/scene change. Scripts must use Character
properties/signals and explicit Character ancestry, not a Humanoid child search.
Existing project scenes/content will not be rewritten automatically. The final
API table must distinguish active behavior, removed stubs and unsupported states.
2D characters keep their existing separate controller and Humanoid2D contract.

GL-007's field authority, freshness, rejection and lifecycle guarantees are
requirements for the new root. Any necessary wire change requires an explicit
version gate, exact payload documentation and safe incompatible-peer rejection;
an internal class rename alone does not justify a second replication system.

### Selected wire contract: character protocol 3

The Character root now supports server-authored orientation/uniform scale and
movement acceleration/rotation settings. Protocol 2 carried only position/yaw
and walk/jump/gravity and cannot express that contract. Protocol 3 retains the
existing relay/session/epoch mechanism and client prediction input shape.
Readiness requires version 3; version 2 cannot create an admitted writer life.

`_character_grant` retains its eight fields and appends `contract: Dictionary`.
`_recv_character` retains its eleven fields and appends that same dictionary.
For 3D, its exact keys are `Version=3`, `Pose: Transform3D`,
`WalkSpeed: float`, `JumpPower: float`, `Gravity: float`,
`Acceleration: float`, `AirAcceleration: float`, `TurnSpeed: float`, and
`AutoRotate: bool`. Numeric movement configuration is finite in `[0, 1000000]`.
The finite positive uniform Pose must agree with the separate position/yaw
fields; grant walk/jump/gravity must also agree with that dictionary.
For 2D the exact dictionary is `{Version=3}`; the existing
2D controller configuration and plane bounds are unchanged. Missing/malformed
contracts fail before state, cache, health or presentation mutation. Historical
fields are not reinterpreted. Full mixed-build gameplay is unsupported.

An owner client still submits only epoch/sequence/position/yaw/speed/airborne.
It cannot supply health, scale, pitch/roll or movement configuration. Trusted
server root/configuration changes issue a correction epoch and a complete grant.
Observers use the admitted full pose for presentation; the internal body follows
that same root. GL-007's bounded movement and airborne-rise admission remain.

The native reset UI uses `_character_reset(epoch)`: the server checks the live
transport owner, current epoch, live Character and a one-second request bound,
then applies death through the same server health API. It cannot select another
player, supply health or reset a replacement life through a stale request.
Single-player/host reset is similarly bounded and resolves the local ObjectID
again before applying. Arbitrary Client health writes remain forbidden.

Explicit server removal sends reliable `_character_removed(who, epoch, life)`.
The receiver admits only its live server/session and non-stale epoch/life, records
a tombstone before deferring lifecycle callbacks, and rejects same/older-life
pose and animation packets. A newer trusted LoadCharacter can create the next
life. Life zero is reserved for an admitted Player with no initial Character:
version-3 readiness admits that Player after the transport poll even when
CharacterAutoLoads is false, and the reliable absence record suppresses stale
presentation. A later Server LoadCharacter grants a positive new life. Local
readiness does not require a pre-existing Character. Dedicated/editor observer
windows remain excluded as local Players. The connected Player survives the
absence of its Character. Same-tree
reparenting preserves Character identity and does not send a removal.

Before production edits, capture a comparable native creation/respawn/object/
memory baseline. Qualification then requires full core regressions, focused real
Model/physics/lifecycle/rig/network fixtures, Windows/Linux Debug/Release,
Windows/Linux core ASan and matching Linux full-native ASan/LSan. GL-018's Windows
full-native limitation remains. Headless results do not establish graphical
camera/animation correctness; any graphical gap must be recorded separately.
