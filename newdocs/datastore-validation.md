# GL-009 transactional DataStore work and qualification

## Starting checkpoint (2026-10-29)

Branch `persistence/gl-009-transactional-datastore` starts from verified local and
remote main `bc8ca88771a2170350e539de48f2cff89044d924`. The checkout is clean,
one worktree is active, and no competing file claims exist. Godot-cpp/Luau pins
remain `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Main must not be merged, releases and
the updater stay disabled, and GL-003/004/005 contracts remain applicable.

The supplied request ends mid-section 12, including in the user's follow-up.
Proceed with its supplied implementation/qualification scope. Preserve existing
MemoryStore and Messaging behavior outside the DataStore transaction boundary.

## Actual baseline trace

`luau_stdlib.h` constructs `ds_<name[_scope]>_<key>.json` through the private
GLServiceStorage bridge; ordered stores prepend `__ord_`. Existing underscore,
scope and Windows case collisions are retained physical-format limitations.
The bridge checks a live matching owner/domain, absence of allocation rejection,
Server kind and native non-client role before I/O. Only the already admitted
synchronous closing hook has ADR-003's narrow storage exception. Root handles,
logical names, physical leaf validation, bounds and legacy Latin-1 conversion
are enforced by GLServiceStorage/GLStorage. Raw gameplay file access is denied.

Public GetAsync reads each time but returns its local cache on a missing or empty
file. Actual native I/O failure raises before that fallback. Safe JSON decoding
swallows corrupt JSON and also collapses decoded false to nil. SetAsync encodes,
writes, then updates cache; its encoder can substitute `{}` on an encoding error.
UpdateAsync calls GetAsync, invokes the transform as ordinary Lua, and SetAsync
unless the result is nil. Thus yielding transforms are possible in a managed
coroutine; no OS lock exists across them. IncrementAsync is Get/add/Set.
RemoveAsync returns only its local cached prior value, not an atomic disk value.
OrderedDataStore uses the same operations; sorting/pagination is a snapshot of
that instance's numeric cache, not global transactional pagination. Version APIs
are compatibility stubs exposing one synthetic version, not history.

All physical operations are synchronous. Native writes validate a confined file,
truncate it in place, and write bytes without a sync/flush or transaction. Short
or failed writes raise but cannot restore overwritten bytes. GL-004 cannot
preempt a blocked OS call. Existing BindToClose permits finite synchronous writes;
yielded close hooks are cancelled. GL-005's host-owned waits and protected result
preparation offer lifecycle precedents, not persistence transaction guarantees.

## Acceptance and evidence discipline

Before production changes, reproduce independent Godot/server lost updates using
an observed-value barrier and examine missing/corrupt/write/delete/cache failures.
An isolated native probe calls the unchanged GLStorage implementation, pauses
immediately after real successful truncation, and is terminated by the owned
launcher. This is controlled process interruption/fault injection, not a real
power-loss test. Preserve original sentinels, commands, logs and input identities.

Backend evaluation must compare transactional files, SQLite and any actually
qualified external integration, then establish the authority/commit/durability,
transform/retry/cancellation and recovery contracts in an ADR before changing
production behavior. No backend or completed qualification is claimed yet.

## Executed baseline

Windows and Linux `gl009-baseline-v1` pass using the unchanged Debug extension,
native input fingerprint `cbb0115097636e91cac3f0228f6dd49abfb51a4c8dcc86f1a0189d58aeaf51cc`.
Two independent Godot ServerScript processes both read committed0 inside
UpdateAsync, signal observation, then are released sequentially. Both return1;
a fresh third process reads1 rather than2. This deterministically reproduces
lost updates without overlapping native writes or a timing-sensitive stress loop.

The native interruption probe first successfully writes and reads the sentinel
`{"Sentinel":12345}`, saving an independent copy. Its second production write
actually truncates the target, signals the controller, and pauses. The owned
controller terminates the child at that point. The target is empty on both
platforms while the saved prior sentinel remains valid. This reproduces process-
interruption loss of the previous acknowledged value; it is not power-loss proof.

Both Godot failure actors confirm missing-file stale-cache42, corrupt JSON->nil,
JSON false->nil, and fresh-instance RemoveAsync returning nil for existing19.
Replacing a leaf with a directory causes write/read/delete to raise, while the
failed write leaves cache7 unchanged. Native GL-003 I/O failures are therefore
not silently reported as successful writes. Results and copied baseline libraries
remain in worker gl009-baseline-v1 trees; production code is still unchanged.

## First native prototype

The selected file backend and companion protocol compile on both workers. Linux
passes native helper Set/read/CAS/conflict and 4 MiB IPC. Windows reaches staging
and flush but the Win32 rename wrapper returns ERROR_INVALID_PARAMETER when given
a pinned RootDirectory. Its call is replaced by native NtSetInformationFile's
relative FileRenameInformation, matching ADR-003's native-API/no-absolute-fallback
approach. This is a candidate correction awaiting execution, not a passing Windows
atomicity claim. No Lua DataStore method has been switched to this backend yet.

The native-relative Windows rename correction passes, but its first large IPC
probe times out: peeking a pipe read handle shared with the child's blocking
fread can serialize behind that read. The sender now uses checked byte-mode
PIPE_NOWAIT writes and preserves actual partial-write counts, without sharing a
read handle. Windows and Linux native helper Set/read/CAS/conflict/4 MiB IPC pass.
The first integrated adapter builds then reject range-for iteration over the
pinned godot-cpp Array, before runtime testing; indexed iteration corrects this
API mismatch. This is recorded separately from eventual runtime qualification.

The selected prototype now routes DataStore only through owner-aware native
requests and its companion; existing MemoryStore/Messaging paths are unchanged.
Strict DataStore codecs retain the legacy character conversion, and yielding
transforms use bounded optimistic retries. Null tombstones, latest-state cache,
previous-value removal, finite/precision checks and manual-resume continuations
are implemented candidates. They are not yet qualified or a resolved GL-009.

The first integrated Windows/Linux run terminated in the new strict encoder's
cycle/depth rejection path: recursive C API pushes exceeded the reserved Lua
stack before the traversal limit. A captured headless Windows breakpoint trace
and source inspection identified the missing stack reservation. The encoder now
checks additional stack space at every recursive entry; decoding reserves the
bounded converter's full stack after validating nesting. This is a new-prototype
defect, not an inherited baseline failure. Both platforms' v4 integrated fixture
now pass CRUD/false/nil-abort/transform-error/yielding-transform, invalid/cyclic
value rejection, Client denial, independent frame progress, previous-value
removal, atomic-increment API and exact BindToClose save. Linux helper permission
loss in fixture copying was also corrected by preserving executable mode.
These are initial integration facts, not complete GL-009 qualification.

## Expanded qualification in progress

The first complete v1 matrix passes all72 existing core cases on Windows/Linux
Debug, Release and core ASan; all43 existing native actors plus21 new DataStore
actors pass in both platforms' Debug/Release and matching Linux native ASan/LSan.
This is preliminary source evidence, superseded by subsequent hardening, not the
final candidate identity. Windows native ASan remains the separately documented
GL-018 host gap and is not relabeled as passing.

The added actors establish deterministic Update-vs-Update/Set/Remove conflicts,
two-process increments, actual previous-value removal, nil/error/no-cache fallback,
bounded repeated yielding transforms, owner/module/task/manual-resume/shutdown/OOM
cleanup and frame progress during native lock contention. Native fault/kill tests
reach real pre/post-publication stages and recover through a fresh process.
The inherited filesystem fixture now waits for accepted completion markers before
firing callbacks registered after DataStore operations; its assertions are retained.

Before freezing the candidate, additional checks now bound JSON lexing before
Godot parser allocation, validate helper exit/trailing diagnostics, map permission
errors and reap cancelled processes during scene shutdown. The v2 corrupt-value
fixture correctly catches an additional encoding edge: Godot replaces escaped
JSON NUL with U+FFFD and emits a diagnostic before the post-parse check. The new
lexical pass rejects that escape before parsing; v2 is a recorded failed run,
not qualification. Missing/incompatible helper actors and 4MiB frame measurements
are included in the next full run. No release/updater/main action is permitted.
