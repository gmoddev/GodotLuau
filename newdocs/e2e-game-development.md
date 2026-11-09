# End-to-end gameplay foundation — Relay Siege

## 2026-11-09 — Preparation

Branch `feature/e2e-gameplay-foundation` starts from verified remote main
`a3c62e9333fbf2a7dd7d095b9f12d9a3d71eba96`. Main core/native CI at its runtime
merge `2b0f846` passes. Existing controller/input/authority/persistence evidence
is reused for unchanged engine inputs. No merge or distribution is authorized.

The game is a 1–4 player cooperative arena: activate three relays, shoot drones,
avoid hazards, preserve reactor integrity, die/respawn, win/lose and play another
round. Server Luau owns rules and damage; Client Luau uses existing InputService
and Scripted Player.Character. A small project-specific Godot bootstrap builds
primitive geometry and UI/presentation. There is no new input, transport, VM,
movement, persistence backend or physics solver.

Acceptance: an actual rendered local round; real ENet listen and dedicated
gameplay with 2–4 players, late join and disconnect; authority rejection; death
and respawn; saved progress read by a fresh process; extracted-package startup.
Synthetic input, headless evidence and actual rendering are reported separately.

DockerPC's heavy-worker lease is held by `jolt-final-performance-20261109`.
Do not interfere. MainPC is the authorized fallback for bounded game execution;
no sustained native compilation runs there. Existing binaries are reused.

The existing admitted GL-029 hosts disable every renderer. The owner explicitly
authorized a renderer-enabled build using only the same pinned engine and
already-admitted GL-018/GL-029 patches. The new optional `--rendered` production
Windows profile changes only `opengl3=no` to `opengl3=yes`; existing headless
and sanitizer profiles remain unchanged. The non-publishing host workflow runs
the existing real ENet host checks before export. Runtime rendering/gameplay
qualification is separate from a successful host build.

GitHub rejects dispatch of a new workflow absent from default main (HTTP 404).
Its branch/path-restricted push trigger starts the initial build without changing
main or publication workflows. Later game-only commits do not rebuild the host.
The first workflow text also needs a YAML block for pip's `:all:` argument;
GitHub's validation failures are retained rather than treated as host attempts.

Implementation and gameplay qualification remain pending at this checkpoint.
Releases and updater distribution remain disabled.

## First game launch

The initial headless local launch exposes two game mistakes: ButtonR2 is absent
from the actual KeyCode enum (use supported ButtonR1), and native PlayerObject's
UserId is a Luau binding, not a GDScript get_user_id method. The Client publishes
its read-only local ID to presentation instead. No engine contract changes.

MainPC's normal Roaming qualification leaf returns NTSTATUS `0xc000050b` from
the existing no-reparse relative directory open despite ordinary attributes
showing a directory. The same DataStore companion reads correctly in the private
artifact root; C: is NTFS. Do not weaken GL-003. Portable game launchers select
their own `Data` directory through child-local APPDATA, the existing Godot user-
data mechanism. No machine-wide environment or arbitrary Lua storage grant is
introduced. Subsequent tests use that actual package convention.

Local headless play-v1 executes the actual menu, input movement/jump, pressure,
death/respawn, defeat, another round and two acknowledged DataStore saves. It
fails six gameplay checks: weapon/interaction input incorrectly consulted the
movement lease's owner-scoped property from a different LocalScript; routing can
also become stuck after a death respawns at the default reactor origin. Correct
the game ownership check and provide a native SpawnLocation. Retain this failed
49.8-second run; do not call it a completed gameplay loop. Reactor health is
tuned to 300 to give a solo player time to learn and complete the objectives.

Local play-v2 activates all three relays and again exercises real saves/respawn,
but combat cannot finish: drones stop within the solid reactor footprint and
the raycast correctly occludes them. Stop drones outside reactor geometry.
The crate impulse moves only 0.12 units; increase its game-level strength for
visible feedback rather than relaxing the playtest assertion. The hazard route
also needs to walk around the reactor instead of through it. GL-043 records
source-verified inherited raycast-filter/native-Vector3-impulse limitations;
the game uses supported arguments and does not expand into a physics refactor.

The authorized renderer-host workflow `42576293787` builds and passes the
existing real ENet host checks; its exported host/provenance is downloaded.
Rendered local play-v3 confirms visible crate motion, but character input stops
after the offscreen window loses focus. The fixture must synthesize the existing
focus-in notification before synthetic input; it must not activate a Windows
window or relax the production focus guard. This remains simulated input plus
actual rendering, never physical-device qualification. Its failed result and
image remain retained. A completed victory is still pending.
