# Networking Foundation 2 campaign journal

## Targeted refresh correction

Stage probe `v20` records 81.21 s total refresh time, with 0.79 s encoding,
5.49 s index work, 11.33 s metadata and 16.55 s admitted-record visibility
checks. Excluded components are outside those stage subtotals; all work remains
inside total refresh timing. Only 585 snapshots rebuild across 256 refreshes,
so wholesale re-encoding is not the measured bottleneck.

The bounded correction excludes Part-owned geometry before visibility traversal,
verifies the three captured scope roots once per refresh, and checks the direct
child's own server-only exclusions rather than repeatedly traversing the same
verified ancestry. Deeper objects retain the existing full visibility check.
Reuse the resolved parent and Part pose origin. No dirty-only source cache,
new scheduler, authority grant or structural ordering change is introduced.

Snapshot `v21` passes all six relevance actors, including a new direct-root and
descendant server-only-name exclusion check; fixture hash is
`7ebfa5ec995f6649f7768923646813d10670f8293335ffa2c8fee31cd5f2f295`.
The one-peer 512-object probe passes both products: candidate refresh total is
23.26 s / 280 calls (maximum 149.7 ms), versus the preceding probe's 81.21 s /
256 calls. Candidate whole-server user CPU is 40.80 s and frame p95 148.2 ms;
paired main is 24.80 s and 11.8 ms. These are diagnostic probes with changing
worker background load, not repeated general performance qualification. GL-034
remains open. The earlier write-boundary timing experiment is removed from the
final correction; final snapshot `v22` requires its own tests and hosted gates.

Final native fingerprint
`738a60cf761be0b691f67d689cb2016cf9260af5f68282f66a3e192f206eccbc`
builds on DockerPC and passes the six-actor relevance fixture in 23.75 s, with
the exact committed fixture and no unexpected ASan report. DLL SHA-256 is
`53a1f38f7c986b7aea7580f065f2305de18a768aa2db2a4ee57dbb78bf2beeb9`.
Legacy replication, Function, Character and animation follow-ups are running;
fresh hosted qualification is required for this source change.

The exact-main baseline candidate replay `41773880784` is rejected because Linux
Release's Dedicated observer fails orientation/configuration/correction and
replacement checks. Captured `characters.log` SHA-256 is
`213f6c7b099b57797528e7905d199ba0f0cb7dc72ceef50fd34c500ff46f086f`.
This is retained baseline counterevidence, not a new candidate regression.
Windows Release at that same run passes and is independently strict-rechecked
against the frozen main worktree for a possible Windows-only Release comparison.
Do not describe the whole baseline candidate as qualified.

## Platform checkpoint completed at `532650f`

All four hosted workflows finish successfully: [core](https://github.com/gmoddev/GodotLuau/actions/runs/41771508468),
[ordinary native](https://github.com/gmoddev/GodotLuau/actions/runs/41771508432),
[full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/41771578913)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41771581733).
Independent frozen-revision verification establishes 85 core cases and 130 native
actors per Windows/Linux Debug/Release candidate profile, both sanitizer profiles
and their detection controls, matching source/product/host/log/harness hashes,
4,000 rehashed unique UUIDs per candidate profile, and both extracted 133-member
packages with Debug/Release companion startup. Nonpublishing acceptance hash is
`30aed5118e66f0ef5d8d6fdc339adf89d7278f61b8ceb987b25a5ae823dc7412`.
The [runtime](evidence/networking2-532650f-runtime-verification.json) and
[candidate](evidence/networking2-532650f-candidate-verification.json) receipts
preserve exact identities. One ephemeral GL-003 mailbox per sanitizer archive
is absent; required captured logs are checked. GL-031 and GL-032 close within
their exercised scope. GL-033 and GL-034 remain open, and the broader Phase 2–4
qualification remains partial. No main merge or publication follows this gate.

## Mixed-workload regression — investigation, not qualification

The complete ordinary core/native and full-native sanitizer workflows for
`532650f` now pass on Windows and Linux. Downloaded artifacts independently
verify 85 core cases, 130 native actors, matching source/products and admitted
hosts ([receipt](evidence/networking2-532650f-runtime-verification.json)).
Candidate Windows Release remains running; package acceptance is pending.

The two paired one-peer mixed-world ASan trials expose a substantial performance
regression, tracked as GL-034. At 512 objects the candidate server frame p95 is
414.5/426.2 ms versus main's 12.2/12.9 ms; Fire/echo RTT p95 is approximately
1.44 s versus 37.4/41.1 ms. Both products satisfy the workload's functional
assertions. Fewer candidate replicas do not establish an optimization when CPU,
frame time and wire traffic worsen. Preserve the negative result. Raw archive 6
contains 8,368 members / 26,021,928 bytes, SHA-256
`f183c5a502d82e6dea71ea4bff4c8ecd9ab5000f2785b9d8c62de2aa32ca00e3`.
The [versioned mixed receipt](evidence/networking2-mixed-asandebug.json) records
all eight passing and sixteen resource-blocked configurations separately.

A focused probe moves the existing Character-authority denial before the new
world projection scan in `CanWriteCharacter`; the same denial predicates remain
required. Read-only cumulative/max timings separately observe this boundary and
catalog refresh. Snapshot `v19`, fingerprint
`d68590d1e22aee4358d7b0b88aa5360dbeb11d09435b4fd44b9cd377ac56edf9`,
builds on DockerPC Windows Debug ASan. It is an investigation product, not a
qualified replacement for `532650f`. Its measured outcome and any further fix
require their own evidence. No main merge or publication is authorized.

The `v19` probe reproduces the cost: 254 catalog refreshes total 85.26 s of
wall time, maximum 836.5 ms, versus 91.69 s of whole-server user CPU. The shared
Client guard has zero observed calls in this dedicated-server workload. Revert
the unhelpful denial-order experiment; retain focused stage timings to isolate
refresh work. This timing attribution does not establish a fix or a comparable
before/after speedup. Other worker builds are active during follow-up probes.

## Hosted checkpoint and mixed measurement follow-up

Implementation checkpoint `532650f926723b588b04559ec242d8fa20e07239` is pushed;
main remains `9f52b273cf977dce9c0541ff718cfb44dfb54c31`. Fresh core workflow
`41771508468` passes 85 cases on Windows/Linux; candidate `41771581733` also
passes Linux core ASan/LSan. Linux ordinary native `41771508432` and Linux
full-native sanitizer `41771578913` pass their complete exercised matrices;
other profiles were still running at this checkpoint. Do not infer their
outcomes from the successful Linux records. Baseline nonpublishing candidate
`41773880784` is dispatched against exact main to obtain comparable Release
products; no main source is modified.

The [mixed benchmark method](networking2-benchmarks.md) adds actual worlds,
Character/animation, Functions, property/structural and relevance churn.
One-peer 64/512-world comparisons pass both products in two interleaved trials
of 64 samples each. All sixteen/32-peer ASan configurations are explicitly
resource-blocked before launch, with about 9 GB available commit. The first
smoke attempt correctly rejected a TYPE_VALUE animation track; switch the
fixture to the existing approved TYPE_SCALE_3D presentation contract. Do not
weaken GL-007 animation policy. Exporting a qualified, nonpublishing Release host
provides a lighter experiment profile without a dependency/host patch or machine
configuration change. Full campaign qualification remains incomplete.

## Qualified Phase 1 checkpoint — 2026-11-04 UTC

GL-030 is QUALIFIED at `2296c966937223994a94cc2f15af29e9f829557b`, native
fingerprint `3ba654399e4af64bb5da99b6befe9ff4a2137fb6af5d0045649fc498498771dc`.
Hosted [core](https://github.com/gmoddev/GodotLuau/actions/runs/41756648637),
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41756648640),
[full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/41756776065)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41756783923)
all finish successfully. Downloaded artifacts were checked against the frozen
exact-revision worktree, not the later relevance working tree. Both sanitizer
profiles pass their detection controls and all checks (Linux 24, Windows 23),
with no unexpected report; each includes 81 core cases and 122 native actors.
Candidate Windows/Linux Debug/Release each pass 81 core cases and 122 actors;
both extracted 133-member packages pass Debug/Release companion startup.
Acceptance `f305340f807ac88cae0325fa25f5475a972f3b828b15eefec1b061508a3e8883`
remains nonpublishing. Versioned receipts record products, host admission,
compiler instrumentation and required log/harness hashes:
[runtime](evidence/gl030-2296c96-runtime-verification.json),
[candidate](evidence/gl030-2296c96-candidate-verification.json).

Archive limitation: five generated Linux Godot profile logs and two transient
GL-003 mailbox files are missing. Their exact paths and expected hashes are
preserved, rather than asserted verified. Required captured actor stdout/stderr,
case evidence and sanitizer reports/controls remain independently checked.

## Phase 2/3 implementation checkpoint — qualification in progress

The expanded six-actor Listen/Dedicated relevance fixture now passes Windows
Debug ASan in 25.188 seconds on snapshot `v18`, native fingerprint
`a7c63d0ea12364a85a6358863dc0d3f5e77cbb33a6ccbc219f358564fac710d7`,
DLL `962ac28821ad2ecd38adccb1cb7b4e204980db95f6303d3249d4651f0ce360ec`.
Actual fixture overlay hash is
`c80be53a8acd4dc468784ab7148dc64343e9df324e222a7d3088ddf0a6eac2f8`.
It exercises source/replica identity, spatial enter/leave/reentry, independent
peer state, wrong-session/future ACK rejection, shared Client mutation denial,
64-write coalescing, deterministic native WouldBlock and healthy-peer progress,
both reparent barriers, reference closure/clearing/cycles, sticky global pin,
generation-tagged server/owned physics, forged physics rejection by effects,
same-name replacement, reconnect and cancellation inside a property callback.
No unexpected ASan report occurs. The full platform matrix remains pending.

At the same native source, the selected follow-up passes 20 Character actors
(144.703 s), ten animation actors (92.984 s), six Function actors (19.484 s),
and the two legacy replication actors (7.219 s). A further six-actor run adds
explicit 9,000-byte snapshot overflow and verifies terminal rejection without
partial materialization or retained queue ownership (24.703 s). Latest relevance
fixture hash is `ae1c93acecd62334c24a79867ca0e90fb9a2e8673fef7436d5a8756b5f94c526`.
The [checkpoint receipt](evidence/networking2-projection-checkpoint.json) records
50 selected process executions, including the six repeated relevance actors;
this is not a 130-actor complete native gate. Raw checkpoint 5 contains 1,877
members, 3,077,527 bytes, SHA-256
`887ab8a28504d8c7e570f71ed8b19f9bbac97d87e957b50443eaeb60c9a10f78`.
The [Phase 1 benchmark receipt](evidence/networking2-phase1-benchmark.json)
preserves all eight completed paired configurations, raw summary metrics,
six allocator/mapping reports and nonempty teardown stderr. It compares GL-030
with exact main, not the later relevance implementation.

Four new exact production-core index test bodies separately pass MSVC ASan:
spatial/global queries, cyclic/missing dependency closure, invalid-input
nonmutation and 16,384-source/4,096-view boundaries. This focused execution is
not the complete core suite. Required hosted gates increase from 81 to 85 core
cases and from 122 to 130 native actors; existing cases are retained.

Development failures are preserved. New-frame queue age initially subtracted a
later enqueue timestamp from the tick's earlier unsigned timestamp; saturating
comparison fixes immediate false expiry. Same-name replacement initially
created before retirement; canonical retirement and receiver teardown now
precede replacement attachment. Listen Client attribute protection initially
treated Game attributes as subtree mutations and suppressed the fixture marker;
protect the actual attribute owner without conflating it with destruction.
ObjectValue's inherited scalar bridge omitted Instance read/write (GL-032), so
native source references remained nil despite a legacy shadow. Add a focused
live Instance/nil path, retain scalar-converter boundaries, and qualify actual
native reference closure. An unsupported Changed:Once test assumption was
corrected to the existing Connect interface. The successful cancellation check
still requires disconnect during the actual production callback.

Local RemoteEvent pressure replays fail at unrelated readiness/final-sequence
steps on both candidate and the qualified GL-030 binary; GL-033 tracks the
unresolved attribution. They are not suppressed or reported passing. Earlier
GL-030 hosted successes remain exact-revision counterevidence.

The 32-peer benchmark archive contains six ASan allocator exhaustion/failed
mapping reports on the baseline. This identifies resource exhaustion in that
profile rather than an established lifetime report. No 32-peer candidate result
exists. Preserve the negative run and do not retry the same oversized ASan
workload without a resource-supported profile. Completed 1/16-peer measurements
remain narrow network-only evidence, with two candidate teardown channel errors
also retained; they do not establish the complete Phase 4 acceptance matrix.

An opt-in native projection now compiles on DockerPC Windows Debug ASan as
snapshot `v9`, fingerprint `b8f2ff1faef41ac544cd8cf5c20f1a7d1a67648fc0ffe63d372437628a07d685`.
It is not yet runtime-qualified. It uses the existing native/application queue,
cached bounded snapshots, per-peer desired/planned/known/materialized state,
generation-tagged physics and a server-owned index. Listen Client mutations of
registered server projection objects are denied through the existing write
boundary. Character/Player authority and the qualified animation path remain
separate. ADR-011 will record the final exercised contract and limitations.

Two comparable 1/16-peer RemoteEvent-only trials per baseline/candidate finish
successfully. The 32-peer baseline exits before readiness; no 32-peer candidate
result or general performance improvement is established. These are partial
measurements, not the Phase 4 workload matrix. A prior attempt exhausted worker
C: space. Only hash-verified task-created fixture DLL/companion copies were
removed (174 files, 4,242,457,088 bytes), preserving original products, logs,
sources and shared caches. Subsequent benchmark cleanup retires verified fixture
copies after their owned processes stop. Negative attempts remain retained.

Started 2026-11-03 from verified local and remote main
`9f52b273cf977dce9c0541ff718cfb44dfb54c31`, on
`foundation/networking-2`. Initial checkout clean, sole worktree, no active
CodexLock claims. Dependency pins unchanged: godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`, Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

## Authority and acceptance

The owner's campaign authorizes bounded implementation/refactoring, tests,
benchmarks, existing workers and hosted CI, commits and pushes to this branch.
No main merge, history rewrite, dependency/host-patch changes, release or updater
publication. DockerPC is the primary local worker; MainPC is fallback only.
Other local workers and unrelated workloads are outside scope.

Work proceeds in order: GL-030 terminal outcomes; server-owned per-peer
relevance; structural batching/coalescing/admission; comparable performance and
adversarial qualification. Each phase needs independently recorded source,
actual executed coverage, limitations and qualification status. Existing
ADR-002 through ADR-009 contracts and prior qualified subsystems remain required.

## Preparation and baseline findings

Read the contribution policy, documentation authority index, current
architecture, invariants, GL-030 record, GL-029 decisions/integration evidence
and source-pinned Gargantuan comparison. Current source confirms public
RemoteFunction calls pass timeout zero, int64 correlation is narrowed to int
for transmission, handler correlation passes through a Lua double, and the
NetworkService age GC erases records after sixty seconds without settling the
domain wait. These are source findings; runtime nonresponse/exhaustion has not
yet been reproduced for this campaign.

Existing expected-peer checks, owner/thread cancellation, service/disconnect
failure completion, protected domain resumption and yielding handlers are useful
baseline behavior to preserve. Endpoint lookup currently uses a path; retained
Invoke closures capture a raw RemoteFunction pointer. Production changes and
new qualification are pending.

## Phase status

| Phase | Status | Evidence |
| --- | --- | --- |
| GL-030 | IMPLEMENTED; latest full qualification pending | Local and hosted attempts below; not closed |
| Relevance | PREPARATION ONLY; runtime not implemented | GL-031 baseline and ADR-011; policy prototype is not runtime evidence |
| Structural replication | NOT STARTED | Pending relevance milestone |
| Performance/scalability | NOT STARTED | No new measurements |

## Worker preparation

DockerPC SSH responds as `HostPC`. Read-only capacity inventory reports roughly
12 GB free on C:, 65 GB on D:, and 1.72 TB on E:. Existing GodotLuau workspaces,
toolchains and caches will be inspected and reused without destructive cleanup.
No campaign build or game process has started at this checkpoint.

## GL-030 implementation checkpoint

Selected a finite 30-second default after inspecting all repository Invoke
callers; only test calls exist, with brief yielding network handlers. The trusted
project may select 0.05–300 seconds. [ADR-010](adr-010-remotefunction-terminal-outcomes.md)
records the explicit deadline/payload/wire compatibility changes, reuse of the
native publication/session authority, exact serving-task ownership and bounds.

Windows matching-host ASan development builds v1/v2 compile successfully using
two jobs and the existing incremental build cache. v1 took 45.782 seconds and
v2 took 32.609 seconds. v2 native fingerprint:
`f1bdd843572b6a9d917689c4e3026a472fdec4ec8f44ab3ad2a6cbb8d3abb000`.
These are development compile results, not qualification of later changes.

The first v2 real-ENet run passes the two clients' success/multiple-return/nil,
typed payload, yielding, explicit handler error, missing handler, timeout,
manual-resume/new-wait and payload-bound assertions. It fails the Server's
reverse-call assertion: the fixture passed a native Node through GetAttribute,
and the initial hypothesis was fixture Player resolution. Change the fixture to
select the actual Player by authoritative UserId; retain this failure. Later
diagnostics below establish a production continuation defect as well.
The run reports no unexpected ASan report. It does not qualify InvokeClient.

Added further candidate checks for full-width IDs beyond Lua double precision,
checked exhaustion, exact pending ceilings, explicit cancellation, actual
wrong-peer/session/generation replies and duplicate late responses. These are
pending execution. Original logs/products/source snapshots remain on DockerPC
under `C:\Sandbox\Codex\Networking2`; controller copies use
`C:\Users\aiden\.codex\artifacts\godotluau\networking2`.

The v3 diagnostic run confirms the continuation returned original call arguments
alongside results (`InvokeServer` returned nine values starting with its receiver;
`InvokeClient` returned four starting with Function/Player). This is a candidate
regression, not a baseline claim or fixture-only failure. Clear the C function's
argument stack before yielding so the continuation exposes only resumed results.
Requalification is pending. Full-width identity, exact 64-request admission,
cancellation, actual wrong-sender/session/generation and late-duplicate rejection
passed in the failed run; success behavior remains unqualified until the fix.
DockerPC's bounded Docker server-version query times out after ten seconds. No
daemon restart, service change, global cleanup or unrelated container operation
was attempted. Use hosted Linux runners if this independent infrastructure gap
persists.

v4 clears the native argument stack before yield. All six focused function
actors pass on Windows ASan with the updated diagnostic fixture: success and
multiple returns in both directions, yielding, full-width IDs, explicit errors,
bounded timeout, manual resume followed by a fresh wait, exact pending ceilings,
cancellation, actual adversarial transport, duplicate-request rejection,
endpoint replacement and checked identity exhaustion. Native fingerprint
`43041d6a72e3321a0898b1885996d5636ca2425b46f1346aaa1ff9f25dc5037a`;
extension SHA-256 `ec58152f6a709bcc045d4ac556caac885858ce80f3ac84f4b3a4e7e3ebdc6cec`.
Fixture SHA-256 `034396fb1d58b5860cc8c751e1ffb613ba15c655a7fe68ff8ba94e7976e6ae58`.

The broader unchanged Integration identity/GC workload hits the 25 ms gameplay
budget in two v4 runs. A fresh build of exact main, fingerprint
`27822f8ec52e43c440c20dad7f6038d6d70fc8d28332b6665eabb2b8c6d279fa`,
reproduces the same Server and Client failure at Identity script line 54 under
the same worker/toolchain/host. This is a retained local baseline failure, not
proof of a candidate-specific regression or of a fixed environmental cause.
No limits/assertions are weakened. Hosted qualification remains required.

The release-candidate checker now requires 122 native actors (the original 116
plus six function actors); all sixteen existing candidate-policy/rejection tests
pass locally. Native evidence upload includes the new function report. Further
handler-side authority and pre-completion liveness checks are in the v5 candidate
and need their own execution; v4 evidence is not relabeled as v5 qualification.

Published the initial GL-030 development checkpoint as `a7339e0`; remote main
remains `9f52b27`. DockerPC subsequently closes SSH before key exchange on repeated
bounded attempts, preventing log collection/new local runs at that moment.
Hosted qualification is authorized and independent of this worker outage.

Correct the baseline identity/GC fixture by yielding every 1,000 iterations of
its existing 20,000-iteration collection workload. Preserve every iteration,
all retained-name/native-identity assertions and the required observed GC.
This test is about identity surviving collection and deletion, not non-yielding
throughput. The production 25 ms limits and dedicated execution/sanitizer controls
stay unchanged. Retain the original candidate and exact-main failures above;
this fixture change does not claim a runtime speed improvement.

v5's six function actors pass with handler-side authority coverage, but the
existing GL-029 regression exposes a contract conflict: disconnect cancelled its
already running Function handler used as an independent sibling callback.
Correct transport retirement to detach that serving token while allowing the
live domain's application callback to finish. It cannot reply through a new
session/service. Active-request timeout/caller cancellation and endpoint
retirement still cancel exact serving work; owner/domain retirement remains
authoritative. This preserves the existing assertion instead of weakening it.

Source review also finds reflected submission helpers could reserve bounded but
ownerless response slots. Public Invoke now uses a private C++ submission call
after live-wait capture; remove those internal ClassDB bindings and require their
absence in the native fixture. Public InvokeServer/InvokeClient shapes stay the
same. These corrections need fresh qualification.

The exact-main nonresponse observation reaches 69,994 ms with `Completed=false`;
the fixture's 70,000 ms threshold correctly remains a failed run. Godot timer time
is not the monotonic wall barrier needed here. Replace the timer with a checked
monotonic frame barrier and repeat, retaining the original observation.

The corrected exact-main baseline reproduces nonresponse at **70,006 ms** after
the validated remote handler entered: caller `Completed=false`, both actors
exit zero with the REPRODUCED marker. Baseline extension SHA-256
`5f3799751dbd8e1fcf1ecd4238f2d240c284ba160c9cbe2b5514b06f24160a56`;
native fingerprint remains exact main's `27822f8...`. This is actual nonresponse
evidence beyond the old GC interval, not direct introspection of an erased map.
Receipt/logs: DockerPC `Networking2/baseline-main-trial2`.

At `11e0036`, hosted Windows/Linux core jobs pass, and the candidate workflow's
Linux core ASan/LSan job passes. Native/full-native/profile jobs are still
building at this checkpoint; they cannot qualify later runtime corrections.
The initial `a7339e0` core run passes; its superseded ordinary-native run was
explicitly cancelled to avoid duplicate heavy work, not reported as passing.

Review found the domain-host timeout still accumulated scaled Godot frame delta,
whereas NetworkService used native monotonic time. Use an absolute monotonic
deadline in both owners and add a 20x simulation-time regression; this preserves
the finite wall-time contract during time scaling and reentrant wait creation.
No general scheduler or unrelated WaitForChild timer behavior changes.

## Latest local checkpoint and hosted fixture correction

Runtime `2f08e44` has native fingerprint
`7a4af3b79e002ac005fcc86a1d7de5bc6ff65291b45b280bbe3a521bde02ba9b`.
The [versioned local receipt](evidence/gl030-local-checkpoint-2026-11-03.json)
records the independently checked 590-member raw-log/report archive, exact
baseline and selected Windows MSVC 18 Debug ASan products. The final local replay
passes six Function actors (109 assertions), eight general integration actors,
and the twelve-actor combined Remote group, including all six existing GL-029
actors (461 assertions) and the six Function actors again. No unexpected ASan
report is present. This is 26 selected actor process runs, not the full 122-actor
matrix or complete platform qualification.

The scaled-time test exposed a fixture race: a 0.05-second cancellation timer
could run before GDScript sampled the admitted 64-request count. The ordinary
hosted Linux job reproduces that same failure after all six GL-029 actors pass.
Use an explicit release barrier and pause inbound polling while observing the
exact pending ceiling. Keep the 64-count/one-over and cleanup assertions intact.
Strengthen endpoint lifetime coverage by actually destroying the Client Function,
creating a same-name replacement, verifying fresh ObjectID/no readiness, and
calling the retained old closure. All six actors pass that stronger fixture.

The first cooperative GC fixture edit also needed `%%` inside its formatted
GDScript string; the corrected form is in `2f08e44` and the complete eight-actor
local regression now passes. Earlier formatting/timeout failures remain retained.
One unchanged v7 Remote replay misses the final unreliable sequence barrier;
an unchanged-runtime replay passes all six GL-029 actors. No source cause or
guaranteed unreliable delivery is claimed from that replay.

Hosted core Windows/Linux at `2f08e44` is downloaded and independently verified:
81 distinct cases each. Original core report hashes are
`0bfe6bf4dae3a8b81e55a9df59ed28fb6a787530f544890cebff581c20161c7c`
(Linux) and `ac24b86b279a15d8126f7b860f0bf1144aef9b6f5b4e97c34efbbba989d065dd`
(Windows). Hosted native `41745944549` fails the old count-observation fixture;
its failed artifacts are preserved. Full-native `41746182521` and candidate
`41746187100` are separate pending runs at that revision, not passing evidence
for the corrected fixture. Final hosted qualification must use the new checkpoint.

## Phase 2 preparation while GL-030 hosted gates run

Both latest core artifacts at `eadad8d` verify independently (81 cases each).
Ordinary native `41750229974`, full-native `41750260756`, and candidate
`41750264823` remain pending. The ordinary Linux remote group has passed;
pending later groups and other profiles are not yet qualification.

A private two-process probe reproduces GL-031: the root control arrives and a
runtime child under a matching static parent does not. The versioned
[receipt](evidence/gl031-baseline/evidence.json) and
[fixture](evidence/gl031-baseline/ReplicationBaseline.gd) preserve that baseline.
No phase-2 production behavior is active at this checkpoint.

Reference inspection uses Gargantuan `e682be08df84d776bfa455137728265c6494b5e8`,
`src/network/ReplicationRelevance.cpp` and
`devdocs/CurrentArchitecture/ReplicationFoundation3J.md`. Relevant concepts are
trusted focus, bounded spatial memberships, complete dependency selection,
Desired versus Known, and acceptance-only state changes. GodotLuau retains its
SceneTree/ObjectID hooks, service tick and admitted ENet boundary; Gargantuan's
DataModel, GNS and mutation gateway are not imported.

Latest ordinary Linux native CI completes all 122 actors and its downloaded
summary, 373 log hashes, 82 harness identities, 4,000 unique UUID samples and
admitted host proofs verify. Windows fails an existing Listen observer check
`trusted replacement reaches owner and observer`. The fixture checks 250 ms
after a file barrier, while `_recv_character` is an unreliable presentation
snapshot refreshed every 250 ms. That file cannot prove packet receipt. Earlier
GL-029 qualification also retained this transient observation. No GL-030 source
cause is established by the logs.

Use a finite five-second positive-convergence barrier, retaining the exact
replacement assertion and all negative stale-life checks. Deliberately pause
Listen observer native polling for 350 ms during restoration to exercise delayed
receipt. This changes the fixture, not the carrier, authority, refresh interval
or runtime limit. Exact revision `eadad8d` remains in an isolated read-only
verification worktree while its original full-native/profile artifacts finish;
their outcomes remain separately identified. A corrected-fixture checkpoint
requires fresh qualification.

The Windows full-native run also fails existing positive movement admission and
the animation stale-life comparison, with detection controls passing and no
unexpected sanitizer reports. Linux full-native completes all required checks.
Movement used only three unreliable inputs after an adversarial flood; add a
bounded valid-input resend/actual-admission barrier without changing native
tokens, accepted motion bounds or rejection checks. Animation froze the native
service tick and relied on a file/200-ms delay to assume a replacement birth
snapshot had arrived. Temporarily allow ordinary periodic refresh until the
receiver reports its newer native life, then freeze dispatch before the same
old-life play/stop no-effects comparison. A first ObjectID-only precondition did
not establish this fixture's receive life and is retained as a failed attempt.

Add read-only `GetCharacterReplicaState(Peer)` diagnostics for the existing
native snapshot's epoch/life/sequence/removal. This grants no mutation or client
authority. Record before/after state and the actual received life, and require
that precondition in the strict checker. The earlier corrected replacement
fixture alone passes all 20 local Character actors (146.25 seconds) on unchanged
`7a4af3b...` runtime. The newer animation/movement corrections still need their
own focused and complete qualification.

The stronger native diagnostic exposes a concrete second fixture race:
`AnimationIntegration.RunClient` lets the observer read `client1.newpeer` after
the server's `reconnect` marker, before the reconnecting client has written its
new peer ID. The resulting argument is zero; later waits cannot repair that
captured value. Add the missing file barrier before reading the identity. The
first stronger native-life attempt correctly fails this observer precondition
and reports an empty snapshot for peer zero. Preserve the failure and retain
the exact native-life check; do not hide it with longer unconditional sleeps.

With the peer-read barrier, all ten focused animation actors pass on diagnostic
runtime fingerprint `3ba6543...` (92.187 seconds), including the stronger life
precondition. The same attempt exposes a fixture edit regression: replacing the
existing movement drain with an early positive sample lets the Latency assertion
run before the final controller samples arrive. Restore the existing drain and
retain a finite final-position convergence check. The original final-position
and motion bounds remain required; that failed attempt is not qualification.

The corrected checkpoint passes ten animation, twenty Character and six Function
actors on DockerPC Windows Debug ASan; the
[receipt](evidence/gl030-convergence-checkpoint-2026-11-03.json) records actual
fixture overlays, source/product identities and raw archive SHA-256
`2223893064da009f048cc4ed4d63451a4269fd53d7bcb20966abe3c6f0a899ec`
(877 members). This selected 36-actor evidence does not replace a complete
122-actor platform gate. Function assertions remain 109 across six actors.

At preceding exact revision `eadad8d`, candidate workflow `41750264823` completes
successfully. All four downloaded source profiles independently recheck 81 core
cases and 122 native actors each, all log/product/harness hashes, 4,000 unique
UUIDs each, admitted host ownership/RPC proof, and both 133-member extracted
packages with Debug/Release companion startups. Non-publishing acceptance hash
is `3ce874537ed6f83671a08ccbf16fd1aca3a509d98720df50d98ba789db2dbf97`.
The [versioned verification](evidence/gl030-eadad8d-candidate-verification.json)
retains all product/host/package hashes. Ordinary native Windows and full-native
Windows at that revision remain failed attempts, independently of the passing
candidate workflow. Fresh corrected-checkpoint gates are still required.
