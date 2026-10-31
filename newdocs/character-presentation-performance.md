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
The candidate keeps ObjectID/type/parent/deletion resolution on every use, checks
both live poses before skipping work, preserves repair of an independently moved
body, and uses direct native camera queries. It adds no cross-frame pointer or
hierarchy cache. Correctness and repeated baseline/candidate measurements must
qualify it before acceptance. Broader hierarchy/puppet/animation caching is not
introduced merely to reduce call counts.

## Qualification status

Candidate builds, complete regression runs, repeated comparisons and hosted CI
are in progress. No pending execution is claimed as passing. Final results,
exact source identities, screenshots and evidence digests will be recorded here.

Native allocation-event counts are not exposed by the available engine API;
the harness records static allocated bytes and live objects/nodes/resources,
including 100 respawns, without treating object count as allocator events.
Physical input-device ergonomics, arbitrary imported content, production scale,
GL-017/018, broader GL-020 adversarial qualification and distribution remain
separate limitations. No full-native Windows sanitizer result is invented.
