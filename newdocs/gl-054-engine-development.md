# GL-054 engine and production campaign

Status: implementation in progress, unmerged. This campaign name is distinct from
the historical GL-054 transitive-module-reload finding, already resolved on main.
Never renumber or reopen that finding without new evidence.

## Baseline and boundaries

On 2026-11-12, remote main and the clean integration worktree both resolve to
`e3d7b53e78dd483e3765d64995e862810d94c6f8`. Work is isolated on
`feature/gl-054-engine-production`. Preserve dependency pins:
godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`,
Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.
No main merge, publication or updater admission is authorized by this campaign.

Read AGENTS, the documentation classes/architecture/invariants/issue ledger,
ADR-014/015/016/017, and GL-049/051/052/053 source and retained qualification.
Existing domains, ownership/generations, ObjectDB/Ref identity, native Godot
systems, Character authority, persistence and transport remain authoritative.
Native remains default; Scripted remains explicit opt-in.

GL-050 is closed within its recorded scope. The retained main receipt identifies
fresh core/native/types passes at `502bcbe`, including 141 native actors on each
platform and the controlled real-companion reply/exit marker. Retained native
fingerprint is `fda36b81c44f8dc11a2c3b52d17687fbda78b5b2f911ea230fd544a54e6b1cb2`.
Do not repeat those unchanged gates merely to establish this starting point.

## Consequential phases and acceptance facts

1. Measure the existing approved surface against the same pinned metadata
   denominators. Keep discoverability, authorization, conversion/call support,
   generated typing, actual execution and representative application use separate.
   Add bounded test-build invocation evidence rather than infer execution from
   declarations, source strings or policy selections.
2. Expand Variant/binding support and complete useful native feature families:
   typed collections, scoped object/resource collections, nullable/default
   arguments, physics/area/casts, navigation, lighting/particles, UI, rendering
   and asset resources. Each family needs valid calls, rejection without mutation,
   bounds, wrong-owner and retirement coverage before it is called qualified.
3. Extend native composition, controlled lifecycle/effects and resource workflows
   where the existing boundary can represent them. Record a focused decision
   before a new ownership/effect model; never expose raw global engine authority
   to bypass a missing interface.
4. Improve actual editor navigation/indexing, diagnostics, inspectable error
   context, preview/reload and project templates. Distinguish error snapshots from
   suspended debugging; do not advertise breakpoints/locals without a real bridge.
5. Build a mechanically substantial, modular Luau-only 3D acceptance game using
   native physics, navigation, animation, UI/audio/resources, transitions and
   persistence. Use existing networking/Relay Siege for unchanged transport and
   multiplayer regression, rather than introduce a competing framework.
6. Qualify bounded stress/performance, actual graphical/editor/export behavior,
   Windows/Linux Debug/Release, core/native/types/sanitizers and non-publishing
   packages. Reuse trustworthy evidence only within identical input/scope limits.

Continue through independent phases; this plan is not an implementation result.
If a family needs unavailable capability/host/debugger support, document its exact
blocker and continue feasible work. API counts are not acceptance by themselves.

## Source-confirmed starting observations

The generated baseline reports 920 metadata classes and 14,379 declared methods;
94 classes are constructible, with 306 selected property descriptors, 167 methods,
33 signals and 49 constants. Those are policy selections, not execution coverage.
NativeCoverage.json inventories metadata and permissions but has no invocation
receipt. Generator Value explicitly rejects typed-array arguments; outputs admit
only limited primitive typed arrays. Generic nested Variant values reject native
object references. Existing direct Node/Resource arguments retain scoped authority.

Existing GL-053 already implements bounded compound/packed values, native physics
and navigation, sealed owned value-track animation, nested/inherited scene
preflight, transitive module invalidation, module navigation and four native
starter scenes. Preserve those instead of rebuilding their infrastructure.

DockerPC was busy at the initial worker admission check. No worker load or local
native compilation was started. Keep source work progressing and use existing
hosted qualification until safe worker admission is available.

## Phase 1 — invocation baseline (implementation, qualification pending)

The CMake test adapter now optionally records successful constructors, member
reads/writes, calls, delivered signals and pure-value construction, keyed by live
execution domain and exact policy descriptor. `GL_NATIVE_COVERAGE=1` enables it;
SCons production builds contain no recorder. Counts are bounded and saturation is
explicit. No native handles, callbacks or owner references are retained by it.
The existing native CI workloads collect this evidence without instrumenting the
performance steps. `tools/NativeCoverageReport.py` joins same-policy receipts with
the stable pinned metadata inventory. Successful invocation is not a correctness
assertion, nor evidence for unmeasured enum reads or scope operations.

Read-only generation check passed; the initial inventory reports zero invocation
receipts until the instrumented workloads run. This deliberately does not invent
executable coverage from the previously qualified source or declarations.
The starting selections are 94 constructors, 306 properties, 167 methods,
33 signals and 49 enum values. The denominators remain 920 metadata classes,
14,379 methods, 3,676 properties, 447 signals, 647 enum declarations and 155
standalone class constants; selected enum values are not compared to that last
constant denominator. The journal and inventory implementation are a first
reviewable phase, not completion of GL-054.

## Phase 2 — collections and native feature families (qualification pending)

Typed primitive arrays now preserve their Godot element type on input and validate
it on output. Scoped typed Node/Resource arrays use the existing live SceneScope
authority: every input handle must belong to that scope, all arguments validate
before invocation, resource query handles remain immutable, and Node query arrays
project only live owned nodes into a dense frozen result. Foreign query bodies
provide no native handle. Arbitrary objects nested in general Variant dictionaries
remain unsupported; no raw RID/Callable/Signal capability is introduced.
Typed arrays retain the 1,024-element collection bound. Exact metadata defaults
now include Vector3, integer Vector2, NodePath and empty typed arrays, without
evaluating source expressions.

New approved families include Area3D and scoped 2D/3D overlap queries, 2D/3D
ShapeCast with bounded collision-index inspection and owned exceptions, 2D
navigation agents/regions and 2D/3D avoidance obstacles, CPU particles, 2D lights,
decals, procedural images/textures, tile pattern inspection and typed CodeEdit
configuration. Existing generic descriptors, handles and generated types remain
the implementation path. Shape updates and navigation calls use the established
runtime physics-phase gate; 2D navigation also checks map synchronization.

Image initialization accepts exact RGB8/RGBA8 data, dimensions 1..16, no mipmaps;
the packed collection limit remains unchanged. Mutable ImageTexture uploads are
non-mipmapped and bounded to 1,048,576 pixels; updates must match existing size and
format. Layered textures accept 1..16 matching owned images within the same total
pixel budget. Invalid inputs reject before native mutation. Loaded project assets
remain trusted local resources, not a hostile-file sandbox. CPU particles start
inactive and preview rejects enabling emission, matching existing temporal-effect
restrictions. Tile patterns have bounded cell capacity; this is not unrestricted
TileSet editing or terrain baking.

`NativeProductionCases.gd` exercises actual dispatch, primitive/resource arrays,
invalid arrays without mutation, cross-scope/cross-owner rejection, foreign-body
projection, native image state, both cast dimensions, overlaps, navigation on the
official full-featured host, and owner retirement. These tests are implemented but
not yet reported as passing. The existing admitted lightweight hosts still omit
navigation; their negative availability evidence remains distinct from full-host
path qualification. Baseline hosted runs: core 43364130777 and native 43364130679.

Both platform declaration jobs passed for `c628b81` in run 43365508318. The new
runtime cases remain pending native builds; selections are not yet qualified by
that type result. Core/native runs 43365508309/43365508357 cover that revision.

## Phase 3 — practical error inspection (qualification pending)

The existing editor debugger transport now supports bounded error-time frame and
primitive-local snapshots, domain/generation labels, opaque native/table values,
and explicit project-source frame navigation. Full local-name compilation is
selected by the trusted editor host, not by gameplay scripts. The
[native development contract](gl-054-native-development.md) records bounds,
compatibility, memory-failure handling and the precise live-debugger limitation.
The actual EditorInterface play/stop fixture now checks real debugger delivery of
copied locals, opacity, domain identity and source navigation. Signature help also
retains typed collection elements. These are implementation statements awaiting
execution; no interactive/graphical debugger pass is claimed yet.

## Retained baseline result and first candidate failure

Native run [43364130679](https://github.com/gmoddev/GodotLuau/actions/runs/43364130679)
passed Windows/Linux at `65c0921e3e517a702c764ecbe02d55826ff1b612`, 141 actors
per platform. Native identity is `0d79e0b7e00759ec452927096c3529950069c8b8c2d451028f985899c7020bee`
(125 LF-normalized inputs). Both invocation reports contain 12 process logs and
440 domain/member pairs with identical membership. Across domains, the union is
61 constructors, 61 methods, 22 property reads, 116 writes, 11 delivered signals
and 26 value constructors. Per-domain constructor/call counts are Server 53/59,
Client 29/12 and EditorPreview 31/3. This is use evidence under the unchanged
baseline workloads, not whole-API correctness or an application coverage claim.

Retained native ZIP digests: Windows artifact 14011375457
`d8e423e6d15098a26a1f3c8a6cc8d759b6f8a9f88c62d6175db953d65be1de77`;
Linux 14010497351
`b3aca80cca09676aa55208b318a8e646da9aab43bc2ae6f4f55807a274ec4e21`.

The first expansion's Linux run 43365508357 failed at ProductionOwner line 44:
the fixture assumed TileMapPattern.SetCell with default -1 IDs removes the cell.
A direct control on the existing official Godot 4.7.1 returned two coordinates
and size (2,1). The fixture now checks that actual native result while retaining
the default-argument test. No engine/product behavior was changed to fit the
assertion. Preserve the failed artifact 14010797518, ZIP
`cdcb705acd3f55afd89f6939f762a368f04fc58372c8cad278dbcdea3283ac0a`.
Four new Color4 properties also lacked explicit 0..1 descriptor bounds; source
review corrected those before qualification. Non-const native observations now
carry matching mutation metadata. These are candidate corrections, not passes.
Core CI also passed the snapshot implementation at 02ef3bc (43366364704).

## Phase 4 — Foundry Expedition (implementation, qualification pending)

Added a new [modular acceptance game](../examples/foundry-expedition/README.md)
using only Luau game code. Server rules own scene-native movement, health,
shape-cast combat, navigating guards, collection, three inherited room scenes,
transitions and transactional progression. Client code owns native UI, keyboard/
gamepad semantic input and session settings. This is single-process solo: the
bounded root-attribute input/presentation bridge is not a network protocol.
Relay Siege remains the multiplayer regression. The Explorer is an independent
scene-owned CharacterBody3D; Native/Scripted Character V2 defaults are untouched.

Native animation and particles, project-local SVG/OBJ/audio/shader resources,
procedural UI texture upload and per-room reconstruction exercise the expanded
surface. GL-009 transforms use bounded server-generated receipts to tolerate
retry/ambiguous acknowledgments. Up to three receipts are pending; failed saving
backs off and stops after three attempts until explicitly retried. Unacknowledged
progress is never labeled durable. Close-hook failure remains explicit.

The existing staging/qualification path gains a Foundry profile, retaining fresh
directory creation, explicit adapter/candidate identity, owned child processes,
crash-UI suppression and isolated user-data roots. The external observer drives
real native input/UI, movement/jump, pause/settings, wrong-owner rejection,
collection, navigation/combat, transitions and a fresh-process persistence read.
It uses deterministic native spatial setup for combat, not substitute game rules;
that is narrower than human gameplay completion. Headless CI uses the existing
verified full-featured official host. Graphical/editor/export, stress, performance,
sanitizer and final Windows/Linux Debug/Release gates remain outstanding.

The snapshot native run 43366364538 found missing direct String/Variant includes
in the new translation unit; added those includes without changing behavior.
The new declaration regressions in 43368429635 found a real mutable-resource
array variance gap: the pinned frontend rejects `{MutableNativeImage}` where an
invariant `{NativeImage}` is expected. Generated typed-resource inputs now admit
the exact immutable/mutable array shapes for admitted constructible subclasses,
without `any`, dropping element checks or changing native permissions. Positive
and wrong-element cases stay enabled. Pending native run 43368429595 was canceled
because it contains the same already-diagnosed compile error; rerun the corrected
head rather than rebuild that known-bad input. Failed attempts remain retained.

Foundry's explicit pause-menu restart now also drives 24 production world rebuilds
in the external observer. Each checks that the old native identity retires and
only the UI/current-world scopes remain. It records input-to-snapshot latency and
native object/resource count deltas, without equating engine cache growth with a
proven leak or these end-to-end timings with isolated binding dispatch cost.

Both platform core and declaration jobs pass at corrected `31d64a5` (runs
43369152931 and 43369152884). Its native run 43369152927 remains pending.
DockerPC's cooperative worker remains held by an active unrelated campaign;
admission was denied and no load, cleanup or takeover was attempted.

## Phase 5 — bounded editor project references (qualification pending)

Project Uses extends the existing AST navigation with a cached, read-only index
of static module member and local function-alias uses. Exact module paths and
lexical identity distinguish unrelated/shadowed names. Active unsaved editor text
participates; changed sources reparse, unchanged hashes reuse pure cached records.
The [contract](gl-054-native-development.md) defines bounds, partial results and
unsupported dynamic/re-export semantics. The editor-only/main-thread/non-Luau
gates preserve gameplay capability restrictions. UI navigation remains explicit.
The actual native editor workflow now checks these behaviors and records cold,
warm and changed-buffer query timings. No index or graphical pass is claimed yet.

A bounded local MSVC `/Zs` check passed the new index, editor-plugin and snapshot
translation units using headers generated from the unchanged pinned API and the
existing pinned Luau headers. It used one process for about four seconds; no
object/library or sustained local build was produced. This caught source/header
issues only and is not Windows runtime, target-compiler or cross-platform
qualification. The checked command is retained under the task's syntax artifacts.

## Production/sanitizer qualification wiring

Current policy selections are 113 constructors, 384 properties, 225 methods,
41 signals and 51 enum values against the unchanged metadata denominators. Policy
identity is `c47c8e9f8a634510278c5ec30ce47850b7898b969399790cbb5c5adab9231ace`.
These selection counts remain implementation measurements, not final execution
qualification.

The shared native checker also serves admitted-host sanitizer and candidate actor
profiles, which omit navigation. Foundry is therefore an explicit required flag
in the full-featured native CI job, not a falsely mandatory workload on those
unsupported hosts. Existing actor assertions remain mandatory in every profile.
Each production Debug/Release candidate separately runs Foundry with its actual
SCons product on the existing verified full-featured official host. Candidate
evidence archives retain that gameplay/restart result. Application assets and
editor fixture inputs join the existing source hashes; no second qualification
framework, host admission, dependency or publishing path is introduced.

The existing 17 candidate and 12 retention unit checks pass locally after wiring
review; production builds, package extraction and sanitizer workflows remain to
be executed. Full-native sanitizer profiles retain their existing host/editor/
navigation limitations; ordinary full-host game results must not be relabeled as
sanitizer coverage of an unsupported configuration.

## Actual plain-scene bootstrap defect

Run 43369152927 completed the expanded integration, positive 2D navigation,
editor snapshot workflow and Orb Run gates on both platforms, then failed Foundry
startup: `BindToClose is not a valid member of Window`. The inherited global
initializer selects only legacy classes/a node named Game and otherwise wraps the
Window. The DataModel compatibility branch likewise excludes an ordinary scene
root. This is a reproduced engine integration defect, not a storage race or an
argument to add GDScript bootstrap logic.

The bounded fix preserves legacy selection, then uses the actual current scene
root before the existing Window fallback; the compatibility branch recognizes
that exact live scene root for BindToClose/metadata. Foundry retains its own
ordinary root name and now asserts `game == script.Parent`, with the external
fixture observing Server/Client state on that same root. No extra DataModel,
controller, domain or filesystem authority is introduced. Qualification is pending.

## Shared ancestor authority defect

An isolated control using the retained Windows `31d64a5` adapter confirms that a
Client can move/rotate a shared plain ancestor of a Server-owned SceneScope:
Position succeeds with X=123 and Rotation with Y=90. Native set/set_position calls
reject. Lowercase position assignment succeeds as unknown-member metadata without
moving the node. The new property guard reuses GLSceneMutation for ancestors,
closing the path consistently rather than weakening native scope checks. Same-owner
ancestors remain writable; explicit metadata channels remain available. GL-057
tracks the actual defect and required cross-platform/sanitizer verification.

Foundry's controlled legacy-root runs also exposed application/fixture problems:
deferred deletion left the prior world name occupied, so the new world was renamed;
the app now releases that name before queueing retirement. A transition continued
its old frame and attempted camera settings through retired handles; it now exits
that frame immediately. Native authority correctly rejected those stale writes.
Collection observation now waits on the actual published cell count rather than a
six-frame timing assumption. The failed attempts remain under local control-01/02
artifacts and are not final plain-root qualification. Control-02 nevertheless
completed 24 restarts with zero measured native object/resource count delta and
exactly two live scopes after each cycle; these scoped observations do not imply
sanitizer leak freedom or a passing overall attempt.
