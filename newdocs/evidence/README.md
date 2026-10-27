# Shared-domain qualification evidence

[`gl006-008-qualification-2026-10-27.json`](gl006-008-qualification-2026-10-27.json)
records the dedicated security branch's source identity, six passing 39-case
core configurations, 90 passing native process results, binary/result/log hashes,
per-session chat policy and remaining scope limits. Source and test hashes match
the Windows/Linux workers. Raw logs remain on those task workers; the
[authority report](../network-authority-validation.md) documents trust rules,
actual adversarial transport assertions, commands and compatibility. Historical
shared-domain and GL-019 reports below retain their original source scope.

[`shared-domains-benchmark-2026-10-26.json`](shared-domains-benchmark-2026-10-26.json)
contains all 90 final benchmark phase records: three counts, three trials, two
architectures and five phases. See the [validation report](../shared-domains-validation.md)
for baseline/source identities, toolchain, worker limits, methodology, measured
regressions and excluded stale TIME_PROCESS fields. The summarizer at
`tests/runtime/SummarizeBenchmark.py` reads these records directly.

[`shared-domains-qualification-2026-10-26.json`](shared-domains-qualification-2026-10-26.json)
records runtime/source identity, dependency pins, executed gate counts/raw-file
digests, the four current binary hashes and local archive identity. It explicitly
retains the unqualified gates alongside passing results.

[`shared-domains-integration-2026-10-26.json`](shared-domains-integration-2026-10-26.json)
records the main merge/source-tree identities and fresh integrated core/native
checks. The [main integration record](../shared-domains-validation.md#main-integration-2026-10-26)
distinguishes those runs from reused historical qualification evidence.

GL-019 records preserve all measurements instead of replacing earlier data:

| File | Meaning |
| --- | --- |
| [Original/shared fresh baseline](gl019-original-shared-baseline-2026-10-26.json) | Five trials/count; Baseline = original per-script, Shared = pre-GL-019 |
| [Population comparison](gl019-population-comparison-2026-10-26.json) | Seven trials/count; Baseline = pre-GL-019, Shared = optimized |
| [Captured require comparison](gl019-require-comparison-2026-10-26.json) | Seven trials/mode; Before/Candidate, one million calls |
| [Core microbenchmarks](gl019-core-microbenchmarks-2026-10-26.jsonl) | Eleven trials at 10/100/1,000; pre/post, CPU/wall/C++ allocations |
| [Larger core sensitivity run](gl019-core-microbenchmarks-large-2026-10-26.jsonl) | Twenty-one trials at 10,000; same phase definitions |
| [GL-019 qualification](gl019-qualification-2026-10-26.json) | Source/binary identities, native perf counters and actual gate results |
| [GL-019 main integration](gl019-main-integration-2026-10-26.json) | Merge/source identity, fresh CMake/SCons/core/native checks and focused performance smoke; historical datasets unchanged |

The [GL-019 report](../shared-domains-validation.md#gl-019-optimization-2026-10-26)
defines metric scopes, spreads, accepted/rejected changes and residual task costs.
Native perf data remains under `/opt/codex/godotluau/artifacts/gl019` as
`pre-require.perf`, `post-require.perf`, their `*-flat.txt` reports and
`*-require-stat.txt` counters. Sampling is limited to the task container; the
official engine is stripped and inclusive function costs overlap.

Raw native logs and failure reports remain in ignored/task-owned artifact trees;
they contain repeated expected-denial/physics diagnostics and are not silently
reclassified by the summary. Exact reproduction commands live in
[`tests/runtime/README.md`](../../tests/runtime/README.md).

| Evidence | Location on the recorded worker/local checkout |
| --- | --- |
| Linux CMake core Debug/Release/ASan repeated suites | `linuxbox:/opt/codex/godotluau/logs/linux-complete-{debug,release,asan}-tests.log` |
| Linux final CMake native fixtures | `/opt/codex/godotluau/artifacts/linux-qualified-{debug,release}/results.json` |
| Linux final SCons package fixtures | `/opt/codex/godotluau/artifacts/linux-package-scons-{debug,release}/results.json` |
| Full Linux native ASan/LSan ordered-close stress | `/opt/codex/godotluau/artifacts/linux-full-asan-stress/results.json` |
| Preserved uncoordinated full-ASan leak | `/opt/codex/godotluau/artifacts/linux-full-asan-guard/report.*` |
| Engine-only full-ASan 54-byte leak | `/opt/codex/godotluau/artifacts/asan-engine-only/report.*` |
| Linux official engine-only five-case matrix | `/opt/codex/godotluau/artifacts/linux-probe/results.json` |
| Final benchmark and per-process stdout/stderr | `/opt/codex/godotluau/artifacts/benchmark-final` |
| Windows CMake core/adapter builds and repeated suites | `dockerbox:C:\Sandbox\Codex\Logs\GodotLuau\qualification-windows-complete-builds.log` |
| Windows SCons failure and correction logs | `C:\Sandbox\Codex\Logs\GodotLuau\qualification-windows-scons*.log` |
| Windows normal native fixtures | Local `.runtime-tests/qualification/windows-qualified-{debug,release}` |
| Windows SCons native fixtures | Local `.runtime-tests/qualification/windows-scons-{debug,release}` |
| Windows engine-only matrix | Local `.runtime-tests/qualification/windows-probe` |

Task artifacts are retained for review and reproduction, not promised permanent
hosting. The repository keeps the commands, source fixtures, benchmark records
and immutable qualification/package identities. No binary is committed or
published as a release, and the inherited ZIP is never a qualification input.
