# Character V2 development and qualification record

Status: runtime migration implemented and qualified for the documented
source/headless scope at `d7905dd`, following verified preparation CI at `9ec71c0`.
See the [final qualification record](character-v2-validation.md). Both development
branches remain unmerged; main is `4ea5311`.
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

No production source, dependency, release workflow or updater policy changes were
part of the preparation checkpoint.

## Runtime migration work

Preparation source `9ec71c024b012aada68750ab9bae3349115a165d` passed hosted core
run `41039974670` and native run `41039974656`, each on Windows and Linux.
The GL-007 branch remains at `514d12f`; its source/evidence is preserved.

The first implementation pass introduces the actual Model-derived Character,
its one internal top-level physics body, Character-owned health/movement state,
an actual Animator child, native class identity, and migrated local/remote
factories. Explicit transforms synchronize the body; physics drives the root
under a feedback guard. Finite uniform positive scale is the initial supported
physics transform contract; invalid/sheared/nonuniform poses are rejected.

Source inspection also found that the legacy NPC direction update was inside
the active-camera conditional. The candidate evaluates scripted NPC movement
without requiring a camera. This is a controller correction requiring its own
native check, separate from preserving the walking/jump/acceleration constants.
Observed movement uses post-slide velocity, and collision/state callback delivery
moves outside the physics step. These changes are not qualified by source review.

The native/Luau binding and lifecycle migrations, explicit final API/protocol
contract, focused integration fixtures, candidate measurements and full platform
qualification remain in progress. No pass claim applies to this first candidate.

The first builds caught a Luau void-error-return mismatch and two dangling
property-binding lines after removal of stored-only compatibility fields; these
compile failures were corrected without changing dependency pins or checks.
An early native run passed 3D Local/Listen/Dedicated on both platforms, then a
2D fixture lookup incorrectly read root health instead of Humanoid2D health.
The fixture now selects the unchanged 2D health component explicitly.

The initial dedicated Model fixture exercised native parent/uniform-transform,
camera-component destruction and camera-free NPC walk/jump/fall on both workers
(jump 20, fall approximately -19.75). Its ServerScript incorrectly used
Players.LocalPlayer, which is correctly nil in a Server domain; it now uses the
actual server roster. An attempted immediate GDScript free during a locked native
signal was rejected by Godot; the fixture now uses the production-supported
queued destruction contract and checks deletion after the frame. These failed
preparation runs, warnings and exit diagnostics remain retained, not qualified.

The next Model fixture passes all 38 initial native checks on both platforms.
It covers real Model/Luau identity, pivot/bounds, synchronized parent transforms,
first/third-person controller math, safe camera-component deletion, camera-free
NPC walk/jump/fall, native Part contact identity, finite input, queued health
callback destruction, actual StarterCharacter cloning and reentrant respawn.
It remains headless evidence, not graphical correctness.

Part contact testing exposed retained geometry/material resources at engine
shutdown (GL-024). The candidate makes the inline caches canonical across
translation units and releases all three during existing scene uninitialization.
The Model rerun no longer reports those engine-exit resource diagnostics.

Protocol-3 character regression passes all 16 actors on Linux in the V6 run.
Windows passes the 3D scenarios but fails the 2D final-position admission
comparison, while its native controller measures walk 200, jump -500 and falling
431. The next fixture records the admitted final state and repeats final 2D
samples as the existing 3D fixture already does; the position assertion is not
weakened. This result is not labelled a qualified Windows pass.

Animation migration also finds the source-verified GL-025 completion-signal
shadowing and retained-pointer/cleanup gaps. The candidate uses live completion
signals, ObjectIDs and an exact-clip playback lease. Puppet references likewise
become ObjectID-backed, with bounded departure revalidation so a same-tree
reparent can preserve native Character/Animator identity without retaining a
freed pointer. These changes require focused native qualification.

V9 passes 54 focused Model/Animator checks, all 16 character actors, all 10
animation actors and all 10 authority actors on both Windows/Linux Debug.
The immediate animation cache departure assertion caught an earlier deferred
cleanup discrepancy; cache invalidation is now immediate, with restoration only
after validating the identical reparented ObjectID/session/life. V10 passes 59
focused checks, including passive rig Part collision and manual/automatic respawn
and stale native reset behavior. These are development results, not full matrix
qualification. The next revision adds explicit removal tombstones and actual
owner/observer departure, stale packet and trusted replacement coverage.

V13 passes all 17 character actors on both platforms, including 61 Model checks,
native deletion/CharacterRemoving identity, initial CharacterAutoLoads=false,
and explicit owner/observer removal/tombstone/trusted-replacement checks.
A correction-contract assertion had raced the observer's unreliable snapshot;
it now waits for the expected complete contract with a five-second deadline.
No value/range/authority assertion was weakened.

The first full regression pass found inherited identity fixtures expecting
Instance.new('Model').ClassName == 'Node3D'. Those assertions now require the
intentional genuine Model identity, including nested callback and GC checks.
Other class/lifetime assertions remain. The failed V1/V2 runs are retained.
V3 starts the complete six-core/five-native configuration matrix. The Model
fixture additionally exercises the actual binary place importer on a disposable
legacy Humanoid file and requires explicit migration rejection with unchanged
source bytes.

The first Linux full-native ASan/LSan run rejects an actual candidate leak:
4,080 bytes/43 allocations in a Security Listen client, with allocation stacks
in the new cached contract Dictionary/default construction. Normal functional
PASS did not close this failure. The candidate now stores admitted full pose and
configuration only in the existing native grant structure and materializes a
dictionary at the protocol boundary, removing the duplicate retained builtin
cache. Sanitizer reproduction and the final matrix must be rerun on this source.
Windows/Linux Debug/Release V3 passed their 83 actors before this correction;
those earlier source identities remain separate.

Expanded device tests initially used a StarterCharacter configured for walk 12
while expecting 16, and touch injection depended on an unspecified headless
viewport/emulated mouse state. The fixture now sets its explicit walk-16 control,
an isolated 1152x648 viewport and direct touch input without mouse emulation.
All 72 expanded checks pass on Linux Debug, including native input, reload,
custom visual template and legacy binary import rejection.

The corrected grant cache passes the same three-actor sanitizer Security Listen
reproduction. Full ASan then reaches the new Model fixture and exposes a separate
576-byte/four-allocation importer reset leak (GL-026). Inspection identifies the
pinned generated Dictionary move assignment's missing old-storage destructor;
copy assignment releases it. The importer now uses distinct const-lvalue resets,
without modifying the dependency or sharing report dictionaries. This corrects
the earlier cache diagnosis from a generic lifetime suspicion to the exact
rvalue-assignment mechanism. Original failure stacks remain retained.

The importer workaround passes the complete 72-check Model fixture under the
matching full-native ASan/LSan engine with clean exit. The final fixture repeats
the same rejected legacy import three times (76 total checks) and starts V5
qualification. No sanitizer suppression, leak waiver, dependency change or
assertion removal is used. The native grant/cache correction and importer reset
workaround are separate from GL-017's inherited inactive-ENet diagnostics.

Final lifecycle review finds an initial manual-loading deadlock: suppressing the
automatic root still left local PlayerAdded/readiness and remote admission tied
to Character existence. The follow-up admits protocol-3 Players after transport
polling, independently of initial Character creation. Life zero is the explicit
initial-absence tombstone; a positive Server grant creates the actual life.
Dedicated/editor observer windows remain excluded from local-player admission.
A new real dedicated-server/two-client fixture checks PlayerAdded without a
Character, Server manual LoadCharacter, exact births and both owner/observer roots.

The preceding Windows V5 pipeline stops on GL-005's lifecycle frame-progress
assertion before measurements/products. HTTP implementation is unchanged; the
failure remains retained and requires a fresh check, not an assertion waiver.

The manual-loading fixture now passes all three actors on Windows/Linux Debug.
It starts a dedicated server with automatic loading disabled, admits the first
Player without a Character, then introduces a late second client. It requires
the restored unspawned roster, Server manual loads, actual Player.Character
identity, and one CharacterAdded for each local/remote life. The initial failed
probe caught readiness still behind a root check; that gate now runs before
Character discovery. Initial local PlayerAdded no longer waits for a root, and
explicit early loads dispatch admission before birth without a duplicate tick.
The full native requirement becomes 86 actors; SCons focus becomes 40.

The final public-property check corrects MouseSensitivity's Lua setter still
targeting the former body class rather than the new Character, and validates
CameraMode before integer conversion. The actual Model Lua fixture now checks
valid camera settings plus NaN/Infinity rejection. Physical movement algorithms
and 2D setters remain unchanged. This final binding correction requires fresh
compiled qualification and hosted source identity.

The existing security fixture's PREINIT chat assertion had relied on automatic
readiness being impossible without a local root. The new required root-free
readiness can legitimately admit it before that packet. The fixture now disables
only each client's automatic broadcaster through process_mode; its explicit
SendState still uses actual readiness RPCs, and SceneMultiplayer continues actual
polling/dispatch. The same pre-admission rejection and all existing chat/state
assertions remain. The prior Windows V6 failure is retained, not waived.

## Final disposition

Source/test revision `d7905dd4af5c7a89c9b0f0a005861e9043379be1` passes the complete
V7 matrix: six 73-case core configurations, five 86-actor native configurations
and four 40-actor SCons products. Actual R6 passes all 76 Model checks on each
platform. Process ownership/packaging and companion recovery checks pass with
the documented Windows platform skips. Comparable parent/candidate Release
measurements retain actual costs and jitter; no broad improvement is claimed.

Hosted core run `41139334359` and native run `41139334272` pass all four jobs at
that exact revision. All four downloaded artifacts match published ZIP digests;
native artifacts verify exact source, all 259 log hashes and 52 harness hashes
per platform. Transferred local archives verify all 12,229 Windows and 14,530
Linux manifest entries. The [qualification record](character-v2-validation.md)
and [machine-readable summary](evidence/character-v2-qualification.json) retain
identities, commands, results, measured costs and the graphical/GL-017/GL-018/
GL-020/dependency limits.

The final attestation is documentation-only. Main and GL-007 remain unchanged;
neither development branch is merged. Release publication and updater
distribution remain disabled. Build/dependency caches and original failures are
preserved; all qualifier-owned actor/companion work has completed.
