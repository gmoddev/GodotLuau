# ADR-006: Server character lifecycle and bounded prediction

Status: implemented, qualified and integrated into main by normal merge
`4d4694e8ea5f05120ded9b116bcd06a2c95e4ead`, preserving qualified source `3bb641a`
and retained tip `514d12f`. Character V2 subsequently carries these authority
requirements into ADR-007's protocol 3 and Model ownership. See the
[integration record](character-main-integration.md). Baseline and architecture map:
[work record](character-development.md); exact checks and evidence:
[qualification](character-authority-validation.md).

## Authority and protocol

The server selects each network character's dimension, spawn, generation and
movement configuration. Native server health is authoritative. Client Luau
health mutations are denied at the native setter, including generic call/set
aliases and the shared local/listen scene. Server callbacks and trusted native
engine delivery retain authority. This is gameplay authority, not a hostile
project-script sandbox.

Protocol 2 replaces unversioned client state with a generation, monotonic packet
sequence and bounded predicted pose. Health and display identity are absent from
the new client payload. The server derives identity from transport membership.
Old inbound state RPCs fail closed; mixed old/new game versions are unsupported.
There is no downgrade. Server snapshots carry authoritative health and a separate
monotonic sequence. Clients reject old generations and snapshots.

A reliable server grant supplies spawn/correction and movement configuration.
Respawn replaces the server character and grants a new generation; corrections
also change generation so in-flight input cannot undo a server teleport. A client
can request initial readiness but cannot choose a spawn or authorize a new life.
Character destruction revokes movement admission until explicit server respawn.
Existing LoadCharacter remains a server/single-player operation. The server polls
health/death and applies CharacterAutoLoads/RespawnTime for remote players.

## Prediction limits

The baseline native controller measured 16 walking, 24 sprinting and jump velocity
20 at 60 physics ticks/second on Windows and Linux. The controller's configured
gravity is 45; 2D defaults are 200/300, jump magnitude 500 and gravity 980.
Movement budgets derive from server configuration and physics tick duration,
including two ticks of positional slack. They do not use a universal teleport
distance. Horizontal credit is capped at one second of configured sprint motion;
arrival gaps beyond that supported prediction window reject movement input.
A separate owner/session/epoch-checked reliable synchronization request grants
the current server pose, at most once per second. Native clients request it when
server pose progress stalls while their predicted pose diverges. Rejected pose
packets themselves cannot change the correction epoch or animation admission.
Synchronization preserves airborne rise accounting; it cannot grant another jump.
Packet admission is bounded independently of distance. Vertical motion uses a
gravity/jump envelope and elapsed airborne time; grounded slope motion must fit
the existing 50-degree controller slope setting. Numeric transforms and animation
inputs must be finite. Server death suppresses movement/presentation.
For 3D with nonzero gravity, cumulative airborne ascent is capped by jump-energy height
plus two physics ticks of slack. Grounded flags remain client predictions, so
this bounds a continuous airborne report without claiming server collision truth.
The existing 2D controller supports both platformer and sustained top-down
movement. Its plane retains per-packet jump/gravity and horizontal/rate bounds,
without the 3D cumulative ascent rule. Mode flags remain predictions; this change
does not add a server simulation of either 2D controller mode.

This policy checks movement plausibility. It does not replay inputs, establish
collision truth, prevent wall traversal, or constitute complete anti-cheat.
Server-authorized teleport/configuration changes establish a fresh baseline.
Presentation flags remain bounded predictions, not evidence of server collision.

## Animation cannot grant gameplay authority

A focused Windows candidate reproduced an additional route: selecting a packaged
animation with a value track targeting `Humanoid:Health` changed real server
health from 75 to 1. A project asset is not automatically safe for client-selected
server playback. This extends the same health boundary, rather than authorizing
an unrelated animation rewrite.

Network playback therefore validates and owns a private checked Animation copy
before cache mutation/relay. A further controlled candidate reproduced resource
script `_init` changing health during loading, before track checks. Client packet
handling must therefore never load arbitrary project resource paths on the server.

The native service owns an immutable presentation catalog. Trusted server startup
registers assets before any live peers, through
`NetworkService:RegisterCharacterAnimation(asset)` or the project setting
`godot_luau/character_animation_assets` (PackedStringArray). Registration is not an
RPC, denies Client execution, stays within `res://`, allows at most 64 assets,
8 MiB per source file and 64 MiB total source bytes, at most 128 identity aliases,
and cannot replace a live
catalog entry. Resource loading at this explicit trusted startup boundary is not
a hostile-project loader sandbox. Scripted Animation objects are rejected. Only
plain validated track data is copied into catalog/per-peer Animation objects;
resource metadata, script attachments and arbitrary subresources are not cloned.
Client-selected paths must resolve to an existing catalog entry before any load,
cache mutation or relay. New registration after peers join fails closed.
Client Luau resource loads use that same catalog on each endpoint. Configure
startup assets in the exported project, or register them natively before Connect;
registration cannot be delegated to a LocalScript. Export remaps are followed
with a four-hop/4-KiB-per-remap bound when measuring stored resource bytes.

Supported tracks are rig position/rotation/scale and
blend shape, with relative descendant paths, finite keys, at most 256 tracks and
16,384 keys. Root, HRP, physics-body, method, generic property, audio and nested
animation tracks cannot be client-selected gameplay channels. Runtime target
resolution must remain inside the character. One selected checked clip is held
per peer; ordinary setting updates reuse it. Playback owns one temporary library
slot per peer and restores an overwritten scene clip, so packet names cannot
accumulate library entries. Server-script local gameplay timelines remain
separate. Client Luau cannot load/play unsafe gameplay clips in
the shared scene either. Missing assets retain the existing inert local-track
behavior. Name-only requests may wait for character/library resolution; playback
still requires the same policy. Unsupported animation content needs an explicit
project migration; no unsafe tracks are silently removed.
Track Stop/Speed/Looped operations obey the same rule and cannot interrupt an
active server gameplay timeline. Named libraries retain their library/clip
identity; temporary network slots restore the original clip when replaced.
Network requests obey the same active-timeline rule and cannot replace inactive
gameplay clips by alias. Cleanup removes only the exact temporary clip it owns;
a later trusted scene replacement is preserved.

For example, register project clips before admitting clients:

```luau
local Network = game:GetService("NetworkService")
assert(Network:RegisterCharacterAnimation("res://Animations/Walk.tres"))
```

Or configure startup assets in `project.godot`:

```ini
[godot_luau]
character_animation_assets=PackedStringArray("res://Animations/Walk.tres")
```

Unregistered resource playback from a client is intentionally rejected. Default
procedural R6 movement does not use this asset catalog. Existing GL-020 fixtures
now register their three project clips during trusted startup; their transport,
pre-puppet, late-join, settings, completion and teardown assertions remain.

Independent animation RPCs now carry correction epochs on client input and life
identity on server playback. Epoch zero supports GL-020's bounded pre-puppet
session cache; it cannot be used after a life has been granted. Animation rates
are separately bounded. A reliable animation for a new life may wait for its
unreliable birth snapshot, without applying to the old character.

## Lifetime and compatibility

The service uses native ObjectIDs and revalidates after gameplay callbacks.
Queued/deleted characters cannot be recreated by a normal input packet.
Client writes to shared server character descendants and ancestor transforms,
reparenting into those characters, Destroy and ClearAllChildren cannot alter
their authoritative native hierarchy. This is checked at the native Luau
property/Instance-method boundary, including Rotation aliases.
The existing shared scheduler, VM topology, GL-020 animation ownership and
GL-022 callback guards remain the governing contracts. No worker VM, second
scheduler or privileged token is exposed to scripts.

Existing network clients require matching builds. Projects that damaged/healed
characters from LocalScripts must move that gameplay decision to a ServerScript.
Standalone server-native NPC health remains supported. Character V2 is a later
stacked migration; this decision does not rename Humanoid or simulate Model
inheritance. Release publication and updater distribution remain disabled.

## Required evidence

Actual local/listen/dedicated two-client fixtures must cover normal movement,
irregular arrivals, corruption/rate/health attempts, server correction/respawn,
stale generations, wrong roles/senders, and callback destruction. Windows/Linux
core/native checks and appropriate sanitizer coverage must qualify the final
input tree before this ADR is marked implemented. These gates pass for native
fingerprint `20ecbfc...`; the qualification record retains the complete matrix,
four hosted jobs, downloaded artifact verification and remaining limits.
