# GodotLuau issue ledger

Initial triage: 2026-10-26. Source baseline:
`7044a11c1bcc2eac2a91155e829a5821d92ab66e` / v1.16.12.
Historical evidence is preserved below. GL-001/GL-002 are resolved for their
specific captures, GL-014 is integrated into main and source-qualified, and GL-019
is optimized, qualified and integrated into main. GL-006/GL-008 are also integrated
into main and resolved for their qualified endpoints; GL-020's dedicated
adversarial follow-up corrects a reproduced malformed-animation gap and is now
integrated, with native sanitizer limitations retained. GL-022 is fixed and
qualified on its dedicated branch and now integrated into main. GL-007 and the scoped GL-024/025 fixes are
also integrated; GL-026's bounded workaround is integrated while its dependency
follow-up remains open. Other entries retain their stated scope. This file does not
create upstream or GitHub issues.

Evidence is static unless explicitly stated otherwise. `Verified` establishes the
described implementation fact, not a reproduced crash/exploit. `Needs review`
identifies a missing material fact. `Design decision` is not a confirmed defect.
P1 = address before relying on the affected production feature; P2 = planned
engineering/design work. Priorities are not security severity scores.

See [review validation](review-validation.md) for the original claims,
counterevidence, security verdicts, and scope. Source line numbers below refer to
the baseline; preserve IDs when a refactor moves the implementation.

## Index

GL-052's [implementation journal](gl-052-development.md) tracks the new-project
Luau-only authoring, preview, native persistence and export campaign. It is
qualified within its documented scope and [integrated normally](gl-052-main-integration.md),
preserving all 25 commits. Fresh Windows/Linux main core/native/definitions CI
passes at 15af022; the integration receipt preserves source and artifact identities.
Windows interactive acceptance is complete. The final default-script `print`
follow-up passes core/native CI,
all four production profiles, both packages and actual game export/startup.
GL-050's later transport correction is qualified on the native-expansion branch;
see its scoped resolution below.
The [qualification record](gl-052-qualification.md) preserves actual editor/game
passes, completed Windows/Linux core/native/types/sanitizers, accepted production
packages and Windows export/rendered multiplayer. The
[interactive receipt](evidence/gl052-interactive-qualification.json) records the
completed native edit/preview/Inspector/error-recovery/save/restart/export and
rendered standalone journey; earlier desktop failures remain historical evidence.
The snapshot-path correction now passes seven fresh-process
reopen checks on Windows/Linux at `60913fb`; the old duplicate-child/load-dialog
failure is preserved. [GL-053](gl-053-default-damage.md) removes and qualifies the
unsafe default damage endpoint without changing native health authority.

The [Relay Siege main integration](e2e-game-main-integration.md) preserves the
qualified game and its original evidence. GL-043 is now separately qualified and
[integrated](gl-043-main-integration.md). GL-044/045 have focused corrections on
retained `codex/gl-044-045-relay-luau` and are qualified within its recorded profiles.
The [normal integration](gl-044-045-main-integration.md) preserves all 17 commits.
The original game
merge did not itself close any of those native compatibility findings.

Networking Foundation 2 source `cb2014f` is now integrated by a normal merge into
compacted main `41acd27`, preserving three foundation commits and every historical
receipt. See the [integration record](networking-foundation-2-work.md#main-integration-2026-11-05).
Historical campaign closures below now apply to the integrated source within
their same recorded scope; no broader closure follows. GL-033/040/041 remain open.

The [combined GL-018/GL-029 development review](gl018-gl029-integration.md)
preserves both histories and lists the remaining acceptance gates. GL-018 now has
its separate scoped [closure](gl018-closure.md); GL-029 has a separate
[admitted-host closure](remoteevent-completion-qualification.md). Normal merge
`6a7fedf` integrates both; [fresh main verification](gl018-gl029-main-integration.md)
passes at `ac119bc`, separately from retained branch qualification. The
[main receipt](evidence/gl018-gl029-main-verification-2026-11-03.json) records all
four successful workflows and independently checked artifacts.

| ID | Priority | Classification | Summary |
| --- | --- | --- | --- |
| GL-001 | P1 | Resolved within stated scope | Live receiver resolution; native ASan lifecycle evidence |
| GL-002 | P1 | Resolved within stated scope | ObjectID captures; service replacement and pending invoke cleanup |
| GL-003 | P1 | Resolved within ADR-003; integrated and verified | Native file global bypassed higher-level role restrictions |
| GL-004 | P1 | Integrated and resolved within ADR-002 | Shared-domain sandbox, interruption, allocator/admission limits |
| GL-005 | P2 | Integrated and resolved within ADR-004 | Async HTTP with native origin grants, bounds and lifetime cleanup |
| GL-006 | P1 | Integrated; resolved within stated scope | Qualified native state/removal sender and receiver-role enforcement |
| GL-007 | P1 | Integrated and resolved within ADR-006/007 | Server health, bounded prediction, freshness and checked presentation |
| GL-008 | P2 | Integrated; resolved within stated scope | Qualified server-owned chat identity, typed/bounded messages and receive authority |
| GL-009 | P1 | Integrated; fixed and qualified within scope | Controlled main merge, stopped-writer gate, preserved data and verified companion packages |
| GL-010 | P1 | Candidate correction integrated and verified; publication unqualified | Same-revision source-built candidate provenance replaces Windows ZIP reuse |
| GL-011 | P1 | Candidate gates integrated and verified; broader qualification incomplete | Required automated profiles; remaining sanitizer/production boundaries |
| GL-012 | P2 | Integrated; resolved within stated scope | Historical releases/tags retained; publication disabled |
| GL-013 | P2 | Open; five extractions integrated | API/stdlib fan-out three to one; bootstrap owned by script CPP |
| GL-014 | P2 | Integrated; source-qualified | Main contains shared domains; remaining limitations stay independently tracked |
| GL-015 | P2 | Needs review | Asset provenance is not established by root MIT license |
| GL-016 | P1 | Integrated; resolved within isolation scope | Runtime updates fail closed; editor tools remain available |
| GL-017 | P2 | Reproduced external engine defect | Godot simultaneous-disconnect relay sends to reset peer and leaks packet |
| GL-018 | P2 | Integrated; resolved within admitted matching-host profile | Headless Windows ASan/Linux ASan-LSan qualification; retained host/platform limits |
| GL-019 | P2 | Integrated; optimized and source-qualified | Main retains revision-aware cache, smaller snapshots and measured tradeoffs |
| GL-020 | P1 | Integrated scoped authority correction; sanitizer qualification partial | Canonical wire validation and ENet adversarial coverage; GL-017/018 remain separate |
| GL-021 | P2 | Verified construction-order discrepancy; runtime unexercised | Inert signals omit lowercase once/wait aliases |
| GL-022 | P2 | Integrated; fixed and qualified | Distinct native subscription identities and owner cleanup on main |
| GL-023 | P2 | Integrated and resolved within the documented API contract | HttpService errors, headers, optional arguments and JSON/GUID semantics |
| GL-024 | P2 | Integrated and resolved within exercised scope | Part geometry caches retire before engine-server teardown |
| GL-025 | P2 | Integrated and resolved within exercised scope | Actual AnimationTrack completion and ObjectID-backed lifetime |
| GL-026 | P2 | Bounded workaround integrated; dependency follow-up open | Pinned Dictionary move assignment leaks replaced importer storage |
| GL-027 | P2 | Rendered authoring limitation | StarterCharacter prototype geometry can remain visible in the live scene |
| GL-028 | P2 | Integrated; fixed and rendered-qualified within exercised scope | Character fade cache can retain first-person dither pixels |
| GL-029 | P2 | Integrated; resolved within ADR-008/009 admitted-host scope | Three-mode RemoteEvent publication and bounded application/native admission |
| GL-030 | P2 | Integrated; closed within ADR-010 scope | Bounded RemoteFunction terminal outcomes; historical qualification at 2296c96 retained |
| GL-031 | P2 | Integrated; closed within qualified scope | Static prerequisite seeding restores runtime-child late join |
| GL-032 | P2 | Integrated; closed within qualified scope | ObjectValue Instance/nil bridge and native reference projection |
| GL-033 | P3 | Open; local fixture reliability gap | RemoteEvent pressure/queue-age replay loses unrelated readiness on the qualified baseline |
| GL-034 | P2 | Integrated; closed within qualified performance scope | Bounded catalog maintenance removes the reproduced mixed-world frame/CPU regression |
| GL-035 | P1 | Integrated; scoped native matrix retained | Empty-catalog listen Client can remove structural scope-root ancestor |
| GL-036 | P2 | Integrated; closed within exercised profiles | Benchmark setup and assertions were omitted by Release GDScript |
| GL-037 | P2 | Integrated; scoped native/sanitizer matrix retained | Follow-up full-native runs fail Character/legacy barriers; fixture races corrected |
| GL-038 | P1 | Integrated; scoped qualification retained | Live ObjectValue can convert a destroyed target through a stale instance binding |
| GL-039 | P3 | Integrated; closed within bounded 32-peer scope | Structural burst convergence corrected by bounded FIFO draining |
| GL-040 | P3 | Open; observed coincident-spawn physics interaction | Presentation listen host rises while overlapping peer bodies share its spawn |
| GL-041 | P3 | Open; observed Windows ASan startup limitation | Raised authoritative lane can leave a walking client in a falling state |
| GL-042 | P2 | Integrated; qualified within documented profiles | Raw input reports GUI consumption only after native GUI routing |
| GL-043 | P2 | Integrated; fixed and qualified within scope | Bounded Workspace raycast root filters and native Vector3 impulses |
| GL-044 | P2 | Integrated; fixed and qualified within recorded scope | Native Node3D CFrame lacks stdlib directional convenience fields |
| GL-045 | P2 | Integrated; fixed and qualified within recorded scope | Vector3 colon Dot reads self as the other operand |
| GL-046 | P3 | Integrated; corrected and qualified within recorded fixture profiles | Character/security barrier files can appear before their peer-ID payloads are written |
| GL-047 | P3 | Integrated; corrected and qualified within recorded fixture profiles | Legacy invoke cancellation fixture can observe a response before queued owner retirement |
| GL-048 | P3 | Integrated; corrected and rendered-qualified within game scope | Relay Siege broadcasts snapshots before every joining peer is ready |
| GL-049 | P2 | Integrated; resolved within qualified ADR-014 scope | Typed native scene/resource/UI/audio/physics authoring and migrated Relay Siege |
| GL-050 | P2 | Resolved on native-expansion branch at `b7297fb`; controlled Windows before/after and Linux full-native ASan/LSan pass | DataStore parent could miss a final helper reply after an empty pipe read |
| GL-051 | P2 | Integrated and verified within ADR-015 scope | Scalable policy-driven native bindings, composition, resources and editor/type integration |
| GL-052 | P2 | Integrated and verified within documented ADR-016 scope; retained limits unchanged | Luau-only clean-project authoring, isolated preview, native scene persistence and export workflow |
| [GL-053](gl-053-default-damage.md) | P2 | Resolved for default templates at `60913fb`; native/sanitizer/four-profile package gates pass | Removed unconfigured DamageEvent from disk and embedded templates; historical sink was commented out; customized scripts require review |
| GL-054 | P2 | Resolved on unmerged native-expansion branch; core/native verification linked below | Changed project module leaves cached transitive importers and their callbacks alive |
| GL-055 | P2 | Resolved on unmerged native-expansion branch; native UI verification linked below | FullRect preset can overwrite explicit offsets depending on property-table iteration order |

## GL-055: Native layout preset ordering

The GL-053 UI starter needs FullRect plus explicit margins in one New/Configure
batch. At main `16e8597`, Apply follows the Lua table's iteration order: a later
FullRect preset resets offsets already applied. This is source-verified ordering
behavior, not a reproduced graphical failure. The native-expansion branch applies
the layout preset before explicit properties, retaining validation before mutation.
NativeTemplateCases checks actual Control anchors/margins and live UI signals.
Fix [72d5dc8](https://github.com/gmoddev/GodotLuau/commit/72d5dc8d2bf399db79229a708170e00e911d31aa)
passes Windows/Linux native run
[43234500028](https://github.com/gmoddev/GodotLuau/actions/runs/43234500028),
including the actual template margins/signals. Current Windows rendered UI and
960x640/1280x800 captures retain explicit margins. See the
[qualification record](gl-053-native-qualification.md). Resolved on this feature
branch; main has not received the fix.

## GL-054: Transitive project module reload

At main `16e8597`, GLExecutionDomain tracks a loading module's WaitingOn edge
for cycle detection but retains no dependency edges after initialization.
InvalidateModule retires one identity only; LuauScript source changes emit a
signal without invalidating a project-resource identity. A ready parent cache
can therefore retain the child's old returned value. This is a source-verified
iteration discrepancy, not a reproduced crash or authority exploit.

The unmerged native-expansion campaign records module import edges, propagates
invalidation across the dependent closure and invalidates changed project resource
identities before changed subscribers run. Existing owner cancellation retires
callbacks; unrelated caches remain intact. New core tests and the actual native
ProjectReloadCases cover transitive cache replacement, pending initialization,
callback retirement and preserved unrelated modules. Fix
[e92084d](https://github.com/gmoddev/GodotLuau/commit/e92084db59c76d370e7bd0043cc6407226c60e2e)
passes Windows/Linux core
[43236560018](https://github.com/gmoddev/GodotLuau/actions/runs/43236560018)
and complete native
[43234500028](https://github.com/gmoddev/GodotLuau/actions/runs/43234500028).
A separate 100-revision Windows observation also passes cancellation/selectivity;
its natural-GC measurements are not a leak-free claim. See the
[qualification record](gl-053-native-qualification.md). Resolved on this feature
branch; main remains unchanged.

## GL-051: First-class native Luau integration

The [campaign journal](gl-051-development.md) and
[ADR-015](adr-015-policy-driven-native-bindings.md) define implementation beyond
GL-049's manually curated bindings. Preserve its ownership/domain guarantees and
qualification while generating runtime/type/editor surfaces from one checked
policy. New methods, native scene composition and resources require executable
evidence. [Qualification](gl-051-qualification.md) and the
[versioned receipt](evidence/gl051/qualification-20261111.json) record final
Windows/Linux Debug/Release, core/native/sanitizer, actual editor, generated-type,
accepted candidate and extracted game package passes. Retained rendered gameplay
qualifies the unchanged binding/game inputs within its documented Windows scope.
The [normal main integration](gl-051-main-integration.md) preserves all 22 feature
commits and original evidence. Fresh Windows/Linux core/native/editor/type CI
passes at `397dde8`; the [main receipt](evidence/gl051/main-integration-20261111.json)
records verified artifacts separately from retained branch qualification.
This is not full
Godot API parity, a complete embedded debugger/type checker or Linux rendered
qualification. Remaining composition/loading limits stay explicit.
GL-050's later transport correction and qualification are recorded separately below.

## GL-050: DataStore receive/exit ordering

Focused review during [native authoring qualification](native-authoring-development.md)
finds a source-verified race in `gl_datastore.cpp` Work::Advance: Receive can
return empty, the helper can then write its reply and exit, and the following
Finished check reports failure without another drain. Finished preserves the
output pipe on both platforms. Snapshotting exit state before draining is
implemented at `b7297fb`, preserved by `0af6e4d`. The CMake-only real-companion
barrier forces exit after an empty read: the old decision fails with committed
value `37` present, while the fixed adapter drains and acknowledges it. Windows
also passes the unchanged large payload and BindToClose checks. Corrected fixture
revision `bb15aab` passes Linux full-native ASan/LSan in run
[43346827388](https://github.com/gmoddev/GodotLuau/actions/runs/43346827388):
27 stages, 87 core cases, 141 native actors, detection controls and no unexpected
reports, including the controlled exit/reply marker. Resolve this transport defect
on the branch; see the [qualification record](gl-053-native-qualification.md) and
[correction receipt](evidence/gl053-native/final-corrections-20261112.json).

This is not an established cause of the recorded candidate close-save failures.
A missed OK reply would leave its committed value present; those failures also
observe missing final values. The temporary cause diagnostics reproduce no
unexpected failure in one full Linux Debug profile and five filesystem replays.
Keep this transport finding separate from the unproven close-save cause. A
follow-up needs controlled transport interleaving coverage and preservation of
the existing reply, deadline and helper-exit checks, without a storage refactor.

The native-expansion campaign's Linux sanitizer attempt at `3a5adb6` again reports
an indeterminate BindToClose write in the unchanged basic persistence fixture,
with no unexpected sanitizer report. This does not establish the receive/exit
race as its cause. Retain the failure and separate disposition in the
[campaign journal](gl-053-native-development.md). The transport correction does
not establish the cause of that separate missing-value observation.

## GL-049: Typed native game authoring

Baseline `5d5bb84` has Node-only Instance handles and a narrow Variant bridge;
`_InstanceNew` discards non-Node resources. Relay Siege constructs its arena,
materials, UI/audio and local cloth in GDScript. This is a source-verified
authoring limitation, not a claimed sandbox vulnerability or reproduced crash.

The [campaign journal](native-authoring-development.md),
[ADR-014](adr-014-native-scene-authoring.md) and [API](native-scene-api.md) define
the isolated implementation. Fixed-family SceneScope construction keeps existing
ObjectID/VM identity, provides typed resource ownership, and migrates the game's
ordinary construction into Luau. Implementation starts at `b8c09bc`; `b6b21a0`
corrects the environment enum and `81cd1c5` corrects dedicated startup's client-UI
wait. The [qualification record](native-authoring-qualification.md) and versioned
receipt establish native Windows/Linux, full-native sanitizers, actual Windows
local/listen/dedicated play, recovery/menu teardown, accepted native candidate
`42987296894` and extracted game package `43005466053`. Both accepted Windows
libraries and the companion match the rendered inputs exactly.

Resolved within this fixed-family API scope and [integrated normally](gl-049-main-integration.md),
preserving all 15 commits on `feature/luau-native-authoring`. No universal Godot API parity is claimed. Synchronous trusted resource
loading, unsupported native families/serialization/analyzer declarations,
Windows LSan and graphical/device limits remain documented. The original
candidate failures and independent GL-050 finding are preserved, not relabeled
as fixed by source implementation or the successful retry.

## GL-048: Relay Siege publication readiness

Accepted-candidate rendered listen/dedicated replays at game source `e65e3b8`
pass their functional checks, but log `Rules:108: Remote peer not ready` during
joining. `Publish` used FireAllClients, whose native validation rejects the
broadcast before commit when a destination has not completed publication.
The game driver reports functional outcomes; its PASS does not establish absence
of script diagnostics. Preserve the raw first replay instead of relabeling it
diagnostic-clean.

The caller now uses the existing FireClient API per live Player, deferring only
the exact native peer-not-ready error until the next current snapshot. Other
errors propagate unchanged. No accepted reliable work is discarded, no retry
queue or readiness authority is added, and one negotiating peer cannot prevent
updates to ready recipients. Native transport/admission stays unchanged. Real
rendered listen/dedicated replay at `0ecc2b5` passes 55/57 checks with no unhandled
script diagnostics. Four known engine retired-channel diagnostics remain under
GL-017/018 limits. The [receipt](evidence/gl044045/qualification-2026-11-09.json)
separates the original diagnostic-bearing replay from the corrected one.

## GL-047: Legacy cancellation fixture retires the owner too late

Windows native run `42752081142` builds successfully, then reports bare FAIL in
Dedicated client2. Its old log does not distinguish the canceled-invoke flag from
wrong-role execution; retain that attribution limit. The
[retained failure](evidence/gl044045/native-windows-lifecycle-failure.txt) and
[controlled reproduction](evidence/gl044045/network-retirement-control.json)
remain separate from the math fixes and GL-046's file publication corrections.

On DockerPC's unchanged Release adapter, a diagnostic eight-actor run passes.
Adding a deliberate 250 ms client stall makes both Dedicated clients resume the
pending invoke after `queue_free()` is requested but before tree exit. Wrong-role
flags stay false. ScriptNodeBase retires the execution owner in
`NOTIFICATION_EXIT_TREE`; requesting queued deletion alone has not done so yet.
This establishes the fixture timing mechanism, not the original missing flag.

The correction removes the victim script and retiring NetworkService from the
tree before queuing destruction. Assertions and deadlines remain unchanged;
failure diagnostics identify the two previously silent conditions. Corrected
normal/delayed controls each pass eight actors, and the unmodified corrected
fixture passes 16 actors over two repetitions. Fresh Windows/Linux native
`42755853334` passes all 141 actors at `e65e3b8`, including this corrected fixture.
The historical missing failure flag remains unproven; this closes the controlled
retirement race within those tested profiles, without relabeling the old run.
No production code, callback ownership policy or networking authority changes.

## GL-046: Character and security qualification marker publication

Windows Debug candidate `42744369456` fails reconnect at `States()[0]`, despite
a later PASS marker/zero exit; strict checking rejects the GDScript error. Its
retained artifact and the bounded correction are in the
[follow-up journal](gl-044-045-relay-development.md#retained-candidate-failure-and-bounded-fixture-correction).
A native Godot FileAccess control confirms that opening the final marker path
exposes an empty payload before close. The historical empty read is inferred,
not directly captured. Mark now uses the existing fixture pattern of a completed
temporary file plus same-directory rename. Production/authority code and all
gameplay assertions/deadlines remain unchanged. All four candidate profiles at
`4510ab4` and fresh Windows/Linux native at `e65e3b8` pass with both completed-file
writers. This does not reclassify the failed attempts as accepted. A second Linux Release
candidate failure records peer zero in NetworkSecurity's wrong-recipient setup;
that fixture had the same publication gap. Its writer receives the same narrow
correction, preserving all authority assertions and chat token expectations.
The retained journal distinguishes the resulting valid broadcast relay from an
actual forged-sender admission. No production authority code changes.

## GL-045: Vector3 method calling convention

The [focused follow-up](gl-044-045-relay-development.md) at `30682a3` fixes colon
argument selection and roots retained bound receivers as userdata upvalues while
preserving legacy dot calls. The native baseline fails six checks; corrected
Release math and 107-check Character fixtures pass, as does actual rendered
Relay Siege gameplay. Windows/Linux core/native, matching-host full-native
sanitizers and all ten candidate gates pass for the recorded inputs. Actual
Windows SCons-production game replays at `0ecc2b5` also pass. The
[receipt](evidence/gl044045/qualification-2026-11-09.json) preserves exact fixture
revisions and the unsupported sanitizer/device profiles.

Historical discovery in the original game campaign:

Relay Siege's controlled ray trace gets approximately 564 instead of 24 from
`Offset:Dot(Direction)`: the native bound closure in
`src/core/luau_value_bindings.cpp` reads argument 1, which colon syntax supplies
as self. Dot-style `Offset.Dot(Direction)` is the currently supported call.
Cross and Lerp use the same bound-closure argument convention in source.
The game uses immediate dot-style calls with a live local receiver; standard
Roblox colon compatibility and retained value-method lifetime remain separate
native-binding follow-up work, not a math-framework refactor in this campaign.

## GL-044: Native CFrame shape differs from stdlib CFrame

The [focused follow-up](gl-044-045-relay-development.md) at `30682a3` reuses the
existing stdlib constructor for native getters, preserving coordinate tables,
matrix layout and write authority. Native rotated Part/Camera/snapshot checks
and actual rendered production gameplay pass, alongside both platforms'
core/native, matching-host sanitizer and four-profile candidate qualification.
The [receipt](evidence/gl044045/qualification-2026-11-09.json) separates unchanged
native inputs from later fixture/game-only changes. The
historical discovery below refers to the original game source.

Relay Siege's actual gun initially sends nil when reading
`Workspace.CurrentCamera.CFrame.LookVector`. The native Node3D getter in
`src/core/luau_api.h` returns raw matrix/position tables, whereas stdlib
`CFrame.new` in `src/core/luau_stdlib.h` provides LookVector/RightVector/UpVector
and methods. The controlled game trace observes four Shoot requests with nil
direction and correct server rejection. The game obtains the same native
direction from `(-m02,-m12,-m22)` and constructs a native Vector3, keeping strict
server input validation. Unifying the returned CFrame contract is a separately
scoped follow-up; this campaign does not replace or refactor the math binding.

## GL-043: Physics query and impulse compatibility

**Resolved within scope at `3227290`; [integrated normally](gl-043-main-integration.md).**
An isolated native probe reproduces ignored Include/Exclude filters and zero
native Vector3 linear/angular impulses. The one-header correction passes 20
focused physics checks inside the existing native fixture, both platforms'
core/native and full-native sanitizer gates, and all four Debug/Release
non-publishing candidate profiles and extracted packages. See the
[contract](gl-043-physics-api.md), [journal](gl-043-development.md) and
[receipt](evidence/gl043/qualification-2026-11-09.json). Other raycast options
and GL-044/045 remain separate. The original game discovery
below describes the pre-fix native profile.

Discovered during [Relay Siege development](e2e-game-development.md). Source in
`src/core/luau_api.h` implements Workspace RaycastParams.MaxDistance, but does
not apply FilterDescendantsInstances or FilterType. ApplyImpulse and
ApplyAngularImpulse read components only from a Lua table; the native Vector3
userdata branch is absent. This is a source-verified contract discrepancy,
not a reproduced memory-safety vulnerability. No broad physics refactor is
included in the game campaign. The game uses a table for its rigid-body impulse
and configures cooperative player hulls as query-invisible, retaining their
native world collision mask. Eye-origin hitscan has native world occlusion.
Full raycast-filter/impulse argument compatibility remains follow-up.

## GL-042: UserInputService GUI routing flag

Integrated by normal merge `f3c5757`, preserving the qualified source and all
four commits. The [integration record](input-main-integration.md) verifies the
previously outstanding four-profile and extracted-package gates. Device and
graphical limits below remain; the source-branch evidence is retained.

The input campaign confirms that actual raw event paths called `_fire` without
its game-processed argument, always defaulting false. DockerPC's native focused
LineEdit probe establishes that GUI consumption occurs after `_input`, before
`_unhandled_input`. The feature branch introduces a shared bounded post-GUI
commit barrier for raw and semantic input, preserving arrival order and consumed
releases. This deliberately changes raw callback timing; see the
[migration contract](input-actions-api.md#userinputservice-migration) and
[development evidence](input-action-development.md#final-qualification-of-the-controller-implementation).
Native Control replay verifies consumed/unconsumed press/release ordering, owner
retirement and the new post-GUI barrier. The separate Windows rendered controller
also verifies that typing into a focused LineEdit does not move the body. This is
synthetic-event coverage, with physical devices and OS capture still unqualified.
Windows Release and full-native ASan, plus hosted Linux native/ASan-LSan, pass at
`c037472`; the journal records final hosted results and remaining limitations.
Main is unchanged.

## GL-041: Raised authoritative startup remains airborne during walking

Windows full-native ASan at `20a1592` and `436af11` captures a local client at
height 1.25/0.9375 with vertical velocity -18/-18.75 after the walking warmup.
The trusted fixture's lane placement starts at height 5. Waiting for a nonzero
lane alone does not resolve the behavior. The
[evidence](evidence/gl041-raised-spawn-evidence.json) retains actual failed
assertions, local samples and original JSON hashes. No sanitizer report, memory
defect, precise grant/reconciliation cause or GL-039 regression is established.

Use the known floor-level lane origin for walking presentation, retaining real
physics, both ground checks and all animation/movement assertions. This isolates
that fixture; it does not fix or close the raised-startup finding. Investigate
initial grants, later reconciliation and simulation/frame timing separately,
preserving GL-007 authority and production physics. Existing single-character
jumping/falling coverage remains required. No production change is made here.

## GL-040: Coincident presentation spawns produce airborne host motion

At `5ea6345`, failed Windows Release presentation evidence shows the listen
host at approximately `(72.7,161.9,-8.1)` while the other characters remain near
the floor. Its local grounding/remote walking-cycle comparisons fail. Grounding
before movement does not resolve the interaction. These are actual captured
transforms, not proof of the precise physics cause or a GL-039 regression.
The [retained failure receipt](evidence/gl040-presentation-failure.json) includes
all three actors' failed assertions, captured transforms and original JSON hashes.

The presentation fixture uses coincident spawns. Assign distinct parallel walking
lanes through the existing trusted-server CharacterAdded/Position API, retaining
real physics, ground checks and every motion/animation assertion. This isolates
the intended walking observation; it does not fix or close the overlapping-body
finding. A separate reproduction should distinguish collision recovery and
moving-platform velocity before changing production physics. Keep native
authority, CharacterBody3D behavior and qualified collision semantics intact.

## GL-039: Structural convergence under a 32-peer burst

**Status: INTEGRATED AND CLOSED within the repeated headless 32-peer
Release scope.** The [bounded FIFO fix](https://github.com/gmoddev/GodotLuau/commit/7c06e08e4a1f99ecb3e7c1efc6e6ad7ef2ca91cf),
[first-frame progress correction](https://github.com/gmoddev/GodotLuau/commit/01ec4eb521576b8d0c477c8f78ade8d9f99afc47)
and [60-KiB byte bound](https://github.com/gmoddev/GodotLuau/commit/8ea2470b0ca2e358f39bf47f082c12e669d029f2)
preserve accepted barriers, native admission, the 64-frame application-ACK window
and existing time/resource limits. The strengthened native fixture retains all
sixteen same-turn transitions and the 7,500-byte payload.

All four candidate 32-peer trials pass after authorized temporary capacity
recovery, with zero replication failures. Worst-client final-counter convergence
is 0.299/0.226 ms at 64 objects and 75.159/699.938 ms at 512 objects. The
[Release receipt](evidence/gl039-release41-qualification.json) retains the failed
legacy large-world warmup and independent candidate runs; it does not establish
a fresh paired large-world frame speedup.

Native fingerprint `6698ad26...` is unchanged through final fixture revision
`903b10c`. Full Windows/Linux sanitizer workflow `42049370120` passes with 23/24
checks, 85 core cases, 131 native actors and no unexpected reports per platform.
Ordinary core/native at `37a5e4e` and four source profiles/two packages at
`fa0d431` remain valid within their identical-production scope. The
[final verification](evidence/gl039-final-verification.json) records exact
revisions, reviewed artifacts and changed-fixture hashes. The
[journal](networking-foundation-2-work.md) preserves blocked and failed attempts.
GL-040/041 remain separate open Character findings. No refactor, wire change,
main merge, release publication or updater distribution is included. No general
latency, graphical or 64-peer qualification is claimed.

At `436850a`, both 32-peer Release trials pass the mixed
workload in 64- and 512-object worlds with zero replication failures. Final
structural convergence nevertheless takes 6.58–6.96 seconds after coordinated
close; the 64-object baseline takes 0.096–0.399 ms. Required reparent barriers
remain ordered. Frame p95 improves in that paired small world, so frame cost
and structural convergence must be assessed separately.

The [receipt](evidence/networking2-436850a-release-qualification.json) retains
all cases, source/product identities, wire/queue diagnostics and actual cleanup.
Convergence stays inside the existing ten-second failure policy in these runs.
No exact bottleneck attribution or general latency guarantee follows from this
measurement. A follow-up should profile barrier production/draining and the
coalesced tail before selecting an optimization; preserve every required
transition, native admission, fairness and existing limits. Do not increase
limits or drop barriers to improve this number.

## GL-038: ObjectValue read after target destruction

**Status: CLOSED on the unmerged campaign at `436850a`.** The focused shared
getter correction passes actual native/Luau target-destruction reads, unfinished
sweep mutation and server replacement. Fresh Windows/Linux core, ordinary native
and full-native sanitizer matrices independently verify: 85 core cases and 131
native actors per profile, with 23 Windows/24 Linux sanitizer checks and no
unexpected reports. The [receipt](evidence/networking2-436850a-runtime-verification.json)
preserves required log/source/product/instrumentation hashes and separately lists
two absent ephemeral GL-003 mailboxes. All four source profiles and both extracted
packages also [verify](evidence/networking2-436850a-candidate-verification.json).
Larger-peer performance/admission also verifies within the GL-034 profiles below;
GL-039 records the measured convergence limitation.

Historical reproduced failure:
The strengthened GL-034 native fixture retains an ObjectValue, destroys its
target after the source sweep cursor passes, and preserves the value for later
native/Luau reads. Windows Debug ASan on native fingerprint `34e4ff3d...`, DLL
`8b937315...`, fixture `c78993cf...` reports heap-use-after-free in
`godot::Variant::operator Object*()` / `get_object_instance_binding`, reached from
`RefreshReplicationRecord` at source line 143. The target was freed by the
SceneTree delete queue on the same main thread. Raw report SHA-256 is
`8e56bc427561db8776b75cbfb319858b869cf6d7244168ec290e449b299024e5`.
The coordinator stops the failed relevance profile and does not start benchmarks;
its entire owned Job is verified empty. This is an actual sanitizer finding,
separate from GL-037's historical fixture barriers.

Source inspection verifies the earlier projection and `RobloxValue::_push_value`
also convert the stored Variant without first validating its weak Node target;
an independent older-build crash has not been reproduced. The focused correction
validates in the shared `get_value()` method and uses that method for Luau reads,
so expired object values read as nil before pointer conversion. No ownership,
storage format, scheduler or automatic Changed-signal behavior is added.
The pinned engine's [Variant validity utility](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/variant/variant_utility.cpp)
uses `get_validated_object()`; the pinned godot-cpp conversion accesses instance
binding after extracting the raw object pointer. Preserve the target-destruction
case and verify both native and Luau getter paths under fresh sanitizers before
closing this issue or GL-034.

At `712ea47`, Linux's complete full-native sanitizer workflow reports success;
the ordinary Linux native job passes expired-value and replacement assertions
but fails its client-physics positive case. Artifact verification and a complete
fresh matrix remain required. Source review separately corrects captured control
revision labeling and orders runtime ownership through structural snapshots.
That discrepancy is source-verified; it is not yet an independently attributed
explanation of the intermittent physics failure. The fixture now requires the
exact requested owner and retains wrong-owner/generation rejection assertions.

## GL-036: Release benchmark omits setup and checks

**Status: corrected and checked on Windows Debug ASan and Release hosts.** The
first uninstrumented Release smoke exits before readiness: extension loading
and animation saving occur inside GDScript `assert` expressions, which Release
omits. This is a fixture defect, not failure to load the qualified native DLL.
Move those operations and input/sample/deadline checks into ordinary checked
calls. Luau payload/API assertions remain intact. Corrected Debug and Release
smokes pass both immutable products; subsequent Release comparisons retain
functional failures rather than silently passing them. See the
[release receipt](evidence/networking2-release-benchmark.json) and
[local checkpoint](evidence/networking2-scopeguard-checkpoint.json).

## GL-037: Full-native follow-up assertion failures

**Status: CLOSED on the unmerged campaign at `bd18580`.**
The focused fixture corrections pass 41 local ASan actors and fresh Windows/Linux
core, native and full-native sanitizer workflows. Independent exact-revision
verification checks 85 core cases per profile, 131 native actors per profile,
23 Windows/24 Linux sanitizer checks, 1,161 instrumented native units and three
core units per platform, with no unexpected reports. The
[receipt](evidence/networking2-bd18580-runtime-verification.json) preserves
missing ephemeral GL-003 mailbox identities separately from required logs.
Package/scalability acceptance remains separate; GL-034 is still open.

Historical failures and attribution:
At `0428413`, Linux fails Movement's airborne resynchronization comparison;
Windows fails its final native movement sample comparison and a Function
adversarial-response barrier. At `cbd91d0`, Linux passes Character and Function
groups but fails the legacy Dedicated `BothClients`/`BothClosed` barriers.
Detection controls pass and these retained attempts report no unexpected
sanitizer finding. Ordinary Windows/Linux native gates pass at both revisions;
the earlier `532650f` sanitizer matrix passes. Preserve this counterevidence and
the [failed receipts](evidence/networking2-sanitizer-follow-up-failures.json).

Windows Function client stderr proves a separate fixture race: the attack JSON
file exists while still empty, and the reader sets its one-shot flag before
parsing fails. Stage the complete metadata in a temporary file, close it, then
publish the final path. The corrected fixture passes six local ASan actors;
this does not resolve or suppress the Character/legacy barrier failures.
Do not classify the remaining failures as fixture-only or close them without
attribution and complete fresh checks.

Resume investigation identifies `RemoteFunction not ready` in the retained
Linux legacy client: its startup barrier checked only Event publication. The
focused correction requires both endpoints. Character functional transport now
uses the existing unthrottled profile in 3D as well as 2D, retries the final pose
until the observer comparison completes, and first measures near-ceiling ascent
before testing a proposal larger than remaining headroom. The old 0.2-unit
proposal could still be valid. Production Character authority is unchanged;
fresh native/sanitizer results are required before closing this repeatability gap.

## GL-035: Empty-catalog listen Client can remove scope-root ancestor

**Status: CLOSED on the unmerged campaign; exact-revision matrix verified.**
The `cbd91d0` fix passes all four 85-core/131-actor package profiles and extracted
Windows/Linux packages ([receipt](evidence/networking2-cbd91d0-candidate-verification.json)).
The subsequent `bd18580` revision also passes both ordinary native and full-native
sanitizer matrices, including the empty-catalog guard
([receipt](evidence/networking2-bd18580-runtime-verification.json)).
On native fingerprint `738a60cf...` / DLL `53a1f38f...`, an actual LocalScript in
an opted-in listen host with no registered instances or Character authority can
execute `game:Destroy()` and remove the server's shared scene. The headless
Windows Debug ASan process exits cleanly without an unexpected sanitizer report;
this is authority failure, not a reproduced memory defect. Fixture SHA-256 is
`34fb006757c72edd87761abbc0a6e3c62a893cf96d43c4d60597199062e3b5bf`;
captured baseline stdout is `5f2981842e97902433b51fc1e8d3b0b43d28e885741017b8e94679249489b9b8`.

The existing Client boundary protects registered objects and their ancestors,
but checks captured scope roots only for exact identity. The focused fix also
rejects structural mutation of their live native ancestors, independently of
catalog population. Ordinary Client attribute writes retain their existing path.
The [required native regression](../tests/runtime/RelevanceRootGuard.gd) checks
the empty precondition, actual Client mutation, preserved scene identity and
ordinary callback completion after rejection. The required native matrix grows
from 130 to 131 actors; no existing actor/assertion is removed. This experimental
protocol remains unmerged.

## GL-034: Opt-in relevance mixed-world performance regression

**Status: CLOSED on the unmerged campaign at `436850a`, within the documented
qualification profiles.** Current four-profile/package, core/native and
full-native sanitizer matrices independently verify. The
[Release receipt](evidence/networking2-436850a-release-qualification.json)
establishes 16 passing candidate configurations: repeated 1/16/32-peer,
64/512-object worlds, plus impaired one-peer/512-object and 16-peer/64-object
workloads. There are zero candidate replication failures, unexpected report
files, successful-case stderr files or resource-guard aborts. Twelve baseline
configurations pass; three unchanged-baseline large-world warmup failures are
retained separately. Those failures do not produce paired speedup claims.

Release candidate server frame p95 is 8.44–9.44 ms at 1/16 peers and
10.87–12.14 ms at 32 peers. All four hosted workflows independently verify at
this source. See the [measurement record](networking2-benchmarks.md) for exact
trials, CPU/wire/convergence data and the GL-039 follow-up. This closes the
reproduced catalog frame-cost regression; it does not establish general
64-player, graphical or long-duration performance qualification.

The earlier fresh paired
512-object Windows ASan trials give candidate frame p95 9.61/9.98 ms versus
main 9.34/9.45 ms, with zero replication failures. Final client structural
convergence is 711.104/84.991 ms, an explicit asynchronous tradeoff. All seven
strengthened relevance actors pass locally, including unfinished-sweep mutation,
exact ownership, expired values and server replacement. See the
[receipt](evidence/networking2-436850a-asandebug-benchmark.json).

Historical baseline: two paired
one-peer Windows Debug ASan trials compare exact main `9f52b27` with relevance
fingerprint `a7c63d0...`, using the same admitted host/compiler and public/native
workload. At 512 objects the candidate server frame p95 is 414.5/426.2 ms versus
12.2/12.9 ms, and Fire/echo RTT p95 is approximately 1.44 s versus 37.4/41.1 ms.
The 64-object candidate also regresses. Functional assertions pass; this does not
qualify scalability. The [measurement record](networking2-benchmarks.md) retains
resource-blocked larger configurations separately. Raw archive 6 SHA-256 is
`f183c5a502d82e6dea71ea4bff4c8ecd9ab5000f2785b9d8c62de2aa32ca00e3`.

Initial candidate hypotheses included the shared Client write-boundary world
scan and catalog refresh work. Focused timings and a denial-order probe were
required to establish attribution. Native authority,
reliable structural ordering, resource bounds and test assertions remain required.

Profiling excludes the write-boundary hypothesis and attributes the dominant
cost to catalog refresh; early exclusion and ancestry reuse already reduce the
512-object ASan diagnostic refresh cost from about 81 seconds/256 calls to 23
seconds/280 calls, without establishing acceptable paired performance. Resume
corrections avoid full refresh on unpublished reparent, measure periodic cadence
from refresh completion, and start the unchanged peer submission budget after
maintenance. Published barriers still refresh synchronously. At that checkpoint,
new paired measurements, larger-world admission and full qualification remained
required; the current proof above supplies the targeted acceptance facts.

A bounded maintenance candidate now reuses source records/index memberships
across 64-item/two-ms cooperative turns. Selection waits for a completed sweep;
accepted frames still drain. Published reparent refreshes its bounded affected
closure, and native unregistration removes its cache immediately. Expanded actual
ENet coverage passes mutation/reference destruction after cursor advance and
service replacement during unfinished work at `436850a`. The original campaign
explicitly authorizes this necessary bounded refactoring. Current qualification
above supersedes the earlier pending state while preserving its negative results.

## GL-032: ObjectValue lacks an Instance bridge

**Status: closed on the unmerged campaign at `532650f`.**
`WriteLuauInstanceProperty` delegates to the intentionally scalar/Vector3/Color3
converter. It cannot assign a Godot Instance to ObjectValue.Value; the matching
generic getter cannot return an Instance either. Legacy shadow encoding could
still carry the write, so this is not a claim that every historical wire
reference failed. The new source projection exposed the discrepancy when the
native value remained nil despite its encoded shadow.

The focused fix handles ObjectValue's live Instance/nil property in its existing
API owner; it does not broaden the generic converter or expose reflection.
Native projection reads the live authorized target identity, normalizes missing
or unavailable weak targets to nil and tracks registration changes. The actual
ENet relevance fixture asserts source Luau assignment/readback, cross-peer
reference closure, clearing and cyclic reference creation/retirement. Windows
Debug ASan passes the expanded six-actor fixture at native fingerprint
`a7c63d0ea12364a85a6358863dc0d3f5e77cbb33a6ccbc219f358564fac710d7`.
Windows/Linux Debug/Release, ordinary native and full-native sanitizer gates
also pass, with exact-revision [runtime](evidence/networking2-532650f-runtime-verification.json)
and [candidate](evidence/networking2-532650f-candidate-verification.json) receipts.
This scoped fix does not close the broader relevance/performance campaign.

## GL-033: Local RemoteEvent pressure replay loses readiness

**Status: OPEN; test/runtime attribution remains under investigation.**
DockerPC replay of the pressure/queue-age fixture fails after the pressure stage,
then cascades into final-sequence/replacement assertions. A control replay on
the previously qualified GL-030 binary also fails: native fingerprint
`3ba654399e4af64bb5da99b6befe9ff4a2137fb6af5d0045649fc498498771dc`,
DLL `677df7f2d71e8941a16d3c72a2de4f4bcc86c26fb8b54bf7ece90c952a072310`.
No unexpected ASan report occurs in these runs. This does not establish a new
relevance regression or a security defect. Exact-revision GL-030 hosted gates
remain successful counterevidence. Preserve the failed logs, investigate actual
native session/readiness transitions, and keep all assertions required.

## GL-031: Late join omits runtime children of static parents

**Status: closed on the unmerged campaign at `532650f`; original failure
reproduced in two independent admitted-host ENet processes.**
The campaign seeds existing static prerequisites and adds a production two-actor
fixture covering deeper/later-ID ancestry, identity-preserving reparenting,
removal and replacement. All four Windows/Linux Debug/Release profiles and both
full-native sanitizer profiles pass the two-actor fixture; the six-actor opted-in
relevance fixture separately exercises reconnect. Exact [runtime](evidence/networking2-532650f-runtime-verification.json)
and [candidate](evidence/networking2-532650f-candidate-verification.json) receipts
retain product/source/host and packaging identities.
The existing `_rep_sync_peer` collects static identities separately, but starts
its topological `sent` set empty. A runtime child whose parent is in
`net_instances` waits for that parent to enter `sent`; static parents never do.
The controlled [fixture](evidence/gl031-baseline/ReplicationBaseline.gd) creates
one runtime Folder under a static Folder before join and another directly under
ReplicatedStorage. Only the direct child arrives. The
[receipt](evidence/gl031-baseline/evidence.json) records matching static identity,
native/product/host hashes and clean actor exits. The generic replication source
is unchanged from main; this experiment uses the GL-030 native snapshot rather
than an exact-main binary. This is a correctness defect, not a security claim.

**Closure:** seed existing static prerequisites, preserve parent-before-child
ordering and verify both children, deeper ancestry, reconnect and destruction
through actual native transport. The per-peer campaign must retain this case.

## GL-029: Application Remote delivery has no unified bounded publication contract

**Phase 1 qualified:** [qualification](remoteevent-phase1-qualification.md) and
the [versioned receipt](evidence/gl029-phase1-ci-verification.json) verify source
`eec2397`: Windows/Linux Debug/Release (80 core/116 native each), hosted ordinary
native and full-native sanitizer profiles, plus exact SCons products and both
extracted companion packages with non-publishing acceptance. Controlled ENet
throttle/readiness fixtures address transport loss/startup assumptions without
changing production carrier defaults. A reproduced Unicode dictionary-key defect
is fixed by one StrictRemote-only UTF-8 conversion line; actual ENet Server/echo/
Wait assertions pass. Other carriers and persistence encoding remain unchanged.
No refactor or main merge is included. Earlier failures remain in the record.

**Status: INTEGRATED AND RESOLVED within ADR-008/009's admitted-host qualification scope.**
Normal main merge `6a7fedf` preserves retained
`integration/gl-018-gl-029-remoteevents` at `d6afbe6`; see
[fresh main verification](gl018-gl029-main-integration.md). The original checkpoint remains
preserved; see the [handoff](remoteevent-phase1-handoff.md).
The [completion investigation](remoteevent-completion-work.md) and
[native admission decision](remoteevent-native-admission-decision.md) reproduce
finite native retention on the stock host. Stronger native-backpressure closure
uses the narrow patched-host contract approved on 2026-11-03, recorded in
[ADR-009](adr-009-bounded-remote-delivery.md). Bounded queues, native call-context
validation and sequencing are implemented and qualified at runtime `6e29c86`,
with the packaging correction at `3c552e6`. The
[completion record](remoteevent-completion-qualification.md) and
[receipt](evidence/gl029-completion-verification-2026-11-03.json) verify all four
Windows/Linux Debug/Release source profiles (81 core / 116 native actors each),
ordinary native, matching-host full-native sanitizer, exact packet/ownership
boundaries and both extracted packages. Actual UDP loss/reorder and two paired
1/16/32-peer performance trials are retained. Response latency increases; 64-peer
performance is unqualified. Earlier Character observation failures pass unchanged
replays without an asserted root-cause fix. Main integration preserves this
qualified tree; fresh CI is tracked separately. Baseline assessment
source is `83cd0887968d73d61d050650718d8ada6e124579`; research is retained at
`9ea782bb739cc35deba06474a82582a12529df6d`.

The baseline boolean/path RPC converged reliable/unreliable event handlers without
target-mode, publication-generation or receive-size/aggregate admission checks.
FireAllClients ran local callbacks before encoding/size validation; retained event
closures captured raw native pointers. Existing role checks, GL-004 budgets and
qualified GL-006/007/020 paths remain counterevidence to a blanket networking
failure claim. The original findings were source verified, not new exploit proofs.

Phase 1 replaces those event boundaries with the narrower
[ADR-008 contract](adr-008-remoteevent-publication.md). The
[qualification record](remoteevent-phase1-qualification.md) preserves failed
attempts, an actual same-named-child precedence failure and the correction to
the research's assumed legacy identity. ClassName/IsA keep their actual native
legacy behavior. Native constructor/domain provenance prevents Client-created
listen-host endpoints from acquiring publication authority. No general mutation
gateway or unrelated replication redesign is implied.

**Closure:** bounded queues, sequenced stale rejection/unsent supersession,
native retained-data admission, complete-RPC MTU and lifecycle/failure outcomes
pass the linked qualification. Application queue and native ownership evidence
remain distinct. Deployment requires the admitted patched host and GER2 peers;
native caps exclude total RAM, receive predecode and control/ACK storage. GL-018's
sanitizer limits remain intact. No unreliable RemoteFunction modes or GL-030
timeout changes belong to this work. Releases and updater distribution remain
disabled.

## GL-030: Default RemoteFunction waits have no finite terminal deadline

**Status: INTEGRATED AND CLOSED within ADR-010; historical qualification at `2296c966937223994a94cc2f15af29e9f829557b` retained.**
Fix commits `a7339e0`, `513faec`, `9192bd1` and `2f08e44` establish
ADR-010's finite monotonic deadlines, full-width checked identities and exact
wait/session/publication retirement. Regression strengthening and fixture
precondition corrections are retained through `2296c96`. All four exact-revision
hosted workflows pass: core `41756648637`, native `41756648640`, full-native
sanitizers `41756776065`, candidate `41756783923`. The
[runtime verification](evidence/gl030-2296c96-runtime-verification.json) and
[candidate verification](evidence/gl030-2296c96-candidate-verification.json)
record independent artifact/source/product checks, 81 core cases, 122 native
actors per profile and 109 focused Function assertions. Five generated Linux
profile logs and two ephemeral filesystem mailboxes are absent from the
downloaded sanitizer archives; their exact names and expected hashes remain in
the receipt. Required captured actor logs, outcomes and sanitizer controls were
verified. This closure does not qualify subsequent relevance changes.

Historical baseline and earlier pending status follow for counterevidence.
Exact main's valid ENet handler leaves its caller uncompleted after 70,006 ms in
the controlled [campaign baseline](networking-foundation-2-work.md). Candidate
full-width/exhaustion and terminal-outcome fixtures pass in development; complete
latest-revision platform/native/sanitizer qualification remains pending.
Networking Foundation 2 is implementing the separately authorized
[ADR-010 terminal contract](adr-010-remotefunction-terminal-outcomes.md) on
`foundation/networking-2`. See the [running journal](networking-foundation-2-work.md).
This remains open pending actual qualification; the baseline below is retained.
Baseline source `83cd0887968d73d61d050650718d8ada6e124579` is unchanged by the
event-only Phase 1 behavior.

Public invokes pass timeout 0.0. GLDomainHost warns after ten seconds but expires
only positive deadlines. NetworkService separately erases expectation/response
records older than sixty seconds without completing that waiting coroutine.
The global int64 request counter is narrowed to int for RPC transmission and has
no checked exhaustion rule. Expected-peer response validation, guarded owner
cancellation, disconnect/service failure completion and legitimate yielding
handlers already exist and must be preserved.

**Closure:** separately approve finite-deadline compatibility, preserve reliable
request/response and current Player/handler APIs, use checked session-scoped
full-width correlation and detach/settle each request once before callbacks.
Qualify missing replies past GC, timeout/response/cancel races, manual resume,
disconnect/reconnect and owner/Remote/service retirement. See the
[research design](remoteevent-delivery-proposal.md#remotefunction-stays-separate).
Phase 1 does not claim this target is already implemented.

## GL-028: Fade update tolerance can retain visible first-person dither

**Status: integrated; fixed and rendered-qualified within the exercised scope.**
Normal merge `bee07b7d4fc948556e69aa2ae0306b0ad1a52fb4` preserves the qualified
runtime and regression inputs; see the
[fresh integration record](character-presentation-main-integration.md). Original
DockerPC NVIDIA custom first-person captures retained faint dither pixels near the
bottom after the rig had mostly faded. The baseline `RobloxPlayer::_update_fade` returned when
the uniform delta is below 0.002, while camera smoothing approaches the fully
hidden endpoint. A cached value just below 1 could remain indefinitely; the shader
correctly discards all pixels only at its full endpoint. The original `>0.95`
fixture proves substantial fade, not complete invisibility. A stronger exact
endpoint regression fails on the immutable main Release DLL for both R6
(`0.999400854110718`) and custom (`0.999045968055725`), with six equal mesh
uniforms in each case after the bounded settling interval. Endpoint clamping and
an endpoint exception to dirty-update suppression pass actual rendered Debug
and Release R6/custom regressions at runtime implementation
`2bd43741f82fd5308e01e5bb88462e17ae256fb7`, with all six uniforms exactly 1.
Both hosted platforms pass the final 110-actor native suite at fixture revision
`6b6a8a29803d47687090b341019155fc770a81b6`. See the
[work record](character-presentation-performance.md); no new shader, authority
or material ownership model is introduced.

## GL-027: StarterCharacter prototype geometry remains in the live render tree

**Status: OPEN, rendered authoring limitation.** DockerPC's actual NVIDIA/OpenGL
custom-rig first-person capture
(`baseline-graphical-v4/custom/presentation-custom-single0-first-person.png`)
shows prototype geometry after the owned Character has correctly faded. Source
inspection confirms StarterPlayer is a native Node and its Node3D visual template
remains in the live tree; the clone factory resets the copied Character position.
There is no automatic render isolation for the original template. This is not
evidence that the owned rig's first-person fade failed.

The qualification fixture places the source prototype outside the playable view
at `(10000, 10000, 10000)` and asserts that the actual cloned custom rig is used.
That authoring workaround does not close this finding or implement template
culling. Existing content must keep template geometry outside the playable view
or explicitly manage visibility without hiding the playable clone. A general
template-isolation change needs a separate compatibility decision. See the
[rendered work and evidence record](character-presentation-performance.md).

## GL-001: Retained WaitForChild closure can outlive its Node

**Evidence:** `src/core/luau_script.h:988-1042` installs the actual metatable
lookup. At `1015` it captures `Node*` as lightuserdata; invocation at `1017-1023`
checks only non-null before dereferencing. `src/core/luau_api.h:375-391` exposes
destruction that queues the object for freeing. A retained method closure can
survive a different node's destruction while its calling script VM remains live.

**Consequence/limits:** Potential stale native dereference, contradicting universal
ObjectID-safety claims. Ordinary wrapper resolution is safer
(`gl_runtime.h:98-111`), but does not protect the captured pointer. No crash or
exploit was reproduced; security triage remains `needs_review`.

**Fix boundary and closure:** Replace the persistent native capture with stable
identity and live/type resolution on invocation. Test retaining the method,
freeing the target across a frame, then invoking it from a surviving VM. Also
test valid lookup, pending wait, timeout, and script shutdown. Define the stale
target result and prove no native crash or abandoned coroutine.

**Migration update (2026-10-26):** WaitForChild now resolves its receiver's
ObjectID at invocation and records guarded waits with the domain host. The
headless native fixture passed valid/pending/timeout paths, destruction while
waiting and retained invocation after target destruction (returns nil), plus
scene replacement. See [validation](shared-domains-validation.md). Kept open:
the Godot adapter/executable were not sanitizer-instrumented and this does not
establish universal binding lifetime safety. Original evidence above is historical.

**Resolution (continuation qualification):** The full Linux engine, pinned
bindings, adapter and Luau now run with ASan/LSan. Ten repetitions (80 native
process results) cover the retained closure after target free, valid/pending/
timeout cases, destruction while waiting, script cancellation and scene
replacement. Windows Debug/Release pass the same native fixture. The stated
capture's closure criteria are satisfied; GL-018 separately bounds Windows native
sanitizer coverage. See [continuation evidence](shared-domains-validation.md#continuation-qualification-2026-10-26).

## GL-002: NetworkService method closures retain service pointers

**Evidence:** `src/core/luau_api.h:2333-2353` captures `nsvc` and later calls
members after only a null check. `2410-2429` repeats the pattern for queries.
These bindings are reached through `godot_object_index` from the script metatable.

**Consequence/limits:** Retained methods may outlive a destroyed/replaced service.
Non-null is not live-object validation. Actual service teardown timing and native
failure were not exercised; security triage is `needs_review`.

**Fix boundary and closure:** Use ObjectID-backed captures and resolve the expected
type at invocation. Cover service destruction/replacement with a surviving script,
stored getters and mutators, valid behavior, and pending callbacks. Review other
captures separately rather than claiming this entry covers all bindings.

**Migration update (2026-10-26):** NetworkService method closures now retain
ObjectIDs and resolve the expected service type through GLNodeUpvalue. Native
listen/network fixtures passed valid getters/mutators, retained GetPeerId and
Disconnect after service destruction, yielding callbacks and cancellation of an
outstanding response. Kept open for broader native adapter lifetime/sanitizer
qualification; these focused results do not qualify every binding.

**Resolution (continuation qualification):** Added live service replacement
while a surviving script retains getters/mutators; stale methods cannot act on
the replacement. A newly reproduced pending-invoke teardown failure is fixed by
disconnecting/failing pending calls at active service exit. Windows Debug/Release
and full Linux ASan/LSan lifecycle stress pass these paths. The stated capture's
criteria are satisfied; this does not qualify every service binding. See
[continuation evidence](shared-domains-validation.md#continuation-qualification-2026-10-26).

## GL-003: FileAccess global bypasses DataStore's role guard

Development on `security/gl-003-filesystem-capabilities` records actual native
Windows/Linux baseline reproduction and boundary inventory in the
[work/qualification record](filesystem-capabilities-validation.md).
Native enforcement at `c3fc544a686b5d43bf67f0f5e864105957c52171` is fixed and
qualified on that branch. Final six 69-case core configurations, 195 full-native
actors and four SCons products each with eleven resource/filesystem actors pass.
Fresh hosted core `40881074709` passes all 69 cases per platform; native
`40881074701` passes all 39 actors per platform. All four downloaded artifact
digests, source/harness/engine identities and native log hashes are verified in
the linked record and manifest. Normal merge
`5ba96ad0ca74f63ac92910633ba1c0d4fd6050e2` integrates both commits with an
identical tree. Fresh Windows/Linux Debug/Release core passes 69 cases each and
Debug native passes all 39 actors per platform. Fresh main core `40970974054`
passes all 69 cases per platform; native `40970974142` passes all 39 actors per
platform, including GL-003 filesystem/service fixtures. Four downloaded archive
digests, exact merge/source/harness/engine identities and every native log hash
are verified. **Resolved within ADR-003's bounded native-storage authority
contract.** GL-005/009/017/018, adversarial GL-020, trusted project resources,
same-credential OS writers and native I/O/allocation limitations remain separate.

**Inherited review evidence:** `src/core/luau_script.h:1604-1642` unconditionally installs
`_FileAccess.read/write/exists/delete/list`; supplied paths reach FileAccess or
DirAccess without a native role, capability, or root check.
`src/core/luau_stdlib.h:627-633` rejects network clients only at the DataStore layer.

**Consequence/limits:** A running gameplay script can call the lower-level global
directly. This is not evidence that a remote player can inject script code, and
the supported hostile-package boundary is undocumented. OS/platform permissions
still apply. The original triage verdict was `needs_review`, rank 1 in that queue;
the new controlled native baseline now confirms the local gameplay exposure.

**Fix boundary and closure:** First specify trusted-host versus gameplay grants.
Enforce grants and canonical root confinement at native entry points, including
alternate path forms and failure paths. Test denied client/ungranted access,
absolute/traversal paths, permitted server persistence, and no partial mutation.
Keep any intentionally trusted host API distinct and explicit.

## GL-004: Explicit VM sandbox and execution limits

**Inherited evidence:** `src/core/luau_script.h:960-983` uses `luaL_newstate()` and
`luaL_openlibs()`. Targeted searches of `src/` found no sandbox initialization,
instruction-interrupt callback installation, or custom VM memory quota. Task and
callback execution resumes Luau synchronously; importer batching is unrelated.

**Consequence/limits:** No demonstrated isolation or protection against runaway
gameplay scripts. This does not prove a sandbox escape or disable Luau's internal
limits. No infinite loop or exhaustion test was executed. Security verdict:
`needs_review` pending the supported trust/resource contract.

**Fix boundary and closure:** Define grants, per-VM/domain resource accounting,
bounded resume/cancellation, and error propagation before implementation. Add
headless bounded tests for non-yielding work, excessive allocation, denied globals,
valid tasks, and shutdown. Run failure cases with crash UI suppressed.

**Development status:** `runtime/gl-004-execution-limits`, based on main
`8aec90252d10f7dcec97e97423ca390467087711`, implements explicit intrinsic/root
sandbox sealing, private owner environments, shared attempt deadlines, actual
allocator quotas with terminal domain retirement, admission caps and diagnostics.
The [policy decision](adr-002-domain-resource-policy.md) distinguishes gameplay
from trusted bootstrap and preserves GL-003/005 as separate capability issues.
The [work/validation record](execution-limits-validation.md) and linked manifest
record six final 66-case core configurations, 180 native actors, four SCons
products with 32 resource actors, representative default-policy workloads and
the failures/corrections that led to this source. Implementation `1e201ed` and
fixture follow-up `040996e` preserve published history. Fresh hosted
[core 40857805897](https://github.com/gmoddev/GodotLuau/actions/runs/40857805897)
passes 66 cases on both platforms; fresh
[native 40857806041](https://github.com/gmoddev/GodotLuau/actions/runs/40857806041)
passes all 36 actors on both. All downloaded artifact digests, source/harness/
engine identities and retained native log hashes verify. The initial Windows
fixture failure remains recorded, with bounded positive-state delivery correction
and 65 passing follow-up actors across the existing worker configurations/trials.
**FIXED AND QUALIFIED on this branch**, within the linked resource contract.
It is not a hostile-script isolation claim. Normal merge `55a9c20` integrates the
qualified source. Fresh main core `40861479206` passes 66 cases per platform;
native `40861479365` passes all 36 actors per platform, including resource and
GL-022 markers. Artifact digests and source/harness/log identities verify.
**INTEGRATED AND RESOLVED within ADR-002**, with no resource-policy expansion.
GL-003/005, GL-018 and GL-020 adversarial qualification remain open.
See the integration record below
the historical branch evidence in [the work record](execution-limits-validation.md#main-integration).

## GL-005: HTTP is synchronous and broadly exposed

Work on `runtime/gl-005-async-http` starts from integrated main `3d390a0`.
**FIXED, QUALIFIED AND INTEGRATED:** Normal merge
`b7d108b08b9b55c8333a1799743204441b424dba` preserves all three commits at
retained branch tip `4a5ebbd`, with the same tree. Fresh main Windows/Linux
Debug/Release core72 and Debug native43 pass. All four fresh hosted main jobs
pass (core72/native43 per platform), with downloaded artifact digests and
source/harness/engine/log identities verified. See the
[integration record](http-validation.md#main-integration-2026-10-29).
Implementation `4dbecc8` plus
fixture/TLS-build follow-up `fce3637` replaces the blocking helper with host-ticked
coroutine completion, native Server/exact-origin grants and finite limits. Six
core configurations pass72, five native configurations pass43 and four SCons
products pass HTTP4/resource8/filesystem3. Fresh hosted core/native Windows/Linux
jobs pass at `fce3637`; all four artifacts and native log/source/harness/engine
identities are downloaded and verified. See the
[work record](http-validation.md#final-local-qualification) and
[evidence manifest](evidence/gl005-asynchronous-http-2026-10-29.json).
Main now contains the same qualified implementation. GL-003/004 source contracts and
regressions are preserved; releases and the updater remain disabled.

**Original evidence:** The initial review's `src/core/luau_script.h:293-439`
implements `gl_http_perform` with polling/delays, with `_HTTP` installed at
`1725-1760`. The later GL-013 extraction moves those bodies to `luau_script.cpp`;
the GL-005 starting main still has the same blocking helper used by HttpService.

**Baseline consequence/limits:** Calls can stall the calling thread. The helper has a
nominal ten-second timeout, so it is incorrect to claim no timeout exists; this
is not a proven universal deadline or nonblocking execution. No native capability
or domain allowlist is present. Hostile-script/network impact needs deployment
context. That original review performed no SSRF exploit or timing benchmark.
The linked GL-005 work record now includes controlled native timing/truncation
reproduction and the branch's authority/scheduling regression results.

**Fix boundary and closure:** Specify permitted hosts/grants and request/response
bounds, then use asynchronous I/O with coroutine completion, cancellation, and
shutdown-safe ownership. Test slow/failing endpoints, byte limits, denial, valid
requests, and continued frame/scheduler progress against explicit budgets.

## GL-006: Server-origin RPC receivers omit authority checks

**Status (2026-10-27): INTEGRATED AND RESOLVED for state/2D-state/removal endpoints
in main through `2e69d8ac703d3f968e42054871511111ab8471be`.** Original static
evidence and counterevidence are preserved below. The unchanged main runtime's
state/removal effects were subsequently reproduced over actual ENet.

**Evidence:** `src/services/roblox_network.h:616-630` configures state and removal
RPCs as ANY_PEER. `_recv_state`, `_recv_state2d`, and `_recv_remove` at `1825-1836`
do not validate the actual sender or receiver role. Removal reaches
`_remove_peer_player:1110-1117`, erases player tracking and queues the Player free.

**Boundary:** A connected peer's chosen RPC arguments reach operations documented
as server-to-client state/removal. This is a confirmed static authority defect,
rank 1 in the confirmed security queue. Exact client/server/topology effects have
not been reproduced. It is not a claim of unauthenticated Internet code execution.

**Counterevidence:** Structural replication checks sender 1 at `1737-1778`;
RemoteFunction replies check the expected peer at `1283-1291`; owned physics
checks the actual sender/owner at `1439-1449`.

**Fix handoff (`$fix-finding`):** Gate allowed receiver role and transport sender
before trusting `who`, updating puppets, or removing players. Choose appropriate
RPC authority configuration and retain defense at handlers. Test malicious
connected-client calls against server and another client, with no mutation,
callbacks, removal, or relay on rejection; preserve legitimate server updates
and disconnect cleanup. Pin the peer/topology configuration in evidence.

**Correction and executed closure:** Implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6` adds authority RPC configuration and
native Client-role/actual-server-sender checks before mutation. Client-origin
state relays also require a Server role and active assigned transport sender,
closing the direct-relay-to-client path. Positive mapped target identities are
required for state; legitimate removal can follow transport departure. Server
session indices replace client-chosen name indices. Callback reentrancy is
followed by ObjectID/sender revalidation before forwarding.

Actual two-client transport attacks against server and victim cover forged/self/
invalid targets, both dimensions, removal and teardown timing. Player/character
state and removal callbacks remain unchanged; legitimate state and real disconnect
cleanup pass. Tests also relax RPC filtering to ANY_PEER and establish native
handler rejection separately. Windows/Linux Debug/Release and matching Linux
full-native ASan/LSan pass. See the [authority report](network-authority-validation.md)
and [immutable qualification manifest](evidence/gl006-008-qualification-2026-10-27.json).
GL-007 and GL-020 remain independent; this closes the named position/health/
removal entry points, not all player presentation or networking authority.
The [main integration record](network-authority-validation.md#main-integration-2026-10-27)
distinguishes fresh integrated-revision checks from retained branch qualification.

## GL-007: Character relay trusts supplied movement and health

**Status (2026-10-31): INTEGRATED AND RESOLVED within ADR-006/007's bounded contract.**
Normal merge `4d4694e8ea5f05120ded9b116bcd06a2c95e4ead` preserves both qualified
GL-007 commits with an identical tree. Subsequent Character V2 merge
`1c3176c0d9331dc1fa6849b98f8ed8e90e59c110` preserves those checks on the actual
Model-derived root and protocol 3. See the [integration record](character-main-integration.md)
for fresh verification, source identity and CI evidence. GL-017/018, the broader
GL-020 security gate, graphical correctness and collision-truth claims remain
separate. The branch qualification history follows.

[Source fix `3bb641a`](https://github.com/gmoddev/GodotLuau/commit/3bb641a822df288bf48fc6358baec389994b77f0)
remains on retained `security/gl-007-character-authority`. Actual
Windows/Linux ENet baseline clients changed real server Humanoid health and
overwrote server damage, as well as moving to X=100000. This supersedes the
historical unproven gameplay-impact limitation below for character health only;
economy/progression effects remain unproven. The qualified GL-007 source implements
[ADR-006](adr-006-character-authority.md). See the
[work record](character-development.md) for baseline identities, development
failures and final acceptance. Historical source-review limits below are retained;
they do not override the subsequent native-health reproduction.

Final native input `20ecbfc...` passes the complete local Windows/Linux core,
native and production-build matrix, including Linux full-native ASan/LSan.
The [qualification record](character-authority-validation.md) retains exact
identities and limitations. Windows/Linux hosted core/native CI passes, and all
four downloaded artifacts are verified for exact source `3bb641a`. This resolves
the bounded finding on the retained branch; the subsequent integration and fresh
main evidence are linked above.

**Evidence:** `src/services/roblox_network.h:1813-1822` derives sender identity,
then updates/relays supplied pose, display index, health, speed, and air state
without finite/range/movement checks in the relay.

**Consequence/limits:** The demonstrated sink is puppet/display state. Effects on
authoritative gameplay health, damage, progression, or economy were not
established. Transport-derived sender identity is positive counterevidence
against arbitrary identity selection on this particular path. Security verdict:
`needs_review`, rank 2 in that queue.

**Fix boundary and closure:** Document authority for each field and separate
client input from server-owned state. Enforce allowed role, finite values,
transitions, rate/size limits and game-specific movement policy before mutation
or relay. Test wrong-role, NaN/infinite/out-of-range/impossible updates plus valid
movement. Trace authoritative consumers before claiming a gameplay exploit.

## GL-008: Chat display identity is client supplied

**Status (2026-10-27): INTEGRATED AND RESOLVED within the qualified chat/session
scope in main through `2e69d8ac703d3f968e42054871511111ab8471be`.** The original finding
is preserved below; baseline ENet tests subsequently reproduced name spoofing.

**Evidence:** `src/services/roblox_network.h:1854-1862` reads the transport peer
ID but displays/relays the caller's `name`; `_show_chat:1841-1845` forwards it to
TextChatService. `_recv_chat` also lacks a server-sender guard.

**Boundary/limits:** A connected peer controls another displayed identity.
Confirmed static display-spoofing defect, rank 2 in the confirmed security queue.
The peer ID itself is not forged; this does not establish account takeover.

**Fix handoff (`$fix-finding`):** Derive sender identity/name from server-owned
player/session data, bound text and rate, and gate server-origin reception before
display. Test a connected client supplying another name or raw receive RPC,
unknown/disconnected senders, valid chat, and rejection without display or relay.

**Correction and executed closure:** Implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6` resolves the active transport sender to
its live server-owned PlayerObject and matching assigned session UserId. Submitted
names are ignored, and first-state display indices can no longer poison that
record. Receive and relay handlers validate receiver role and transport sender.
Original Variant types are checked before conversion: a real Array attack showed
that Godot's binder could stringify invalid text despite reporting an error.

The shared acceptance path rejects missing/stale records, invalid/oversized text,
and excessive rate before display/relay. The policy is 256 Unicode scalars,
five burst tokens and one token/second. Sender UI waits for accepted server echo;
single-player/system chat, including no Players service, remains supported.
RPC argument counts/order and valid string wire payloads remain unchanged.

Transport tests demonstrate replacement of other-player/system names, rejection
of raw receive/relay spoofing, pre-initialization/disconnected/invalidated records,
malformed/oversized/control text, Unicode bounds and bursts. They also establish
normal multi-client/server/local UI chat, refill/independent allowance and real
reconnect/record replacement. Platform and sanitizer coverage is the same as
GL-006; see the [report](network-authority-validation.md) and
[manifest](evidence/gl006-008-qualification-2026-10-27.json).
Session identities are not authenticated accounts. Deterministic numeric peer-ID
collision, mixed historical-client versions and malformed UDP framing were not
forced. GL-017/018 and unrelated capability/security findings remain open.
The [main integration record](network-authority-validation.md#main-integration-2026-10-27)
retains these limits and records fresh focused checks without a new security phase.

## GL-009: DataStore loses updates and has no crash-atomic write protocol

Work starts from main `bc8ca88` on `persistence/gl-009-transactional-datastore`.
Windows/Linux deterministic lost-update and controlled truncation-interruption
reproductions now exist in the [work record](datastore-validation.md).
[ADR-005](adr-005-transactional-datastore.md) selects confined transactional files
and a companion native I/O process. Implementation `d4dfb32` is fixed and qualified
within that supported contract. Normal merge `fc923d2` integrates all four commits
at branch tip `d5e855b`; its tree equals that qualified tip. Main integration
verification is in the [integration record](datastore-integration.md#final-disposition).
Fresh Windows/Linux hosted core72/native66 and five packaging tests per platform
pass at follow-up `31d0f1f`, with all four artifacts and 426 native log hashes
verified. The legacy-writer gate clears before merge, all nine seeded legacy files
and their backups remain byte-identical, and extracted native packages pass on
both OSes. No existing application root is activated. No release
or updater enablement is authorized. See the
[final evidence and CI](datastore-validation.md#final-disposition).

**Verified starting-main evidence:** `src/core/luau_stdlib.h` implements Get/Set/Update/Increment
as local JSON access. `UpdateAsync` is Get/transform/Set with no lock, version,
transaction, or CAS. Native `GLStorage::WriteFile` in `gl_storage.h` truncates
the target. README's coordinator limits explicitly document shared `user://`.

**Consequence/limits:** Two world processes can read the same value and overwrite
one another; interruption can leave incomplete JSON. A single non-yielding
transform is not cross-process serialization. Windows/Linux baseline tests now
reproduce competing-writer loss and loss of a prior acknowledged sentinel after
controlled truncation/interruption; see the linked work record. The optional
Nakama stack is not wired into DataStore.

**Fix boundary and closure:** ADR-005 selects confined files after evaluating
SQLite and the unqualified optional external stack. Rename alone is insufficient;
the fix adds shared locking, conditional commit, flush/ack and bounded ownership.
Qualification covers independent
process writers, retries/conflicts, cancellation, disk failure, interrupted commit,
restart, and preserving the previous committed value on failure.

**Remaining limits:** same-account cooperating local writers; stop old writers
before upgrade. NTFS/ext4 are executed configurations. Ordered sorting remains
local cache and public history methods remain stubs. Callback effects are not
exactly-once. Power loss, unsupported/network filesystems and independent replicas
are not qualified. Host init/supervisor must reap terminated orphaned helpers;
hot reload with unretired children is unqualified. Native codec/startup latency
and aggregate disk capacity remain operational limits. Windows native ASan GL-018,
GL-017 engine diagnostics and GL-020 adversarial qualification remain separate.

## GL-010: Windows release binaries lack same-revision build evidence

**GL-010/011 continuation:** Normal merge `b88a88b64c3f576d8b51e51908c0141ac9231a18`
integrates all six qualified source commits. The
[non-publishing candidate contract](release-candidate-qualification.md) replaces
committed Windows ZIP reuse with four source-built profiles and provenance
qualified at
`ca8cefbafbe6012e6ae0699ae433b7d5355edfa6`. All ten hosted jobs, both extracted
packages and eight downloaded artifacts verify. Fresh main
[integration verification](release-candidate-qualification.md#main-integration-2026-11-01)
passes all ten candidate gates plus ordinary core/native CI with exact artifacts.
Publication stays disabled; historical/published provenance is not retroactively
established. This is bounded candidate qualification, not full production closure.

**Original evidence (starting main):** `.github/workflows/build-release.yml` builds Linux debug/release
with SCons, then extracts Windows binaries from `GodotLuau.zip`. It does not
compile Windows at the tagged source revision.

**Consequence/limits:** A mixed ZIP may combine binaries from different source
revisions; this workflow cannot establish their equivalence. It does not prove
every existing Windows DLL is stale or unsafe.

**Closure:** Build supported Windows/Linux variants from the same immutable
revision and pinned dependencies; record compiler/configuration, source digest,
binary hashes and required check results in release provenance. Remove committed
archive reuse as a substitute for source builds.

**Continuation:** Manual same-source Windows/Linux qualification builds and the
explicit-input local package are recorded in the shared-domain validation report.
The inherited release workflow still reuses its ZIP; GL-010 remains open for
published release provenance and workflow correction.

GL-009 integration follow-up `31d0f1f` fixes the source ZIP builder's omitted
Windows/extensionless Linux companion, executable metadata and missing-helper
preflight; real extracted source-built packages pass on both platforms. The
disabled inherited release workflow still stages only Linux `.so` files and
reuses its Windows ZIP. Its pipeline/provenance and updater extraction remain
unqualified; publication stays disabled. See the
[integration record](datastore-integration.md#companion-archive-follow-up).

## GL-011: Automated runtime qualification is missing from release gates

**GL-010/011 continuation:** Required four-profile core/native, Linux core
ASan/LSan, extracted-package and fail-closed admission gates pass
[candidate qualification](release-candidate-qualification.md). Existing strict
checks remain unchanged. Failed/skipped required jobs demonstrably prevent
acceptance; all four final profiles execute 80 core/110 native cases. Unsupported
graphical/sanitizer configurations and production distribution retain explicit
limits. The correction is integrated by normal merge `b88a88b`; fresh main
candidate/core/native gates and downloaded artifacts verify in the
[integration record](release-candidate-qualification.md#main-integration-2026-11-01).
Publication stays disabled.

**Original evidence:** One tracked Actions workflow performs build/package/release steps
without runtime tests, multiplayer integration, or sanitizers. `test_chat/` has a
small scene/script fixture; it is not executed by the workflow.

**Consequence/limits:** Successful builds do not establish lifetime, scheduler,
authority, or persistence behavior. Private/untracked/manual tests may exist;
their absence was not proved. No runtime qualification was attempted here.

**Closure:** Introduce headless, bounded regression gates covering the relevant
bugs and supported configurations, including lifetime/reload, rejected RPCs,
multiple peers/processes, and persistence failures. Add appropriate native
sanitizer coverage and retain evidence. Keep docs-only checks lightweight.

**Continuation:** Bounded cross-platform runtime runners, focused regressions and
native Linux ASan/LSan evidence now exist under `tests/runtime`. They are manual
qualification gates; the inherited release workflow still does not enforce them,
so GL-011 remains open.

**Character follow-up (2026-10-31):** The development branch's
[qualification record](character-performance-followup.md) preserves the original
truncated Linux CTest failure and completes fresh Linux Debug/Release core and
core ASan/LSan (80 cases each), Release native (110 actors), and verified hosted
Windows/Linux 80-core/110-native results. A complete-report local wrapper uses
the already-qualified hosted output limits and the unchanged strict checker.
Full-native sanitizer and release-enforcement limits remain; this does not close
GL-011 or enable publication.

**First CI milestone (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`f0199004d56485ec7a9de14d5454d1907822ba11` preserves source branch
`ci/gl-011-core-qualification` at `95167299ad8a102b23fb3b25284a751483815779`.
Adds a separate read-only, non-publishing
Windows/Linux Debug workflow for the existing 39-case production-core suite.
Recursive pinned checkout, bounded compilation and deadlines, explicit discovery
and full completion checks reject missing/partial evidence. No new runtime or
duplicate scheduler is introduced. Diagnostic artifacts exclude production
binaries. See [commands, actual outcomes and limitations](shared-domains-validation.md#gl-011-independent-core-ci-2026-10-27).
Hosted [run 40475254435](https://github.com/gmoddev/GodotLuau/actions/runs/40475254435)
passes both Windows MSVC and Linux GCC Debug jobs, 39 cases each, including
discovery/report checks and diagnostic uploads. Fresh main integration
[run 40476321167](https://github.com/gmoddev/GodotLuau/actions/runs/40476321167)
also passes both jobs, all 39 cases each, with reports and diagnostics retained.
The release workflow stays disabled. Native Godot, multiplayer/lifecycle/security
fixtures, sanitizers, persistence failures and release enforcement remain manual
or independently incomplete. This milestone does not close GL-011 or qualify
GL-020's deferred adversarial cases.

**GL-011B native milestone (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`9029d01a24d904deaa1ecd7a9c30fc483e13757f` preserves both commits of qualified
source `ci/gl-011-native-integration` at `cebc64919e4fbf67624b19e075f31ef25941d136`.
The separate read-only
Debug workflow builds `GodotLuauAdapter` on Windows/Linux, verifies pinned official
Godot 4.7.1 assets and reuses 8 lifecycle/network, 10 GL-006/008 and 10 functional
animation process fixtures per platform. New launcher ownership/cleanup and eight
bounded failure tests address process trees and partial startup. Equivalent worker
runs pass all 28 actors on each platform. Actual hosted
[run 40478173463](https://github.com/gmoddev/GodotLuau/actions/runs/40478173463)
also passes fresh Windows/Linux adapter builds, eight launcher checks and all
28 native actors each (56 process results), with diagnostic-only uploads verified.
This is Debug/x86_64 coverage, distinct from manual sanitizer evidence. See
[native CI evidence and sanitizer assessment](shared-domains-validation.md#gl-011b-native-ci-2026-10-27).
No sanitizer job or release enforcement is introduced; no GL-020 adversarial
animation test is added or executed. GL-011 remains open.
The merge tree exactly matches qualified source; following integration notes
change documentation only. Existing hosted qualification is reused within its
Debug/x86_64 scope. No expensive local matrix is repeated; automatically triggered
integration runs are observed for a bounded period and are not assumed to pass.

The integrated Linux run `40483447902` subsequently exposed a launcher-test
proc-stat check/read race before provisioning or compilation; Windows passed.
The [focused correction](shared-domains-validation.md#linux-process-liveness-correction-2026-10-27)
uses one guarded read with narrow disappearance handling. Complete worker tests
pass (Linux 14; Windows eight plus six Linux-only skips); deterministic baseline
reproduction fails as expected. Fresh corrected-main core run `40618765032` passes
39 cases per platform; native run `40618765012` passes both actual adapter builds,
process suites and all 28 actors per platform. Both diagnostic summaries verify
the correction and unchanged native fingerprint. The race is fixed and
hosted-verified; historical evidence remains separate.
This CI reliability correction does not close GL-011 or expand runtime scope.

## GL-012: Release workflow deletes prior provenance references

**Original evidence:** The final release step lists up to 100 releases and attempts
`gh release delete --yes --cleanup-tag` on every tag except the current release.

**Consequence/limits:** This can remove useful published assets and source tags,
hindering rollback and historical verification. The workflow's existence does not
prove that all earlier releases were deleted.

**Closure:** Adopt an explicit retention policy preserving immutable release
tags, artifacts and provenance. Validate the changed workflow without performing
destructive deletion of real published history. Do not dispatch the inherited
workflow as a documentation check.

**Integration (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`3551bcce8f5f68ed2ee47c2ac41e2e85f74a4feb` preserves qualified branch
`maintenance/gl-012-release-retention` at `169fd98be216c4322f4c820c7d77f3081761982b`.
Removes historical release/
tag deletion, rejects reuse of a published release or Git tag before package/
commit/publish, serializes this workflow's publication and disables asset
overwrite. Twelve mocked/read-only tests and parsed YAML structural checks pass;
no live publishing/deletion or remote tag change is performed. See
[retention policy and continuation assessment](release-retention.md) and
[evidence](evidence/gl012-release-retention-2026-10-27.json). The interim policy
also removes automatic triggers and disables both publishing-workflow jobs with
read-only permissions. GL-010/011 and repository-wide immutability/external
publisher coordination remain independent gaps.

## GL-013: Implementation headers concentrate unrelated responsibilities

**Evidence:** Git blob sizes: `luau_api.h` 294380 bytes; `roblox_network.h` 154252;
`luau_autocomplete.h` 138520; `luau_script.h` 121617; `luau_stdlib.h` 116928;
`roblox_gui.h` 102551. `luau_script.cpp` is 172 bytes. These headers contain
implementations, not just declarations.

**Consequence/limits:** Review and dependency boundaries are difficult to isolate.
Compilation/rebuild cost was not measured. Header size alone is not a runtime
bug and does not justify a sweeping rewrite.

**Closure:** Extract cohesive implementation units incrementally with explicit
ownership/interfaces, preserve behavior, and measure build impact when claimed.
Avoid mixing mechanical movement with unrelated runtime changes.

**First extraction (qualified 2026-10-27; integrated 2026-10-28):** Starting main
`eb638bfa6ff16abc91d11742625b3cc034f53178`; branch
`refactor/gl-013-luau-api-extraction` moves native Vector3/Color3 userdata bindings
to a separately compiled unit with no Godot/domain dependency. The original
header is 290,353 LF bytes at this main baseline, reduced to 281,472; the historical
294,380-byte finding above remains tied to its original revision. The narrow
header exposes layouts/helpers and two initialization calls; math callbacks stay
private. CMake compiles the new unit; SCons dry-run discovery includes it.
See the [extraction record](shared-domains-validation.md#gl-013-first-value-binding-extraction)
and [measurements](evidence/gl013-value-extraction-2026-10-27.json).

Local Windows/Linux Debug/Release each pass 39 core cases and 28 native actors.
Implementation `83bc42d2bcea9d66d21cfd4d2df2650b6c87a06c` also passes fresh hosted
core run `40626224165` (39 per platform) and native run `40626224232` (actual Debug
builds, 28 actors per platform and verified diagnostic summaries). Disposition:
**GL-013 — Incremental modularization underway; four extractions qualified.**
Normal merge `bdd57fd3097537bb1cf0f8a0b7c08ae7e312d0d7` integrates both commits
through source `1c9f4c6296bc955a6a5969a6da0668d137e46ed1`; the merge tree exactly
matches qualified source. The [integration record](shared-domains-validation.md#first-extraction-main-integration-2026-10-28)
distinguishes reused qualification from fresh main CI observation. Existing shared-domain ownership, userdata layout,
registration order, reflection and networking remain unchanged. The original
header still couples Instance dispatch, services and Godot properties; this first
boundary does not close GL-013. An exploratory physics-backed baseline fixture
also exposed a Linux shutdown failure after PASS; its diagnostic evidence is
retained as an independent qualification limitation, not fixed by extraction.

**Second extraction (2026-10-28, integrated):**
`refactor/gl-013-variant-bindings` starts from integrated main `174efcc2bdb59c5072ba21d27645c5380c61e8e9`.
Only the two generic Luau/Variant conversion bodies move to an owned `.cpp` and
two-declaration forward-only header; Instance reflection, ObjectID validation and
property/Offset/error dispatch stay with their existing owners. No type support,
ownership, registration or conversion logic is added. `luau_api.h` decreases from
281,472 bytes/4,946 lines to 280,183 bytes/4,923 lines. See the
[second extraction record](shared-domains-validation.md#gl-013-second-generic-variant-extraction)
and [separate measurements](evidence/gl013-variant-extraction-2026-10-28.json).
All Windows/Linux Debug/Release worker builds/core39/native28 pass. Implementation
`5f72f4cda1c5e3bb76edd33bb11e276cff07ac10` also passes hosted core run `40631078253`
(39 per platform) and native run `40631078251` (fresh actual Debug builds and28
actors per platform). Diagnostic summaries verify exact source/fixture identity.
Normal merge `21d10d91769ee81c85ae2e1d2029e683feeb51ba` preserves both commits
with an identical tree. Fresh main core/native observation is recorded below.
Disposition: **SECOND EXTRACTION QUALIFIED AND INTEGRATED**. Baseline tests establish that unsupported reads retain invalid-member
errors and Lua non-ASCII strings retain the existing Latin-1 constructor behavior;
these are preserved, not silently fixed. The first extraction's historical
measurements/limitations remain. GL-013 stays open.

**Third extraction (2026-10-28, integrated):**
`refactor/gl-013-instance-reflection` starts from verified integrated main
`752bb2063f61a533c3e59b481196a0d8aa88f1ba`. Exact property-list membership and
the two generic `_gl_bridge` read/write blocks move to an owned Object adapter,
with a three-declaration forward-only interface. Dependencies now point from
Instance dispatch through reflection to Variant conversion and native values;
no Node/service/domain header, retained object, registry or registration is added.
Class identity, method/signal/callback bindings, ObjectID validation, class-specific
properties, child/error fallbacks and replication remain in their existing owners.
The API header decreases from 280,183 bytes/4,923 lines to 278,169 bytes/4,885 lines.
The new interface is 1,007 bytes/18 lines; implementation is 1,878 bytes/53 lines.
See [third extraction analysis and qualification](shared-domains-validation.md#gl-013-third-instance-property-extraction)
and its [separate manifest](evidence/gl013-instance-reflection-2026-10-28.json).
Baseline production fixtures establish read-only/property/metadata/Offset/error
and Changed behavior before code moves; those semantics are preserved. GL-013
remains OPEN for broader Instance/service/editor header coupling. Normal merge
`b7ec9fd614bd0e92ce418859de68b835180a7d7c` preserves both commits with a tree
identical to qualified tip `90776e7c1c5ba2b087d4efc4b9ecc2e50a223058`.
**THIRD EXTRACTION QUALIFIED AND INTEGRATED**: Windows/Linux
Debug/Release core39/native28 pass (112 local actor results); hosted core
`40643325332` passes39 per platform and native `40643325389` passes fresh Debug
builds/process checks/all28 actors per platform. Exact revision/source/fixture
identities are verified in digest-checked diagnostic archives. A one-unit
implementation edit boundary is measured; no general build-speed or native
lifetime/sanitizer guarantee is inferred.

**Fourth extraction (2026-10-28, integrated):**
`refactor/gl-013-class-identity` starts from integrated main
`4e3db8496e189b6e09148b015eff28b1c8ae29b6`. The generic native/Roblox class map
and exact/custom-parent/Godot IsA predicate move to an Object/String-only unit with
an owned String result and two forward declarations. The old fallback used a
TU-local mutable CharString, but current callers immediately copied/compared it;
no supported-call lifetime defect is confirmed. Returning an owned value avoids
introducing shared mutable fallback storage at the new compilation boundary.
Player/Value overrides, Mouse branch ordering, ObjectID resolution and error/
hierarchy dispatch remain unchanged. No separate lifetime fix or ownership model
is introduced. The [audit and qualification](shared-domains-validation.md#gl-013-fourth-class-identity-extraction)
and [new manifest](evidence/gl013-class-identity-2026-10-28.json) retain exact
analysis, baseline fixture failure and measurements. The API header decreases
278,169 bytes/4,885 lines -> 274,780 bytes/4,838 lines; the interface is 748 bytes/15
lines. Local Windows/Linux Debug/Release core39/native28 pass (112 actors total).
**FOURTH EXTRACTION QUALIFIED**: hosted core `40646744969` passes 39 per platform
and native `40646744985` passes fresh Debug builds/process checks/all 28 actors per
platform. Digest-checked summaries verify exact revision/source/fixture identity.
No supported-call lifetime defect is confirmed; no new sanitizer matrix is run
because native object ownership is unchanged. Normal merge
`35c993ce3711076a61dace5324f74691f4fb77ef` preserves all four commits and equals
qualified tip `eb53661072999887d2a124e5d4ece2f458c7bb30`. GL-013 remains OPEN. No general speed/lifetime/sanitizer guarantee is inferred.
EOF-only follow-up `688fd5b` removes one trailing blank line; implementation code
is unchanged. Fresh follow-up core39 passed while native run `40648770257` was still
building at that earlier bounded observation. Both cleanup workflows subsequently
passed; fresh merge core `40651973151` and native `40651973098` also pass Windows/Linux
39 core cases / 28 native processes each. Final main is
`08b2bb83b7093a361c80b147b4827eb22715ad32`, with identical tested inputs.

**Remaining-boundary assessment (2026-10-28): complete, GL-013 still OPEN.**
The [assessment](gl013-boundary-assessment.md) and
[inventory/compiler evidence](evidence/gl013-boundary-assessment-2026-10-28.json)
record 64 headers/eight implementation units, no project include cycles and exact
matches of eight qualified compiler include closures. Four isolated owners are a
maintainability improvement; API-header edits still affect three TUs and no general
build-speed improvement is established. Prefer script bootstrap/Instance access in
existing `luau_script.cpp`, followed by completion ownership and GUI metadata/style
adaptation. Inert helpers rank below these; earlier next-helper suggestions are
historical. State/dispatch/network boundaries need their stated proof before a
future extraction. GL-021 records a separate static compatibility discrepancy.
No fifth extraction, production/test/build/workflow change or unrelated closure.

**Fifth extraction (development branch, 2026-10-28): FIFTH EXTRACTION QUALIFIED.**
`refactor/gl-013-script-bootstrap` begins at main
`ce5e19fa8aea1cf65da875d07cda13c1696fc08c` after assessment integration. Bootstrap,
RemoteFunction setup and child relay move to existing script CPP, with one narrow
wrapper-push declaration and explicit host/registration include prerequisites.
VM, scheduler, module cache and network/dispatch implementations remain unchanged.
Compiler dependency closures match the graph in all eight before/after/platform/
configuration sets (64 objects): API and stdlib fan-out three → one; script-header
touch still rebuilds three. All four candidate configurations pass 39 core cases
and 28 native actors (112 candidate actors); unchanged baseline passes the final
expanded eight-actor regression group in all four configurations.
The [fifth qualification record](shared-domains-validation.md#gl-013-fifth-script-bootstrap-boundary)
and [manifest](evidence/gl013-script-bootstrap-2026-10-28.json) retain timing/size
increases, include failures, baseline callback finding GL-022 and qualification
limits. Implementation `50f1c0e4b7f569bbacf3163651dcf16fa0e9a8f4` is pushed and
remote identity read back. Fresh hosted core `40661531131` passes 39 distinct cases
per platform and native `40661531193` passes fresh Debug builds, process-runner
self-checks and all 28 actors per platform. Digest-checked summaries match exact
source/pins/all 22 harness hashes. Both complete within the 25-minute bound.
The evidence follow-up changes no tested input; this is not merged to main.
GL-013 remains OPEN; no sixth extraction or unrelated issue closure is implied.

**Fifth extraction integration (2026-10-29):** Normal merge
`109bd6d838410509da9831b1502dfffb023ad823` preserves both source commits and
exact qualified tree `9171199fc6b3b43a2aa07a98f3f20977abc43533`. Fresh checks
and hosted outcomes are recorded in the [integration record](gl022-child-relay-validation.md).
GL-013 stays open. GL-022's shared-target reproduction predates this extraction
and is not treated as an introduced refactor regression.

## GL-014: Shared execution domains — integrated and source-qualified

**Evidence:** Per-executable-script `L_main` at `luau_script.h:960`; require's
registry cache at `1806-1828`; README explicitly documents isolated module state.

**Original classification:** Design decision. The baseline model was real;
calling it inherently wrong or too slow was not established.

**Implemented:** The owner explicitly requested migration on 2026-10-26.
Implementation commit:
[`521265c338fc890a0e30b9e8a556f6346baf7d00`](https://github.com/gmoddev/GodotLuau/commit/521265c338fc890a0e30b9e8a556f6346baf7d00).
[ADR-001](adr-001-shared-execution-domains.md) compares per-script, per-domain,
universal and Actor-like ownership and records compatibility before runtime edits.
GLExecutionDomain owns the VM/cache/scheduler and script/module identities;
GLDomainHost owns applicable Server/Client domains for the running scene/process.
No per-executable VM or permanent legacy scheduler remains. Environments,
sticky module failures, invalidation, shared state, shutdown, role boundaries and
native callback ownership are described in [current architecture](current-architecture.md).

**Executed evidence:** 35 production-core regressions pass in Windows MSVC
Debug and ASan, including deep require/spawn dispatch after an ASan-discovered
stack overflow was fixed. Actual GDExtension fixtures pass single-player,
listen-host, dedicated server plus two clients, and editor-style two-client
launch flags. They exercise native signals/remotes, script/module lifecycle,
Instance value replication, identity and wrong-role checks. See exact commands,
limits and artifact identity in [validation](shared-domains-validation.md), and
the investigation history in [work log](shared-domains-work-log.md).

**Status: OPEN for qualification.** Implementation and exercised functional
acceptance are delivered. Representative old/new startup/memory/scheduler costs
have not been measured; no performance or scalability claim is made. Linux,
release/SCons packaging, a full graphical editor session, coordinator deployment
and sanitizer-instrumented Godot/native adapters were not qualified. ENet
`max channels: 0` teardown diagnostics occurred in a passing multi-process run;
baseline attribution remains unresolved. Close only with linked qualification
evidence and an explicit disposition of these remaining acceptance/proof gaps.
GL-003 through GL-009 and GL-016 remain independent issues.

**Continuation disposition (2026-10-26): CLOSED for the requested migration and
source-qualification scope; CONDITIONALLY READY for source integration.** The
historical open status above describes the initial report. Windows/Linux CMake
and SCons Debug/Release, 36 core cases with repeated Debug/Release/
ASan suites, and full Linux native ASan/LSan stress establish the exercised
acceptance facts. Controlled old/new 10/100/1,000-script benchmarks show lower
startup/RSS and slower cached require/task bookkeeping. The validation report
records exact figures, build/package disposition, commands and limitations.
Remaining independent engine, Windows sanitizer-host and performance follow-ups
are GL-017/GL-018/GL-019; graphical editor/coordinator/production content remain
unqualified. This closes neither production distribution nor unrelated issues,
and does not authorize merging main or publishing binaries.

**Authorized integration (2026-10-26): INTEGRATED WITH QUALIFICATION LIMITATIONS.**
Normal merge `dd68cda850fb548aa7713242275ff73c183e813c` integrates source
`9423fed4051bec2fba798d9a49eaec7dea6cca3b` into main, preserving all four
source commits without conflicts. The merge tree is identical to that qualified
source. Fresh Windows/Linux Debug/Release builds and native fixtures plus core
ASan checks pass; exact scope and reused immutable evidence are in the
[integration record](shared-domains-validation.md#main-integration-2026-10-26).
GL-014 remains closed for its implementation/source-qualification scope and is
now integrated. GL-017/GL-018/GL-019, production networking, persistence,
capabilities and distribution limitations remain independently open. The
integration does not publish production binaries or change updater behavior.

## GL-015: Establish asset-specific redistribution provenance

**Evidence:** Root LICENSE and `GodotLuau/licenses/` cover the project and named
software dependencies. `GodotLuau/assets/avatars/`, branding, and imported content
need their own provenance review before broad redistribution.

**Classification/limits:** Needs review; no infringement or ownership defect is
asserted. Filenames and similarity are not evidence of missing rights.

**Closure:** Inventory shipped assets, record origin/license/permission and
required notices, distinguish user-imported content, and replace or omit any
asset whose redistribution rights cannot be established.

## GL-016: Fork updater still installs from upstream

**Original evidence:** `addons/GodotLuauUpdater/plugin.gd:4-39` hardcodes Pimpoli's
version, ZIP, hash, tag/history and model URLs. `project.godot:18` enables the
plugin. Creating the GitHub fork does not change those endpoints.

**Consequence/limits:** Using the updater can install upstream packages over fork
work or mix distributions. This docs-only bootstrap did not launch the editor,
download packages, change updater behavior, or publish fork binaries.

**Closure:** Decide fork update policy before distributing builds. Options
include disabling automatic updates or selecting verified, pinned fork releases.
Cover all version/archive/hash/history/model endpoints as appropriate, preserve
upstream attribution, verify failure paths, and distinguish inherited ZIPs from
fork-built artifacts. A URL replacement alone does not establish provenance.

**Integration (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`abf7776dfb1d7dfde1abfc7b7cb468047575f738` preserves qualified source
`maintenance/gl-016-fork-updater` at `ed7211a2e354aa29516c646a3ee40f2459f87106`.
Runtime checks/download/apply,
callbacks, history, unverified backup restore, staging/swap/restart and destructive
startup cleanup fail closed before side effects. Enabled editor tools and explicit
model/custom-autocomplete downloads remain available. Both Windows/Linux actual
headless editor fixtures pass 596 assertions across 42 blocked operations and two
localhost optional-data downloads, preserving installed files/backups/metadata.
See [policy/recovery/limits](fork-updater-isolation.md) and
[evidence](evidence/gl016-updater-isolation-2026-10-27.json). Fresh Windows/Linux
integration fixtures each repeat 596 assertions and 42 rejected operations; the
historical branch results remain separate. Release publication stays disabled.
No fork production update channel or distribution provenance is established.
Original evidence and GL-010/011 remain independent.

## GL-017: Godot simultaneous-disconnect relay targets reset peers

**Status: OPEN; reproduced external engine defect, P2 for source integration.**
Godot 4.7.1 at `a13da4feb8d8aefc283c3763d33a2f170a18d541` reproduces
zero-channel sends with two disconnects before a server poll, without loading
GodotLuau. The full engine-only ASan/LSan probe also leaks 54 bytes (48+6).
Relay-off isolates the engine notification; synchronous application sends add a
second timing hazard, corrected here by deferred NetworkService callbacks.

**Boundary:** Production engine relay remains enabled; diagnostics and failed
leak gate remain visible. Ordered-close native stress isolates extension lifetime
checks but does not fix this engine edge. No upstream issue/message was created.

**Closure:** A separately reviewed Godot patch or verified engine version must
pass the existing simultaneous-close probe with relay on, no diagnostics and
ASan/LSan clean exit, then pass native two-client teardown. Preserve the exact
engine/source reproduction in [validation](shared-domains-validation.md).

## GL-018: Windows full-native sanitizer host remains unqualified

**Current disposition: INTEGRATED AND RESOLVED within the admitted matching-host profile.**
Normal merge `6a7fedf` preserves the combined qualified source;
[fresh main verification](gl018-gl029-main-integration.md) passes at `ac119bc`,
including Windows/Linux ordinary native, matching-host full-native sanitizer,
all four source-product profiles and both extracted packages. The original qualification
limits remain unchanged.
The retained branch qualification at `46427d0` passes all six hosted
core/native/sanitizer jobs, with exact
source/harness, actual cases, instrumented builds and retained logs independently
checked. See [closure and proof limits](gl018-closure.md). Stock-host unload safety,
Windows LSan and arbitrary custom/device profiles remain outside this closure.
The historical OPEN dispositions and failed attempts below are superseded by
this scoped closure and preserved as evidence.

**Frame-progress follow-up:** the
[HTTP timing investigation](gl018-http-frame-investigation.md) attributes the
original failures to measured domain startup and an uninterrupted 2,000-UUID
stress loop. A small fixture correction preserves 250 ms assertions, warms the
measured domains and batches the sample workload. The corrected utility passes;
an injected 350 ms stall is rejected at 441.823 ms. Local full groups still fail
unchanged close-time storage assertions, so complete hosted qualification remains
required. No production change or refactor is included; GL-018 remains OPEN.

**2026-11-02 bounded-conflict correction:** the
[focused work record](gl018-increment-qualification.md) identifies the increment
fixture's unsupported fair-completion assumption. A small fixture-only change
checks exact acknowledgment accounting while permitting only ADR-005's definite
conflict exhaustion. Windows ASan DataStore passes 23 actors and unchanged native
controls; GL-018 stays OPEN pending complete profile verification. No runtime or
retry-policy change and no refactor is included.

**Completed hosted follow-up:** exact-fix core/ordinary native CI and Linux
full-native sanitizers pass. Windows DataStore also passes all 23 actors, but
HTTP and HttpService frame-progress assertions fail at 0.332602/0.334151 seconds.
All 520 Linux and 495 Windows summary-indexed artifact files rehash correctly;
no unexpected sanitizer report is recorded. GL-018 remains OPEN for those Windows
timing failures; see the [completed observation](gl018-increment-qualification.md#completed-hosted-observation).

**Status: OPEN; bounded qualification gap.** MSVC-instrumented adapter/bindings/
Luau reaches functional PASS under stock Godot, then times out at exit. A
registration-only inherited baseline and candidate both reproduce the timeout
without any script/domain/network. Core ASan and normal Windows Debug/Release
native fixtures pass; full native Linux ASan/LSan passes ordered lifecycle stress.

**Closure:** Build a matching Windows Godot sanitizer host with compatible runtime
and rerun registration plus native lifecycle fixtures with bounded clean exit.
Do not label the current timeout as successful native coverage, infer all Windows
bindings safe from Linux evidence, or suppress the failure.

**2026-11-01 follow-up:** The dedicated
[GL-018 qualification record](native-sanitizer-qualification.md) preserves fresh
stock-host reproductions, matching instrumented host builds and actual UAF/LSan
detection controls. Minimal C ABI and production registration reloads now exit
cleanly on the matching Windows host; Linux uses Godot's existing ASAN_ENABLED
loader path without DEEPBIND overrides. Full production VM reload nevertheless
fails after its functional marker, with an unloaded instance-binding callback
in the Windows root Window destructor. Additional HTTP progress, utilities,
contention and template-asset profile failures remain unqualified. GL-018 stays
open; no runtime fix, GL-017 remediation or complete full-native pass is claimed.

**2026-11-02 follow-up:** [Binding-only controls and qualification records](native-sanitizer-qualification.md#follow-up-from-66362c7)
reproduce the unload failure on both matching hosts without godot-cpp, Luau or
GodotLuau. Explicit binding retirement exits cleanly; leaving callbacks attached
fails after PASS. The branch corrects a demonstrated locale-dependent UrlEncode
defect and prepares original Character assets for template hosts. It does not
patch the engine or change authority, persistence or execution bounds. Supported
Linux ext-family storage exercises the earlier denied groups, but backing-disk
exhaustion interrupts the full local attempt; its evidence and authorized worker
recovery are retained. Fresh source profiles and required hosted states remain
separate from old passes. Closure still requires clean production unload, all
80 core cases and 110 native actors on both supported sanitizer platforms with
actual detection controls and no unexpected reports, crashes or timeouts.
The final source-`2466015` hosted core/native jobs pass 80/110 on each platform
(one ordinary Linux retry; its original failure is retained). Both fresh full
sanitizer jobs fail: core ASan passes 80 each, but only 52 Windows/95 Linux native
actors complete in whole passing groups, with production unload still failing,
dedicated presentation incomplete and performance actors timing out. Linux's
hosted 23-actor DataStore group closes that supported-filesystem proof gap;
the local disk failure, GDB record loss, Windows timing/contention limits and
historical Linux leak remain explicit limitations. No full GL-018 closure is claimed.

**Binding-retirement follow-up:** diagnostics `44fe8c2` and qualification-host
correction `0119017` preserve the production tree and reproduce seven surviving
engine-owned bindings on both platforms. A durable symbol-retaining Linux trace
resolves the root Window teardown into an unmapped binding callback. The narrowly
admitted host patch retires library-token bindings before unmapping; direct
production registration/VM reload now exits cleanly on both corrected hosts,
with intentional sanitizer detection retained. This is a derived qualification
host correction, not an upstream/production engine change or a GL-017 fix.
See the [mechanism and scope](native-sanitizer-qualification.md#binding-retirement-follow-up-from-dfa700a).
Fixture correction `92659b` preserves all original rig identities in binary
bundles and routes Linux storage through the admitted ext-family profile root.
The corrected Linux full-native ASan/LSan profile passes all 80 core cases and
110 native actors locally and in hosted CI. Windows hosted ASan passes 80 core
and 87 actors in complete passing groups, including actual GL-020 transport
fixtures; its 23-actor DataStore group fails at competing increments. A diagnostic
trace captures eight consecutive conflicts while the other writer commits,
matching ADR-005's bounded-retry failure rather than a sanitizer memory finding.
The assertion still fails; no fairness guarantee or larger retry budget is added.
Windows HTTP timing failures persist in separate local attempts even though the
fresh hosted HTTP groups pass. Historical failures, including the 29,400-byte
missing-rig leak report and an earlier hosted animation assertion, remain retained.
GL-018 is **PARTIALLY QUALIFIED, OPEN**. Closure requires a separately reviewed
resolution of the increment acceptance/fairness conflict and a complete clean
Windows profile; see the [final outcomes and next step](native-sanitizer-qualification.md#qualification-outcome-and-remaining-blocker).

## GL-019: Shared-domain cached require and task overhead regresses

**Original status: OPEN; measured P2 performance tradeoff.** Three counterbalanced Linux
Release trials at 1,000 scripts measure 100,000 cached requires at median
129.327 ms baseline versus 194.723 ms shared, and 32,000 create/cancel pairs at
7.803 versus 19.973 ms. Startup/RSS improve substantially in that workload.
Source trace identifies source/path construction before the shared cache lookup,
plus rooted owner/task records and deferred safe reaping. Exact cost fractions
and isolated scheduler CPU time are not established.

**Correction already made:** A much larger pilot cancellation regression came
from unconditional native scene/guard scans; a registered-native-wait bit removes
irrelevant scans while preserving actual wait cleanup. Final figures above are
after that correction, not the failing pilot.

**Closure:** Profile cache/task paths, optimize only demonstrated costs while
preserving source invalidation/owner guarantees, and repeat the controlled
benchmark/regressions. Add a scheduler-only CPU measurement if making a scheduler
speed claim. [Raw data](evidence/shared-domains-benchmark-2026-10-26.json) and
[method/limits](shared-domains-validation.md) are retained.

**Resolution (2026-10-26): OPTIMIZED AND QUALIFIED on `perf/gl-019-hot-paths`; not
merged into main.** Runtime commit `1756cc2600e5a59ea948e69a684f5abd93e32229`
follows measured native perf sampling and controlled baseline reproduction.
Native cache hits validate module/resource identity and source revision, loading
source/path only on misses. Source revision increments before changed-signal
delivery. Task snapshots preallocate and avoid unused live-record shared_ptr
copies while preserving strong references during dispatch/cleanup.

At 1,000 scripts, seven counterbalanced pre/post trials measure cached requires
198.230 → 82.433 ms, startup 290.204 → 171.446 ms and RSS growth
57.203 → 56.230 MiB. The captured-module loop falls from 1,054.330 to
163.508 ms per million calls. Core snapshots allocate once rather than eleven
times at 1,000 tasks. Create/cancel bursts remain about 20 ms versus the original
per-script baseline's ~8 ms: strong task/owner records and their two C++ allocations
are retained. Pools/raw-pointer records were not adopted; they do not remove the
initial burst's lifetime requirements and add unjustified complexity/risk.

The established 36 cases plus three focused metadata/revision cases pass five
times in Windows/Linux Debug/Release/core ASan; normal native fixtures and full
Linux native ASan/LSan also pass, including a changed-subscriber ordering check.
This completes the measured optimization task under its stated acceptance
criteria, not a claim that every task operation beats the old architecture.
No public behavior, VM ownership, environments, pins or updater changed. Further
task-creation work is an optional profiled follow-up; no additional evidence is
required to retain these changes. See the [GL-019 report](shared-domains-validation.md#gl-019-optimization-2026-10-26)
for all spreads, CPU/allocation limits, rejected candidates and raw records.

**Integration (2026-10-26):** Main now preserves all three GL-019 commits through
normal merge `6badbae4b467a5544ffd027a1c7d7bd505cd0d46`, with no conflicts.
Its complete source tree equals qualified branch revision
`ad200aa468be56edf4812bb3a03daeb31d5bbdd8`; runtime/build/test code equals
`1756cc2600e5a59ea948e69a684f5abd93e32229`. The
[integration record](shared-domains-validation.md#gl-019-main-integration-2026-10-26)
distinguishes fresh checks from reused historical measurements. GL-019 stays
resolved for its measured scope. GL-017/GL-018 and the independent capability,
networking, persistence, asset and distribution issues remain open.

## GL-020: Animation RPCs omit sender and receiver-role authority

**Current status (2026-11-01): scoped authority correction integrated and freshly
verified on main. Native sanitizer qualification remains partial.**
The [adversarial record](animation-authority-qualification.md) and
[manifest](evidence/gl020-animation-authority-2026-11-01.json) distinguish current
runtime reproduction, correction, executed transport coverage and sanitizer gaps.
The [main integration record](animation-authority-main-integration.md) separates
the controlled merge and fresh main verification from branch qualification.
Historical findings and partial evidence follow.

**Historical status (2026-10-27): OPEN; source-verified independent presentation
authority defect, P1. No adversarial runtime reproduction was then claimed.**

**Evidence:** At security implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6`, `_setup_rpcs` still configures
`_relay_anim` and `_recv_anim` as ANY_PEER (roblox_network.h:703-704).
`_recv_anim:2027-2031` checks only whether payload `who` is the local peer, then
`_apply_anim_puppet:2032-2040` writes `peer_anim[who]` and invokes `gl_anim_apply`
on an existing puppet. `_relay_anim:2022-2026` likewise lacks receiver-role/
current-sender membership enforcement before applying and relaying.

**Boundary and scope:** A connected peer can choose a different remote puppet's
animation state via these entry points. This is a static presentation-authority
defect; no position/health mutation, player removal or chat sink is reached by
these animation methods. It therefore does not bypass the qualified GL-006/008
endpoint corrections, but prevents a general claim that every presentation RPC
is protected. GL-007's movement semantics are separate too.

**Closure:** Apply server-origin/client-origin role and transport-sender checks,
preserve valid ownership/late-join animation behavior, and demonstrate actual
two-client rejection without animation/cache/relay effects plus valid play/stop.
Do not close based only on a helper test or compilation. No animation fix is
included in the GL-006/008 branch.

**Functional implementation (2026-10-27): delivered on
`fix/gl-020-animation-lifecycle`; security qualification remains OPEN.** Runtime
commits `f9b27c6b6bb3caa3b8b617e029d45c858a546f9a` and
`7212b87e71f539a80d8e6b6977510fa075c0a2ba` add existing execution-role/
transport-sender guards, current service/session validation and AUTHORITY receive
configuration. Cached animation records bind the server-assigned UserId, preserve
pre-puppet/late-join updates and clear at character/session/service boundaries.
Tracks resolve AnimationPlayers by ObjectID; settings/completion replicate and
loaded clips are independent per character. No wire signature or shared-domain/
GL-019 ownership/hot-path change is introduced.

The [functional record](animation-lifecycle-validation.md) and its evidence
manifest distinguish exercised playback/lifecycle checks from closure acceptance.
GL-020 is **partially qualified**, not closed: actual two-client forged animation
receive/relay traffic, native handler guards with RPC authority relaxed, and
proof of rejection without cache/animation/relay effects remain for the security
follow-up. Existing GL-006/008 adversarial regressions are retained and passing;
they are not animation security qualification. GL-017/GL-018 remain independently
open. This branch is not merged into main and publishes no binaries.

**Executed functional qualification:** Windows/Linux Debug/Release core and
native groups, Windows core ASan and Linux full-native ASan/LSan pass. The 39-case
core runs in six configurations; four SCons builds pass and run their animation
fixtures. All 180 final native process results pass (90 animation, 40 existing
multiplayer/lifetime, 50 GL-006/008). Source/fixture and binary hashes match across
the checkout/workers; the [manifest](evidence/gl020-animation-qualification-2026-10-27.json)
retains exact evidence and failed fixture-attempt dispositions. No full animation
security closure is inferred from these results.

**Integration (2026-10-27): INTEGRATED FUNCTIONAL IMPLEMENTATION — SECURITY
QUALIFICATION PENDING.** Normal merge `6b140427e8ab39d97e12ee693f7cbda72abc7bba`
preserves all four GL-020 commits with a tree identical to qualified branch
`8e21d18a5504e0d703efbcf2a71a53d56314058e`. The
[integration record](animation-lifecycle-validation.md#main-integration-2026-10-27)
distinguishes fresh functional checks from reused immutable qualification.
GL-020 remains OPEN for animation-specific adversarial transport/handler evidence;
the historical finding and closure requirements above remain applicable. No
deferred adversarial qualification, binary release or general security certification
is performed by this integration. GL-007/GL-017/GL-018 remain independent.

**Adversarial follow-up (2026-11-01): corrected and qualified within the exercised
authority scope on the dedicated branch; full native sanitizer qualification
remains incomplete.** Actual ENet traffic confirms existing role/sender/session
guards reject wrong peers even with receive filtering relaxed. A distinct native
binder defect is reproduced: typed argument conversion diagnostics still permit
six malformed client-relay states and eight malformed server-receive states to
mutate real animation/cache state. Commit `358d6ffc491303e498d512792d09bdb62332bb25`
validates original Variants before conversion, preserving normal wire shapes,
catalog/life/admission semantics and the existing ownership/lifetime implementation.
Separate test commits and every failed attempt remain retained.

Windows Debug/Release and Linux Release each pass 80 core cases and 110 native
actors locally on DockerPC, including ten animation actors, 510 authority checks
and 1,003 total animation assertions. Linux Debug core and Windows/Linux core
sanitizer checks pass. Actual Character replacement, disconnect/reconnect,
late-join, callback cancellation and 23/20 per-packet no-mutation matrices execute.
Hosted core/native Windows/Linux artifacts have been independently
verified, including actual execution of all new cases. Linux stock-host native
ASan fails before assertions on RTLD_DEEPBIND; its diagnostic is preserved, and Windows native
ASan remains GL-018's gap. No sanitizer pass is substituted. Original GL-020
two-client authority closure criteria are satisfied on the branch; this does not
close GL-017/018, certify engine security, or integrate/publish the correction.

**Controlled integration (2026-11-01):** normal merge
`9f4a4d165abcc5e8b97af65fe7fda1eb191eba8f` preserves all four source commits and
exactly equals retained source tip `83e498b7c7ffd203857806488c8c3790439e9560`.
Qualified runtime/fixture identity `358d6ffc491303e498d512792d09bdb62332bb25`
is unchanged. Fresh hosted Windows/Linux core reports each pass all 80 cases;
native profiles each pass all 110 actors. Independent downloaded-artifact checks
verify every animation phase, all 510 authority checks and 1,003 assertions per
platform, including all 23/20 no-mutation matrices and actual actor stdout. See the
[integration manifest](evidence/gl020-main-integration-2026-11-01.json). No GL-017/018
fix, sanitizer suppression, release/updater enablement or dependency change is
included. Earlier failures, sanitizer gaps and branch evidence remain retained.

## GL-021: Inert signals omit lowercase once/wait aliases

**Classification: Verified construction-order discrepancy; runtime unexercised.**
Source revision `08b2bb83b7093a361c80b147b4827eb22715ad32`:
`src/core/luau_api.h:63-71` copies Connect/Wait/Once to connect/wait/once only when
each uppercase field already exists. `_gl_push_inert_signal` at `172-190` creates
a new table, installs Connect, calls that copier at `185`, then installs Once and
Wait at `186-189`. Thus the constructed table has connect but no once/wait fields.
The source's stated legacy signal contract includes all three lowercase names.
`GetPropertyChangedSignal` at `1290-1295` returns this inert table.

**Impact and limits:** scripts expecting the documented lowercase inert methods
would find nil. This is a source trace, not an executed failure, native lifetime
defect or security finding. Uppercase behavior and connection reference handling
are not reclassified. No focused assertion for these lowercase inert fields was
found in the current native fixtures. No code or tests changed during assessment.

**Separate follow-up:** reproduce with actual production GetPropertyChangedSignal;
decide and document the intended alias contract; correct construction order in a
focused compatibility fix. Require Connect/connect, Once/once, Wait/wait,
Disconnect/disconnect, Connected=false, nil Wait result, repeated calls with no
references or callbacks, GC and fresh-domain teardown. Preserve the inert nature.
Close only with linked implementation and executed regression evidence. Do not
silently combine this behavior change with the next GL-013 extraction.

## GL-022: Shared ModuleScript loses the second domain's child relay

**Original classification: Reproduced baseline callback compatibility gap; cause needs review.**
The first fifth-extraction fixture runs the same native ModuleScript in Server
and Client domains, with each module connecting game.ChildAdded. Both requiring
callers retire; a later child reaches the Server callback but the Client marker
never appears. This fails on unchanged production main `ce5e19f` / native fingerprint
`653e3ce3b6c3e4555365f53bea7490b1cd09664921deb9d6000ee8e7bd70f6c3`, Windows and
Linux Debug, before the refactor. Windows diagnostic replay shows only one native
child_entered_tree connection, targeting the shared ModuleScript with one bound ref.

`luau_api.h:1239-1286` selects the owner's native script node and uses
`Callable(sn, "_gl_child_event").bind(ref)` with an is_connected guard. Domains
share the same native ModuleScript receiver even though references/VMs differ.
The trace identifies the missing connection; exact callable equality/registration
cause and any broader signal impact remain unproven. No UAF, authority defect or
cache-isolation failure is established. Source, failed logs and diagnostic replay
are retained under worker `gl013-bootstrap/baseline-qualification1-debug` and
`baseline-diagnostic2-debug`; see the fifth manifest for hashes and scope.

Distinct native relay ModuleScripts pass the same both-domain/caller-retirement
assertions in baseline Windows/Linux Debug/Release. The final extraction fixture
uses those targets, retains shared-module cache/metatable checks and adds
cross-domain attribute watchers. The failed shared-target expectation is preserved,
not reported as passing or fixed. No production callback/ModuleScript logic is
changed to address this finding. The refactor's qualification does not close it.

**Separate follow-up:** reproduce the shared-native-target case, trace connection
identity and owner/reference cleanup, and implement a focused fix with two-domain,
same-domain multiple connection, disconnect, caller/module destruction and fresh
domain tests. Close only with linked fix and executed evidence.

**Resolution (2026-10-29): FIXED AND QUALIFIED on the development branch.**
The [record](gl022-child-relay-validation.md#stage-2-baseline-and-mechanism-2026-10-29)
reproduces the shared-target failure on both unchanged Debug platforms. Godot
source and native is_connected diagnostics confirm bound arguments are excluded
from signal identity; public references are process-wide/non-recycled. The
development branch uses distinct base Callables and host-owned cleanup, preserving
module-owned callbacks after caller retirement. Windows/Linux Debug/Release
core39 and 112 native actors pass; Windows core ASan and Linux core/full-native
ASan/LSan pass (28 native actors). Final hosted core39/native28 pass per platform
on `0cdaed65f0a9592c7a19302d837e5a0e68db5c58`; verified artifacts exercise all
four required GL-022 markers. The record preserves baseline failures, the child
signals' Connect-only protocol, test-adapter teardown access and limits.
This resolves the exercised scope on `fix/gl-022-cross-domain-child-relay`,
not main or unrelated findings. GL-017/018 and deferred GL-020 adversarial
qualification remain open.

**Main integration:** Normal merge `f1e1b9c492e56549a72739ad3086ad3ec9c32ee9`
preserves all three qualified GL-022 commits without conflicts. Runtime/build/
fixture inputs are unchanged from qualified revision `0cdaed6`; see the
[integration record](gl022-child-relay-validation.md#main-integration) for fresh
main CI results and retained limitations. Historical branch evidence above is
preserved; no broader issue closure or distribution readiness is inferred.

## GL-023: HttpService facade and serialization contract discrepancies

**Status: integrated by normal merge `669feae9d0602ae385f295390d4e348d8d667e57`,
preserving the qualified implementation
`aa5b765adfe09e2b4f3c7ee998bdbbdbc9cbc8d4` and all four source commits.**
The [main integration and caller migration record](httpservice-main-integration.md)
distinguishes fresh verification from retained branch qualification below.
Main input `0a66b4ab6c291917745c698728d952657b2d5abf` passes fresh hosted
Windows/Linux core (80 each) and native (95 each) jobs with verified artifacts.
The three added actors execute the migrated public HTTP example and strict JSON
recipe. There are no other executable public HttpService JSON callers to migrate
in the repository; private service codecs remain unchanged. External/imported
scripts require their own migration. See the
[integration manifest](evidence/gl023-main-integration-2026-10-31.json).
The original findings below remain historical evidence. Windows/Linux
Debug/Release and core ASan pass 80 cases; all five applicable full native
configurations (including Linux ASan/LSan) pass 92 actors. Both production SCons
targets pass HTTP qualification on each platform. Four hosted jobs and artifacts
are verified, including actual JSON/UUID/header/error/options/cancellation actors
and zero forbidden requests. See the [API and migration contract](httpservice-api.md),
[qualification record](httpservice-validation.md) and [evidence manifest](evidence/gl023-httpservice-2026-10-31.json).
This resolves the scoped API findings, not GL-017/018, broader
GL-020, graphical correctness or release/updater qualification.

The GL-018 follow-up reproduces a narrower host-locale counterexample to URL
encoding: `%w` leaves non-ASCII bytes unescaped on its Windows host. Branch
correction `241396b` replaces that class with explicit ASCII ranges and extends
existing core/native assertions to all 256 byte values. See the
[follow-up record](native-sanitizer-qualification.md#follow-up-from-66362c7) for
fresh verification and remaining sanitizer failures. This correction is not yet
integrated into main; GL-005's transport and authorization are unchanged.

At the audited revision,
`src/core/luau_stdlib.h:782–847` hardcodes HttpEnabled, catches public HTTP errors,
reconstructs RequestAsync with empty Headers, ignores noCache/compress, uses
legacy JSON fallbacks and constructs timestamp/random GUIDs. Native
`src/core/gl_http.cpp` also does not expose response headers in completion, so
the header limitation is not solely in the facade. The exact-origin/native-owner
boundary remains enforced by GL-005; these findings do not establish a bypass.

See the [scoped audit and prioritized recommendation](inherited-api-audit.md).
Follow-up must specify errors/null/unsupported options, retain async transport
and cancellation, preserve zero forbidden-origin hits, add bounded response
headers, and qualify GUID/encoding semantics. No HttpService changes are bundled
into GL-007 or Character V2. Character-adjacent architectural observations in
that audit are classified independently; they are not blanket security claims.


## GL-024: Part geometry cache teardown

**Integration (2026-10-31):** the qualified fix below is integrated on main by
`1c3176c0d9331dc1fa6849b98f8ed8e90e59c110`; see the
[fresh verification record](character-main-integration.md). The original branch
qualification below remains historical evidence for its exercised scope.

Character V2's actual Part collision fixture emitted five ObjectDB leak warnings
and late material/shape/mesh destruction diagnostics on Windows/Linux. The prior
source defines the three shared caches as header-static functions; only the
registration translation unit's material cache is explicitly cleared. Geometry
caches and translation-unit cache copies can survive until library unload,
after RenderingServer/PhysicsServer teardown. This is a native resource-lifetime
defect, not a security vulnerability or a newly reproduced baseline crash.

The Character V2 candidate gives each inline cache one program-wide identity and
clears materials, meshes and shapes during the existing scene uninitialization
boundary. The subsequent Model fixture exits without those resource diagnostics
on both workers. **Resolved for the exercised source scope on unmerged Character
V2 at `d7905dd`:** final Windows/Linux Debug/Release, Linux full-native ASan/LSan,
all four SCons products and all four hosted jobs/artifacts pass. See the
[qualification record](character-v2-validation.md). Main retains the pre-fix implementation
until an authorized merge. The failed logs are retained in the
[Character V2 work record](character-v2-development.md).

## GL-025: AnimationTrack completion/lifetime contract

**Integration (2026-10-31):** the qualified fix below is integrated on main by
`1c3176c0d9331dc1fa6849b98f8ed8e90e59c110`; see the
[fresh verification record](character-main-integration.md). GL-020's broader
animation-security gate remains open; the original branch evidence follows.

Source inspection during Character V2 finds that the AnimationTrack Luau getter
returns an inert signal for Ended/Stopped before reaching their real native
callback bindings. The later bindings also retain raw track/vector pointers;
native callback vectors have no destruction cleanup. Existing GL-020 functional
qualification does not establish actual Luau completion delivery or these
retained-view destruction cases.

Character V2 replaces the shadowed bindings with live ObjectID-backed signals,
gives tracks an explicit Character/Animator playback lease, cancels playback
when that owner retires, and releases callback references on retirement and
destruction. Cleanup checks its exact owned clip so an older track cannot stop
a later trusted gameplay timeline. Focused completion, replacement, destruction,
retained-method and reload checks pass in the final 76-check native fixture,
including actual R6 on both platforms. **Resolved for this scope on unmerged
Character V2 at `d7905dd`:** all five native configurations, four SCons products
and four hosted jobs/artifacts pass; see [qualification](character-v2-validation.md).
GL-020's independent broader animation-security qualification stays open.

## GL-026: Pinned Dictionary rvalue replacement leaks old storage

**Integration (2026-10-31):** main now contains the qualified bounded workaround
through `1c3176c0d9331dc1fa6849b98f8ed8e90e59c110`, with
[fresh verification](character-main-integration.md). The dependency-wide
follow-up remains open. The pinned dependency and original evidence below are unchanged.

Linux full-native ASan/LSan finds 576 bytes in four allocations when the new
Character scene-migration fixture calls actual RBXImporter.Begin. The four stacks
originate in its four Dictionary members. The pinned generated
`godot-cpp/gen/src/variant/dictionary.cpp` move assignment constructs a new
Dictionary over the old opaque storage without calling its destructor; the copy
assignment does release it. This is a confirmed bounded native leak, not an
exploitable memory-safety claim or proof about every generated builtin.

The candidate importer resets through four distinct const lvalues, selecting
copy assignment and retaining independent reports. The new protocol grant avoids
a duplicate Dictionary cache entirely, storing configuration in its existing
native grant structure. Dependencies remain pinned and unmodified. A broader
dependency upgrade or repository-wide assignment audit is separate follow-up.
**The bounded workaround is qualified on unmerged `d7905dd`:** three repeated
actual legacy imports pass the matching full-native ASan/LSan fixture with clean
exit, all platform/product checks and exact-source hosted CI pass. See
[qualification](character-v2-validation.md) and [work record](character-v2-development.md).
The dependency-wide follow-up remains open; no vendor change or repository-wide
assignment safety guarantee is claimed.
