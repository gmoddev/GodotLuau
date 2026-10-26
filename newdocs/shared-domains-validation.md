# Shared-domain implementation and qualification

Date: 2026-10-26. Starting revision:
`8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
Branch: `runtime/shared-domains` in the public `gmoddev/GodotLuau` fork.
Tested implementation commit:
[`521265c338fc890a0e30b9e8a556f6346baf7d00`](https://github.com/gmoddev/GodotLuau/commit/521265c338fc890a0e30b9e8a556f6346baf7d00).
The follow-up qualification commit only records this immutable identity; runtime
and fixture sources are unchanged from the exercised implementation.
The decision precedes implementation in [ADR-001](adr-001-shared-execution-domains.md).
[The work log](shared-domains-work-log.md) records investigation, failed checks
and fixes as they occurred. This report distinguishes implemented behavior from
production qualification; GL-014 remains open for the latter.

The sections through "Limits and remaining work" below are the preserved initial
report. The [continuation qualification](#continuation-qualification-2026-10-26)
records subsequent fixes, measurements and the current readiness decision.

## Build environment and reproduction

Pinned dependencies were initialized without modification: godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`, Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Native work ran over SSH on
`dockerbox`/`HOSTPC`, workspace `C:\Sandbox\Codex\Workspaces\GodotLuau`, with
MSVC 19.51.36260, CMake 3.31.10, Ninja, existing controlled Python 3.12.6 and
`--parallel 4`. Existing dependency/object caches were retained. No toolchain was
installed, no worker machine settings changed, and no sustained native build ran
on the controlling PC.

Exact configure/build/test and local fixture commands are in
[tests/runtime/README.md](../tests/runtime/README.md). On this worker CMake/CTest
resolve to `C:\Sandbox\Codex\Tools\cmake-3.31.10\cmake-3.31.10-windows-x86_64\bin`;
the developer environment is initialized with
`C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat`.
Debug and ASan use separate build directories under
`C:\Sandbox\Codex\Builds\GodotLuau`. Final build logs are under
`C:\Sandbox\Codex\Logs\GodotLuau\shared-domains-final-qualification.log`.

Native fixtures use the existing Godot `4.7.1.stable.official.a13da4feb` executable
and the pinned Godot 4.3 binding API. Test processes are headless, hidden, bounded
to 30 seconds, and capture stdout/stderr with crash UI suppression. The isolated
project excludes the updater; inherited release automation was not dispatched.
These checks do not establish compatibility with every Godot 4.x version.

## Final executed results

| Check | Observed result |
| --- | --- |
| MSVC Debug adapter/core incremental build, parallel 4 | Exit 0; actual production extension linked |
| Debug CTest `ExecutionDomains`, timeout 30 | 1/1 target, 35 cases passed, 0 failed; 0.22 seconds |
| MSVC ASan core build and CTest, timeout 30 | Exit 0; 1/1 target, 35 cases passed, 0 failed; 0.71 seconds |
| `RunIntegration.ps1`, timeout 30 | Exit 0; PASS; required five-second child-wait warning/stack followed by successful continuation |
| `RunNetworkIntegration.ps1 -Mode Listen` | Exit 0; listen PASS; both domains remain separate |
| `RunNetworkIntegration.ps1 -Mode Dedicated` | Exit 0; server plus both clients PASS |
| `RunNetworkIntegration.ps1 -Mode Editor` | Exit 0; server plus both clients PASS using inherited editor flags |
| Build input synchronization | SHA256 matched all 22 changed/new production files plus test CMake/CPP between local checkout and worker |
| Documentation/diff checks | 11 policy/documentation files checked for local Markdown link targets; `git diff --check` passed |

Final locally exercised DLL SHA256:
`25C1EC0898FAEEC453F63043D5B99D8702C75CF62B0416A14A35A35934081358`.
The DLL remains an ignored qualification artifact at
`.runtime-tests/artifacts/godot_luau.dll`, not a distributed release.
Local evidence: `.runtime-tests/artifacts/core-debug.log`, `core-asan.log`,
`shared-domains-final-qualification.log`; isolated project/logs at
`.runtime-tests/final-integration`. Network logs were preserved separately in
`.runtime-tests/artifacts/network-Listen`, `network-Dedicated`, `network-Editor`
before the next mode could overwrite process labels. Final modes passed with
expected ServerStorage denials; earlier passing runs' ENet diagnostics remain
recorded under limits rather than being reclassified as fixed.

## Source boundaries

| Boundary | Changed production files |
| --- | --- |
| VM, environments, modules, scheduler, references | `src/core/gl_execution_domain.h`, `src/core/gl_execution_domain.cpp` (new) |
| Scene host, roles, native condition queues/cleanup | `src/core/gl_domain_host.h`, `src/core/gl_domain_host.cpp` (new) |
| Script bootstrap, wrappers, error/response bridges | `src/core/luau_script.h`, `luau_api.h`, `gl_runtime.h`, `gl_errors.h`, `gl_net_bridge.h`, `register_types.cpp` |
| Shared Lua services and subscriber ownership | `src/core/luau_stdlib.h` |
| Native services, network callbacks and invoke cancellation | `src/services/roblox_services.h`, `roblox_network.h` |
| Remotes and gameplay callback dispatch | `src/gameplay/roblox_remote.h`, `roblox_animation.h`, `roblox_input.h`, `roblox_interactive.h`, `roblox_tween.h` |
| Character/physics callbacks | `src/characters/humanoid.h`, `roblox_part.h` |
| UI callbacks | `src/ui/roblox_gui.h`, `roblox_billboard.h` |

`tests/runtime` contains production-core C++ tests, an optional native adapter
build, GDScript fixtures, bounded PowerShell runners and reproduction instructions.
No persistence/wire-format redesign, dependency upgrade, updater rewrite or
generated distribution artifact is included.

## Implemented acceptance coverage

| Area | Executable evidence |
| --- | --- |
| Domain/cache identity | Server A/B and Client A/B share results with explicit A-before-B ordering; Server/Client results and VMs are independent |
| Module loading | Concurrent and yielding initialization once; false/scalars/functions/tables; direct/indirect/concurrent dependency cycles; invalid return counts; sticky errors; unrelated scripts survive |
| Invalidation | Native module rename preserves identity; source reload affects both caches; destroy/replace produces fresh values; pending invalidation wakes errors; first-caller destruction does not cancel the initializer |
| Environments | Own script/module globals and script identity across yields; deliberate domain `_G`/shared; explicit getfenv/setfenv behavior; mutable compatibility context flags do not change native role |
| Scheduler | Spawn/defer/delay/wait arguments; external callbacks that yield; bounded 256-module/200-spawn chains; manually resumed coroutines adopting waits; cancellation and completed-thread guards |
| Ownership/lifecycle | Disable/reload/re-enable, pending child/signal/invoke waits, callback self-destruction, owner-bound Lua services, non-aliasing references, detached native wait source, fresh scene domains |
| Repetition/shutdown | 100 owner create/cancel/GC cycles, 20 domain initialize/shutdown cycles, finite close-hook snapshot with admission closed, repeated native script teardown |
| Roles/processes | Single-player both domains; listen-host separate domain caches; dedicated Server and two remote Client processes; editor-style server view plus two clients; template exclusion and RunContext |
| Native API regression | Yielding RunService/BindableEvent/RemoteEvent callbacks, local synchronous RemoteFunction, yielding network RemoteFunction handlers, pending invoke cancellation, Instance Folder/IntValue replication, retained native service methods |

The core fixtures compile the production implementation. They use a fake module
resolver and numeric script identity; the Godot fixtures exercise real native
objects, resource changes, services, ObjectIDs and ENet. Tests only prove the
specific paths/assertions run, not universal correctness of all service APIs.

## Migration compatibility

- Executables no longer allocate separate VMs. Services/builtins initialize once
  per applicable domain; they are shared mutable Lua objects within that domain.
- Ordinary global writes stay in each script/module environment. `_G` and shared
  intentionally share across scripts in one domain; Server/Client stay separate.
  getfenv/setfenv remain available; no hostile-script sandbox is claimed.
- Module results initialize once per ObjectID/source revision/domain; failures are
  sticky until invalidated. Exactly one non-nil return is required. Old returned
  values survive invalidation but module-owned pending work is cancelled.
- Destroying an executable no longer closes a VM or clears unrelated modules.
  Disable/reload cancels the old run; re-enable/reload creates a fresh environment.
- Callback references and waits are owner-bound; a publisher does not lend its
  identity/lifetime to another script's callback. Trusted shared-service polling
  survives first-subscriber destruction. Coroutine resume/wrap reject dead owners.
- Immediate native dispatch is capped at eight nested resumes; deeper spawn or
  require chains continue on later ticks. Defer runs on a subsequent scheduler
  tick. Managed numeric/empty yields are timed/next-tick; ordinary yields in
  manually driven coroutines stay manual until they enter a managed wait.
- BindToClose runs on domain/game shutdown, not on individual script destruction.
  Admission is closed; hooks cannot schedule work or initialize uncached modules,
  and yielding hooks are cancelled. There is no instruction quota for a hook
  that never yields. Local synchronous RemoteFunction fallback remains
  non-yielding; yielding network handlers are supported and tested.
- Domain capabilities derive from native ownership, not mutable role globals.
  Native scene objects/transport remain shared in a listen process as before;
  no new filesystem confinement, network protocol or persistence model was added.

## Limits and remaining work

The initial baseline was source-traced, not runtime-benchmarked or crash-reproduced.
No representative old/new initialization, memory or scheduler measurements were
made, so reduced VM count is an architecture fact, not measured improvement.
Linux, SCons distribution/release builds, full graphical editor launch, actual
coordinator/world deployment and production scene content remain unqualified.
The editor fixture tests the launch flags headlessly, not editor window behavior.

ASan instruments the production core and pinned Luau, not the Godot executable,
godot-cpp or the native adapter. It found a deep-dispatch stack overflow at an
earlier bound of 64; the final bound is eight and the regression passes.
Earlier mixed-header/object synchronization also caused a native crash; content
hash synchronization and fresh timestamps for changed inputs corrected it before
the final build. Both failures and their fixes remain in the work log.

Passing multi-process tests sometimes emit ENet `Unable to send packet on channel
0, max channels: 0` during peer teardown. Baseline reproduction/attribution is
unresolved. Expected ServerStorage client-denial logs are separate negative-test
evidence. Functional PASS markers do not erase transport diagnostics.

GL-001/GL-002 have focused fixes and passing retained-method regressions, but
remain open for broader native lifetime qualification. GL-003/GL-004/GL-005 and
GL-006 through GL-009 remain independent: shared VM ownership does not provide
sandboxing, quotas, nonblocking HTTP, RPC input validation or durable storage.
GL-016 remains open; inherited updater/binaries are not qualified fork releases.
No distribution archive, generated assets, dependency pins or updater policy
were changed.

## Continuation qualification (2026-10-26)

Starting revision: `0498efca0c3da15b16fff6fb30aac9658975c50a`, clean
`runtime/shared-domains`. This continuation performs targeted corrections and
qualification, with unchanged godot-cpp/Luau pins. No architecture decision changed;
ADR-001 remains the accepted design, including its historical unmeasured baseline.
Final runtime/build/fixture revision:
[`5f61bea0e273e7473260f351fa4fb321116090ee`](https://github.com/gmoddev/GodotLuau/commit/5f61bea0e273e7473260f351fa4fb321116090ee).
The following evidence commit updates documentation/data only. No main merge,
release, updater enablement or upstream
communication is part of this qualification.

### ENet findings and corrections

The zero-channel diagnostic is a real transport lifecycle defect in the exercised
Godot engine, with an additional application callback timing hazard. It is not
established as harmless logging or as a shared-VM defect.

1. During one ENet poll, multiple peers can already be reset before their queued
   disconnect signals are delivered. ENetMultiplayerPeer emits disconnection
   before erasing that peer from its map.
2. SceneMultiplayer's `_del_peer` sends a reliable six-byte peer-removal relay
   notification to other entries in its connected-peer set. Another reset peer
   can still be present. ENetPacketPeer rejects channel zero when channelCount is
   already zero. An unused packet then remains allocated on this failed send.
3. A synchronous application disconnection callback can send into the same
   incomplete poll state. NetworkService now defers that callback until polling
   has drained, before its removal/ownership RPCs and Lua subscriber dispatch.
   This corrects application timing; it does not fix the engine's internal relay.

Source trace at the exact engine revision:
[ENet poll](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_multiplayer_peer.cpp),
[SceneMultiplayer relay](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/multiplayer/scene_multiplayer.cpp),
[packet send rejection](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_packet_peer.cpp).
The allocation ownership explanation follows this source chain and the reproduced
48+6-byte leak; the minimally built engine lacked full local symbol information.

`ENetDisconnectProbe.gd` creates a server and two clients, closes both before one
server poll, and never loads the GDExtension, Luau, Game or NetworkService.
Five repetitions of each row passed their expected assertions on both official
Windows and Linux Godot 4.7.1 (`a13da4feb`), 25 cases per platform:

| Engine relay | Application callback send | Zero-channel diagnostic |
| --- | --- | --- |
| On | None | Reproduced |
| Off | None | Absent |
| Off | Synchronous reliable broadcast | Reproduced |
| Off | Deferred reliable broadcast | Absent |
| On | Deferred reliable broadcast | Engine diagnostic remains |

The fully instrumented engine-only relay-on probe reports a **54-byte LSan leak**
(48-byte allocation plus six-byte payload) and exits nonzero, matching the
uncoordinated native fixture. This failed adversarial gate is preserved. No log
filter, leak suppression, relay disablement or vendor patch was introduced.
This is tracked as GL-017 with a bounded engine follow-up.

A separate new regression proved an extension defect: destroying active
NetworkService while a surviving script awaited RemoteFunction left the caller
stranded. EXIT_TREE now invokes the existing disconnect/fail-pending path before
clearing service identity. The caller resumes with the existing peer-left error;
transport role resets and retained methods cannot act on a replacement service.
The fixture failed before this correction and passes after it. Script cancellation,
yielding response callbacks, peer cleanup, scene replacement and process exit are
also exercised. These checks do not establish all unreliable-RPC delivery edges.

### Additional targeted corrections

- A diagnostic 1,000-script pilot found about 6,046 ms in 32,000 pure deferred
  task cancellations: every cancellation traversed the scene and scanned all
  native wait guards. Tasks now record whether a native wait was registered;
  only such tasks run native detachment/guard cleanup. Real native wait cleanup
  still executes exactly once; focused coverage checks guards are released.
  This was a measured amplification fix, not a scheduler redesign.
- Full Linux ASan exposed a false native stack-overflow error when the legacy
  guard compared an address-taken local, relocated onto ASan's fake stack, with
  an unrelated stack high-water address. The guard now uses real native frame/
  return-slot addresses and Linux pthread stack bounds, with thread-local caches
  and integer address comparisons. Windows retains OS stack limits. The new
  shallow-stack/reserved-margin regression passes under ASan; fake-stack checks
  remain enabled. Other platforms retain the existing estimated-budget fallback.
- Actual SCons/MSVC builds exposed oversized UTF-8 raw literals (C2026), then
  the binding translation unit's COFF section limit (C1128). Adjacent smaller
  literals preserve the exact concatenated Lua bytes; `/bigobj` matches CMake's
  existing adapter flag. No dependency or generated binding was changed.

### Expanded sanitizer evidence

| Combination | Executed result and boundary |
| --- | --- |
| Windows MSVC 19.51 Debug/Release/core ASan | 36 cases, 20 consecutive suite runs in each configuration, all pass |
| Windows stock Godot + full MSVC ASan extension | Functional marker reached but shutdown timed out; **not qualified** |
| Windows registration-only ASan baseline/candidate | Both reached marker and timed out at exit without creating any domain, script, Game or peer |
| Linux GCC 13.3 Debug/Release/core ASan | 36 cases, 20 consecutive suite runs in each configuration, all pass |
| Linux stock Godot + instrumented adapter | ASan rejects stock loader RTLD_DEEPBIND; unsupported combination, not a clean run |
| Matching source-built Linux ASan/LSan Godot + instrumented godot-cpp/adapter/Luau | Ten ordered-close repetitions: **80 process results pass**, leak detection enabled |
| Matching full Linux ASan engine, simultaneous-close engine-only probe | Functional PASS then 54-byte leak/nonzero exit; preserved failure |

Linux core and full adapter use `-fsanitize=address -fno-omit-frame-pointer`,
Debug configuration, matching executable/shared linker sanitizer flags. All
pinned Luau and godot-cpp targets are instrumented. Engine source is exact
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, built with GCC using
`use_asan=yes use_lsan=yes use_static_cpp=no linker=lld dev_build=yes
debug_symbols=no optimize=none disable_path_overrides=no` and the minimal
GDScript/multiplayer/ENet modules. See the complete reproducible command in
`tests/runtime/BuildSanitizedGodot.sh`. Its custom-build version lacks a Git hash
because the source was an archive; the pinned download identifies the source.

`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=...` remains enabled.
Ordered-close stress explicitly waits for the server's completed disconnect poll
before the second client closes. It isolates native lifecycle acceptance from
GL-017; it does not replace the failed simultaneous-close gate or alter production
relay behavior. Minimal engine dummy-physics warnings are retained; renderer,
full physics and graphical editor behavior are outside this headless build.

Windows instruments the core, bindings, extension and Luau with
`/fsanitize=address`, `/Zi /Od`, `/INCREMENTAL:NO`; runtime DLLs must be beside the
extension for this loader. A registration-only inherited baseline reproduces
the shutdown timeout. This bounds attribution but does not prove every Windows
native lifetime path safe. GL-018's smallest next step is a matching instrumented
Windows Godot host. No UBSan, TSan or production-scene sanitizer claim is made.

### Build, runtime and stress matrix

Windows worker: existing MSVC 19.51.36260, CMake 3.31.10/Ninja, controlled Python
3.12.6. The owner approved portable SCons 4.5.2 at
`C:\Sandbox\Codex\Tools\GodotLuauSCons`; wheel SHA256:
`2f66a1c5c485068a496c12356583eefb2d79e17177278c7334b12b460f0503ce`.
No global installation or machine setting changed. Native builds use four jobs
and persistent project caches under `C:\Sandbox\Codex`.

Linux worker: actual Ubuntu 24.04 on `linuxbox`, Ryzen 9 7950X3D (32 logical
CPUs), with task container limited to four CPUs/10 GiB. GCC 13.3.0,
CMake 3.28.3, SCons 4.5.2, Python 3.12 and lld run inside Docker. The checked-in
Dockerfile pins the Ubuntu base digest and names tool packages, not every apt
package version. It reproduces the setup, not a bit-for-bit hermetic image.
No host-native packages or unrelated Outline/PostgreSQL/Redis workloads changed.
The task container was stopped after qualification; its filesystem/image and bind
tree retain source/build caches and logs. Existing unrelated containers remained
healthy. No persistent Windows build process or task service remains.

Both official runtime hosts are `4.7.1.stable.official.a13da4feb`, using the pinned
Godot 4.3 binding API. Tests are actual native executions, not cross-compilation.
Both build paths compile the production domain and host sources through their
core-source glob. Linux static Luau uses PIC when linked into the adapter.
All 65 native input files (src `.h`/`.cpp` plus SConstruct) match across local,
Windows worker and Linux worker after compiler-equivalent LF normalization:
SHA256 `6b9b752044b36b161a34868ad7d5b94258fdf831d0effb0d489403ce9735103c`.
`tests/runtime/SourceFingerprint.py` reproduces that comparison; dependency
identities are recorded separately by their unchanged pins.

| Gate | Result |
| --- | --- |
| Windows CMake Debug/Release | Core/actual adapter build pass; 24 Debug and eight Release native process results pass on corrected runtime |
| Windows core ASan | Build plus 20 suite repetitions pass; full native host limitation above |
| Windows SCons template_debug/template_release | Both production builds pass; eight native process results per configuration pass |
| Linux CMake Debug/Release/ASan | Core and full adapter builds pass; 20 suite repetitions each pass |
| Linux CMake Debug/Release native | Eight process results per configuration pass |
| Linux SCons template_debug/template_release | Both production builds pass; eight native process results per configuration pass |
| Linux fully instrumented native stress | 80 ordered-close process results pass; separate engine leak remains |
| Engine-only disconnect matrix | 25 cases per platform reproduce the exact expected diagnostic pattern |

Release extension libraries were exercised under the official headless Godot
executable, not a separately exported production game. This establishes those
extension build configurations, not every export/renderer/platform combination.

### Local qualification package and retained evidence

`PackageQualification.py` created
`.runtime-tests/qualification/GodotLuau-shared-domains-5f61bea-test.zip` from
the committed runtime revision above, the unchanged dependencies, and explicitly
supplied current SCons Windows/Linux debug/release binaries. It includes 129
runtime/descriptor/license files, 13,992,761 compressed bytes, and a manifest
containing every file's size/SHA256 and native source fingerprint. Every descriptor
resource is included; ZIP CRCs and all manifest hashes pass. Extracted-package
registration smoke tests load the **shipped descriptor and its actual library
paths** on Windows and Linux, exit zero and emit no diagnostics. These are
additional load checks; the identical binary hashes already have full fixture
coverage above. The archive excludes inherited binary inputs and the updater.

ZIP SHA256:
`31dc9ef586ad78bc03b12a8cf4f191f9afcc7790dad8876729fa8fa52089401e`.
Full library hashes/sizes, raw result-file digests, gate counts and failed gate
dispositions are retained in the
[qualification manifest](evidence/shared-domains-qualification-2026-10-26.json).
The [evidence index](evidence/README.md) records remote/local raw log locations.

Reproduce the archive from runtime revision `5f61bea0e273e7473260f351fa4fb321116090ee`
with the four explicit `--windows-debug`, `--windows-release`, `--linux-debug`,
`--linux-release` inputs as shown in the runtime README. ZIP file timestamps may
differ on regeneration; the source, pins and individual file hashes are the
identity checks, not a promise of byte-for-byte archive reproducibility.

This ignored local archive is a test artifact, not a GitHub Release or production
distribution. Asset-specific provenance remains GL-015; release automation,
retention and updater policies remain GL-010/GL-011/GL-012/GL-016. No production
publication is implied by successful local packaging.

The native fixtures cover single-player, listen host, dedicated server and two
clients, headless editor launch flags, per-domain module identity, environment
isolation, module invalidation, script disable/reload/destroy, pending waits,
retained native methods, network service destruction/replacement, callback owner
destruction, replicated Instance values, scene replacement and shutdown. Core
tests additionally cover concurrent/yielding/cyclic require, sticky failures,
reentrancy, domain separation, 100 owner cycles and 20 domain shutdown cycles.
The extra case tests the actual OS stack guard, rather than increasing counts
without a new acceptance fact. GL-001/GL-002 now have their own native sanitizer
and replacement/retained-call evidence; this does not qualify all bindings.

### Controlled performance measurements

Raw evidence: [90 phase records](evidence/shared-domains-benchmark-2026-10-26.json).
Reproduce with [runtime instructions](../tests/runtime/README.md) and
`SummarizeBenchmark.py`. Baseline `8b163269cbe44cf7fcf7a9a0285620878a2345fd`
has the inherited per-executable VM implementation. Baseline and candidate Release
adapters link the same pinned vendor builds in the same CMake tree with identical
GCC settings, same official Linux Godot, hardware and four-CPU container. No other
compiler/Godot workload was running when the final benchmark started.
An incremental Release rebuild after final raw-literal segmentation produced the
**identical candidate binary SHA256** as the benchmarked binary:
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.
Thus the MSVC packaging correction did not change the measured Linux runtime.

Three trials per script count, alternating baseline/shared order (odd trials
reverse it). Every script performs one initial require, 100 cached requires,
32 deferred task create/cancel pairs and 20 task.wait frames. Assertions verify
module result 5050 and cache identity. Baseline initializes the module N times;
shared initializes it once. The external runner samples process RSS at phase
handshakes. `os.clock` and engine ticks measure monotonic **elapsed** time, not
CPU time. Values below are medians across the three trials, baseline → shared.

| Scripts | Startup ms | RSS growth MiB | Initial requires ms, summed | 100 cache hits/script ms, summed | 32 create/cancel pairs/script ms, summed |
| --- | --- | --- | --- | --- | --- |
| 10 | 31.732 → 6.865 | 12.836 → 3.023 | 0.242 → 0.176 | 1.356 → 2.021 | 0.086 → 0.104 |
| 100 | 304.969 → 31.928 | 107.664 → 7.035 | 2.168 → 0.506 | 13.082 → 20.294 | 0.794 → 1.640 |
| 1,000 | 2,988.325 → 284.925 | 1,056.836 → 57.188 | 21.429 → 3.286 | 129.327 → 194.723 | 7.803 → 19.973 |

| Scripts | Script destruction ms | Game/domain shutdown ms | Frame interval median ms | Frame interval p95 ms |
| --- | --- | --- | --- | --- |
| 10 | 13.687 → 13.700 | 13.684 → 13.741 | 6.895 → 6.900 | 7.196 → 7.168 |
| 100 | 13.796 → 13.557 | 13.549 → 13.466 | 6.902 → 6.904 | 7.169 → 7.218 |
| 1,000 | 145.723 → 139.818 | 13.762 → 13.873 | 6.904 → 6.892 | 7.165 → 7.165 |

At 1,000 scripts, baseline startup spans 2,984.250–3,001.476 ms; shared spans
284.011–285.902 ms. RSS growth spans 1,056.813–1,056.891 versus
57.160–57.188 MiB. Cached requires span 128.699–129.910 versus
194.083–195.296 ms. Coroutine pairs span 7.762–7.813 versus
19.737–21.183 ms. The summarizer emits all min/median/max values.

These measurements support much lower startup time and RSS growth **for this
workload**, with real cached-require and task-bookkeeping regressions. At 1,000
scripts, each cached require averages about 1.29 → 1.95 microseconds; a create/
cancel pair about 0.244 → 0.624 microseconds. No universal scalability claim is
made from three trials on one machine.

Investigation: the new require resolver resolves/type-checks the native module,
copies its source and constructs its full chunk path before the shared cache
lookup; the baseline checks its registry cache before source retrieval. The
shared task path additionally owns rooted thread records, owner checks and a
hash-map/shared_ptr allocation, with reaping at a safe scheduler boundary. These
are source-established additional operations; their individual cost fractions
were not isolated. The measured catastrophic native-cleanup amplification was
corrected before final trials. Further cache/task optimization is GL-019 and
requires profiling, preserving source invalidation and lifetime guarantees.

Limits: startup includes VM allocation/bootstrap, script compilation, native node
creation and benchmark work; isolated luaL_newstate timing was not measured.
RSS is whole-process growth from Before to Startup, not Luau-only allocation.
Destruction/shutdown include two frame boundaries and allocator retention is not
automatically a leak. Frame intervals remain dominated by ~6.9 ms headless pacing
even at max_fps zero. TIME_PROCESS updates were stale/zero (one baseline sample
repeated startup time); those raw fields are retained but **excluded from all
conclusions**. Isolated scheduler CPU cost and graphical frame-rate impact remain
unmeasured. Reload semantics changed intentionally, so no equivalent old/new
reload-cost claim is made. Sanitizer results, not retained RSS, assess tested leaks.

### Readiness decision

**CONDITIONALLY READY for source integration.** Shared-domain acceptance behavior,
Windows/Linux Debug/Release CMake/SCons runtime coverage and expanded Linux native
sanitizer lifecycle coverage are established. The targeted pending-invoke,
stack-guard and cancellation defects have fixes and focused regressions.
GL-014's implementation/source-qualification scope is satisfied, with bounded
remaining work explicitly tracked as GL-017/GL-018/GL-019.

The independently reproduced Godot relay leak, unqualified Windows full-native
sanitizer host and unresolved finer scheduler/graphical performance measurements
limit production claims. They do not demonstrate an unresolved shared-domain
correctness regression requiring a redesign. A source merge recommendation is
separate from production binary publication. GL-003–GL-013 and GL-015/GL-016 retain
their own scope: public-network authority/input checks, persistence, script
capabilities/quotas, updater, automated release gates and asset provenance remain
unqualified. No full graphical editor, coordinator/world deployment or production
scene qualification occurred. Do not publish production binaries on this report.

## Main integration (2026-10-26)

**INTEGRATED WITH QUALIFICATION LIMITATIONS.** Main is the canonical shared-domain
development baseline. This section records source integration; the preceding
qualification reports, ADR and measured/failed outcomes remain historical evidence.

### Revision and merge record

| Identity | Revision |
| --- | --- |
| Starting local and remote main | `8b163269cbe44cf7fcf7a9a0285620878a2345fd` |
| Qualified source branch | `runtime/shared-domains` at `9423fed4051bec2fba798d9a49eaec7dea6cca3b` |
| Integrated main merge | `dd68cda850fb548aa7713242275ff73c183e813c` |
| Complete merge/source tree | `7b2185eef6afef8951afa7ad21d895244d654b0e` |

Neither branch advanced before integration. Main was the source branch's merge
base. `git merge --no-ff 9423fed4051bec2fba798d9a49eaec7dea6cca3b` used the
normal ort strategy with **no conflicts**, preserving `521265c`, `0498efc`,
`5f61bea` and `9423fed`. Fifty-five files changed relative to starting main;
`git diff --name-status 8b163269 9423fed` reproduces the exact file list.
No main functionality or source-branch commits were discarded. The source branch
is retained unchanged. An unrelated remote branch was not merged or modified.

Preflight found a clean working tree, one local worktree, no unmerged paths and
no active CodexLock claims. Origin is the public `gmoddev/GodotLuau` fork and its
default branch remains main. No upstream repository was modified.

The complete tree at the merge equals the qualified source tree, established by
matching Git tree IDs and an empty `git diff 9423fed dd68cda`. The follow-up
integration evidence commit changes documentation only. Runtime, test code, build
configuration and pinned dependencies remain identical to qualified source.
The 65-file native fingerprint remains
`6b9b752044b36b161a34868ad7d5b94258fdf831d0effb0d489403ce9735103c` on the
integrated checkout and both workers. Windows core build inputs additionally
match normalized digest
`916e2375f4d1e8d68bf18cbd950310bdaf210ab83ceac5390e27ebcb2c1e1cb6`;
Linux build/native-fixture inputs match
`234320629dc8a7505d58bf33b9a68c622f77a5afa58587b484ec65cd11f5dc6c`.
Windows native fixtures run from the integrated local checkout; those fixture
files are not required in the Windows build-only mirror.

### Fresh integrated checks

Existing MSVC/GCC CMake/Ninja caches and the previously configured Linux task
container were reused with four build jobs. No dependencies or toolchains were
installed, no worker settings changed, and no expensive stress matrix reran.

| Fresh gate | Actual result |
| --- | --- |
| Windows Debug core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Windows Release core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Windows ASan core build/test | Exit 0; 36-case core suite passes once |
| Linux Debug core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Linux Release core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Linux ASan core build/test | Exit 0; 36-case core suite passes once |
| Windows Debug native fixtures | Eight process results, all exit zero/PASS; known GL-017 diagnostic in dedicated server stderr |
| Windows Release native fixtures | Eight process results, all exit zero/PASS |
| Linux Debug native fixtures | Eight process results, all exit zero/PASS |
| Linux Release native fixtures | Eight process results, all exit zero/PASS |

Each native group runs single-player Integration, Listen, Dedicated with two
clients, and headless Editor launch flags with two clients. `--teardown` requires
RemoteFunction cancellation when NetworkService is destroyed. Existing assertions
also cover shared module identity, Server/Client separation, script environments,
script/coroutine ownership, owner cancellation, disable/reload/destroy, native
Instance liveness, retained methods, service replacement and scene shutdown.
The production core suite covers concurrent/yielding require, module errors/
invalidation, reentrancy and lifecycle bounds. Source inspection still finds the
single extension `luaL_newstate` call in GLExecutionDomain, with no executable-
script VM allocation. No new runtime behavior or optimization was introduced.

The Windows Debug dedicated-server stderr contained one `max channels: 0`
diagnostic. Functional exits/assertions passed; this is **not** a clean transport
claim. GL-017 remains independently reproduced and unresolved. No diagnostics
were suppressed and no sanitizer settings/checks were weakened.

Exact incremental commands, in the existing MSVC developer environment on
`dockerbox` (the full CMake/CTest paths are in the build-environment section):

```powershell
foreach ($Config in @('debug', 'release')) {
    $Build = "C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-$Config"
    cmake --build $Build --target ExecutionDomainTests GodotLuauAdapter --parallel 4
    ctest --test-dir $Build --output-on-failure --timeout 30
}
$Build = 'C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-asan'
cmake --build $Build --target ExecutionDomainTests --parallel 4
ctest --test-dir $Build --output-on-failure --timeout 30
```

Inside the existing `codex-godotluau-qualification` Linux container:

```sh
for Config in debug release; do
    cmake --build /work/builds/linux-$Config \
        --target ExecutionDomainTests GodotLuauAdapter --parallel 4
    ctest --test-dir /work/builds/linux-$Config --output-on-failure --timeout 30
done
cmake --build /work/builds/linux-asan --target ExecutionDomainTests --parallel 4
ctest --test-dir /work/builds/linux-asan --output-on-failure --timeout 30
for Config in debug release; do
    python3 /work/source/tests/runtime/RunQualification.py \
        --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
        --extension /work/builds/linux-$Config/godot_luau.so \
        --output /work/artifacts/integration-main-dd68cda-$Config \
        --teardown --timeout 45
done
```

Windows adapters were copied from the two worker build directories, then tested
headlessly from the integrated checkout:

```powershell
foreach ($Config in @('debug', 'release')) {
    C:/Python312/python.exe tests/runtime/RunQualification.py `
        --godot C:/Users/aiden/Downloads/Godot/Godot_v4.7.1-stable_win64.exe `
        --extension ".runtime-tests/qualification/main-dd68cda-windows-$Config.dll" `
        --output ".runtime-tests/qualification/main-dd68cda-windows-$Config" `
        --teardown --timeout 45
}
```

Fresh logs: Windows worker
`C:\Sandbox\Codex\Logs\GodotLuau\integration-main-dd68cda-builds.log`;
local `.runtime-tests/qualification/main-dd68cda-windows-{debug,release}`;
Linux `/opt/codex/godotluau/logs/integration-main-dd68cda-{debug,release,asan}.log`
and `/opt/codex/godotluau/artifacts/integration-main-dd68cda-{debug,release}`.
Fresh native binary/result-file hashes are recorded in the
[integration evidence](evidence/shared-domains-integration-2026-10-26.json).

### Reused evidence, publication control and next baseline

The source/tree identities justify reusing the prior Windows/Linux SCons
Debug/Release builds and native fixtures, 20-repeat core suites, 80-process full
Linux native ASan/LSan ordered-close stress, engine-only failure attribution,
controlled benchmark and explicit-input local-package evidence. Those tests were
not rerun or relabelled as new main executions. The recorded SCons libraries and
test archive remain artifacts of runtime revision `5f61bea`; they are applicable
to main's unchanged runtime content, not newly published main binaries. The fresh
Linux Release adapter still has the exact benchmarked SHA256
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.

The inherited release workflow is active and its path filter matches this merge.
The merge and integration-documentation commit messages include `[skip ci]`,
using GitHub's documented
[push-workflow skip directive](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).
Main had no branch protection or applicable branch rules; no protection was
bypassed. Workflow state/configuration and updater behavior are unchanged.
No workflow dispatch, GitHub Release, production binary publication or upstream
communication is authorized by this integration. The prior qualification's
no-merge restriction applied to that completed task; this task explicitly
authorizes integrating and pushing main.

GL-014 is integrated and remains source-qualified/closed within its established
scope. GL-017 (engine teardown/leak), GL-018 (Windows full-native sanitizer host)
and GL-019 (cached require/task overhead) remain open, alongside networking
authority/input validation, persistence, script capabilities/quotas, updater and
release provenance limitations. Integration resolves none of those issues.

The smallest coherent next task is **GL-019 profiling of cached ModuleScript
require**, starting with native source retrieval/path construction before the
cache lookup in `GLDomainHost::GetDomain`/`GLExecutionDomain::BeginRequire`.
Measure attributable costs before optimizing; preserve module revision
invalidation and owner lifetime guarantees. Coroutine bookkeeping remains part
of GL-019 but does not need to be bundled into the first profiling change.
No GL-019 implementation was performed here.

## GL-019 optimization (2026-10-26)

**OPTIMIZED AND QUALIFIED** on `perf/gl-019-hot-paths`; not merged into main.
Starting main: `aa5400321b8f838a75de8d2b4005b0c5165dab34`, verified clean and
unchanged on origin. Measurement harness:
`0427a3560ac01b191aa7dcc8b2c144f8eccda2dd` (production code unchanged from main).
Runtime optimization: `1756cc2600e5a59ea948e69a684f5abd93e32229`.
The following evidence commit changes documentation/data only. ADR-001 and the
Server/Client ownership model are unchanged; previous results above are preserved.

### Comparable baseline and attribution

Reused the existing linuxbox Ubuntu 24.04 container, four-CPU/10-GiB limits,
GCC 13.3/CMake Release `-O3 -DNDEBUG`, pinned vendors and official Godot 4.7.1.
No tools/packages/settings changed. Builds were finished before timed/profiled
runs. Source/native input identity is recorded in the
[qualification manifest](evidence/gl019-qualification-2026-10-26.json).

Fresh original/shared baseline: five counterbalanced trials at 10/100/1,000
scripts using the **unchanged population benchmark**. At 1,000, original
per-script startup is 2,979.038 ms, RSS growth 1,056.820 MiB, cached requires
129.808 ms and create/cancel pairs 7.876 ms. Pre-GL-019 shared results are
287.317 ms, 57.191 MiB, 195.620 ms and 20.140 ms, respectively. This reproduces
the historical regression closely enough for direct pre/post comparison.

Pre-GL-019 library SHA256:
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.
Final optimized Release library SHA256:
`d9398aed311dab4e4493b022fc0df8e4ed81e569e778d562aeb3695248544883`.
All 65 native input files match local/Windows/Linux, LF-normalized digest
`40e2cbadfae3cef7fdc39e17d6b9feec94f635aa5e8926614bdcdb27c324045d`.
The dependency pins remain exactly those recorded in the initial report.

Added a captured-module workload using the existing bounded runner helpers.
It removes `game.ReplicatedStorage.Counter` property/hierarchy lookup from the
timed loop. Native perf sampled only the task container cgroup, not unrelated
host services: 16,463 pre and 3,094 post user-cycle samples, zero lost samples.
The extension is symbolized; the official Godot binary is stripped. Inclusive
pre-profile costs overlap and must not be summed:

| Native sampled path | Inclusive sampled cycles |
| --- | --- |
| GLExecutionDomain::BeginRequire | 67.63% |
| Native module resolver | 66.04% |
| String::utf8 (source/path conversions combined) | 30.98% |
| gl_instance_fullname | 26.62% |
| ModuleScript type cast | 3.17% |
| Lua registry result access | 0.63% |

The old path enters through the Luau require wrapper, resolves the ObjectID,
checks Node/ModuleScript type and tree/resource liveness, retrieves/converts the
entire source, constructs/converts the hierarchy chunk name, then looks up the
numeric cache key and returns through registry/stack operations. Sampling
establishes that pre-cache native work is a bottleneck. It does not separately
time every Godot internal lock, individual allocation or source/path conversion;
some of those functions are stripped/inlined.

An optional executable links the **production core and pinned Luau**, recording
monotonic elapsed time, process CPU (`std::clock`) and C++ new-call/requested-byte
counts. Creation takes two C++ allocations per task (record/control block plus
map node), with additional table growth when needed; cancellation takes none.
Snapshot growth takes eleven allocations
at 1,000 tasks. Luau/Godot malloc and peak/live bytes are not counted. The core
benchmark is single-threaded; native Godot's allocator/shared_ptr atomic behavior
can differ. It supports attribution, not an isolated native scheduler CPU claim.

### Accepted changes and preserved behavior

- `luau_script.h`: LuauScript stores a source revision, incremented on actual
  source changes **before** changed-signal callbacks. Resource replacement is
  distinguished by its Godot ObjectID even when revisions are equal.
- `gl_domain_host.cpp`: the resolver performs live/type/tree/resource checks and
  returns module/resource IDs plus revision. A separate miss loader retrieves
  source and chunk path. No native pointer/resource is retained in a new cache.
- `gl_execution_domain.h/.cpp`: compare metadata before source loading; ready
  hits return the same registry value immediately. Resolvers without metadata
  retain the original content comparison. Loading entries still join once;
  cycle detection, sticky failure, invalidation, cancellation and shutdown
  admission behavior remain. Old returned values survive source invalidation.
- `gl_execution_domain.cpp`: reserve current snapshot/close-owner vector sizes;
  avoid a temporary shared_ptr copy when merely inspecting a live task. Strong
  snapshot roots and cancelled-task locals remain across resume/reset/unref.
  The registered-native-wait cleanup bit remains unchanged.

No public ModuleScript/task API, `_G`/shared behavior, environment, VM ownership,
authority/capability, network/persistence path, updater or dependency changed.
Native resource revision is internal metadata, not a new gameplay property.

### Final before/after measurements

Seven counterbalanced trials per count on the same idle worker/binaries. Values
are medians, **pre-GL-019 → post-GL-019**. All times below are elapsed milliseconds;
RSS is whole-process Startup-minus-Before growth. Generic runner labels in this
file map `Baseline` to pre-GL-019 and `Shared` to post-GL-019.

| Scripts | Cached require sum (100/script), ms | Startup ms | 32 create/cancel pairs/script, ms | RSS growth MiB |
| --- | --- | --- | --- | --- |
| 10 | 2.030 → 0.847 | 6.829 → 6.830 | 0.106 → 0.110 | 3.063 → 3.086 |
| 100 | 20.152 → 8.362 | 31.713 → 19.897 | 1.641 → 1.639 | 7.063 → 7.016 |
| 1,000 | 198.230 → 82.433 | 290.204 → 171.446 | 20.321 → 20.107 | 57.203 → 56.230 |

At 1,000, cached sums span 195.386–209.731 → 80.347–85.378 ms; startup spans
286.049–306.892 → 169.099–177.816 ms; task pairs span
19.658–22.990 → 19.854–20.608 ms. RSS growth spans
57.191–57.250 → 56.105–56.262 MiB. The small-count RSS/time ranges overlap;
no material startup/memory regression is established. Original per-script VM
costs remain a separately recorded comparison, not the primary optimization base.

The final captured-module loop (one million calls, seven counterbalanced trials)
measures **1,054.330 → 163.508 ms**, ranges 1,018.822–1,065.148 →
159.992–173.674 ms. True first module initialization is **13.040 → 13.080 us**,
ranges 11.800–14.910 → 12.190–14.050 us: no meaningful cold-path change is
claimed. The earlier require-only trial and final binary give consistent gains.
Population initial-require sums include one miss plus other scripts' cache hits;
they are not separate VM-allocation timing.

Domain/game shutdown medians at 10/100/1,000 scripts are
13.743/13.767/13.683 → 13.716/13.765/13.598 ms. Script destruction with pending
waits is 13.473/13.693/138.787 → 13.724/13.682/135.747 ms. Both include two
frame boundaries. Frames remain near 6.9 ms; TIME_PROCESS remains excluded.
No graphical frame-rate or scheduler CPU conclusion follows from those intervals.

Core microbenchmarks use eleven counterbalanced trials at each count. CPU
medians below are **process CPU ms per 1,000 operations**, not wall time; full
wall/CPU trial values remain in the raw evidence for min/median/max calculation.

| Core phase | CPU ms, pre → post | C++ allocation calls, pre → post |
| --- | --- | --- |
| Spawn + completion | 0.653 → 0.668 | 2,006 → 2,006 |
| Defer creation | 0.406 → 0.415 | 2,000 → 2,000 |
| Cancellation | 0.037 → 0.037 | 0 → 0 |
| Cancelled reaping | 0.037 → 0.031 | 11 → 1 |
| Defer/wait creation | 0.351 → 0.353 | 2,000 → 2,000 |
| Resume + yield | 0.085 → 0.073 | 11 → 1 |
| Resume + completion/reaping | 0.105 → 0.086 | 11 → 1 |
| Delay creation | 0.553 → 0.571 | 2,000 → 2,000 |
| Idle pending-task tick | 0.026 → 0.020 | 11 → 1 |
| Owner cancellation/reaping | 0.051 → 0.048 | 11 → 1 |
| Manual coroutine resume/completion | 0.557 → 0.590 | 0 → 0 |
| Concurrent require start (includes compile/owner creation) | 3.818 → 3.908 | 36,054 → 36,054 |
| Concurrent require finish | 0.155 → 0.151 | 22 → 2 |
| Domain shutdown | 0.028 → 0.034 | 11 → 1 |

These small timings contain noise; unchanged creation/manual-resume paths are
not claimed faster. A 21-trial sensitivity run at 10,000 operations gives idle
tick CPU median 0.271 → 0.159 ms (ranges 0.157–0.315 → 0.135–0.226), owner
cancellation 0.647 → 0.550 ms, and shutdown 0.381 → 0.383 ms. Creation/complete
results have broad overlapping spreads. Retention is justified by deterministic
allocation reduction and measured tick improvement without a structural rewrite.
At 1,000 tasks a snapshot requests 16,000–16,016 bytes once instead of 32,752
bytes across eleven calls. Two-step concurrent completion requests 32,000 rather
than 65,504 bytes. These are requested C++ bytes, not RSS or peak live allocation.

Separate native perf stat captures execute the same fifteen million cached
calls/five processes: accumulated task-container CPU **16,570.54 → 3,150.85 ms**,
cycles **92.553 → 16.905 billion**, instructions **325.971 → 56.991 billion**.
Capture windows are 25/15 seconds; idle capture time consumes no task CPU.
Totals include runner/startup/shutdown and sampling overhead; they are not
isolated function CPU times. Latency trials above ran without perf attached.

### Rejected candidates and remaining costs

- Removing shared_ptr roots or live ObjectID/type checks was rejected: those
  protect reentrant callbacks, destruction and native lifetime. A ~3% sampled
  type-cast contribution does not justify weakening validation.
- A bounded record pool/map replacement was considered but not implemented.
  Cancelled burst records remain rooted until a safe scheduler boundary, so
  they cannot be recycled during the initial create/cancel burst. A pool also
  needs correct snapshot/reference eligibility and extra retained storage.
  No prototype speedup is claimed. Complexity is not justified by the measured
  residual cost while simpler allocation reductions are available.
- Replacing the Luau require wrapper/continuation protocol was rejected as
  unnecessary after the measured native improvement; yielding/concurrent/error
  behavior remains intact. No new custom allocator or VM model was introduced.

Create/cancel bursts still cost ~20 ms at 1,000 scripts versus ~8 ms in the
original per-script architecture. Task records, registry roots, owner checks,
map/shared_ptr allocations and safe reaping are retained. This is an explicit
measured tradeoff, not a claim that every original regression disappeared.
Future task-creation work requires new profiling and lifetime evidence.

### Correctness and qualification

The original 36 core cases remain; three focused cases add lazy-source load
counts, resource identity/revision replacement, pending revision invalidation,
metadata-path cycles/sticky errors and cached require during shutdown. Native
Integration adds an earlier changed-signal subscriber that requires new source
before ModuleScript's later invalidation handler. This protects against an
identity-only shortcut returning stale data. Existing native fixtures still
exercise role/cache separation, source reload/destroy/replace, environments,
callbacks, task cancellation, Instance liveness, remotes, service replacement
and scene shutdown.

| Final gate | Result |
| --- | --- |
| Windows MSVC Debug/Release/ASan core + adapter builds | Pass; 39-case core suite passes five repetitions in each configuration |
| Linux GCC Debug/Release/ASan core + adapter builds | Pass; 39-case core suite passes five repetitions in each configuration |
| Windows Debug/Release native fixtures | Eight process results/configuration, all exit zero/PASS |
| Linux Debug/Release native fixtures | Eight process results/configuration, all exit zero/PASS |
| Full Linux Godot + bindings + adapter + Luau ASan/LSan | Three ordered-close repetitions, 24 process results pass with detect_leaks=1 |

Windows Debug Dedicated/Editor and Release Editor servers emitted the known
GL-017 zero-channel diagnostic; logs remain intact. Ordered-close sanitizer
stress still isolates the separately proven engine leak. GL-017 and GL-018
remain open; Windows full-native sanitizer coverage is not claimed. SCons/release
packaging was not rerun or republished for GL-019; CMake exercises actual native
code in both build configurations. The inherited distribution issues retain
their own scope. No historical stress matrix was repeated without need.

Reproduction commands and metric limits are in
[tests/runtime/README.md](../tests/runtime/README.md#gl-019-profiling-and-optimization-comparison).
Raw records and metadata are indexed in [evidence](evidence/README.md). Worker logs:
`linuxbox:/opt/codex/godotluau/logs/gl019-*.log`, raw perf/core/native artifacts
under `/opt/codex/godotluau/artifacts/gl019`; Windows build log
`dockerbox:C:\Sandbox\Codex\Logs\GodotLuau\gl019-builds.log`, native logs in
local `.runtime-tests/qualification/gl019-windows-{debug,release}`.

GL-019 is resolved for the requested profiling/optimization/qualification scope
on this branch. No universal performance target or production readiness is
implied. Main, upstream, dependency pins, updater and release automation remain
unchanged. Networking authority, persistence, capability/quota and distribution
limitations remain independently tracked. The next optional performance task is
profiling steady-state task creation under a real gameplay workload, preserving
the same ownership rules; it is not part of this completed change.
