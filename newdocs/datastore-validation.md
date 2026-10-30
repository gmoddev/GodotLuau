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

V3 Windows Release passes its 23 DataStore actors but the existing filesystem
fixture catches a close-hook SetAsync timeout at the provisional 100ms sync bound;
the helper had not published the final value. The caller receives indeterminate
rather than false success. The finite sync bound becomes250ms to accommodate
ordinary Windows process startup; cancellation reaping also precedes close hooks
so retired requests do not needlessly consume their admission slots. These are
explicit changes to the selected bound, requiring final qualification again.
Native normal calls still yield and native lock waiting stays off the frame
thread. V3 is retained as preliminary/failed evidence, not the final matrix.

## Final local candidate (2026-10-30)

Implementation `d4dfb32ee89aef0968725597371db753259acbac` retains its preceding
decision and implementation commits. Native inputs are87 files, LF-normalized
SHA256 `c88311513a6a91e195a6f37712a19dada19754c02222f26ad02b7ac6048e622c`.
Both workers reproduce this identity and verify full pinned dependency contents.
V4 replaces the preliminary matrices above; results below use this source.

| Gate | Windows | Linux |
|---|---|---|
| Core Debug / Release / ASan | 72 /72 /72 pass | 72 /72 /72 pass |
| Full native Debug / Release | 66 /66 pass | 66 /66 pass |
| Matching native ASan/LSan | GL-018 gap; unrun | 66 pass; no suppressions |
| SCons template_debug / template_release | Both build; 38 actors each pass | Both build; 38 actors each pass |
| Owned process launcher | 14 tests, 6 platform skips | 14 tests pass |

Each full native configuration retains all43 earlier actors and adds23 Godot
DataStore actors plus native commit/fault/recovery probes. The backend rejects
hard links at committed, stage and lock leaves on both platforms, retains an
outside sentinel, and recovers after rejection. Linux also rejects leaf/root
symlinks; existing core tests retain Windows junction/reparse/race checks on the
shared pinned-root authority. Four genuine process-kill stages preserve old123
before publication or valid new999 after it; a fresh process reacquires the lock
and overwrites the validated stage. These are not OS/power-loss tests. SCons
exercises DataStore, HTTP, resources and filesystem on each distribution product,
including its matching independently built companion.

### Observed latency and frame impact

These are single controlled headless sequences, not a throughput distribution.
The small sequence includes CRUD, yielding transforms, eight forced conflicts,
precision rejection, scope aliases and ordered/version compatibility. The large
sequence performs 4MiB Set/Get/Remove. An independent counter progresses across
native I/O. Codecs/process creation still cost frame time; yielding alone is not
used as proof that native disk I/O moved off the frame thread.

| Configuration | Small sequence ms / peak frame gap ms | 4MiB sequence ms / peak frame gap ms |
|---|---|---|
| Windows Debug | 3256 /23.820 | 1100 /168.482 |
| Windows Release | 2162 /9.128 | 882 /134.169 |
| Linux Debug | 1468 /40.592 | 1621 /68.533 |
| Linux Release | 1421 /13.134 | 1601 /47.412 |
| Linux ASan/LSan | 1607 /8.188 | 2219 /478.938 |

The small-sequence acceptance threshold is250ms. The large sequence records its
cost; it does not assert a sub250ms codec bound. Per-operation limits are not hard
real-time or total-process-memory caps. No aggregate disk quota/collector is added.

### Execution and audit trail

Windows reuses `C:\Sandbox\Codex\Workspaces\GodotLuau`, persistent
`Builds\GodotLuau\runtime-msvc-{debug,release,asan}`, and
`Logs\GodotLuau` / `Artifacts\GodotLuau`. Linux uses the owned
`codex-godotluau-qualification` container, `/work/source`, persistent
`/work/builds/linux-{debug,release,asan}`, `/work/logs` and `/work/results`, backed
by `/opt/codex/godotluau`. Builds use two jobs. No controlling-PC native build,
new installation, vendor edit, visible editor or crash dialog is required.

Executed command families (absolute paths/configurations expanded in worker logs):

```text
cmake --build <configuration> --target ExecutionDomainTests GodotLuauAdapter DatastoreBackendProbe --parallel 2
ctest --test-dir <configuration> --output-junit <report> --output-on-failure
python tests/runtime/CheckCoreCI.py report <report>
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh> --datastore --timeout 60
python tests/runtime/RunQualification.py ... --http / --security / --animation / --resources / --filesystem
python tests/runtime/RunQualification.py ... --teardown --coordinated-close
scons platform=windows|linux target=template_debug|template_release -j2
python tests/runtime/FixtureProcessTests.py
```

Windows uses the already approved portable SCons4.5.2 runner; Linux uses its
existing SCons. A matching fully instrumented Godot4.7.1 hosts Linux native
ASan/LSan. Windows core ASan is executed; native GL-018 is explicitly unrun. No
GL-017 diagnostic or GL-020 adversarial gap is reclassified by functional passes.
Worker records retain library/companion/engine digests, native inputs, harness
hashes, result/log hashes, dependency identity and baseline sentinel/library.
Early prototype log paths were reused; their narrative failures are not presented
as a complete archived log corpus.

Hosted core/native CI is green on both platforms at this implementation, with
all four artifacts verified; final disposition follows below.
Main, release publication and updater distribution remain unchanged.

### Retirement follow-up

After the matrix, inspection found one defunct helper predating V4 and no live
helpers. A fresh-container 40-actor native ASan lifecycle/OOM stress passes but
leaves one terminated helper adopted by the container's `sleep infinity` PID1.
This exposes a cleanup-environment requirement: bounded runtime reaping does not
promise to wait indefinitely, and that PID1 never reaps adopted children.

A second fresh-container run uses a task-scoped Linux child-subreaper controller
(`prctl(PR_SET_CHILD_SUBREAPER,1)`) without changing runtime source or disabling
ASan/LSan. All40 lifecycle/OOM actors pass again. The controller adopts/reaps two
terminated helpers (SIGKILL status9), and final process inspection finds no live
or defunct Godot/helper descendants. Records remain in
`/work/results/gl009-final-retirement-{stress,supervised}`. This qualifies bounded
cancellation plus host reaping, not guaranteed immediate waitpid completion.
ADR-005 explicitly requires an init/supervisor that reaps orphaned children;
native extension hot reload with unretired children remains unqualified. The
owned container is stopped after evidence collection; unrelated services stay up.

## Final disposition

**Implemented and qualified within ADR-005's supported scope; ready for a separate
integration decision. No main merge or production distribution is performed.**
Runtime `d4dfb32ee89aef0968725597371db753259acbac` preserves the decision commit
`0792f69` and implementation `d987c8e`. Main remains `bc8ca88`.

Fresh hosted [core run40999872768](https://github.com/gmoddev/GodotLuau/actions/runs/40999872768)
and [native run40999871845](https://github.com/gmoddev/GodotLuau/actions/runs/40999871845)
pass both Windows/Linux jobs: core72 and native66 per platform. All four downloaded
ZIP digests match GitHub metadata. Native summaries match the exact implementation,
87-file native fingerprint, 43-file harness map and verified official engine
digests. All423 native log hashes and result groups match the archives, including
the four-stage native commit evidence. The earlier `d987c8e` native run was
cancelled as superseded; it is not substituted for the final run.

The [machine-readable evidence](evidence/gl009-transactional-datastore-2026-10-30.json)
records these artifacts plus local CMake/SCons/core/native/retirement results,
baseline reproductions, product/helper/engine hashes and pinned dependencies.
The final documentation-only commit does not change those native inputs or
restart path-filtered runtime CI. Release workflow admission remains literal
false/read-only; `RuntimeUpdatesAllowed()` remains false. No generated binary or
release archive is published; no upstream message or PR is created. Caches and
evidence are retained.

Final capacity inspection found the Linux volume had no unreserved free space.
Cleanup removes330 hash-identical generated GL-009 qualification library copies,
reclaiming20,177,328,808 bytes (20.2GB). Each removal is verified against a retained
identical library; baseline copies and canonical final CMake/SCons products,
profiles, logs, evidence and build/dependency caches stay intact. The detailed
removal manifest remains in `/opt/codex/godotluau/logs/gl009-duplicate-reclamation.json`
with its digest in the evidence record. The volume now has19GiB available (81%
used). The task-owned container is stopped; unrelated services are unchanged.
