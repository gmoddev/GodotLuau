# Character V2 presentation/performance main integration

## Source identity and authorization

The user accepted the documented small or inconsistent performance tradeoffs
and authorized this controlled integration on 2026-10-31 (local time). Normal
merge `bee07b7d4fc948556e69aa2ae0306b0ad1a52fb4` has parents:

- Previous main: `c562ba8b74226a15ffb5e18e6547cfccebac94dd`.
- Retained `perf/character-v2-graphical-qualification`:
  `57d0083e66ea50893fb28f57f0d29ef2e71b8ce3`.

The merge tree equals the source tip exactly
(`11eb40e76ae3075283188faee9dfae8da8572738`) and preserves all 15 commits.
Runtime implementation remains `2bd43741f82fd5308e01e5bb88462e17ae256fb7`;
runtime, test and workflow inputs equal qualified fixture revision
`432b06af6f5a9d43ad9c5961ed7f84de25266699`. The 89-file LF-normalized native
fingerprint is
`559961ab22bc22ec349b8bb80cc4dd0fdc4cc4a2b180c78d37f06a59a4d401b0`.
Dependency pins remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.

The only production changes avoid writes of equal live transforms, replace
internal reflective camera calls with typed calls, and finish first-person
fade at exact endpoints (GL-028). Every synchronization still validates the
pose and resolves the live body. No unsafe cached-pose authorization is added.
Model inheritance, native ownership, protocol 3 and GL-007 authority remain the
ADR-006/007 contracts. GL-003/004/005/009/019/020/022/023 behavior is retained;
no HTTP origin grant, cancellation policy, resource limit or public API changes.

## Fresh integration verification

The merge was pushed to the verified `origin` fork, and its remote SHA checked.
Fresh core/native main CI is observed for at most 25 minutes. Artifact validation
checks exact merge identity, dependency pins, native fingerprint, all 63 fixture
hashes, actual case/actor markers and declared log hashes. A workflow name or
green aggregate alone is insufficient evidence of execution.

| Fresh main run | Windows Debug | Linux Debug |
| --- | --- | --- |
| [Core 41267351401](https://github.com/gmoddev/GodotLuau/actions/runs/41267351401) | PASS, 80 distinct cases; artifact verified | PASS, 80 distinct cases; artifact verified |
| [Native 41267351412](https://github.com/gmoddev/GodotLuau/actions/runs/41267351412) | PASS, 110 actors; artifact verified | PASS, 110 actors; artifact verified |

All four jobs pass within the 25-minute observation window; nothing remains
pending. All four ZIPs are downloaded and digest-verified on DockerPC. The
unchanged hosted-artifact verifier checks 80 distinct core completions per
platform and all 110 zero-exit native actors, including all 14 presentation
actors and required assertion labels, exact fade endpoints, custom puppet
geometry, remote rig animation and grounded walking observation. The performance
fixture executes five windows at 1/16 characters; this is execution evidence,
not a speed threshold. GL-023 retains 4,000 unique GUID samples and zero
unauthorized HTTP requests; published caller migration also reports zero
unauthorized requests. DataStore retains four fault stages, four kill stages
and 40 independent increments. Character Model's 76 checks and two real delayed
ENet proxies also verify. Pins, 63 fixture hashes and all declared log hashes
match the merge inputs.

An early verifier invocation rejects the missing Windows native ZIP while the
asynchronous download is still running. After the download exits successfully,
the unchanged verifier passes all four artifacts. This ordering mistake and its
failed diagnostic are retained in the archive; no test failure is inferred.

Fresh actual rendered Debug/Release fixtures pass on DockerPC with the existing
qualified native products and official Godot bytes. The worker verifies all
63 current fixture inputs against the merge, the native source fingerprint,
the frozen product hashes against the retained graphical execution, and all
asset inputs against Git before accepting evidence. Each configuration executes
14 actual NVIDIA/OpenGL actors, 454 assertions and 48 hashed PNG captures.
R6/custom local, listen-host and dedicated cases all pass; exact six-mesh fade
endpoints are 1. Transforms/body repair, cameras, simulated keyboard/mouse/
controller/touch input, movement, real animation progression/completion and
death/respawn/manual loading execute. Fresh R6 third-person and custom
first-person captures were also visually inspected. Headless hosted presentation
actors are separate from these real graphical runs.

For each `release` and `debug` configuration, the worker invokes the existing
`tests/runtime/RunCharacterPresentation.py` with `--graphical`, the official
Godot executable, `candidate-v3/<mode>/godot_luau.dll` and a fresh output under
`C:/Sandbox/Codex/CharacterGraphics/integration-bee07b7/graphical-<mode>`.
The integration collector checks the renderer, every assertion/capture, source
and product identity; its helper and complete output are archived together.

The first Release evidence-collection attempt rejects raw Git/working-copy
asset-byte equality after the graphical actors have passed. Inspection identifies
only CRLF versus LF in UTF-8 OBJ/MTL/import/shader text. The collector now verifies
their normalized contents against Git and preserves both raw hashes; binary
assets still require exact byte equality. All executed asset hashes also equal
the original qualified graphical run's hashes. No runtime/fixture/asset is
changed or graphical assertion relaxed, and the completed Release run is retained
without rerunning it. Debug then passes independently. The initial collector
failure and diagnosis remain in the integration archive.

## Accepted performance scope and retained qualification

The [follow-up record](character-performance-followup.md) and its raw-distribution
summaries remain unchanged. Eight extended interleaved measured pairs on DockerPC
give these median endpoints (baseline to candidate): 64-character rendered CPU
1.518 to 1.559 ms, Linux network-host process 0.0385 to 0.0390 ms, Linux
16-character physics p99 0.510 to 0.509 ms, Windows respawn p99 661 to 637 us.
Windows physics medians improve consistently; render/host/tail effects remain
mixed across short, extended, full-sequence and separate MainPC comparisons.
Linux whole-actor CPU and MainPC's adverse 64-character physics tail remain
visible. These are accepted development tradeoffs, not formal equivalence,
an FPS gain, or proof that every original outlier has a known cause.

The complete Linux Debug/Release core reports (80 each), Release native (110)
and core ASan/LSan (80) remain retained on identical runtime inputs. The original
1,024-byte CTest truncation report and strict-check failure are preserved.
The runner now uses the already-qualified hosted 65,536-byte output flags;
the strict checker is unchanged. Prior Windows Debug/Release core/native and
core-ASan qualification remains retained. Integration does not claim a newly
repeated Release/sanitizer build matrix or new performance trials.

## Remaining limitations and publication boundaries

Native allocation-event profiling and full-native ASan/LSan were unavailable in
the follow-up. Live object/static-byte stock measurements are not allocator
event counts or universal leak-freedom evidence. After 1,500 respawns both
products retain the same small static-byte increase with no live object/node
growth; sampling itself allocates. DockerPC's preexisting background contention,
fallback hardware differences and finite tail samples limit inference.

GL-027's visible StarterCharacter prototype authoring limitation remains open;
fixtures move the prototype away from gameplay. GL-017's external engine defect,
GL-018's Windows native sanitizer-host gap and broader GL-020 adversarial
animation qualification remain independent. Physical-device ergonomics,
arbitrary assets, server collision truth and production-scale performance are
not qualified by these fixtures.

All local runtime execution for this integration uses DockerPC; no LinuxBox or
other worker is used. Existing caches, source branches, failed attempts and
negative findings are retained. The manual release workflow still has both
jobs disabled and read-only permissions; runtime updater admission remains
false. No upstream write, release, updater distribution or further development
is part of this integration.

The [machine-readable integration record](evidence/character-presentation-main-integration.json)
retains product, source, asset, screenshot and hosted-artifact identities. The
[archive record](evidence/character-presentation-main-integration-archive.json)
identifies the complete retained graphical/CI collection and helper scripts.
The final publication follow-up changes documentation/evidence only, leaving
all qualified runtime, test, workflow, asset and dependency inputs unchanged.
