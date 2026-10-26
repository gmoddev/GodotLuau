# Shared-domain implementation work log

## 2026-10-26: Baseline and investigation

- Starting revision: `8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
- Working branch: `runtime/shared-domains`; starting checkout clean.
- Read root policy, documentation authority, architecture, invariants, issue
  ledger, and the supplied review validation.
- Initialized the existing pinned submodules without upgrading them:
  godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and
  Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.
- Existing executable coverage: a chat scene/script fixture; no automated runtime
  suite or sanitizer gate in the tracked release workflow.
- Build worker reachable as `dockerbox` (`HOSTPC`), 24 logical CPUs, approximately
  18 GiB free RAM at initial probe; no compiler/build processes reported by the
  targeted process probe. MSVC Build Tools 18, GCC 13.2, CMake, Ninja, and a
  controlled Python directory are present. No Godot executable or SCons command
  was found on the worker PATH; further bounded tool inspection is pending.

### Lifecycle evidence before runtime edits

| Area | Baseline implementation and migration consequence |
| --- | --- |
| VM allocation | `ScriptNodeBase::iniciar_corrutina`, `luau_script.h:960-983`, creates/registers one state and writes context into globals/registry |
| VM teardown | EXIT_TREE at `850-895` cleans RunService/remotes by state, runs close callbacks, unregisters and closes; destructor also closes |
| Script/run identity | `L_main`, `L_thread`, node-owned task/wait vectors; registry keys `GODOTLUAU_SCRIPT_NODE`/`GODOTLUAU_MAIN_STATE` assume one script per registry |
| Startup/roles | ModuleScript early return, template exclusion, deferred network ServerScripts, RunContext flags and Enabled checks in `iniciar_corrutina` |
| Globals | `game`, `workspace`, `script`, context flags, task functions and embedded stdlib installed per VM; stdlib services use `_G[__SVC_*]` |
| Require | Registry result cache plus Lua loading table; yieldable pcall; module environment currently forwards global writes to caller globals; only same-coroutine recursion is detected |
| Tasks | spawn resumes immediately; defer/delay enqueue node-owned threads; numeric yields drive timers; external sentinels suspend automatic resumes |
| Native callbacks | services, characters, UI and remotes store state/ref pairs, create threads and resume directly; some callback results that yield are not scheduler-owned |
| External waits | child waits store parent ObjectID, signal resumes use a shared queue, network invokes store call IDs and refs in the executable script |
| Cleanup assumption | VM/state identity currently doubles as script identity; sharing that pointer without new ownership would invalidate unrelated callbacks |
| Known hazards | WaitForChild stores a raw Node upvalue; NetworkService methods store raw service upvalues. Neither is covered by wrapper ObjectID checks |
| Close hooks | `gl_close_cbs` is owner-state indexed; a second fallback BindToClose vector is present. Teardown must not run arbitrary callbacks once owners/VM are invalid |

No baseline runtime behavior has been executed yet. The observations above are
source traces, not crash or performance measurements.

## Decision checkpoint

[ADR-001](adr-001-shared-execution-domains.md) records the selected architecture,
ownership, environment/cache semantics, compatibility changes, and acceptance
requirements before runtime modifications. Runtime implementation is pending.
GL-014 remains open. Other issue statuses are unchanged.

## Core implementation checkpoint

- Added `gl_execution_domain.h/.cpp`: one VM per domain, isolated owner
  environments, a domain-owned scheduler, independently owned module
  initialization, shared result identity, sticky errors, cycle detection,
  invalidation, and owner-scoped registry references with non-recycled IDs.
- Added executable C++ regressions against the production core and pinned Luau.
  The initial MSVC Debug build and CTest run passed on `dockerbox` before Godot
  integration. This is core qualification, not a Godot/ENet result.
- Initial build command used the wrong CMake directory and failed before
  configuration. Corrected to the installed nested `cmake-3.31.10-windows-x86_64`
  directory. No software installation or local native build was performed.
- Successful configure/build: CMake 3.31.10, Ninja, MSVC 19.51.36260, Debug,
  target `ExecutionDomainTests`, `--parallel 4`, approximately 9.5 seconds.
- Successful run: `ctest --test-dir
  C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-debug
  --output-on-failure --timeout 30`; 1/1 CTest target passed in 0.08 seconds.
- Worker workspace: `C:\Sandbox\Codex\Workspaces\GodotLuau`.
  Incremental build: `C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-debug`.
  Logs: `C:\Sandbox\Codex\Logs\GodotLuau\runtime-msvc-debug-build.log` and
  `runtime-msvc-debug-tests.log`. Existing dependency/build caches are preserved.

## Godot integration in progress

- ScriptNodeBase no longer allocates/closes a VM or owns a legacy task scheduler.
  It selects its execution domain, bootstraps native bindings once per domain,
  creates an owner environment, and delegates execution/cancellation.
- Added a lazy SceneTree runtime host to own/tick domains and child/signal/remote
  condition queues. Module identity/env binding uses live Godot ObjectIDs.
- Migrating native callback dispatch to owner anchors and tracked references;
  native script lookup no longer uses a mutable VM-wide script registry slot.
- Adjusted WaitForChild to resolve its argument through ObjectDB and NetworkService
  method upvalues to retain ObjectID handles. GL-001/GL-002 are not closed: focused
  Godot destruction regression evidence is still required.
- Added an optional CMake adapter target for qualification; SConstruct remains
  the existing distribution build path. Full adapter compilation and Godot
  integration execution are pending. GL-014 remains open.

- First full adapter build compiled the pinned Godot bindings and the original
  extension translation units, then failed in the new host translation unit on
  an incomplete `godot::ScriptLanguage` type. Added the required native header;
  incremental rebuilding preserves the already-built vendor bindings.
- Found existing local Godot 4.7.1 console/engine executables under
  `C:\Users\aiden\Downloads\Godot`. Small bounded headless adapter fixtures can
  use this existing installation; all sustained compilation remains on the
  worker. The fixture runner captures stdout/stderr, hides processes, inherits
  Windows error-dialog suppression, and uses a separate project without the
  updater plugin. No engine or toolchain was installed.

### Integration failure and correction

- The generated fixture configuration initially used Windows PowerShell's
  BOM-producing UTF-8 encoding. Godot failed to find the extension entry key;
  switched the ASCII-only config files to ASCII. This was a harness failure.
- The first DLL then crashed in `GLExecutionDomain::SetErrorHandler` while the
  native host was being initialized. Captured the failure headlessly and resolved
  the stack offline with DbgHelp and the worker PDB; no debugger was attached.
- Investigation found a stale adapter-core object after timestamp-preserving
  synchronization: the earlier incremental build recompiled the native host and
  test core, but not the DLL's core object after the ownership header changed.
  Edits had occurred while the previous remote build was running; preserved local
  timestamps predated its object output. This mixed class layouts within the DLL.
- Recompiled the core/host together and temporarily checked their compiled class
  sizes (both 816 bytes). The fixture passed. Removed temporary layout logging.
  Subsequent sync/build checkpoints compare content hashes and advance timestamps
  only for changed source files, avoiding both stale objects and unnecessary
  vendor rebuilds.
- Godot 4.7.1 fixture passed shared Server/Client modules and separate caches,
  interleaved script identity, isolated globals, yielding RunService callbacks,
  child resolution, destruction with outstanding work, surviving module cache,
  disable/reload/re-enable, and retained WaitForChild after target destruction.
  Initial successful run completed in approximately two seconds locally, using
  the existing console executable and a two-thread fixture worker pool.
- Full adapter compile passed after the native-header fix (approximately 17.7
  seconds incrementally). Logs and binaries are task-owned artifacts; no release
  workflow was dispatched. Network/process-role and sanitizer qualification remain
  pending; GL-014 is still open.

## Network and sanitizer checkpoint

- The native core passed MSVC AddressSanitizer qualification, including the pinned
  Luau VM/compiler. Configure flags: `/fsanitize=address`, Debug `/Zi /Od` without
  `/RTC1`, linker `/INCREMENTAL:NO`, Ninja `--parallel 4`; CTest passed in 0.31s.
  Build/log root: `C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-asan` and
  `C:\Sandbox\Codex\Logs\GodotLuau\runtime-msvc-asan-build-tests.log`.
  This does not instrument the Godot executable or qualify all native adapters.
- Bounded headless fixtures passed local single-player, listen-host with both
  domains, dedicated server with two clients, and the editor-style process flags
  `--glindex 1/2/3 --glcount 2`. The latter exercises the editor launch convention
  without opening the editor or its updater. The three-process fixtures completed
  in a few seconds with a two-thread pool per process.
- Native network fixtures passed shared cache identity in each process/domain,
  wrong-role non-execution, a negative ServerStorage access check, yielding
  RemoteEvents/RemoteFunctions and handler attribution, and destruction while a
  RemoteFunction response was outstanding. Listen-host also keeps Server/Client
  module values separate in one process.
- The dedicated run logged two ENet `max channels: 0` diagnostics during peer
  teardown, despite functional PASS results. These remain visible qualification
  evidence; no baseline reproduction or production transport hardening is claimed.
  Client ServerStorage denial logs are expected negative-test output.
- Integration revealed that the RemoteFunction response map/call-ID allocator
  must have external inline linkage for the new host translation unit; changed
  those two shared bridge helpers without altering the wire format or authority
  checks.
- Added focused checks for cancellation of native signal waiters, template and
  RunContext rules, native module rename/reload/replacement, retained service
  getters/mutators, and replicated Instance values. Final execution is pending.
- Bounded immediate resume nesting at 64: deeper module/spawn chains continue
  on a subsequent scheduler tick. This avoids unbounded C++ recursion and is not
  an instruction or memory quota (GL-004 remains open). Dependency cycle tracking
  follows module initializer threads, not unrelated child tasks spawned by a
  module. Added regressions for both cases.

## Shared Lua services and scene ownership

- Review found a remaining per-script assumption in Lua services: a shared
  service firing a stored callback could schedule it under the publisher or
  service poller's owner. Added an owner-bound callback bridge and migrated the
  shared signal helpers, CollectionService, ContextActionService, teleport arrival
  signal, and MessagingService subscriptions. Invalid owners become no-op
  dispatches; active yielding handlers remain scheduler-owned by their subscriber.
- MessagingService's first-subscriber polling now uses a trusted domain-owned
  spawner. The temporary hook is captured by the embedded stdlib and removed
  before any user script starts, including initialization-error cleanup. It does
  not expose a gameplay path to evade script cancellation or change domain role.
- Runtime host ownership follows the running current scene; replacement shuts
  down the old domains and defers destruction until active native calls return.
  Added a native scene-replacement test for fresh globals and game/script handles.
- Added native module rename/reload/replacement, template exclusion, RunContext,
  signal cancellation, callback self-destruction and repeated teardown fixtures.
  Final debug/ASan and Godot fixture runs are still pending for this revision.

- Native condition waits now retain non-recycled guard references, including
  waiters registered on detached/orphaned native sources that a scene-tree cleanup
  cannot visit. Cancellation clears guard references before thread reclamation;
  queued node arguments use ObjectIDs. Added an orphan-source/scene-replacement
  regression and a manually resumed coroutine's transition into managed waits.

## Final regression findings

- Expanded single-player, listen, dedicated-plus-two-clients, and editor-flag
  fixtures passed, including module rename/reload/replacement, native service
  handles, replication, and scene replacement. These preceded the final dispatch
  bound/coroutine guard changes and will be rerun against the final DLL.
- ASan caught a native stack overflow in the 256-module/200-spawn deep-chain
  test at the initial resume-depth bound of 64. Reduced immediate nesting to 8;
  deeper dispatch continues on subsequent ticks. Updated the spawn fixture's
  tick budget to allow the intentional deferral. This is a concrete regression
  found during qualification, not a passed sanitizer result for the earlier code.
- Manually resumed coroutines now join timed/module/native wait ownership.
  Guarded coroutine.resume/wrap reject retired owners and cancelled tasks,
  including retained handles that were never started. Ordinary explicit yields
  in manually driven coroutines retain manual scheduling semantics.
- Script nodes also retain a non-recycled run guard before consulting their
  native owner pointer during cleanup, so a replaced domain cannot make an old
  node mistake a reused Lua anchor address for its previous run.
- Added public service regressions exposed a migration bug: GetService still
  read `__SVC_*` directly from the global environment, while the new `_G` is a
  separate domain table. That bypassed Lua services and returned a native
  CollectionService without the signal API, or nil for ContextActionService.
  Corrected the lookup to `_G[__SVC_*]`. The fixture also initially attempted the
  client-only action service from Server; moved action binding/dispatch to
  separate Client owners without broadening capabilities. The tests retain the
  public GetService path to prevent this regression.
- Final lifetime review made anchor-map erasure compare owner identity before
  removal. A retired anchor can be collected while a retained Lua coroutine
  keeps its metadata alive; its address must not erase another domain's newer
  anchor during shutdown.
- Restored inherited one-shot child/invoke infinite-wait diagnostics in the host
  scheduler, retaining the child-wait call stack. The native fixture waits past
  five seconds, requires the diagnostic in captured output, then creates the
  child and verifies normal continuation.

## Final candidate qualification checkpoint

- Final Debug extension/core build succeeded with four remote jobs. CTest passed
  all 35 core cases in 0.22 seconds; ASan passed the same 35 cases in 0.71 seconds.
- Final DLL passed single-player integration (including public Lua services,
  local synchronous invoke, yielding BindableEvent and the captured child-wait
  warning/continuation) and Listen/Dedicated/Editor network modes. Each mode used
  a 30-second bound and required process exit zero and PASS markers.
- Final multi-process modes emitted the expected client ServerStorage denials;
  no ENet diagnostic occurred in those final modes. Earlier intermittent ENet
  teardown output remains unresolved evidence, not a claimed transport fix.
- Compared SHA256 of all 22 changed/new production files plus test CMake/CPP
  between local checkout and worker; all matched. Tested DLL SHA256 is
  `25C1EC0898FAEEC453F63043D5B99D8702C75CF62B0416A14A35A35934081358`.
- Updated architecture/invariants, English/Spanish runtime descriptions,
  issue progress and exact reproduction instructions. Checked local links in
  11 documentation/policy files and `git diff --check`; both passed.
- Implementation and exercised Windows functional acceptance are complete.
  GL-014 remains open for performance/platform/native-adapter qualification and
  transport diagnostic disposition. Other issues remain independently tracked.
  See [validation](shared-domains-validation.md) for the complete evidence/limits.

## Commit checkpoint

- Committed the qualified implementation, fixtures and maintained documentation
  as `521265c338fc890a0e30b9e8a556f6346baf7d00` on `runtime/shared-domains`.
- The following documentation-only checkpoint records that immutable source
  identity. Publication targets `origin` (`gmoddev/GodotLuau`) on this branch;
  inherited release automation triggers on main and is not dispatched here.
