# ADR-011: Bounded per-peer runtime replication

Status: implementation decision for Networking Foundation 2; qualification pending.
This document is not a claim that the runtime or complete campaign is qualified.
The `532650f` vertical slice passes the recorded Windows/Linux platform matrix;
GL-034 performance and the explicit broader coverage gaps remain open.

## Authority and deployment

Retain NetworkService, SceneTree, existing native net IDs and ObjectIDs, Luau
replication hooks, GL-007 Character authority and ADR-009's admitted ENet host.
No second scheduler, VM, transport or client visibility grant is introduced.
Use an explicit trusted project opt-in, fixed for a session. Legacy projects
retain their existing replication behavior. Peers must use matching builds;
there is no silent wire downgrade.

The first spatial slice is runtime anchored leaf Parts under Workspace. Existing
place contents, services, containers, Character/Player identities, Remotes and
other runtime objects remain globally relevant. A native object relationship
requiring an otherwise spatial object brings that dependency into the desired
closure. This is runtime replica selection, not place/asset paging. Non-anchored
physics, public Remote Instance-reference delivery and richer spatial hierarchies
must have explicit compatible treatment before this opt-in can be qualified;
they cannot be assumed safe from a spatial query test alone.

Focus comes from the existing server-validated Player.Character transform. An
absent Character receives globals, not an arbitrary client camera or requested
coordinate. Native server configuration may explicitly retain global objects;
client metadata must not acquire this authority. Selection must retain the
parent/reference closure, fail without a partial desired set on limits, and
distinguish missing dependencies from a legitimately empty spatial query.

## Identity and state

Maintain separate per-peer Desired, Known and Materialized records. Desired is
the bounded server selection. Known changes only after successful native reliable
admission of a complete structural group. Materialized changes only after an
exact application acknowledgment for that session and accepted sequence. Neither
state is an ENet ACK, a persistence acknowledgment or a gameplay authority grant.

Bind state to the live service ObjectID, native epoch, existing peer/session,
net ID, source ObjectID and checked positive int64 materialization generation.
Leave is a replica departure; it does not destroy the authoritative object.
Authoritative destruction has a distinct operation/disposition. Reentry must
allocate a new generation and new native replica identity. Stale structural,
reference and physics traffic must not target the new generation accidentally.

Disconnect, service replacement, domain/scene shutdown and object retirement
must release their exact state. No history-sized tombstone set or age-based
silent removal of accepted reliable work is permitted.

## Bounded planning and submission

The query catalog is a projection of existing native identities, not semantic
truth. The candidate policy uses at most 16,384 catalog entries, 4,096 desired
objects per peer, 64 references per object, 256-unit cells and a maximum 512-unit
query radius (at most 125 cells). Finite coordinate validation precedes cell
conversion. Dependency cycles terminate by identity; missing dependencies and
oversized closure reject the whole selection. These bounds do not cover total
process RAM, Godot decoder overhead or arbitrary project scene size.

Drain pending semantic state from NetworkService's existing tick. Reliable
create/reference/reparent/leave/destroy operations retain ordering. A dependency
group must fit the explicit operation and encoded-byte quantum together; do not
accept half a required group. Validate an entire received frame before mutation,
stage identities required by same-frame references, and revalidate ObjectIDs
after callbacks. This does not promise a global SceneTree transaction that hides
every intermediate callback observation.

Only unaccepted property state may coalesce. Accepted work is immutable. A
structural barrier must preserve the accepted parent/reference relationships
until their replacement or clear is admitted. Native capacity preflight can
defer a frame without advancing Known, sequence or generation. Actual admission
still uses ADR-009. A subsequent send failure or finite backlog deadline has an
explicit affected-peer failure outcome; it never silently drops required work.
Rotate bounded peer quanta so one blocked peer cannot monopolize the service.

Expose read-only desired/known/materialized, pending/deferred/accepted, bytes,
query visits, coalescing, rejection and failure diagnostics. Distinguish sampled
native occupancy from exact native ownership and application materialization.

## Compatibility and qualification

GL-031 is a prerequisite regression: static place parents are existing
prerequisites for late-join runtime children. Preserve static identity and old
data rather than creating duplicate parents.

Production integration must qualify actual ENet enter/leave/reentry, reference
dependencies, destruction and replacement, reconnect, reparenting, wrong sender,
session/generation replay, exact bounds, native deferral and healthy-peer
progress. Preserve the complete existing core/native, Character, animation,
storage, HTTP, RemoteEvent/Function and matching-host sanitizer/package gates.
Record unsupported behavior and negative measurements explicitly. A policy-only
prototype, successful compile or headless fixture is not full graphical or
scalability qualification. Main, release publication and updater distribution
remain unchanged throughout this development campaign.

Reference concepts: Gargantuan `e682be08df84d776bfa455137728265c6494b5e8`,
`src/network/ReplicationRelevance.cpp` and
`devdocs/CurrentArchitecture/ReplicationFoundation3J.md`. GodotLuau does not adopt
its GNS, DataModel, mutation gateway or deployment model.

## Implemented opt-in contract

The trusted project boolean `godot_luau/network/replication_relevance` defaults
to false and is captured at session creation on both server and client. Matching
builds and settings are required. An opted-in client rejects legacy structural
RPCs before its first frame and fails explicitly if the new protocol does not
begin within ten seconds. This is an experimental campaign branch contract,
not a distribution or main integration approval.
Enable it at project startup in a fresh scene; in-place conversion of an active
legacy world, including prior Client-written native state, is not qualified.

Only native server registrations enter the source catalog. A runtime anchored
leaf Part under Workspace is spatial; its native mesh/collider components stay
Part-owned. Registered gameplay descendants conservatively make that hierarchy
global. Other objects and unanchored Parts are globally relevant. Global status
is sticky for that canonical identity. `SetReplicationGlobal(Object)` is a
trusted native host operation, guarded against Client execution; this first
slice does not add an arbitrary Luau reflection/capability API. The native
registry retains live runtime ObjectID registrations and global pins across
same-scope service replacement. Runtime IDs use a checked process-lifetime
counter below the static-place bit. Client metadata never registers an object.

Listen-host Client writes to registered objects, their native descendants, and
structural ancestors are denied through the existing write boundary, including
attributes, impulses, destruction and ownership assignment. Ordinary attributes
on Game are not structural subtree mutations. Client-local additions cannot
promote an object into the source global set. Focus uses existing validated
Character authority, with a fixed 250-unit selection radius.
Captured scope roots and their structural ancestors remain protected even before
the first registered object or Character exists (GL-035). Native scope identity,
not Client-editable metadata or catalog population, establishes this boundary.

The source uses bounded immutable property snapshots: 8 KiB/512 codec nodes/128
properties per record and 8 MiB encoded catalog data. The existing bounded queue
owns reliable batches of at most 64 operations, 60 KiB and 4,096 codec nodes.
Per-peer application admission is 256 KiB/256 messages; service totals are 16 MiB/
16,384 messages across at most 64 peers. Incoming structural work is bounded to
4 MiB/64 frames and shares the existing Remote receive rate budget. These are
encoded payload bounds; source/view/commit metadata and Godot allocations are
additional bounded state, not part of a claimed 16 MiB process-memory ceiling.

Planned state advances at application queue acceptance; Known advances only at
successful native handoff. Materialized records mean the exact peer/session
reported cumulative application of an accepted sequence. An ACK is not evidence
of an honest client, an ENet ACK or an independent ownership decision. At most
64 structural frames remain application-unacknowledged per peer. A ten-second
backlog/materialization deadline fails that peer explicitly and retires its
owned state. Failed sessions do not re-enter planning or produce unbounded logs.

Wire carriers are reliable channel-zero `GRV1` frames and `GRA1` application
ACKs. Enter generation is that peer/session's checked batch sequence; update and
leave must match it. Canonical retirement is distinct from relevance departure.
Same-name replacement retires the old identity first. Every required creation
and reference closure must fit one admitted group. Receiver validation precedes
allocation; all new identities exist before reference properties apply. This
is admission atomicity, not a claim that arbitrary SceneTree callbacks observe
a transactional scene. Revalidate service, session and native objects after
callbacks; an interrupted application receives no ACK. Bounded reference cycles
can retire together, with native child removal ordered before its parent.

Property writes coalesce before admission. Already accepted reparent barriers
remain immutable FIFO work, including two changes in one Luau turn. Cached
property bytes are reused with per-peer headers. NetworkService's existing tick
does at most eight peer turns or four milliseconds of submission work, round
robin. Catalog refresh/query and native property application have their own
finite object/byte bounds; the four milliseconds is not a whole-frame time bound
or a proof of fairness under every mixed traffic workload.

Refresh diagnostics report cumulative calls, visited/rebuilt records, elapsed
wall time and maximum duration, with visibility/metadata/encoding/index stage
subtotals. Excluded-record and cleanup work remain in the total, so stage sums
are not the total. These are elapsed timings, not isolated CPU measurements.
Part-owned geometry is excluded before ancestry traversal. Each captured scope
root is verified once per refresh; direct children retain their own server-only
name/class exclusions, and deeper objects retain the full visibility path.
This reduces duplicate queries without making Client metadata authoritative.

Runtime physics uses a 180-byte unreliable channel-zero `GRP1` carrier with
epoch, user session, canonical ID and materialization generation. Validate actual
sender/carrier, current native identity, server ownership, current visibility,
control acknowledgment and finite pose/velocity before application. Ownership
requests wait for materialization; automatic ownership considers eligible views.
Static-place physics retains its existing contract. Non-anchored bodies stay
global rather than acquiring ambiguous selective ownership.

Public Remote Instance arguments referring to selective runtime objects return
an explicit not-ready error. They require a sticky global pin and that target's
global-state application ACK; existing Player/scope/static reference behavior
continues. This avoids stale cross-channel reentry aliases without changing
GER2 or introducing a second Remote system. ObjectValue now has a focused live
Instance/nil getter/setter; its projection encodes authorized native identity,
normalizes unavailable weak targets to nil, and preserves dependency closure.

Remaining qualification includes larger-world cost, mixed-traffic fairness,
loss/reordering workloads, server service replacement, mixed-mode rejection,
and full graphical behavior. Static-place removal history before a peer joins
is not introduced by this runtime-only slice. Unsupported arbitrary attached
script getters and oversized groups fail explicitly. No general performance,
full world paging, native ACK retirement or 64-player support is claimed.
