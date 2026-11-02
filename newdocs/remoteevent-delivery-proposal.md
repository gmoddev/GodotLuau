# Unified RemoteEvent delivery API and migration proposal

Status: **proposed, not implemented or accepted**. Companion to the
[source assessment and roadmap](networking-architecture-assessment.md).
Source baselines, limitations and reference labels G/A/E are defined there.
This document defines the recommended target contract; it does not authorize
runtime changes or promise current behavior.

## API and delivery meaning

```luau
local Remote = Instance.new("RemoteEvent")
Remote.DeliveryType = Enum.EventDeliveryType.UnreliableSequenced
Remote.Name = "AimState"
Remote.Parent = game:GetService("ReplicatedStorage")

Remote.OnServerEvent:Connect(function(Player, Aim)
    -- Validate gameplay authorization and values here as well.
end)
-- Client: Remote:FireServer(Aim)
-- Server: Remote:FireClient(Player, Aim) / Remote:FireAllClients(Aim)
```

Configure before parenting/publication. `Connect`, `Once` and `Wait` remain on
`OnServerEvent` / `OnClientEvent`, with existing Player-first Server arguments,
payload argument order and yielding callback ownership. The Fire methods keep
their existing names, parameters and no-result surface.

| Enum member | Proposed stable numeric value | Contract |
| --- | ---: | --- |
| `ReliableOrdered` | 0 | Default. Accepted events use reliable ordered delivery while their connection and endpoint remain valid. Preserve send order within a sender/destination/Remote stream. Never silently downgrade, supersede or discard accepted work on a healthy active stream. |
| `UnreliableUnordered` | 1 | Best effort; loss and reorder are allowed. No application freshness guarantee. Do not add an application stale/duplicate filter. Native transport may suppress duplicate packets, so duplication is allowed rather than required. |
| `UnreliableSequenced` | 2 | Best effort, with independent stream sequence checks. A newer valid frame makes older/equal frames stale; a newer unsent entry replaces the previous unsent entry for that same stream. No eventual-delivery guarantee. |

Only modes implemented and qualified in a phase appear in its public enum.
P1 publishes the first two members; P3 adds the third. Unknown/unavailable values
raise an explicit error, never fall back to another carrier.

“Ordered” describes event dispatch/start order, not completion order of yielded
handlers. It promises no order between different Remotes, directions, recipients,
replication, physics, Character or animation. Reliable transmission is not an
exactly-once gameplay-effect guarantee. Application retries can create new events.

Sequenced mode treats the **whole argument tuple as one replaceable sample**.
It is appropriate for aim/cursor/cosmetic state. It must not be used for purchases,
damage, inventory commands or individually necessary actions. Separate state
channels require separate Remote instances in the first API; do not add a
caller-selected channel or a hidden field merge policy.

## Native configuration, publication and mutation

DeliveryType is a real native enum-backed property, not metadata or a mutable
Lua capability table. Getter returns the canonical integer enum representation
used by the existing stdlib. Before conversion, setter accepts only the exact
supported integer values; reject boolean, numeric string, fraction, nonfinite
number, table and unknown value. Invalid writes leave configuration unchanged.
Use a raw Variant/native validation boundary where Godot binding coercion could
otherwise conceal an invalid input, following the existing GL-020 lesson.
Reserve canonical property lookup before arbitrary metadata or same-named child
fallback; a child named DeliveryType must not impersonate configuration.

| State | Allowed behavior |
| --- | --- |
| Configurable | Trusted native/editor scene load or a live native Server-domain owner can configure an unpublished Remote. Client owners cannot, including in a combined listen process. |
| Published/active | First server publication to a peer freezes the instance configuration. Offline/local first Fire also freezes it. Connecting signals alone does not freeze it. The descriptor carries its selected mode to all present and future peers. |
| Retired | Destroy, service/scope exit or publication retirement prevents old work from dispatching. Old identity never resolves to a replacement at the same name/path. |

Once published, all gameplay writes are errors, even a write of the current value.
Disconnecting the final peer does not unfreeze the instance. To change mode,
create and publish a new Remote; retire the old instance explicitly. This avoids
mode epochs, in-flight reliable drains and toggle-based quota evasion in the
first design.

Clone/scene persistence copies **configuration only**. A clone gets a new native
ObjectID, new endpoint publication and fresh runtime counters; it never inherits
callbacks, waits, peer membership, queue entries, frozen runtime state or sequence
watermarks. Do not persist service/session identifiers. Same-service reparenting
preserves endpoint identity; crossing the publication/service scope retires it.

Apply identical native authority checks to Lua property assignment, generic
`set`/`call`, reflection, constructor defaults and replicated updates. Lua enum
tables, role globals, attributes named DeliveryType, class names and payload
fields cannot grant authority. Internal replica application must not enter a
general “Client may write” scope that a callback can inherit. Follow GL-007's
native-before-Client-callback pattern rather than an exposed bypass flag.

Server publication is an explicit bounded descriptor containing endpoint
identity, publication generation and delivery mode. A client validates its local
replica type/configuration and acknowledges readiness before that peer's endpoint
becomes active. A newly joined client does not infer mode from the first data
packet. Unknown endpoints, mode mismatches and future/stale descriptors fail
closed. A locally fabricated Remote cannot register itself for inbound authority.

Existing `Instance.new(Type, Parent)` remains valid with its class default. Code
that needs a nondefault mode constructs without Parent and configures first;
setting a static/already published Remote from a late startup script is an
intentional configuration error. Editor-authored DeliveryType is loaded before
publication. The implementation ADR must specify that startup barrier precisely,
including dynamically created and late-join instances.

## Sequencing, supersession and lifetime

Use separate native types for endpoint publication, event sequence and request
identity. They are never Character sequence, animation epoch, `_gl_netid`,
Player.UserId, ENet sequence or a future replication cursor.

One logical sequenced stream is:

```text
(local service/transport generation,
 live assigned peer session, direction,
 Remote endpoint identity, peer publication generation,
 native Event channel)
```

The first version has exactly one native Event channel per Remote. It is a
semantic discriminator, not an ENet channel or a public user key. The Server
derives the sender from the current transport and assigned session; no supplied
peer number selects the stream. S2C sending and C2S receiving have separate
state. Each recipient of a broadcast has its own stream/counter, shared with
targeted FireClient calls to that recipient. Broadcast may serialize one immutable
payload once, but still charges each destination and validates its publication.

1. Start a native positive sequence at one. Never expose sequencing authority to
   Lua or round-trip it through a Lua floating-point number. Use a checked
   positive 63-bit range for compatibility with Godot's signed integer boundary,
   or an explicitly encoded full-width binary field with equally checked limits.
2. Refuse the next send/publication before exhaustion; do not wrap, reset within
   the same publication or reuse an old identity. Report a terminal affected
   stream/peer outcome and require a fresh trusted publication/session. Tests
   seed counters near the boundary without sending billions of events.
3. Validate native role/session, endpoint, publication, carrier/mode, canonical
   field types, size and reference scope **before** changing any watermark or
   allocating per-key state. Unknown attacker-created keys do not create entries.
4. At receive admission, reject sequence less than or equal to the highest valid
   admitted sequence for that exact stream. A valid newer frame advances the
   watermark even if later unreliable dispatch admission drops it, so an older
   frame cannot resurrect superseded state. Invalid/unauthorized frames cannot
   poison watermarks. Recheck endpoint/owner liveness before dispatch.
5. Sender queue keeps at most one unsent sample per stream. Replace only with a
   strictly newer, completely validated sample. Compute checked byte/message
   deltas before committing replacement; failed larger replacement retains the
   earlier valid entry. Bound distinct keys and aggregate bytes as well as entries
   per key. A flood of Remotes/peers cannot evade a one-entry rule.
6. Newest-wins ends at handoff. Never reach into ENet queues or cancel an already
   started callback/Wait resume to imitate supersession. Receiver stale checks
   handle delayed packets after handoff. A lost newest packet may leave the last
   observed state unchanged indefinitely; applications needing a refresh send one.
7. Disconnect, reconnect, Remote destruction/replacement, peer publication change,
   service exit and scene replacement remove the exact generation's pending
   entries/watermarks. New transport/session/publication identities fence old
   datagrams and deferred work; clearing a map alone is insufficient replay
   protection. Reused peer numbers and NodePaths cannot resurrect an endpoint.

Native session/publication serials are freshness identities, **not credentials**.
They do not authenticate a user or authorize a gameplay action. Reuse existing
live native transport/UID admission; do not introduce a second independently
authoritative session map. Any additional transport generation is local lifetime
bookkeeping attached to that owner and replaced on transport replacement.

## Wire and transport proposal

Keep ENet and the production RPC dispatch infrastructure. Map ReliableOrdered to
Godot reliable transfer. Map both unreliable modes to Godot **unordered** transfer,
with application sequencing above it. Ordered-unreliable on shared channel 0
cannot isolate Remote A from Remote B [E1–E2 in the assessment].

Negotiate one explicit Remote protocol/capability version before activating
application endpoints. Bind descriptors through existing replicated IDs where
available and validated static-place bootstrap paths otherwise. Path lookup is
only initial binding to a local ObjectID; it is never repeated as fallback when
dispatching an old data frame. Keep `_gl_netid` semantics for other subsystems.
Do not send raw local ObjectIDs as if they were global cross-process IDs.

Candidate event header, **not a frozen wire layout**:

| Field | Candidate encoding / validation |
| --- | --- |
| Magic, RemoteVersion | 4-byte discriminator and u16 exact supported version |
| MessageKind, DeliveryType | u8 each; legal combination must match the native descriptor and actual received carrier |
| Session, Endpoint, Publication | Three u64 binary identities, nonzero and matched to the admitted connection/publication; not arbitrary object paths |
| EventSequence | u64; positive only for sequenced events, zero for unsequenced/reliable events in this candidate |
| BodyLength | u32, exact remaining bytes, checked before body decoding |

That candidate is 44 bytes before the bounded argument body and Godot RPC/Variant
framing. Request/cancellation/response identity uses a distinct future schema;
do not overload EventSequence or accidentally ship a new request protocol here.
The final ADR must define byte order, exact lengths, allowed flags, trailing-byte
rejection and version changes before implementation acceptance.

Prefer a bounded PackedByteArray argument for the new event envelope, followed
by bounded decoding of the existing compatible Variant payload, rather than a
freely typed Array RPC that has already expanded before the handler checks it.
Check the raw wire Variant kind before coercion. Keep Godot object decoding
disabled. This bounds the inner application decoder; it does **not** establish a
bound on all Godot RPC envelope parsing or all native allocations. Include that
engine boundary in hostile/large-packet qualification.

Reference decoding for Remotes receives native peer/publication context. It may
resolve only admitted, live, peer-visible instances. No arbitrary root path or
global `_gl_netid` fallback confers knowledge of ServerStorage or a replacement.
Keep generic replication/physics codec consumers unchanged; add explicit
Remote-specific context rather than globally changing the shared helper's meaning.
Visible but not yet materialized references initially cause explicit reliable
admission rejection. A later bounded dependency queue may defer reliable work;
unreliable work never waits for materialization. Neither silently changes an
unresolved reference to a replacement or invents cross-channel ordering.

All peers in a session must use a supported matching protocol. Existing Godot
RPC method-set checksums can reject mixed builds before a custom error [E3].
Do not promise mixed old/new wire interoperability or silently downgrade
UnreliableSequenced. Source/project migration is a separate compatibility goal.

## Bounds, failure and callback behavior

The following are **provisional review/fixture values**, not current limits,
approved shipping defaults or measured capacities. Calibrate before acceptance;
never copy Gargantuan's much larger manager ceilings without Godot workloads.

| Resource | Initial review candidate |
| --- | --- |
| unreliable application arguments | At most existing 900 bytes, further reduced so the entire new RPC/envelope fits the qualified datagram budget |
| reliable event body / argument count | 64 KiB / 64 arguments; explicitly test compatibility impact of introducing a cap |
| value traversal | Preserve supported depth 16; additionally bound visited nodes (candidate 4,096), strings and total decoded/native charge |
| per-peer unsent reliable queue | 1 MiB and 1,024 records, with finite trusted admission policy |
| service-wide unsent reliable queue | 16 MiB and 16,384 records |
| unreliable queued work per peer | At most one configured flush byte/message budget; one sequenced sample per valid stream |
| aggregate send/decode/dispatch | Independent trusted per-peer and per-service byte/message/work budgets; receive fanout/handler count are charged before dispatch |

The final valid configuration must accommodate one maximum supported frame in
its flush budget. Incompatible peer advertisements reject startup or negotiate
downward, never raise a native ceiling. Limits are trusted native policy;
DeliveryType does not let Lua select priority, an unlimited budget, transport
channel, raw peer handle or reliability bypass. New hard limits intentionally
reject some formerly unbounded inputs; document exact limits and migration.

Admission, queue residence, ENet submission and remote dispatch are distinct
observations. Record them separately with bytes, messages, high water, drops,
supersessions, stale/role/session/mode rejections and terminal reasons. ENet RTT
or loss may be available; native ACK retirement/queued bytes may be unavailable.
Represent unavailable measurements explicitly. Bound per-peer/endpoint diagnostic
state, use monotonic counters and bounded `[Network:Remote]` logs, and never log
payloads by default.

Reliable FireServer/FireClient invalid input or failed admission raises a useful
error before new work is accepted. Once accepted, reliable work is retained until
handoff or explicit endpoint/session failure; no silent TTL drop while reporting
a healthy stream. A peer that cannot honor a hard reliable backlog policy must
fail explicitly and release its charge. Do not fail unrelated peers or a whole
server. Native ENet retention after handoff remains the separate unresolved
admission/measurement gate in the assessment; these candidate queue caps do not
solve it. No application-ACK shortcut is proposed as native ACK evidence.

Unreliable congestion, stale state and pre-activation loss may drop work with
counters; invalid caller input still errors. Reliable Fire before activation in
P1 reports “Remote not ready”; it does not allocate an unbounded startup queue.
P2 can add a bounded explicit readiness queue under the same owner. The existing
silent preconnection drop is not relabeled reliable acceptance.

Broadcast validates/encodes the argument tuple before any local callback. Charge
logical fanout before per-peer copies; snapshot eligible peer generations and
revalidate each destination. Per-peer admission can fail independently; there is
no all-peers atomic broadcast guarantee. Aggregate invalid input rejects the
whole call before side effects; a terminal slow peer can fail while healthy peers
and the host receive once. Keep the public no-result method; expose partial
admission through bounded native diagnostics, not a success fiction. Do not throw
a late payload-validation error after the host callback has already run.

Local/listen delivery uses the same property, payload and lifecycle admission;
it need not serialize a physical packet or artificially lose valid local data.
Preserve existing immediate local callback-start behavior and protected owner
dispatch. Network receive queues drain at a defined safe point after transport
polling; callbacks must not be introduced inside ENet/native-worker callbacks.
That scheduling distinction is documented, not a promise of identical frame timing.

After admission, encoded outbound work is owned by the Remote/service/session,
not a raw Lua thread. Retiring the sending Script does not retract an already
accepted Fire. Remote/session retirement cancels unsent work by exact identity;
already handed-off bytes cannot be recalled. Inbound callbacks/Waits retain their
existing owning Script/ModuleScript and GL-004/022 guards. A running callback may
finish/yield normally while its owner lives; supersession does not undo its
effects. No new callbacks begin after endpoint retirement. Cancel outstanding
Remote Wait registrations through existing domain cancellation and release their
references without delivering stale arguments or canceling unrelated owner work.

## RemoteFunction stays separate

| Option | Assessment |
| --- | --- |
| Writable EventDeliveryType | Reject. Unreliable requests/responses invalidate completion and retransmission assumptions. |
| Read-only DeliveryType = ReliableOrdered | Technically possible, useful for generic inspection, but misleadingly applies an event enum to two correlated directions and deadlines. Adds a public field without functional benefit. |
| Omit DeliveryType | **Recommended.** Keep a distinct internal ReliableRequestResponse contract. No unreliable event mode can change request, response, cancellation or error delivery. |

Do not add DeliveryType to RemoteFunction's supported property list. Explicit
attempts to configure that reserved delivery setting should error rather than
silently create inert metadata. Existing unknown-property behavior and any
project collision with that name must be characterized before adopting the guard.
Keep `InvokeServer`, `InvokeClient(Player, ...)`, `OnServerInvoke` and
`OnClientInvoke` spelling and successful handler yielding. Do not copy
Gargantuan's provisional peer table or different handler setter API.

The target request state machine is native and session scoped:

```text
Admitted -> Pending -> exactly one of
Success / RemoteError / Timeout / Cancelled / PeerDisconnected /
RemoteRetired / ServiceStopped / ProtocolRejected / ResourceRejected
```

Take/detach the pending record and accounting before running a completion or
Lua resume, so reentrancy cannot settle it twice. Match response to expected
transport sender, current session, endpoint publication and full-width request
ID. Reject duplicates, old sessions, narrowed IDs and exhaustion. Retain native
owner cancellation, protected resumption and manual-resume protection. No
automatic retry is allowed: a lost response or cancellation cannot prove that
the remote gameplay effect did not occur, and cancellation is not rollback.

**Current gap:** GodotLuau's public invokes pass timeout zero and later age out
network maps without a terminal wakeup [G4, GL-030]. Do not claim this target is
already implemented or silently change it in the event-property PR.
Recommended separate P4 policy: a finite trusted default (candidate ten seconds,
maximum thirty seconds) and additive explicit timeout methods, with all existing
successful argument/return/handler behavior retained. A finite default changes
the historical infinite-wait compatibility contract and needs explicit ADR/API
migration approval. Expiry must complete and release the wait, not just GC a map.

## Legacy RemoteEvent migration

1. Continue registering/loading `UnreliableRemoteEventNode` and accepting
   `Instance.new("UnreliableRemoteEvent")`. It remains an ordinary native subtype
   with DeliveryType fixed to UnreliableUnordered. Keep its existing ClassName,
   IsA and saved scene/import identity. A conflicting property write is an error.
2. Plain RemoteEvent defaults to ReliableOrdered. Existing projects that never
   configure it retain reliable delivery. Do not infer a mode from a name, payload
   size, call frequency, class metadata or first packet.
3. New projects use `RemoteEvent` plus configuration before Parent. Migrate an
   old unreliable object by explicitly replacing its class with RemoteEvent and
   persisting UnreliableUnordered. This creates a new publication/lifetime at
   runtime; migrate editor/project data offline, not a live object in place.
4. Keep the old constructor/serialized loader for an indefinite compatibility
   period until a separately authorized versioned removal and project inventory
   justify otherwise. At most emit one bounded opt-in migration diagnostic;
   do not flood games or auto-rewrite assets/archives/declarations.
5. Document new strict validation, smaller effective unreliable payload budget,
   native bounds, startup readiness errors and frozen-property errors. Add
   golden old-project load/clone and source migration fixtures. The legacy class
   shares the new admission/authority rules; it is not an escape hatch into an
   unbounded or unvalidated legacy transport path.

The assessment's Q1–Q14 requirements and phase gates are the acceptance plan.
No runtime, tests, saved assets, dependency pins, main, releases or updater
distribution change in this research task.
