# ADR-011: Bounded per-peer runtime replication

Status: implementation decision for Networking Foundation 2; qualification pending.
This document is not a claim that the runtime or complete campaign is qualified.

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
