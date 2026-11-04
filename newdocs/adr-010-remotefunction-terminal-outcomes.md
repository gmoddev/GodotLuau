# ADR-010: Bounded RemoteFunction terminal outcomes

Status: accepted for implementation by the Networking Foundation 2 campaign;
development qualification pending. Branch `foundation/networking-2`, baseline
main `9f52b273cf977dce9c0541ff718cfb44dfb54c31`. Actual executions and failures:
[campaign journal](networking-foundation-2-work.md). This extends ADR-002/008/009
without a new VM, scheduler, transport, dependency or host patch.

## Request ownership and deadlines

NetworkService owns transport correlation; GLDomainHost owns the exact coroutine
wait. Both records are detached before resuming gameplay. Every accepted network
invoke has one terminal completion: success, remote error, timeout, transport
failure, endpoint/session/service retirement, or owner/thread cancellation.
Owner cancellation stops the coroutine rather than calling back into a dead
owner. No age GC may silently erase a live wait.

The default deadline is 30 seconds of native monotonic time. The trusted project
setting `godot_luau/network/remote_function_timeout_seconds` accepts finite
numbers from 0.05 through 300 seconds; invalid settings use 30. An invoke
snapshots its deadline. Zero cannot request infinity. Source inspection found
only test callers in the repository; existing network handlers yield for short
timers. This is an intentional change for external projects with longer
handlers: choose a finite project limit and handle timeout with `pcall`.

Timeout/cancellation does not roll back completed gameplay effects or guarantee
the other machine immediately stops work. There are no automatic application
retries. While its session remains active, the serving process bounds request
handling by its own snapshotted deadline and cancels the exact handler task.
On disconnect/service retirement it detaches transport ownership; already
running application handlers may finish in their live domain, preserving GL-029's
sibling-callback contract. Their retired tokens cannot respond through another
session or service. These detached application tasks remain subject to existing
domain coroutine/task/memory admission, not the correlated-serving count.
Owner/domain shutdown still cancels their scheduler tasks. Existing domain
execution/memory limits continue to apply to every resume. Local synchronous
fallback retains its existing non-yielding contract and return shapes.

## Identity and publication

Use checked positive signed-64-bit request IDs, never recycled in the process,
including after service replacement. Exhaustion fails before wrap. IDs remain
native integer Variants on the wire; private serving tokens cross Lua as decimal
strings, never doubles. Tokens belong to one exact serving coroutine and live
owner; knowing a token is insufficient to respond from another thread.

Extend the existing native publication map, epoch, endpoint allocator, bootstrap
ObjectID capture, descriptor/acknowledgment/activation and retirement machinery
to RemoteFunction. Functions retain their native class and public APIs. A
function descriptor is the existing nine-element GER2 control descriptor plus
the explicit boolean `true` at index 9. Ordinary event descriptors and GER2 data
frames are unchanged. Both kinds share the 4,096 publication ceiling and
64-descriptor production budget. Functions have no event DeliveryType.

Client-created/private Functions cannot become Server publications. Bootstrap
handler assignment also enforces Server-owned OnServerInvoke and Client-owned
OnClientInvoke at the native Luau setter, including listen/shared-tree execution.
Only a function or nil is accepted; nil clears that side's handler.
The former internal reflected `net_invoke_server/client` submission helpers are
private C++ calls, reached after native live-owner wait capture. They are not
public RemoteFunction APIs; reflection cannot reserve ownerless response slots.
Bootstrap
paths bind only the captured native ObjectID, and data requests contain no path.
Runtime Functions use the existing replicated net-ID map. A function leaving
the SceneTree advances its local generation; a replacement cannot inherit
in-flight correlation. Rebinding requires a new publication handshake.

## Versioned function wire

All function RPCs use reliable channel 0 and require the admitted host's actual
native call context, correct receiver role and current transport sender.
The six-element header is:

`[1, service_epoch, assigned_client_session, endpoint, publication, request_id]`

Every element has its original integer Variant type; all identities are positive.
Requests append the encoded argument Array. Responses append a boolean success
flag and encoded return Array. Cancellation carries only the header. Responses
must match the exact expected peer and complete header. Failed responses carry
one string. Duplicate/stale/late responses never allocate a response slot.
Incoming request high-watermarks are per existing live peer/session, not an
unbounded tombstone set. Replays cannot run a handler twice.

`_rf_invoke_server`, `_rf_invoke_client` and `_rf_return` keep their internal
method names with the new frame shape; `_rf_cancel` is added. Require matching
builds across peers. Old request signatures are incompatible, and old clients
cannot activate a function descriptor. There is no silent legacy downgrade.
Godot's method-set checksum may reject mixed builds before a custom diagnostic.

## Bounds and failures

At most 64 outgoing requests or serving handlers per peer and 256 per service.
The process-wide response-slot ceiling is 256, including ready results awaiting
the domain host. Admission rejection leaves existing requests intact. Payloads
use the existing bounded Remote validation rules: 64 arguments/returns, 4,096
traversal nodes, depth below 16, finite numbers, supported types and strict UTF-8.
The encoded body limit is 65,408 bytes, leaving 128 bytes for the function frame.
Instance references use the current admitted replication/root/Player identity
rules rather than an arbitrary path fallback. These are explicit compatibility
limits for previously unchecked external callers.

Function request/response/cancel traffic shares the existing per-tick Remote
receive budget and admitted native reliable ceilings. Reliable receive overload
terminates the affected session explicitly. Failed request handoff completes
the caller with a transport error; failed response admission schedules affected
peer failure. No new hidden retry queue or native ACK claim is introduced.
Invalid traffic receives no amplified error stream. Missing handlers and bounded
handler-admission errors are explicit responses to validated fresh requests.

An external manual resume cancels the old wait before its continuation raises
`Invoke resumed outside completion`; an old completion cannot resume a later
wait on the same coroutine. Endpoint/service liveness is checked again before
delivering an accepted result. Disconnect, service replacement, owner retirement
and domain shutdown release exact correlations and serving references.

`GetFunctionState` exposes bounded read-only counts and outcomes for trusted
native diagnostics. Test-only counter/identity controls are absent from the
distribution build. Bounds cover these records and payloads, not total process
RAM, arbitrary user task allocations, native decoder storage or transport control
queues. Qualification must exercise the production implementation with actual
ENet and matching-host sanitizers on both platforms before GL-030 closes.
