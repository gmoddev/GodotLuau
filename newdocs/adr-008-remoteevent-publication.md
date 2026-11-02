# ADR-008: RemoteEvent configuration and publication

Status: Phase 1 qualified at `eec2397` within the documented functional profiles;
unmerged on `integration/gl-018-gl-029-remoteevents`, preserving the original
`network/gl-029-unified-remoteevents` checkpoint. Main remains
`83cd0887968d73d61d050650718d8ada6e124579`. This is not release authorization.

The [source-pinned research](networking-architecture-assessment.md) and
[three-mode proposal](remoteevent-delivery-proposal.md) at
`9ea782bb739cc35deba06474a82582a12529df6d` remain historical inputs. This ADR
defines the narrower implemented Phase 1 contract and its compatibility choices.

## Ownership and public API

`RemoteEvent.DeliveryType` is a native property. Enum values are
`ReliableOrdered = 0` and `UnreliableUnordered = 1`; identity 2 is reserved but
`UnreliableSequenced` is absent from the public enum and rejected natively.
RemoteEvent defaults to 0. Exact numeric 0/1 are accepted before publication;
booleans, numeric strings, fractional/nonfinite/unknown values are rejected.
The canonical getter wins over metadata and a child named DeliveryType.

Client execution cannot configure a Remote, including in a listen process,
through ModuleScript ownership, native reflection or generic Godot setters.
Network client role also rejects ordinary native configuration. Editor/native
Server configuration loads before publication. Internal descriptor application
is a private C++ operation, not a bound method, Lua capability or ambient bypass.
Native constructor provenance also prevents a Client-created object in a shared
listen tree from becoming a Server publication. Cloning in Client execution does
not transfer that provenance. Remote-specific replication admission follows the
same rule; this is not a replacement for general replication authority.

First descriptor publication to any peer freezes configuration. With no peers,
configuration remains mutable until a valid local Fire or first descriptor.
Connecting a signal does not freeze it. Once frozen, even same-value writes fail;
disconnecting peers or reconnecting does not unfreeze the instance. Configure
before setting Parent to avoid racing the publication tick.

FireServer is Client execution; FireClient/FireAllClients require Server
execution. OnServerEvent subscriptions/Wait belong to Server, OnClientEvent to
Client. Existing method spellings, Player-first Server arguments, yielding,
Connect/Once/Wait, and no-result Fire methods remain. Local callback starts are
immediate after validation; no new general scheduler or transport layer exists.
Network polling still enters the existing protected domain dispatcher.

`UnreliableRemoteEventNode` remains registered and the existing public constructor
and importer mapping remain. Its mode is fixed to unordered. **Research correction:**
the inherited Lua ClassName is `UnreliableRemoteEventNode`, not an existing
Roblox-name alias; IsA accepts the inherited native names. Phase 1 preserves that
actual behavior, native inheritance and serialized identity. It does not silently
rename legacy objects or rewrite projects. Normal RemoteEvent retains its existing
RemoteEvent ClassName/IsA behavior.

Cloning copies configuration, including nested Remote nodes, but not callbacks,
waits, frozen state, transport membership or publications. Existing net-ID stripping
remains. RemoteFunction's API, wire methods, yielding, correlation/GC and timeout
behavior are unchanged; GL-030 remains separate.

## Publication and session admission

NetworkService remains the sole transport/session owner. Publication reads its
existing assigned `peer_seq_uid` identity and native connected-peer membership;
it does not create an independently authoritative account/session registry.
Each service start has a fresh native epoch. Endpoint/publication numbers are
positive checked signed-64-bit counters and are never reused in that epoch.

The Server sends a reliable descriptor containing epoch, assigned user/session,
endpoint, publication generation, replicated net ID or initial bootstrap path,
delivery mode and legacy-class identity. The Client resolves the descriptor once
to a live local ObjectID. It acknowledges that exact descriptor; the Server
validates sender and current assigned session, marks that peer ready and sends
activation. The Client can send only after activation. Unreliable traffic cannot
overtake its acknowledgement and accidentally establish authority.

Static paths are bootstrap-only: only trusted native/place Remote objects
constructed before Client role/execution are eligible. Capture records their
ObjectIDs before connecting. A replacement or Client-created object at the same
path cannot satisfy that original identity. Runtime replicas use the existing
replication net-ID map and production create/destroy ordering. Data frames contain
no target path, and never look up a replacement by name.

Same-scope reparenting retains a local ObjectID/publication. Crossing publication
scope, detaching, destruction or service teardown invalidates admission and pending
waits. Subsequent publication uses a fresh endpoint. Client descriptor replay is
fenced by the highest accepted endpoint number, without an unbounded tombstone set.
Disconnect clears readiness for that peer; reconnect requires its new assigned
session and a new handshake. Deferred work resolves native objects again.

Descriptors, activation, retirement and data handlers independently check receiver
role and actual sender. Production Server-to-Client controls use Godot authority
RPC configuration as an additional gate. The fixture may relax that gate solely
to exercise the production handler's own rejection checks.

## Event wire and bounds

Phase 1 uses an event-only bounded PackedByteArray codec. Generic replication and
RemoteFunction keep their Variant codec. It preserves the existing supported
mixed/nested/typed table representation while bounding traversal and accepting
only the supported built-in type names. No arbitrary Godot object decoder runs
on event body bytes. References resolve through admitted replicated IDs with
ServerStorage/ServerScriptService excluded; receiver dispatch and Waits capture
local ObjectIDs, rather than retaining path fallback. Local reference admission
captures identity before any callback and rejects private/dead objects.
Player references use the existing assigned peer/session identity; canonical
public scope roots use three bounded connection-local ObjectID bindings. Root
paths are captured at connection setup, never used as a data-frame fallback.
Player representation is materialized only after the complete body validates,
then captured by ObjectID. Its existing map reserves identity before native
child callbacks and revalidates liveness afterwards. Arbitrary unreplicated
path-only objects are rejected rather than silently resolved to replacements.

The version-1 frame is little endian: magic `0x31524547` (bytes `GER1`), u32
delivery, then u64 service epoch, assigned session, endpoint and publication.
The header is 40 bytes. Body values have a one-byte pinned Godot 4.7.1 Variant
type tag, with only NIL/BOOL/INT/FLOAT/STRING/VECTOR3/COLOR/ARRAY/DICTIONARY allowed.
Integers/doubles are 8 bytes, components are doubles, UTF-8 strings and collections
have checked u32 lengths/counts; trailing bytes, duplicate dictionary keys and
unsupported tags fail. Format changes require a versioned migration.

Limits are native, shared by local/network preflight where applicable:

| Resource | Phase 1 limit |
| --- | --- |
| arguments | 64, preserving nil positions |
| complete event frame | 65,536 bytes, including 40-byte header |
| unreliable body | 768 bytes and at most 900 bytes in the existing encoded argument-Array measure |
| traversal | 4,096 value/key nodes; encoded depth below 16 |
| strings/numbers | valid UTF-8 without embedded NUL; finite numbers, with integer conversion range-checked in the event encoder |
| publications/registered Remote identities | 4,096 |
| descriptor production | 64 new peer descriptors per service tick |
| subscriptions or Waits | 256 per Remote per side, within existing domain limits |
| receive admission | 256 frames/1 MiB per peer per tick; 2,048 frames/8 MiB service-wide per tick |

Counts are checked before body collection construction/iteration. Invalid payloads
are rejected before local/broadcast callbacks. Broadcast readiness is preflighted
for every current recipient before submitting frames; a not-ready destination
raises a useful error. Actual transport rejection may still follow partial fanout;
there is no all-peers transaction or exactly-once gameplay guarantee. No unbounded
startup queue hides readiness errors.

Reliable receive overload terminates that connection instead of silently dropping
accepted work on a healthy stream. Unreliable overload drops. Invalid frames
never allocate attacker-selected endpoint state or dispatch callbacks. Read-only
`GetRemoteState` exposes bounded publication/admission diagnostics; identity
numbers are freshness data, not credentials or gameplay authorization.

The body cap leaves transport framing room but is not a universal MTU guarantee.
Godot's outer RPC Variant parser, ENet fragmentation and backend retention remain
separate engine boundaries. No exact native ACK/backlog accounting, total ENet
memory bound, traffic scheduler, lossless overload promise or priority policy is
claimed. Phase 2 must qualify those measurements/admission boundaries explicitly.

## Lifecycle and qualification

Functional ENet fixtures explicitly use `throttle_configure(5000, 32, 0)` on
actual loopback links, including replacement connections. They assert the
configured profile rather than assuming adaptive unreliable delivery remains
unthrottled under instrumented startup. Production carrier defaults are unchanged.
This profile establishes functional admission/lifecycle behavior, not default
congestion, induced-loss, retention or guaranteed unreliable delivery. Those
remain separate Phase 2 qualification requirements.

Retained event/signal closures use ObjectID wrappers. Dispatch checks liveness
between callbacks, Once disconnects before invocation, and waits carry exact
Remote-generation guards. Retirement cancels the exact waiting coroutine through
the existing domain cancellation path; it does not cancel all work owned by a
shared ModuleScript. Service retirement detaches publication state before owner
cancellation can reenter. Existing domain/resource guards remain authoritative.
Retirement also invalidates already queued Wait deliveries, whose registrations
have left the Remote's wait vector. A controlled real ENet poll fixture checks
that boundary separately from a Wait still waiting for its first event.

See [Phase 1 qualification](remoteevent-phase1-qualification.md) for commands,
executed cases, retained failed attempts, source/binary/harness identities and
platform/sanitizer limitations. A compile or headless simulation is not real
transport or graphical qualification. GL-003/004/005/007/009/019/020/022/023,
Character V2 and GL-017/018 limitations remain independent contracts.
