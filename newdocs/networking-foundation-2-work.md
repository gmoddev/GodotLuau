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
| GL-030 | IN PROGRESS; not qualified | Source inspection above |
| Relevance | NOT STARTED | Pending GL-030 milestone |
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
