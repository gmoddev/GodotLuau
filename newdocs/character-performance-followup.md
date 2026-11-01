# Character V2 qualification follow-up

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
qualification finish; hosted CI may run independently. MainPC fallback has not
been needed. No LinuxBox, dependency changes, distribution or updater is used.

The [original Linux XML](evidence/character-followup/original-linux-truncation/candidate-core.xml)
contains CTest's explicit 1,024-byte truncation notice. Its strict verification
failure and orchestration traceback are retained beside it. The local runner
was missing the hosted workflow's `--test-output-size-passed 65536` and
`--test-output-size-failed 65536` flags. These are restored; the versioned
`RunCoreQualification.py` additionally uses the same discovery, verbose output,
bounded CTest invocation and unchanged strict 80-case report checker. Fresh
output directories retain successful reports without replacing the original.

The rendered summary's scope label now correctly states three paired trials.
Its numerical measurements have not been changed. Numerical validation against
the retained raw archive is part of the follow-up evidence collection.

## Performance method

First repeat the original all-count workload with eleven alternating pairs.
The first pair is retained as warmup and excluded from inferential summaries;
ten remaining pairs are the independent units. Extended runs use 1,200 physics
samples and 200 measured creation/respawn calls after five discarded calls.
Subsystem modes preserve the same products/configuration while disabling
animation or physics updates in the fixture. All default CI fixture assertions,
counts and runtime contracts remain unchanged.

Priority probes measure elapsed scene dispatch, engine render monitors measure
viewport rendering, and whole-actor OS CPU includes startup/harness overhead.
These are distinct quantities. Network-only mode disables Character/controller
and procedural-animation processing after actual peers/puppets exist; it retains
native transport and scene dispatch and is not an isolated networking CPU timer.
Godot live object/static-byte counts are allocation-stock observations, not
allocator-event counts. Per-window p99 observations and 200-call lifecycle tails
remain sample-limited; thousands of frames are not independent paired trials.

Exact paired sign tests and descriptive paired bootstrap intervals will be
reported with absolute times, trial count, direction consistency and raw
distributions. Multiple exploratory endpoints do not establish causal
attribution by themselves. Runtime changes require source evidence and a
demonstrated benefit; no unsafe cache or authority/lifetime relaxation is allowed.

## Current disposition

Qualification and repeated measurements are in progress. Pending runs are not
passing evidence. Final source identities, reports, distributions, hosted CI,
limitations and integration recommendation will be recorded after execution.
