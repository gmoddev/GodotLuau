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
P impulses the blue physics crate. Escape/Start opens the native-controller
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
python examples/e2e-game/PrepareGame.py --candidate GodotLuau-Windows.zip --engine godot.windows.template_release.x86_64.exe --host-manifest remote-host.json --output C:/Sandbox/RelaySiege --archive C:/Sandbox/RelaySiege-Windows.zip
```

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
Current RaycastParams exclusion is not implemented; shots begin beyond the
shooter's capsule. This is a game workaround, not a claim of full Roblox raycast
compatibility or an unrestricted API audit.

Qualification and performance observations are in
[`newdocs/e2e-game-development.md`](../../newdocs/e2e-game-development.md).
This is a non-publishing qualification package. Existing engine/asset provenance
limits remain; releases and updater distribution are disabled.
