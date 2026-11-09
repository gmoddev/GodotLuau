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

Implementation and gameplay qualification remain pending at this checkpoint.
Releases and updater distribution remain disabled.
