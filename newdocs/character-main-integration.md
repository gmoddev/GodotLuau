# GL-007 and Character V2 main integration

Date: 2026-10-31 UTC. Scope: integrate the two qualified branches into the user's
fork by sequential normal merges. Both source branches and all original source,
test and qualification commits are retained. No upstream operation is performed.

## Revisions and source identity

| Stage | First parent | Retained second parent | Normal merge |
| --- | --- | --- | --- |
| GL-007 | `4ea53113a98961a64347c672890f65bf9b5c8a54` | `514d12f1bf1add924214492248a459e0763d4ca0` | `4d4694e8ea5f05120ded9b116bcd06a2c95e4ead` |
| Character V2 | `4d4694e8ea5f05120ded9b116bcd06a2c95e4ead` | `46f65e0414bbfeecbe535e47236e1a2ccd4c7b75` | `1c3176c0d9331dc1fa6849b98f8ed8e90e59c110` |

Both merge trees exactly equal their second-parent trees (`git diff --exit-code`).
GL-007's merge base is the stated original main. Character V2's merge base with
the integrated GL-007 main is `514d12f`, so the second merge preserves the existing
GL-007 commits rather than replaying them. There are no conflict resolutions,
squashes, rebases, cherry-picks or source corrections in these integrations.
Each merge was pushed to `origin/main` and verified through `git ls-remote`.
The final follow-up updates only documentation/evidence; runtime/test inputs
remain those of the second merge.

The recomputed native fingerprints match both the implementation commits and
their documentation attestation tips:

| Source | Implementation | Retained tip | LF-normalized native files | SHA256 |
| --- | --- | --- | ---: | --- |
| GL-007 | `3bb641a822df288bf48fc6358baec389994b77f0` | `514d12f` | 87 | `20ecbfcbb11cbdbef85480c41ec3cd4e1705bba210cb3ab290c84eab518b329a` |
| Character V2 | `d7905dd4af5c7a89c9b0f0a005861e9043379be1` | `46f65e0` | 88 | `e64dffcbd69a806aedadcf98dc97507a3a17eaff88ced4a38d9fbd7d4ac427db` |

Only `newdocs/` differs between each qualified implementation and its retained
tip. Complete merge-tree equality also preserves the default scripts, generated
declarations, build files, tests and asset inputs. Dependency pins remain
godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

## Qualification gate and implementation checks

During integration, the historical GL-007 core/native runs
`41032181619`/`41032181621` and Character V2 runs
`41139334359`/`41139334272` were checked against their exact source revisions.
All eight artifact ZIP digests match GitHub and the existing qualification
records. Core discovery and all 73 distinct completed cases verify; native
fingerprints, every declared harness/log hash, actor exits, engine provenance,
latency evidence and DataStore interruption evidence verify. This rechecks
existing evidence; it is not another execution of the original local matrix.

Stage 2 began only after both Stage 1 core jobs, both native jobs and all four
downloaded artifacts passed fresh verification. The Stage 1 actor count is 82,
as enforced by its qualified source. Character V2 raises it to 86.

Source inspection confirms the established contracts:

- [GL-007 native health setters](../src/characters/rbx_character.h) reject Client
  execution and invalid values; death latches before callbacks. Native server
  health is independent of submitted pose/presentation values.
- [Network admission](../src/services/roblox_network.h) derives transport identity,
  checks receiver role/session, epoch/sequence freshness and finite bounded
  movement before mutation/relay. Legacy state/animation handlers remain inert.
  Startup catalog admission and checked presentation copies preserve the
  animation-health boundary and trusted gameplay timeline ownership.
- `RBXCharacter : RBXModel` is actual native inheritance, with Model registered
  before Character. The removed 3D Humanoid is not registered or simulated by a
  compatibility wrapper. One internal top-level physics body, the direct
  HumanoidRootPart proxy, visual rig and actual Animator share one Character life.
- [Player lifecycle](../src/services/roblox_services.h) and network lifecycle use
  ObjectIDs and callback revalidation. Reentrant loading coalesces; removal binds
  epoch/life tombstones before deferred delivery. Connected Players survive
  Character absence, including initial manual loading and late joining.
- [Animator/track ownership](../src/gameplay/roblox_animation.h) binds ObjectIDs
  and the exact playback clip. Retirement releases callback references and
  preserves newer trusted playback. Native Part cache cleanup and the bounded
  importer Dictionary workaround remain the qualified GL-024/025/026 changes.

The execution-domain engine, HTTP manager, confined storage/DataStore backends
and 2D implementation are unchanged between the qualified GL-007 and V2 tips.
GL-019's cache/scheduler paths and GL-022 subscription identities retain their
owners. Fresh core/native suites below exercise GL-003/004/005/009/020/022 as
well as Character authority. No acceptance assertion or fixture is weakened.

## Fresh focused integration before the second push

Linux Debug ran on the existing `linuxbox` qualification container with two
build jobs, headless child processes, captured logs and explicit timeouts.
All 149 local production/build/runtime-harness/packaging inputs matched the
qualified Character V2 files before and after execution. The worker uses its
existing source overlay and incremental cache; its historical Git HEAD is not
claimed as the merge revision. Three worker workflow YAML files differ from the
qualified tip and are not consumed by these commands; hosted workflow identity
is checked separately in Git and fresh CI.

The matching cached adapter passed 73 core cases and 48 fresh native actors:
lifecycle 8, network authority 10, animation 10 and Character 20. The actual Model
fixture reports 76 checks; all three manual-loading actors execute and pass.
This covers genuine inheritance/pivots/bounds, synchronized body/root transforms,
native input/physics, death/respawn/reentrant destruction, completion and retained
signals, server health/corrections, wrong/stale traffic, removal tombstones,
manual initial birth, unspawned-player late join and owner/observer replacement.

Principal commands, with the verified source overlay and matching official engine:

```text
cmake --build /work/builds/linux-debug --target ExecutionDomainTests GodotLuauAdapter DatastoreBackendProbe --parallel 2
ctest --test-dir /work/builds/linux-debug -R ^ExecutionDomains$ --output-junit <fresh>/core.xml --test-output-size-passed 65536 --test-output-size-failed 65536 --output-on-failure
python3 tests/runtime/CheckCoreCI.py report <fresh>/core.xml
python3 tests/runtime/RunQualification.py --godot <verified-4.7.1> --extension <matching-adapter> --output <fresh>/regression --teardown --coordinated-close --timeout 60
python3 tests/runtime/RunQualification.py --godot <verified-4.7.1> --extension <matching-adapter> --output <fresh>/security --security --timeout 60
python3 tests/runtime/RunQualification.py --godot <verified-4.7.1> --extension <matching-adapter> --output <fresh>/animation --animation --timeout 60
python3 tests/runtime/RunQualification.py --godot <verified-4.7.1> --extension <matching-adapter> --output <fresh>/characters --characters --timeout 60
```

Worker output: `/opt/codex/godotluau/results/character-main-integration-20261031`.
The transferred diagnostic/fixture ZIP has 614 entries and SHA256
`fff3c5a19b7a4d2034c3889d7daf97e2167e8abf9d9c4940e8d4d038ce0f241e`.
Its archive digest and all 121 declared log hashes verify. The local retained
collection is `.runtime-tests/CharacterIntegration20261031/`, ignored by Git;
it also contains all downloaded hosted ZIPs and verification records.

## Fresh hosted main CI

Observation is bounded to 25 minutes per stage. Only the read-only core/native
workflows run on the pushes; no release workflow is dispatched.

| Stage / revision | Core, Windows and Linux | Native, Windows and Linux |
| --- | --- | --- |
| GL-007 `4d4694e` | [41171080423](https://github.com/gmoddev/GodotLuau/actions/runs/41171080423): pass, 73 each | [41171080300](https://github.com/gmoddev/GodotLuau/actions/runs/41171080300): pass, 82 each |
| Character V2 `1c3176c` | [41172545145](https://github.com/gmoddev/GodotLuau/actions/runs/41172545145): pass, 73 each | [41172545109](https://github.com/gmoddev/GodotLuau/actions/runs/41172545109): pass, 86 each |

Stage 1 artifacts verify exact revision/fingerprint, dependency pins, 73 distinct
core completions and all native actor exits. Harness/log hashes, real delayed
ENet forwarding and DataStore's four fault stages, four kill stages and 40
independent increments verify. No power-loss test is claimed.

All four Stage 2 artifacts verify against GitHub's ZIP digests and the exact
merge revision. Both native artifacts contain the matching 88-file fingerprint,
52 normalized harness hashes and 260 declared log hashes, all verified. Each
platform executes all 20 Character actors: the original 16 authority/network
actors, `character-model` with 76 actual checks, and the three manual-loading
actors. Every Character actor's required PASS marker is verified in its log;
no fixture is inferred from a workflow name or aggregate count. GL-022's actual
native markers, delayed ENet evidence and complete DataStore native recovery
evidence are also retained. All eight fresh jobs pass within the observation
windows; no CI result remains pending.

The [machine-readable record](evidence/character-main-integration-2026-10-31.json)
records final results and exact artifact identities. The final documentation
follow-up changes no runtime, harness, workflow or dependency input.

## Compatibility, preservation and remaining limits

[ADR-006](adr-006-character-authority.md), [ADR-007](adr-007-model-character.md)
and the [API migration](character-v2-api.md) remain the contracts. Protocol 3
requires matching builds; incompatible readiness/malformed grants fail closed.
3D content must migrate explicitly from a Humanoid child to Character properties
and an actual Animator. The separate 2D controller/Humanoid2D contract remains.
There is no automatic rewrite of user content or new replication system.

The original Debug/Release, core ASan, matching Linux full-native ASan/LSan,
four SCons products and actual R6 qualification remain attached to unchanged
source. Fresh integration checks are Debug/headless and do not claim a repeated
product/sanitizer matrix. GL-017's independent engine relay edge, GL-018's Windows
full-native sanitizer-host gap and GL-020's broader animation-security gate remain
open. Graphical camera/animation appearance, physical-device ergonomics, arbitrary
custom content, server collision truth and production anti-cheat remain unqualified.
GL-026's dependency-wide assignment follow-up remains open.

The release workflow retains manual-only triggering, both jobs disabled and
read-only permissions. RuntimeUpdatesAllowed remains literal false. No updater
distribution or production release channel is enabled. Both source branches are
retained. Work stops after these integrations; GL-023 and further development are
outside this change.
