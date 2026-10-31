# Character V2 qualification

Status: qualified for the documented source/headless scope on
`runtime/character-v2-model`, stacked on qualified GL-007 tip `514d12f`.
Both branches remain unmerged. Releases and updater distribution remain disabled.
See [development evidence](character-v2-development.md),
[ADR-007](adr-007-model-character.md) and [API migration](character-v2-api.md).

## Source and preparation gate

Qualified source/test revision:
[`d7905dd4af5c7a89c9b0f0a005861e9043379be1`](https://github.com/gmoddev/GodotLuau/commit/d7905dd4af5c7a89c9b0f0a005861e9043379be1).
It preserves implementation `4e3a96c`, manual-loading correction `9312d01`,
camera-binding correction `f9260e5` and the final fixed-camera fixture control.
Subsequent attestation edits documentation/evidence only.

Preparation commit `9ec71c024b012aada68750ab9bae3349115a165d` passed both hosted
core jobs in run `41039974670` and both native jobs in run `41039974656`.
Main remains `4ea53113a98961a64347c672890f65bf9b5c8a54`; GL-007 remains
`514d12f1bf1add924214492248a459e0763d4ca0`.

The final native fingerprint is 88 LF-normalized production files:
`e64dffcbd69a806aedadcf98dc97507a3a17eaff88ced4a38d9fbd7d4ac427db`.
Pinned dependencies remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`; complete tracked dependency
digests match the qualified parent. Worker checkouts use source overlays rather
than claiming their historical local Git HEAD is this revision. Fingerprints,
dependency digests and archived actual fixture copies establish the tested inputs.

## Executed local matrix

Final V7 results, independently checked from both transferred archives:

| Configuration | Core cases | Native actors | Result |
| --- | ---: | ---: | --- |
| Windows Debug | 73 | 86 | Pass |
| Windows Release | 73 | 86 | Pass |
| Windows core ASan | 73 | — | Pass; GL-018 full-native limitation retained |
| Linux Debug | 73 | 86 | Pass |
| Linux Release | 73 | 86 | Pass |
| Linux matching full-native ASan/LSan and core ASan | 73 | 86 | Pass with leak detection and clean exits |

Each native configuration contains all eight groups: regression 8, authority 10,
animation 10, characters 20, resource limits 8, filesystem 3, HTTP 4 and DataStore
23. DataStore additionally verifies four fault stages, four interrupted commit
stages and 40 independent native increments. No power-loss test is claimed.

The 20 character actors retain the 16 existing GL-007 scenarios, add the actual
76-check Model fixture and three manual-loading actors. Coverage includes real
Model/Character/Animator identity, hierarchy/pivot/bounds, synchronized valid
parent transforms and rejected direct invalid poses, camera-controller math and
deletion, keyboard/sprint/camera-relative/gamepad/touch movement, jump/fall,
NPC targeting and collision hit identity, finite health/configuration,
actual animation completion and playback ownership, retained views, destruction,
disable/reload, custom visual and native StarterCharacter templates, repeated and
reentrant respawn, native deletion/CharacterRemoving, initial manual loading,
unspawned-player late join, owner/observer replacement and stale packet rejection.
Actual unchanged R6 assets also pass the complete 76-check fixture on both platforms.

Both SCons `template_debug` and `template_release` products pass on each platform:
40 focused actors per product (20 character, 10 authority, 10 animation).
Companion packaging passes all five tests per platform. Process ownership/failure
handling passes all 14 Linux tests and eight Windows tests; six Linux-specific
process-inspection/signal cases are correctly skipped on Windows.

Sustained builds used two jobs and persistent caches on `dockerbox` and the
existing `linuxbox` qualification container. Processes were hidden/headless,
isolated and bounded. Windows uses crash UI suppression. The Linux matching engine
retains the previously qualified physics-enabled ASan/LSan configuration,
`use_static_cpp=no` and `disable_path_overrides=no`, SHA256
`02f913eddb7069fe2c35319d74af10525752ab33c08ac2e1f4612e829a96853a`.
No toolchain or dependency change was introduced.

## Reproduction

The archived command helpers retain exact paths, environments, orchestration and
exit checks. Principal repository commands are:

```text
cmake --build <configuration> --target ExecutionDomainTests GodotLuauAdapter DatastoreBackendProbe --parallel 2
ctest --test-dir <configuration> --output-junit <report> --output-on-failure
python tests/runtime/CheckCoreCI.py report <report>
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh-output> --characters --timeout 60
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh-output> --manual-characters --timeout 60
python tests/runtime/RunCharacterBenchmarks.py --godot <engine> --extension <library> --output <fresh-output> --script CharacterV2.gd --r6-assets <unchanged-r6-assets>
python tests/runtime/RunCharacterNetworkBenchmarks.py --godot <engine> --extension <library> --output <fresh-output>
scons platform=<windows-or-linux> target=<template_debug-or-template_release> -j2
```

The matrix also executes the unchanged regression, authority, animation, resource,
filesystem, HTTP and transactional DataStore groups. Full-native sanitizer runs
use the matching engine and `ASAN_OPTIONS=detect_leaks=1:halt_on_error=1`.
Windows core ASan builds only the core target. Linux orchestration adopts/reaps
the intentional companion-process interruption descendants under ADR-005.

## Hosted CI and artifacts

At the exact qualified revision, all four hosted jobs pass:
[core run 41139334359](https://github.com/gmoddev/GodotLuau/actions/runs/41139334359)
and [native run 41139334272](https://github.com/gmoddev/GodotLuau/actions/runs/41139334272).
Core artifacts verify discovery and 73 distinct completed cases on each platform.
Each native artifact verifies the exact revision/fingerprint, 86 actors, all 259
declared log hashes, 52 normalized harness hashes, engine provenance and companion
fault/recovery evidence. ZIP hashes match GitHub's published digests.

| Artifact | SHA256 |
| --- | --- |
| runtime-core-Windows-Debug | `47afb49354c4998ad3626b3ef5a037591f3b9a1064a9fcf5f7d3439772429934` |
| runtime-core-Linux-Debug | `f84a59b6122c0cbe952052b62dd8446b50e88c926b640356bb1a16ccf8099d01` |
| runtime-native-Windows-Debug | `f11421a892c33453e0add6e24edefdbfd087f2a281c01af7b37cae75924fc4c7` |
| runtime-native-Linux-Debug | `fe4216db806e90845260857b19d69746348f536eac1e447315e4aa3f11772679` |

## Comparable measurements

Fresh Release trials use the same current benchmark harness on retained GL-007
products and the candidate, with actual R6 assets. Creation/respawn use 30 measured
samples after warmup; one/16-character frame profiles use 120 samples. Native
AnimationPlayer advance uses 30 batches of 1,000 calls. The actual ENet workload
has a host and two clients, two remote Characters per actor and 240 samples each.
It measures whole-frame network/presentation workloads, not isolated method costs.

Medians, parent → candidate:

| Measurement | Windows | Linux |
| --- | --- | --- |
| R6 creation, microseconds | 6758 → 6712 | 2569 → 2400 |
| Respawn, microseconds | 393 → 433 | 326 → 365 |
| One-character physics, milliseconds | 0.218 → 0.212 | 0.223 → 0.244 |
| 16-character physics, milliseconds | 0.692 → 0.711 | 0.497 → 0.628 |
| 16-character process, milliseconds | 0.334 → 0.307 | 0.185 → 0.177 |
| Native animation advance, microseconds/call | 0.553 → 0.269 | 0.122 → 0.119 |
| Network host whole-frame process, milliseconds | 0.351 → 0.352 | 0.175 → 0.248 |
| Native nodes per R6 Character, including internal nodes | 21 → 22 | 21 → 22 |

There is an observed cost: respawn rises about 10–12%; Linux's 16-character physics
median rises 0.131 ms (about 26%), and its network-host process median rises
0.073 ms. These single trials have substantial scheduling jitter, especially
Windows tails, and do not establish statistical improvements/regressions for
individual subsystems. No performance improvement is claimed from simplification.
Raw medians/P95s, client frame data, object/memory counts and product hashes remain
in [machine-readable evidence](evidence/character-v2-qualification.json).

Both candidates have zero object growth and zero measured static-memory growth
after 100 repeated respawns. The parent has zero object growth and four measured
static bytes. This is the bounded exercised workload, not an unlimited lifetime
or production scaling guarantee.

## Retained evidence and limits

Local collection:
`C:\Users\aiden\.codex\artifacts\godotluau\character-v2`.
The two archives preserve development failures, exact commands/configurations,
actual fixture copies, final summaries and logs. Every manifest entry was verified.

| Archive | SHA256 | Verified entries |
| --- | --- | ---: |
| character-v2-windows-evidence.zip | `9d4f3f72c444004a13a219f22c07add627ebd3e0a8283616fb378640add98261` | 12229 |
| character-v2-linux-evidence.zip | `5a8bdc4b2f210b1e4938a02a300b057f58419bee55d2faf3ed2214c522511241` | 14530 |

Completed identical result-library copies were hardlinked only after hash checks,
preserving paths/bytes and keeping build outputs independent. A development run
exhausted disposable worker disk; it is retained as a failure, and the final
stable V7 matrix ran with restored headroom. Earlier fixture/setup errors, actual
candidate leaks, the corrected readiness premise and transient HTTP frame-progress
failure remain separate from final acceptance. No check or sanitizer was waived.

Headless camera/transform and animation assertions do not establish graphical
correctness. No graphical display/Xvfb is available in the Linux qualification
environment; Windows tests remain hidden/headless. Physical-device ergonomics,
rendered camera/animation appearance and arbitrary custom content are unqualified.

GL-018's Windows full-native sanitizer-host gap and GL-017's independent engine
relay edge remain. The bounded service-departure cases retain inherited inactive
ENet diagnostics. This does not establish server collision truth, production
anti-cheat, full GL-020 animation-security qualification, a dependency-wide SDK
assignment fix or mixed-build gameplay. GL-024/025 are qualified on this branch;
GL-026's exercised importer/protocol workaround is qualified with broader
dependency follow-up open. Existing user content needs explicit manual migration.
