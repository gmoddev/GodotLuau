# Networking Foundation 2 measurements

These experiments do not establish 64-player support or a general speedup.
Runtime/source qualification and performance evidence are separate gates.

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

Remaining performance coverage includes Release 16/32 peers, an impaired-link
profile, mixed traffic fairness/starvation, more sustained churn and repeated
disconnect/reconnect storms. Phase 2/3 correctness fixtures cover deterministic
WouldBlock, independent healthy-peer progress, reconnect and callback-driven
cancellation; those facts are not substituted for performance measurements.
