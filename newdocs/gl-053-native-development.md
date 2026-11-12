# GL-053 native API expansion campaign

Baseline: `16e8597cb342a1bbc888f190680c678ecf9ba055`, fetched and verified on
2026-11-12. Branch: `feature/gl-053-native-api-expansion`. No main merge or
release/updater distribution is authorized.

The owner uses GL-053 for this comprehensive campaign. The issue ledger already
uses GL-053 for the resolved default damage example. Preserve that stable issue
and all its evidence. This campaign uses a distinct native-API slug; new defects
receive new issue IDs instead of repurposing the resolved finding. GL-050 stays
separate and unresolved.

## Acceptance and sequence

Expand ordinary Luau-first development through the existing policy/runtime/type/
editor architecture. Preserve exact live scope ownership, immutable loaded
resources, domain/capability boundaries, native graph/physics authority, lifetime
retirement, Native default and Scripted opt-in. Do not introduce arbitrary
reflection, global engine/OS authority, a second graph, VM or scheduler.

1. Inventory actual pinned metadata and current policy, with reproducible status
   classifications and before/after evidence.
2. Expand shared conversions, approved defaults and observation properties, then
   useful 2D/UI/resource families through that machinery.
3. Add gameplay/rendering/animation functionality with effect-specific ownership
   checks where plain reflection would be unsafe.
4. Improve reusable scene/assets and editor completion/navigation/iteration.
5. Exercise representative Luau-only 2D, 3D and UI projects, native editor restart,
   export and independent startup. Keep Relay Siege as a separate regression.
6. Qualify coherent phases on Windows/Linux and supported sanitizer/graphical
   profiles. Reuse existing evidence only within unchanged inputs.

This is an implementation campaign. Inventory counts do not establish runtime
qualification or broad parity. Continue beyond the first API expansion phase.
Keep unsupported, intentionally restricted, blocked and deferred work explicit.

## Baseline audit

GL-049/051/052 already provide owned native nodes/resources, inheritance-aware
descriptors, methods/defaults, constants, generated declarations, project modules,
restricted editor preview, independent snapshots and native diagnostics.
The current policy has 48 constructible classes, 118 properties, 27 methods and
12 signals. The pinned metadata is Godot 4.3: 920 classes, 14,379 declared methods,
3,676 properties, 447 signals, 647 enums and 155 class constants. Existing admitted
runtime/editor hosts are 4.7.1; newer-only APIs are not inferred from that version.

Concrete expansion barriers: nine scalar/value/resource kinds, only numeric/bool
optional defaults, a four-argument call ceiling, and getter/setter-only property
descriptors. These constrain common 2D, UI, animation and resource APIs. Preserve
the existing generalized dispatcher rather than adding repetitive wrappers.

Extend the existing generator to emit NativeCoverage.json from the same policy,
catalog and pinned metadata. It lists declared member classifications, inheritance,
construction/loading, generated handles, authority/editor scope and Variant forms.
It is an inventory, not permission or runtime availability proof. Full declared
metadata is visible; only reviewed policy entries execute. Legacy Roblox facades
remain a separate surface.

DockerPC's host-local worker slot is actively held by StudioCreatorFoundation3,
generation 111. Do not acquire, bypass or interrupt it. Use existing hosted CI
for sustained builds while continuing independent local source/generation work.
Local submodule checkout uses the unchanged pins solely for metadata and analysis.
No local sustained build or LinuxBox workload is started.

Phase A emits the complete declared metadata inventory (1,163,950 bytes), with
constructibility separated from whole-class parity. Generator drift checking and
ten policy/inventory tests pass. Original runtime descriptors, declarations and
catalog remain unchanged. Preserve the before counts and exact coverage hash in
the [baseline receipt](evidence/gl053-native/baseline.json). This qualifies the
inventory/generation change only; proceed to production implementation.

## Phase B implementation in progress

The reviewed policy now has 84 constructible classes, 261 property entries,
101 methods and 28 signals. New families cover native 2D bodies/areas/shapes,
timers, sprite animation, UI lists/text/layout, gradient resources, ShaderMaterial
and MultiMesh. A shared bounded pure-value converter handles compound math,
collections and packed arrays. Existing Vector3/Color3 public forms are preserved.
See the [public contract](gl-053-native-api.md) for exact limits and restrictions.

The generalized dispatcher now supports approved optional string/null/Vector2
defaults, scoped Node payloads, observation properties, metadata-checked live
collection validation and most-derived descriptor resolution. MultiMesh allocation
and shader uniforms have effect-specific preflight. Preview cannot start temporal
playback or bypass that restriction through autoplay/autostart properties.

Thirteen generator/policy tests and generated drift checks pass locally. New
production native integration cases cover value roundtrips and rejection,
collections/defaults, 2D overlaps, animation/timer completion, shader parameters,
MultiMesh, foreign-owner calls and cancellation at owner retirement. Added Luau
typechecker cases exercise new APIs and rejection. These runtime/type cases are
not yet qualified; hosted C++ build and Windows/Linux execution are the next gate.
No main, release, updater, dependency or admitted-host change is included.

Phase B source `ba4b400bc27e43fa17b39d7f9f79ca77a497639b` passes hosted
Windows/Linux core run [43215953625](https://github.com/gmoddev/GodotLuau/actions/runs/43215953625).
Native run 43215953985 is still building. Type run
[43215953650](https://github.com/gmoddev/GodotLuau/actions/runs/43215953650)
compiled and loaded all generated definitions on both platforms, then correctly
failed the new read-only-constructor rejection. Luau width subtyping accepts
extra fields when an observation field is merely omitted. Emit explicit nil
fields for those constructor/Configure entries so numeric writes cannot be
accepted as harmless extra data. Preserve this failed attempt; rerun the type
workflow for the corrected declarations. This changes declarations only.

## Selective dependency reload implementation

GL-054 records a source-verified stale-parent-cache discrepancy. Add import edges
to existing module records, including ready-cache imports, without a new module
system or scheduler. Up to 256 distinct dependencies per module are admitted.
Build reverse edges only during invalidation; ordinary cached require remains
constant-time without source rereads. Source changes invalidate the resource
identity before emitting changed. Invalidation detaches the whole dependent
closure before cancellation hooks can re-enter, then releases results and retires
owners/tasks/subscriptions. Existing pending waiters receive invalidation errors.
Other domain caches and unrelated modules remain separate.

Existing consumer variables remain ordinary Luau snapshots; there is no automatic
state migration or rollback to stale executable generations after compile failure.
Call require again to obtain a fresh module, or rebuild the entrypoint. Modules
required while executing returned functions belong to the current execution owner;
dependency edges describe module-owned imports, not arbitrary closure provenance.
Editor preview continues explicit whole-preview rebuild/retirement under ADR-016.

Two core regressions and a production native fixture exercise a three-module
chain, ten resource revisions, unchanged unrelated caches, pending initialization
and cancellation of callbacks from old parent generations. Qualification pending.

## Gameplay and editor implementation in progress

The policy now selects 90 constructible classes, 301 property entries, 150
methods and 32 signals. Added native raycasts, standalone 2D/3D character bodies,
navigation regions/agents and procedural Skeleton3D poses. Gameplay effects
enforce runtime physics phase, synchronized navigation maps, scoped collider
projection and bounded valid bone hierarchies/rotations. New native fixtures use
actual Godot collisions, navigation meshes and skeleton state, not replacements.
These are implemented but not yet runtime-qualified.

Existing editor analysis now supplies enum/value completion, metadata signatures
and call hints, immutable-observation diagnostics and returned-handle inference.
New actual production inspection cases exercise those paths. The preview now
allocates its own World2D; its existing own World3D remains. Full breakpoints and
arbitrary language-server behavior are not inferred from source locations/hints.
Further scene/asset, animation, templates and acceptance project work remains.

Reload commit `e92084d` executes all 71 ordinary core cases successfully on both
platforms, including both new dependency regressions. Run 43216999459 then fails
the launcher because it still requires the former exact 69-case marker. Correct
the existing launcher, report, sanitizer/candidate receipts and receipt tests to
require 71 ordinary plus the unchanged 16 isolated limit cases (87 total). This
raises the acceptance count; no assertions, watchdogs or cases are removed.

At `4b1cd19`, fresh Windows/Linux core run
[43218255774](https://github.com/gmoddev/GodotLuau/actions/runs/43218255774)
passes all 87 cases, and type run
[43218255569](https://github.com/gmoddev/GodotLuau/actions/runs/43218255569)
passes the generated definitions, representative calls and RelayFactory.
Original native run 43215953985 fails compilation: commas in the new Scene.Value
lambda's aggregate initializer split the lua_pushcfunction macro arguments.
Parenthesize the lambda expression. Stop superseded native runs 43216999492 and
43218255451, which contain the identical known-broken macro, rather than finishing
redundant builds. Preserve those failed/cancelled attempts; no runtime pass is
claimed from them.

## Native animation implementation in progress

Add bounded native Animation/AnimationLibrary/AnimationPlayer value-track
construction under [ADR-017](adr-017-owned-native-animation.md). Whole-library
preflight checks owned relative targets, actual property descriptors and every
key before attachment. Sealing prevents later mutable aliases from changing an
autonomous player's admitted effects. NodePath pure values and typed-array
observations support this workflow without exposing native Object/RID/Callable
collections. New real 2D/3D playback fixtures check final native transforms,
unsafe path/type/time rejection, sealed aliases and yielded completion retirement.
The runtime correction and new animation work await fresh hosted qualification.

## Scene composition implementation in progress

An official headless Godot 4.7.1 probe at
`gl053-native-20261112/scene-probe` observes SceneState for plain, nested and
inherited scenes: nested/inherited roots carry PackedScene references and empty
type names; overrides name existing inherited paths. This is engine API evidence,
not qualification of the new extension behavior.

Expand preflight to resolve those native references recursively before node
construction, with shared resource/value limits and a bounded transient path/type
map. Validate every base and override; reject scripts, stored signals/groups,
placeholders and escaping/unknown identities before instantiation. Preserve native
serialization, resource sharing, independent snapshot behavior and actual subtree
adoption. Existing binding fixtures now exercise positive nested/inherited scenes
and recursively reject a nested scripted scene before its initializer can run.
Node2D radian rotation receives its existing degree-bound serialization adapter.

Animation commit `cb35958` passes fresh Windows/Linux 87-case core run 43219735951
and generated type run 43219735683. Native run 43219735745 is still building.

## Editor navigation implementation

Extend the actual lookup hook with existing Luau AST local identities and static
project imports. Resolve require aliases and exported returned-table functions,
preserve lexical shadowing and return bounded source-local reference locations.
No code evaluation, second analyzer, unrestricted filesystem walk or package
manager is introduced. Add production-hook fixture cases for module exports,
shadowed references and denied user:// navigation. Full project-wide semantic
indexing/find-references and breakpoint stepping remain explicit limitations;
existing bounded stack/error/domain diagnostics are retained.

## Native starter templates in progress

Reuse the existing canonical .luau template generator for Empty, unchanged 3D,
2D physics/input and native UI sources. Add a selector to the existing native
new-scene action, with the old one-argument/default-3D API preserved. No second
scene format, package manager or updater is added. The generator's --check joins
the existing generation gates; default-damage template contents remain unchanged.

GL-055 records the UI starter's source-verified preset/offset ordering discrepancy.
Apply presets before explicit properties and preserve validation of the entire
batch first. New native fixture cases execute all four actual template sources,
2D physics and live UI signals, then retire owners. Existing editor workflow
coverage adds profile creation/static preview and rejection before file writes.
These changes await hosted runtime/editor execution and graphical qualification.

## First native runtime results and corrections

Linux `cb35958` compiles the complete extension and reaches actual execution in
run 43219735745. Value/collection cases run through the MultiMesh observation;
native animation and ten project reload revisions pass. The new physics fixture
reveals CharacterBody2D was selected through member metadata but omitted from
constructible class policy. Admit that intended owned class and add it to the
generated type probe. This is a campaign implementation omission, now corrected;
the total becomes 94 constructible classes.

The failing MultiMesh roundtrip is a renderer-profile limitation. A direct
unmodified official Godot 4.7.1 headless control, without GodotLuau, writes origin
(2,3,4)/RGBA then reads (0,0,0)/(0,0,0,1). Retain the control logs under
`gl053-native-20261112/scene-probe/renderer-control.*.log`. Do not emulate GPU state
in another object graph. Keep the exact transform/color and shader assertions
in a renderer-required execution of the same fixture, via
RenderedNativeExpansion.gd and the existing Integration runner. Headless tests
retain conversion, bounds, ownership and lifecycle checks; they do not qualify
renderer-backed state. The rendered run remains required and pending.

The fontconfig diagnostic is already present in the retained successful main
Linux integration log, before this campaign. It is the existing admitted host's
system-font limitation, not a new product regression. Preserve it visibly.

## Production-representative project implementation

Add [native foundation projects](../examples/native-foundation/README.md): a 2D
pickup/platform game with real Area events, sprite animation, physics/input, audio
and round reconstruction; a 3D game with body/camera movement, animation, navigation,
instancing and project shaders; and a themed native UI with icons, text editing,
lists, tabs and responsive layout. Shared factories receive caller scopes and
cache no scene capabilities. Assets are original native resources and shader text.

Reuse the existing explicit project stager and export runner with profile choices;
OrbRun stays the default, and Relay Siege remains a separate regression. New
headless integration runs the actual shipped 2D source through keyboard movement,
three physical Area pickups and a round transition; it exercises live UI controls
and 3D construction. Renderer gameplay/export remain separate pending evidence.
Bootstrap-to-ready timings/object counts are measurements, not claimed speedups.
Extend existing candidate harness hashes to include the newly consumed sources.
The actual pinned Luau frontend now resolves project imports in its production
factory probe, instead of treating imported helpers as unknown/dynamic types.

## Rendered control and declaration follow-up

The Windows renderer-required expansion fixture passes all transform/color,
declared shader, conversion, native 2D overlap/impulse and owner-retirement checks
with `cb35958`'s retained Debug adapter on the verified official 4.7.1 editor host,
OpenGL/AMD RX 7900 XT, exiting zero. Logs are under
`gl053-native-20261112/rendered-cb-control-3/official-expansion.*.log`.
This is selected API component evidence, not current whole-campaign or visual
acceptance. The fixture first needed the existing explicit extension-load step
and the same two-physics-frame initialization barrier used by GL-049's impulse
test. Failed attempts remain in rendered-cb-control and rendered-cb-control-2.

The Debug adapter paired with the Release renderer template passes the assertions
but exits with 0xC0000374. Minimal module-load-only and scope controls reproduce
that status with both the campaign adapter and the retained GL-052 `60913fb`
adapter. The native renderer-only control exits zero. The official editor host
module-only and full expansion controls both exit zero. This is a retained
mixed-profile limitation, not evidence that this campaign introduced a heap bug;
do not extend the GL-018 claim or qualify production Release from that pairing.

Factory type run 43224970473 catches an owned SpriteFrames constructor-property
compatibility failure. An initial declaration-order hypothesis led to the f2bb5e7
trial. Run 43227301184 disproves that hypothesis: reordering does not resolve the
assignment. Revert that unnecessary ordering change. Property input types should
explicitly admit their approved owned resource classes alongside the immutable
base handle; getter types and mutating-call receiver restrictions remain unchanged.
Add owned/base and constructor assignment cases and rerun without casts. The 3D
factory and all previous type cases passed the initial attempt.

Native compilation of the later navigation revision catches a const-reference
mismatch: GLProjectResourcePath intentionally normalizes its String argument.
ModulePath must accept the mutable local Imported path, then use that validated
canonical path for the bounded file read. Correct the signature, without changing
path authority. Stop superseded native runs containing this identical compile
failure; new core/type jobs continue independently.

Final API review adds the missing live/final-count constraint for MultiMesh
VisibleInstanceCount and applies it after allocation in a constructor batch.
Rejecting a larger count must preserve the prior native state. Bound sprite
custom playback speed explicitly to [-16,16], alongside existing speed/frame
limits. These are bounded effect checks on the newly admitted APIs, not a new
resource policy or scheduler. Native runtime verification remains pending.

## Binding measurements and bounded metadata indexing

Compare retained Windows Debug adapters `60913fb` and `cb35958` on the same
official 4.7.1 headless host, with an identical fixture and seven trials (first
excluded as warmup). Median 10,000 Position set/read pairs: baseline 42.873 ms,
candidate 76.257 ms. Median 64-node construction: 0.714 ms versus 0.707 ms.
New Transform3D conversion costs 11.411 ms for 2,000 roundtrips; no baseline API
exists for that conversion. Raw samples, binary hashes and fixture identity are
retained in `gl053-native-20261112/binding-measurements.json`.

The measured dispatch increase justifies replacing repeated policy-wide member
scans with a policy-sized immutable class/member index. It stores descriptors
only, resolves inherited members most-derived first, and retains the existing
checked fallback for native resource subclasses absent from the selected class
list. Native object pointers, owner/domain checks, ObjectDB resolution and caller
query strings are not cached. This is not a second object registry or new
capability. Reuse the same measurement after a fresh compiled adapter; no speedup
is claimed before that result. Existing native lifecycle/authority fixtures remain
the regression gate.

## Fresh native execution: host capability and fixture corrections

Run 43227602615's Linux adapter compiles and passes native expansion, reload,
animation and the existing bindings. The Integration actor times out after a
new fixture parse error: a loop's Variant profile does not support inferred
String concatenation. Give both template/foundation markers explicit String
types. The same run records a navigation-path timeout. The admitted GL-018/029
headless host explicitly disables modules by default and does not enable the
navigation module; its dummy server never synchronizes. Keep that admitted
profile unchanged. The unsupported-host case must reject navigation without
mutation; run the same native physics/navigation cases separately on the
already provisioned verified official host, where actual pathfinding is required.
This does not extend full-native sanitizer claims to a non-instrumented host.
The official 4.7.1 direct native control produces the expected two-point path;
the bound native path check remains pending the fresh adapter run. Check the
modified GDScript fixtures with the verified official parser before dispatching
further expensive runs; correct the same explicit String issue in the editor's
new template-path loop as well.

The renderer-required acceptance entrypoint reuses the shipped project fixture
and sources. It drives the 3D player's existing input actions through real
viewport key events, requires all three pickups, a following camera, an actually
moving navigation guide, ongoing native animation and a fresh round hierarchy.
It runs on the full-featured official renderer host; the headless 3D fixture
continues to describe its narrower construction scope. Neither substitutes for
interactive visual observations or production exported startup.

The 3D-only development run on retained `cb35958`/official OpenGL host finds a
sample configuration defect: the navigation path is valid, but the guide's
0.8-high body origin cannot reach its first surface waypoint with a 0.25 path
tolerance. Set both path/target tolerances to 1, accounting for that vertical
separation. The unchanged real-input gameplay check then collects all markers,
follows the camera, plays animation, advances the guide by 5.17 units and replaces
the round, exiting zero. Preserve failed/successful development logs under
`gl053-native-20261112/development-3d-cb-*`. This is earlier-adapter component
evidence; the final current adapter and standalone product still require checks.
