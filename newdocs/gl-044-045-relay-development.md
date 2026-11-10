# GL-044/045 and Relay Siege API migration

## Baseline and acceptance

Starting main is `eee10f8779a1002c664a81267d9ab96d1dae1e62`. GL-043 is
[integrated normally](gl-043-main-integration.md), reusing the already qualified
source and ten candidate gates. Follow-up branch: `codex/gl-044-045-relay-luau`,
based on main `82d831a59c79c81065c5822751c44c9ecca24d01`.

Acceptance: native Node3D/Camera CFrames have the same shape, basis orientation
and methods as existing stdlib CFrames; Vector3 Dot/Cross/Lerp support colon calls
while preserving bound dot calls and retaining their receiver across collection.
Actual Relay Siege shooting/impulses/occlusion should use those public APIs and
GL-043 filters. Native scene/UI/geometry responsibilities need not become a new
Luau renderer or physics framework. Existing authority and lifetime contracts,
dependencies, admitted hosts, release and updater policy remain unchanged.

## Reproduction

On MainPC (`DESKTOP-B8V8NAN`), regression-only `f002461` runs against the retained
game baseline binary. `CharacterV2.gd --math-baseline` exits 1: colon Dot, Cross,
Lerp, retained temporary methods, native CFrame shape and Camera directions fail.
Legacy dot calls, raw matrix/position snapshots and existing CFrame methods pass.
The Lerp diagnostic explicitly receives userdata where its old argument 2
expects alpha. Logs are retained at
`C:/Sandbox/Codex/GL04404520261109/baseline.*` on MainPC. This is actual native
execution, not a source-only inference. Receiver allocation pressure is normal
production GC, with no new collection hook. It does not by itself establish a
specific sanitizer report.

DockerPC initially had only 300 MB free, requiring MainPC fallback. The owner
then authorized Codex/Gargantuan cleanup. Removing 7,548 disposable compiled
files from the two explicit Gargantuan build roots recovered 34,193,801,216
bytes; free C: became 34,497,626,112 bytes. No source, report, toolchain,
GodotLuau cache or unrelated workload was removed. CarbonLuau's large test root
was a junction to an archive drive and was excluded. The DockerPC deletion
receipt is `C:/Sandbox/Codex/Artifacts/Cleanup-20261109-GodotLuau/summary.json`.

## Focused correction

The Node3D getter reuses existing `PushModelCFrame`, which calls the existing
12-component stdlib constructor already used by Model pivots. Raw numeric matrix
fields and Position remain; LookVector/RightVector/UpVector now exist. Their
coordinate tables remain the established stdlib representation, not newly
introduced native Vector3 userdata. No CFrame math algorithm or transform setter
changes. Values are detached snapshots. This is additive native getter shape
compatibility, not a general Roblox CFrame conformance claim.

Vector3 bound closures retain the actual receiver userdata as a GC upvalue,
replacing raw lightuserdata pointers. One-operand dot calls remain supported;
colon calls require the explicit receiver to match the bound userdata identity.
Lerp similarly supports its two operands or matching receiver plus two operands.
Wrong receivers/arity fail explicitly. Invalid legacy operand behavior remains
zero for Dot, nil for Cross/Lerp (Lerp still validates numeric alpha). No Vector3
layout, numeric precision, arithmetic operation, domain or native owner changes.

The existing CharacterV2 actor adds native regressions, including retained
temporary methods under allocation pressure, same-value self operands, invalid
receivers/alpha, rotated Part and Camera frames, inverse/composition and snapshot
independence. No new actor or parallel qualification framework is introduced.
Qualification is pending; GL-044/045 remain open until execution passes.

## Relay Siege migration

The weapon client reads `Camera.CFrame.LookVector` instead of interpreting native
matrix layout. It explicitly converts the established CFrame coordinate table
to the native Vector3 required by the existing endpoint. Server hitscan uses
colon Dot and builds an Exclude RaycastParams list of current Character roots;
queries retain the 70-unit range and all world occlusion. The list is server
authored and bounded by the existing four-player game limit. It is rebuilt from
live Player.Character identities per shot, covering respawn/replacement without
retained raw body references. Crate impulses use native Vector3.

The cooperative layer-0 hull setting still means players do not block allies;
its retained Godot scene hook is no longer the weapon's filtering mechanism.
Changing it would change game collision behavior, independently of raycasts.
Keep Godot geometry/UI/audio construction and local SoftBody mesh/pin handling:
none has a matching qualified reusable Luau surface in this scope. In particular
do not introduce an unrestricted Godot-call bridge, a pretend PhysicsService
collision implementation, another solver, or a new cloth ownership model merely
to remove a small presentation adapter. Gameplay, authoritative query policy,
input, movement and persistence stay in Luau. No new wire format or authority
grant is required. Actual game replay and native compatibility qualification
remain pending here.
