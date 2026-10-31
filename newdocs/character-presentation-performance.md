# Character V2 graphical and performance qualification

Work starts at main `c562ba8b74226a15ffb5e18e6547cfccebac94dd` on
`perf/character-v2-graphical-qualification`. Main, dependency pins, release and
updater settings remain unchanged. ADR-006/007 and the existing Model/physics,
health, animation, callback, ObjectID and service contracts remain requirements.
This work adds gameplay evidence and measures bounded optimizations; it does
not change Character ownership or authority.

## Environment and acceptance

All local builds, tests, benchmarks and rendering execute on **DockerPC**
(`HostPC`, Ryzen 9 5900X, GTX 1650 SUPER). MainPC is a fallback only; no fallback
has been required. No LinuxBox or other testing worker is used. SSH's existing
MiniVPS route is transport to DockerPC, not a testing environment.

Windows reuses Godot 4.7.1, controlled Python 3.12.6, MSVC 14.51, CMake 3.31.10
and Debug/Release/core-ASan build caches. A new task-owned Docker Desktop Linux
container on that same DockerPC reuses the existing Clang 19/CMake 3.31.10 image;
its build is limited to two CPUs and 6 GiB. It uses existing pinned dependency
sources and a separately verified official Godot Linux tool where necessary.
Graphical evidence requires the Windows display/OpenGL renderer and actual GPU
readback; Linux/headless assertions are not graphical qualification.

Acceptance requires rendered default/custom rigs, camera/input/physics/animation/
life/transport assertions, reproducible captures, repeated comparable performance
trials, unchanged correctness/authority regressions, verified hosted execution and
honest platform/measurement limits. No optimization is accepted solely because
it looks cheaper in source or wins one trial.

## Controlled baseline and retained attempts

The starting 89-file native fingerprint is
`71c663fbb978b34559a00a92b5315a8d6ff637f6db09ec04867e6cf5ddd8149f`
(LF normalized). Immutable copies of the qualified Windows Debug/Release DLLs
and companions are retained at `C:/Sandbox/Codex/CharacterGraphics/baseline`;
`baseline.json` records hashes independently of the worker's old Git HEAD.
The GL-007 historical comparator is retained separately. The original
[Character V2 qualification](character-v2-validation.md) remains unchanged.

A real-render probe passes pixel readback at 960×540 on NVIDIA OpenGL 3.3
(driver 591.86), with Windows/gl_compatibility/opengl3. Task windows run outside
the interactive user's session, offscreen, with no-focus behavior and bounded
process jobs. No editor or interactive user's game is restarted.

The initial R6 fixture used an unbound diagnostic method, and its animation
progress check assumed seven physics ticks meant seven animation process frames.
The retained V3 diagnostic proves playback started and progressed, but shader
startup can cause physics catch-up without equivalent process updates. The
corrected check waits on actual visual progress with a deadline and requires
greater displacement; it is not an assertion waiver. V4 passes rendered R6 and
custom rigs (65 assertions each) and three real listen actors (18 each). Its
dedicated case incorrectly started the already auto-starting `--glserver` twice;
the bounded failure/timeout remains. V5 observes native dedicated startup,
requires no local Character on the observer, and passes three rendered actors.
Final assertions add explicit rotation and independently displaced-body repair.

The first candidate headless input attempts failed mouse/touch assertions.
The unchanged candidate passes after establishing the viewport extent after
startup and using the native first-person mouse path on the dummy display.
Rendered cases retain actual third-person captured RMB input. The final fixture
also checks controller A and a synthetic click on the real mobile JumpButton;
its focused headless diagnostic passes. These simulation controls do not replace
rendered input evidence or establish physical-device ergonomics.

Raw outputs remain under `C:/Sandbox/Codex/CharacterGraphics`, including all
failed fixture attempts. The first Linux configure omitted the explicit C
compiler name; its failed log is retained before the corrected Clang-19 retry.

## Profiling and candidate hypothesis

Three initial 16-character trials separate all work, physics-only, animation-only
and inactive roots. Built-in Performance monitor snapshots are retained as a
historical comparison, but some monitors update only once per second, as
[Godot documents](https://docs.godotengine.org/en/latest/classes/class_performance.html).
They cannot establish 240 independent frame observations merely by polling them
240 times. The initial coarse run remains at `baseline-profile-v1`.

`CharacterDispatchProbe.gd` brackets actual SceneTree node dispatch using ordered
front/tail callbacks. The improved three-trial baseline (`baseline-profile-v2`)
has median physics dispatch 0.410 ms for 16 walking R6 roots, 0.401 ms with
procedural animation disabled, and about 0.050 ms with physics disabled. Process
dispatch medians are 0.047 ms with animation and 0.016 ms inactive. These elapsed
windows include native controller/animation and dispatch/harness cost; they
exclude engine work outside node dispatch and are not OS-thread CPU accounting.
Raw independent dispatch and process-frame observations retain mean/median/p95/p99.

Source inspection identifies redundant synchronization of an already validated
root/body pose and reflection calls on the known internal RobloxPlayer type.
The candidate keeps ObjectID/type/parent/deletion resolution and full pose
validation on every use, skips only equal live transform writes, preserves repair
of an independently moved body, and uses direct native camera queries. It adds no
cross-frame pointer or hierarchy cache. Correctness and repeated measurements must
qualify it before acceptance. Broader hierarchy/puppet/animation caching is not
introduced merely to reduce call counts.

The **rejected first candidate** used `Pose == LastPose` as a shortcut around
validation. Source review found that physics also assigns LastPose without first
validating it, so that shortcut could suppress existing rejection/diagnostics.
It is not accepted, regardless of measured speed. Its products, successful
functional runs and negative measurements remain separate from the final
candidate, which retains validation on every call.

Five alternating Windows Release pairs of that rejected candidate at 120 FPS
reduce the 16-character median dispatch from 0.404 to 0.382 ms and the
32-character median from 0.799 to 0.753 ms. Every pair improves at 1/16/32/64.
This is a scoped dispatch improvement, not a demonstrated frame-rate or total
CPU improvement. Whole-actor CPU (including startup, lifecycle and frame pacing)
instead rises from a median 5.0625 to 5.53125 CPU-seconds in the roughly 37-second
actor. That negative result is retained rather than discarded as noise.

A second five-pair 16-character comparison at a 60 FPS cap still improves
physics dispatch in all five pairs (median 0.398 to 0.385 ms). Whole-actor CPU
is mixed: baseline 2.140625/2.21875/1.84375/2.421875/2.46875 seconds and candidate
2.296875/1.890625/2.59375/1.875/2.125 seconds. Its median decreases, but only three
pairs decrease. Thus this diagnostic does not establish the cause of the
120-FPS CPU increase, nor a general process-CPU benefit. CPU attribution outside
node dispatch and cap/engine scheduling sensitivity remain measurement limits.

## Qualification status

Rendered review identifies GL-028: the old cache can retain first-person dither
speckles. The stronger exact-endpoint test reproduces on the immutable main
Release DLL: R6 retains dissolve `0.999400854110718` on all six meshes, custom
retains `0.999045968055725`; both fail only the new endpoint assertion after a
bounded settling interval. Captures/logs remain in `baseline-fade-r6` and
`baseline-fade-custom`. The fix snaps only near-endpoint values to 0/1 and never
lets the 0.002 dirty-update tolerance suppress an endpoint transition. Interior
fade behavior, shader bytes, material ownership and native ObjectID checks stay
unchanged. Final qualification includes the new assertion and both custom and
default rigs in real listen/dedicated multiplayer (fourteen presentation actors,
110 native total with the performance fixture).

The first expanded custom multiplayer fixture incorrectly expected the local
`Character/` container on remote puppets. Source confirms their established
container is `Visual/`; the failed rendered run is preserved separately. The
corrected assertion uses that exact remote path and additionally requires the
custom BoxMesh geometry, so a default R6 fallback cannot satisfy it. No runtime
factory/container contract is changed.

Candidate builds, complete regression runs, repeated comparisons and hosted CI
are in progress. No pending execution is claimed as passing. Final results,
exact source identities, screenshots and evidence digests will be recorded here.

The validation-preserving implementation is `a09f10d55dcc212dd28e1c3f0a60f341689839c3`,
native fingerprint `aec51cc5e25828b32990e85a297fc769f6c94da12347671ff9a1d62527c79ed2`
(89 files). Its Windows Debug/Release and Linux Release adapters build, and its
eight-actor Windows Release graphical run passes. Further runs remain pending.
Hosted CI will require 80 core cases and 104 native actors per platform: the
original 95, eight presentation actors, and one performance fixture execution
actor. The last is an execution check, not a single-trial speed gate.

The rejected first Windows candidate Debug and Release pass 80 core cases and 103 native actors
each, including eight new headless presentation actors; core ASan passes 80.
The newer rendered/assertion snapshots are recorded separately at final
qualification. The DockerPC Linux container has built both the retained GL-007
comparator and starting V2 source and passed the 80-case starting core suite.
That first Linux adapter also builds successfully. The validation-preserving
candidate requires fresh builds, comparisons and native suites. Benchmark phases are
serialized after task builds and functional suites stop, rather than measuring
against a concurrently compiling task.

Native allocation-event counts are not exposed by the available engine API;
the harness records static allocated bytes and live objects/nodes/resources,
including 100 respawns, without treating object count as allocator events.
Physical input-device ergonomics, arbitrary imported content, production scale,
GL-017/018, broader GL-020 adversarial qualification and distribution remain
separate limitations. No full-native Windows sanitizer result is invented.
