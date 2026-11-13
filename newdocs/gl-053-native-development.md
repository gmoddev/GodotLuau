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

Fresh `e2735ec` adapter checks pass actual native navigation, rendered expansion
and all shipped 2D/UI/3D acceptance logic on the verified official Windows host.
The physics-rejection fixture first assumed script initialization occurred outside
a physics frame; a deferred initial script can legitimately start during that
phase. Check rejection in an actual RunService.Heartbeat process callback instead.
Preserve the first failed attempt and the passing rerun under e273-components*.

The same repeated performance fixture shows metadata indexing alone does not
resolve the dispatch regression: median 77.203 ms for 10,000 read/write pairs.
Construction is 0.724 ms/64 nodes and new conversion 11.029 ms/2,000 roundtrips.
Do not claim an improvement. Avoid three unrelated engine class queries on every
property write by selecting effect checks from the already class-validated
descriptor, and reuse the resolved descriptor on reads instead of looking it up
again. UpDirection and MultiMesh checks, live owner/domain resolution and result
validation remain intact. Remeasure after a fresh adapter; current results do not
qualify this subsequent native change.

## Editor and visual observations before the effect optimization

The retained `e2735ec` Windows adapter passes the full existing native editor
workflow, including new profiles, preview/save and fresh-process reopen, in
`gl053-native-20261112/e273-editor`. The independently staged shipped 2D, 3D and
UI scenes also render on the verified official OpenGL host. Inspect viewport
captures at 960x640 and 1280x800 under `capture-e273-*-resize`: sprites/markers,
3D camera/materials/instancing and themed controls are visible; the UI retains
its margins and usable layout. Native Tab focus moves from text entry to slider,
and Right changes the slider. The external game observer reuses the established
Relay Siege frame-post-draw/readback pattern; it does not control the desktop or
change production project sources. Retain its commands, sources and image hashes.

The actual interactive editor attempt at `interactive-e273` cannot proceed.
The Computer Use capture is black; activation fails twice with
`GetCursorPos failed: Access is denied. (0x80070005)`. Stop that verified task-owned
editor process after the failed access attempts; its termination is intentional,
not a claimed normal-exit runtime pass. No unsaved user content was involved.
This is an environment/UI access gap. Headless editor and rendered game evidence
do not establish interactive editor completion.

Current core run 43234499930 passes both platforms. Non-publishing candidate
43234541985 and full-native sanitizer 43234536332 target immutable `3a5adb6`;
native run 43234500028 is in progress. DockerPC's worker slot remains actively
held by the unrelated campaign at 14:14 UTC, so sustained builds stay in hosted
CI. No host lease is bypassed, admitted profile changed, or local build started.

Source inspection finds a concrete identity mismatch in this campaign's evidence
extension: ReleaseCandidate.Identity hashes the newly consumed example/template
files, but CheckNativeCI still emits the older file set. That would fail the
unchanged strict profile comparison after otherwise successful runtime checks.
Add the identical paths/LF hashes to the native receipt, preserving the comparison
and all execution gates. This is a receipt correction, not permission to relabel
old evidence or weaken source identity. Keep the superseded candidate attempt;
the corrected candidate cohort must carry its own immutable revision.

The `b9123fa` native/candidate receipt expressions match all 132 consumed file
hashes; retain the one-off comparison in `receipt-identity.json`. Corrected
candidate run 43236570162 preserves all strict gates. Native implementation and
executable fixture cases are unchanged from `3a5adb6`; its full-native sanitizer
run continues with that actual identity rather than being relabeled.

The existing native preview/save methods also accept all three shipped project
entrypoints in a separate isolated editor observation (`foundation-preview-e273`).
Each preview has 24–27 native nodes, saves to ordinary PackedScene and reloads
independently after preview teardown. Reported preview times are 15.744 ms (2D),
9.348 ms (3D) and 6.779 ms (UI); VM observations are 608,360, 595,440 and 526,920
bytes. These are bounded single observations, not baseline speedups or leak proof.
No gameplay services run in preview and no application GDScript is introduced.

## Current runtime results and retained sanitizer failure

Run 43234500028 passes complete Windows/Linux native qualification (141 required
actors plus the official-host navigation/editor checks) at `3a5adb6`. Current
Windows component/rendered/editor checks also pass at that native fingerprint,
including fresh current captures, shipped gameplay, preview/save/reopen and a
100-revision reload observation. Keep exact measurements and the remaining Debug
dispatch increase in the [qualification record](gl-053-native-qualification.md).

Full-native sanitizer run 43234536332 attempt 1 passes Windows completely.
Linux passes detection controls, reloads, new API/module cases and every group
except DataStore; no unexpected ASan/LSan reports are emitted. The unchanged
basic persistence actor reports an indeterminate Counter BindToClose SetAsync
and lacks the expected close-save result. The strict final check then fails
because that group's results are incomplete. Preserve logs in 3a-sanitizer-linux.
Storage/companion sources and DatastoreIntegration.gd are identical to main.
Do not attribute this to GL-050's unproven receive/exit race or change durability,
deadlines, retries or assertions. Run the failed Linux job once on a fresh runner,
preserving the first attempt. Windows evidence stays at its successful attempt.

The independent saved-scene reopen works in a new project with no extension or
Luau VM. Native Godot warns that the copied 3D shader UID is absent from the new
project cache and successfully falls back to its text resource path; preserve
that warning rather than claiming a completely silent UID-cache migration.

Rendered acceptance reveals a sample-quality gap: the 2D player's two native
sprite frames reference the same texture, so playback is not visibly different.
Give its second frame an original native gradient texture. This changes only
the acceptance application's source/assets; native implementation, declarations,
engine package and dependency inputs remain unchanged. Keep the accepted engine
candidate at its real `b9123fa` identity, and qualify the changed application
inputs with the existing gameplay/render/export runners and their staging hashes.
Do not relabel the older full-matrix fixture inputs as the new application.

## Final supported-scope qualification checkpoint

Candidate 43236570162 is accepted at `b9123fa`: all four production profiles,
core ASan/LSan, retention controls, both packages and extracted companion startup
pass. Full-native sanitizer 43234536332 passes Windows at attempt 1 and Linux at
attempt 2, with no unexpected reports. Preserve Linux's first indeterminate
close-save failure and GL-050's separate unresolved status.

Current engine-native implementation remains fingerprint `685cbd6a...81149`.
Native2D/Native3D/UI pass actual native export, independent startup and rendered
Release standalone observations. The 2D-only visible-animation follow-up passes
its fresh focused gameplay/export/render checks and type run 43249386432 on both
platforms, using the unchanged accepted engine. Separate engine, application,
fixture and documentation revisions in the versioned receipt.

Relay Siege passes rendered solo, fresh-process persistence recovery and both
four-player listen/dedicated scenarios with the accepted products and unchanged
game/controller/networking sources. Existing soft-body interaction limits and
Native-default/Scripted-opt-in contracts remain intact.

The actual interactive editor attempt remains blocked by black capture and two
GetCursorPos access-denied activation results. No interactive pass is claimed.
All other feasible campaign qualification is complete; do not expand into host,
debugger, persistence or qualification-framework redesign to hide that gap.
The known Debug dispatch increase and deferred API families stay visible in the
[qualification record](gl-053-native-qualification.md). Leave the feature branch
unmerged and keep release/updater distribution disabled.

## Owner-authorized completion and main integration follow-up

The owner now authorizes completing the remaining issues, qualifying and normally
merging into main, preserving history and disabled distribution. Start from clean
feature HEAD `7201afa` and fetched main `16e8597`. Existing passing evidence remains
valid within its scope; new native changes need focused measurements and CI.

Replace property lookup's repeated native class-name reflection/UTF-8 conversion
with a bounded query-name descriptor index. Candidate descriptors remain derived
before base and are checked against the live native type on every query. No object
pointer, caller string, authority decision or native identity is cached. Method/
signal lookup and all owner/lifetime/resource checks remain unchanged. Measure
before claiming the dispatch regression resolved. Investigate GL-050 separately
with a controlled real-helper exit/reply interleaving; do not conflate it with the
earlier unproven close-save failure.

Desktop access recovered on the same isolated Windows editor project. Actual UI
actions now pass UI-profile scene creation, native preview/node inspection,
independent snapshot save, highlighted Luau editing, inline syntax diagnostics
and recovery, approved enum completion, source save/re-preview, Play/Stop, native
keyboard input and Apply callback, followed by editor exit 0. Retained captures:
`gl053-followup-20261112/interactive-ui-preview.jpg` and `interactive-ui-play.jpg`.
This replaces the access blocker within the unchanged editor implementation's
scope; it does not relabel the earlier failed attempt. The embedded UI starter's
non-ASCII status separators render incorrectly in this Windows build. Replace
those two cosmetic separators with ASCII pipes in its source and generated copy;
verify the corrected starter on the new adapter and reopen the saved project.

The actual companion barrier reproduces GL-050 with the old exit decision:
`race-before-datastore` exits 1 at the controlled empty-read/exit check while
`ds_GL050_Race.json` contains committed value `37`. The corrected `b7297fb`
adapter passes the identical fixture (including large payloads and BindToClose).
The barrier and direct driver are CMake-test-only; SCons products expose neither.
No lock, durability, exit-status, trailing-diagnostic or deadline check is removed.

Same MSVC 19.44.35228 Debug cache and official Windows host, identical seven-trial
fixture (first trial excluded): `7201afa` dispatch median 65.016 ms; first fix
52.416 ms. Reusing one validated Assignment batch rather than allocating it twice,
and indexing immutable descriptor names with string_view, reduces this to
40.089 ms. Construction median is 0.657 ms for 64 nodes, conversion 11.240 ms for
2,000 Transform3D values. The retained older `60913fb` dispatch was 42.873 ms;
the observed regression is removed in this workload, not a universal performance
claim. Rendered expansion passes including unrelated Node3D/Node2D/Control
Position dispatch and invalid-write rejection without mutation. One mistaken
headless invocation correctly rejected this renderer-required fixture; retain
that environmental attempt alongside its rendered pass.

Supersede the in-flight `b7297fb` native/sanitizer/candidate checks with the final
allocation correction's cohort. This is a known source change, not a retry of a
failed product check. Core 43342974083 and declarations 43342974114 passed.

The final normalized native fingerprint is `fda36b81...6b1cb2`, runtime revision
`0af6e4d`, tree `ffd4de98c780a7df46da28d46ca360a0b031363d`. The complete final
seven-trial measurement is 40.124 ms dispatch, 0.642 ms construction and 11.021 ms
conversion; this includes the explicit string_view include. The actual final
adapter passes rendered expansion and the existing native editor workflow:
44 authoring checks and seven fresh-process reopen checks. The emitted UI starter
and template contain ASCII separators. Reuse the completed actual interactive
journey for unchanged editor code; do not claim that the later physical-Escape
interruption was another graphical pass. All task-owned editor processes have
exited, and DockerPC lease generation 114 is released after its builds finish.

Final hosted cohort: core 43343578815 passes; native 43343578813,
full-native sanitizers 43343586993 and candidate 43343590025 are still running.
The candidate policy/retention and Linux core ASan/LSan gates already pass.
Remote main remains `16e8597`, an ancestor of all 26 current feature commits.
No dependency pin, admitted host, Character/networking implementation or
release/updater policy changes are introduced by this integration follow-up.

Linux sanitizer 43343586993 attempt 1 fails the new controlled GL-050 fixture,
with detection controls passing and no unexpected ASan/LSan report. Its close-save
file contains `99`; the race-test file is absent. The test directly supplied
`globalize_path("user://")`, including its trailing slash, whereas production
supplies a root without that separator. Linux's confined OpenRoot rejects the
resulting empty final path component; Windows explicitly skips empty components.
Correct only this fixture argument with trim_suffix("/"). Do not loosen native
confinement or change production persistence. Retain the failed logs/artifact
14000824287 (archive SHA256 `ebad20c3c6d431031d0bedc5260fa899ba67c6c9282d8a77105b341021492816`)
under `gl053-followup-20261112/sanitizer-linux-attempt1`. The final native build
fingerprint stays unchanged; fixture identity and hosted qualification must use
the corrected input. Supersede the in-flight cohort for that concrete correction.

The corrected fixture passes Windows on the final adapter with raw fixture hash
`7636c35441a30e0200077e1e12097dd061520c3d82c00504ec3d87d3e6186461`.
Final qualification revision is `bb15aab`: core 43346809940 passes; native
43346810000, full-native sanitizers 43346827388 and non-publishing candidate
43346831705 run the corrected fixture. The normalized native fingerprint remains
`fda36b81...6b1cb2`; no product rebuild is needed for the local focused checks.
The [final correction receipt](evidence/gl053-native/final-corrections-20261112.json)
records those distinctions and preserves the preceding accepted receipt unchanged.

Linux full-native sanitizer 43346827388 passes the corrected `bb15aab` fixture:
27 stages, controls, 87 core cases, 141 actors and no unexpected ASan/LSan report.
The basic persistence log explicitly passes controlled empty-read/exit reply and
ordinary prototype/BindToClose. Retained artifact 14003151397 has archive SHA256
`eff288166f3676fe63c0dc08ab414ddf1f6b689b30cbbacf84d8885fb3ececee`.
Its strict native summary records the expected native fingerprint and revision.
Together with the Windows controlled before/after, this closes GL-050's scoped
transport defect on the branch. Remaining Windows/native/candidate gates still
run; do not conflate that issue closure with completion of the main integration.

Native 43346810000 passes both Windows and Linux at `bb15aab`, each with all
141 required actors and the unchanged strict checker. Both summaries retain the
expected native fingerprint, four storage fault stages, four kill/recovery stages
and 40 independent native increments. Actual native editor, authoring/reopen and
official-host path checks also pass. Windows evidence artifact 14004275361 has
archive SHA256 `97438b6c195f99a175346bec9a8dc2277e530e20643cc14b7db91f8725850246`;
Linux artifact 14003027221 has
`a3390da796ec87f09dab5702d2f1a809ccd0f5d34fc1603d962e8d4e2376670c`.
Keep waiting for complete Windows sanitizer and candidate/package acceptance.

Full-native sanitizer 43346827388 now passes both platforms: Windows 26 stages,
Linux 27 stages; both controls, 87 core cases, 141 actors and zero unexpected
reports. Windows explicitly passes the controlled empty-read/exit marker and
ordinary persistence/BindToClose. Artifact 14003528598 has archive SHA256
`82bf6d8e9257ccc4ae4ccf22a31176c59011484fe7237518d244774460059f6a`.
Retain GL-018's Windows sanitizer/LSan limits. Only final non-publishing candidate
build/package/extracted-startup acceptance remains before the normal merge.

All four source-built profiles in 43346831705 pass, but both extracted-package
checks fail at the newly added controlled race assertion. SCons production
libraries correctly omit the CMake-only test methods; the shared basic fixture
incorrectly required one. Correct its scope: the existing CMake reset-domain
marker identifies a test adapter, where the race method remains mandatory.
Ordinary service, large-payload, authority and BindToClose assertions stay active
for both products. No production code or companion packaging changes are needed.

Reuse these exact four qualified products and the passed core sanitizer through
the existing repackage workflow. Its bounded repair allowlist additionally names
this one startup fixture. Smoke uses the reviewed checker checkout and records
its actual fixture hash; product/source identities, all profile checks, archive
checks, extracted startup and acceptance remain enforced. Preserve original
profile/fixture identities in provenance and the repair revision separately.
This avoids rebuilding unchanged products for a demonstrated fixture-scope error.

Repackage 43355306613 passes Policy, both platform packages and final Acceptance.
Accepted source remains immutable `bb15aab`; checker revision is `2d8b16f`.
All original profile/product identities and existing checks remain enforced.
Windows/Linux Debug and Release extracted companion startups pass. Corrected
Windows CMake fixture replay also explicitly passes the controlled race marker.
Accepted evidence SHA256 is
`0c53d2cc038754a61aad84468bc0e1a62bf5f9e5d7d0ff298be0284dead44ec2`.
Archive hashes are Windows `be9c979c28f0208a42bbded1f90ad432e86084809916f8401793d787c4aef949`
and Linux `85062b288fe0d3f4939c54093917ab9840652371f519c9a4030f5394489f9be2`.
The source and final correction receipts preserve failed attempts and explicit
reuse scope. Qualification is complete within the documented limits; proceed
with the authorized normal merge, exact-tree/history checks and fresh main CI.
