# Foundry Expedition

GL-054 production acceptance project, qualified within the
[recorded profiles and limitations](../../newdocs/gl-054-qualification.md).
All authored game logic is Luau. Godot scenes/resources/shaders/SVG provide native
content. External GDScript observers are test fixtures, not shipped game logic.

Restore three sectors by collecting three power cells, defeating navigating
guards with directional pulses and extracting near the gate. WASD/stick move,
Space/A jumps, Shift/LB dashes, F/RB pulses, E/X extracts and Escape/Start pauses.
The native UI provides FOV, volume, restart and explicit persistence retry.

Server execution owns the private scene physics, health, guard AI, damage,
sector progression and DataStore updates. Client execution owns UI/input only.
Same-process root attributes carry bounded semantic input and presentation JSON;
they are not a network protocol or a trusted source of health/rewards. Server
rules ignore claimed outcome fields. This mode is solo. Remote replication of
these independently authored native bodies is not implemented; Relay Siege
remains the separately qualified listen/dedicated multiplayer project.

The Explorer uses a scene-owned CharacterBody3D. It is not a replacement
RBXCharacter or a change to Character V2. The engine's Native controller remains
default and Scripted remains opt-in. No global controller setting is modified.

Rooms inherit the native Base PackedScene and share an authored NavigationMesh.
The world is reconstructed through a fresh SceneScope on transitions; previous
physics, animation, callbacks and resources retire with their owner/scope.
Modules separate world, art/animation, enemies, rules, transactional progress and
UI. Assets remain project-local. Navigation requires a full-featured Godot host;
the lightweight admitted network hosts omit it and cannot run this game.

Cached rule/progress modules expose factories: each Server entrypoint generation
starts a fresh session and reloads committed progress. Disabling that entrypoint
retires its world; volatile movement, combat and unacknowledged session state are
not a saved checkpoint. Command watermarks prevent replay after reload. Client
reload reconstructs UI/input under its fresh owner and continues command counters.
A heartbeat neutralizes movement/dash after 0.25 seconds of simulation without
fresh input production; shared attributes alone do not keep a retired producer
moving the body. These are local application rules, not a network admission token.

Progress uses GL-009 UpdateAsync with pure retryable transforms and bounded
server-generated idempotency receipts. A stage clear is not a durability
acknowledgment: the HUD reports committing, durably saved or unacknowledged.
At most three receipts are pending, retries back off and stop after three failed
attempts until explicitly requested. Shutdown waits boundedly for active saving
and attempts remaining progress; failure stays explicit. An unacknowledged commit
may already have taken effect under GL-009's documented indeterminate-outcome
contract; retry uses the same receipt and restart reads the latest committed
record. The supplied user-data folder is distinct from other examples.

Stage from an explicit verified adapter or candidate with the existing helper:

```powershell
python examples/luau-only/PrepareProject.py --profile Foundry --adapter <adapter.dll> --adapter-source <source.json> --output <fresh-directory>
```

Open that directory with the matching full-featured Godot editor, allow the normal
asset import and run Main.tscn. Test adapters are qualification products; do not
distribute them. Use a matching qualified production candidate for standalone
exports. Export resource filtering must include `*.luau`; releases and updater
distribution stay disabled. Physical controller/mobile and remote multiplayer
support are not inferred from keyboard or headless qualification.

On Linux, retain the verified candidate's Unix modes while extracting. Godot's
extension-dependency export copy treats the companion as a shared object and
drops its executable bit. After an ordinary editor export, restore that bit on
the unchanged companion before launching or archiving the application:

```sh
chmod 755 godot_luau_store_worker
```

RunLuauExport performs this packaging step after verifying the exported native
file hashes, records the before/final modes and requires a successful DataStore
read in both standalone starts. This is a packaging requirement, not a change
to native storage authority or permission to distribute unqualified products.
