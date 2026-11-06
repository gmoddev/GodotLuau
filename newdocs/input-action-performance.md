# Input performance investigation

DockerPC (HostPC), Windows 11, existing MSVC 14.51.36231 Release toolchain and
unchanged pinned Godot 4.7.1/godot-cpp/Luau inputs. Builds and measurements reuse
the existing caches. No compiler or other task-owned workload runs during the
measurements. Binary hashes, worker/processor identity, raw observations and
trial order are retained in the linked JSON, not reconstructed from summaries.

The [main comparison](evidence/input-main-comparison-2026-11-06.json) uses source
main `091c13da85b1d082249b525123f5cae4d3c17dd1` and the first complete controller
candidate. Five trials alternate baseline/candidate order. Each real Godot
viewport burst routes 32 immutable W press/release events, with eight warm bursts
then 64 measured bursts per workload. Candidate post-GUI commit is explicitly
included in the timed CPU interval; frame waiting is excluded. Every workload
verifies its exact expected callback count. Raw0 estimates routing/harness cost;
Raw1/16/64 preserve legacy raw signal workloads. Dense semantic cases bind every
action to W; sparse cases bind only one action to W and the rest to Q. Both
exercise actual production handlers and owner-aware Lua callbacks.

The initial main/candidate raw comparison retains the cost of fixing GUI routing:
median microseconds per 32 events are 30 → 40 with no subscribers, 73.5 → 82
with one subscriber, 448 → 454.5 with 16, and 1,585.5 → 1,620 with 64. The
corresponding p99 values are 63 → 69, 130 → 153, 814 → 742 and 2,364 → 2,249.
The post-GUI queue adds a small absolute routing cost; the subscription workloads
show mixed tails. These values compare main with the first complete controller
candidate, before the semantic publication optimization below. Raw routing code
is unchanged by that optimization. Do not describe this campaign as a universal
legacy-input performance improvement.

The existing [hot-path benchmark](../tests/runtime/HotPathBenchmarks.cpp) gains
`--input` to isolate the production evaluator. Its [40 profiles](evidence/input-projection-profiles-2026-11-06.jsonl)
cover five repeats at 1/16/64/256 actions, dense and sparse, with 1,000 warm events
then 50,000 measured events. Mean CPU wall time per 32 events ranges from 8.9 to
138.0 microseconds dense and 8.7 to 84.4 microseconds sparse. Counted C++ `new`
allocations are zero during evaluation; authoring, Godot and Luau malloc are
excluded. These timings establish that full callback/publication cost dominates
the dense engine workload; they do not isolate every component of that residual.

## Bounded publication optimization

Source inspection identifies redundant ObjectID resolution and value commits for
every unchanged action on every event/frame. Publication now resolves/commits
only the complete changed set before dispatch, while compile/cancellation and
physics sampling keep their explicit full-state synchronization. Callback
snapshots retain validated reference IDs without zero-filling 128 unused callback
structures. No native pointer cache, new scheduling system or changed callback
authority is introduced.

The [optimization comparison](evidence/input-publication-comparison-2026-11-06.json)
uses the preserved unoptimized DLL and optimized DLL, both with the same semantic
API. Five interleaved trials use identical workloads and warmed caches. Values
below are microseconds per 32-event burst, **not frame-time percentiles**.

| Workload | Mean before → after | Median before → after | p95 before → after | p99 before → after |
| --- | ---: | ---: | ---: | ---: |
| Sparse 16 | 160.86 → 137.28 | 159 → 133.5 | 200 → 181 | 213 → 220 |
| Sparse 64 | 262.07 → 152.89 | 254 → 149 | 318 → 203 | 377 → 230 |
| Sparse 256 | 662.86 → 219.75 | 635 → 211 | 775 → 270 | 872 → 310 |
| Dense 256 | 10,230.14 → 9,517.03 | 9,907 → 9,192 | 12,413 → 11,791 | 13,359 → 12,914 |
| Raw 64 control | 1,712.96 → 1,756.28 | 1,675.5 → 1,737 | 2,171 → 2,200 | 2,335 → 2,387 |

Sparse 256 improves in every paired trial, with medians 643/638.5/633/634/624
before and 212.5/220.5/206/215/209.5 after (overall median -66.8%). This is the
source-attributable reason to keep the small optimization. Dense 256 is mixed:
the final two paired trial medians regress about 0.5% and 7.8%, despite the
overall improvement. Raw controls also drift despite using the same raw code;
do not attribute every timing change to the patch. Sparse16 p99 increases from
213 to 220. Preserve these observations and avoid a universal speedup claim.

## Scope and limits

This is synthetic headless event routing on one worker, not physical device,
networking or GPU frame-rate qualification. The separate rendered controller
fixture establishes real rendering and gameplay state, not comparative rendering
performance. Godot's periodically refreshed TIME_PROCESS diagnostic is stale in
some samples; its retained values must not be reported as per-frame CPU p95/p99.
Native allocator coverage is limited to the isolated evaluator's C++ counter and
the demo's stable node count/Godot static-memory observation; there is no claim
of complete native/Godot/Luau allocation profiling. The dense 256-action case
intentionally fans one key into 256 callbacks and is a stress workload, not a
claim about an ordinary controller's input layout. CI checks correctness and
actual fixture execution without introducing a noisy speed gate.
