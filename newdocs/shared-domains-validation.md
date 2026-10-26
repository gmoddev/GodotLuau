# Shared-domain implementation and qualification

Date: 2026-10-26. Starting revision:
`8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
Branch: `runtime/shared-domains` in the public `gmoddev/GodotLuau` fork.
The decision precedes implementation in [ADR-001](adr-001-shared-execution-domains.md).
[The work log](shared-domains-work-log.md) records investigation, failed checks
and fixes as they occurred. This report distinguishes implemented behavior from
production qualification; GL-014 remains open for the latter.

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
