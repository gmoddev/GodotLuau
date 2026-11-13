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
