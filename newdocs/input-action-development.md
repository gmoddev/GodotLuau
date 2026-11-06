# Input Action and Native API campaign

Started 2026-11-06 on `feature/input-action-api-foundation` from verified main
`091c13da85b1d082249b525123f5cae4d3c17dd1`. Main core workflow `42160074655`
and native workflow `42160074673` both completed successfully. Main is not to be
merged, rewritten or otherwise advanced by this campaign.

## Assessment and acceptance

The supplied `GodotLuau_Input_Action_API_Research.md` is research, not implemented
behavior or additional authorization. Its reference Gargantuan revision is
`04c6385f26de9b7d96b48de06c911ecea692796c`. Reading its InputActions contract and
CompiledInputGraph confirms ordinary authoring Instances plus one disposable
native evaluator. GodotLuau retains its own SceneTree, domains and Godot input;
no Gargantuan runtime, mutation gateway, platform adapter or dependency is ported.

Current GodotLuau source confirms that UserInputService dispatches in `_input`
and genuine event paths omit `_fire`'s game-processed argument, defaulting false.
Godot routes GUI after `_input`, before `_unhandled_input`. A real Control/event
order probe is required before selecting the final commit barrier. Existing
ContextActionService discovery is not implementation proof. Existing generic
Variant conversion supports neither dictionaries nor Vector2, so new APIs need a
bounded typed bridge, not unrestricted Godot reflection. Current retained raw
signal closures also capture pointers; touched paths need ObjectID resolution.

Acceptance is a working Jump/Menu slice, then composites/analog/pointer input,
then an independent local motor/camera and runnable Luau controller. Every slice
must cover lifecycle/rebinding/GUI rejection and state-before-callback behavior.
Existing Character V2 hardware control, physics, networking and authority remain
intact. No new Player.Character authority or global InputMap mutation is allowed.

## Execution and evidence

DockerPC is the primary worker, MainPC is fallback, GitHub Actions is permitted;
LinuxBox and other execution workers are excluded. Existing toolchains and
fixture ownership are reused. No dependency installation/pin change, Godot host
patch, release or updater distribution is authorized.

Initial DockerPC SSH/.NET filesystem reads succeed. A broad PSDrive inventory
and a read through an old Networking2 build path stalled; these are infrastructure
observations, not input/runtime failures. Replace with bounded task-owned reads;
do not restart shared services or delete historical caches to recover them.

## Progress

- Preparation: branch created, instructions/reference source read, latest main CI
  verified. No new input implementation or qualification is claimed yet.
- Native routing baseline: DockerPC's existing Godot 4.7.1 passes
  `InputRoutingBaseline.gd` using real focused LineEdit and Viewport dispatch.
  Consumed press/release visit input then GUI, with no unhandled callback;
  unconsumed input reaches unhandled. `_input` sees Handled=false before GUI.
  Logs and JSON are under `C:/Sandbox/Codex/InputAction20261106` on DockerPC.
- Worker inspection: existing pinned godot-cpp/Luau sources and Windows MSVC
  cache are available. An old Networking2 CMake path is absent; the bounded
  read reports FileNotFoundError. `docker ps` times out after ten seconds.
  Windows native work can proceed independently; Linux local Docker readiness
  is not established. No shared backend restart is performed.
- Implementation started: pure native digital graph projection with bounded
  authoring counts, stable priority ordering, fresh-edge chord admission,
  consumption and explicit cancellation. It is not yet wired to public Nodes
  or claimed qualified.
- Digital slice: native InputService/Context/Action/Binding, typed Luau authoring,
  stable priority/consumption, fresh-edge chords, runtime rebinding, owner-aware
  Connect/Once and neutralization are implemented. UserInputService is the sole
  physical adapter and now commits after GUI routing. See the
  [public API and migration](input-actions-api.md).
- DockerPC MSVC Debug production adapter builds against the unchanged pinned
  dependencies. Reused adapter cache has the historical CMake driver, with
  GL_SOURCE_ROOT explicitly redirected to this task's complete current source;
  no old core test executable is used for qualification. The task-owned current
  core build passes all 85 existing cases, complete CTest XML and strict report
  verification, plus 17 new direct evaluator checks.
- Native input attempt v1 printed PASS but contained a callback assertion: the
  fixture incorrectly required Space's companion action after rebinding Jump to
  Q. This is a failed attempt, not accepted qualification. Attempt v2 then failed
  the corrected callback-count check (expected three instead of the four actual
  valid presses). Both full logs remain under InputAction20261106/input-v1 and
  input-v2. v3 passes with clean stderr and the corrected expectation. Subsequent
  focused coverage adds Once connection state and retained-handle destruction;
  v4 passes all 30 checks with clean stderr, including these additions. The
  [digital milestone receipt](evidence/input-digital-milestone-2026-11-06.json)
  records normalized production/fixture identities, binary hash and retained log
  hashes. The existing 16 candidate admission/rejection tests also pass on the
  worker after adding the input actor to release candidate gates.
- Existing CI now invokes the input fixture as one additional native actor (132
  total, preserving all 131 predecessors) and the direct evaluator executable.
  Release candidate gates use the same fixture and updated actor count; release
  publication remains disabled. Linux, Release, sanitizer, analog/controller and
  performance qualification are not yet established for this campaign.

## Analog, motor and runnable controller follow-up

Digital implementation `9ce9382bd6afc0f946f425c7a480e2f1f9d8e20b` is published.
Fresh [core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42170148571)
and [native CI](https://github.com/gmoddev/GodotLuau/actions/runs/42170148520)
pass on Windows/Linux. Downloaded native artifacts `13482356149` (Windows) and
`13480898480` (Linux) contain all 132 actors, the actual input fixture PASS and
production fingerprint `a37b92d484d4964e1f46ef2080d00a64d5f6bc1e04e061709784729656593d74`,
matching the local receipt. This establishes that digital revision's scope,
not the uncommitted analog/controller follow-up.

The follow-up implements keyboard composites, radial gamepad sticks and
relative mouse input within the same graph. Frame/physics fences rotate separate
accumulators before existing RunService callbacks. Retained raw input views now
use ObjectIDs; adapter replacement and destruction release old subscriptions.
Source-verified private native callback boundaries revalidate lifetime before
continuing. Vector options are raw typed data, so an __index proxy cannot run
arbitrary code during a native setter. Projected values retain their kind until
the next safe evaluation after authoring changes; pause clears input and commands.

`KinematicMotor3D` provides an independent Godot collision body, bounded
physics-tick commands, observations and viewport camera/capture leases. It never
targets Character V2. Scene-authored bodies are inactive until Client adoption.
The existing ENet replication fixture gains local-type stamping/activation
assertions; local input/motor subtrees are excluded from existing replication
and remote reference admission without changing the wire contract.

The [runnable controller](../examples/input-controller/README.md) uses actions
and the motor for keyboard/gamepad movement, look, sprint/jump, GUI, remapping and
restart. Native tests execute that exact Luau source; source identity includes it
in existing harness hashes. The shared input group now has three actors, making
134 total while retaining all preceding actors. The existing sanitizer runner
also invokes the group. Source-backed editor completion metadata is added for
the implemented surface, with Connect/Once rather than an invented signal Wait.

Interim DockerPC MSVC Debug results: 29 evaluator assertions; input v5 passes 44
native checks, motor v1 passes 20 and the first runnable-demo replay passes 19,
all with clean stderr and successful process exit. Later coverage adds projected
type transitions, pause, service destruction during adapter creation and repeated
restarts. Final-profile results remain to be recorded.

The extended Release input attempt `input-axis-repro` establishes an actual
diagonal-stick focus defect in the first analog implementation: clearing the
adapter's reconstruction cache allowed X-only updates to invent full neutral
while Y was still held. Both focus/rearming assertions fail. The correction
preserves physical axis reconstruction and clears graph admission/output instead;
the failed log remains under the task-owned DockerPC evidence directory.

DockerPC's Docker endpoint is local `npipe:////./pipe/dockerDesktopLinuxEngine`,
but `docker info` times out after ten seconds. The permitted MainPC fallback is
DESKTOP-B8V8NAN; its CLI reports the Linux engine pipe absent. Its SSH wrapper
reports exit 0 despite that error, which is not accepted as engine availability.
No shared backend is restarted and no other workers are used. Local Linux
qualification is unavailable; hosted Linux qualification remains permitted.

The axis-cache correction passes the expanded **51-check Release input fixture**,
including the diagonal focus regression, raw-data proxy rejection, pause and
service destruction inside adapter creation. The final optimized Release motor
fixture passes 20 checks. Real offscreen rendering on DockerPC's existing NVIDIA
GTX 1650 SUPER passes 23 example checks; 20 restart cycles leave node count
unchanged and observed Godot static memory 5,160 bytes lower (not a whole-process
allocation/leak proof). The only stderr diagnostic is the host's unsuccessful
display-timeout override request. Automated replay deliberately avoids physical
mouse capture. The [receipt](evidence/input-controller-milestone-2026-11-06.json)
records exact source/fixture/binary identities and the
[screenshot](evidence/input-controller-2026-11-06.png).

Five interleaved main/candidate trials and five same-API optimization trials are
retained with [performance analysis](input-action-performance.md). Sparse
256-action publication improves from median 635 to 211 microseconds per
32-event burst. The small correction skips unchanged ObjectID commits and unused
callback snapshot initialization, preserving all-changes-before-callbacks and
explicit physics cancellation. Dense/tail and unchanged raw-control measurements
remain mixed; they are not hidden. The existing evaluator benchmark records zero
hot C++ allocations within its stated scope. All 16 existing candidate rejection
tests pass with the 134-actor gate and example source identity. Expanded hosted
134-actor CI, final core profiles and full-native sanitizer results are pending;
this milestone does not claim their completion.

## Final qualification of the controller implementation

Implementation revision: `c03747277dfd1ccdfcfed2d2bf453659da553af5`.
Native production identity: 99 files, LF-normalized SHA256
`0cf632015b905ead12291e1dc148f6a8606f1ef169a6cccddd3c39c096bccedf`.
The later documentation receipt does not change runtime, fixture or dependency
inputs. Earlier pending statements describe their historical milestones.

DockerPC's final current-source Windows Release run passes 85 core cases with
complete CTest output and the existing strict checker, plus 29 graph assertions.
The optimized Release DLL is
`37bcb8dc08168120d87cb9cfa0aa0b47991f39e7fc71ee2c82f4810e297b8822`.
Input/motor checks are 51/20; the real rendered example passes 23 checks and 20
restart cycles with no node-count growth. The screenshot and raw performance
observations remain those linked above.

The existing full-native sanitizer builder/runner also passes on DockerPC with
the matching existing MSVC 14.51 host: detection controls, registration/reload,
85 core cases, all 134 native actors and strict native completeness verification.
No unexpected sanitizer report is present. Windows LSan remains unsupported.
No dependency or host correction is changed. Task-owned native processes are
gone; the durable evidence and build caches remain, with 16.5 GiB free on C: at
the final local check.

Fresh hosted [core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42180439541)
passes on Windows/Linux: 85 cases and 29 graph assertions per platform. Downloaded
Linux [native](https://github.com/gmoddev/GodotLuau/actions/runs/42180439542) and
[full-native ASan/LSan](https://github.com/gmoddev/GodotLuau/actions/runs/42180461051)
artifacts pass all 134 actors at the same native source identity. Actual logs
contain 51 input checks, 20 motor checks and 20 headless example checks, including
20 restart cycles. Both ENet replication actors pass local input/motor exclusion
and inert scene-authored motor assertions. Linux sanitizer coverage includes
intentional UAF/leak controls, all 85 core cases and zero unexpected reports.
Hosted Windows native and full-native ASan subsequently pass as well. Their
downloaded artifacts contain the same 134 actors, 51/20/20 input/motor/example
checks and controller fixture identity. Both hosted sanitizer builds instrument
1,164 compilation units; all detection controls and production reload gates pass,
with 85 core cases and no unexpected reports. The ordinary Windows/Linux native
jobs and both core jobs are complete and successful; no pending gate is counted
as passing. Windows LSan is unsupported, rather than silently disabled coverage.

The [final receipt](evidence/input-final-qualification-2026-11-06.json) retains
workflow/job links, all six downloaded artifact IDs/digests, source/binary and
companion identities, fixture hashes, actual input-check inventories, core report
hashes, local Release/rendered results and sanitizer scopes. **QUALIFIED within
these recorded profiles.** No runtime or fixture correction was needed after
`c037472`; this final follow-up contains documentation/evidence only.

Remaining scope limits are physical keyboard/gamepad/touch and actual OS mouse
capture, Linux graphical/Release coverage, and complete native allocation
profiling. The existing admitted-host, GL-017/018 and other issue-ledger limits
remain independent; this work does not close them. The next useful qualification
is a bounded physical-device/capture play session on the permitted workers.
Character V2, GL-029/030/031–039 authority and transport contracts remain intact.
No main merge, release, updater distribution, dependency change or upstream change
is performed by this campaign.
