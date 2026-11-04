# Networking Foundation 2 campaign journal

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
