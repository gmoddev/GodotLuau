# ADR-002: Shared-domain resource policy

Status: accepted; qualified source integrated by normal merge `55a9c20`.
Fresh main CI remains pending in the linked integration record.
Builds and executed evidence are recorded in [the work record](execution-limits-validation.md).
This decision extends [ADR-001](adr-001-shared-execution-domains.md), without
changing its VM, environment, cache or scheduler ownership model.

## Decision

Account and enforce Luau allocation at the Server/Client domain boundary. The
allocator counts actual live/peak VM bytes and rejects growth before realloc.
These are requested allocator bytes, including VM pages/blocks, not malloc
bookkeeping, sanitizer redzones, temporary realloc peaks or process RSS.
Shrinking/freeing remains permitted. Bootstrap and registry/thread/module memory
share the same cap; Godot objects, compiler/C++ allocations and process RSS do not.

Quota/OOM is terminal for that domain. Even if gameplay catches a Lua memory
error, the protected host boundary observes the allocator rejection, denies new
work, cancels owners, invalidates native registrations and skips close hooks.
It does not close the VM inside a callback or restart it. Normal host/scene
destruction eventually calls lua_close with the allocator context still alive.
A new scene/domain starts with fresh accounting. The other domain is independent.
Allocator quota rejection is distinguished from an underlying host allocation
failure; neither represents an OS/process memory cap.

Gameplay entry/resume/callback preparation and synchronous invocation share an
outermost monotonic deadline. Nested calls inherit it; yielding and returning to
the host end the attempt. Catching an inner budget error does not reset it.
Synchronous Server/Client nesting also inherits active ancestor constraints,
including when the child domain's own timer/count is disabled. A thread-local
chain holds domain scope pointers only while those C++ calls are active; tasks
and native registrations never retain the chain. A domain already in that chain
is not pushed again on reentry, and each active domain counts a VM safepoint once.
The optional count includes gameplay safepoints in active descendant VMs, not
exact per-VM instructions. Each domain's allocator and persistent state remain
independent. Unrelated owners can run after the participating failed attempts end.
A caught allocation rejection in an active ancestor blocks descendant execution;
only the rejecting domain receives terminal memory-failure disposition.
The pinned interrupt checks time every 64 VM safepoints; optional deterministic
safepoint limits count callback opportunities, **not bytecode instructions**.
Interrupts do not throw during collector callbacks. Cancellation and module error
publication happen after protected execution returns. Module initialization
budget errors keep the existing sticky-error contract.

Native marshalling runs protected on the coroutine that allocates/executes it.
Suspended coroutine arguments are prepared on a fresh, synchronously rooted
scratch coroutine, then moved after protected stack reservation. This is
preparation for the existing Resume scheduler, not another scheduler. Public
callback IDs remain globally non-recycled. No native registration retains these
temporary context pointers.
Result-copy unwinding checks source allocation failure before rethrowing a
destination error to its own protected boundary.
Successful native result copying also checks the deadline on return and cancels
the callback owner if conversion exceeded it.

Embedded registration/stdlib bootstrap is trusted and has no gameplay deadline;
the VM memory cap still applies. Gameplay reached through trusted functions or
service callbacks receives a budget. Host property conversion also receives a
budget; a budget failure cancels its bootstrap owner, including service tasks
owned by that token. It does not reconstruct services automatically. Blocking
native calls are only checked after return and cannot be preempted by Luau.
Compiler work is likewise outside VM interruption. The deadline is per outer
entry, not an aggregate per-frame limit: many valid entries can still accumulate
frame latency. Mutations performed before a failure are not rolled back.
Shutdown hooks share one aggregate budget, and remaining hooks are skipped after
failure. Zero time/safepoint configuration explicitly opts out of that control.

Admission limits bound retained scheduler records, live coroutines (including
manual coroutines and anchors), live external references, and retained owner
tokens. Cancelled tasks consume admission until scheduler cleanup. Dead owner
tokens can remain until coroutine GC; reload does not evade their record cap.
Rejected Lua admission raises a catchable scheduler error; it does not create
another task. Live-reference/owner counters are constant-time, and high-water
counts are exposed for diagnostics. These caps do not bound every native object
or inactive native signal-vector slot.
Nonterminal replacement rejection preserves the previous owner until the new
owner has been admitted. Bootstrap detects even caught admission rejections and
becomes unavailable rather than admitting gameplay with partial services.

## Sandbox and compatibility

Seal after trusted bootstrap, before gameplay admission. Use luaL_sandbox for
intrinsic library/root immutability and luaL_sandboxthread for private owner
environments. Restore prior mutability of custom service facades and _G/shared;
aliases of intrinsic library tables remain frozen. Freezing task/coroutine and
standard library tables is an intentional compatibility change: gameplay can
shadow a global in its own environment but cannot patch a shared intrinsic table.

Disable safeenv in every gameplay environment, including ModuleScripts. Its
builtin fastcalls otherwise bypass GodotLuau's custom typeof. Reused environments
also disable import optimization. getfenv/setfenv and mutable compatibility
globals remain available. Read-only proxy metatables do not prevent a script
from replacing its own environment/metatable through supported compatibility APIs.
Sandbox initialization preserves native userdata/metatable identity and module
result identity. It is not hostile-code isolation: _FileAccess, _HTTP and other
native facades remain accessible under GL-003/005.
The pinned standard libraries do not publish io, package, dofile, loadfile,
debug.getregistry or os.execute; native bootstrap leaves those unavailable.
That pre-existing Luau API surface does not confine the exposed native facades.

Local remote/bindable value copying reads raw __type metadata and raw local/root
type globals. It does not invoke metadata/global lookup metamethods while another
coroutine's source table is being traversed. Raw destination-local type overrides
remain visible; computed metadata/type globals are not a supported serialization
contract. Source stack reservation is protected separately, and temporary source
stack entries unwind if destination conversion fails. This prevents exceptions
from a source state being caught by the wrong destination VM boundary.

## Configuration and diagnostics

ProjectSettings are sampled once when creating each domain. Prefixes are
`godot_luau/server_limits/` and `godot_luau/client_limits/`. Changes require a new
scene/domain; an exhausted domain is not reconfigured/restarted in place.

| Suffix | Default | Meaning / valid range |
| --- | ---: | --- |
| resume_milliseconds | 10000 | finite number, 0–60000; zero disables elapsed limit |
| max_safepoints | 0 | integer 0–1,000,000,000; zero disables count limit |
| vm_memory_bytes | 536870912 | integer 0–17,179,869,184; zero is accounting only |
| tasks | 65536 | integer 0–1,000,000; retained scheduler records |
| coroutines | 131072 | integer 0–2,000,000; includes main VM/anchors |
| references | 65536 | integer 0–1,000,000; live external references |
| owners | 16384 | integer 0–1,000,000; retained non-bootstrap owner records |

Zero explicitly disables an admission cap. Invalid types, negative/nonfinite or
over-range values log one configuration warning at creation and use the default.
Defaults pass the actual 1,000-script/32-cancel workload and million-call
cached-require workload on both native Debug platforms. The slower cached-require
entry takes 2,473 ms; population peaks at about 50.5 million VM bytes, 33,002 tasks,
34,004 coroutines, 1,001 owners and 1,000 references. These justify compatibility
headroom for these workloads, not every project. See the measured work record.

`GLDomainHost.GetResourceStats(Client)` returns a Godot Dictionary without VM
pointers: creation, sandbox/closing/memory failure state; live/peak/limit VM bytes;
allocation/admission rejections; task/coroutine/reference/owner live and high-water counts;
and the effective policy. Resource failures use Runtime:Execution, Runtime:Memory
and Runtime:Scheduler categories. Memory failure avoids allocating a Lua trace.
`HostOperationsAvailable` distinguishes a cancelled bootstrap owner from a healthy
service context; `Failure` retains unavailable-bootstrap or terminal memory context.

## Qualification conditions

Production core and native fixtures must verify normal compatibility, actual
non-yielding interruption, catch/retry, nested/module/callback/invoke/shutdown
paths, quota rejection/GC/retirement and fresh-domain recovery. Risky fixtures run
as separately owned headless children. A watchdog kill is a failed test.
Preserve GL-019/022 coverage, dependency pins, disabled releases/updater, and
existing GL-017/018/020 qualification limitations.
