# Relay Siege — gameplay qualification

The playable Windows game is complete on the unmerged
`feature/e2e-gameplay-foundation` branch. Production game source and the supplied
Actions ZIP identify `3f617040ab7d7edeb94721ed4f7cd7a0af3345e6`.
Later evidence-only commits do not change that package. Main remains
`a3c62e9333fbf2a7dd7d095b9f12d9a3d71eba96`.

Download the `RelaySiege-Windows` artifact from the
[non-publishing package run](https://github.com/gmoddev/GodotLuau/actions/runs/42588812901).
Extract its ZIP to a writable folder and run `Play.cmd`; use `Server.cmd` for a
dedicated server. The artifact expires after 14 days. The source
[launch/build instructions](../examples/e2e-game/README.md) describe reproduction
from explicit inputs. The retained local ZIP and inputs are named in the
[identity receipt](evidence/e2e-game-qualification-2026-11-09.json).
The ZIP SHA-256 is
`a0ce9f1760b8f359fdfdadc43ba1c1f0acae3646c17dec0288bca83ee3013645`.

## Actual gameplay

| Configuration | Result | Evidence and scope |
| --- | --- | --- |
| Extracted Windows rendered package | 28/28 | [Local report](evidence/e2e-game/packaged-local.json): actual menu, native Scripted Character input, jumping, soft body, rejected forged requests, crate impulse, three relays, six weapon kills, victory/save, another round, health/death/respawn, defeat/save |
| Four-player rendered ENet listen host | 55/55 across four actors | [Session](evidence/e2e-game/listen-session.json): leader 28, three observers nine each, deliberate late join, shared authoritative result and departures |
| Corrected dedicated server + four rendered ENet clients | 57/57 across five actors | [Session](evidence/e2e-game/dedicated-session.json): server two, leader 28, three observers nine each; final join/bootstrap and retirement paths |
| Fresh-process DataStore recovery | 8/8 | [Recovery](evidence/e2e-game/restart-recovery.json): reads prior acknowledged rounds, win and credits; actual transactional companion, no in-memory substitute |
| Final Actions ZIP rendered menu | 4/4 | [Menu](evidence/e2e-game/packaged-menu.json): failed connection stays in UI; actual session teardown returns to a fresh main menu; empty stderr |
| Matching Windows full-native ASan, headless | 17/17 | [Lifecycle](evidence/e2e-game/asan-lifecycle.json): actual input, rejection, cloth, weapon dispatch, native Character death/replacement, defeat/save and shutdown; no sanitizer report |

Rendering uses MainPC's RX 7900 XT, the approved OpenGL engine profile, an
offscreen non-activating window, synthetic input and synthetic focus notification.
It does not establish physical-device or real OS-capture behavior. All multiplayer
actors are independent processes using actual ENet packets on loopback. Only the
dedicated server is headless in those sessions. The game uses existing qualified
network authority and lifecycle rules; no mock transport or Character is used.

The final local report took 63.354 seconds for two rounds. At an intentional
30 FPS cap, mean frame time was 33.490 ms, peak 144.833 ms including startup,
and final scene node count 166 (the report field is named `NativeObjects`).
The final dedicated session's rendered actors averaged 33.519–33.785 ms/frame,
with peaks up to 150 ms including startup. These are bounded functional
observations, not uncapped performance or improvement claims.

The fresh packaged server career finishes with two rounds, one win and 72
credits. Recovery's older disposable root contains 14 rounds, one win and 198
credits, including earlier failed attempts. Production launchers keep data in
their portable `Data` folder; no existing player directory was migrated or erased.

## Inputs and verification

The unchanged 101-file native fingerprint is
`2278df21b72670c189c6206a5a49582a50d4cd835448f3f0708629ae0fd7d52e`.
The accepted native candidate is from `d76d689`, run 42216970390 attempt 2.
The renderer host is from successful run 42576293787, pinned Godot
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, with the same admitted GL-018/029
patches. Neither native source nor dependency pins changed. Established native
and sanitizer evidence is reused within that scope; see the
[controller integration](player-controller-main-integration.md).
The shared controller example adds only an optional suspension gate for results;
the game explicitly opts into Scripted control. Native remains the engine default.

The package workflow verifies the existing native archive and host using their
established admission checks, imports the six R6 meshes with the existing helper,
builds a fresh self-contained ZIP, extracts it and starts its actual Main scene.
Startup succeeds with empty stderr. Its 157 payload members match manifest
hashes and sizes; the ZIP contains no test driver, save data or updater add-on.
Two local archives at `b0b9010` from identical explicit inputs are byte-identical.
This does not claim independently compiled engines or different producers yield
identical bytes.

Focused commands, with the explicit inputs from the receipt:

```text
python tests/runtime/RunRelaySiege.py --game EXTRACTED/RelaySiege --output FRESH --scenario local --graphical --timeout 240
python tests/runtime/RunRelaySiegeMultiplayer.py --candidate CANDIDATE.zip --engine ENGINE.exe --host-manifest remote-host.json --assets IMPORTED_ASSETS --output FRESH --graphical
python tests/runtime/RunRelaySiegeMultiplayer.py --candidate CANDIDATE.zip --engine ENGINE.exe --host-manifest remote-host.json --assets IMPORTED_ASSETS --output FRESH --dedicated --graphical
python tests/runtime/RunRelaySiege.py --game STAGED_GAME --output FRESH --scenario recovery --verbose
python tests/runtime/RunRelaySiege.py --game EXTRACTED/RelaySiege --output FRESH --scenario menu --graphical --timeout 45
python tests/runtime/RunRelaySiege.py --game MATCHING_ASAN_GAME --output FRESH --scenario lifecycle --timeout 200 --verbose
```

The last command uses the previously admitted instrumented engine, extension and
companion together, with `ASAN_OPTIONS=halt_on_error=1`. Instrumented binaries
and hashes are explicit in the receipt; the production archive is not an ASan
package. Two unavailable-navigation-module fallback warnings remain in that
profile. Full instrumented victory replays failed to complete gameplay and are
retained as failures, without reported sanitizer faults. The passing lifecycle
does not relabel those attempts. Windows LSan remains unsupported.

Core CI run 42587537286 and native run 42587537271 pass Windows/Linux Debug,
with all 141 required native actors per platform. Both use `43f513b`; subsequent runtime
changes are only the game's ready log and dedicated-startup ordering, exercised
by the package and dedicated tests above. No new native compilation or duplicate
sanitizer campaign is needed for unchanged C++ inputs.

The subsequent two-line fixture correction is `78b7f65`:
[core run 42590964403](https://github.com/gmoddev/GodotLuau/actions/runs/42590964403)
and [native run 42590964418](https://github.com/gmoddev/GodotLuau/actions/runs/42590964418)
pass both platforms, with all 141 native actors per platform. Both downloaded
native summaries identify that revision and the unchanged 101-file fingerprint;
artifact IDs/digests and summary hashes are in the receipt. The focused
seven-actor matching ASan relevance run also passes. No production game file
changed after the packaged and dedicated qualification source.

## Remaining scope

The inherited ENet retired-channel diagnostic still occurs during peer exit.
The exact cause is unproven; no engine patch or assertion is changed to hide it.
The duplicate dedicated bind was a separate, corrected game-bootstrap bug.
An earlier Windows CI relevance attempt fails its server-motion observation.
The fixture now explicitly pins that phase to the server before the unchanged
later client-owner grant. [All seven existing relevance actors pass](evidence/e2e-game/relevance-ownership.json) with the
matching ASan test adapter. Two initial local runs used the production DLL,
which intentionally omits fixture-only peer diagnostics; those runs are invalid
fixture configurations and do not establish a product defect.
GL-043/044/045 retain real raycast/CFrame/vector compatibility gaps; the game uses
supported calls. SoftBody deformation is local; its native point/pin API is
called through the scene adapter, with no vertex replication.

Linux rendered gameplay, physical devices, WAN/NAT traversal, authentication,
matchmaking and pristine-machine runtime installation remain unqualified.
Existing GL-017/018 and asset-provenance limitations remain. No broad refactor,
dependency update, transport replacement, release publication, updater admission
or merge into main is part of this campaign.
