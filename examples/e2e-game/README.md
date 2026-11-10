# Relay Siege

A small cooperative arena for 1–4 players. Activate all three amber relays and
destroy six drones before the reactor is destroyed or the 150-second timer ends.
Relays turn green and heal nearby players. Red floor tiles pulse damage. Players
automatically respawn after two seconds. Complete a round to earn shared arena
career credits; results must save before another round starts.

## Launch

The staged package contains `RelaySiege.exe`, the native GodotLuau libraries,
matching DataStore companion, project and sources. Double-click `Play.cmd`, then
choose **Play solo**, **Host co-op**, or enter an address and **Join server**.
For a dedicated server use `Server.cmd` (UDP 24870). All peers need the same
package. Maximum four players; listen host includes its local player.
Ports/addresses are editable in the main menu; CLI equivalents:

```text
RelaySiege.exe --path . -- --mode solo
RelaySiege.exe --path . -- --mode host --port 24870
RelaySiege.exe --path . -- --mode join --address 127.0.0.1 --port 24870
RelaySiege.exe --headless --path . -- --mode server --port 24870 --glserver 24870
```

WASD/left stick moves; Shift/L3 sprints; Space/A jumps. Hold RMB and move mouse,
or right stick, to look. LMB/R1 shoots; R reloads; E/X activates a nearby relay;
P impulses the blue physics crate; O releases the local soft-body anchor. Escape/Start opens the native-controller
menu; Escape resumes. Results allow another round or retry of a failed save.

Progress is the **server's shared arena career**, not authenticated personal
accounts: cumulative rounds, wins and credits. Clients cannot write it. It lives
in the project's `user://` directory. The launchers select portable Godot user
data under `Data/GodotLuauRelaySiege` beside the game, using child-local APPDATA.
Keep this directory across server restarts. Never run old pre-GL-009 writers on
the same root. Save errors are visible and do not acknowledge success.

## Stage from explicit qualified inputs

From this repository, using a previously accepted Windows candidate ZIP and the
authorized renderer-enabled host plus its `remote-host.json`:

```text
python examples/e2e-game/PrepareGame.py --candidate GodotLuau-Windows.zip --engine godot.windows.template_release.x86_64.exe --host-manifest remote-host.json --assets imported-character-assets --output C:/Sandbox/RelaySiege --archive C:/Sandbox/RelaySiege-Windows.zip
```

Use `--asset-editor Godot_v4.7.1-stable_win64.exe` instead of `--assets` to run
the existing six-mesh import/bundling helper from explicit editor input. Archive
creation requires a fresh staging folder so progress, logs and test scripts
cannot enter the delivered ZIP. Extract to a writable folder for portable data.

The reliable game endpoint accepts `(Action, Round, Value?)`; only Shoot takes a
finite unit native Vector3. Server identity, live Character, round, rate,
ammunition, range and world occlusion are authoritative. Other supported intents
are Interact, Reload, Impulse, Again and Save. Snapshot Version 1 is a complete
server-owned view sent at 5 Hz; it includes relays, drones, roster, health,
ammunition, reactor, timer, result and shared career. It changes no native wire
protocol. Unknown/stale/forged requests cannot grant damage, rewards or victory.
The last 32 round receipts make normal save retries idempotent within that
bounded history. A failed/unacknowledged save remains explicit; another round
cannot start until it is acknowledged.

No source checkout is needed by the resulting game. `game-package.json` records
supplied input and payload hashes. The official stock editor can stage local
rendered development without `--host-manifest`; it cannot host/join GL-029.
Such a package is explicitly unqualified for networking. The game sources reuse
the repository's `PlayerController.luau`, copied by staging, without a second
movement or input framework.

The game uses primitive geometry, generated tones and Godot physics. The hanging
green object is a local Godot SoftBody3D demonstration, not networked cloth.
The blue crate uses RobloxPart/ApplyImpulse and native rigid-body collisions.
`Game.gd` authors geometry/UI/presentation; server/client Luau owns game rules,
intent and persistence. Drones use simple server-authored point movement and
bounded sphere hitscan; existing workspace raycast handles world occlusion.
The original game qualification used a native build without raycast filtering;
the current game requires the GL-043/044/045 compatibility fixes. Authoritative
Luau now excludes current Character subtrees with RaycastParams, uses colon Dot
and native Vector3 impulses, and reads Camera.CFrame.LookVector. The game retains
its cooperative Character hull configuration: hulls
use collision layer 0 while retaining their world collision mask. Players slide
against arena geometry but do not block allies or eye-origin ray queries. This
is scene configuration, not a claim of full Roblox raycast
compatibility or an unrestricted API audit. Shot filtering no longer depends on
the query invisibility of those hulls. Godot still authors geometry, menus/HUD,
audio and local SoftBody mesh/pin presentation; the existing Luau API has no
qualified cloth-point surface. No raw Godot method/physics handle is exposed to
Luau to remove that small presentation adapter. See the
[migration qualification](../../newdocs/gl-044-045-relay-development.md).

Qualification and performance observations are in
[`newdocs/e2e-game-development.md`](../../newdocs/e2e-game-development.md).
This is a non-publishing qualification package. Existing engine/asset provenance
limits remain; releases and updater distribution are disabled.
