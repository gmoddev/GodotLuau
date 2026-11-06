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
