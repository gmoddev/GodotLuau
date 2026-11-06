# Character V2 qualification follow-up

This is the retained pre-integration qualification record. The subsequent
authorized [main integration](character-presentation-main-integration.md)
preserves these inputs, failed attempts, negative findings and limitations.

This follow-up starts at development branch
`5963f83737b17a7268610fa9ce3f4b646a7b8042`. Main remains
`c562ba8b74226a15ffb5e18e6547cfccebac94dd`; no integration is authorized here.
The runtime is the existing qualified `2bd43741f82fd5308e01e5bb88462e17ae256fb7`,
with 89-file native fingerprint
`559961ab22bc22ec349b8bb80cc4dd0fdc4cc4a2b180c78d37f06a59a4d401b0`.
No runtime optimization is assumed necessary before reproducing the adverse
observations. The [original record](character-presentation-performance.md) and
its negative measurements remain historical evidence.

## Qualification method

All local execution remains on DockerPC (HostPC, Ryzen 9 5900X, GTX 1650 SUPER),
including Linux in the retained task-owned Docker Desktop container. Existing
Windows Godot 4.7.1/MSVC products and Linux Clang 19/CMake/Godot caches are reused.
Builds use at most two jobs. Benchmarks run serially after builds and functional
qualification finish; hosted CI may run independently. No LinuxBox, dependency
changes, distribution or updater is used.

DockerPC's read-only load sample reports about 80% CPU and thirteen old `sshd -R`
workers consuming approximately one core each, with no child processes. Their
creation dates predate this task; they are not claimed as task-owned and are
left untouched. The paired primary runs therefore describe this contended host,
and do not establish idle-machine performance. This context is not proof that
SSH load caused any particular candidate/baseline difference.

MainPC (`DESKTOP-B8V8NAN`, Ryzen 9 7950X3D, Radeon RX 7900 XT, observed initial
load 9%) is used as the permitted Windows fallback. It reuses the exact frozen
baseline/candidate Windows products and official Godot bytes, with existing
Python and task-isolated source/assets/output directories. Each pair uses the
same machine and configuration; MainPC results are kept separate from DockerPC,
and cannot establish that a GTX 1650-specific cost disappeared. No system
configuration, active session or unrelated workload is changed. Two bounded
Python/SSH staging attempts timed out after creating the destination folders;
the direct PowerShell staging path completes. No test result is inferred from
those failed transfers.

The [original Linux XML](evidence/character-followup/original-linux-truncation/candidate-core.xml)
contains CTest's explicit 1,024-byte truncation notice. Its strict verification
failure and orchestration traceback are retained beside it. The local runner
was missing the hosted workflow's `--test-output-size-passed 65536` and
`--test-output-size-failed 65536` flags. These are restored; the versioned
`RunCoreQualification.py` additionally uses the same discovery, verbose output,
bounded CTest invocation and unchanged strict 80-case report checker. Fresh
output directories retain successful reports without replacing the original.

The reusable invocation after configuring/building each mode is:

```text
python tests/runtime/RunCoreQualification.py --build <existing-build-directory> --output <fresh-evidence-directory>
```

For a multi-configuration Windows build, add `--config Debug` or `Release`
and `--ctest <installed-ctest.exe>` when necessary. Sanitizer compilation and
`ASAN_OPTIONS` remain the invoking configuration's responsibility; the evidence
records both separately and does not infer instrumentation from a successful
ordinary test.

The rendered summary's scope label now correctly states three paired trials.
Its numerical measurements have not been changed. Numerical validation against
the retained raw archive is part of the follow-up evidence collection.

## Performance method

First repeat the original 240-sample windows for the affected 64-root GPU and
16-root Linux workloads with nine alternating pairs.
The first pair is retained as warmup and excluded from inferential summaries;
eight remaining pairs are the independent units. Extended runs use 1,200 physics
samples and 200 measured creation/respawn calls after five discarded calls.
Subsystem modes preserve the same products/configuration while disabling
animation or physics updates in the fixture. All default CI fixture assertions,
counts and runtime contracts remain unchanged.

Priority probes measure elapsed scene dispatch, engine render monitors measure
viewport rendering, and whole-actor OS CPU includes startup/harness overhead.
These are distinct quantities. Network-only mode disables Character/controller
and procedural-animation processing after actual peers/puppets exist; it retains
native transport and scene dispatch and is not an isolated networking CPU timer.
Disabling movement can also change packet activity; mode differences must not
be added/subtracted as independent component CPU budgets or treated as a
constant-packet causal experiment. The retained Linux tool image has none of
`perf`, `valgrind` or `heaptrack` on PATH; no native allocation-event profile is
collected in this pass.
Godot live object/static-byte counts are allocation-stock observations, not
allocator-event counts. Per-window p99 observations and 200-call lifecycle tails
remain sample-limited; thousands of frames are not independent paired trials.

Exact paired sign tests and descriptive paired bootstrap intervals will be
reported with absolute times, trial count, direction consistency and raw
distributions. Multiple exploratory endpoints do not establish causal
attribution by themselves. Runtime changes require source evidence and a
demonstrated benefit; no unsafe cache or authority/lifetime relaxation is allowed.

## Completed Linux qualification

| Configuration | Actual result | Evidence |
| --- | --- | --- |
| Linux Debug core | 80 distinct cases PASS | [verified report](evidence/character-followup/core-debug/verified.json) |
| Linux Release core | 80 distinct cases PASS | [verified report](evidence/character-followup/core-release/verified.json) |
| Linux Debug core ASan/LSan | 80 distinct cases PASS | [verified report](evidence/character-followup/core-asan/verified.json) |
| Linux Release native | 110 actors PASS, all strict groups | retained native summary and final collection |

The [configuration record](evidence/character-followup/core-configurations.json)
retains executable hashes, Clang 19 build types and actual `-fsanitize=address`
compile/link flags. ASan execution uses `detect_leaks=1:halt_on_error=1`.
Each core run includes discovery, the sixteen owned resource children, complete
JUnit and the unchanged strict case checker. The original rejected 1,024-byte
report remains separate; these fresh passes do not alter it.

Native Release passes GL-003/004/005/007/009/019/020/022/023 and Character V2
regression groups, including fourteen presentation actors and the five-window
performance smoke. These are headless functional assertions. The native runtime
fingerprint and frozen candidate product are unchanged from the preceding
qualification. This run's fixture snapshot precedes the diagnostic network
typing fix; its actual hashes remain retained, not relabeled as later execution.

The first new network profiling invocation fails to parse `var Animator :=`
because its receiver is a dynamically typed Array element. The failed directory
and stderr/runner traceback are retained as `network-all-Baseline-0-failed-inference`.
The fixture now uses explicit `Node` typing and requires an actual animator at
the established local `R6Animator` or remote `Visual/R6Animator` path before
pausing it. The complete network comparisons execute that correction; no runtime
factory or authority code changes. Earlier hosted success did not exercise this
standalone benchmark script and is not claimed as proof that it parsed.

Full-native ASan/LSan is not newly qualified: no matching instrumented Godot host
has been qualified for this pass on the permitted machines. GL-018's Windows limitation and broader
GL-017/020 qualification limits remain. No preexisting LinuxBox execution is
substituted for this pass.

## Repeated performance results

The primary extended comparisons contain eight measured interleaved pairs after
one retained warmup pair. They use 1,200 physics samples per dispatch window and
200 measured lifecycle calls per actor. Each cell below is the median of the
respective trial statistics, not a pooled distribution. Values are ordered
**mean / median / p95 / p99**. Paired percentage changes are calculated within
each pair first, so they need not equal the ratio of displayed aggregate medians.

| Primary endpoint | Baseline distribution | Candidate distribution |
| --- | --- | --- |
| DockerPC 64-root viewport render CPU, ms | 1.5254 / 1.5180 / 1.8625 / 1.9925 | 1.5335 / 1.5590 / 1.8560 / 1.9890 |
| Linux three-peer host process dispatch, ms | 0.04753 / 0.03850 / 0.09350 / 0.12350 | 0.05014 / 0.03900 / 0.10200 / 0.13100 |
| Linux 16-root physics dispatch, ms | 0.31505 / 0.29800 / 0.44300 / 0.51000 | 0.31171 / 0.29400 / 0.43850 / 0.50900 |
| DockerPC Windows respawn call, microseconds | 457.015 / 448.5 / 558.5 / 661.0 | 455.480 / 448.0 / 549.0 / 637.0 |

| Selected statistic | Median paired change | Descriptive 95% paired-bootstrap interval | Exact sign P |
| --- | ---: | --- | ---: |
| 64-root render CPU median | +1.20% | -0.70% to +4.31% | 0.727 |
| Linux network-host process median | +1.32% | -5.13% to +5.13% | 1.000 |
| Linux 16-root physics p99 | -1.19% | -4.47% to +4.09% | 0.727 |
| Windows respawn p99 | -2.31% | -12.30% to +2.14% | 0.289 |

All four exploratory primary endpoints have Holm-adjusted P=1. These bounded
runs do not establish a consistent adverse shift, and do not prove equivalence
or the absence of a regression. No performance acceptance margin was specified
in advance. The short 240-sample GPU repeat still has an adverse render-CPU
point estimate: 1.4655→1.6055 ms, paired +5.29%, six of eight pairs worse,
interval -3.96% to +16.77%, sign P=0.289. That counterevidence is retained.

The original full **1/16/32/64** sequence is additionally replayed with five
interleaved pairs and its original 240-sample windows, thirty lifecycle calls
and sixty-tick warmup. The first pair is retained warmup; four measured pairs
therefore preserve the original sequence's allocation/history context rather
than only starting fresh at 64 roots. At 64, viewport render CPU has baseline
mean/median/p95/p99 **1.55254 / 1.56550 / 1.89200 / 2.02250 ms** and candidate
**1.54287 / 1.51150 / 1.87850 / 1.99200 ms**. Median paired change is -2.97%,
three improved/one worse, interval -12.55% to +9.60%, sign P=0.625. This replay
also fails to establish a stable candidate render penalty; its small sample is
not an equivalence proof and does not replace the original negative evidence.

The original Windows respawn p99 used only thirty measured calls, making it the
single maximum observation in each trial. Two hundred calls improve tail
resolution without turning them into independent paired trials. This explains
a limitation of the original 569→648 microsecond inference; it does not prove
why either original maximum occurred.

Existing physics benefits remain measurable on Windows. DockerPC 64-root GPU
physics median is 1.6240→1.5745 ms, paired -3.08%, eight of eight improved;
16-root headless is 0.4080→0.3940 ms, paired -3.91%, eight of eight improved.
Each exact sign P is 0.0078125, exploratory and unadjusted for those additional
endpoints. Linux's extended physics median is mixed (five improved, three worse,
paired -0.33%); the earlier Linux median benefit is not claimed as uniformly
reproduced. Mean process-frame intervals remain near the 120 FPS cap. No general
FPS, rendering, creation, respawn or network-host speedup is claimed.

MainPC independently observes 64-root render CPU 0.4745→0.4775 ms, paired +0.20%,
four improved/four worse, interval -1.28% to +2.55%, sign P=1. Windows headless
respawn p99 is 601.5→562.0 microseconds, paired -2.47%, six of eight improved,
interval -8.41% to +6.02%, sign P=0.289. Its 16-root headless physics median
improves in all eight pairs (-2.78%, sign P=0.0078125). These remain separate
hardware observations. Negative MainPC 64-root physics-tail evidence also remains:
p99 is 1.5275→1.6020 ms, paired +2.70%, six of eight worse, interval -1.82% to
+11.02%, sign P=0.289. Linux whole-actor CPU rises in seven of eight extended
pairs (paired +1.32%, sign P=0.0703); it is not hidden by the dispatch summary.

Four measured subsystem pairs per mode do not isolate a stable candidate cost.
DockerPC render-CPU paired medians are -0.78% with animation paused, +2.04% with
physics paused, and +1.26% with both Character and procedural animation inactive.
MainPC's corresponding changes are -0.72%, +0.41% and +1.15%. These small samples
and different retained scene histories do not identify a causal hot path.
Linux host process median is equal at 0.0355 ms with animation paused and
0.0285→0.0265 ms with Character/controller and animation processing disabled.
Transport remains real; disabled movement can alter packet activity, so these
are diagnostic ablations rather than isolated network CPU accounting.

Full original-sequence replay, source identities and all distributions are
retained in the [Windows analysis](evidence/character-followup/windows-analysis.json),
[Linux analysis](evidence/character-followup/linux-analysis.json),
[MainPC analysis](evidence/character-followup/mainpc-analysis.json) and compact
[endpoint record](evidence/character-followup/performance-endpoints.json).
Every raw mean/median/p95/p99 is recomputed from its stored samples on an allowed
worker. Actual per-actor executed fixture copies and immutable library/Godot
hashes are checked against invocation inputs. MainPC's export is `1bc5e05`;
its executed performance/presentation/probe scripts are identical to `432b06a`.
Later changes affect its unused network diagnostic script. Overlay checkout
HEADs are not used as substitutes for content and product identity.

## Separate allocation-stock investigation

Both Windows and Linux run an additional frozen-body R6 lifecycle probe with
100 warmup respawns followed by three 500-respawn blocks. Every block retains
1,554 live objects and 35 nodes in both products. Static allocated bytes rise
by 1,292 from warmup to 1,500 respawns in both products on each OS; the candidate
is a fixed eight bytes above baseline at every absolute-stock checkpoint. The residual common
growth is not attributed to a native leak or declared to be zero.

Retaining five copies of the original sampling dictionaries reproduces the
original first-to-last `+3048` byte reading **without any intervening respawn**,
with zero object delta. The held-sample stock increases by 3,772 bytes; clearing
it releases 3,504 bytes, leaving 268 bytes including intervening diagnostic work.
This establishes a sampler contribution and invalidates treating the original
`+3048` alone as evidence of a Character leak. It does not establish universal
leak freedom. [Windows](evidence/character-followup/windows-memory.json) and
[Linux](evidence/character-followup/linux-memory.json) retain every checkpoint.
Allocation-event counts and fully instrumented native-host leak qualification
remain unavailable; object/static-byte counts are explicitly different metrics.

## Hosted qualification and implementation scope

Both hosted platforms pass at fixture revision
`432b06af6f5a9d43ad9c5961ed7f84de25266699`:
[core 41263214425](https://github.com/gmoddev/GodotLuau/actions/runs/41263214425)
verifies 80 distinct cases each, and
[native 41263214446](https://github.com/gmoddev/GodotLuau/actions/runs/41263214446)
verifies 110 actors each. All four downloaded artifacts pass digest, source,
dependency, log and exact 63-file fixture identity checks on DockerPC. Required
fourteen-actor presentation assertions and five independent performance windows
execute; headless hosted success is not new graphical gameplay qualification.
See [artifact verification](evidence/character-followup/hosted-verified.json).

The follow-up commits add the complete-report wrapper, optional matched profiling
controls and corrected evidence metadata. The failed diagnostic typing attempt
remains in history and evidence. **No production runtime implementation changes
are made.** Existing native implementation `2bd4374`, authority, lifetime,
protocol, dependency pins and measured Windows physics improvements remain.
The preceding actual rendered Debug/Release gameplay qualification and Windows
80-core/110-native Debug/Release and 80-case core-ASan records remain retained
for identical native inputs; fresh hosted Debug and new Release performance/
memory execution are distinguished from that retained full Windows matrix.

## Disposition and preserved evidence

**READY WITH ACCEPTED TRADEOFFS — recommend acceptance for development
integration.** The complete Linux reporting/native/core-sanitizer gap is closed.
The original large adverse estimates do not reproduce consistently across the
interleaved, longer-window, full-sequence and independent fallback comparisons.
Windows physics improvements remain measurable. No further production patch is
source-justified by these observations, so the existing runtime is retained.

Acceptance explicitly includes small unresolved renderer/host/tail point
estimates, broad descriptive intervals, DockerPC's background CPU contention,
different fallback hardware, allocation-stock rather than allocation-event
profiling, and unavailable full-native sanitizer qualification. No general
performance gain, formal equivalence, production-scale qualification or causal
explanation for every original outlier is claimed. MainPC's adverse physics
tail and Linux's whole-actor CPU observations remain visible. GL-027 template
authoring, GL-017/018 and broader GL-020 limits, physical input ergonomics and
arbitrary imported content retain their earlier scope. Releases/updater remain
disabled. Integration remains a separate action; main is unchanged.

Three CRC/entry-hash-verified archives retain the raw distributions, actual
fixture copies, logs and failed attempts selected for this follow-up. Receipts
are [DockerPC Windows](evidence/character-followup/windows-archive.json),
[DockerPC Linux](evidence/character-followup/linux-archive.json) and
[MainPC](evidence/character-followup/mainpc-archive.json). They are also copied
to `C:/Users/aiden/.codex/artifacts/godotluau/character-followup` for local review.
The initial Windows archive (`2ad355ea4ebad4dd54309fae1ce88e6f530e286c36247bc5bf564b0dea2feefe`)
is preserved separately before the full-sequence supplement. The original
129 MB graphical qualification archive remains unchanged.

The retained Linux task volume contains complete local Release native output;
the published [summary](evidence/character-followup/linux-native-summary.json)
includes actor results, source/fixture identities and log hashes. The
[failed new network runner](evidence/character-followup/failed-network-runner.log)
and original truncated-report evidence remain separate from fresh passes.
CI artifact receipts verify all required hosted fixtures actually execute.
Evidence-only final commits leave the qualified runtime and test inputs intact.
Scoped evidence attributes preserve the captured JSON/XML/log bytes for their
recorded hashes. Only CTest's generated trailing spaces and the failed runner's
final blank line are exempted from whitespace diagnostics; runtime assertions
and strict completion checks are unchanged.
