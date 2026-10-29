# GL-003 filesystem boundary work and qualification

## Baseline

Starting local/remote main: `2e899956fa685b0b5cbe8e058c506c9d2ffc760f`.
Dedicated branch: `security/gl-003-filesystem-capabilities`; main is not to be
merged or changed. Initial tree was clean, one worktree, unchanged Luau and
godot-cpp pins, and no competing source changes were present.

Actual Windows and Linux Debug GDExtensions reproduce the raw native bypass in
`FilesystemIntegration.gd`: ServerScript, LocalScript, required ModuleScript,
signal callback and source reload can read a disposable absolute-path sentinel
outside service storage. Both roles also exercise native write/read/exists/delete
on a disposable copy, and directory listing. The client DataStore operation
rejects while the raw native operation succeeds. Original sentinel bytes remain
unchanged. No personal/project production data or system configuration is used.
Both bounded existing-runner children exit zero with
`[Runtime:FilesystemTest] PASS baseline`; captured stdout/stderr are under
the owned workers' `gl003-baseline` result directories. This is local gameplay
filesystem authority, not proof of remote script injection or remote code execution.

## Inventory and design checkpoint

The native bridge is installed in `luau_script.cpp`. DataStore/OrderedDataStore,
Messaging and MemoryStore use it in `luau_stdlib.h`, including mailbox discovery.
Their current flat `user://ds_*`, `user://msg_*`, `user://mem_*` files intentionally
share the project user-data directory across processes. MemoryStore queues remain
process-local. No transactional/concurrency or durability correction is included.

Read-only independent boundary investigation also finds gameplay routes to
DataModel's editor structure helpers, arbitrary `_GL_NET.call` methods (including
host-key helpers), and caller-selected image, sound and animation resource paths.
Fixed packaged shader/avatar/grid reads and engine startup/configuration reads
are distinct host operations. These routes must be accounted for before closure.

Selected direction: deny raw gameplay filesystem operations at their native
entry points and provide typed, native-checked storage operations with explicit
service namespaces and per-operation permissions. No raw path or numeric owner
token constitutes a grant. Every operation checks current native owner/domain
liveness and native role; Lua globals, environment identity and bootstrap-owner
identity do not authorize host access. Mutable/getfenv-accessible service closures
may delegate only the same confined service authority, never arbitrary paths.

Preserve existing service names, serialization and shared physical filenames.
Path/size/operation validation precedes mutation. Service root/leaf operations
need no-follow/handle-based platform confinement rather than canonicalize then
reopen. Native I/O remains non-preemptible and outside exact VM allocation
accounting. GL-004 controls remain unchanged; GL-005 and GL-009 remain open.

## Implemented checkpoint and focused verification

The branch implements [ADR-003](adr-003-native-storage-authority.md): denied raw
operations, native service records, operation-specific names and permissions,
handle-relative service storage, and bounded read/write/list operations. Editor
structure mutation, arbitrary `_GL_NET.call` methods and external dynamic asset
paths are also gated. Project assets remain trusted ResourceLoader content;
this is not a sandbox for hostile projects or same-credential OS writers.

An additional immutable `2e89995` source snapshot builds the baseline adapter
against the same pinned dependencies. The `gl003-baseline-retired` Windows/Linux
Debug runs also reproduce a captured raw read invoked by a live sibling after
the original script is disabled. They retain the original `gl003-baseline`
evidence rather than replacing it.

The first enforced probe (`gl003-enforced-1`) failed its explicit-denial assertion:
`_GL_NET.call` returned nil for an absent service before checking its method
allowlist. No host-key access was observed. Moving the native allowlist and owner
check before object lookup fixes this; `gl003-enforced-2` passes on both workers.

`gl003-services-probe` passes on Windows/Linux Debug: 69 production core cases and
three actual GDExtension filesystem actors. These exercise native raw denial,
Server/Client separation, module/coroutine/task/signal calls, path/name/encoding
rejection, legacy non-ASCII data, project image/sound/animation access, editor and
network helper denial, reload, scene replacement and final BindToClose writes.
Two independent server processes exchange Messaging mailboxes, DataStore/ordered
values and MemoryStore map values/expiration through the existing shared root.

The production backend tests include observed hard links, intermediate links,
Linux symlinks/FIFOs and Windows real junctions, concurrent directory replacement,
unchanged outside sentinel bytes/metadata, a 16 MiB roundtrip and 1,024-record
enumeration. The native service fixture roundtrips a 4 MiB DataStore value.
These workloads establish exercised bounds, not arbitrary I/O latency guarantees.

The fix-finding workflow's independent initial investigation and final read-only
candidate review are complete. The latter reported no concrete surviving bypass
or unintended regression in reviewed paths; source review is not runtime proof.

The final local Debug/Release/sanitizer and SCons qualification passes below.
Hosted CI and publication remain pending at this commit.

The initial complete matrix (`gl003-final`, native fingerprint
`ea9756beed9b9610bb379a5182f4a33844f427e1300f2d410a468f63755bb52d`)
passes six core configurations and all 195 native actors. Final review separates
the bounded domain-closing diagnostic from capability-unavailable. The final
`gl003-qualified` rerun uses fingerprint
`16b67f44c4120b3a9790e501c7f8ed1753d8559530e5b4d76318742ab5f932a5`;
the first matrix remains intermediate evidence rather than proof of that revision.

## Reproduction and qualification commands

Baseline: archive only `src` from `2e89995` into an owned immutable snapshot;
configure the existing optional `GL_BASELINE_SOURCE_ROOT` adapter target against
that snapshot, build `GodotLuauBaselineAdapter --parallel 2`, then run
`FilesystemIntegration.gd -- --baseline` through the existing `Prepare/Start/Check`
launcher with a fresh project and isolated profile. Both baseline generations
record zero exit, not just log markers.

Candidate: for each existing CMake Debug/Release/ASan directory, run
`cmake --build <build> --target ExecutionDomainTests GodotLuauAdapter --parallel 2`
(Windows ASan builds only the core target), followed by
`ctest --test-dir <build> --output-junit <report> --test-output-size-passed 65536 --test-output-size-failed 65536 --output-on-failure`
and `python tests/runtime/CheckCoreCI.py report <report>`.
Native groups use `python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh-group> <group> --timeout <seconds>`:

| Group | Switches | Actors | Timeout |
| --- | --- | ---: | ---: |
| Lifecycle | `--teardown --coordinated-close` | 8 | 60 s |
| Existing network authority | `--security` | 10 | 60 s |
| Functional animation | `--animation` | 10 | 60 s |
| Resource rejection/recovery | `--resources` | 8 | 15 s |
| Filesystem and services | `--filesystem` | 3 | 60 s |

Windows/Linux use verified official Godot 4.7.1; Linux sanitizer native tests use
the existing matching full ASan/LSan engine, with leak defaults unchanged. Windows
full native ASan remains the separately documented GL-018 host limitation.
SCons uses `platform=windows|linux target=template_debug|template_release -j2`;
Windows invokes the already approved portable SCons 4.5.2 runner. Each resulting
distribution product runs the eight resource actors and three filesystem actors.
The existing process-ownership tests, one 1,000-script population trial and one
million-require-call trial per platform accompany the regression checks; these
are workload controls, not statistical performance claims.

Owned worker roots are `C:\Sandbox\Codex` on `dockerbox` and `/work` in the owned
Linux container. Builds reuse pinned dependency/incremental caches with two jobs;
headless tests retain bounded logs without foreground windows or editor restarts.
Final result identities and artifact hashes are retained in the
[qualification manifest](evidence/gl003-filesystem-capabilities-2026-10-29.json).

## Final local qualification

The final 78-file native input fingerprint is
`16b67f44c4120b3a9790e501c7f8ed1753d8559530e5b4d76318742ab5f932a5`.
Both workers match all 26 normalized native fixture/harness hashes and the
production-core test source hash in the manifest. Dependencies remain pinned.

| Configuration | Core cases | Full native actors |
| --- | ---: | ---: |
| Windows Debug | 69 PASS | 39 PASS |
| Windows Release | 69 PASS | 39 PASS |
| Windows ASan | 69 PASS | GL-018 limitation retained |
| Linux Debug | 69 PASS | 39 PASS |
| Linux Release | 69 PASS | 39 PASS |
| Linux matching ASan/LSan | 69 PASS | 39 PASS |

All four SCons Windows/Linux Debug/Release products build and pass eight resource
actors plus three filesystem actors each. The process suite passes 14 cases on
Linux and eight applicable cases on Windows (six POSIX-only skips). Python syntax,
changed Markdown links, source references, final diff and publication guards are
checked. No sanitizer failure or forced watchdog exit is accepted as a pass.
Population/require controls pass on both platforms, and the existing Linux native
hot-path benchmark completes. These are exercised workloads, not a speed claim.

Final artifacts are `gl003-qualified-{windows,linux}-{debug,release,asan}` under
each worker's recorded results root (Windows native ASan is excluded). Core
JUnit/build/check logs use `gl003-qualified-*` under the logs root. SCons products
and their separate filesystem results use `gl003-qualified-scons-*`.
Intermediate `gl003-final`, focused `gl003-services-probe`, both baseline
generations and the first failed denial probe remain retained.

The native boundary shown vulnerable on `2e89995` no longer reproduces in the
qualified candidate. Legitimate services retain public names/return shapes and
shared physical files; their newly explicit failure and Client persistence
restrictions follow ADR-003. GL-005, GL-009, GL-017/018, GL-020 adversarial
qualification, trusted project graphs and same-credential OS writers remain
outside the fix. This is no claim of remote script injection or an OS sandbox.
