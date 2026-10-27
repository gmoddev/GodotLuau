# GL-006 / GL-008 native authority qualification

Date: 2026-10-27. Base main: `78d9664d10cede4f4dc7e7d4a93ddf1785c97ea0`.
Working branch: `security/gl-006-008-rpc-authority`. Reproduction fixtures:
`2f563e079ac289d6bba54af0232ee100c71cb37d`. Implementation and final fixtures:
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6`.

This record covers the named state/removal and chat entry points. It does not
establish general multiplayer security, authenticated accounts, or movement
anti-cheat. Shared Server/Client execution domains and GL-019 code are unchanged.

## Investigated trust boundary

The topology is Godot SceneMultiplayer over ENet, with server peer 1 and server
relay enabled. `NetworkService` owns the transport and per-peer PlayerObject
ObjectIDs. It assigns sequential session UserIds at connection; these are session
identifiers, not authenticated accounts. A PlayerObject may be created by the
first character state or by an existing RemoteEvent workflow. Merely connecting
does not require a character or fire PlayerAdded.

Originally all affected RPCs were ANY_PEER. `_recv_state*` trusted payload `who`,
and `_recv_remove` removed tracking/characters and fired removal callbacks.
`_relay_state*` and `_relay_chat` also mutated/displayed on client receivers.
Chat trusted the submitted name. Reading the old server PlayerObject alone was
insufficient: the first client state `idx` selected its display name too.

The correction enforces these rules before side effects:

| Entry | Authorized execution |
| --- | --- |
| `_recv_state`, `_recv_state2d` | Connected Client service, actual sender 1, server present in current transport; positive target with server-assigned session mapping; ignore own target |
| `_recv_remove` | Same server-origin sender/receiver check; positive nonlocal target; target need not remain connected because disconnect removal follows transport departure |
| `_recv_chat` | Same server-origin sender/receiver check; positive mapped origin, original name/message Variants must be strings, valid message |
| `_relay_state`, `_relay_state2d` | Connected Server service, actual sender >1 in current transport and assigned session map; coordinator rejected; sender determines target |
| `_relay_chat` | Same client-origin guard, original string payloads, live nonqueued server PlayerObject matching its assigned session UserId; no identity creation/fallback on chat |
| `gl_send_chat` | Explicit local API, not configured as an RPC; connected clients submit for server acceptance; local/server dispatch has its own bounded acceptance path |

The four receive RPCs additionally use RPC_MODE_AUTHORITY. Handler guards remain
effective if authority configuration is relaxed. Sender zero never grants an
inbound handler local authority. Listen-host broadcasts use existing local
server code rather than calling inbound receive handlers locally. Existing
replication/RemoteFunction/physics authority checks are preserved.

Server state relays replace the client `idx` with the assigned session UserId
before creating a PlayerObject or forwarding state. Chat derives its display
name from that live server-owned record; the submitted name is ignored. Trusted
server scripts may still set display names or send a system label locally.
Clients cannot select those labels through these RPCs.

## Chat validation and compatibility

- Messages contain 1–256 Unicode scalars and cannot be whitespace-only. C0/C1
  controls, DEL, surrogate scalars and values above U+10FFFF are rejected.
  There is no truncation, profanity filter or account validation.
- A per-session token bucket starts with five tokens and refills at one token
  per second, capped at five, using monotonic ticks. Invalid/unknown senders and
  malformed/oversized messages do not allocate a bucket or consume tokens.
  Buckets bind Player ObjectID plus assigned UserId and are reset on peer/full
  disconnect, transport replacement or service destruction.
- Chat before a valid server-owned PlayerObject exists is dropped. Detached,
  queued-for-deletion, removed and stale ObjectIDs are rejected. A successful
  reconnect must establish its new record before sending chat. UID-map presence
  alone is insufficient: current transport membership is checked too.
- Local/system chat can operate without a Players service; its bucket belongs
  to the local service. No remote identity fallback uses a submitted name.
- The sender displays only accepted server echo. The UI no longer displays an
  optimistic message that the server might reject; local standalone UI still
  works. MessageReceived follows the actual accepted display.

RPC names, argument counts/order, reliable/unreliable channels and valid wire
payload shapes are unchanged. Native chat parameters use Variant to reject
non-string wire values before Godot's binder can stringify them, even when it
reports a conversion error. In the pinned engine, `SceneRPCInterface::get_rpc_md5`
hashes configured method names, not native parameter types. No protocol migration
is required; mixed historical application versions were not separately qualified.
Remote player labels now use server-assigned session indices rather than the
client's chosen/editor display index. This visible naming change is intentional.

Chat relay enqueues network delivery before calling user display callbacks and
does not access service/session pointers afterwards. State relays re-resolve the
service ObjectID and sender membership after character callbacks before forwarding.
No deferred work retains a Player pointer. Existing owner cancellation, pending
RemoteFunction teardown and the GL-001/002 resolutions are retained.

## Executed transport regressions

`NetworkSecurity.gd` is run by the existing bounded `RunQualification.py` runner.
It uses file barriers only to coordinate actors; tested messages traverse actual
ENet RPC dispatch. It observes real puppet positions/health, live PlayerObjects,
PlayerRemoving callbacks, displayed chat and MessageReceived callbacks.

The unchanged Linux Release baseline reproduced unauthorized state/removal and
chat effects. Its failure output remains in
`linuxbox:/opt/codex/godotluau/artifacts/gl006-008-baseline-2/Dedicated`.

Each candidate security group runs ten processes: one single-player process,
listen-host plus two clients, dedicated server plus two clients, and dedicated
server plus two clients with the four receive RPCs deliberately configured
ANY_PEER. The latter tests native handler guards independently of RPC filtering.

Assertions cover:

- Forged state/2D state/removal to the server and another client, targeting the
  attacker, victim, zero, negative and nonexistent identities; direct relay RPCs
  to a client; no position/health/player-registry/removal-callback/relay effects.
  Default victim logs show unauthorized RPC rejection, confirming cross-client
  delivery through the enabled relay rather than claiming a blocked topology.
- A forged first state index followed by chat; another player's name and SYSTEM
  become the actual sender's server-owned name. Direct forged chat receive/relay
  produces no display or callback.
- Pre-initialization and pre-reconnect-identity chat; empty/whitespace/control,
  oversized ASCII, 256/257-scalar Unicode and malformed Array text; burst
  exhaustion, later refill, independent second-client allowance and sender UI
  awaiting acceptance.
- Legitimate server/local chat, local UI with/without Players, multiple clients,
  3D/2D updates after attacks, join/disconnect callbacks, attacks immediately
  before disconnect, rejection after disconnect, reconnect with a fresh record,
  invalidated Player ObjectID rejection and record replacement recovery.

The existing eight-process regression group additionally covers module sharing,
invalidation, Server/Client isolation, RemoteEvents/RemoteFunctions, late-join
replication, owner/callback/native-wait cancellation, NetworkService replacement
and pending-invoke teardown. It includes Editor-style multiplayer flags.

Reconnection uses real new ENet connections. A deterministic collision of the
numeric peer ID was not forced; stale-record rejection also checks the assigned
UserId and live ObjectID, and invalidated/replaced records are exercised.
Malformed UDP framing/fuzzing and an authenticated identity system are outside
this fixture's claims. Unicode display is observed directly because the inherited
Luau SetAttribute string conversion is not a faithful Unicode observation channel.

## Qualification scope and retained evidence

**SECURITY FIXES QUALIFIED** for GL-006/008's stated endpoints on the dedicated
branch. The following final-source gates passed:

| Platform/configuration | Core | Existing native regression | Security native fixture |
| --- | --- | --- | --- |
| Windows Debug | 39 cases | 8 processes | 10 processes |
| Windows Release | 39 cases | 8 processes | 10 processes |
| Windows core ASan | 39 cases | Not claimed | Not claimed |
| Linux Debug | 39 cases | 8 processes | 10 processes |
| Linux Release | 39 cases | 8 processes | 10 processes |
| Linux full-native ASan/LSan | 39 cases | 8 processes | 10 processes |

All 90 native processes exit zero and pass their assertions; no sanitizer report
is produced. The final groups emit no GL-017 zero-channel diagnostics, which
does not resolve the independent historical engine defect. An initial Windows
core ASan attempt failed with missing runtime DLL exit 0xc0000135; adding the
existing compiler runtime directory to PATH yields the recorded final pass.
Builds/normal native fixtures use CMake; SCons inputs are unchanged and no new
SCons packaging qualification is claimed.

All 65 normalized native inputs match local, Windows and Linux source digest
`3f4e64b4477d228e9ed3580d5c054a4cc1f3d6d32abf53de842cf25daf78fd37`.
Both changed headers and both security test files also match across workers.
Every tested copied library matches its final worker build hash.
Final commands, binary/result/log hashes, diagnostics and worker paths are in
the [evidence manifest](evidence/gl006-008-qualification-2026-10-27.json). Native builds
use the existing Windows worker caches and four-job Linux task container.
No dependency/toolchain upgrades, release/updater execution, binary publication,
main merge or upstream writes are part of this task.

GL-017's independent ENet teardown diagnostic/leak remains open. Normal logs
retain engine diagnostics; Linux full-native ASan/LSan uses the existing matching
instrumented minimal host with `detect_leaks=1`. Final closes are ordered after
the transport poll; disconnect/reconnect attacks remain separate executed checks.
This does not qualify simultaneous-close engine behavior. GL-018 still excludes
Windows full-native sanitizer-host qualification. Graphical rendering, production
content/coordinator operation and release packaging are not newly qualified.

GL-007 movement/health semantic validation remains independent. Investigation
also identifies GL-020: ANY_PEER animation receive/relay paths can change another
puppet's animation. It does not reach the corrected position/health/removal or
chat sinks, so it is not a prerequisite to closing these endpoint-specific
findings. It prevents a general claim that all remote presentation is protected.
