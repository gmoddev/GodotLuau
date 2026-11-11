# Native authoring qualification — 2026-11-11

Branch `feature/luau-native-authoring` remains unmerged. The reusable surface is
the fixed-family [API](native-scene-api.md), under [ADR-014](adr-014-native-scene-authoring.md).
The [journal](native-authoring-development.md) preserves the development sequence
and failed attempts; the [receipt](evidence/native-authoring/qualification-20261111.json)
retains source, fixture, product and report identities.

## Native inputs and checks

Native revision `b6b21a0913f35acff56434eb5ff71daffa2c519f` has LF-normalized
fingerprint `350392bb4f5613a1722333e3de44f60adb9a4ac4b08ded4430a26a42e9f94b68`
(103 files). The temporary close diagnostics were removed at `7f78ed4`, restoring
these exact inputs. The authoring fixture hash is
`8320500cf078996abc7e5ac8535d8bee3eba02ba82a3107bd9ac76c7032aab69`.

| Evidence | Result and scope |
| --- | --- |
| [Core 42987291392](https://github.com/gmoddev/GodotLuau/actions/runs/42987291392) | Windows/Linux pass, 85 core cases and 29 input-graph assertions each. |
| [Native 42987291389](https://github.com/gmoddev/GodotLuau/actions/runs/42987291389) | Windows/Linux Debug pass, 141 actors each; actual authoring Integration cases pass. |
| [Full-native sanitizers 42987292678](https://github.com/gmoddev/GodotLuau/actions/runs/42987292678) | Windows ASan and Linux ASan/LSan pass; 85 core/141 native, controls pass, no unexpected reports. |
| [Candidate 42987296894](https://github.com/gmoddev/GodotLuau/actions/runs/42987296894) | Accepted non-publishing candidate: Windows/Linux Debug/Release, core sanitizer, policy, both extracted-companion profiles per platform and aggregate acceptance pass. |

Post-restoration [core 42999540021](https://github.com/gmoddev/GodotLuau/actions/runs/42999540021)
and [native 42999540348](https://github.com/gmoddev/GodotLuau/actions/runs/42999540348)
also pass on both platforms at `7f78ed4`. This does not relabel the retained
`b6b21a0` sanitizer run as a fresh run on later documentation commits.

Native tests exercise actual constructors/properties, whole-batch rejection,
finite/type/count bounds, exact execution ownership and cross-domain rejection,
resource GC/retirement, reload/destruction/detached roots, callback reentrancy,
audio completion, initialized impulses and soft-body pinning. They reuse the
existing Integration actor and production native implementation.

The 64-child construction samples are 22.247 ms Windows Debug, 29.437 ms Linux
Debug, 173.605 ms Windows ASan and 60.110 ms Linux ASan/LSan. Monitor deltas are
121/122 Objects and 1 Resource. These include bootstrap/loading and are neither
isolated per-call benchmarks nor complete allocation measurements. They do not
establish a performance improvement over GDScript.

## Actual Relay Siege

The game uses the source-built SCons products from the passed `b6b21a0` Windows
profiles, unchanged admitted rendered host (SHA256
`09130cf169b0904be4f0f4cc566aaa58519553dcc1ca1a4563999553c3dd0ebc`) and existing
verified R6 asset bundle. At test time the private archives were explicitly marked
`DEVELOPMENT_BUILD_UNACCEPTED`. Candidate acceptance subsequently passed; existing
`CheckJobs`/`CheckPackage` verification passes on downloaded artifacts, and both
Windows DLLs and the companion are byte-identical to the retained rendered inputs.
Reuse those actual gameplay observations without repeating unchanged sessions.
The original private archives keep their development marker and original identity.

| Existing driver/scenario | Result |
| --- | --- |
| `RunRelaySiege.py --scenario local --mode solo --graphical` | 27/27: actual movement/jump, cloth release, impulse, server rejection, victory/save, results input consumption, death/respawn, defeat/save. |
| `RunRelaySiege.py --scenario recovery --mode solo` | 7/7: a fresh process reads the acknowledged two rounds/one win. Headless. |
| `RunRelaySiegeMultiplayer.py --graphical` | 55/55 across four rendered listen-session actors, including late join and two rounds. |
| Same multiplayer driver with `--dedicated` | 57/57 across headless server and four rendered clients, after dedicated bootstrap correction `81cd1c5`. |
| `RunRelaySiege.py --scenario menu` | 5/5: native menu, connection failure/retry UI, actual session teardown and scene reload. Headless. |
| Fresh private game archive extraction/startup | 160 payload hashes match; headless solo startup reaches `[Game:Rules] Ready`, exit 0, no script errors. |

Accepted native ZIP SHA256: Windows
`8f3369779e26eacab599f835611dc51b4210533640075bbaed46ad88c4e607bf`, Linux
`c5ed75aa34b9990878724652a757ef1a82e53dbc33b29e3392003abbc7a140cb`.
The accepted-input Relay Siege package job is the remaining packaging step.

Game source identities are retained separately from the native fingerprint.
Local/listen checks precede `81cd1c5`, which changes only dedicated startup's
wait for client UI. Dedicated/menu/package checks use that corrected bootstrap.
The failed dedicated attempt is preserved; it is not relabeled as passing.
Existing game rules, Server/Client scripts, protocol, persistence and Character
controller code are unchanged by the migration.

Rendered local play records mean frame time 33.489 ms at a deliberate 30 FPS cap,
peak 144.856 ms and 170 Objects over 65.517 seconds. This is a whole-game
observation, not isolated authoring overhead or an uncapped throughput claim.
Local stderr is empty. Listen/dedicated teardown retains the admitted engine's
known retired-channel errors; no unhandled game script errors are observed.

## Retained limitations

Windows rendering uses Godot-simulated input in no-focus/offscreen windows.
Physical devices, OS input capture, Linux rendered gameplay and full rendered
game sanitizer coverage are not established. Windows LSan remains unsupported.
The existing native/sanitizer lanes do establish their documented headless scope.

Project resource loading is synchronous trusted loading with an encoded-file
bound, not a hostile resource sandbox or decoded-memory/time bound. Template
root classes/SubViewport, arbitrary native classes/methods, clone/save/reparent,
automatic analyzer declarations, texture presentation and vertex replication
remain unsupported. See the API's explicit bounds and ownership contract.

Candidate close-save failures remain retained. A focused diagnostic profile and
five filesystem replays pass without reproducing the unexpected failure; its
cause remains unproven. No storage behavior, timeout or assertion is weakened.
The separate source finding [GL-050](issues.md#gl-050-datastore-receiveexit-ordering)
is not claimed as that cause or fixed by this campaign.

No release or updater distribution is enabled. Dependency pins, admitted hosts,
network protocols and `main` remain unchanged.
