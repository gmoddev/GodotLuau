# Relay Siege qualification scope

This is a non-publishing Windows qualification game, not an updater channel.
Use the matching supplied runtime, libraries and DataStore companion together.
The engine uses the pinned GL-018/GL-029 patches with an explicitly authorized
OpenGL renderer profile. Dependencies and native patches are unchanged. Exact
identifiers/results are retained in the
[campaign journal](https://github.com/gmoddev/GodotLuau/blob/feature/e2e-gameplay-foundation/newdocs/e2e-game-development.md).

Actual Windows rendering with simulated input covers local victory, defeat,
objectives, hitscan, health, death/respawn, menus and persistence. Four-player
ENet listen/dedicated sessions cover real transport, late join, shared results
and peer departure. A fresh process recovers progress. The native Character,
controller, movement admission, animation and transport are reused. Cooperative
hulls retain world collisions but do not block allies or world ray queries.

The green local SoftBody3D has native deformation and a releasable anchor. Luau
observes identity/transform and supplies InputService intent; the scene adapter
invokes Godot's pin API. No vertex replication or new solver is implemented.
The blue crate uses native collisions/impulses and explicit server ownership.

The matching Windows full-native ASan game lifecycle profile covers input,
authority rejection, soft-body interaction, firing, death/replacement and an
acknowledged failed-round save. Windows LSan is unsupported. Full instrumented
victory replays remain failed gameplay/automation attempts without reported
sanitizer findings; they are not reported as passing. Complete rendered rounds
use the uninstrumented production profile.

Physical devices, actual OS capture, Linux rendered game play, WAN/NAT discovery,
authentication, internet matchmaking and pristine OS runtime installation are
not qualified. Use direct addresses and a reachable UDP port. The admitted
engine can retain a retired-channel diagnostic at peer exit; existing GL-017/018
and asset-provenance limits remain. GL-043/044/045 record physics/CFrame/vector
compatibility limitations and the supported game calls used here. No safety or
authority assertions are disabled.

Package startup/archive identities are recorded separately in the campaign
receipt. `game-package.json` identifies supplied inputs and payload hashes; it
does not authorize distribution or claim bitwise reproducibility of independently
compiled engine binaries. Releases and updater admission remain disabled.
