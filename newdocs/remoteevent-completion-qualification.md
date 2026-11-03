# GL-029 later-phase qualification

Status: local qualification complete; final hosted and package verification in
progress. GL-029 remains OPEN until those gates pass. The branch is unmerged.
The [work record](remoteevent-completion-work.md) preserves development failures;
[ADR-009](adr-009-bounded-remote-delivery.md) and the
[API/migration contract](remoteevent-api.md) define candidate behavior.

## Source and retained local evidence

Runtime source is `6e29c8681adef414c2911e25e7f6414a210c6b15`, native fingerprint
`27822f8ec52e43c440c20dad7f6038d6d70fc8d28332b6665eabb2b8c6d279fa`
(91 LF-normalized inputs). The packaging-upload correction is separately
`3c552e63950a3f1d293c2a9994c0ccc734c4f6d7`; it changes no runtime input.
The engine pin, godot-cpp and Luau pins remain unchanged.

The controlled Windows worker uses MSVC compiler SHA-256
`b0a1818ebae6da7f18230a84e76ce839212584ac4c2ab55b97a0d5268085da57`,
Debug ASan, two build jobs and persistent caches. The matching extension is
`c9faa2dad570cb1032aa10d0dc1317032a5aadaba07e409f0dc6700466079498`;
the admitted host is
`d68f6f49e8f5aba0a00768aaa3e971d1c86cde1ff49e4784ded7fb91d28a0cf7`.
Host patch SHA-256 is
`df10215b62e125d3595972e5f16e0c7b45a9b0b9141564a91f1741b413f7568b`.

Local `completion-evidence-v1.zip` retains 2,865 files, 13,347,725 compressed
bytes, SHA-256
`798ae18690f7f14fede266ddebb90f68309d7d9bfbc483dbc86daff6e866dfaf`.
Every indexed member and the archive hash are independently verified after
download. It contains logs, source snapshots, identities, raw results and failed
attempts; generated binaries remain outside Git.

| Executed local check | Result |
| --- | --- |
| Strict core ASan regression | 81 distinct cases; exact production aggregate byte/message ceilings and allocation rollback included |
| Native ownership fixture | 156 assertions; exact peer/host bytes and commands, partial/full ACK, reset/destroy, rejection and healthy partial fanout |
| Native RPC fixture | 18 assertions; cached/uncached WouldBlock, terminal unbuffered control failure and complete packet measurements |
| Existing RemoteEvent actors | All six listen/dedicated actors pass on corrected source; 54.843 seconds |
| Real UDP faults | Three actors, two independent proxies; 7.937 seconds; intentional reliable loss recovers natively in order, unordered loss remains lost, delayed old sequence rejects |
| Actual native-method packet | 256-byte UTF-8 NetworkService path; maximal 816-byte event frame submits as 820-byte cached RPC packet, one command |

Each proxy observes two reliable matching datagrams after dropping the first,
one dropped unordered datagram, two delayed datagrams and one duplicated datagram.
There are zero capacity drops and no unexpected sanitizer reports. Duplication
can be suppressed by ENet's own unsequenced window; the test does not invent an
application exactly-once guarantee. The separate host-only fixture measures
1,066-byte uncached / 819-byte cached script-method RPC packets. Native-method
identifiers use the larger encoding; the actual native event measurement above
exercises it. All remain below the measured 1,364-byte unfragmented budget at
MTU 1,392. Final hosted Debug/Release packet gates remain required.

## Comparative network performance

Two trials alternate baseline/candidate order on the same worker, using immutable
products and matching original/admitted hosts, identical compiler/build arguments,
16 warmups and 64 measured 1 KiB reliable Fire/echo operations per peer. Both
products are Debug ASan. The workload uses actual separate processes, 120 FPS
caps and production callbacks; it creates no Character/rendering workload.

Baseline native fingerprint is
`ac6706375ad4dfa912b6424bf9c17d767262e51ed62dbc5ebfeaf614e8ec2ffc`;
baseline extension is
`5721e2092827dba585e817192a9b4fbe0ceff23b0769112d78b3b542658c68e5`.
The baseline host retains GL-018's admitted correction, without the GL-029 host
adapter. This compares the complete changes at the observed build configuration.
These timings do not establish production Release latency or graphical speed.

Pooled round-trip milliseconds across both trials:

| Peers | Product | Samples | Mean | Median | p95 | p99 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Baseline | 128 | 13.14 | 15.68 | 16.66 | 16.95 |
| 1 | Candidate | 128 | 29.04 | 31.17 | 33.77 | 33.98 |
| 16 | Baseline | 2,048 | 72.40 | 70.63 | 93.66 | 110.80 |
| 16 | Candidate | 2,048 | 114.56 | 113.73 | 135.73 | 149.29 |
| 32 | Baseline | 4,096 | 210.05 | 212.92 | 307.66 | 360.07 |
| 32 | Candidate | 4,096 | 505.65 | 503.03 | 574.32 | 634.41 |

The candidate increases latency. Deferred bounded dispatch exchanges immediate
poll-time callback execution for peer turns and later ticks. Median client Fire
call cost rises from 1.61/1.71/1.77 ms to 1.84/1.97/2.07 ms at 1/16/32 peers.
Median server Fire call cost rises from 1.94/2.54/3.42 ms to 2.20/2.87/3.96 ms.
These calls include codec/validation/admission; they do not isolate codec CPU.

| Peers | Baseline server frame p95 | Candidate server frame p95 | Candidate dispatch p99 |
| --- | --- | --- | --- |
| 1 | 12.14 ms | 9.19 ms | 4.50 ms |
| 16 | 79.77 ms | 15.42 ms | 14.23 ms |
| 32 | 244.46 ms | 30.59 ms | 37.01 ms |

Frame progression improves in this workload while response latency worsens.
The dispatch bracket changes its coverage when callbacks move from engine poll
into NetworkService's node tick, so its baseline/candidate values are not total
network CPU comparisons. Active callback/native work can exceed a 4 ms
between-message slice; GL-004's execution deadline remains authoritative.

Both products start exactly 160/2,560/5,120 client callbacks and the same number
of server callbacks at 1/16/32 peers. The candidate reports zero application
drops/supersessions in this reliable workload. Its outgoing queue high water is
1,100 bytes; incoming high water is 1,100/16,500/34,100 bytes. Sampled native host
ownership reaches 1,104 bytes and at most five commands. These are observations,
not exact peak proofs; the independent native boundary fixture establishes caps.
The original host has no corresponding native observation API.

All actors tear down to one node and at most 1,123 native objects for both
products. Maximum candidate static-memory change after teardown versus warmed
pre-work state is -6,380 / +29,068 / +172,712 bytes at 1/16/32 peers. Two trials
with these engine-monitor observations do not prove allocator leak absence or
an unbounded-growth result; sanitizer/lifecycle evidence remains separate.

The baseline 64-peer attempt stops with 59 warmups complete; the candidate-only
64-peer attempt also misses its bounded deadline. Neither is a pass. The practical
comparative scope is 32 actual peers, consistent with the assessment's bounded-
equivalent allowance. Existing engine/resource ceilings are not silently changed
into a larger performance qualification. No scaling refactor is included.

## Hosted verification status

Initial runtime `6c04b20` passes hosted Windows/Linux core, ordinary native (Linux
after one unchanged rerun), both full-native sanitizer jobs and all four source
build/runtime profiles. Initial packaging fails because the artifact upload common
root changed. Raw failed artifacts are retained. Private normalized copies of
all four profile payloads pass the unchanged strict production profile/native
verifiers; this confirms the layout cause without calling packaging successful.

Fresh runs against runtime `6e29c86` and their downloaded artifacts now verify:

| Hosted workflow | Windows | Linux |
| --- | --- | --- |
| [Core 41618226624](https://github.com/gmoddev/GodotLuau/actions/runs/41618226624) | 81 distinct cases | 81 distinct cases |
| [Native 41618227155](https://github.com/gmoddev/GodotLuau/actions/runs/41618227155) | 116 actors, 459 Remote assertions, two host fixtures | 116 actors, 459 Remote assertions, two host fixtures |
| [Full-native 41618226865](https://github.com/gmoddev/GodotLuau/actions/runs/41618226865) | ASan: 81 core / 116 native, 460 Remote assertions | ASan/LSan: 81 core / 116 native, 459 Remote assertions |

Independent verification matches runtime/harness identities, all recorded native
log hashes, host patch identities, product/compiler identities and ASan compile
commands. Both ordinary native artifacts also retain 4,000 distinct GUID samples
each. The full-native uploads retain their checked GUID summary rather than the
raw GUID text; no raw-sample recheck is claimed for those two uploads.

All 23 Windows / 24 Linux sanitizer checks pass, including intentional detection
controls and lifecycle reloads, with no unexpected reports or timed-out results.
The downloaded manifests verify 557 Windows / 562 Linux files. Each retains one
missing transient GL-003 mailbox JSON after fixture consumption; no required log,
result or input is missing. This is an explicit evidence-retention limitation.
GL-018's admitted matching-host/headless scope, Windows-LSan and renderer/device
limitations remain unchanged.

The non-publishing [candidate run 41620026268](https://github.com/gmoddev/GodotLuau/actions/runs/41620026268)
at `3c552e6` verifies the artifact-layout correction and exact package inputs.
Its source-product/package/acceptance checks remain in progress; they must finish
and the downloaded artifacts must verify before closing GL-029.

Main remains unchanged. Releases and updater distribution remain disabled.
