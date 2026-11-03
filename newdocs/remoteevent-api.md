# RemoteEvent candidate API and migration

Status: implementation under qualification on
`integration/gl-018-gl-029-remoteevents`; unmerged, not a distribution channel.
[ADR-008](adr-008-remoteevent-publication.md) defines publication/authority and
[ADR-009](adr-009-bounded-remote-delivery.md) extends native admission/delivery.
The [work record](remoteevent-completion-work.md) is the verification source.

| API | Contract |
| --- | --- |
| `Remote.DeliveryType` | Native enum: `ReliableOrdered = 0` (default), `UnreliableUnordered = 1`, `UnreliableSequenced = 2`. Server configuration before publication; frozen afterward. Client writes and invalid enum values fail. |
| `Remote:FireServer(...)` | Client to Server. `OnServerEvent` receives the actual Player before the supplied arguments. |
| `Remote:FireClient(Player, ...)` | Server to the selected live Player/session. |
| `Remote:FireAllClients(...)` | Server fanout with separate per-peer streams. Local listen-host callbacks retain immediate behavior. |
| `OnServerEvent`, `OnClientEvent` | Existing `Connect`, `Once`, `Wait` and connection ownership/cancellation semantics. A Once connection detaches before callback invocation. Yielding callbacks can overlap; ordering concerns callback starts. |

```luau
local Position = Instance.new('RemoteEvent')
Position.Name = 'Position'
Position.DeliveryType = Enum.EventDeliveryType.UnreliableSequenced
Position.Parent = game.ReplicatedStorage
```

Legacy `UnreliableRemoteEvent` construction and saved
`UnreliableRemoteEventNode` scenes retain their actual native class identity and
fixed unordered delivery. Plain RemoteEvent remains reliable by default. No
automatic scene/project migration or asset regeneration is performed.

## Delivery and failures

Successful network Fire returns after bounded application admission, or after a
permitted unreliable drop. It does not acknowledge remote receipt, callback
completion, native ACK retirement or a persisted gameplay effect. Reliable work
remains owned by its Remote/session after the submitting script exits or dies.
Explicit Remote/publication retirement can cancel its pending work.

Reliable overload of one peer marks that peer for terminal failure; other healthy
fanout destinations may proceed. Global queue/allocation rejection happens before
fanout commit and returns an error. Previously admitted work remains intact.
Native WouldBlock keeps reliable work queued. A reliable queue residence beyond
10 seconds, or a non-retryable handoff failure, explicitly ends the affected
session. There is no silent reliable TTL while the session is called healthy.
An unbuffered reliable control RPC also terminates its affected session on native
admission exhaustion. This adds no RemoteFunction timeout or gameplay retry.

Unordered work can drop, reorder or repeat valid payloads. It has no application
freshness filter. Sequenced work uses a native positive 63-bit counter per live
peer/session/direction/Remote publication. Only a fully validated newer received
sample advances freshness. Counter exhaustion returns an error without wrapping
or replacing accepted work; publish a fresh Remote or session. A transform of a
sequence number through Lua floating-point values is not part of this API.

Sequenced mode retains at most one **unsent** sample per stream. A newer candidate
replaces it only after validation and capacity checks. A rejected larger sample
leaves the old sample intact. Native-submitted work and already admitted incoming
samples are not superseded. For example, incoming 3,1,2,3,4 starts callbacks for
3 and 4. A lost newest sample is not guaranteed delivery. Both unreliable modes
discard application-queued work older than 250 ms, with accounting.

## Limits and execution

| Ownership boundary | Candidate ceiling |
| --- | --- |
| Event frame / codec | 65,536 bytes including 48-byte GER2 header; 64 arguments, 4,096 nodes, depth 16 |
| Unreliable encoded body | 768 bytes, additionally checked against negotiated native unfragmented budget |
| Outgoing application queues | 1 MiB / 1,024 messages per peer; 16 MiB / 16,384 aggregate |
| Incoming application queues | 1 MiB / 256 messages per peer; 8 MiB / 2,048 aggregate |
| Native retained data | 4 MiB / 4,096 data commands per peer; 16 MiB / 16,384 per host |

Application byte charges describe encoded frame sizes, not total decoded Variant
or allocator memory. Native data limits exclude control/ACK queues, receive
predecode storage and total process RAM. Partial ACK retains the full packet
buffer charge until its last native data-command reference retires. Shared
broadcast buffers are conservatively charged once per owning peer.

NetworkService drains at its existing main-thread tick with rotating peer turns,
byte/message/work bounds and between-message time slices. A 4 ms slice is not
preemption of a running Luau callback. GL-004's shared-domain execution/memory
policy remains authoritative. Local immediate delivery does not acquire a second
scheduler or VM.

## Host and protocol compatibility

Network startup requires the admitted host in
[`RemoteAdmissionHost.json`](../tests/runtime/RemoteAdmissionHost.json), including
actual native RPC context and error propagation. Stock hosts return startup
failure before activating transport. Build commands and scope are in the
[runtime instructions](../tests/runtime/README.md). Engine/submodule pins remain
unchanged; the extension package does not distribute a patched engine.

GER2 explicitly changes the event frame to magic `0x32524547`, delivery (32 bits),
epoch/session/endpoint/publication/sequence (five 64-bit fields), then the bounded
body. Reliable/unordered frames require sequence zero. Descriptors require nine
fields with protocol version 2. GER1/old descriptors and incompatible modes are
rejected; no silent downgrade or reinterpretation is supported. All peers need
the same candidate protocol. Other qualified RPC payloads remain unchanged.

NetworkService's absolute node path is limited to 256 UTF-8 bytes. The candidate
reserves 384 bytes above the event frame for complete RPC framing and checks the
actual negotiated ENet budget. Initial Windows ASan measurements at MTU 1,392
observe 1,066 uncached / 819 cached script-method packet bytes for an 816-byte
frame. The supplemental real UDP fixture observes an actual native NetworkService
method submitting that frame as an 820-byte cached packet at the maximum path.
Each uses one command, below the 1,364-byte unfragmented budget. Final independent
Debug/Release qualification is still required. This is the existing UDP path,
not an unqualified DTLS, relay or arbitrary network MTU guarantee.

The [qualification record](remoteevent-completion-qualification.md) reports the
measured cost of deferred dispatch: higher response latency and better frame
progression in the bounded Debug ASan echo workload. It does not promise a
Release speed improvement or successful 64-peer performance qualification.

`NetworkService:GetRemoteState(Remote)` and `GetRemotePeerState(Peer)` expose
read-only queue/counter/identity diagnostics. Queued, submitted, superseded,
dropped, stale and failed counts describe distinct boundaries. Native last
submission sizes are separate from retained ownership. Qualification barriers
exist only in the native test adapter and reject gameplay Lua in both domains.

Releases and updater distribution remain disabled. GL-030 stays a separate issue.
