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

## Rendered local loop completed

Play-v7 passes all 21 game checks using the renderer-enabled admitted host on
MainPC's RX 7900 XT (actual OpenGL 3.3), synthetic input/focus and an offscreen
non-activating window. It activates three relays, defeats six drones, wins,
acknowledges persistence, starts a second round, takes hazard damage, dies,
respawns with the existing controller, loses to reactor pressure and saves again.
The victory image is visually inspected. No physical-device claim follows.

The 58.252-second run averages 33.514 ms/frame at an intentional 30 FPS cap;
peak including startup is 148.373 ms; final native node count is 161. This is a
functional observation, not an optimization claim. Earlier failures and writes
remain retained: the disposable career now has 14 rounds and one actual win.

GL-044 records missing native CFrame direction conveniences; the gun reads the
existing matrix fields. GL-045 records colon Dot reading self as the operand;
the gun uses the existing immediate dot-style API. World rays now start at the
true eye: cooperative hulls use layer 0 while retaining their native world mask,
avoiding self hits without weakening occlusion or adding a query framework.
The existing Character asset-bundling helper supplies six self-contained meshes
with preserved geometry/textures, eliminating editor-cache dependencies.

One ObjectDB object is reported at exit; identify it from a verbose real run.
Fresh-process recovery, real multiplayer and final extracted-package startup
remain pending. No main merge or publication has occurred.

## Multiplayer and cleanup

Listen-v1 passes four actual rendered ENet players: 28 leader checks and nine
checks per observer, including the late joiner. The leader completes victory,
saved reward, another round, damage/death/respawn and defeat; clients receive
the same authoritative result. Mean frames are 33.49–33.72 ms at the 30 FPS cap,
with startup peaks 142.67–145.83 ms. The fresh server career acknowledges two
rounds, one win and 72 credits. Native game-input forgery checks also pass.

The verbose recovery run identifies the one leaked object as continuous
AudioStreamGeneratorPlayback. Replace it with a short generated PCM WAV played
on demand; recovery-v3 exits without that leak. It passes eight checks, including
fresh-process progress and actual local SoftBody3D anchor release through a Luau
InputService action and the native scene adapter. Luau can observe SoftBody
identity/transform; point/pin APIs require the scene adapter, not a new solver.

Dedicated-v1 completes the entire four-client gameplay loop, but fails its crate
motion check: default automatic ownership transfers simulation to a nearby
client, while the validated impulse runs on the server. Configure that specific
crate using existing SetNetworkOwner(nil); do not redesign physics replication.
Both sessions retain an inherited ENet retired-channel diagnostic at peer exit;
dedicated-v1 also retains one rejected Character-transform warning, with no
established cause. Neither is hidden by gameplay PASS claims. The normal game
quit path now explicitly disconnects and yields a short drain before scene exit.
The package includes the already-established empty global-script cache to avoid
consumer startup errors. No native source or admitted patch is changed.

The controller example gains one optional additional pause attribute,
PlayerControllerSuspended, for result screens. It defaults false and reuses
the same context cancellation/fresh-input rules. Dedicated gameplay verifies
stopped results input and no held-key reactivation after restart. Original
native behavior remains untouched; current native regressions are required.

## Qualification follow-up

Dedicated-v2 passes all five actors: 28 leader checks, nine per each of three
observers and two server checks. Pinning the crate with SetNetworkOwner(nil)
restores its actual client-visible impulse motion. The redundant second server
start caused an avoidable bind failure; the bootstrap now respects the native
CLI-created dedicated session. Connection failures stay in the game UI, and
owned client scripts retire before transport teardown/main-menu reload.
Menu-v3 exercises failed join and return to a fresh menu with four passing
checks and no script errors. Pending joins now defer controller creation until
native connection/Player ownership is live; weapon context Enabled is always
boolean rather than nil during initial startup.

Matching Windows full-native ASan lifecycle-v1 passes 17 actual game checks,
including forged-intent rejection, native input, cloth release, weapon dispatch,
death/respawn, defeat, acknowledged persistence and shutdown. No sanitizer report
is emitted. Full instrumented victory attempts remain failed: headless synthetic
mouse aiming does not behave like rendered input, and the right-stick replay
loses the reactor before completing six kills. Their reports remain failed;
they do not establish a sanitizer fault or passing full victory. Game difficulty
and complete-loop assertions are unchanged. The scoped passing lifecycle is
reported separately; Windows LSan remains unsupported.

Native CI at `7826a7b` passes Linux; Windows attempt 1 fails official-editor
download with HTTP 504 before building/testing. Only that failed job is retried,
preserving Linux evidence. Final source/packaging verification remains pending.
