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

## Passing focused and actual game results

Native/fixture input is `30682a33c418cde73c710c168fe09c1c14af4155`, fingerprint
`40270fc0232566b9cd3f06584feba29cfbf88902be7609cdb140f2e12e00132c` (101 files).
DockerPC's two-thread Release build passes, reusing pinned dependency caches.
The math-only probe exits 0 with empty stderr; the full existing CharacterV2
actor passes 107 checks, preserving all 96 prior checks. Its expected rejected
nonuniform-transform diagnostic remains visible. The first build setup failed
before configure because inherited PATH exceeded cmd limits; the task child now
uses a bounded explicit PATH. No system environment or toolchain changed.

Actual rendered MainPC replay at game source `b92b256` passes all
[28 checks](evidence/gl044045/rendered-local.json) with the current Release test
adapter, including victory/save, round restart, death/respawn and defeat/save.
This is a development replay over copied admitted game assets/host, explicitly
marked with `development-inputs.json`; it is not accepted-candidate packaging.
The adapter SHA-256 is
`ea3c850f23b64c245bc98bd47cf7288e034bdea1396282de89f0503eecadbb39`.
The [actual capture](evidence/gl044045/victory.png) was visually inspected.
Two acknowledged rounds produce one win and 72 shared career credits.
The 63.329-second replay averages 33.466 ms at the intentional 30 FPS cap,
peaks at 145.118 ms including startup and finishes with 166 scene nodes.
These are functional observations, not an uncapped performance comparison.
stderr retains `Failed to request display timeout override.`; there is no script
error or unexpected runtime failure. Physical devices/OS capture, Linux rendering
and wider allocation profiling remain outside this claim.

The [failed baseline](evidence/gl044045/baseline.txt) remains retained.
Fresh ordinary core passes at `30682a3`; native/full-native sanitizer and the
four-profile non-publishing candidate are still running. Their exact run IDs are
`42743902074`, `42744024821` and `42744369456` respectively. No required pending
gate is being called passed, and neither GL-044 nor GL-045 closes at this point.

## Retained candidate failure and bounded fixture correction

Candidate `42744369456` Windows Debug builds both products successfully, then
fails Character Listen reconnect: `States()[0]` raises a GDScript error at
CharacterIntegration line 457. Although the process later prints PASS and exits
0, the existing strict checker correctly rejects the script error. Failed profile
artifact `13731907377`, digest
`bf38737e20f73d8c0751f9e71ad536e19bd1e9e75943fe6e487cf7908edd19c5`,
retains the complete failure. No GL-044/045 math assertion fails. Independent
ordinary Windows/Linux 141-actor and matching full-native sanitizer qualification
at `30682a3` passes; that does not make this candidate attempt successful.

The fixture's Mark opened its final path before writing/closing its contents,
while Wait checked existence alone. A DockerPC Godot-only control reproduces
`VisibleBeforeClose=true`, `EarlyValue=""`, `ParsedEarly=0`, followed by complete
`1234` after close. Its logs are retained at
`C:/Sandbox/Codex/GL04404520261109/marker-control/`. The historical peer-zero
failure is consistent with this demonstrated publication window; its actual
marker bytes were not retained, so this is not a claim to have captured the
original empty read directly. It is separate from the native math fixes.

Mark now closes a per-process temporary file and renames it within the same
directory, following RemoteFunctions.gd's existing publication pattern. Open or
rename failure fails the fixture explicitly. No assertion, deadline, production
runtime, authority or networking implementation changes. This actual failed
qualification justifies the small fixture correction (GL-046), rather than a
new verification framework or accepting PASS after a script error. Affected
Character/controller groups and candidate inputs must be requalified; the
original failed attempt remains failed. Native fingerprint stays unchanged.

The complete [failed profile diagnostic](evidence/gl044045/candidate-windows-debug-failure.txt)
is versioned as well as retained in its original artifact. After preserving that
artifact, remaining old candidate jobs are cancelled as superseded, not counted
as passing. Current qualification inputs are `8eddb826667fe1dc95dc92f875ef9be89e971d40`:
[candidate](https://github.com/gmoddev/GodotLuau/actions/runs/42748734970),
[native](https://github.com/gmoddev/GodotLuau/actions/runs/42748697994),
[core](https://github.com/gmoddev/GodotLuau/actions/runs/42748698003) and
[full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/42748739079).
DockerPC's affected Release qualification passes all 20 Character and seven
controller actors with the corrected marker and unchanged native binary.
Matching Windows/Linux full-native qualification at the prior native/fixture
revision `30682a3` independently passes 85 core/141 native actors and controls,
with no unexpected reports; its native fingerprint is still the current value.
Those successful results do not replace the new fixture-input gates.

The next candidate `42748734970` Linux Release builds successfully but fails
NetworkSecurity Listen: client1 reports `State deadline peer=0`, its `FORGED_RELAY`
text appears under the correct authenticated name Player2, and the expected
two-message burst has one message. The unchanged fixture reads First/Second from
its own non-atomic peer marker files. Attack(Second) with Second=0 broadcasts;
its `_relay_chat` reaches the server as a valid own-sender request, consuming one
token and invalidating the intended wrong-recipient test setup. Native
wrong-role receive RPCs remain rejected in the retained logs. This is evidence
of invalid fixture target setup, not proof of a new authority bypass; exact
historical marker bytes were again not uploaded.

Failed profile artifact `13733596670` has digest
`ec250710173778df8cceab6284bf055210c466faec963dba66b4e7a75066202c`.
NetworkSecurity.Mark receives the same completed-file publication correction;
all attacks, sender/role checks, message/token expectations and deadlines remain
unchanged. GL-046 therefore covers both observed marker-writer gaps. No other
runtime or networking correction is bundled. Affected security/Character/
controller qualification and fresh candidate inputs remain required.

## Current qualification checkpoint (2026-11-10 UTC)

At `8eddb826667fe1dc95dc92f875ef9be89e971d40`, both platforms' ordinary
[native](https://github.com/gmoddev/GodotLuau/actions/runs/42748697994) and
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/42748739079)
runs finish successfully. Downloaded artifacts verify 141 actors, the 107-check
Model fixture and unchanged native fingerprint `40270fc0...`. Sanitizer controls
pass, all 1,165 instrumented translation units are recorded and no unexpected
reports occur. Linux leak detection is enabled; Windows LSan remains unsupported.
These runs include the Character marker correction, but precede the security
marker correction. They are not represented as a full sanitizer run of the final
security fixture.

Final fixture input is `4510ab4006f3e13a80f564cc3088aae01406192e`. DockerPC's
affected ten security actors pass in Release, in addition to the earlier 20
Character/seven controller actors. The final input's downloaded
[core artifacts](https://github.com/gmoddev/GodotLuau/actions/runs/42752080974)
verify 85 cases and 29 input-graph assertions per platform.
[Native](https://github.com/gmoddev/GodotLuau/actions/runs/42752081142) and
[candidate](https://github.com/gmoddev/GodotLuau/actions/runs/42752234638)
qualification remain pending at this checkpoint. Candidate core ASan/LSan and
both rejection/retention jobs pass; pending source profiles, package startup and
final acceptance are not counted as passing.

No C++ input has changed since `30682a3`, and no game runtime script has changed
since `b92b256`. The [machine-readable receipt](evidence/gl044045/qualification-2026-11-09.json)
distinguishes these identities, both failed candidate attempts and final-input
results. An accepted current candidate is still required for production-package
listen/dedicated game replay; the passing development replay is not relabeled.

DockerPC cleanup remains complete: 31.85 GiB recovered without deletion failures.
A later capacity observation shows 17.35 GiB free after unrelated disk activity;
the original before/after values and per-file audit remain retained. No task-owned
test processes remained on DockerPC or MainPC at that observation. Source,
toolchain caches and historical evidence remain available. Follow-up work stays
on `codex/gl-044-045-relay-luau`, unmerged; main remains `6db2e2c`.

## Legacy cancellation fixture: reproduced deferred-retirement window

Final-input Linux native `42752081142` passes all 141 actors, with the expected
107 Model checks and both corrected marker hashes. Windows builds successfully
but fails legacy Dedicated client2 before reaching the new math actor. The
[original diagnostic](evidence/gl044045/native-windows-lifecycle-failure.txt)
contains a bare FAIL; the old fixture did not log whether wrong-role execution
or the canceled-invoke flag caused it. Do not claim that missing historical flag
was captured or that this is a new runtime authority defect.

DockerPC's [diagnostic control](evidence/gl044045/network-retirement-control.json)
uses the unchanged Release adapter and existing regression driver. Normal input
passes eight actors. A deliberate 250 ms client stall makes both Dedicated
clients fail: continuation is false before `queue_free`, true before tree exit,
and wrong-role flags remain false. The response resumes an owner that has not
yet retired. Source confirms `ScriptNodeBase::StopRun` cancels its owner on
`NOTIFICATION_EXIT_TREE`; deferred deletion requests are not that boundary.

GL-047's fixture correction explicitly removes the victim script and retiring
NetworkService from the tree before queuing destruction. Existing assertions,
timeouts, queued destruction and actual ENet transport remain. Two formerly
silent failure conditions now log their reason. No production behavior changes.
Corrected normal and delayed controls each pass eight actors; the actual
corrected fixture, without diagnostic overlays, passes 16 actors over two
repetitions. All controls/log identities and the diagnostic source are retained.

Fresh Windows/Linux native qualification must cover this corrected fixture.
Candidate `42752234638` remains running at its original immutable `4510ab4`
inputs. If accepted, its products qualify that recorded source and unchanged
native fingerprint; they do not imply execution of this later fixture correction.
The prior Windows/Linux full-native passes likewise retain their exact fixture
revisions. The development branch stays unmerged, and failed runs stay failed.

## Accepted products and game diagnostic follow-up

Candidate [42752234638](https://github.com/gmoddev/GodotLuau/actions/runs/42752234638)
passes all ten gates at immutable `4510ab4`: four 85-core/141-native profiles,
Linux core ASan/LSan, both rejection/retention jobs, both extracted-package
startups and final acceptance. All four downloaded profiles execute 107 Model
checks with the expected math fixture hash. Existing CheckPackage/CheckJobs on
DockerPC verifies both downloaded 133-member packages, their provenance, native
binaries, Release persistence companions and startup logs. The first verifier
setup attempt lacked the archived tools directory; unchanged authoritative
checker/policy files were supplied before the successful check. It was a setup
failure, not an invalid candidate or runtime failure.

Fresh corrected-fixture [core](https://github.com/gmoddev/GodotLuau/actions/runs/42755853368)
and [native](https://github.com/gmoddev/GodotLuau/actions/runs/42755853334)
finish successfully on both platforms at `e65e3b8`: 85 core/29 graph assertions,
141 actors/107 Model checks and exact Character/security/retirement fixture
hashes. Native C++ inputs remain identical to the accepted product. Existing
full-native ASan/LSan results retain their earlier exact fixture revisions.

Rendered production-ZIP listen/dedicated sessions at game `e65e3b8` finish with
all 112 functional checks passing across nine actor processes. Both leaders
complete 28 gameplay checks; each observer/late joiner completes nine, and the
dedicated server completes two. Actual victory images were visually inspected.
However, log inspection finds an unhandled `Remote peer not ready` in each
server's Publish callback during joining. Preserve this first replay as
functional success with an unresolved diagnostic, not a clean qualification.
The known display warning and three retired-channel engine diagnostics in each
server stderr are also retained under the existing GL-017/018 limits.

GL-048 corrects the Luau snapshot producer, not native admission. Publish takes
one bounded live-Player list and calls FireClient independently. Only the exact
peer-not-ready rejection is deferred until the next current snapshot; every
other error is rethrown. Nothing has been admitted for that peer, so this does
not silently discard reliable work. Ready peers keep receiving state while a
new peer negotiates. No new queue, scheduler, readiness probe or Godot adapter
is introduced. Re-run the two actual game sessions and inspect their diagnostics
before packaging or calling the game migration qualified. The accepted native
product and unchanged core/native inputs need no rebuild for this Luau change.

## Qualified runtime and rendered game checkpoint

The GL-048 replay at `0ecc2b5443f3f3405479a53a50c5b0b63a6283eb` passes all
112 checks, with no unhandled script diagnostics. Readiness remains native
authority; the example only handles the precise pre-admission failure.
The [listen report](evidence/gl044045/game-listen.json) has four successful actor
processes and 55 checks; the [dedicated report](evidence/gl044045/game-dedicated.json)
has a headless server/four rendered clients and 57 checks. Both leaders complete
28 checks and finish two acknowledged rounds/one win/72 career credits. Current
[listen](evidence/gl044045/listen-victory.png) and
[dedicated](evidence/gl044045/dedicated-victory.png) victory captures were inspected.
The [summary](evidence/gl044045/game-rendered-summary.json) records actual engine,
production-library and supplied-candidate identities for every actor.

| Rendered production replay | Seconds | Mean frame ms | Peak frame ms | Final native objects |
| --- | ---: | ---: | ---: | ---: |
| Listen leader | 64.304 | 33.473 | 145.494 | 167 |
| Dedicated leader | 64.473 | 33.479 | 141.394 | 167 |

Both use the intentional 30 FPS cap on MainPC's admitted OpenGL host. These are
functional frame observations, not an uncapped benchmark or improvement claim.
The four retired-channel engine errors and eight display warnings remain
visible; neither is suppressed or called sanitizer-clean teardown. The first
diagnostic-bearing replay is retained in
[its own record](evidence/gl044045/game-admission-original.json).

The [downloaded-package verification](evidence/gl044045/candidate-package-verification.json)
checks Windows ZIP `41551f6e5a73a3b49df99e535359a071ac20fc55c93c31e50044cc8945a07a6c`
and Linux ZIP `4be5781d60da06fdab0095336f23cb5e5a56e54acd8af1445b2eda377f8e1e4d`.
Each has 133 verified members and matching provenance/companions/startup logs.
Windows production Release DLL is
`bf97e93b4638c8e47cb39b7bf6d7a7dc12c8ce70b8f2d3c62739f962e2853bd8`.
The two native fixes remain `30682a3`; accepted products use `4510ab4`; final
native fixture qualification uses `e65e3b8`; final game runtime uses `0ecc2b5`.
No qualified C++/dependency input changes between these revisions.

GL-044/045 close within those native API profiles; GL-046/047 close within their
recorded fixture profiles; GL-048 closes within the rendered game replay. The
corrected test harness is not falsely attributed to the older sanitizer or
candidate revision. Existing GL-017/018, full-game sanitizer, asset-provenance,
physical-device, Linux-rendering, WAN, older-glibc/pristine-consumer and allocation
profiling limitations remain. There is no independent byte-for-byte build
reproducibility or distribution claim.

The standalone game workflow now selects accepted candidate `42752234638` and
retains read-only permissions. Final fresh game-package startup/payload
verification follows this checkpoint. Main stays `6db2e2c`, development history
is preserved, and release/updater publication remains disabled.

## Final standalone package and closure

**QUALIFIED WITH DOCUMENTED LIMITATIONS** within the native API and rendered
Windows game profiles above. [Game package run 42762178179](https://github.com/gmoddev/GodotLuau/actions/runs/42762178179)
passes at source `c9c03b0c573bda5a351cbc806b90af6bc5ac6189`, reusing accepted
native candidate `42752234638`. Actual extracted startup exits 0, reaches Rules
ready and has empty stderr. Artifact `13738073089` has GitHub digest
`9f40aa00133647ed303286315b0ff89fa6c9e6edd4dc3c8027de31b6057f3d02`.

DockerPC [verifies the downloaded archive](evidence/gl044045/standalone-game-package-verification.json):
157 payloads/158 ZIP members, every recorded size/hash, embedded native candidate
files and all four LF-normalized game/controller runtime scripts match qualified
inputs. Game ZIP SHA-256 is
`29e1348146a0b9417b114d3f62146462c87a1ea9e7cbc9f346bb93ed5a46c521`
(25,369,076 bytes). This evidence update changes no qualified runtime/test input;
the package's exact source revision remains the value above.

Final process inspection finds no task-owned test processes on DockerPC or
MainPC. Caches, source snapshots and original failure evidence remain retained;
unrelated workloads are untouched. DockerPC has 7,366,324,224 free bytes at the
final observation, reflecting continuing disk activity after the earlier cleanup;
MainPC has 250,082,082,816. No further builds are started. Main remains
`6db2e2c563dfb4680dc09f1451f05dba5b778069`; GL-043's source branch is retained.
The compatibility/game branch stays unmerged. Releases and updater distribution
remain disabled. Stop here; no additional development phase is started.
