# Character authority and Character V2 work record

Integration update (2026-10-31): both retained branches are now integrated into
main by normal merges. See the [integration record](character-main-integration.md)
for exact identities and fresh verification. The dated development history below,
including its original authorization boundaries and failed attempts, is preserved.

## Baseline and acceptance

Work starts from local and fetched `origin/main`
`4ea53113a98961a64347c672890f65bf9b5c8a54`. The clean checkout was branched as
`security/gl-007-character-authority`; Character V2 must subsequently stack on
its qualified tip as `runtime/character-v2-model`. Neither branch is authorized
for merge. Release publication and runtime updater distribution stay disabled.
Pinned godot-cpp and Luau revisions are unchanged. Native input fingerprint is
`c88311513a6a91e195a6f37712a19dada19754c02222f26ad02b7ac6048e622c` (87 files).

Stage 1 requires actual transport rejection before mutation/relay, server health
and lifecycle ownership, bounded movement prediction, explicit corrections and
freshness, and valid local/listen/dedicated gameplay on Windows and Linux.
Source traces below are not runtime reproductions. Stage 2 requires real native
Model inheritance, one character root, composed physics, migrated consumers,
and independent qualification. The remaining Stage 2 requirements were supplied
during investigation, including HRP transform consistency, actual physics
composition, migration/API tables, Model/lifecycle/animation/2D regressions,
performance comparison and a separate HttpService compatibility investigation.
Graphical qualification is explicitly separate from headless evidence and
optional when graphical access is unavailable.

## Stage 0: source map at the baseline

| Responsibility | Implemented path and implications |
| --- | --- |
| Local creation | `RobloxWorkspace::build_local_character` in `src/services/roblox_workspace.h` creates `RobloxPlayer : CharacterBody3D`, selects a team/neutral SpawnLocation (fallback `(0,5,0)`), adds capsule collision, rig, Humanoid and cloned starter scripts. |
| Rig ownership | `src/characters/gl_avatar.h` clones StarterPlayer/StarterCharacter before falling back to generated R6 or caller capsule. Generated R6 is flattened into direct character children; custom rigs retain their layout except the remote HRP lift. R6Animator is separately owned. |
| Local movement | `Humanoid::_physics_process` requires a CharacterBody3D parent. It owns acceleration, gravity, jump, state and movement animation inputs. `RobloxPlayer` owns camera, input presentation, touch controls, first person and fading. The capsule supplies physics independently of visible R6 parts. |
| Remote representation | `NetworkService::_make_puppet3d` creates an AnimatableBody3D, not a RobloxPlayer. Its real native Humanoid supplies gameplay API/health but cannot execute CharacterBody3D movement. The network overwrites target position each frame; this is client prediction plus server relay, not server physics simulation. |
| Player identity | `PlayerObject` in `roblox_services.h` is separate from the character and stores its ObjectID. Network peer-to-player maps also use ObjectIDs. PlayerAdded precedes CharacterAdded on initial remote creation; replacing the character is distinct from replacing the Player. |
| Events/lifetime | PlayerObject owns CharacterAdded/Removing/Appearance callbacks and deferred waits. Existing creation paths call user callbacks and then continue using raw pointers; touched paths must revalidate identities after callback dispatch. GL-022 owner guards remain required. |
| Health | `humanoid.h` owns Health/MaxHealth, TakeDamage/Heal, HealthChanged and a permanent death latch. `_apply_puppet_health` currently applies client HP to this real server Humanoid. A 250 ms server health comparison can be defeated by the next client write; CharacterAdded-set HP is also overwritten after callbacks. This establishes a gameplay-health source path, not an economy/progression exploit. |
| Death/respawn | Players polls local Humanoid death and rebuilds locally after RespawnTime. Network LoadCharacter asks the owner to rebuild; ordinary subsequent state does not replace the dead server Humanoid. Workspace fall-kill currently targets local characters. Lifecycle is not server-owned at baseline. |
| Animation | Humanoid supplies movement speed/airborne inputs; R6Animator drives generated rigs. `roblox_animation.h` owns Animation/Track playback. GL-020 validates independent animation RPC role/session, string bounds and finite speed, retains pre-puppet/late-join state and clears it on lifecycle changes. Character state carries separate unvalidated speed/air flags. |
| Transport | `_broadcast_local` sends at about 30 Hz. `_relay_state` replaces submitted identity with server UID but accepts the remaining payload. `_recv_state` uses GL-006 server role/sender checks. There is no character generation, correction epoch, packet sequence or movement-time policy. `_relay_state2d` also lacks semantic validation. |
| Corrections | HRP Position/CFrame in `gl_runtime.h` moves the owning character, but the remote target remains unchanged and `_lerp_puppets` overwrites the correction. A freshness protocol is necessary to distinguish pre-correction traffic. |
| Dimension | Incoming 2D/3D state currently changes one service-wide `is_2d` flag, although existing puppet native types do not change. Admission must bind the world/character dimension before accepting state. |
| Model/identity | `RBXModel : Node3D` in `src/importer/rbx_instances.h` implements pivot, PrimaryPart and bounds. It is not a base of RobloxPlayer or remote AnimatableBody3D. `luau_class_identity.cpp` currently maps RobloxPlayer to Player, although PlayerObject is the actual Player. A string alias cannot supply Model behavior. |
| Luau API consumers | `luau_api.h` implements Humanoid properties, damage, movement, states, signals and animation lookup; `luau_stdlib.h` supplies NPC helpers. `gl_runtime.h` maps HRP transforms/touched targets. Native Part, Workspace, Players, Network, animation and settings consumers use class/name lookups. Import class maps, generated templates, editor declarations and default scripts also reference Humanoid and require explicit migration review. |
| Default scripts | `GodotLuau/DefaultScripts/StarterPlayer/StarterCharacterScripts/Health.luau` is a ServerScript regenerating through Humanoid.Health; Animate.luau looks up Humanoid and is otherwise a template. Server starter scripts currently clone on local construction, not remote server puppet creation. |
| Independent 2D | RobloxPlayer2D owns its own CharacterBody2D movement/camera (200 walk, 300 run, -500 jump, 980 gravity defaults); Humanoid2D supplies separate health. Workspace2D builds it independently. Removing the 3D Humanoid need not remove or alias these types. |

The trust failures above are source-backed defects. Preferring a first-class
Character root and separating movement/camera/rig ownership is an architectural
choice explicitly requested for Stage 2, rather than evidence of a vulnerability.

## Proposed Character V2 contract (not implemented)

`RBXCharacter : RBXModel` is the actual object in Player.Character and owns health,
movement configuration, state and lifecycle. One internally owned CharacterBody3D
supplies collision/velocity; it does not become another public character root.
Rig parts, HRP and animation retain explicit character ownership. Camera/input
remain components, with remote characters omitting local input ownership.
ClassName is Character; native inheritance supplies IsA(Character)/IsA(Model),
Model pivots and bounds. Identity and callback validity use existing ObjectID and
execution-owner contracts. No fake Humanoid child is planned.

Health, MaxHealth, TakeDamage, Heal, WalkSpeed, jump configuration, HipHeight,
AutoRotate, MoveDirection, state/events and NPC movement need an explicit API
migration table. Redundant legacy settings must be classified before removal.
Existing content which looks up Humanoid needs documented source migration;
an optional compatibility layer would require separate approval. Full Roblox
Humanoid compatibility is not a goal. HRP remains a direct transform-compatible
child; it must not become a second physics body or authoritative position source.

## Development checkpoints

The independent read-only pre-patch investigation agrees that NetworkService is
the shared inbound character-state boundary. It additionally identifies server
correction rollback, dead-server-character reuse, dimension switching, and
callback teardown as paths the fix must cover. GL-007 remains open during work.

Controlled baseline actors reproduced on Windows and Linux using the unchanged
main extension: client X=100000 and Health=1 reached the server character, then
a client Health=100 replaced server-applied Health=75. The baseline native body
measured walking 16, sprinting 24, jump velocity 20 and downward velocity
-20.5000019 at 60 physics ticks/second. `CharacterBaseline.gd` records the actual
control and trigger; the archived baseline extensions are SHA256
`b713e143b18896126d04c43c06c88c054c2d92d167f7be433650b62c33169064`
(Windows) and `94ae954ad4b1f2249ebee6bbaf9757c6b4077a8fc7c696c37f665ab58b65787f`
(Linux). Baseline logs are retained through the security artifact store under
`artifacts/baseline/{windows,linux}/`. Client teardown logged the existing
inactive-ENet diagnostic; neither baseline had a sanitizer/crash claim.

The in-progress implementation removes health/identity from protocol 2 client
state, introduces server grants and correction epochs, and denies Client VM
native health mutations. The first Windows candidate passes local, listen and
dedicated two-client authority fixtures. Its 2D observer-health assertion exposed
a missing application in the new snapshot path; that is being repaired before
qualification. An initial fixture attempted immediate free during a Godot signal;
Godot correctly rejected freeing the locked emitter. The fixture now queues
deletion and verifies invalidation after the frame. These are development results,
not final qualification of the branch.

### Animation boundary and subsequent checkpoints

Candidate V8 (`ad9927f12fd8075ebd6684650b40798a63a1e74df90ed99fa85b4852b73f9017`,
Windows extension SHA256
`3a18fc1466cb9cda232107f5a614e856a2e94752b72f04d3c9fdbb72ef4782f9`)
still allowed a client to select a packaged Animation whose property track wrote
`Humanoid:Health`. The actual server moved from Health=75 to Health=1 with no
accepted movement input. This was reproduced, not inferred from a track name.
The fixture and logs are retained at `artifacts/animation-health-probe/` in the
security artifact store.

Track filtering then passed focused Windows/Linux core (73 cases) and character,
network and animation checks. A second controlled probe against V10
(`f0ec9024eb399b3a8433847ded9088dab7488a099516cfd84665fe67f6c2d294`, Windows
extension SHA256
`1cb24045d598e7d3c818ecc84bb3076021782b322479790958786dbd2d942f5a`)
used an Animation resource's attached script initializer, rather than a property
track, and again changed server health to 1 during loading. Evidence is retained
at `artifacts/scripted-animation-probe/`. A post-load check alone is insufficient.

ADR-006 now requires a native server-startup catalog and plain track-data copies.
Network packet handling performs neither arbitrary ResourceLoader loads nor
Roblox-ID filesystem resolution. Scripted resources, gameplay/method/root tracks
and unregistered identities fail admission. The catalog candidate V11 passes
Windows/Linux Debug core and all 33 focused native character/network/animation
actors per platform, including actual native walk/jump/fall. This is still
development evidence, not final branch qualification.

The next candidate additionally bounds animation aliases to one temporary native
library slot (restoring an overwritten scene clip), charges malformed/stale
packets against admission, releases character/player callback references on
destruction, and revalidates touched Player/Players callback continuations.
New checks cover valid-pose floods, repeated animation names, automatic respawn,
retained signal views and real ENet forwarding with 200–270 ms delay in each
direction. Full Release/sanitizer/SCons/hosted qualification and the independent
candidate review remain pending. Character V2 must not begin until GL-007 is fully
qualified; this was reiterated by the user during development.

V12 passed the expanded non-latency character checks on both platforms, but the
delayed ENet case exposed an admission interaction: an expired movement packet
issued a correction grant before its pose was rejected, invalidating the
subsequent legitimate animation epoch. The next candidate separates bounded
explicit synchronization from movement rejection. Its Windows UDP fixture also
disables connection-reset reporting on its own forwarding socket so late replies
to retired actors cannot obscure the underlying test result. V12 is not qualified.

V13 passed Windows/Linux Debug and Release core plus all 82 native actors, and
Windows core ASan. Linux core ASan and the native lifecycle/network/animation
groups passed; the physics movement control failed because the previously
provisioned instrumented engine has dummy 2D/3D physics servers. This is an
engine configuration gap, not movement qualification or a sanitizer finding.
The engine must include actual physics before this required check can pass.

The single independent candidate review reported shared-scene Rotation and
Destroy/ClearAllChildren authority paths, unsafe AnimationTrack settings, exported
resource remaps, named AnimationLibrary paths, and cumulative airborne ascent.
Source inspection confirms those paths. The next candidate covers their shared
boundaries and adds focused regressions. Client asset selection also uses the
startup catalog to prevent resource initializer effects deferred beyond Client
execution. The existing actual property-track and script-initializer packet
reproductions remain the original animation health evidence. No final fixed or
qualified disposition is made yet.

V14 exercised the new remap, named-library, shared-scene, unsafe-track-control and
ascent cases. Client animation assets must be configured at startup on each
endpoint; the GL-020 fixture now supplies that configuration before native
NetworkService creation. V15b passes 73 Debug core cases and all 36 focused native
actors on Windows and Linux, including reconnect/stale-life rejection and actual
CharacterAdded callbacks destroying the character or service. Service departure
still emits the inherited inactive-ENet diagnostic in this bounded fixture; it
is retained and is not labelled a sanitizer result.

The broader V1 matrix passed Windows Debug/Release full native groups, Windows
core ASan and both SCons products. Linux Debug passed; Linux Release exposed a
fixture race between observing a named clip and the next alias message. A barrier
now holds playback until observation completes. The instrumented engine rebuild
also needed the prior `disable_path_overrides=no` option retained for fixtures;
the first physics-enabled engine failed before loading the extension without it.
These development results do not qualify the subsequently revised source.

The current candidate additionally preserves airborne rise through explicit
resynchronization. Actual 2D platformer and sustained top-down controls are being
added: the 3D cumulative-rise rule must not reject a supported 2D movement mode.
The full final-source matrix, production builds and hosted CI remain required.

V16 passes the real 2D platformer/top-down controls (walk 200, jump -500 and
observed falling), the named-library observation barrier and the 3D airborne
resynchronization check on Windows/Linux. V17 also rejects presentation requests
that stop an active server gameplay timeline or replace its inactive named clip.
Temporary-slot cleanup only removes the exact checked clip it owns, preserving
subsequent trusted scene edits. All 36 focused native actors and 73 Debug core
cases pass on both platforms for V17.

The final-input matrix is now running against native source fingerprint
`20ecbfcbb11cbdbef85480c41ec3cd4e1705bba210cb3ab290c84eab518b329a`
(87 LF-normalized files). The cached instrumented Godot 4.7.1 source remains
`a13da4feb8d8aefc283c3763d33a2f170a18d541`; its build explicitly enables native
2D/3D physics, FreeType, TLS, ENet, multiplayer and GDScript, preserves path
overrides, and keeps ASan/LSan enabled. Nothing has been merged or released.

Final-source Windows/Linux Debug and Release each pass all 82 native actor
results and 73 core cases. Windows core ASan passes; both SCons products on both
platforms pass 36 focused character/network/animation actors each, plus process
ownership and DataStore packaging checks. Native source is still `20ecbfc...`.

The first full-native sanitizer run on the physics-enabled engine aborted during
the unchanged GL-022 module-reload error path. Enabling ASan abort-stack capture
showed Luau's exception entering the executable's statically linked C++ unwinder
while the adapter uses the shared runtime. The engine rebuild helper had omitted
the already documented `use_static_cpp=no` setting; restoring it only relinks the
engine (3.2 seconds), without changing the extension. The original abort/report
are retained. The rerun keeps the full regression and ASan/LSan enabled. The
canonical `BuildSanitizedGodot.sh` now also enables native 2D/3D physics and
FreeType while preserving its original shared-C++-runtime/path settings.

The unchanged extension subsequently passes all 82 full-native ASan/LSan actors,
with real physics and leak detection enabled. The final local matrix is complete:
six 73-case core configurations, five 82-actor native configurations, and four
36-actor production products. Transfer/manifest hashes and all 1,017 tracked
dependency files were verified on both workers. See the focused
[qualification record](character-authority-validation.md) for exact identities,
archive digests, commands and limits. Hosted CI remains the final gate before
Character V2 implementation.

## GL-007 final disposition

Source `3bb641a822df288bf48fc6358baec389994b77f0` is published and qualified.
Hosted core run `41032181619` and native run `41032181621` pass on Windows/Linux;
all four downloaded artifact digests, core discovery/73-case reports, native
82-actor summaries, 46 harness hashes per platform and all recorded log hashes
are verified. Native source remains `20ecbfc...`. Packed binary/remap resources
also pass an actual PCK mount/registration check on both platforms, with no
original text resource present.

The documentation attestation following the source commit changes no runtime or
test input. Main is still `4ea5311`; releases and the updater remain disabled.
GL-007's required gate is satisfied. Character V2 has not yet started and must
stack from this retained qualified branch, preserving both commits and evidence.
