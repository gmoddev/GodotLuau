# GL-006 / GL-008 native authority qualification

Date: 2026-10-27. Base main: `78d9664d10cede4f4dc7e7d4a93ddf1785c97ea0`.
Qualified branch (retained as history): `security/gl-006-008-rpc-authority` at
`462969bd967bd26fcbeccdca1bd6ae60335347f4`. Main now integrates that source;
see the [integration record](#main-integration-2026-10-27). Reproduction fixtures:
`2f563e079ac289d6bba54af0232ee100c71cb37d`. Implementation and final fixtures:
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6`.

The original qualification below and subsequent integration cover the named
state/removal and chat entry points. This record does not
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

**Historical branch qualification: SECURITY FIXES QUALIFIED** for GL-006/008's
stated endpoints. The following source-qualification gates passed before integration:

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
main merge or upstream writes were part of that qualification phase. Main source
integration is recorded separately below.

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

## Main integration (2026-10-27)

Starting local and remote main: `78d9664d10cede4f4dc7e7d4a93ddf1785c97ea0`.
Qualified local and remote source: `462969bd967bd26fcbeccdca1bd6ae60335347f4`.
Neither advanced before integration. One clean worktree and no active edit claims
were present; main was the exact common ancestor. Review confirmed the three
commits separate regression fixtures (`2f563e0`), implementation/focused coverage
(`b839ea4`) and qualification/documentation (`462969b`). No extra source changes
or dependency/build/workflow/updater modifications were present.

Normal `git merge --no-ff` produced runtime main revision
`2e69d8ac703d3f968e42054871511111ab8471be` without conflicts, retaining all three
commits. Its entire tree equals the qualified source tree:
`3ddb481b04cd36a28f006b03736a43ae2d9cc83d`. Subsequent integration edits are
documentation/evidence only; the publication tip is the documentation commit
immediately following this merge, identifiable in Git history. No history rewrite,
squash, force push or behavioral conflict resolution occurred.

Runtime, security fixtures and build code equal the qualified branch. All 86
runtime/build/test files compared with the worker mirrors match after LF
normalization; all 65 native inputs retain fingerprint
`3f4e64b4477d228e9ed3580d5c054a4cc1f3d6d32abf53de842cf25daf78fd37`.
Shared-domain, module-cache, environment, owner/cancellation and GL-019 core files
are unchanged from pre-integration main; dependency pins and SConstruct are
unchanged. Static inspection retains connected role/sender/target guards and RPC
configuration, active server-assigned relay senders, live PlayerObject/session
identity, original Variant validation, the 256-scalar policy, five-token burst/
one-token-per-second refill, and accepted server echo. RemoteFunction ownership
and ObjectID revalidation paths are preserved.

### Fresh integrated-revision checks

**INTEGRATED WITH QUALIFICATION LIMITATIONS.** Existing Windows worker caches and
the four-CPU/10-GiB Linux task container were reused. Six incremental CMake core/
adapter checks report no work; their compatible library hashes exactly match the
qualified artifacts. This is fresh execution with retained binaries by source/
build identity, not a claim of six clean rebuilds or a new full qualification.

| Configuration | Fresh core | Fresh existing regression | Fresh security fixture |
| --- | --- | --- | --- |
| Windows Debug | 39 cases pass | 8 processes pass | 10 processes pass |
| Windows Release | 39 cases pass | 8 processes pass | 10 processes pass |
| Windows core ASan | 39 cases pass | Not claimed | Not claimed |
| Linux Debug | 39 cases pass | 8 processes pass | 10 processes pass |
| Linux Release | 39 cases pass | 8 processes pass | 10 processes pass |
| Linux full-native ASan/LSan | 39 cases pass | 8 processes pass | 10 processes pass |

All 90 native process results exit zero with PASS, including 50 actual-ENet
security-fixture processes and 40 existing regression processes. Security runs
exercise default RPC filtering and deliberately relaxed filtering for native
handler rejection, state/removal/chat attacks against server and victim, malformed/
oversized text, rate limits/refill, accepted identity echo, normal local/listen/
dedicated behavior, disconnect/reconnect and invalidated/replaced PlayerObjects.
Existing regressions retain Editor-style flags, module/cache/domain separation,
callback/task cancellation, late-join replication and RemoteFunction teardown.
Each configuration runs once; no historical stress or performance matrix repeats.

The original source-qualification manifest and baseline failure artifacts are
unchanged. Its evidence remains applicable within the preceding scope and limits;
the fresh results above are recorded separately in the
[main integration manifest](evidence/gl006-008-main-integration-2026-10-27.json).
It preserves commands, per-group results/log hashes and matching library/source
identities. Windows output is under
`dockerbox:C:/Sandbox/Codex/Builds/GodotLuau/gl006-008-integration-2e69d8a` and
`C:/Sandbox/Codex/Logs/GodotLuau/gl006-008-integration-{debug,release,asan}.log`.
Linux output is under
`linuxbox:/opt/codex/godotluau/artifacts/gl006-008-integration-2e69d8a`.
No raw logs, binaries or archives enter Git.

Runs use the documented `RunQualification.py --security` and separate
`--teardown --coordinated-close` commands with new output directories and
60-second child deadlines. Linux full-native ASan/LSan uses the existing matching
minimal instrumented engine, `detect_leaks=1:halt_on_error=1`, a distinct report
path and 90-second deadlines. Windows stays hidden/headless with crash-UI
suppression and uses the existing compiler runtime DLL path for core ASan.
No sanitizer report or GL-017 zero-channel diagnostic appears in the fresh groups.
This does not resolve GL-017's independent simultaneous-close leak/diagnostic or
GL-018's Windows full-native host gap; ordered final close remains explicit.

### Publication, remaining limits and next task

The hardened endpoint implementation is now the canonical main source baseline.
GL-006/008 remain resolved within their documented scope and their source branch
is retained at `462969bd967bd26fcbeccdca1bd6ae60335347f4`. The publication target
is only `gmoddev/GodotLuau` main, via ordinary non-force push after these gates.
Both new commit messages include `[skip ci]` to prevent the inherited destructive
release workflow. No workflow/updater configuration, upstream repository, binary
publication or GitHub Release changes. Main was unprotected and repository
rulesets were empty at preflight; no publication restriction is bypassed.

GL-007, GL-020, GL-017/018 and all capability/sandbox/HTTP, persistence, release/
provenance/updater and asset limitations remain open. No graphical/coordinator/
production-content or SCons packaging qualification is added. Original limits on
forced numeric peer-ID collision, mixed application versions and malformed UDP
framing remain. No general claim that all multiplayer RPCs are secure is made.

The next bounded task is GL-020: `_relay_anim`/`_recv_anim` still use ANY_PEER and
lack the role/sender checks before animation-cache mutation/application/relay.
Enforce those boundaries and test actual wrong-peer rejection plus valid play,
stop and late-join behavior. GL-007 remains a separate gameplay-authority design
and semantic validation effort for movement/health/speed. Neither is implemented
during this integration.
