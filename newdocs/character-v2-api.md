# Character V2 API and migration

Status: implemented, qualified for the documented source/headless scope and
integrated into main through `1c3176c0d9331dc1fa6849b98f8ed8e90e59c110`.
The breaking contract below is unchanged from qualified `d7905dd`. See the
[integration record](character-main-integration.md),
[work record](character-v2-development.md) and [ADR-007](adr-007-model-character.md).

## Identity and ownership

The actual 3D `Player.Character` is an `RBXCharacter : RBXModel : Node3D`.
Its Luau ClassName is `Character`; IsA accepts Character, Model, PVInstance and
Instance. The separate PlayerObject retains Player identity, UserId, account,
GUI and Backpack ownership. A remote player exposes the same Character class.
There is no separate 3D Humanoid or fake Model wrapper.

One internal CharacterBody3D component handles collision and local/NPC movement.
It is top-level in Godot transform space. Physics drives the Character world
pose; explicit root/Model transforms synchronize the body. HumanoidRootPart is
a direct transform proxy with identity local transform, not health or another
physics body. The visual rig and native Animator are separate children. Tracks
belong to that Animator. The existing AnimationPlayer stays under the Character
to preserve qualified rig paths; its active playback lease binds the Character,
Animator, track ObjectID and exact clip.

The physics component is an internal Godot child, omitted from public child
enumeration. Native tools can resolve it through GetPhysicsBody; gameplay scripts
should use Character methods and properties. Destroy the Character to retire
the complete life. Clearing public children removes rig/Animator content without
replacing the Character's native health identity.

## Properties

Server means native Server execution or trusted native engine code. Client
execution cannot write authoritative health or movement configuration, including
in a shared listen-host scene. Invalid/nonfinite numeric setters leave prior
state unchanged. Movement configuration lies in `[0, 1000000]`.

| Property | Type / default | Access and authority | Replication / lifecycle |
| --- | --- | --- | --- |
| Health | number / 100 | Server write; Client read | Server snapshot; zero latches death once per life |
| MaxHealth | number / 100 | Server write; minimum 1 | Snapshot; lowering clamps health and emits HealthChanged |
| IsDead | boolean / false | Read-only | Derived from native health; a dead life cannot be healed back |
| WalkSpeed | number / 16 | Server write | Complete grant and snapshot |
| JumpPower | number / 20 | Server write; upward velocity | Complete grant and snapshot |
| Gravity | number / 45 | Server write | Complete grant and snapshot |
| Acceleration | number / 110 | Server write; ground acceleration | Complete grant and snapshot |
| AirAcceleration | number / 45 | Server write | Complete grant and snapshot |
| TurnSpeed | number / 11 | Server write; exponential turn rate | Complete grant and snapshot |
| AutoRotate | boolean / true | Server write | Complete grant and snapshot |
| MoveDirection | Vector3 / zero | Read-only observed horizontal direction | Actual local/NPC post-slide movement; remote displacement observation |
| Velocity | Vector3 / zero | Read-only | Native local/NPC velocity; inferred remote displacement rate |
| Grounded | boolean / false | Read-only | Local/NPC floor result; remote admitted airborne presentation |
| CameraMode | integer / 1 | Camera presentation setting; inherited Character authority guard applies | Local follow style; not replicated |
| MouseSensitivity | number / 0.0022 | Finite nonnegative camera setting; same guard | Local presentation; not replicated |
| DisplayName | string / empty | Overhead presentation | Local scene presentation; not a new identity protocol |
| NameDisplayDistance | number / 100 | Finite nonnegative presentation setting | Local scene |
| HealthDisplayDistance | number / 100 | Finite nonnegative presentation setting | Local scene |
| PrimaryPart | Node3D / HumanoidRootPart | Model descendant reference | Local Model pivot selection; root/body still move together |
| WorldPivot | CFrame / root pose | Model pivot | World-space Model semantics; client authority guards apply |
| Name, Parent | inherited Instance fields | Genuine native scene hierarchy | Stable ObjectID across supported same-scene reparenting |
| Position, CFrame, Rotation, Scale | inherited Node3D fields | Explicit root transform; existing native authority guards | Protocol 3 carries server world pose; clients cannot propose scale/pitch/roll |

Remote observed movement is presentation derived from admitted inputs and server
snapshots. It is not independently simulated server collision truth. GL-007's
finite/rate/epoch/sequence/movement/rise bounds remain in force. Character
attributes are Server-owned in Luau; arbitrary project attributes do not acquire
an automatic distributed schema through this migration.

## Methods and signals

| Method | Behavior |
| --- | --- |
| TakeDamage(amount), Heal(amount) | Finite nonnegative Server health changes; healing cannot revive a dead life |
| GetState() | Observed CharacterStateType: Idle 0, Running 1, Jumping 2, Landed 3, Dead 7, Freefall 8 |
| ChangeState(state) | Return boolean admission for supported movement/death actions; never directly claim arbitrary grounded/flight state |
| Move(direction, relativeToCamera?) | Continuous local/NPC movement request; a zero direction stops the scripted request |
| Jump() | Return boolean admission for a grounded jump; observed state changes through physics |
| WalkToPoint(position) | Bounded horizontal target attempt, within 0.25 units, at most eight seconds; no pathfinding |
| WalkToPart(part) | Same target attempt with a validated ObjectID; departure cancels it |
| StopNPCMovement() | Cancel scripted movement; does not disable ordinary local input |
| GetPivot(), PivotTo(CFrame), MoveTo(Vector3) | Inherited Model world positioning; MoveTo teleports the complete Character |
| GetBoundingBox(), GetExtentsSize() | Bounds include transformed native Parts and mesh geometry; Lua bounding box returns CFrame and size |
| LoadAnimation(animation) | Convenience delegation to the actual Animator; existing native asset and gameplay-timeline admission remains |
| Animator:LoadAnimation(animation) | Track owned by this Animator/Character; does not create a second replication system |
| Animator:GetPlayingAnimationTracks() | Current playback owner only |
| Destroy() | Retire native identity and its owned components/callbacks |

Signals support actual Connect/Disconnect and lowercase connection aliases.
HealthChanged emits `(newHealth, oldHealth)`; StateChanged emits
`(newState, oldState)`, preserving this engine's existing ordering. Died fires
once per native life. Running carries horizontal speed; Jumping and FreeFalling
retain the existing controller's emission policy: Jumping emits true when a
jump starts, and FreeFalling carries the airborne flag (including ascent).
Use GetState()/StateChanged to distinguish Jumping from Freefall phases.
MoveToFinished carries success/failure for a target
attempt. Player CharacterAdded/Removing/AppearanceLoaded retain their existing
owner-aware signal/wait mechanism.

AnimationTrack Ended is actual natural completion. Stopped carries
`completed: boolean` for explicit stop or completion. Replacing playback retires
the older track's control lease; inactive speed/loop settings cannot alter the
new owner. Destroying an Animator/track cancels its owned playback and releases
callbacks. Retained method/signal views resolve ObjectIDs and cannot reconnect
to freed tracks. Destroyed/disabled executable owners cannot receive completion.
Unsupported KeyframeReached/DidLoop notifications are not advertised as working
callbacks. Direct trusted gameplay AnimationPlayer timelines remain protected
from Client presentation and older-track cleanup.

## Breaking migration

Update gameplay scripts explicitly. Existing user project source/scenes are not
rewritten automatically. This is a 3D API change; 2D retains RobloxPlayer2D and
its separate Humanoid2D component and controller.

```luau
-- ServerScript: use the actual server roster or PlayerAdded argument.
local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Character)
        Character.WalkSpeed = 16
        Character:TakeDamage(10)
        Character.Died:Connect(function()
            print("[Character:Lifecycle] Character died")
        end)
    end)
end)

-- LocalScript: presentation and movement use the owner's actual Character.
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Track = Character.Animator:LoadAnimation(Animation)
Track.Ended:Connect(function()
    print("[Character:Animation] Playback completed")
end)
```

Replace `Character.Humanoid.Health` with `Character.Health`; move damage, healing
and movement configuration to ServerScript. Replace Humanoid discovery in hit
logic with explicit Character identity/ancestry. HumanoidRootPart remains a
direct proxy, so its Parent is the Character. Player remains separate.

Replace separate 3D Humanoid scene nodes with a real Character root and migrate
their active properties. A native Character StarterCharacter is cloned as the
actual root, with one fresh internal body. The existing Node3D visual-template
path and R6 visual flattening remain separate. Custom rigs need their supported
relative animation paths; this task does not add a new rig importer.

Stored-only JumpHeight, HipHeight, AutoJumpEnabled, RigType, neck/joint flags,
EvaluateStateMachine and unsupported swimming/climbing/ragdoll requests are not
functional Character physics. Remove those assumptions rather than using a
renamed Humanoid object. The previous Humanoid MoveTo alias did not navigate;
Character MoveTo now has genuine Model teleport semantics. Use bounded
WalkToPoint/WalkToPart for simple NPC targets.

Engine-owned StarterCharacterScripts use Character state. The existing engine
placement of StarterPlayerScripts under each Character remains; it is not
silently moved into PlayerScripts in this migration. PlayerGui/Backpack remain
Player-owned. Existing user copies of templates require manual updates.

Only finite positive uniform physics transforms are supported, with scale in
`[0.001, 100]` and each world coordinate within `[-10000000, 10000000]`.
Nonuniform, singular, mirrored, sheared or nonfinite transforms are rejected
while preserving the prior synchronized pose. Same-scene parenting affects
local hierarchy; the character protocol carries world pose, not a new general
scene-parent replication format. See ADR-007 for exact protocol-3 fields,
legacy rejection, reset requests and unsupported mixed-build gameplay.

Headless native tests establish only their exercised control/physics/lifetime
facts. Camera/controller math is separate from graphical camera/rig correctness.

The place importer rejects files containing a legacy 3D Humanoid before instance
construction, returning an explicit migration error. It does not rename or
rewrite the source file. Prepare compatible scenes/scripts manually; no automatic
conversion tool is included. The 2D controller remains a separate path.

Rig PhysicsBody3D visual parts are passive: RigidBody3D parts are frozen and all
rig-body collision layers/masks are zero. Gameplay Parts cannot re-enable a
second Character collider. Tool subtrees and Area sensors retain their separate
semantics. Call `RefreshRig()` after native deep hierarchy edits; root child edits
schedule one bounded refresh.

Player.CameraMode remains the existing classic/first-person setting. Character
CameraMode forwards the internal camera's follow style (1=fixed, 2=smooth,
3=combined); those two settings have different meanings.

CharacterAutoLoads=false preserves connected Player identity and PlayerAdded even
before an initial Character exists. Version-3 readiness runs without a local
root; its reliable life-zero absence record also restores the unspawned Player
to late joiners. Server Player:LoadCharacter creates a positive life and delivers
the actual owner/observer roots. PlayerAdded callbacks may request that load;
birth events remain ordered and reentrant loads coalesce. Dedicated/editor
observer windows are excluded as local Players.

Supported Character parent chains must preserve a finite, invertible uniform
world basis. Arbitrary singular/nonuniform scene ancestry is outside the physics
composition contract; the supported parent-transform tests use valid uniform
parents. Direct invalid Character poses are rejected by the qualified setters.
