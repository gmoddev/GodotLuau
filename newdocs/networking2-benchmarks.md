# Networking Foundation 2 measurements

These experiments do not establish 64-player support or a general speedup.
Runtime/source qualification and performance evidence are separate gates.

## Release qualification — 436850a

The [current receipt](evidence/networking2-436850a-release-qualification.json)
compares exact main `9f52b27` with native fingerprint `770c9ff5...`, using the
independently qualified current Windows Release adapter and the same admitted
Release host/compiler. Each measured configuration uses 16 warmups, 64 samples
and two interleaved trials. Sixteen candidate configurations and twelve baseline
configurations pass: 392 successful actor process runs. Three baseline warmup
failures remain failures. Successful cases have zero stderr files, report files,
candidate replication failures and resource-guard aborts.

| Peers / objects | Main server frame p95, trials 0/1 | Candidate server frame p95, trials 0/1 | Candidate maximum final convergence, trials 0/1 |
| --- | --- | --- | --- |
| 1 / 64 | 8.487 / 8.444 ms | 8.471 / 8.455 ms | 0.233 / 0.101 ms |
| 1 / 512 | 8.444 / 8.450 ms | 8.502 / 8.441 ms | 683.273 / 691.569 ms |
| 16 / 64 | 9.116 / 8.834 ms | 8.757 / 9.336 ms | 125.170 / 133.302 ms |
| 16 / 512 | Warmup fails | 9.436 / 9.169 ms | 591.485 / 466.716 ms |
| 32 / 64 | 17.270 / 17.279 ms | 11.444 / 10.865 ms | 6,657.999 / 6,608.137 ms |
| 32 / 512 | Warmup fails | 12.133 / 11.122 ms | 6,958.075 / 6,833.060 ms |

This closes GL-034's reproduced frame/CPU regression within the exercised
profiles. All current large-world candidate trials admit and converge under the
unchanged queue/native/time limits. Baseline 16/32-peer large worlds fail all-peer
warmup with invalid-target errors; the separate candidate-only trials are not
paired speedups. The 32-peer convergence result is a material limitation, tracked
as GL-039. At 64 objects, baseline final convergence is 0.096–0.399 ms. Preserve
required reparent ordering while investigating that difference.

In the paired 32-peer small world, whole-server user CPU is 3.844/3.547 seconds
for the candidate versus 7.891/9.422 seconds for main; measured sent bytes are
28.96/30.01 MB versus 96.11/94.62 MB. These are workload-specific observations:
CPU includes the entire actor lifecycle and ENet bytes include resends/protocol
traffic. One-peer sent bytes increase, so this is no general bandwidth claim.
Maximum observed Release sweep turn is 0.762 ms across the candidate cases;
this excludes synchronous affected reparent capture, which frame times include.

Separate actual ENet impaired-link pairs pass at one peer/512 objects and
16 peers/64 objects. A task-owned UDP proxy drops every seventeenth datagram and
adds 40-ms delay with 0/35/70-ms jitter to the last client. All eight configurations
observe intentional loss and reordered forwards with zero overflow. At 16 peers,
the candidate's 15 healthy peers have maximum per-peer RTT p95 of 33.426/33.432 ms,
while the impaired peer has 516.711/516.563 ms; all 64 measured callbacks and
eight Function calls per client complete. This establishes finite progress in
this workload, not a general starvation bound. A separate impaired 16-peer/512
baseline fails warmup and is retained without a candidate comparison.

Both sealed coordinator installations use exact `cf1628de...`, fixed numeric
profiles, fresh run IDs and checked nested/outer owned Jobs. The first window's
nonzero result preserves baseline failures; it is not relabeled success. A fresh
six-minute follow-up supplies the missing supported-world fairness comparison
without mutating the first input seal. Final census finds zero owned processes
or listeners. Collection/transfers complete before checked early release at
11:26:11 UTC, inside the 11:08:48–11:28:48 reservation. Raw archive 10 contains
19,469 members/67,818,845 bytes; ZIP integrity passes and SHA-256 is
`886d2c136c1d2998a7a4adc8684c80879a99a75bfba8854b26e860bc2018dec3`.
It retains actual fixtures, reports, failed logs, helpers, identities and journals.

Release `MEMORY_STATIC` returns zero and is unavailable; it does not show zero
memory growth. Object/node counters, sampled native occupancy, staged payload
bytes and machine commit headroom are recorded. Allocation rates, total process
RSS, long-duration reconnect storms, broader 32-peer impairment and graphical
behavior remain separate coverage. The current full native sanitizer and
four-profile/package receipts establish their own exact configurations.

## Bounded sweep measurements — 436850a

The [fresh paired receipt](evidence/networking2-436850a-asandebug-benchmark.json)
records eight passing one-peer Windows Debug ASan configurations, 64 measured
samples/16 warmups, with native fingerprint `770c9ff5...`, the same admitted
host/compiler and exact main baseline. The separately sealed coordinator first
passes all seven strengthened relevance actors, then both paired world sizes.

| Objects | Product | Server frame p95, trials 0/1 | Fire/echo RTT p95, trials 0/1 |
| --- | --- | --- | --- |
| 64 | Main | 9.17 / 9.55 ms | 33.71 / 26.11 ms |
| 64 | Candidate | 9.51 / 9.32 ms | 34.07 / 33.30 ms |
| 512 | Main | 9.34 / 9.45 ms | 34.07 / 25.67 ms |
| 512 | Candidate | 9.61 / 9.98 ms | 33.08 / 33.98 ms |

At 512 objects, measured sweep work totals 0.751/0.742 seconds across 761/766
turns; maximum turn is 2.706/2.813 ms. These counters now describe bounded turns,
not whole rebuilds, and exclude synchronous affected barrier capture. Final
client structural convergence is 711.104/84.991 ms, versus baseline
0.463/0.409 ms; the test waits for the exact final value and records that latency.
No replication failure or unexpected ASan report occurs. This establishes the
one-peer frame-cost correction, with asynchronous convergence as an explicit
tradeoff. It does not establish larger-peer, Release, loss/fairness or allocation
rate acceptance.

Other chats retired stale SSH worker processes before this window. Therefore use
the fresh within-window baseline/candidate comparison; do not attribute an
absolute before/after timing change across environments solely to source code.
The two-job build takes 25.25 seconds; DLL SHA-256 is
`47cf79e9faa6fd7eb90479ec1a91dee2ea4932ccacc02533297ad4aee792ea6d`.
Both coordinator profiles exit zero and their outer owned Jobs are verified
empty before checked release to the next project.

## Focused refresh correction — bd18580

The [new paired receipt](evidence/networking2-bd18580-asandebug-benchmark.json)
records eight passing configurations with the same admitted Windows Debug ASan
host/compiler, 64 measured samples and 16 warmups. Candidate native fingerprint
is `554af399...`; baseline is exact main `9f52b27`. The three narrow changes skip
unpublished reparent refreshes, measure periodic cadence after completion, and
exclude maintenance from the unchanged peer submission budget.

| Objects | Product | Server frame p95, trials 0/1 | Fire/echo RTT p95, trials 0/1 |
| --- | --- | --- | --- |
| 64 | Main | 11.64 / 11.87 ms | 34.33 / 37.93 ms |
| 64 | Candidate | 20.12 / 22.25 ms | 76.49 / 100.69 ms |
| 512 | Main | 13.92 / 16.21 ms | 42.74 / 41.51 ms |
| 512 | Candidate | 100.64 / 98.30 ms | 331.50 / 333.91 ms |

At 512 objects, candidate refresh consumes 11.41/10.77 seconds across 145/146
calls; maximum refresh is 136.85/110.93 ms, with zero recorded replication
failures. Early exclusion and the new cadence improve the original 414–426 ms
frame regression substantially, but still do not establish acceptable baseline
parity. GL-034 remains open. The source still scans the full native catalog and
refreshes published structural barriers synchronously. A broader incremental
candidate now uses the campaign's explicit bounded-refactor authorization;
the earlier approval question was unnecessary. Its new implementation remains
unqualified and is not substituted into these measurements.

These earlier measurements preceded the qualified current Release/larger-peer
results above; they remain negative evidence for that earlier source.

## Release follow-up

The [Release receipt](evidence/networking2-release-benchmark.json) preserves
18 passing measured configurations, two passing smoke configurations, one failed
setup smoke, and three retained large-world failures. Immutable products are
exact main and the original `532650f` relevance implementation, with the same
qualified Release host/compiler. These do not measure the newer native refresh
and GL-035 corrections. Host hashes and actual ownership/RPC checks are in the
[host receipt](evidence/networking2-release-host-verification.json).

| Peers / world | Outcome | Server frame p95, main / relevance | Combined client RTT p95, main / relevance |
| --- | --- | --- | --- |
| 1 / 64 | Both products, two trials pass | 8.4–8.5 / 8.5–8.7 ms | 25.1 / 25.1–33.4 ms |
| 1 / 512 | Both products, two trials pass | 8.5 / 11.5–12.0 ms | 25.0–25.1 / 41.7–50.1 ms |
| 16 / 64 | Both products, two trials pass | 10.9–11.0 / 10.2–11.6 ms | 42.0–47.8 / 41.7–41.8 ms |
| 32 / 64 | Both products, two trials pass | 70.3–74.4 / 53.6–66.1 ms | 974–1,294 / 275–659 ms |
| 16 / 512 | Main warmup fails; relevance passes twice | Unavailable / 46.3–49.3 ms | Unavailable / 174–224 ms |
| 32 / 512 | Both products fail warmup | Unavailable | Unavailable |

At 32/512 the relevance source logs explicit backlog/dependency and reliable
admission failures; both products produce invalid-target errors after peers
leave. The resource guard does not trigger: minimum observed commit headroom
is about 6.8 GB for the candidate failure. No valid steady-state comparison
exists for the failed configurations. Do not raise native limits or call this
32-player large-world support. The exact causal split remains under investigation.

The first Release attempt exposed GL-036: GDScript
[omits assert expressions in non-debug builds](https://docs.godotengine.org/en/4.3/tutorials/scripting/gdscript/gdscript_basics.html#assert-keyword).
Setup and checks now execute in ordinary calls, including bounded deadlines.
Independent configuration selection preserves failed baselines while allowing
separately labeled candidate/32-peer scenarios; it cannot create a paired result
where the baseline failed. Raw archive 8 SHA-256 is
`f30e914a718451c4202563d62478724817562eff8c5533dee935dd4c61db1d3f`.

The [Phase 1 receipt](evidence/networking2-phase1-benchmark.json) compares exact
main `9f52b27` with the GL-030 runtime under the same DockerPC MSVC Debug ASan
host/compiler. Eight 1/16-peer configurations complete, with two interleaved
trials, 16 warmups and 64 measured 1 KiB Fire/echo samples per peer. This is
network-only overhead evidence. Two candidate server teardown stderr logs have
channel-zero send errors. Six 32-peer baseline reports show allocator/mapping
exhaustion; no corresponding candidate measurement exists. Preserve these
negative observations rather than calling the complete matrix successful.

## Mixed workload

`FoundationBenchmark.gd` extends the existing production Fire/echo harness. Both
products run identical public gameplay and native Character implementations:
64 or 512 authored runtime anchored Parts; real Character lives; an approved
looping presentation scale track; eight Functions per peer per 64 measured
samples; high-frequency property writes; two same-turn reparent barriers;
short-lived object creation/removal; and server-authorized Character focus
movement between spatial regions. The baseline retains global legacy world
replication, while the candidate explicitly enables ADR-011. This comparison
does not replace actual rig/bone graphical qualification.

Native child signals maintain Part/Character census. Character physics/input
is frozen consistently to keep the headless workload bounded; native animation
playback, networking and Character identity remain active. This is not a
movement-feel benchmark. Counter convergence is checked after the server's
measured workload completes. Existing warmup, echo ordering, callback counts,
argument checks, retirement and companion environment remain unchanged.

Report frame/dispatch distributions, Fire/echo RTT, native/application occupancy,
source replication counters, startup/convergence time, Godot object/memory
counters, whole-owned-process kernel/user CPU time, and ENet sent/received data
and packets. ENet counters are reset at phase boundaries using
[ENetConnection.pop_statistic](https://docs.godotengine.org/en/stable/classes/class_enetconnection.html#class-enetconnection-method-pop-statistic);
they include protocol/resends. Whole-process CPU includes startup, warmup and
teardown; sampled native occupancy is not an exact high-water guarantee, Godot
memory counters are not total process RSS, and no allocation-rate claim is made.

`RunFoundationBenchmarks.py` alternates trial order and validates immutable
products, compiler and admitted host identity. Workloads use disposable roots,
captured headless processes, finite deadlines and exact task-owned cleanup.
ASan uses a conservative commit/physical-memory preflight. A verified
uninstrumented Release configuration has a distinct preflight and a live
resource observer; if system commit headroom falls below 1 GiB, only this
workload's owned actors terminate and the result is failure. This observer does
not alter machine settings, unrelated processes, native admission or assertions.

Initial mixed ASan trials complete both product configurations for 64/512 worlds
at one peer with two trials and 64 measured samples. Sixteen and 32 peers are
explicitly blocked by preflight: available commit is about 9 GB despite about
20 GB free physical memory. A previous 33-actor run already exhausted this
profile. Repeating it is not qualification. The nonpublishing candidate workflow
can export its already qualified admitted Windows Release host, including
manifest/runtime hashes and Godot license notices, for a separate bounded
Release comparison. Export is a qualification artifact, not a release channel
or updater admission. Dependency/host-patch pins remain unchanged.

The core workflow also has an explicit `ExportBenchmarkHost` manual option.
It retains the ordinary core jobs and adds an independent host build using two
compiler jobs and actual ENet native ownership/RPC checks before exporting the same
admitted Release profile. This host-only evidence does not accept source
candidates, skip their gates or grant publication. It avoids waiting for a
complete candidate build merely to obtain the executable needed for a bounded
Release memory profile.

Current Release/larger-world and bounded impaired-link/fairness results are
recorded above. Remaining coverage includes longer sustained churn, repeated
disconnect/reconnect storms, broader impairment and allocation instrumentation.
Phase 2/3 correctness fixtures cover deterministic
WouldBlock, independent healthy-peer progress, reconnect and callback-driven
cancellation; those facts are not substituted for performance measurements.

## Negative mixed-ASan result

Both paired one-peer trials pass functional checks but reproduce GL-034:

| World objects | Product | Server frame p95, trials 0/1 | Fire/echo RTT p95, trials 0/1 |
| --- | --- | --- | --- |
| 64 | Main | 11.2 / 10.7 ms | 34.4 / 38.0 ms |
| 64 | Relevance | 56.8 / 57.1 ms | 173.8 / 181.7 ms |
| 512 | Main | 12.2 / 12.9 ms | 37.4 / 41.1 ms |
| 512 | Relevance | 426.2 / 414.5 ms | 1,440.6 / 1,440.1 ms |

Candidate native fingerprint is `a7c63d0...`; main is `27822f8...`. At 512 objects,
whole-server user CPU increases from 23.6/24.4 s to 108.0/108.3 s and measured
sent bytes from 63,405/65,611 to 213,029/213,007. Spatial presentation reduces
client Parts to 64–128, but these observations establish no overall speedup.
Startup/workload durations differ, so whole-process CPU is not a per-frame CPU
comparison. Raw archive 6 preserves the exact driver, prepared fixtures,
identity receipts and all completed/blocked configurations; its SHA-256 is
`f183c5a502d82e6dea71ea4bff4c8ecd9ab5000f2785b9d8c62de2aa32ca00e3`.
