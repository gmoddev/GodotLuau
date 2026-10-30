# ADR-005: Confined transactional DataStore files

Status: selected for implementation on the GL-009 branch; not qualified or merged.
Extends ADR-003's DataStore operations only. Execution, HTTP, MemoryStore and
Messaging authority remain those of ADR-001/002/003/004. Executed results are in
[the work record](datastore-validation.md).

## Backend selection

| Option | Correctness/confinement | Durability/recovery | Integration cost |
|---|---|---|---|
| Confined transactional files | One stable root lock serializes cooperating writers; raw-content conditional commit detects transform conflicts; existing handle-relative authority can be reused | Stage, flush, atomic same-directory replacement, then namespace/metadata flush; abandoned stages are discarded under the lock | Preserves flat JSON names/encoding; requires a small native I/O helper and platform qualification |
| SQLite | Mature transactions and contention handling; stock pathname VFS does not preserve ADR-003's pinned-root/no-follow handling for database/journal side files | Established rollback/WAL recovery and configurable synchronization | New pinned dependency, custom confined VFS or weakened authority, migration/rollback and packaging; WAL adds shared-memory authority |
| Existing external infrastructure | No qualified DataStore transaction integration exists | No executed application durability/acknowledgment contract | Optional Nakama is an example stack, not this persistence authority; adding a deployment service is out of scope |

Select confined files. This preserves the established authority and physical
format while implementing a complete single-record transaction. This is not
selection by implementation convenience: the SQLite default VFS cannot simply
replace handle-relative confinement, and a custom VFS/migration would add a much
larger boundary. No public version-history backend or cross-key transaction is
introduced.

## Consistency and transform contract

All DataStore keys in one root share one private, stable lock file. It is never
replaced, deleted or locked through a replaceable data-file inode. This is stronger
serialization than per-key locking and deliberately avoids Windows case/legacy
alias inconsistencies between separate lock names. All participating binaries
must implement this protocol. Upgrade with old writer processes stopped; mixed
old/noncooperating writers, hostile same-credential OS writers, network filesystems
and independent replicas are unsupported. Existing name/scope/case collisions are
preserved, not silently resolved by a new naming scheme.

Reads acquire the lock and capture existence plus exact committed bytes. Set
validates and replaces under the same lock. Update reads a snapshot, releases the
lock, decodes it and calls the transform on the owning Lua coroutine. It then
encodes/validates the candidate and conditionally replaces only if existence and
raw committed bytes still match, checking and publishing while holding one lock.
An intervening change back to identical bytes is observationally equivalent and
can linearize at conditional commit; this token is not a public history version.

Managed transforms retain their existing ability to yield, and never hold an OS
lock while doing so. Nil aborts without writing; callback errors propagate without
a commit. A conflict retries the entire transform, at most eight attempts, with
bounded scheduler backoff. Arbitrary callback side effects are not exactly-once.
Non-yielding callback/close contexts cannot back off: a conflict raises explicitly.
Increment uses the same conditional protocol with finite numeric validation and
rejection of integer precision loss/overflow, not an unprotected read/write.
Remove conditionally commits a JSON null tombstone and returns the actual
committed previous value. The tombstone is JSON-compatible missing state, keeping
the flat filename instead of requiring a second, weaker Windows delete-ack path.

Get always reads committed state; missing/null clears cache. Native I/O, corrupt
JSON and validation errors raise rather than falling back to cache. Candidate
validation bounds traversal and rejects unsupported/lossy representations before
I/O. The existing DataStore legacy character encoding stays unchanged. Ordered
stores use the same transactions; sorting remains their local numeric-cache
snapshot. Public version methods remain documented compatibility stubs.

## Commit and acknowledgment

The worker pins/revalidates the trusted root and regular, single-link objects,
acquires the stable lock with finite contention time, and stages bounded bytes
in a fixed private same-directory file. Only the lock holder may recover/remove
an abandoned stage, after validating its type/link properties. No privileged
path, handle, lock or authority token is exposed to gameplay.

On Linux, sync the staged file, rename relative to pinned directory handles, then
sync the directory. On Windows local NTFS, open the staged file with write-through
semantics, flush it, atomically rename via its validated handle and pinned target
directory, then flush that same file handle for metadata before acknowledging.
Windows namespace durability must be qualified against these actual APIs; do not
infer directory-fsync equivalence or physical-media behavior beyond the OS/drive
contract. Other filesystems fail closed until supported/qualified. Actual power-
loss guarantees remain conditional on filesystem, kernel, device and flush support;
controlled process-kill tests do not prove physical power-loss behavior.

Atomic replacement is the visibility/linearization point. Definite errors before
publication leave the prior committed entry intact. Failure after publication
may be indeterminate, including a final durability/acknowledgment failure. Such
an outcome must not be reported as definite nonmutation: read latest committed
state and reconcile before retrying application side effects. No success is
returned before the selected sync/flush sequence completes. Native status must
separate invalid/denied, unavailable, corrupt, contention, conflict, timeout,
commit/durability failure and indeterminate outcomes.

## Scheduling and ownership

Disk I/O and OS lock waits execute in a small companion executable built from
the same source, located beside the extension. It executes native filesystem
operations only, with no Lua VM or callbacks. This costs process startup and an
additional packaged build product, but makes cancellation and extension unload
independent of an in-process thread blocked in filesystem code. It avoids a new
Lua scheduler and unbounded main-thread worker joins.

The existing host ticks finite native requests and protected completions. Native
admission validates current owner/domain/Server role and bounds before launching
anything. Use at most four helper processes globally, at most two requests per
owner, bounded IPC bytes per tick and a finite operation deadline. Owner/thread
retirement kills delivery, cancels the owned helper and releases Lua roots.
Reaping/retired slots stay accounted until cleanup; no unbounded cancellation
queue. A native continuation rejects manual resume so an old result cannot
complete a newer coroutine wait. Already published work cannot be rolled back
merely by cancelling its caller.

Normal managed calls yield. Existing non-yielding callbacks and the specifically
admitted BindToClose coroutine use a tightly bounded synchronous IPC pump, never
an unbounded OS lock/flush wait on the main thread. Its timeout may be indeterminate
for a fully submitted mutation. The GL-004 aggregate close budget still applies;
all authority checks and terminal allocation-failure denial remain mandatory.
Exact capacities/timeouts and frame/latency measurements are qualification facts,
not hard-real-time or total-process-memory guarantees.

## Qualification gates

Both platforms must execute independent-process conflicts, increments/removals,
yielding transforms, nil/error/retry/precision and cache/corrupt-data cases;
pre/post-publication fault and crash recovery; confinement and old-file migration
compatibility; owner/module/task/scene/close/OOM cleanup and stale-resume rejection;
finite admission/IPC/contention/latency bounds; and unchanged GL-003/004/005/core/
native regressions. The companion must build in CMake and SCons, carry source/
binary provenance in evidence, and fail closed when absent or incompatible.
Release publication and the updater remain disabled. No production behavior is
changed until this selected contract is recorded; no GL-009 closure is claimed
until its implementation and these gates actually pass.

## Operational limits and recovery

Current admission is four native requests/helpers across live hosts in an
extension generation and two per owner. IPC work is at most 1 MiB sent and 1 MiB
received per request per host tick; at most one new helper starts per tick. Normal
operations have a 30-second deadline, native lock contention a one-second bound,
and non-yielding/close IPC a 100 ms bound per call. Conflict backoff is 5–25 ms,
with eight total attempts. JSON is bounded to 16 MiB physical bytes, depth20 and
65,536 traversal nodes; lexical limits precede native parser allocation. Existing
logical/physical filename limits remain 200/240 bytes. The companion also bounds
its trusted root field to 4,096 bytes. These are finite capacities, not a claim
that native serialization/process startup cannot stall a frame or that VM quotas
account for Godot/OS allocations.

Shutdown kills delivery first, terminates owned children and spends at most50ms
reaping retired processes. A failed device/kernel operation can outlast process
termination; there is no unbounded main-thread join and no worker executes Lua or
extension code. Do not repeatedly unload/reload against a failed device while
uninterruptible children remain: stop the host and restore storage health first.
Normal process cleanup is an executed qualification fact, not a guarantee that
user-mode cancellation can force completion of arbitrary kernel I/O.

No import/migration is needed: existing leaves remain the committed authority.
After all writers stop, back up the root before upgrade. Never delete the stable
lock while a writer may exist. A terminated pre-publication write may leave the
private stage; a subsequent successful write validates and truncates that stage
under the lock. A terminated post-publication write leaves an entirely old or new
committed record. Re-read/reconcile any unacknowledged mutation; increments and
arbitrary transform side effects must not be blindly retried as exactly-once work.
Corrupt committed data raises; explicitly repair it with validated SetAsync or
restore an offline backup. No silent cached recovery or historical rollback exists.
For rollback to old binaries, stop every new writer first and retain the backup.
The raw JSON and null tombstones remain readable, but old writers restore the
historical transactional/cache/false-value defects.

The OS flush contract is conditional on truthful filesystem/device support:
[SQLite's atomic commit analysis](https://www.sqlite.org/atomiccommit.html),
[Windows FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers),
and [native relative rename structure](https://github.com/MicrosoftDocs/windows-driver-docs-ddi/blob/staging/wdk-ddi-src/content/ntifs/ns-ntifs-_file_rename_information.md).
The implementation adds no volume-wide administrative flush and claims no
Windows directory-fsync equivalence. Physical power-loss testing is outside the
controlled process-interruption qualification.
