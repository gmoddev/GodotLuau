# Relay Siege qualification scope

The normally integrated GL-051 campaign adds policy-driven native bindings, reusable relay
PackedScene/module composition, shared textures and typed native signals/calls.
Game/native/editor/package evidence is retained in the
[GL-051 qualification](https://github.com/gmoddev/GodotLuau/blob/main/newdocs/gl-051-qualification.md).
The [main integration record](https://github.com/gmoddev/GodotLuau/blob/main/newdocs/gl-051-main-integration.md)
tracks fresh main CI separately from reused branch evidence.
The retained GL-049 outcomes below do not qualify those changed inputs.
See `NATIVE-BINDINGS-API.md` in a staged package for the extended authoring API.

The normally integrated GL-049 `feature/luau-native-authoring` campaign replaces ordinary
geometry/UI/audio presentation construction with owner-scoped native Luau APIs.
Its [current qualification](https://github.com/gmoddev/GodotLuau/blob/feature/luau-native-authoring/newdocs/native-authoring-qualification.md)
records native Windows/Linux, full-native sanitizer and actual Windows rendered
local/listen/dedicated passes. Native candidate `42987296894` is accepted, with
fingerprint `350392bb4f5613a1722333e3de44f60adb9a4ac4b08ded4430a26a42e9f94b68`.
The rendered products match its accepted Windows libraries/companion exactly.
The journal retains failed attempts, source identities and packaging results.
The receipts below
remain historical; their exact source identities must not be relabeled as new
authoring qualification.

The current API migration uses qualified GL-043/044/045 behavior: Camera CFrame
directions, colon Vector3 math, native Vector3 impulses and server-authored
raycast filters. Native implementation `30682a3` has fingerprint
`40270fc0232566b9cd3f06584feba29cfbf88902be7609cdb140f2e12e00132c`.
Candidate run `42752234638` accepts source `4510ab4` after all ten gates:
Windows/Linux Debug/Release, 85 core cases and 141 native actors per profile,
107 Model checks, core ASan/LSan, rejection/retention and extracted-companion
startup. The complete native suites use the existing CMake test adapter;
source-built SCons products are separately packaged and started.

Game source `0ecc2b5` passes rendered automated four-player listen/dedicated
ENet sessions with that accepted production ZIP: 55/57 checks across four/five
actors respectively, zero failed checks and no unhandled script diagnostics.
The dedicated server is headless; its four clients render. Two rounds exercise
victory/save, restart, input cleanup, death/respawn and defeat/save. Snapshot
publication now uses FireClient per live Player, deferring only native
peer-not-ready rejection until the next current snapshot. Every other error
still propagates. The earlier replay with unhandled broadcast errors is retained.
Four known retired-channel engine errors and eight display-timeout warnings
remain in the passing replay; this is not a claim of diagnostic-free engine
teardown or full-game sanitizer qualification.

Fresh Windows/Linux core/native qualification at `e65e3b8` verifies the final
marker/retirement fixture corrections. Full-native sanitizer run `42748739079`
passes at `8eddb82` with unchanged C++/math inputs; later fixture corrections and
this game replay are not represented as a new full-native sanitizer run.
The [separate qualification journal](https://github.com/gmoddev/GodotLuau/blob/codex/gl-044-045-relay-luau/newdocs/gl-044-045-relay-development.md)
and its versioned receipt retain exact sources, hashes, failed attempts and limits.

## Earlier game campaign

The wider evidence below remains historical; it does not automatically qualify
new inputs.

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

The earlier matching Windows full-native ASan game lifecycle profile covers input,
authority rejection, soft-body interaction, firing, death/replacement and an
acknowledged failed-round save. Windows LSan is unsupported. Full instrumented
victory replays remain failed gameplay/automation attempts without reported
sanitizer findings; they are not reported as passing. Complete rendered rounds
use the uninstrumented production profile.

Physical devices, actual OS capture, Linux rendered game play, WAN/NAT discovery,
authentication, internet matchmaking and pristine OS runtime installation are
not qualified. Use direct addresses and a reachable UDP port. The admitted
engine can retain a retired-channel diagnostic at peer exit; existing GL-017/018
and asset-provenance limits remain. The original GL-043/044/045 findings and
their baseline failures remain preserved in the corresponding issue records;
the migration journal distinguishes their corrections and actual qualification.
No safety or authority assertions are disabled.

Package startup/archive identities are recorded separately in the campaign
receipt. `game-package.json` identifies supplied inputs and payload hashes; it
does not authorize distribution or claim bitwise reproducibility of independently
compiled engine binaries. Releases and updater admission remain disabled.
