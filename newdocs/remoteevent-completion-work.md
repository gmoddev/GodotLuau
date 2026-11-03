# GL-029 completion work

Date: 2026-11-03. Starting branch `integration/gl-018-gl-029-remoteevents` at
`cda423abae0270e62400be116ba23093dd6265c2`; qualified Phase 1 runtime `eec2397`.
Main remains `83cd0887968d73d61d050650718d8ada6e124579`. The working tree starts
clean and the published development tip matches. Dependency pins remain unchanged.

The user requests completion of GL-029 with the same small-change/no-refactor,
documentation, commit-preservation, unmerged-main and disabled-publication rules.
This authorizes continuing the remaining RemoteEvent work. GL-030 request timeout
semantics, replication batching and Character protocols remain separate issues.

## Acceptance and first gate

The outstanding P2/P3 behavior is bounded Remote-owned admission and queues,
fair peer service, exact accounting/teardown, the third sequenced mode, independent
stream freshness and safe unsent supersession. Actual loss/reorder/slow-peer,
complete-RPC packet-size and comparable performance evidence must accompany the
existing full Windows/Linux regression/sanitizer/product qualification.
Application admission, ENet submission, native retention and remote dispatch must
remain distinct observations. A successful send or application receipt is not
native ACK retirement. No total-backend-memory claim follows from an unsent queue cap.

Before changing production behavior, establish whether the pinned stock host can
support the required native egress admission contract. The pinned extension API
lists only loss, RTT and throttle peer statistics. There is no exposed reliable
queue byte/command count, native ACK-retirement ledger or outgoing queue cap.
`ENetConnection.bandwidth_limit` limits traffic, not retained bytes.

Source references at engine `a13da4feb8d8aefc283c3763d33a2f170a18d541`:

- [ENet peer API](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_packet_peer.cpp): exported send/statistics and method bindings.
- [Native send](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/thirdparty/enet/peer.c): packet/channel/state checks and outgoing command allocation.
- [Native retirement](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/thirdparty/enet/protocol.c): reliable command/packet references retire on native acknowledgments/reset.

These are source-verified API observations, not yet a measured backlog failure.
Run a bounded disposable raw ENet connection probe on the remote worker, with one
endpoint deliberately not polling after connection. Record accepted submissions,
process memory, payload bytes, available statistics and cleanup. This characterizes
the engine boundary; it is not a substitute for production RemoteEvent qualification.
Do not alter the engine, dependency pins or production runtime while this contract
gate is unresolved. Retain the qualified Phase 1 behavior and evidence.

## Characterization outcome

Both bounded Windows probes complete, including the second probe servicing the
sender without receiver polling. All 32 MiB of payload is admitted; approximately
37 MiB of additional private storage remains until host destruction. No exact
native backlog/retirement observation or public outgoing cap is available. This
is finite retention evidence, not a leak or an exhausted-limit claim.

The [native admission decision](remoteevent-native-admission-decision.md) records
the measured evidence, the minimum adapter contract, the patched-host compatibility
impact and the explicitly weaker stock-host alternative. GL-029 remains OPEN;
production Phase 1, main, pins, releases and updater admission remain unchanged.

## Approved continuation

The user approves the narrow native adapter on 2026-11-03. The recorded
[ADR-009 contract](adr-009-bounded-remote-delivery.md) now guides implementation.
Preserve the stock-host characterization and Phase 1 evidence. First implement
and test the native admission ownership boundary, then integrate bounded Remote
queues and sequencing under the existing NetworkService. Do not broaden into
replication, a second scheduler, unrelated refactors or GL-030.

## First adapter execution

The first Windows matching-host ASan prototype compiles from the hash-verified
engine archive and admitted GL-018 correction, with the six-file admission patch
applied under `C:/Sandbox/Codex/GL029Completion/host-asan`. It reuses a task-owned
copy of the prior 3.6 GB cache (original E: evidence unchanged), two compiler jobs,
MSVC compiler SHA-256 `b0a1818ebae6da7f18230a84e76ce839212584ac4c2ab55b97a0d5268085da57`.
Preparation takes 271.625 seconds; build/check duration is 303.235 seconds overall.

The actual raw native admission fixture then passes in 7.391 seconds with no
unexpected ASan report. Exact 4 MiB peer and 16 MiB host payload ceilings reject
one-over without retaining new ownership. A real partial ACK retires commands
from 3,076 to 3,028 while keeping the entire fragmented packet charged. Full ACK,
unordered handoff, peer reset and host destruction release the corresponding
ownership. A healthy broadcast recipient proceeds while full recipients reject.
Repeated rejected candidate packets leave prior ownership unchanged.

This is initial Windows native-boundary evidence, not GL-029 closure, a Linux
pass or full-suite qualification. Command-count boundaries, native RPC error
propagation, queue integration, sequencing and the complete matrix remain pending.
The new production queue component and its focused regression preserve the prior
80 core cases and raise the required total to 81; native adapter inventory remains
116, with host-boundary qualification recorded separately.

## RPC boundary continuation

Source tracing finds that the pinned SceneRPC sender discards `send_command`
errors. Its receive path checks RPC authority but does not establish that the
actual received transfer mode/channel matches the configured method. A method
name supplied by a caller is insufficient carrier evidence.

The approved adapter now includes error propagation through SceneRPC and a
read-only native call-context check scoped to the actual target, method, sender,
transfer mode and channel. NetworkService requires both native capabilities
before starting transport and checks that context for RemoteEvent data/control.
Reliable RPCs without the Remote-owned retry queue explicitly terminate their
affected session on native admission exhaustion. Healthy fanout recipients still
proceed. These behavior changes require focused runtime tests before qualification.

The expanded ten-file host patch compiles on the matching Windows ASan host in
32.219 seconds with two jobs. Its first attempt stopped before compilation: a
verified reverse patch restored CRLF inputs. The builder now normalizes only
hash-verified admitted originals before applying the pinned LF patch. Both
attempts remain in the task-owned evidence tree. Compilation is not runtime proof.

GER2 fixture frames now include the 48-byte header and sequence field; unknown
delivery rejection uses mode 3 because mode 2 is now the supported sequenced mode.
The existing controlled cancellation fixture explicitly drains admitted incoming
work before disconnect, preserving its original queued-Wait cancellation edge.
The queue regression additionally checks atomic fanout rejection/commit, record
counts and peer-identity bounds. Full runtime compilation and these checks remain
pending at this point in the work record.

## Initial production execution

The candidate compiles against the pinned bindings after correcting the ENet
generated-header spelling and separating `auto` declarations for two distinct
queue specializations. These failed build logs remain retained. Native source
fingerprint `72f1826a8300ccdefde570eb412a51d9bdeb73ff9fe39182d0f0ee59019a2f0d`
covers 91 files. Its adapter SHA-256 is
`f90dce86ddf0926e3f57b873b051a43942042c12476d566dec7198fe098c410e`.
An isolated matching MSVC ASan core build passes all 81 cases in the strict
runner. The first core configure lacked an explicit portable Python path; the
subsequent attempt selects the existing verified interpreter and passes.

The expanded native boundary fixture passes in 20.610 seconds, including exact
peer/host command ceilings independently below byte ceilings. An earlier
16,384-single-packet setup exceeded its 120-second timeout under ASan. The fixture
now seeds most command ownership with fragmented buffers and fills only the
remaining commands with small packets; ceilings/assertions are unchanged.
The actual SceneRPC error-propagation fixture passes 12 assertions in 2.875
seconds: cached and uncached-path WouldBlock reaches `rpc_id`, rejected Remote
data retains no candidate ownership, and unbuffered reliable control exhaustion
terminates its affected session. Neither run writes an unexpected ASan report.

The first sequencing run exposed a fixture mistake: Godot caches RPC config on
first use, so later `rpc_config` calls did not change its carrier. Wrong-carrier
probes now send pinned complete SceneRPC packets over the actual ENet peer, and
the server asserts native rejection counts before freshness. A second fixture
mistake assumed one drain must run every callback; bounded between-message time
slices permit later drains. The corrected fixture preserves the exact four
admitted samples and drains subsequent slices under the same receive barrier.
All six listen/dedicated actors then pass in 27.032 seconds, with no unexpected
ASan report. This is the initial sequencing/lifecycle fixture, before the added
pressure, terminal-overflow and exhaustion cases.

Ordinary native CI, full-native sanitizers and all four non-publishing candidate
profiles now require the admitted host policy and host-boundary fixture results.
The official editor remains the verified asset preprocessor. Runtime host
identity is separate from editor provenance and embedded in candidate evidence;
no engine binary is added to extension distribution. Stock hosts cannot start
the stronger network protocol. The new candidate-policy rejection case passes
with all 15 policy tests; hosted execution remains pending.

## Pressure, packet size and terminal cleanup

The expanded six-actor fixture passes pressure/fairness, submitter destruction,
exact 1,024-record unordered admission plus one-over drop, exact publication
retirement, positive-counter exhaustion and targeted/broadcast/direction stream
isolation. The corresponding Windows ASan runs take 56.344 and 54.547 seconds.
They inject reordered/duplicate valid unordered payloads without requiring ENet
to duplicate a packet it suppresses. These are explicit payload/wire injections,
not yet an actual lossy-UDP proxy run.

Native host patch SHA-256
`df10215b62e125d3595972e5f16e0c7b45a9b0b9141564a91f1741b413f7568b`
builds in 52.703 seconds; executable SHA-256 is
`d68f6f49e8f5aba0a00768aaa3e971d1c86cde1ff49e4784ded7fb91d28a0cf7`.
Its ownership fixture passes 156 assertions in 20.297 seconds. The actual RPC
fixture passes 18 assertions in 3.031 seconds. An 816-byte frame at an absolute
256-byte UTF-8 path submits 1,066 uncached / 819 cached packet bytes, one native
command each, below the negotiated unfragmented budget 1,364 at MTU 1,392.

The earlier MTU attempt incorrectly observed retained unreliable bytes after
Godot's immediate flush. Those bytes had already retired. Read-only native
last-submission sizes/reference deltas now establish complete packet size and
fragment count at acquisition; retained/ACK observations remain separate. The
failed attempt is preserved rather than presented as a packet-size pass.

The default production queue regression additionally fills exact aggregate
16 MiB and 16,384-message limits before one-over rejection. All 81 strict core
cases pass again in 9.344 seconds with ASan. Added Lua barrier probes initially
assumed the test method was visible: the existing Lua service facade instead
rejects that member. Protected probes accept either denied lookup or a native
false return, and verify no barrier activation in either domain.

One age-fixture attempt loses readiness before its sends; added before/after
barrier checks preserve that observation, and the next run passes all six actors.
This timing failure remains retained and is not called a reproduced persistence
or transport exploit. Terminal overflow/age testing also exposes a distinct
production cleanup defect: clearing Remote state alone leaves generic client
transport state active. `FailRemotePeer` now uses existing `disconnect_net()`
cleanup for client-session failure, preserving RF cancellation and resetting mode,
identity, replication and animation state. No second cleanup system is added.

The corrected adapter compiles in 29.109 seconds: native source fingerprint
`5dbe48210d607f256a9e1c0f13ec49a847681850939c83325f59b35d520c3e6d`,
adapter SHA-256 `47eddd9cd5aa7bfcf18cdc08572017c6032de3972d214a1b3858c1a61cb1a1cb`.
Its six actors pass in 53.688 seconds without unexpected ASan reports. The
regression requires terminal queue release, mode zero and peer identity zero.
The separate performance harness passes its first actual one-peer baseline/
candidate smoke workload; repeated 1/16/32/64-peer evidence is pending.

Remote main remains `83cd0887968d73d61d050650718d8ada6e124579`. The local `main`
reference is older (`4ea53113a98961a64347c672890f65bf9b5c8a54`); neither is changed.
The sole worktree stays on the integration branch. Pins, dormant release workflow
and updater admission are unchanged. [API/migration](remoteevent-api.md) describes
candidate behavior separately from qualification and deployment authorization.
