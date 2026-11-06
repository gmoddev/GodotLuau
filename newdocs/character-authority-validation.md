# GL-007 character authority qualification

Status: **integrated and resolved on main within ADR-006's bounded contract**,
through normal merge `4d4694e8ea5f05120ded9b116bcd06a2c95e4ead`. Fresh Windows/Linux
main core/native jobs pass with all four artifacts verified. See the
[integration record](character-main-integration.md). The original branch
qualification and subsequent Character V2 preparation gate remain preserved below.

## Scope and identity

Branch: `security/gl-007-character-authority`, based on main
`4ea53113a98961a64347c672890f65bf9b5c8a54`. This section records the original
branch qualification, before the subsequent integration authorization.
The final native input fingerprint is
`20ecbfcbb11cbdbef85480c41ec3cd4e1705bba210cb3ab290c84eab518b329a`
(87 LF-normalized files). Dependencies remain godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

The [work record](character-development.md) retains the Windows/Linux baseline
health/position reproduction, two subsequent animation-health bypasses and the
development failures. [ADR-006](adr-006-character-authority.md) defines the final
authority, protocol, limits and asset migration. This is bounded gameplay
authority, not a general script sandbox, collision simulation or full GL-020
security qualification.

| Field or operation | Authority and accepted behavior |
| --- | --- |
| Health / MaxHealth / damage / healing | Native Server state; Client execution cannot write native health. Server snapshots update replicas. |
| Spawn, dimension, life and correction epoch | Server-selected; readiness cannot choose a position, revive a destroyed character or reuse an old life. |
| Position / yaw | Finite bounded client prediction; native server corrections issue a fresh epoch. No server collision-truth claim. |
| Movement configuration | Native server grants; 3D bounds derive from current Humanoid settings. Existing default 2D platformer/top-down paths retain their plane bounds. |
| Speed / airborne presentation | Finite/ranged predictions, independently rate limited; not authoritative collision or health state. |
| Animation selection | Startup catalog or a checked existing named rig clip; no packet-time arbitrary server resource load, gameplay track or scripted resource initialization. |
| Gameplay timelines | Client track controls and network presentation cannot interrupt an active gameplay timeline or overwrite its inactive clip by alias. |
| Lifecycle and callbacks | ObjectID revalidation, cancellation and native reference cleanup; CharacterAdded can destroy a character or service safely. |

Old state/animation RPCs fail closed. Matching protocol 2 builds are required;
there is no mixed-version downgrade. Custom project content needs the asset
registration and ServerScript migration described in ADR-006.

## Local execution

Heavy work runs on Windows `dockerbox` under `C:\Sandbox\Codex` and independently
on Linux `linuxbox` in the task-owned `codex-godotluau-qualification` container,
with `/opt/codex/godotluau` mounted at `/work`. Builds use two jobs and retained
incremental caches. Windows has a historical workspace Git HEAD; Linux uses a
source archive. Explicit overlays are qualified by the matching fingerprint,
rather than misrepresented as clean checkouts of the eventual published commit.
All 165 tracked godot-cpp and 852 tracked Luau files match the clean pinned local
checkouts by normalized path/content digest on both workers.

| Configuration | Current result |
| --- | --- |
| Windows Debug / Release | 73 core cases and all 82 native actor results pass in each. |
| Linux Debug / Release | 73 core cases and all 82 native actor results pass in each. |
| Windows core ASan | All 73 cases pass. Full-native Windows sanitizer remains excluded by GL-018. |
| Linux core ASan | All 73 cases pass. |
| Linux full-native ASan/LSan | All 82 native actor results pass, with real physics and leak detection enabled. |
| Windows / Linux SCons template_debug and template_release | Each product passes all 36 focused character/network/animation actors. Process ownership and packaging checks pass. |

The 82-actor suite includes the complete existing lifecycle (8), network (10),
animation (10), resource (8), filesystem (3), HTTP (4) and DataStore (23) groups,
plus 16 character actors. DataStore's separate native evidence still requires
four fault stages, four kill stages and 40 independent increments; no power-loss
test is claimed. The 36 product actors are the 16 character plus existing 10
network and 10 animation actors, without a CMake-only lifecycle test hook.

Commands, with explicit platform/configuration paths:

```text
cmake --build <existing-config> --target ExecutionDomainTests GodotLuauAdapter DatastoreBackendProbe --parallel 2
ctest --test-dir <existing-config> --output-junit <core.xml> --test-output-size-passed 65536 --test-output-size-failed 65536 --output-on-failure
python tests/runtime/CheckCoreCI.py report <core.xml>
python tests/runtime/RunQualification.py --godot <verified-engine> --extension <matching-library> --output <new-output> --teardown --coordinated-close --timeout 60
python tests/runtime/RunQualification.py --godot <verified-engine> --extension <matching-library> --output <new-group-output> --characters --timeout 60
scons platform=<windows-or-linux> target=<template_debug-or-template_release> -j2
```

The same native runner executes `--security`, `--animation`, `--resources`,
`--filesystem`, `--http` and `--datastore` into separate output roots; resource
actors use 15-second bounds. Windows SCons uses the previously approved portable
4.5.2 installation through `RunSConsPortable.py`. Exact helper commands and logs
are retained with the final evidence collection.

The instrumented engine uses pinned Godot 4.7.1 source
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, matching shared GCC C++ runtime,
ASan/LSan, real native 2D/3D physics, FreeType, TLS, ENet, multiplayer and GDScript.
`BuildSanitizedGodot.sh` preserves `use_static_cpp=no` and path overrides.
`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1` remains enabled; no suppression is
introduced. A scoped subreaper handles deliberately killed DataStore descendants
in the container whose PID 1 is not an init process, as required by ADR-005.

## Acceptance facts exercised

- Actual native local/listen/dedicated two-client characters, server damage and
  health replication, corrections, manual and automatic respawn, exactly one
  death, destruction and reconnect with stale-life rejection.
- Finite/range checks, impossible poses, legacy/wrong-role/wrong-sender paths,
  valid-pose floods, bounded continuous 3D ascent and resynchronization that
  cannot replenish that ascent allowance.
- Actual 3D walk/jump/fall, actual 2D platformer walk/jump/fall and sustained
  top-down movement, with server/observer checks.
- Real ENet forwarded through a bounded UDP proxy with 200–270 ms delay in each
  direction and deterministic jitter/reordering; retained statistics require two
  active forwarders, nonzero forwarding and no drops.
- Property/method/root/scripted animation attempts leave server health and safe
  cache intact; deferred resource initializer effects cannot escape Client load
  admission. Safe named-library playback, alias bounds and original clip
  restoration remain functional.
- Shared-scene Client rotation/Destroy/ClearAllChildren rejection, retained native
  signal views, callback-reference release and character/service destruction
  during actual CharacterAdded callbacks.

## Limits and publication

Retained local collection:
`C:\Users\aiden\.codex\state\plugins\codex-security\scans\forkedgodot\artifacts-542989bd43e22e429d804a7960af0279a784254b9f3300f7b47f96f704ab5207\artifacts\qualification`.
It contains exact helper commands, configuration, summaries, original logs and
the failed engine diagnostics. The transferred archives and every manifest file
hash were verified; `gl007-local-qualification.json` records all accepted products.

| Archive | SHA256 | Verified entries |
| --- | --- | --- |
| gl007-qualified-windows-evidence.zip | `7ded219c931e3191a6e73f1869ab2a848aa4c60fd753e9d10f2caec1bbf3b82f` | 1,489 |
| gl007-qualified-linux-evidence.zip | `859592932977648844cb0221b1d7c9e98b6132ba9e38d3101695fc9052a4c55c` | 1,416 |

The clean dependency-tree digests are godot-cpp
`88627d442827ebb09f0de875e59939216f74a09d2479104f00714b047548620c` and Luau
`fde7ed51588a364dcb97680fbe40e73106b3e4ce4b52d8652c36b1a2ba563391`.
The accepted instrumented engine is SHA256
`02f913eddb7069fe2c35319d74af10525752ab33c08ac2e1f4612e829a96853a`;
its matching adapter is
`876a88f0c969d335bea7ed2d22aca0b9878b877608861dbceabd92a5dc21545a`.

An additional bounded Windows/Linux native check mounts an actual asset PCK
containing only a binary Animation and `.tres.remap`, with no original `.tres`.
The unchanged final adapter registers and returns its plain catalog copy on both
platforms. `CharacterPackedResources.gd`, its runner, PCK bytes and logs are
retained in the same collection. This qualifies packed asset remapping; it does
not claim a complete graphical exported-game qualification.

The independent candidate review was performed once, read-only, and its six
source-backed findings were confirmed and addressed with focused native checks.
The work record distinguishes those source confirmations from actual bypass
reproductions. The incorrect sanitizer-engine rebuild's abort and stack report
are retained rather than discarded; restoring its documented C++ runtime setting
retests the unchanged extension.

These are headless native checks. They do not establish graphical camera/rig
correctness, all custom-rig/controller behavior, collision truth, distributed
anti-cheat or a full animation-security audit. GL-017's independent engine relay
limitation and GL-018's Windows full-native sanitizer limitation remain visible.
The bounded service-departure fixture retains inherited inactive-ENet diagnostics.

## Hosted source revision

Published source commit:
`3bb641a822df288bf48fc6358baec389994b77f0`, verified against the remote branch.
Its native fingerprint exactly matches the local qualified input above.

- [Core run 41032181619](https://github.com/gmoddev/GodotLuau/actions/runs/41032181619):
  Windows and Linux jobs pass. Both artifact ZIP digests, revision identities,
  dependency pins, CTest discovery and all 73 distinct core cases were verified.
- [Native run 41032181621](https://github.com/gmoddev/GodotLuau/actions/runs/41032181621):
  Windows and Linux pass all 82 actors each. Both exact-source fingerprints,
  all 46 harness-file hashes per platform, all 251 Windows/249 Linux recorded
  log hashes, latency statistics and DataStore native evidence are verified.

Core artifact digests are Linux
`1b92794508f93464c8990cfbd3c5f4d7c743c8ee7903e84263faed1d4a2afda7` and Windows
`ae0773a06cc124e0ea08228f5d340369791add0890f1a55d89be6d0ce0ccb3fa`.
Native artifact digests are Linux
`1991249b3102939b919c4035ce95122c03ac6d648bb593f201f3f6dda00df92c` and Windows
`d19e1142134b672b2aedb280e57bfb328eb884a4fd88f4b361339796ecbacb89`.

Artifacts are retained under the collection's `artifacts/hosted/` directory,
alongside API metadata, `VerifyCharacterHosted.py` and
`gl007-hosted-qualification.json` (SHA256
`cb0df203a36177e9bef9698a2b967da5df6c5fc49e4220de9f0f6e63173486d9`).
The verification checks ZIP/revision/discovery/core reports and exact native
source/harness/log evidence, without claiming a downloaded native binary: the
native binary/companion digests are recorded by the CI check in its summary.

The subsequent documentation attestation preserves `3bb641a` and changes no
runtime, harness, workflow or dependency input. Qualification attaches to that
exact published source commit and fingerprint; a documentation-only tip does not
claim a separate runtime execution. Main is verified at `4ea5311`.

Original pre-integration disposition: GL-007 is fixed and qualified within
ADR-006's bounded authority contract on its
unmerged branch. Main, release publication and updater distribution remain unchanged;
the release workflow still has both jobs disabled and RuntimeUpdatesAllowed
still returns false. Character V2 has not started.
