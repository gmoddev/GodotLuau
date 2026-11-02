# Networking architecture assessment and adoption plan

Status: research and proposed design, **not accepted architecture or implemented
functionality**. Reviewed 2026-11-02. This change modifies documentation only.

## Scope, revisions and evidence

| Input | Immutable revision | Meaning |
| --- | --- | --- |
| GodotLuau | `83cd0887968d73d61d050650718d8ada6e124579` | Verified local and remote main; parent of this research branch |
| Gargantuan | `e682be08df84d776bfa455137728265c6494b5e8` | Remote main and clean read-only sparse source snapshot |
| Godot | `a13da4feb8d8aefc283c3763d33a2f170a18d541` | Pinned 4.7.1 source used to inspect the actual ENet/RPC implementation |
| Separate GL-018 follow-up | `0e61db4a418c606deff50fad27f9831dc6204981` | Published, unmerged qualification evidence; not silently included in this branch |

Both root contribution policies, documentation authority indexes, relevant
invariants, networking decisions, source paths and qualification records were
read. The [source index](#source-index) identifies the implementation boundaries;
[research inputs](evidence/networking-research-inputs.json) record normalized
source hashes and scope. Inspection used Git, `rg`, targeted source reads and
the GitHub connector. No engine, game, benchmark, sanitizer or security scan was
run for this assessment. A source trace is not a reproduced exploit. Historical
test results below remain results for their recorded sources/configurations.

## Recommendation

Adopt the **semantics** of Gargantuan's delivery modes, independent identities,
bounded admission, observable loss and explicit lifecycle ownership. Extend the
existing `NetworkService`, Remote nodes, codec and domain dispatcher. Keep ENet,
Character V2, the Server/Client domains and current authority implementations.

Prioritize a single configurable `RemoteEvent`. Its proposed contract is in
[Remote delivery API and migration](remoteevent-delivery-proposal.md). It defaults
to `ReliableOrdered`; configuration is native Server-owned, replicated and frozen
at publication. Preserve `UnreliableRemoteEvent` as an unordered compatibility
class. Keep `RemoteFunction` separate and omit an event-delivery property.

This is not a direct import of an existing unified Gargantuan API: Gargantuan
currently exposes **three event classes**, plus `RemoteFunction` [A1, A2]. Its
public `FireClient` peer slot/generation arguments and provisional peer callback
table must not replace GodotLuau's existing Player API [A1, G1].

The first implementation should deliver the reliable/unordered vertical slice
with authoritative configuration and admission, rather than introduce a large
general-purpose networking framework. Add the sequenced mode after its queue,
identity and receiver rules exist. Do not expose a mode that silently behaves
like a different mode.

## Current architecture comparison

| Boundary | GodotLuau implemented now | Gargantuan implemented now |
| --- | --- | --- |
| Ownership | One Godot `NetworkService` combines transport, players, replication, Remote dispatch, physics, chat and Character state. Domain hosts own Lua scheduling [G2, G4]. | `GameSession` composes scheduler, transport, replication, Remote and Character managers. DataModel/MutationGateway remain separate authorities [A3, A9]. |
| Event API | `RemoteEventNode::reliable=true`; derived `UnreliableRemoteEventNode` sets false. Same Fire/signal methods; two pairs of RPC handlers [G1, G2]. | Reliable, unordered and sequenced event classes share `RemoteEventBase`. Manager derives message kind from registered class [A1, A2]. |
| Delivery | Reliable RPCs and unordered unreliable RPCs, all configured on channel 0. No application Remote sequence or unsent supersession [G2]. | Three explicit modes; strong Remote sequence, per-peer publication lifetime, stale rejection and scheduler supersession [A2–A5]. |
| Endpoint identity | Remote RPC target is a NodePath resolved at receive time. Argument Instances use `_gl_netid`, with path fallback. Local userdata use Godot ObjectID [G1–G3]. | Generation-safe ObjectId, ConnectionId, replication epoch and RemotePublicationId, checked again at dispatch [A2, A4]. |
| Admission | Outgoing unreliable encoded argument Array has a 900-byte check. Recursive network conversion caps depth at 16. These are not complete receive, aggregate, native-memory or dispatch budgets [G1, G3]. | Peer/session/manager limits for bytes, calls, handlers, requests, dispatch and broadcast amplification, with explicit results [A4, A5]. |
| Requests | Reliable RPCs; expected transport peer map, owner cancellation, yielding handler wrapper, disconnect/service failures. Current public calls pass timeout zero; GC separately erases old records [G4]. | Finite request deadlines, cancellation, peer/publication scope and one detached terminal completion. Generated error traffic is bounded [A4, A6]. |
| Structural replication | Native create/property/reparent/destroy RPCs, replication shadows, stable IDs mapped to ObjectIDs, initial world shared from the place. Incremental changes are generally broadcast, with late-join synchronization [G2, G5]. | Schema-checked binary GRPL; per-peer desired/known/materialized views; dependency-safe prepared groups, immutable templates and bounded coalescing/admission [A8, A9]. |
| Character | Protocol 3, native Server health, life/epoch/tombstones, bounded client-pose plausibility, correction grants, remote interpolation and owned animation [G6]. | Semantic inputs, server simulation, acknowledged input history and reconciliation; separate compact GCHR batches, materialization generations, cadence tiers and fair publication [A10]. |
| Testing/diagnostics | Real ENet fixtures for listen/dedicated/editor roles, latency proxy, authority/animation/lifetime tests, frame and performance probes; ping and animation snapshots. No unified Remote queue-accounting view [G7]. | Deterministic simulator plus real localhost GNS and composed-session fixtures; optional transport statistics and separate scheduler/Remote accounting [A5, A7, A11]. |

### Verified gaps and counterevidence

The following are source findings, not newly reproduced runtime failures:

- `_re_deliver_*` and `_ure_deliver_*` converge on `_deliver_event` without
  checking the target Remote's configured reliability, a per-peer publication
  generation or a receive-side 900-byte rule. The existing direction checks
  (`is_server`, sender 1) are useful, but are weaker than the existing
  `GetClientRpcSender` / `AcceptServerRpc` session checks used elsewhere [G2].
- NodePath targets and Instance path fallback do not prove peer publication or
  reference visibility. A replacement at the same path is not an endpoint
  generation. Do not generalize qualified GL-006/007/020 checks to these distinct
  application Remote handlers [G2, G3, G6].
- `FireAllClients` invokes local callbacks before encoding/checking its network
  payload. Offline/listen-local routes bypass the unreliable size check. A
  uniform validation-before-dispatch contract would change those edge behaviors
  and needs explicit migration tests [G1].
- Several Remote Fire/invoke/signal closures capture raw Remote pointers in
  `luau_api.h`; safe userdata lookup when obtaining the closure is not retained
  closure liveness. New work must use ObjectID resolution and focused destruction
  tests. This does not reopen the already qualified, capture-specific GL-001/002
  fixes or claim a new reproduced UAF [G1, G4].
- Existing string conversion uses NUL-terminated `lua_tostring` / `lua_pushstring`
  and UTF-8 Godot String conversion. Do not assume lossless arbitrary binary
  strings merely because the new envelope is binary; include embedded-NUL and
  invalid-UTF-8 characterization before changing codec semantics [G1, G3].
- Both network Invoke methods register timeout `0.0`. The domain host warns
  after ten seconds but times out only for a positive deadline. Every five
  seconds, `NetworkService` ages correlation/response state and erases entries
  older than sixty seconds without completing the waiting coroutine. The global
  int64 request counter is narrowed to int for RPC transmission and has no
  exhaustion guard [G4]. A finite terminal request contract is therefore a target,
  not a guarantee already supplied by the current code.

The ledger records the delivery/admission gap as [GL-029](issues.md#gl-029-application-remote-delivery-has-no-unified-bounded-publication-contract)
and the request gap as [GL-030](issues.md#gl-030-default-remotefunction-waits-have-no-finite-terminal-deadline).
Correcting them is future implementation work, not part of this assessment.

### Gargantuan evidence is scoped

Foundations 1–7 retain simulator and localhost GNS qualification of queue bounds,
publication/session replay rejection, request termination, reference visibility
and aggregate amplification [A6]. Current source implements those boundaries;
the record's earlier Windows Debug/Release runs are not fresh executions here.

Foundation 3L's later D03 amendment explicitly adopts
`POOLED_CORRECTNESS_V1`, with source `b420a7fd1567632b376760e65fc71386c9bddcf4`
recording Windows 97/97, Linux headless 53/53, GNS sanitizers 11/11 and five
Release workloads. Correctness, conservation, bounded resources and algorithmic
fairness remain mandatory. Timing targets are measured nonfatal diagnostics;
physical/provider certification remains deferred [A12]. Do not import those
numbers as GodotLuau performance guarantees or weaken existing GodotLuau gates.

The broad networking architecture document also describes future optimization.
Frozen-schema validation and bounded binary codecs exist; negotiated compact
connection-local Remote/schema indexes are explicitly deferred. A general
Gargantuan schema registry, mutation journal and DataModel are not present in
GodotLuau and are not prerequisites for the first RemoteEvent slice [A1, A8, A13].
Gargantuan's current inbound RemoteFunction implementation also disables ordinary
task-scheduler yielding while permitting its supported nested-request path.
Do not transplant that policy over GodotLuau's qualified yielding handlers [A4, G7].

## What ENet already supplies, and what it does not

Pinned Godot maps reliable transfer to ENet reliable packets, unordered transfer
to `UNSEQUENCED | UNRELIABLE_FRAGMENT`, and ordered-unreliable transfer to
`UNRELIABLE_FRAGMENT` [E1, E2]. ENet owns retransmission, packet ordering,
fragment/reassembly and transport congestion mechanics. It does not know which
Remote, object life, callback owner or gameplay authorization a payload represents.

For this pinned implementation, default channel 0 selects two internal channels:
reliable 0 and unreliable 1. Explicit positive channels select additional ENet
channels. Do not assume a separately isolated native channel for every Remote or
delivery enum value [E1]. Ordered-unreliable freshness is channel-wide and cannot
replace per-Remote/per-sender sequence domains. It also cannot supersede unsent
application state or retract a packet already handed to ENet.

Use unordered ENet RPCs for **both** unreliable event modes, and implement
sequencing above transport. Keep a fixed, bounded transport-channel policy, not
one native channel per Remote. Reliable application ordering remains affected by
head-of-line blocking on shared native channels; no cross-Remote parallelism or
cross-replication causal order is promised.

The existing 900-byte check measures `var_to_bytes(args)`, excluding RPC/path and
future envelope overhead. Godot permits unreliable fragmentation, so that check
alone is not a proof of a single datagram. The new profile must account for the
complete serialized packet and the qualified MTU; tightening the effective
argument ceiling is a documented compatibility change [G1, E1–E3].

**Reliable backpressure is a separate proof gate.** Godot's exposed ENet peer
statistics include RTT/loss/throttle observations, not an exact outgoing reliable
queue-byte or ACK-retirement ledger [E4]. A successful `rpc_id`/send is not an ACK
or evidence that backend retention is empty. Application queue limits bound only
application-owned storage. Do not clear an alleged total-memory charge at handoff
and then claim bounded native retention. A peer-supplied application receipt is
also not proof that ENet retired its reliable copy.

Before adopting Gargantuan's stronger reliable-retention guarantees, isolate and
measure the existing ENet admission/queue behavior with a slow and non-ACKing peer.
Establish a supported native cap/admission observation, or request a separate
reviewed host/adapter change. If that cannot be done without engine work, defer
the stronger guarantee explicitly; do not replace ENet, invent ACK evidence or
grow an opaque retry queue. No such host/dependency modification is authorized by
this research branch.

## Ranked adoption matrix

Ranks indicate implementation order, not measured speedups. H/M/L are relative
complexity estimates; none is an executed performance result.

| Rank / concept | Gargantuan actual implementation | GodotLuau / native ENet baseline | New work, benefit and principal risk | Decision |
| --- | --- | --- | --- | --- |
| 1. Three modes and independent sequences | DeliveryMode, typed sequence domains, Remote publication and per-peer sequences; separate event classes [A1–A4] | Two classes/boolean. ENet has reliable, unordered and ordered-unreliable mechanics, not object lifetime semantics. | M: native enum/property, frozen descriptors, endpoint generation, bounded freshness/supersession. Benefit: one API and replaceable-state semantics. Risk: configuration races, cross-sender poisoning, path replacement and legacy class assumptions. | **Adapt now**, preserving legacy constructors and ENet. |
| 2. Bounded scheduling, priorities and unreliable supersession | Production scheduler; per-peer/aggregate budgets, explicit tick flush, control precedence and eight-structural-to-one-application opportunity policy [A5] | Direct RPC submission; GL-004 limits Lua work, not all native queues. ENet cannot choose application semantic priority. | M/H: small Remote-owned queue and counters under NetworkService, bounded peer rotation, trusted classes, receive dispatch budget. Benefit: predictable retained work and fresher state. Risk: local dispatch latency, starvation and background queues bypassing limits. | **Adapt**, Remote traffic first; broader service scheduling only after measurements. |
| 3. Reliable backpressure | WouldBlock retains queued reliable work; hard backlog failure is terminal for that peer. Later GNS-specific native/ACK ownership is separately instrumented [A5, A12]. | Reliable retransmit exists. Extension API does not establish exact native queue/ACK accounting [E4]. | H: explicit admission result, ownership transitions, slow-peer cap and terminal policy; backend observability proof required. Benefit: bounded overload without silent reliable loss. Risk: confusing submission with delivery or importing a GNS ledger without ENet evidence. | **Adapt conditionally**; reject direct GNS patches and unproven native-memory guarantees. |
| 4. Diagnostics and accounting | Optional backend statistics; distinct scheduler and Remote queue, drop, stale, request and high-water counters [A4, A11] | Ping/Player ping and animation diagnostics exist; ENet exposes selected statistics. | L/M: native read-only snapshot, per-mode/per-peer bounded counters, actual units and unavailable values. Benefit: prove admission and diagnose overload. Risk: high-cardinality endpoint maps, logs or treating estimates as authority. | **Adopt early**, alongside the first queue, with no required telemetry service. |
| 5. Deterministic delivery simulation | Explicit clock, seeded faults and bounded semantic queues under IGameTransport [A7] | Actual ENet fixtures and latency proxy exist; sockets are nondeterministic. | M: pure sequence/admission policy tests with an injected clock/send seam; real ENet remains the qualification path. Benefit: reproducible exhaustion/replay/races. Risk: building a second runtime transport framework or mistaking simulation for networking/graphical proof. | **Adapt narrowly** for policies; defer a full replacement transport abstraction. |
| 6. Schema-aware serialization | Frozen schema/definition validation, WireValue binary codec, bounded GRMT/GRPL/GCHR formats. Compact Remote indexes deferred [A8, A13]. | ClassDB reflection and Variant codec, mixed/nested tables and typed-table compatibility; no equivalent frozen game schema. ENet only transports bytes. | H: first bound existing Remote encoding/decoding and reference context; later versioned typed codecs for measured hot paths. Benefit: size/work limits and less repeated metadata. Risk: Gargantuan's Remote Luau reader does not accept arbitrary Lua tables, so direct replacement breaks GodotLuau projects. | **Adapt validation now**, defer schema negotiation/compact indexes; reject a schema-system transplant. |
| 7. Structural batching/coalescing | Prepared dependency-safe groups, bounded peer/global transitions, immutable per-object templates, accepted-cursor commit [A8, A9] | Shadow properties, individual replication RPCs and late-join synchronization [G5]. ENet packets may aggregate physically but that is not semantic batching. | H: commit boundary, create/reference/destroy dependencies, failure-atomic receiver and peer cursor. Benefit: fewer encodes/messages. Risk: coalescing across lifecycle barriers or treating local queue admission as peer materialization. | **Adapt later**, after Remote/event ownership and measurements; never apply newest-wins to structural history. |
| 8. Per-peer relevance/spatial interest | Server-owned desired/materialized sets, bounded spatial candidates, ancestor/hard-reference closure, hysteresis and publication lifetimes [A9] | Replication/Character broadcasts; nearest-owner selection is not interest management. Godot has visibility primitives, not automatic knowledge of this custom protocol. | H: authoritative peer-known state, reference closure, enter/leave epochs and bounded spatial index. Benefit: reduce fanout for larger worlds. Risk: exposing hidden objects, missing parents, confusing unpublish with destruction and breaking late join/Remote references. | **Defer**, then adapt behind shared relevance state; no client radius/focus authority. |
| 9. Prediction/reconciliation | Semantic inputs, server simulation, acknowledged histories, bounded reconciliation and renderer-only smoothing; GCHR batching/tiering [A10] | GL-007 validates client-predicted poses; correction grants and interpolation exist. This is not acknowledged-input server replay [G6]. ENet supplies neither simulation nor reconciliation. | Very H: reproducible controller inputs, physics query contract and a new versioned Character protocol. Benefit: stronger prediction model if needed. Risk: changing collision truth, movement authority, Model/body synchronization and animation lifetimes. | **Defer** behind a separate ADR and gameplay measurements; do not bundle with Remotes. |

Gargantuan's GNS-specific egress worker, native arbitration, pooled capacity and
ACK patches are not proposed for GodotLuau. Their implementation and correctness
records are valuable evidence about ownership pitfalls, not a reason to change
transport, dependencies, process topology or deployment policy.

## Incremental implementation roadmap

Every phase requires a separate authorized implementation change. This branch
does not approve a new wire protocol or declare the proposal accepted.

| Phase | Bounded deliverable and dependency | Acceptance / stop condition |
| --- | --- | --- |
| P0: contract and characterization | Review the API proposal into an accepted ADR; characterize current constructors, native/reflection setters, local timing, cloning/import, payloads and RPC cancellation. Pin the ENet packet-size/backpressure investigation. | Golden current behavior and explicit intended differences. No misleading claim that GL-029/030 are already fixed. |
| P1: unified reliable/unordered vertical slice | Replace the internal boolean with a validated native delivery enum; expose server-owned DeliveryType, freeze/persist/replicate it, retain the legacy class, register generation-checked endpoints and reject carrier/mode mismatches. Reuse existing role/session helpers and codec/domain dispatch. Add bounded preflight and local/network validation parity; avoid a general traffic framework. | Default reliable and legacy unordered examples pass through real ENet and local/listen paths; no post-publication property mutation, hidden/path-replacement dispatch or bypass via generic setters. Ship only the two supported enum members at this checkpoint. |
| P2: minimal Remote queues and observations | Under the same service owner, add bounded send/receive admission, fair peer service, native read-only counters and an injectable policy clock/send seam. Resolve or explicitly limit the ENet native-retention proof before promising total reliable bounds. | At every transition, charged bytes/messages equal owned records. Reliable rejection is explicit, accepted reliable work is not silently dropped, one exhausted peer cannot hold the others, and old generation cleanup is exact. |
| P3: complete unified API | Add UnreliableSequenced and independent stream watermarks to P1/P2; at most one unsent entry per stream, checked replacement, no transport-channel-wide freshness coupling. Publish the third enum member only with working support. | Forced reorder/duplicates, independent peers/remotes/directions, reconnect, replacement, exhaustion and congestion pass deterministic policy and actual ENet fixtures. This is the first complete three-mode API. |
| P4: separate RemoteFunction completion correction | Preserve reliable request/response and existing Player/handler API. Review finite defaults/explicit timeout migration, full-width session-scoped IDs and exactly one native terminal completion. Fix GL-030 in a dedicated change, not by using unreliable events or changing handler yield semantics. | No GC-only disappearance, ID truncation/reuse or stale response completion; timeout/cancel/disconnect/owner-retirement races each settle once. Required before claiming all application networking has finite request completion. |
| P5: measured replication/codec work | After traffic metrics identify cost, add dependency-safe structural batches and bounded explicit materialization dependencies. Retain generic Variant compatibility; introduce typed binary hot paths only with a version and measured gain. | No cursor advances on a healthy peer from rejected work, no partial structural group or reference-to-replacement. Paired baseline/candidate workload evidence justifies each optimization. |
| P6: optional relevance and Character work | Shared per-peer relevance/visibility before spatial acceleration; only then consider a separately designed input/reconciliation protocol. | Existing Character protocol 3 and GL-007/020 remain authoritative until a separately approved migration is qualified. No Humanoid reintroduction or second pose authority. |

**Recommended first implementation task:** P1, following P0 review: “Unify
RemoteEvent reliable/unordered configuration with frozen Server-owned delivery,
legacy-class compatibility and generation-checked admission.” Its PR should not
include GNS, broad schema extraction, spatial streaming, Character prediction,
RemoteFunction timeout migration or unrelated GL-017/018 remediation. P2/P3 are
explicit follow-ups; a partial API must not advertise three supported modes.

### Source boundaries for that work

| Existing source | Planned responsibility; avoid incidental extraction |
| --- | --- |
| `src/gameplay/roblox_remote.h` | Native mode/configuration state, legacy subclass default, shared preflight, Fire routing, signal/Wait integration and Remote retirement. Resolve retained methods through ObjectID. |
| `src/services/roblox_network.h` | Existing service remains owner: exact role/session checks, frozen descriptors, endpoint publication, bounded routing/queues, transport mapping, peer/service cleanup and counters. No second session registry with independent authority. |
| `src/core/gl_net_bridge.h` | Bounded Remote-specific codec context, exact supported value behavior and visibility-aware references. Keep non-Remote consumers compatible; no global codec replacement. |
| `src/core/luau_api.h`, `luau_instance_reflection.cpp` | DeliveryType read/write and generic-set/call consistency; retained Fire/signal closures; Player arguments and callback argument order. |
| `src/core/luau_stdlib.h` | Numeric Enum.EventDeliveryType constants and constructor/class maps. A mutable Lua enum table is convenience, never native authority. |
| `src/core/gl_domain_host.*`, `gl_execution_domain.*` | Reuse protected dispatch, owner references and cancellation. P4 changes invoke completion only after separate approval. Do not create another VM/scheduler. |
| `src/core/register_types.cpp`, `src/importer/rbx_instances.h`, `src/editor/luau_type_database.h` | Keep legacy registration/serialized class loading and update canonical property/type discovery where needed. No generated corpus/model/archive regeneration. |
| `tests/runtime/NetworkIntegration.gd`, `NetworkSecurity.gd`, `RunQualification.py`, `CheckNativeCI.py`, core CMake cases | Extend the existing fixture/strict-discovery framework and required result inventory; use focused new fixture files when isolation warrants them. |

A small dependency-light delivery-policy helper may be justified for pure tests;
its owner remains NetworkService. That is not approval for a DataModel, mutation
gateway, universal transport interface or repository-wide header split.

## Qualification required for implementation

These are **future acceptance requirements**, not results of this research.

| Group | Required facts |
| --- | --- |
| Q1 API and assets | Old/new constructors, default reliable, legacy unordered ClassName/IsA, enum discovery, saved scene/import/clone round trip, no persisted counters/connections, invalid assignment leaves old mode intact; same-named child/metadata cannot shadow canonical DeliveryType. |
| Q2 native authority | LocalScript, shared ModuleScript, generic set/call, forged Lua globals/enum tables and Client RPC cannot configure/freeze/unfreeze a Remote. Trusted startup, native setters and admitted replication have explicit distinct paths with no reentrant privilege leak. |
| Q3 valid delivery | Single-player, listen plus two clients, dedicated plus two clients and existing editor actors; real ENet FireServer receives the actual Player, targeted FireClient reaches only that Player, FireAllClients includes host once; no return-value changes. |
| Q4 reliable ordering | Large/small adjacent events and delayed/retransmitted packets preserve accepted send order per stream. Yielding callbacks may overlap; verify callback start order, not completion order. No promise of cross-Remote or replication causality. |
| Q5 unordered | Forced loss, reorder and duplicate message injection can produce reordered/duplicate valid payloads, with no application freshness filter or invented reliable retry. Do not require actual ENet to duplicate a packet it natively suppresses. |
| Q6 sequenced | Deliver 3,1,2,3,4 and assert only 3,4 dispatch. Replace queued 1 with 2 before flush; reject duplicate/older submissions. A/B peers and X/Y Remotes cannot suppress one another. Lost newest is not guaranteed delivery. |
| Q7 publication/lifetime | Remote cloned/replaced at same path, reparented within scope, moved across scopes, destroyed between decode/dispatch, unpublished/republished, peer-ID reuse, service/scene replacement and stale descriptors all reject old work. Late join receives mode before activation. |
| Q8 no side effects on rejection | Wrong role/sender/transport generation, unpublished Remote, forged delivery/channel, hidden/stale Instance references, malformed/version-mismatched frames, future publication and poisoned high sequence: zero unauthorized handler/signal/Wait resume, state mutation or relay. Invalid traffic cannot evict a valid newer queued record. |
| Q9 serialization and packet size | Preserve nil/trailing arguments, valid mixed/nested/typed tables, Vector3/Color3/CFrame and supported references using golden cases. Exercise cycles, depth, node/argument/string/byte bounds, NUL/UTF-8 and numeric edge behavior explicitly. Verify complete RPC framing/MTU limits in Debug and Release; never infer a datagram bound from argument size alone. |
| Q10 resources | Exact-full/one-over peer and aggregate bytes/messages, many distinct Remote keys, broadcast fanout, native allocation failure and slow/non-ACKing peers; no unbounded pending state. Test replacement with larger/smaller payloads, rollback on failed replacement, age limits, fair peer rotation and charge conservation through teardown. |
| Q11 callbacks | Connect/Once/Wait, disconnect during dispatch, connect during callback, reentrant Fire/destroy, yielded handlers, caller versus ModuleScript ownership, manual coroutine resume, owner disable/reload, shutdown and cancellation. Once disconnects before invocation; no replay of callbacks already started. |
| Q12 RemoteFunction | Reliable carriers only; wrong-peer/duplicate/late replies, narrowing/exhaustion, new session/Remote replacement, nonresponse past the current GC horizon, finite-deadline migration, response-timeout races, manual resume and teardown; exactly one terminal settlement, no automatic retry of gameplay effects. Preserve existing successful yielding handlers. |
| Q13 regressions | All existing core/native required IDs and GL-003/004/005/007/009/019/020/022/023 coverage, Model Character V2, native ObjectID and shared-domain ownership. Preserve current frame-progress assertions and all retained failures. |
| Q14 performance | Repeated interleaved baseline/candidate, same hardware/build/configuration/warmed caches; 1/16/32/64 peers or bounded equivalents where practical. Separate encode/decode, admission, queue/dispatch, physics, animation, rendering, fanout and backend retention. Record mean/median/p95/p99, drops/supersessions, queue high water, native objects/bytes, handler count and teardown growth. A network timing improvement is not inferred from headless graphical simulation. |

Pure policy tests should use an explicit clock, deterministic packet schedule and
small validated budgets, including near-exhaustion counters. Real ENet actors
must exercise production handlers: use the existing delayed proxy and scoped
test-only carrier/replay injection. Exercise both engine RPC authority rejection
and production handler rejection with the fixture's temporarily relaxed RPC
configuration. Neither mocked authorization nor a simulator substitutes for
actual transport. Do not disable production authority to make a normal case pass.

Reuse `FixtureProcesses`, timeouts, Windows crash-UI suppression and explicit
process-tree cleanup. DockerPC is primary; MainPC is fallback only. No LinuxBox,
other local worker, external security service or cloud local-test environment.
Existing GitHub Actions are permitted. Run Windows/Linux Debug/Release and core
sanitizers, plus applicable full-native profiles with exact host/source identity.
Keep GL-017 and GL-018 limitations separate; an unsupported sanitizer profile
stays unqualified. Do not reuse a GL-018 branch binary as evidence for different
main inputs.

Baseline strict discovery currently requires 80 core cases and 110 native actors
[G7]. Preserve every existing case/actor and add the new labels/counts explicitly
to the existing checker/CI inventory. New cases can increase those counts; do not
retain an obsolete count by skipping fixtures. Verify complete reports, actual
Remote fixture execution, source/binary/harness hashes and downloaded hosted
artifacts after each implementation phase. Pending, skipped, timed-out or
incomplete required work is not a pass.

## Decision gates, compatibility and remaining uncertainty

Approve the proposed property/activation policy and legacy-class retention before
implementation. Approve any tightened payload/rate/deadline limits explicitly,
using existing-project characterization and repeated overload measurements.
Provisional limits in the API proposal are review inputs, not new repository
guarantees. Never silently convert oversized reliable sends into unreliable sends,
drop accepted reliable work, coalesce arbitrary event effects or retry a request
with possible gameplay side effects.

The largest unresolved engineering fact is safe **native ENet egress admission**,
not enum syntax. A bounded extension queue is useful without claiming it bounds
all engine memory. Full reliable-backpressure adoption requires the separate
proof described above. Precise new wire layout, complete-RPC MTU accounting and
budget calibration are also implementation gates, not invented measurements.

Project/API compatibility and mixed-version wire compatibility are different.
Godot RPC method-set checksums and a new Remote capability handshake may reject
mixed builds before a custom diagnostic is delivered [E3]. Require one qualified
protocol across peers; keep old serialized project classes and defaults. Do not
offer a silent fallback that loses sequencing, configuration authority or bounds.

Preserve all existing GL contracts, release/tag protections and fail-closed updater
admission. No releases, updater distribution, merge, runtime/test changes, pin
changes, upstream write or additional development phase is part of this branch.

## Documentation verification

Static review on DockerPC verified the pinned source hashes, immutable source
paths/line ranges, local links, new section anchors and balanced code fences.
The [review receipt](evidence/networking-research-review.json) records its scope;
link resolution is not independent proof of every semantic claim. No runtime
qualification or performance result was generated. Core/native CI is path-filtered
and this documentation-only change does not require dispatching those workflows.
The release workflow remains read-only with both jobs disabled; the updater and
release-candidate configuration are unchanged.

## Source index

Immutable links establish implementation evidence. Qualification references
establish only their recorded execution scope.

| Ref | Source and inspected boundary |
| --- | --- |
| G1 | [Remote nodes](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/src/gameplay/roblox_remote.h): `RemoteEventNode`, `_gl_check_unreliable_size`, Fire/local/network delivery, signals and legacy subclass |
| G2 | [NetworkService](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/src/services/roblox_network.h): `_setup_rpcs`, `net_send_event`, `_deliver_event`, session helpers, connection/teardown and physics |
| G3 | [Variant network codec](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/src/core/gl_net_bridge.h): depth, typed/mixed tables, reference-ID/path fallback and request counter |
| G4 | [Luau API](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/src/core/luau_api.h#L2792), [domain invoke waits](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/src/core/gl_domain_host.cpp#L412), and G2 `_rf_return` / `rf_gc_timer`: callbacks, timeout zero, expected peer, cleanup and narrowing |
| G5 | G2 `rep_send_new/prop/reparent`, `_rep_sync_peer`, `_rep_node`, `_stamp_static_ids`; G4 replication shadows and clone net-ID stripping |
| G6 | [ADR-006](adr-006-character-authority.md), [ADR-007](adr-007-model-character.md), [authority qualification](network-authority-validation.md), [GL-020 integration](animation-authority-main-integration.md): authority, protocol 3 and qualified scope |
| G7 | [ENet integration fixture](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/tests/runtime/NetworkIntegration.gd), [strict native checker](https://github.com/gmoddev/GodotLuau/blob/83cd0887968d73d61d050650718d8ada6e124579/tests/runtime/CheckNativeCI.py), `NetworkSecurity.gd`, `AnimationIntegration.gd`, `AnimationAdversarial.gd`, `CharacterPresentation.gd`, `RunQualification.py`, `RunCharacterNetworkBenchmarks.py`, `CheckCoreCI.py` |
| G8 | [Policies/invariants](invariants.md), [resource policy](adr-002-domain-resource-policy.md), [shared domains](adr-001-shared-execution-domains.md), [current architecture](current-architecture.md) and [GL-018 unmerged follow-up](https://github.com/gmoddev/GodotLuau/blob/0e61db4a418c606deff50fad27f9831dc6204981/newdocs/native-sanitizer-qualification.md) |
| A1 | [Bounded Luau remotes](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/LuauRemotes.md), [RemoteEvent definition](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/assets/classes/RemoteEvent.luau), [sequenced definition](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/assets/classes/UnreliableSequencedRemoteEvent.luau), `RemoteEventBase.cpp`: actual public API and deferred indexes |
| A2 | [Delivery](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/Delivery.hpp), [Remote protocol](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/RemoteProtocol.hpp), `RemoteProtocol.cpp`: three modes, four kinds, GRMT v2, limits and compatibility |
| A3 | [Sequence types](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/Sequence.hpp), [message intent](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/MessageIntent.hpp), [networking contracts](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/NetworkingContracts.md) |
| A4 | [RemoteManager implementation](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/RemoteManager.cpp), [limits/metrics header](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/RemoteManager.hpp), `RemoteBase.hpp`, `RemoteFunction.cpp`: publication, send/dispatch, detached terminal ownership |
| A5 | [Scheduler source](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/Scheduler.cpp), [contract](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/NetworkSchedulerContract.md): queue keys, supersession, accounting, flush and fairness |
| A6 | [Foundations 1–7 qualification](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/NetworkingFoundations1To7Validation.md), [Remote regressions](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/tests/RemoteTests.cpp), `RemoteGnsTests.cpp`, `RemoteLuauTests.cpp` |
| A7 | [Simulated transport contract](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/SimulatedTransport.md), `SimulatedTransport.cpp`, `SimulatedTransportTests.cpp`, `SchedulerContractTests.cpp`: explicit clock, seeded faults, bounds and semantic policy fixtures |
| A8 | [Basic replication](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/BasicClientReplication.md), [binary codec](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/BinaryCodec.cpp), `ReplicationProtocol.cpp`, `RemoteLuau.cpp`: schema-aware values and actual argument restrictions |
| A9 | [ReplicationCoordinator](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/ReplicationCoordinator.cpp), [relevance](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/ReplicationRelevance.cpp), [3J](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/ReplicationFoundation3J.md), [3E](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/CharacterReplicationFoundation3E.md) |
| A10 | [Character networking](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/src/network/CharacterNetwork.cpp), [3C](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/CharacterNetworkingFoundation3C.md), [3G](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/CharacterNetworkingFoundation3G.md), `CharacterNetworkingTests.cpp`: input acknowledgments, bounded histories, publication and presentation |
| A11 | [Statistics](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/include/gargantuan/network/Statistics.hpp), [transport implementation/contract](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/devdocs/CurrentArchitecture/RealGameTransport.md), `GameNetworkingSocketsTransport.cpp`: optional observations and native handoff limitations |
| A12 | [D03 final scope](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/docs/adr/D03-hybrid-pooled-service-and-permit-ownership.md), [retained acceptance receipt](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/tests/Foundation3LCoreAcceptance20261021.json), `KNOWN_ISSUES.md` KI-006: correctness-qualified, physical/provider deferred, timing diagnostic |
| A13 | [Accepted design and deferred optimization](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/docs/src/content/docs/developing/networking-architecture.mdx), [architecture authority](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/docs/architecture/README.md), [invariants](https://github.com/gmoddev/gargantuan/blob/e682be08df84d776bfa455137728265c6494b5e8/docs/invariants/Core.md), `ProtocolInputHardening.md`, `LoopbackReplication.md` |
| E1 | [Pinned Godot ENet peer](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_multiplayer_peer.cpp#L343), [internal channel constants](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_multiplayer_peer.h#L48) |
| E2 | [Bundled ENet send logic](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/thirdparty/enet/peer.c#L136), `thirdparty/enet/protocol.c`: fragmentation, unsequenced/reliable command mechanics |
| E3 | [Pinned SceneRPCInterface](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/multiplayer/scene_rpc_interface.cpp): RPC configuration, framing, method-set checksum and argument dispatch |
| E4 | [Exposed ENet peer statistics](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_packet_peer.h#L80), `enet_packet_peer.cpp`: available RTT/loss/throttle values versus absent exact reliable backlog/ACK ownership |
