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

### Final rendered gameplay and repeated rendering measurements

Implementation `2bd43741f82fd5308e01e5bb88462e17ae256fb7` retains the bounded
physics changes from `a09f10d` and fixes GL-028. Qualification fixtures are
`6b6a8a29803d47687090b341019155fc770a81b6`. The final 89-file native fingerprint is
`559961ab22bc22ec349b8bb80cc4dd0fdc4cc4a2b180c78d37f06a59a4d401b0`.

Windows **Debug and Release each pass fourteen actual NVIDIA/OpenGL actors,
454 assertions and 48 captured PNGs**. Both default R6 and the box-based custom
StarterCharacter run single-player input/camera/physics/animation/lifecycle
checks and real local/remote listen/dedicated checks. Each owned rig reaches six
exact `dissolve=1.0` uniforms, then restores its original third-person materials.
The strict endpoint test fails on unchanged main as recorded below. Twenty
processed respawns per rig/configuration leave zero live-object and static-byte
growth after warmup. This is bounded evidence, not a universal leak guarantee.

Three alternating graphical Release pairs use the same 960×540 scene, GPU,
driver, assets and 120 FPS cap. All pairs improve physics dispatch at every count:

| R6 roots | Baseline median, ms | Candidate median, ms | Median paired change | Candidate mean / p95 / p99, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.053 | 0.049 | -7.55% | 0.0514 / 0.070 / 0.100 |
| 16 | 0.413 | 0.396 | -5.15% | 0.4015 / 0.483 / 0.540 |
| 32 | 0.802 | 0.774 | -3.49% | 0.7722 / 0.900 / 1.048 |
| 64 | 1.611 | 1.577 | -4.03% | 1.5659 / 1.884 / 2.031 |

Each summary cell is the median of the respective trial statistics. A paired
percentage is calculated within each pair before taking its median; it need not
equal the ratio of the two summary medians. The descriptive bootstrap intervals
refer only to these trials, not independent host populations.

Process-frame mean stays about 8.333 ms at the cap; no FPS gain is claimed.
At 64 roots, candidate frame median/p95/p99 are 9.691/10.607/10.872 ms versus
9.534/10.635/10.911 ms. Process dispatch and rendering are mixed: render-CPU
median rises from 1.480 to 1.663 ms at 64 roots, while render-GPU median is nearly
unchanged (2.045 to 2.054 ms). Raw mean/median/p95/p99 render observations are
retained, without attributing a renderer improvement to these changes.
[RenderingServer's measured CPU/GPU values are milliseconds](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).
Whole-actor CPU decreases in all three pairs: baseline 12.0625/11.234375/11.953125
seconds, candidate 11.890625/10.796875/11.65625. These include startup, rendering,
factory/lifecycle work, scripting harness and frame pacing; dispatch timing is
not isolated OS-thread CPU.

Native factory-call creation medians are 7208→7146 microseconds and production
respawn-call medians 480→462 microseconds in this rendered comparison. No general
creation/respawn speedup is established. Their calls exclude render-ready and
network-ready latency. The separate 100-respawn frozen-body monitor has zero
object growth but **+3048 static bytes in both products**, including retained
measurement dictionaries; it is not a zero-byte-growth assertion or allocation
event count. The processed graphical lifecycle check above exercises fade/UI
initialization as well.

Performance roots are real factory R6 Characters in separate inactive Workspace
containers with a common floor and observer camera. Their local body camera/UI
process is disabled and native NPC movement drives the controllers. They measure
Character dispatch and procedural animation, not 64 active network players or an
entire production game. Camera/input/UI behavior is qualified separately by the
rendered gameplay fixtures. Full raw samples distinguish engine monitors, native
dispatch, harness intervals, rendering and whole-process accounting.

### Final repeated headless comparisons

Five alternating Release pairs per OS use the same starting-main and final
products on DockerPC, with 240 physics-window samples and a 120 FPS process cap.
Windows physics dispatch improves in all five pairs at every count. Linux
improves in all five at 16/64 and four of five at 1/32; the latter descriptive
intervals include a regression, so those counts do not establish a consistent
Linux improvement.

| OS | Roots | Baseline / candidate median, ms | Median paired change | Candidate mean / p95 / p99, ms |
| --- | ---: | ---: | ---: | ---: |
| Windows | 1 | 0.052 / 0.048 | -7.69% | 0.0493 / 0.071 / 0.096 |
| Windows | 16 | 0.401 / 0.389 | -3.23% | 0.3819 / 0.451 / 0.535 |
| Windows | 32 | 0.793 / 0.755 | -4.79% | 0.7521 / 0.882 / 1.044 |
| Windows | 64 | 1.595 / 1.536 | -3.64% | 1.5142 / 1.792 / 1.937 |
| Linux | 1 | 0.043 / 0.041 | -2.38% | 0.0465 / 0.080 / 0.103 |
| Linux | 16 | 0.307 / 0.292 | -4.90% | 0.3057 / 0.420 / 0.521 |
| Linux | 32 | 0.565 / 0.537 | -5.13% | 0.5666 / 0.770 / 0.822 |
| Linux | 64 | 1.050 / 0.999 | -4.69% | 1.0669 / 1.483 / 1.605 |

These are elapsed node-dispatch observations. Linux's 16-root p99 increases
0.512→0.521 ms despite its lower median; process/renderer/tail behavior is not
universally improved. Windows whole-actor CPU is mixed (three increases, two
decreases; both medians 5.421875 CPU-seconds). Linux decreases in four of five
pairs (median 2.113807→2.094837 CPU-seconds). The first rejected candidate's
120-FPS CPU increase remains above and is not substituted for final results.

Windows native creation median increases 6425→6602 microseconds, while respawn
is 451→448 (p99 569→648). Linux creation increases 3528→3634, while respawn is
257→226 (p99 417→345). Together with the rendering trials, these support a
bounded physics-dispatch optimization and no general creation/respawn latency
claim. Frame means remain near the cap. The 100-respawn monitor again has zero
object delta and +3048 static bytes in both products in every trial.

Three same-DockerPC Linux historical GL-007/V2 pairs retain the earlier R6
factory/respawn/animation/coarse-monitor workload. Sixteen-root physics medians
are GL-007 0.953/0.746/0.899 ms and V2 0.836/0.868/0.764 ms: one pair regresses,
two improve. The previously reported Linux slowdown is not consistently
reproduced on this permitted hardware. Those 120 polled monitor snapshots are
coarse, not independent frames; they cannot establish a high-confidence tail
regression or its resolution. Historical respawn medians are 193/201/232 versus
213/220/209 microseconds. This does not reuse measurements from LinuxBox.

### Network-host investigation

Five alternating pairs per OS run three actual ENet actors, imported R6 rigs,
240 physics-window samples after warmup and a 120 FPS cap. These include native
networking, Character/controller/animation and fixture dispatch; they do not
isolate network CPU.

| Host / metric | Baseline median / p95 / p99, ms | Candidate median / p95 / p99, ms |
| --- | ---: | ---: |
| Windows physics dispatch | 0.059 / 0.074 / 0.106 | 0.055 / 0.065 / 0.091 |
| Windows process dispatch | 0.047 / 0.116 / 0.276 | 0.050 / 0.113 / 0.227 |
| Linux physics dispatch | 0.043 / 0.065 / 0.090 | 0.045 / 0.076 / 0.101 |
| Linux process dispatch | 0.036 / 0.096 / 0.134 | 0.041 / 0.105 / 0.142 |

The Linux host physics pairs are +104.88%, -4.88%, -4.35%, -8.16%, +11.63%;
the first outlier remains in the evidence.
Process has three increases, one tie and one decrease. Thus the isolated
Character-dispatch benefit does **not** establish a general network-host win;
Linux's adverse median/tail observations and Windows' increased process median
remain explicit tradeoffs/measurement limitations. No network, authority or
puppet ownership redesign is bundled to erase them. Host mean frame interval
stays near 8.333 ms; all client roles and raw mean/median/p95/p99 observations
remain in the evidence.

Three additional historical GL-007/V2 pairs use this same capped network fixture
on each OS. Windows host physics median rises 0.044→0.059 ms and process
0.048→0.051; Linux physics rises 0.039→0.044 and process 0.039→0.040. This
reproduces bounded per-host Character V2 overhead relative to GL-007, while
preserving V2's required Model, lifetime and protocol contracts. It does not
justify replacing them or comparing these capped independent windows directly
to earlier uncapped/coarse monitor totals.

### Development counterevidence and final verification

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

The next custom run samples a host at Y=126–161 with a nearly constant airborne
leg pose (about 0.35002 radians), while the other remotes animate normally. The
walking-cycle premise was not established. The fixture now requires actual
owner grounding before the shared walking observation and records bounded
position/velocity/platform-velocity traces while waiting. The six-actor rendered
custom listen/dedicated diagnostic passes with the original progress threshold.
The earlier startup trajectory is retained as an unresolved spawn/contact
observation, not silently called a fixed physics defect or a stuck Animator.

Final runtime implementation: `2bd43741f82fd5308e01e5bb88462e17ae256fb7`;
fixture qualification revision: `6b6a8a29803d47687090b341019155fc770a81b6`.
The 89-file LF-normalized native fingerprint is
`559961ab22bc22ec349b8bb80cc4dd0fdc4cc4a2b180c78d37f06a59a4d401b0`.
Windows Debug/Release and Linux Release adapters build. Final actual NVIDIA
Debug and Release runs each pass fourteen actors, 454 assertions and 48 captures.
All final repeated Windows, Linux-on-DockerPC and GPU comparisons above completed.
Benchmark phases are serialized after task builds and functional suites stop.

Hosted qualification at that exact fixture revision succeeds on both Windows
and Linux: [core run 41187871681](https://github.com/gmoddev/GodotLuau/actions/runs/41187871681)
passes 80 distinct cases per platform; [native run 41187871716](https://github.com/gmoddev/GodotLuau/actions/runs/41187871716)
passes 110 actors per platform (original 95, fourteen presentation actors and one
performance execution actor). Downloaded artifact digests, native fingerprint,
62 exact fixture hashes, logs and required assertion labels were independently
checked on DockerPC. The performance smoke executes five profile modes for 1/16
characters; it is not a speed gate. Hosted headless presentation is separate
from the actual rendered DockerPC qualification.

The earlier [failed native run 41187189642](https://github.com/gmoddev/GodotLuau/actions/runs/41187189642)
and both downloaded artifacts remain preserved: its custom remote assertion
expected the incorrect container described above. Final fixtures correct that
premise without changing the runtime factory or weakening geometry assertions.

The final local fresh matrix passes Windows Debug's 80 core cases and 110 native
actors. Windows Release and core ASan completion are recorded in the closing
evidence supplement when available. The fresh Linux Release core ctest exits
successfully, but its JUnit has insufficient distinct-case evidence and the
strict 80-case checker rejects it; subsequent local native and ASan stages were
not reached. This local report gap is not counted as a passing 80-case run.
Hosted Linux Debug's independently verified 80/110 results remain valid. The
user requested immediate committed/published shutdown preparation, so incomplete
local qualification is retained explicitly rather than delaying publication.

The rejected first candidate's Windows Debug/Release 80-core/103-native and
80-core ASan results remain historical counterevidence, not substituted for
final native sanitizer qualification. No final Linux Debug local execution or
full-native ASan/LSan result is claimed. See the machine-readable closing
[evidence manifest](evidence/character-presentation-performance-2026-10-31.json).

Native allocation-event counts are not exposed by the available engine API;
the harness records static allocated bytes and live objects/nodes/resources,
including 100 respawns, without treating object count as allocator events.
Physical input-device ergonomics, arbitrary imported content, production scale,
GL-017/018, broader GL-020 adversarial qualification and distribution remain
separate limitations. No full-native Windows sanitizer result is invented.
