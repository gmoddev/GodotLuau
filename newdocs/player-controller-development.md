# Scripted Player.Character control

## Scope and current state

This campaign first integrates the qualified Input foundation without changing its
runtime or fixtures. The second slice makes the existing local Player.Character
usable through a Luau controller. Native remains the default. This is not a new
Character body, prediction model, physics solver, VM domain or network protocol.

## Acceptance facts

- The input merge preserves four source commits and the qualified native source
  identity. Non-publishing source/profile/package gates must complete before merge.
- Scripted selection disables native movement and look hardware polling while
  keeping the actual Model, CharacterBody3D, Animator and normal pose admission.
- Only a live Client script may select its native-bound local Player.Character.
  Script lifetime, exact Character identity and existing native transport identity
  own the controller lease. Retained methods from a replaced lease cannot mutate it.
- Direction is finite, horizontal and length bounded; one latest command is
  consumed per physics tick. Native speed, jump, gravity, collision and server
  authority remain authoritative. Missing intent is neutral.
- Death, disconnect, script teardown and focus/GUI suspension clear intent and
  owned capture. Retirement stays dormant Scripted rather than returning to held
  native hardware. New Character lives still begin Native.
- Existing games need no changes. Explicit Native restoration resumes the legacy
  controller. The separate independent KinematicMotor3D example stays supported.
- Actual Luau example, native lifetime and real ENet fixtures establish behavior;
  unrun drafts, compilation and headless simulation are not graphical evidence.

## Initial evidence and investigation

The source implementation is RBXCharacter : RBXModel with one internal
RobloxPlayer : CharacterBody3D. Its native movement, state and animation paths
already drive network samples. LocalControl also identifies the legitimate local
Character for networking and camera ownership; disabling that flag would be wrong.
The new mode instead gates the existing hardware polls and submits bounded intent
to the same physics loop.

InputService already provides native semantic evaluation and frame/physics values.
RunService.Stepped runs before Character's opted-in scripted physics step. No second
input evaluator or general scheduler is introduced.

A controller-specific focus gap needs coverage: focusing a LineEdit while W is
already held does not create a new physical key event. Command admission checks
text focus and the example disables its gameplay context until it can admit fresh
input. The input foundation and default native controller are not silently changed.

## Qualification journal

Implementation and fixtures are in preparation. No controller qualification is
claimed yet. The input foundation's retained qualification remains historical
evidence at its exact source identity. New attempts will be recorded here with
commands, platform, source/binary/fixture identity, outcomes and remaining limits.

### First functional slice on DockerPC

The native bridge, optional mode, semantic Luau example and seven-actor ENet/local
group are implemented. Windows Debug builds from the existing cache. The focused
stock-host local fixture passes Native compatibility, scripted movement/sprint/
jump, remapping, GUI/menu suspension, camera steering, replacement, stale-method/
owner rejection, death/respawn and neutral owner teardown. Expanded synthetic
gamepad, focus-loss and scene-pause assertions also pass.

The Windows Release extension with the existing admitted Release host passes all
six listen/dedicated actors after correcting the example's repeated attachment.
A delayed initial PlayerAdded/CharacterAdded notification can announce the same
already-bound Character. Re-selecting Scripted canceled the held InputService
action. Idempotent attachment preserves the existing live lease; explicit
replacement still acquires a fresh generation. Native binding and protocol
behavior were not changed to accommodate the fixture.

Matching Windows full-native ASan focused execution passes after a concrete new
bridge defect was corrected: the closure diagnostic name used a temporary UTF-8
key buffer. A malformed-argument test produced a symbolized heap-use-after-free
in Luau's diagnostic formatter. The closure now uses a static literal. The
original report and failed attempts remain in durable task storage.

Attempts retained under `C:/Sandbox/Codex/ScriptedCharacter20261106`:

- build-v1: initial task-helper command quoting/unpack failures.
- build-v2: C preprocessor macro rejected commas in an unparenthesized lambda.
- local-v1: example used the wrong MouseButton2 enum namespace.
- suite-release-v1/v3: delayed same-Character attachment canceled held intent.
- suite-release-v2: expanded focus cases ran before the new focus handler was
  compiled. The later Debug and matching ASan focused runs include that handler.
- asan-local-v1: symbolized diagnostic-name use-after-free; corrected focused
  asan-local-v2 exits cleanly with no unexpected report.
- suite-v1 and suite-debug-retirement-v1: Debug extension with the older admitted
  Release host prints PASS then exits 0xC0000374. This mixed profile remains failed;
  source responsibility is unresolved. Stock-host Debug, matched Release and
  matching full-native ASan focused runs exit cleanly. Fresh matching hosted
  Debug qualification is still required.

These are provisional focused results, not final source qualification. Broader
regressions, current-source Release/rendered and hosted checks remain pending.

### Current Release and rendered milestone

Current native source fingerprint is
`2278df21b72670c189c6206a5a49582a50d4cd835448f3f0708629ae0fd7d52e`
(101 files). Release DLL SHA-256 is
`6012efd287e17b9242c758a883f2cd1c052766652854e2a2cd8d27f3fc9a0043`.
`CharacterCampaignWorker.py suite --label release-v5 --configuration Release`
passes all seven actors: 40 local checks, 14/9/9 listen and 13/9/9 dedicated.
They include actual ENet movement admission, server correction, ownership
rejection, death/respawn and disconnect/reconnect. Local checks additionally
verify cancellation of Move/Jump queued earlier in the same physics tick when
the owner destroys itself, and exact single-path camera rotation.

`CharacterCampaignWorker.py graphical --label release-v2 --configuration Release`
passes 43 checks with actual Windows rendering and imported R6 assets. Walking
animation progresses on the existing rig; the [screenshot](evidence/player-controller-walking-2026-11-06.png)
shows the actual Character and playable scene. The first capture had no useful
lighting; image inspection prompted native fixture lighting/reference markers,
and a fresh real rendered capture. The first image and logs remain in durable
storage rather than being treated as sufficient visual evidence.

The [milestone receipt](evidence/player-controller-milestone-2026-11-06.json)
retains actual case inventories and binary/source identity. The retained
[ASan failure](evidence/player-controller-diagnostic-uaf-2026-11-06.log) establishes
the pre-commit diagnostic-name defect; matching focused ASan passes after its
static-name correction. Full matching sanitizer/hosted matrices and affected
regressions are still pending. No final qualification claim is made here.

### Linux authority-baseline follow-up

At implementation `9b1d67e6dc9ba5c77c5d5408115177200c96aa8c`, hosted core CI
passes 85 cases and 29 graph assertions on each platform. DockerPC's affected
Release regressions pass 3 input, 20 Character and 10 animation actors. Its full
matching Windows ASan run passes controls, production registration/reload, all
85 core cases, all 141 native actors and strict completeness checking, with
1,165 instrumented compilation units and no unexpected reports. The new bridge
and all 100 normalized harness/example hashes match the committed implementation.

Hosted [Linux ASan/LSan](https://github.com/gmoddev/GodotLuau/actions/runs/42196754665)
attempt 1 fails the dedicated movement assertion, with no unexpected sanitizer
report. Other groups, including controls, core, Character, animation, HTTP,
DataStore and presentation, pass. The
[retained trace](evidence/player-controller-linux-initial-baseline-failure-2026-11-06.log)
shows Scripted control active and accelerating to 24 units/s at epoch 2, followed
by a trusted correction to epoch 3 and a different starting lane before the sample
was checked. A peer-ready file did not establish a settled initial authority
baseline. This is a failed functional qualification attempt, not a sanitizer pass
for the complete suite and not evidence that movement admission should loosen.

The fixture now reuses CharacterIntegration's existing production
`_character_sync` handshake before starting the controlled movement interval.
Both sides assert the same actual baseline and the server asserts that the
movement interval retains that epoch. The original movement distance/convergence
assertion and all limits/timeouts remain unchanged. No runtime, networking,
dependency or host change is made by this follow-up. DockerPC's Release listen
and dedicated actors pass the revised baseline assertions. Matching Windows ASan
also passes all seven revised controller actors, reusing the already instrumented
binary and detection controls. Fresh hosted qualification remains pending here.

The ordinary Linux native job at
[the same implementation](https://github.com/gmoddev/GodotLuau/actions/runs/42196561908)
times out after five minutes downloading Clang from the Ubuntu mirror, before
any extension build or fixture execution. Failed artifact `13492318470` and its
job log remain retained. Linux sanitizer failure artifact `13493083408` has digest
`63b55d7b9efe1c939f2db3ed8522a0d3950a4ec19c0a4c8a45e11b045e4524b6`.
Neither incomplete/failed job is accepted as passing.

Release publication, updater distribution, dependency pins and the admitted Godot
host remain unchanged. GL-040/041 and documented device, allocation and sanitizer
scope limitations remain independent.

### Published qualification and shutdown handoff

The Input foundation is integrated on `main` at
`9ef59d12dbfbd8b1a695e09c993760b5b458a375`, including normal merge
`f3c575728a7d40b291a3e8f55015f24b5c542396`. Its source branch and four commits
remain retained. All ten [candidate/package gates](https://github.com/gmoddev/GodotLuau/actions/runs/42185879161)
passed at `435bb6917b847c0405a9574cfe5fccfcdb1b9340`; extracted Windows/Linux
Debug/Release packages, binary identities and persistence companion startup
were verified. These package results apply to the Input foundation source.

The controller remains on `codex/scripted-character-control`, unmerged.
Runtime implementation is `9b1d67e6dc9ba5c77c5d5408115177200c96aa8c`;
`0325c3c6d6ce18972313f35906a769ffa86ffd17` changes the movement-baseline
fixture and documentation only. The final documentation commit changes no
qualified runtime, test, dependency or workflow inputs.

Fresh hosted qualification at `0325c3c` is complete:

- [Core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42200598352):
  Windows and Linux each pass 85 core cases and 29 graph assertions.
- [Native CI](https://github.com/gmoddev/GodotLuau/actions/runs/42200598344):
  Windows and Linux each pass all 141 actors, including all seven actual ENet
  controller actors and ten adversarial/legitimate animation actors.
- [Full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/42200618819):
  Windows ASan and Linux ASan/LSan pass controls, registration/reload, 85 core
  cases and 141 native actors each, with 1,165 instrumented compilation units
  and no unexpected sanitizer reports. Linux leak detection remains enabled.

Downloaded artifacts confirm the source fingerprint above, actual controller
case counts `40 / 16 / 10 / 10 / 15 / 10 / 10`, zero failed controller assertions,
and the same 100 harness/example hashes across current Windows native,
Windows sanitizer and Linux native evidence. The
[final receipt](evidence/player-controller-qualification-2026-11-06.json)
records artifact IDs/digests, binary hashes, local results and retained failures.
Earlier failed attempts remain failed; fresh results do not erase them.

DockerPC additionally passed Windows Release affected regressions, the revised
focused ASan controller group, full matching Windows ASan, and 43 actual
rendered checks with the retained walking screenshot. Classification:
**QUALIFIED within the documented supported profiles**. Physical-device and
OS-capture testing, Linux graphical validation, Windows leak detection,
older-glibc/pristine-consumer portability, broader allocation profiling, and
new controller candidate packages remain outside this claim. The mixed local
Debug extension/older Release host shutdown failure remains unqualified and
unresolved; matching profiles pass.

At shutdown handoff, DockerPC has no task-owned build/test processes remaining;
13,657,382,912 bytes are free on C:. Caches and durable historical evidence are
preserved. No further local processes need to run. The next action is review of
the published controller branch before any separately authorized integration.
`main` remains at the Input integration revision. Releases, updater distribution,
upstream, admitted hosts and dependency pins remain unchanged.
