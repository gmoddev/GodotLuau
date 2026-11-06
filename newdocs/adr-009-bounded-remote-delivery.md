# ADR-009: Bounded native RemoteEvent delivery

Status: accepted, implemented, qualified and integrated through main merge `6a7fedf`
within the [documented profile](remoteevent-completion-qualification.md). User approval
on 2026-11-03 covers the narrow Godot/ENet admission adapter described in the
[decision record](remoteevent-native-admission-decision.md). This ADR extends
[ADR-008](adr-008-remoteevent-publication.md). The qualification record retains
source/product identities, failed attempts, performance costs and supported
limits. [Fresh main verification](gl018-gl029-main-integration.md) is recorded
separately; publication and updater admission remain disabled. No new VM, general traffic
scheduler or RemoteFunction contract.

## Native admission authority

Keep the pinned engine revision, ENet and existing RPC path. Maintain a source-
and output-hash-verified host patch. Use native queue ownership as the source of
truth rather than an extension estimate or application receipt. Walk the native
outgoing/sent command lists at admission, count data commands, and count each
referenced packet's full payload once per peer. A partial fragment ACK retains
the packet's full charge while any native command still owns it. Retransmission
must not create a second packet charge; native destruction/reset releases it.
Shared broadcast packets are conservatively charged independently to each peer.

Qualified native data ceilings for the admitted profile:
4 MiB retained payload and 4,096 retained data commands per peer; 16 MiB and
16,384 commands per host. The ceilings cover admitted data packets, not total
process RAM, allocator overhead, Godot RPC predecode storage or ENet control/ACK
queues. Command counts separately bound packet/fragment metadata. Candidate
admission includes the complete packet and the exact number of native fragments.
The maximum supported Remote frame must fit one native admission opportunity.

The guard runs at the native send boundary for targeted sends and broadcasts.
Check peer and host limits together before enqueue; reject without retaining
the candidate packet or changing previous ownership. Low-level wrappers must
destroy a packet rejected before ownership transfer. RPC send errors must reach
the extension, rather than being converted to successful handoff.

Expose a read-only versioned native admission snapshot through the host API.
No gameplay limit setter, raw ENet pointer, fake ACK or second session authority.
NetworkService checks this capability before activating the stronger protocol.
Stock-host use cannot silently acquire the new guarantees. Document the patched
host requirement and exact engine/patch identities for project deployment.
Read-only last-submission byte/command observations support complete-RPC MTU
qualification. They describe actual native packet ownership acquired before the
transport's immediate flush, separately from retained bytes and ACK retirement.

## Remote-owned work

NetworkService remains the sole service/session owner. New bounded Remote queues
own immutable encoded work after admission, independent of the submitting Lua
thread. Keep existing immediate local callback starts. Network work drains at
the existing main-thread service tick, outside native callbacks. Per-peer fair
rotation and independent byte/message budgets prevent one stalled peer from
holding others. Native WouldBlock retains reliable work until capacity or an
explicit affected-peer failure; never silently expire accepted reliable work
while calling its stream healthy. Unreliable overload can drop with counters.

Sequenced delivery adds one native stream per live peer/session/direction/Remote
publication. Checked positive signed-64-bit sequences never wrap or share state
across Remotes or peers. Completely validate a frame before advancing freshness;
reject older/equal samples. At most one unsent sample per stream can be replaced
by a newer validated candidate. Check message/byte deltas before replacement so
rejected larger work leaves the previous sample intact. Once handed to ENet or
a running callback, work is no longer supersedable. No reliable event coalescing.

Every queue/watermark is tied to existing native epoch/session/endpoint/generation
and ObjectID, with exact cleanup on retirement, disconnect, service replacement
and shutdown. The event wire/capability version must change explicitly before
exposing the third enum member. Preserve the legacy unordered class and existing
public Fire/Connect/Once/Wait shapes. GL-030 remains separate.

## Qualification and migration

RPC admission includes a native call-context check: actual target ObjectID,
method, non-local sender, received transfer mode and channel. A reflected method
call or method name alone cannot establish transport provenance. Preserve that
context across nested native polling and restore it when the call returns.
SceneRPC must propagate transport send errors through `rpc_id`. On native
WouldBlock, the Remote-owned reliable queue retains its data. An unbuffered
reliable RPC explicitly terminates its affected peer rather than silently losing
work while the session appears healthy. This is a transport exhaustion outcome,
not a new RemoteFunction timeout or retry policy.

Before closure, require deterministic exact-full/one-over admission, fragment
retention/ACK/reset, rejection cleanup, broadcast fanout and peer isolation.
Exercise actual ENet with slow/non-ACKing receivers, loss/reorder/duplicates,
independent streams, counter exhaustion and lifecycle cancellation. Measure full
RPC packet sizes and declare the supported MTU/path profile. Repeat comparable
baseline/candidate traffic and teardown workloads; report costs, not assumed wins.
Run the complete existing Windows/Linux Debug/Release, core/native sanitizer and
source-product/companion packaging gates against the qualified patched hosts.
Keep GL-018's admitted host/sanitizer limits and all prior failed evidence visible.
An adapter compile or engine-only probe is not production qualification.
