# Networking Foundation 2 campaign journal

## Presentation passes; Windows contention fixture follow-up

At `37a5e4e`, core `42031393024` and ordinary native `42031392980` pass on both
platforms. Full-native sanitizer `42031394386` passes Linux. Both platforms'
presentation groups pass, preserving every grounding/movement/animation check.
Windows fails a different existing DataStore contention assertion, followed by
the strict check's missing incomplete DataStore result. Controls pass and there
are no unexpected sanitizer reports. The failed artifacts remain retained under
`ci-gl039-phase`; this is not a passing full Windows sanitizer run.

The old single-line assertion does not identify whether the returned status or
elapsed time failed. Source shows each operation starts a new helper, so the
0.8–3-second test includes loading the freshly copied ASan executable as well as
the backend's one-second lock wait and helper retirement. The focused fixture
change reads the missing key before publishing the root barrier, warming that
disposable executable image; it does not introduce a persistent worker. The
timed request still creates a new companion and retains the exact error,
0.8–3-second and frame-progress assertions. Failure messages now retain status
and elapsed seconds. Cold helper behavior remains covered by the other cases.
Cold-image attribution remains a hypothesis, not a reproduced native defect.

The worker lease is busy with another campaign, so no additional worker test is
started or lease bypassed. Run fresh full-native sanitizer CI for this fixture
change. Reuse `37a5e4e` ordinary native and `fa0d431` four-profile/package evidence
within their unchanged-production scope instead of rebuilding those matrices
again. The fixture-only commit skips automatic duplicate push jobs; the manual
full sanitizer workflow still requires both complete platform suites and all
existing core/native checks. GL-039 remains open until that result verifies.

## Capacity recovered and 32-peer latency measured — 2026-11-05

The owner authorizes bounded pagefile recovery and MainPC fallback. DockerPC has
no remaining GL-039 process to retire; large allocations belong to unrelated
workloads and remain untouched. Its free commit is 7,291,944,960 bytes despite
17,363,705,856 bytes of free physical RAM. MainPC lacks the existing physical-RAM
headroom. A temporary, non-boot-registered auxiliary pagefile adds 2 GiB through
the existing privileged SSH/Python installation. Free commit becomes
8,492,187,648 bytes; the 7,717,519,360-byte guard remains unchanged. Windows' own
system-managed file changes size too; the receipt reports actual commit rather
than equating allocated disk bytes with recovered commit. No restart, process
termination, shared-cache cleanup or persistent setting change occurs. The
[capacity receipt](evidence/gl039-capacity-recovery.json) records the failed
initial helper call, correction, observed counters and safe rollback after a
normally planned restart. Never delete or shrink an active pagefile.

Core `41964866152`, native `41964866191` and all four candidate profiles/package
gates `41964867366` pass at `fa0d431`; downloaded candidate artifacts verify with
the existing verifier in the
[receipt](evidence/gl039-fa0d431-candidate-verification.json). Production inputs
remain native fingerprint `6698ad26...`. Both full-native sanitizer jobs fail
only the new walking-ground sample in listen presentation; no unexpected
sanitizer report is present. Remote poses remain near the floor and remote walk
cycles pass, unlike the prior GL-040 airborne-host failure.

Lease generation 5 covers the existing sealed Release recipe and subsequent
independent candidate-only large-world run. All four candidate 32-peer trials
pass with zero replication failures. Worst-client final convergence is
299/226 us at 64 objects and 75,159/699,938 us at 512 objects, versus the retained
6.58–6.96-second old opt-in measurements. Small-world server frame p95 is
14.813/15.802 ms versus paired legacy 17.954/20.464 ms. Large-world frame p95 is
15.557/16.050 ms; its legacy baseline fails warmup before candidate launch, so
the unchanged harness runs the candidate independently. That failed comparison
is retained, not relabeled passing or retried without attribution. No fresh
large-world paired frame-speedup claim follows. Ordinary and impaired 16-peer
pairs pass, including healthy-peer progress. See the
[Release receipt](evidence/gl039-release41-qualification.json): 14 passes and one
retained legacy failure, no candidate failure. Raw archive has 1,899 members,
8,395,841 bytes and SHA-256 `246cfd59e0f80cb3f5d4355b3746f3c5a52f35ba947bf90cb909dc14ca207c4e`.
Owned process census is zero; all coordinator Jobs retire and lease 5 releases.

The focused fixture correction observes the completed physics step before the
ground check, retaining its assertion and before/after pose/velocity evidence.
Godot documents `physics_frame` before node physics callbacks; the prior
`Ticks(90)` returns at that boundary. Three focused Windows ASan listen actors
pass using the existing matching host/products; this reuses unchanged Character
physics and does not qualify a new production binary. Fresh hosted sanitizer
verification remains required. The phase attribution is source-supported, not
an independently reproduced before-false/after-true transition in this local
run. No production physics, assertion, resource bound or native source changes.
GL-039 remains open pending the final sanitizer result; GL-040 stays separate.

## Current GL-039 checkpoint — fa0d431

The separate-lane presentation fixture is committed and pushed as `fa0d431`.
Core workflow `41964866152` passes; ordinary native `41964866191` and full-native
sanitizer `41964870001` are running. Nonpublishing candidate `41964867366` is
running after cancellation of the superseded `5ea6345` run. Its failed Windows
Release evidence is retained in the
[GL-040 receipt](evidence/gl040-presentation-failure.json). Initial policy and
Linux core sanitizer gates pass; four source profiles remain in progress, not
accepted. A frozen `fa0d431` verification worktree and
downloaded core artifacts preserve the source boundary for independent review.

A read-only worker resource probe at 04:02 UTC on 2026-11-05 reports
7,336,517,632 bytes of free commit, still below 7,717,519,360 bytes. No 32-peer
actor launches, guard changes, unrelated workload stops or machine-setting
changes occur. The previously released worker lease remains released.
The 16 release-candidate admission tests and `git diff --check` pass locally.
Main remains `9f52b27`; dependency pins, disabled publication and fail-closed
updater remain unchanged. GL-039 cannot close without actual 32-peer results.

## Presentation evidence revises the initial fixture hypothesis

At `5ea6345`, all core/native/full-native sanitizer workflows pass but Windows
Release presentation fails again. Saved JSON now shows the host rising to about
161.9 units while other participants remain near the floor; the initial
ground-before-walking change was insufficient. GL-040 retains this observed
coincident-spawn interaction without asserting an unproven physics cause.
The next small fixture change assigns parallel lanes through the already
qualified trusted-server CharacterAdded/Position API before peers join, rather
than changing production collision/platform behavior. Every existing ground,
movement, identity and animation assertion remains required. GL-039 and GL-040
remain open until their respective acceptance facts are established.

## GL-039 diagnostic run — 32-peer memory preflight blocks launch

Atomic worker-heavy lease generation 4 is acquired at 03:18:52 UTC, renewed,
then released at 03:23:13 after checked retirement. The first unsealed recipe
references a missing preinstalled helper; no benchmark starts in that root.
Fresh sealed installation `release40` uses the same diagnostic Release adapter
from the failed `cb4c967` profile, explicitly not accepted candidate proof. The
runtime fingerprint remains `6698ad26...`; the earlier full runtime matrix
verifies that source independently. Neither a failed candidate nor this
diagnostic result is relabeled full qualification.

Both 32-peer world sizes are blocked before launch: free commit is about
7.21–7.22 GB decimal, below the unchanged 7,717,519,360-byte requirement. No
resource guard is weakened. The separate 16-peer ordinary and impaired-peer
pairs pass all eight configurations, with zero replication failures and retained
frame/RTT/convergence metrics. These do not qualify 32 peers. See the
[diagnostic receipt](evidence/gl039-diagnostic-release40.json).

All executed outer/nested Jobs are checked reaped, with no timeout/output errors.
The final census finds zero owned processes/listeners. Raw archive integrity
passes: 869 members, 3,162,648 bytes, SHA-256
`b85ec41022ad672a52d3226965a77072668169327f49c9761733c538aaf3dea1`.
No worker workload remains active. A text clarification asks the user to free
about 1 GiB of committed worker memory; unrelated workloads and machine settings
are preserved. Fresh presentation-corrected CI continues independently. GL-039
remains open pending actual 32-peer execution and full current acceptance.

## Retained Windows Release presentation precondition failure

Candidate workflow `41953316449` passes three source profiles but Windows Release
fails `listen-custom` at `walking observation starts from grounded owner`, with
a remote animation comparison also failing. Keep its captured `presentation.log`
and actor logs. This does not establish a GL-039 source cause: the fixture begins
scripted walking before establishing startup ground contact. The focused fixture
correction establishes real grounding first, starts walking, and retains the
movement/animation checks plus a grounding assertion after the walking warmup.
No artificial pose reset, physics disable, tolerance increase or timeout increase
is used. Retain final failed ground samples and presentation evidence JSON in
future failed artifacts. Fresh qualification is required; no failed profile is
relabeled passing.

## GL-039 final runtime matrix verified — cb4c967

Core `41953311858`, ordinary native `41953311887` and full-native sanitizer
`41953312982` pass on Windows/Linux. Frozen-source independent verification
establishes 85 core cases, 131 native actors per profile, 23 Windows/24 Linux
sanitizer checks and 1,161 native plus three core instrumented units. Required
logs/harnesses/products/host identities verify; two ephemeral GL-003 mailbox
hashes are explicitly retained as such in the
[receipt](evidence/gl039-cb4c967-runtime-verification.json). The 7,500-byte
sixteen-barrier fixture passes with exact ordering and payload integrity.

The four-profile/package workflow remains running. Its qualified Release
products will supply the matched old/new 32-peer test. No older runtime receipt
or prepared-but-unexecuted recipe is substituted for final latency evidence.
GL-039 remains open. The worker lease was busy during local preparation;
historical availability and a fresh Free status do not confer admission.

## GL-039 burst byte-bound review

Before the latency run, source review identifies a byte-quantum edge: eight
near-maximum frames could exceed the former one-frame per-visit traffic quantum.
Cap the burst at the existing 60-KiB frame maximum as well as eight frames and
the existing cooperative time/in-flight checks. This is a source-verified bound
correction, not a reproduced receiver failure. No queue/native/timeout limit or
wire format changes. Earlier `01ec4eb` qualification remains attributed to that
source; fresh proof is required for this additional minimal guard.
The actual native fixture now reparents a 7,500-byte StringValue sixteen times
and verifies its exact final payload and every ordered transition. This exercises
large-frame burst splitting without adding an implementation-mirroring unit test.

## GL-039 resumed CI review — 01ec4eb

Core `41930591599`, ordinary native `41930591984` and candidate `41930600188`
pass. Independent frozen-source candidate verification checks all four
85-core/131-actor profiles, logs/products/harnesses, admitted host proof and both
133-member extracted packages with two startup actors each. The
[receipt](evidence/gl039-01ec4eb-candidate-verification.json) retains acceptance
hash `db2e49362134a58235300cec49b298442fb93f55e3095cf09bb6b01db8dccb77`.
Full-native sanitizer `41930595264` passes Windows but Linux times out after
five minutes installing compiler prerequisites, before any source build/test.
Retain that infrastructure failure; rerun only its failed job without runtime,
assertion or workflow changes. Its result is pending.

The exact qualified Release adapter is staged locally for a matched comparison
of old `436850a` and new `01ec4eb`, with the same admitted compiler/host. Fixed
profiles cover repeated 32-peer 64/512-object worlds and 16-peer ordinary and
impaired fairness checks. GL-039 stays open until actual latency evidence and
the remaining sanitizer proof establish acceptance. Worker admission now uses
the shared host-local lease mechanism; no historical release grants a new lease.

## GL-039 interrupted-turn collection — 01ec4eb

Minimal runtime source `01ec4eb` preserves first-frame progress within the
cooperative submission budget; native fingerprint is `8a3c5036...`. The existing
two-job Windows Debug ASan incremental build passes, DLL SHA-256
`96daa40e9dd7bb9cafcfba8428353603ced1297b89bf47fd87847139cc435dd5`.
The first operator wrapper incorrectly called an unsupported `communicate`
method and closed its owned Job; the corrected bounded wrapper and its captured
logs remain alongside that preparation failure.

Pinned coordinator window `6a71ee3f-9ef0-4a2c-a37a-6a699cc778fb` passes both
profiles: seven relevance actors, twenty Character actors, eight legacy actors
and six Function actors. No unexpected ASan report occurs. The stronger fixture
retains all 32 signals from sixteen same-turn barriers in exact order. Captured
diagnostics include invalid-target messages during relevance peer retirement
and existing Character teardown/intentional access-rejection diagnostics; this
is not a claim of empty stderr. Both outer Jobs and the build Job are checked
reaped, without timeouts or output-reader errors.

The chat interruption delayed collection/release notification. Following the
coordinator's expiry notice, only bounded collection and retirement checks run.
The 23:16:32 UTC task-root census finds zero live owned processes; no owned PID
remains to retain a listener. All SSH/SCP commands finish before checked release
is sent. Raw archive `gl039-local-checkpoint1.zip` contains 933 members and
2,746,941 bytes; ZIP integrity passes and SHA-256 is
`ca676b4cb1fa45933c2c5ea2c6b0efb9991fa0701a3363efe8720280e84e9b88`.
It preserves actual logs, identities, executed helpers and coordinator journals.

GL-039 stays open: these focused correctness passes do not establish the
32-peer latency improvement. Fresh hosted qualification and repeated matched
Release latency/frame/fairness measurements remain required. No worker workload
is active or queued; a later run requires a separate checked handoff. The branch
remains unmerged, with release publication and updater admission disabled.

## GL-039 minimal burst candidate — qualification pending

Resume from clean local/remote `b4b6ea3`; main remains `9f52b27`. Retained
Release evidence reproduces 6.58–6.96-second 32-peer convergence. Source inspection
finds one queued frame submitted per peer visit and one received frame applied
per client tick. The candidate changes only those loops to bounded FIFO bursts
of eight, preserving the existing server eight-peer/four-ms budget, native
preflight for every send, 64-frame ACK window, queue caps and ten-second failures.
The client burst has its own cooperative four-ms quantum and revalidates native
lifetime after each application. No wire format, scheduler or ownership refactor
is introduced. The actual native fixture now requires all 32 transition signals
from sixteen same-turn reparent barriers in exact order. Nothing is qualified
by this source trace; fresh native/sanitizer/platform and paired latency evidence
must establish the result before GL-039 closes.

## GL-034/037 qualification complete within recorded profiles — 436850a

GL-037 remains closed by its corrected fixture/actual native matrix. GL-034 now
closes on this unmerged campaign: the bounded catalog source passes all four
hosted workflows and current repeated Release 1/16/32-peer small/large workloads.
The [Release receipt](evidence/networking2-436850a-release-qualification.json)
independently checks 16 passing candidate configurations, twelve passing baseline
configurations and three retained baseline large-world warmup failures. There
are 392 actor runs in successful configurations, zero successful-case stderr
files, zero candidate replication failures and no resource-guard/report failures.
No comparison is invented where the baseline failed.

Separate real ENet loss/reordering pairs pass at one peer/512 objects and
16 peers/64 objects, with one impaired peer alongside 15 healthy peers in the
latter. The [measurement record](networking2-benchmarks.md#release-qualification--436850a)
preserves frame, CPU, wire, convergence and memory-observation limits. GL-039
records the measured 6.58–6.96-second structural convergence at 32 peers; it is
not hidden by the frame-cost closure. Broader long-duration/graphical/allocation
coverage remains distinct from this targeted qualification.

The worker reservation starts 11:08:48 UTC with a hard 11:28:48 bound. Current
Release products are verified/staged/sealed before execution. Window
`2b6ef821-205c-4989-9f68-f154b82cb1de` retains failed baseline cases and retires
all Jobs. Fresh sealed follow-up
`b7cdd6fc-5325-4bec-9de0-c0525c98a591` passes the supported-world fairness pair
and skips its unnecessary candidate-only repeat. Final census at 11:24:10 finds
zero owned processes/listeners; archive/transfers exit before checked release at
11:26:11. Raw archive SHA-256 is
`886d2c136c1d2998a7a4adc8684c80879a99a75bfba8854b26e860bc2018dec3`,
19,469 members with ZIP integrity verified. Earlier GL-038 ASan failure and the
subsequent current v31 proof are retained in the same archive.

This final checkpoint changes documentation/evidence only; qualified runtime
remains `436850a` / native fingerprint `770c9ff5...`. Main, dependency pins,
admitted host patch and release/updater controls remain unchanged. The campaign
stays unmerged. No further worker job or broad refactor is queued.

## Complete current CI and package verification — 436850a

The [candidate workflow](https://github.com/gmoddev/GodotLuau/actions/runs/41807864382)
passes all gates. Independent frozen-source checks establish four Windows/Linux
Debug/Release profiles with 85 core cases and 131 native actors each, required
log/product/harness hashes, actual ownership/RPC admission proof, 4,000 unique
UUID samples per profile, Linux core ASan/LSan, and both 133-member packages with
two extracted startup actors each. Nonpublishing acceptance SHA-256 is
`48833621d1db5af55e2e7ba49c94840f1ff805c507b238519b01e106e3237af2`;
the [receipt](evidence/networking2-436850a-candidate-verification.json) retains the
exact profile/host/extension/companion/package hashes. Together with the current
runtime receipt below, all four hosted workflows are independently qualified.

The current Windows Release qualification adapter matches the existing admitted
Release host's compiler hash. Its immutable benchmark input archive SHA-256 is
`266901c2e85d49a52eed765f46015feb66457112b1bfd0a92ca05af3848ee6bc`.
The larger-peer worker window is queued after other chats' checked handoffs;
no worker execution or transfer has started. GL-034 stays open for those actual
performance/admission trials. Releases/updater remain disabled and main unchanged.

## Release qualification preparation — 2026-11-04

The current `436850a` candidate's Linux Debug and Release profiles pass, as does
its Linux core sanitizer; Windows Debug/Release remain running. Core, ordinary
native and full-native sanitizer matrices already independently verify below.
Documentation checkpoint `61b9ee5` preserves that evidence without changing the
runtime or triggering new native builds. Remote main remains `9f52b27`.

Prepare a separate local fixed-profile coordinator installation for the exact
current CI Release adapter, baseline `9f52b27`, and the existing admitted Release
host/compiler. Stage only after independent artifact verification. Six profiles
cover repeated paired 1/16/32-peer, 64/512-object workloads; separate profiles can
retain a current candidate result when an older baseline fails. The finite outer
window is 1,100 seconds with checked task-owned Job retirement. No worker recipe
has executed during this preparation or other chats' reserved timing windows.

Two separate impaired-link profiles use one task-owned UDP proxy with a fixed
every-17th-datagram loss pattern and 40-ms delay plus 0/35/70-ms jitter. Other
clients remain direct, and production assertions/admission/settings are unchanged.
A bounded socket-only preparation check passes with 86 echoes, ten intentional
drops, 114 reordered forwards, no overflow and checked shutdown. This is helper
evidence, not real ENet qualification. Current larger-peer, impaired-link and
package acceptance remain pending; no performance or scalability closure follows
from preparation.

## Current native matrix verified — 436850a

All current [core](https://github.com/gmoddev/GodotLuau/actions/runs/41807722427),
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41807722519), and
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41807859581)
workflows pass Windows/Linux. Independent frozen-source verification establishes
85 core cases and 131 native actors per profile, 23 Windows/24 Linux sanitizer
checks, and 1,161 native plus three core instrumented units per platform.
Required captured logs and source/harness/product/host/compiler identities verify.
The [receipt](evidence/networking2-436850a-runtime-verification.json) separately
records two absent ephemeral GL-003 mailbox hashes. No unexpected sanitizer
finding occurs. GL-038 closes at this exact unmerged source; GL-037 remains closed.

The [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41807864382)
four-profile/package matrix still runs. GL-034's one-peer frame correction is
measured, but larger-peer Release acceptance remains pending. The branch stays
unmerged with distribution disabled. No further runtime changes are justified
by the established current acceptance facts unless qualification exposes a new
failure.

## v31 worker qualification — 436850a

The explicitly released five-minute worker window completes successfully: two-job
build in 25.25 s, all seven strengthened relevance actors, then all eight paired
one-peer 64/512-object ASan configurations. Native fingerprint is `770c9ff5...`;
DLL SHA-256 is `47cf79e9faa6fd7eb90479ec1a91dee2ea4932ccacc02533297ad4aee792ea6d`.
Both fresh coordinator profiles exit zero without timeout/output errors; outer
owned Jobs are checked empty and window
`4421afe7-792d-4ed6-ac9a-584e8a73e0f6` retires before release to Studio at 09:46 UTC.
No additional worker job is queued.

At 512 objects, fresh candidate frame p95 is 9.61/9.98 ms versus main 9.34/9.45 ms,
with no replication failure. Maximum sweep turn is 2.706/2.813 ms; final client
structural convergence is 711.104/84.991 ms. Preserve the convergence tradeoff
and changed worker background context in the
[measurement record](networking2-benchmarks.md#bounded-sweep-measurements--436850a)
and [receipt](evidence/networking2-436850a-asandebug-benchmark.json). This resolves
the reproduced one-peer frame-cost symptom, but GL-034 remains open pending
current complete matrix and larger-world admission/Release qualification.

## Bounded catalog first execution — GL-038

Both `712ea47` full-native sanitizer jobs now pass and independently verify:
23 Windows/24 Linux checks, 85 core cases and 131 native actors per platform,
1,161 native plus three core instrumented units. All required captured logs and
source/harness/product/host identities verify; the two absent ephemeral GL-003
mailbox hashes are recorded in the
[receipt](evidence/networking2-712ea47-sanitizer-verification.json). No unexpected
report occurs in this corrected matrix. Ordinary Linux's physical-owner failure
remains separate evidence, so the campaign is not qualified by this pass alone.

The subsequent source-control correction is `436850aca89e87e6ee8bc2e520740318ba0be27c`,
snapshot v31 / native fingerprint `770c9ff5...`. Fresh
[core](https://github.com/gmoddev/GodotLuau/actions/runs/41807722427),
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41807722519),
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41807859581)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41807864382)
workflows are running/queued. The next worker reservation is explicitly retained
after Studio Recovery04 and Steward's bounded tail; v31 preparation is staged,
with no uncoordinated execution. Other chats report retiring stale SSH child
processes while preserving service/configuration and live sessions; new paired
measurements must record their own fresh resource context rather than treating
old absolute timings as a controlled before/after across that environment change.

At `712ea47`, Linux ordinary native qualification passes the expired-value and
new service-replacement assertions, but fails the authorized client-physics
positive case. Its complete Linux full-native sanitizer job subsequently reports
success; independent artifact verification is pending. Preserve both results:
the ordinary failure is not erased by the sanitizer pass.

Source review identifies an ordering/acknowledgment discrepancy: runtime
`net_set_owner` sends an immediate legacy RPC while cached structural snapshots
also carry ownership, and queue admission labels a snapshot using the live
control map. A snapshot captured before a later control write can therefore be
tagged with the newer revision. Capture the control version with the source
record and route opted-in runtime ownership through the ordered snapshot.
Keep native immediate revocation and the existing ACK/readiness check. The
fixture now waits for the exact requested owner, rather than any nonzero owner,
and uses the established functional ENet unthrottled profile, retaining all
wrong-generation/owner assertions. Production transport defaults stay unchanged.
The precise cause of the observed ordinary physics failure is not independently
attributed yet; the source discrepancy and stricter precondition are verified.

The [failure receipt](evidence/networking2-6b6ee8b-objectvalue-failure.json)
retains source/product/fixture identities, the actual report hash and checked
coordinator disposition. The focused getter correction is published as
`712ea478a6d503f85655cc20219de21c84a7e4c2`; its
[core](https://github.com/gmoddev/GodotLuau/actions/runs/41802226872) passes and
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41802226887),
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41802340597)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41802343918)
workflows are running. The concurrency queue supersedes the unstarted `6b6ee8b`
candidate with this corrected source; the failed source's ordinary/sanitizer
runs and local failure remain retained.

The earlier `bd18580` candidate now completes and independently verifies all
four 85-core/131-actor profiles, both 133-member extracted packages and startup
actors, with acceptance hash
`a271d89c8f99dc1f503dc3033d4c24e38538097fa61cf4762e1b55526a8000cf`
([receipt](evidence/networking2-bd18580-candidate-verification.json)). All four
workflows are qualified at that exact earlier source. This does not qualify the
new catalog/getter changes or close GL-034/038.

Candidate `6b6ee8b93caa88898b80875fc5929c5e6899eb2c` compiles on the existing
worker MSVC Debug ASan toolchain in 35.656 seconds with two jobs; DLL SHA-256 is
`8b9373158642305af2457296f69556adc4a550e13a51bacb23bff95e2c474751`.
Its first strengthened relevance execution fails after the forced unfinished
sweep mutation and produces an actual ASan heap-use-after-free report in the
ObjectValue target conversion. Preserve report SHA-256
`8e56bc427561db8776b75cbfb319858b869cf6d7244168ec290e449b299024e5`.
GL-038 records the stack/source attribution. The shared value getter now validates
the engine Variant before godot-cpp pointer conversion, and Luau value pushing
uses that getter. Native/Luau nil assertions are added; they are not yet run.

The new coordinator profile exits 1 without timeout/output error and the outer
owned Job is checked empty. No benchmark profile starts. The worker is released
early to the next chat, and there is no uncoordinated retry. Fresh source
[core CI](https://github.com/gmoddev/GodotLuau/actions/runs/41800928567) passes;
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41800928440),
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41801098115)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41801102051)
qualification at the failing source remain running/queued and cannot qualify
the subsequent lifetime correction. GL-034/038 remain open. The earlier GL-037
closure applies to its independently verified `bd18580` checkpoint.

## Verified resumed checkpoint — bd18580

The narrow patch is published as `bd18580d65d29a60fa90a2fc53f2fccfec0febea`.
Fresh hosted [core](https://github.com/gmoddev/GodotLuau/actions/runs/41789098795),
[native](https://github.com/gmoddev/GodotLuau/actions/runs/41789098680), and
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41789196521)
workflows all pass Windows/Linux. Independent frozen-revision verification checks
85 core cases and 131 native actors per profile; full-native controls require
23 Windows/24 Linux checks, with 1,161 instrumented native translation units and
three core units per platform. Required logs, actual harnesses, host/compiler,
products and instrumentation hashes verify; two missing ephemeral GL-003
mailboxes are listed explicitly. GL-037 and GL-035 close on this unmerged branch
with the [runtime receipt](evidence/networking2-bd18580-runtime-verification.json).

The earlier `cbd91d0` [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41781834809)
also completes: all four 85-core/131-actor profiles, Linux core sanitizer, both
extracted 133-member packages and startup processes verify independently
([receipt](evidence/networking2-cbd91d0-candidate-verification.json)). The newer
`6ae1b9` candidate completes as well, but its separate receipt is pending.
The exact `bd18580` [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41789199528)
is now running; it is not yet accepted.

All eight new paired ASan benchmark configurations pass, but 512-object server
frame p95 is still 98–101 ms versus baseline 14–16 ms, with full catalog refresh
dominant. See the [measurements](networking2-benchmarks.md#focused-refresh-correction--bd18580).
GL-034 remains open. Rechecking the original campaign attachment confirms explicit
bounded-refactor authority; the approval question was unnecessary. A bounded
catalog candidate is now implemented locally and awaits compilation/execution.
It reuses the private cache/index across 64-item/two-ms cooperative sweep turns,
drains accepted immutable frames while withholding new incomplete selection, and
refreshes only a published barrier's bounded dependency closure. The expanded
production relevance fixture covers mutation/reference-target destruction after
the sweep cursor passes, same-turn reparent ordering, and server service
replacement with unfinished work. These changes are not yet qualified.

Following the user's cross-chat worker coordination, prepare a project-local
adapter pinned to coordinator `cf1628de...`, three fixed numeric profiles, hashed
inputs, fresh UUIDs, loopback bootstrap, bounded output/deadlines, and checked
owned Job cleanup. Its static schema preparation passes; no endpoint or recipe
ran during preparation. After the coordinated release, both fresh profiles pass
(seven relevance and 34 Character/legacy/Function actors), with no timeout or
output errors and checked empty owned Jobs. Window
`39a6360a-0dda-4070-b681-bb93569a57ba` retires successfully; the worker is released
to Steward, with Studio queued afterward. The new catalog candidate has not run.
The installed input lock seals 176 files; four static schema/denial tests pass.
After Studio's checked release, a second five-minute window starts at 08:36 UTC.
Final review produces snapshot `v29`, native fingerprint
`34e4ff3d1e4d6bfe97ed01bdc16f1e1da47c12030591c67a25fa40f472f15d97`;
its source archive SHA-256 is
`29f75ce7f93722da5f72cda0a90b53e22cac3174244a72a200aa7476ce806774`.
Intermediate v27/v28 snapshots were not executed. The candidate also verifies
live source identity/visibility before new frame admission and catches barrier
allocation failure. Unchanged dependency traversal stops only at prerequisites
already accepted by every affected view, avoiding an accidental new ancestry
limit or treating an unfinished source record as accepted proof. The build and
new fixture/measurement runs must establish the result.
Intermittent SSH pre-authentication failures are retained, with bounded retries;
no machine settings, services, tooling, coordinator wire format or other
repository files change. Main, release publication and updater admission remain
unchanged and disabled.

Raw archive 9 retains 14,806 members / 50,931,527 bytes, SHA-256
`4402b57d182ea7fb30bfc2ce8db918d60ebe286fe1733542c9d496c47467e69a`.
It includes the 41 focused v26 actors, eight paired ASan configurations and
coordinator preparation/inputs. The later coordinator execution needs its next
archive. Actual Movement ascent is 5.0999998 units before the strengthened
post-sync rejection probe; required actor logs pass.

## Resumed qualification — 2026-11-04

At resume, `6ae1b9` core CI passes; native/full-native sanitizer qualification
is running and its candidate is queued behind `cbd91d0`. The latter candidate
has passed Linux Debug/Release and Windows Debug; Windows Release is running.
These partial results are not complete acceptance.

Retained Linux legacy stderr identifies `RemoteFunction not ready`: the fixture
waited only for Event publication before invoking the separately published
Function. Require both identities with an explicit wall-clock deadline. Character
functional profiles previously disabled ENet unreliable throttling only in 2D;
apply the same carrier profile in 3D, retaining the impaired latency proxy. Retry
the final positive movement sample until the observer comparison completes.
The airborne negative test must first approach the ascent ceiling, then request
more than its remaining headroom; the previous 0.2-unit proposal could legally
fit below that ceiling. Keep the exact no-movement comparison and strengthen
the measured precondition. These fixture corrections need fresh execution.

GL-034 source inspection finds three narrow costs: unpublished reparent edits
unnecessarily rebuild the full catalog, refresh cadence starts before a costly
refresh, and that refresh consumes the peer submission budget. Skip rebuilding
only when no accepted peer view contains the identity, measure the next refresh
interval from completion, and start the unchanged 4-ms/eight-peer submission
budget after catalog maintenance. Published reparent barriers, admission bounds
and native authority remain intact. Measurements and full qualification follow;
GL-034/037 stay open until their acceptance evidence exists.

The first worker run of this patch passes 41 Windows Debug ASan actors: 20
Character (143.375 s), eight legacy regression (57.937 s), seven relevance
(28.765 s) and six Functions (18.797 s), with no unexpected ASan report. Native
fingerprint is `554af399b8ea76a9934c9d3b7d1bc3d398b9be3099f103f6ff2bb81226d8a728`;
DLL SHA-256 is `851e48e7b0566e0b0a0c60d1bdfa5f3de1cd6bfaf9bfdd65b30643b1a6fadc90`.
Source snapshot `v26` SHA-256 is
`311557ff04bb0ddc89d7a1969eaab32e59669c448759f32428f0e4132d183859`.
Actual harness hashes and per-actor logs are retained in the worker's unique
`focused-v26-first` output. Paired 64/512-object ASan measurements are running.
This focused result is not a substitute for hosted Windows/Linux qualification.

## Campaign checkpoint — 2026-11-04

Final evidence follow-up: Windows full-native ASan at `cbd91d0` completes all
23 checks, 85 core cases and 131 native actors. Independent verification checks
636 files, 383 captured native logs, source/harness/product identities and
1,161 instrumented native translation units plus three core units. One ephemeral
GL-003 mailbox is absent, with its expected hash recorded. The
[Windows receipt](evidence/networking2-cbd91d0-windows-sanitizer-verification.json)
does not erase the Linux failure or establish complete cross-platform acceptance.

Fixture/evidence checkpoint `6ae1b9784e881c2c448f20b86ee19df425e41ac0`
preserves the same native fingerprint and passes fresh
[core CI](https://github.com/gmoddev/GodotLuau/actions/runs/41785670768).
Fresh [native](https://github.com/gmoddev/GodotLuau/actions/runs/41785670839),
[full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41785760383)
and [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41785763061)
qualification remain running/queued. Final documentation validation found the
older Phase 1 receipt contained a truncated tool rendering. Regenerate its
compact valid JSON directly from the original hashed archive, retaining all eight
measurements, six exhaustion reports and nonempty stderr; measurements do not
change. All versioned JSON and local documentation links are checked afterward.

| Phase | Classification | Established scope |
| --- | --- | --- |
| 1 — GL-030 | QUALIFIED | Exact `2296c96` four-workflow qualification; finite terminal outcomes and real ENet lifecycle/adversarial checks |
| 2 — Relevance | PARTIALLY QUALIFIED | Default-disabled anchored-leaf slice; cross-platform Debug gates and scoped native evidence; broader lifecycle and current complete matrix outstanding |
| 3 — Structural admission | PARTIALLY QUALIFIED | Bounded batching/coalescing, dependency closure, exact accepted state, WouldBlock/healthy-peer and cancellation checks; larger mixed-load admission remains limited |
| 4 — Scalability | PARTIALLY QUALIFIED | Repeated 1/16/32-peer small-world Release comparisons and isolated large-world attempts; large-world failures, loss/fairness/memory-rate gaps remain |

Runtime checkpoint `cbd91d08c4384348b4b29cf91dc461fff109e120`, native fingerprint
`c702c86c...`, passes [core](https://github.com/gmoddev/GodotLuau/actions/runs/41781831570)
(85 cases each) and [ordinary native](https://github.com/gmoddev/GodotLuau/actions/runs/41781831679)
(131 actors each) on Windows/Linux Debug. Independent frozen-source verification
checks required logs/harness/product hashes, host proofs, the new root guard and
4,000 UUIDs per platform in the [receipt](evidence/networking2-cbd91d0-ordinary-verification.json).
Its [candidate](https://github.com/gmoddev/GodotLuau/actions/runs/41781834809)
remains in progress. Its [full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/41781831880)
Linux profile fails legacy Dedicated barriers; Windows was still running at this
checkpoint. Do not equate ordinary-native success with complete qualification.
GL-037 records this and the preceding failed matrix, without suppressing checks.

The [local receipt](evidence/networking2-scopeguard-checkpoint.json) records 43
selected native actors at this source, six repeated Function actors after the
verified JSON publication-race fix, and the corrected two-product Debug ASan
benchmark smoke. No unexpected ASan report occurs in these selected runs.
Atomic Function fixture hash is `4ba5d63b...`. The temporary-file publication
change preserves every adversarial assertion and avoids the actual empty-JSON
reader failure. Character/legacy follow-up attribution remains open.

The original relevance checkpoint additionally completes candidate workflow
`41774926042`: all four 85-core/130-actor profiles and both extracted packages
verify independently, with acceptance hash
`a33bfc47e9dcec5fc0e170427fe63f079ee5f32de615e254a621670c42bb1f19`
([receipt](evidence/networking2-9884bf7-candidate-verification.json)). This is
historical `9884bf7`, not current-source acceptance. The queued `0428413`
candidate was superseded by the newer request and cancelled without profiles.

The [Release measurements](networking2-benchmarks.md#release-follow-up) preserve
18 measured passing configurations, two passing smoke configurations, one
failed setup smoke and three large-world failures. They use immutable main and
`532650f` products; the newer native correction is not silently substituted.
GL-036 fixes Release-elided benchmark setup/checks. A local compiler lookup finds
a different executable hash from the CI toolchain; no compiler installation,
mixed-toolchain comparison or fabricated current Release result is performed.

Raw archive 8 contains 13,508 members / 46,843,412 bytes, SHA-256
`f30e914a718451c4202563d62478724817562eff8c5533dee935dd4c61db1d3f`.
It retains baseline root removal, corrected actor logs, failed and successful
benchmarks, exact fixtures/helpers, worker host admission and product identities.

**Integration recommendation:** retain the experimental opt-in branch unmerged.
Finish GL-037 attribution/current complete qualification, GL-034 larger-world
cost/admission work, server service replacement and impaired-link/fairness,
reconnect-storm, allocation/retained-memory and graphical evidence before wider
adoption. Main stays `9f52b27`; all commits are retained, dependency/host patches
are unchanged, releases and updater distribution remain disabled.

## Empty-catalog authority follow-up — GL-035

A separate actual listen-host LocalScript probe reproduces removal of the shared
scene through `game:Destroy()` before any source records or Character authority
exist. Snapshot `v22` exits with the two required preservation/completion checks
failed and no ASan report. Original fixture hash is `34fb0067...`; baseline
stdout hash is `5f298184...`. Source trace shows registered-object ancestors are
protected, while scope roots themselves were checked only by exact identity.
Extend that same native boundary to their live ancestors for structural writes.
Promote the reproduction to the required native suite, retaining the empty
precondition and positive callback-completion assertion; the matrix now requires
131 actors. Snapshot `v23`, fingerprint
`c702c86c162bc4c9f655052fbcefb4f99a5460c1a7ea22d87724022bbe065c85`,
is under qualification. Sixteen candidate-policy tests pass with the stricter
131-actor requirement. No main or distribution activation is performed.

The corrected `v23` passes all seven relevance actors, including the promoted
empty-root test, in 28.97 s, and six Function actors in 18.69 s, without an
unexpected ASan report. DLL SHA-256 is
`f9f171dbc3805c28fb1ae9b07c2d1eac5108089aca50a1ba5af07159f31e3008`.
Twelve retention-policy tests also pass. Character/animation and fresh complete
platform gates remain required; GL-035 is not closed from these selected checks.

The [refresh checkpoint](evidence/networking2-refresh-checkpoint.json) preserves
44 selected final-refresh actors and four supplemental incompatible-mode actors,
all passing. Both mismatch directions terminate without materializing a replica.
They do not replace complete cross-platform qualification. Raw archive 7 has
10,066 members / 31,288,516 bytes, SHA-256
`4ddd0da2763babde443b09786b21cca814370658506cb47ea8acd4b81dc2a7b6`.

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
