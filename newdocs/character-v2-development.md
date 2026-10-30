# Character V2 preparation record

Status: preparation only on `runtime/character-v2-model`. Production source is
unchanged from the qualified GL-007 parent. No Character V2 runtime qualification
is claimed. Both development branches remain unmerged; main is `4ea5311`.
Release publication and updater distribution remain disabled.

## Gate and source identity

GL-007 source `3bb641a822df288bf48fc6358baec389994b77f0` passed the complete
[qualification](character-authority-validation.md), including the animation
health bypass regressions, all four hosted jobs and verified downloaded artifacts.
The stacked parent is documentation attestation
`514d12f1bf1add924214492248a459e0763d4ca0`; the attestation changes no production
or qualification input. Native source fingerprint remains
`20ecbfcbb11cbdbef85480c41ec3cd4e1705bba210cb3ab290c84eab518b329a`.

This checkpoint preserves the parent and its evidence. The production migration
described in [ADR-007](adr-007-model-character.md) is subsequent work, requiring
its own API/protocol contract and qualification before it can be called complete.

## Executed production baseline

`tests/runtime/RunCharacterBenchmarks.py` prepares an isolated project and uses
the actual native Workspace/Players factories through `CharacterBenchmarks.gd`.
It imports unchanged R6 source assets in an asset-only project, requires exit 0,
and copies only those fixture import products into the runtime project. It never
regenerates repository assets. Windows child processes use the existing hidden
process runner and error UI suppression; import/runtime waits are bounded.

Both workers ran official Godot 4.7.1 against their qualified CMake Release
adapter. The [raw measurements and file identities](evidence/character-v2-baseline.json)
retain the exact adapter and log hashes. The accepted output is
`character-v2-baseline-r6-v3`: Windows under
`C:\Sandbox\Codex\Artifacts\GodotLuau`, Linux under `/work/results` in the existing
qualification container (`/opt/codex/godotluau/results` on its host).

Reproduce with matching platform paths and a fresh output directory:

```text
python tests/runtime/RunCharacterBenchmarks.py --godot <official-4.7.1> --extension <qualified-release-adapter> --r6-assets <unchanged-r6-source-directory> --output <new-isolated-directory>
```

Creation and respawn each discard five warmups and retain 30 samples. Direct
creation frees the previous root before rebuilding; respawn uses the production
Players lifecycle with its deferred cleanup. These are distinct workloads.
The repeated-lifecycle sample performs 100 respawns and ten settling frames.
The physics workload uses 1 and 16 factory-created characters, a static floor,
the existing native scripted-movement request, 90 warmup ticks and 120 measured
ticks. Measurements use Godot's global frame monitors and include engine work.

| Measurement | Windows | Linux |
| --- | --- | --- |
| R6 creation median / P95, microseconds | 6,986 / 9,011 | 2,380 / 2,739 |
| Production respawn median / P95, microseconds | 389 / 488 | 330 / 349 |
| Nodes in one character hierarchy | 21 | 21 |
| Object count delta after 100 respawns | 0 | 0 |
| Static memory delta after 100 respawns, bytes | 4 | 4 |
| One-character physics median / P95, milliseconds | 0.249 / 9.195 | 0.246 / 0.448 |
| Sixteen-character physics median / P95, milliseconds | 0.665 / 0.712 | 0.500 / 0.547 |

These are single trials, not performance thresholds or evidence of an
improvement. The Windows one-character P95 shows substantial scheduling
variation. A candidate comparison needs matching builds, assets and workloads,
with additional trials if conclusions depend on that variation. Stable object
count in this bounded sample is not a universal leak-freedom guarantee.

## Preparation failures and limits

Earlier `character-v2-baseline-r6` and `character-v2-baseline-r6-v2` runs imported
the entire native fixture project. First import exited 1 on both platforms;
the retained stderr contained asset warnings without an explanatory script
error. A subsequent cached import exited 0. The cause of that first native-editor
import exit remains unresolved. Those runs are not accepted measurements.
The isolated asset-only import exited 0 and supplies the accepted R6 baseline.
It does not establish that the earlier editor behavior is fixed.

Earlier fallback-only factory samples are retained separately and are not mixed
with these R6 measurements. No candidate, graphical camera/rig, networking cost
or remote-puppet performance result is claimed. The new fixture is preparation
for implementation, not a substitute for the required full native regression,
sanitizer, production-build and hosted matrices.

## Next implementation acceptance facts

- A real `RBXCharacter : RBXModel` root in Player.Character, one synchronized
  physics authority and a distinct direct HumanoidRootPart proxy.
- Character-owned health/configuration/lifecycle and an actual Animator, with
  explicit removal/migration of the separate 3D Humanoid API; 2D stays intact.
- GL-007/GL-020 authority, animation admission, lifetime and session guarantees
  retained through local/listen/dedicated, stale-packet and destruction cases.
- Model transforms, parent/reparent behavior, physics, collision, rigs and player
  lifecycle verified through production native implementations.
- A documented final API and any exact protocol compatibility change, full
  Windows/Linux qualification, comparable candidate measurements, and a separate
  graphical observation or explicit graphical-access limitation.

No production source, dependency, release workflow or updater policy changes are
part of this preparation checkpoint.
