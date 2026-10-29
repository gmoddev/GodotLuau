# GL-004 execution limits: contract and work record

## Baseline and scope

Verified local/remote main `8aec90252d10f7dcec97e97423ca390467087711`;
clean single worktree, unchanged pinned Luau and godot-cpp. Development branch:
`runtime/gl-004-execution-limits`. No main merge or distribution is authorized.
This chronological record preserves intermediate implementation states and
failures. The final policy is [ADR-002](adr-002-domain-resource-policy.md);
completed qualification and its limits appear below. GL-004 is fixed and
qualified on this development branch, not merged to main.

## Trust and accounting contract

Preserve one VM per applicable Server/Client domain. The accounting boundary is
the domain, not exact per-script heap attribution. Trusted initialization includes
library/native registration and embedded bootstrap; gameplay includes modules,
scripts, tasks, callbacks and resumed coroutines. Bootstrap policy must be explicit
and must not accidentally exempt gameplay reached through a native callback.

VM allocation accounting must cover the allocator's actual pages/blocks, including
bootstrap, shared module objects, registry roots and thread stacks. It excludes
Godot objects, compiler/C++ allocations, sockets and OS/process memory. Allocation
growth must be checked before realloc; failed realloc preserves the original block
and accounting. Allocator context outlives lua_close. No allocator exception may
escape its C callback.

Execution attempts share the earliest deadline through nested/reentrant resumes;
a yield ends an attempt and a legitimate subsequent resume receives a new budget.
Module failures retain existing sticky-error semantics. Cancellation must happen
at a safe boundary, not by freeing a VM in an interrupt callback. Shutdown needs
an aggregate budget as well as per-hook limits. No automatic restart of a
deterministically failing owner/domain.

Native filesystem globals and synchronous HTTP remain exposed under GL-003/005.
Luau interrupts do not preempt arbitrary native C++ calls. Neither these controls
nor Luau's sandbox API establish hostile-code isolation or a hard real-time bound.
Keep _G/shared mutable within a domain, independent script/module environments,
require identity and getfenv/setfenv compatibility; document any intentional
read-only builtin change rather than removing APIs silently.

## Verified pinned API findings

Pinned Luau provides lua_newstate(lua_Alloc, void*), lua_cpcall, callback userdata,
interrupt(lua_State*, int gc), userthread, luaL_sandbox and luaL_sandboxthread.
Sandbox freezes global library tables and the root global environment; applying
it blindly after bootstrap would also freeze mutable _G/shared/service tables.
Initialization order and compatibility therefore require deliberate handling.
Interrupt safepoints include loop edges and calls/returns; GC callbacks must be
handled separately. The pinned default LUA_USE_LONGJMP is zero and error recovery
uses C++ exceptions; supported build configuration must retain exception-safe
unwinding. Do not rely on unwinding RAII through longjmp.

lua_cpcall establishes protection before checking stack space, constructing its
temporary C closure and invoking the host trampoline. This is relevant to quota
failures during host preparation, not just inside lua_resume. Rejecting allocation
only inside Resume would leave argument marshalling/thread creation unbounded;
rejecting everywhere without protected host entries could escape into Godot.

## Entry inventory checkpoint

Core Execute/module initialization/task scheduling/coroutine wrappers and close
hooks converge on Resume. Existing depth-eight deferral must remain. Native
dispatch first creates a coroutine and marshals arguments outside that protected
resume in services, input/GUI/billboard, humanoids/parts, animation/tween,
interactive objects, network/remotes, attribute/property publication and child
relays. These preparation paths need protected boundaries too.

Two synchronous RemoteFunction lua_pcall paths operate on owner anchors and need
explicit execution scopes. API-side constructor/conversion lua_call/lua_pcall
paths may execute user-replaced Lua functions and must inherit the active budget.
Core require/coroutine wrappers and embedded native bootstrap have separate trusted
load/pcall paths. Reload/invalidation cancels existing owners and reuses normal
startup; source compilation itself is native work, not preempted Luau bytecode.

## Qualification plan and unresolved design work

Measure allocator peaks and high-water task/thread/reference/owner counts on the
existing workload before choosing production defaults. Existing GL-019 evidence
includes 1,000 scripts with 32 create/cancel pairs each and million-call require
loops; small arbitrary limits would break that legitimate fixture.

Use actual production core/native fixtures. Run infinite-loop and quota failures
in separately owned, hidden/headless child processes with deadlines, captured logs
and Windows crash-UI suppression. A watchdog timeout is failure, not proof of
runtime interruption. Extend CI discovery/admission deliberately when case counts
change. Preserve GL-019/022 semantics and existing GL-017/018 limitations.

## Intermediate probes (not qualification)

Windows MSVC Debug, existing worker build `runtime-msvc-debug`, two build jobs:

- `gl004-accounting-baseline.log`: compile rejected the Windows `max` macro
  collision in `numeric_limits::max()`. The parenthesized `(max)()` form fixes it.
- `gl004-accounting-baseline-fixed.log`: 42 normal core cases pass. The actual
  production allocator reaches about 5,970,952 VM bytes in the 1,000-operation
  core benchmark. This is a core fixture measurement, not native process RSS.
- `gl004-interruption-probe.log`: 42 normal cases plus eight isolated resource
  children pass. Actual non-yielding loops, catch/retry, nested resumes, module
  initialization, callbacks and close hooks stop through the VM interrupt.
  None required the external watchdog. Fresh domains and unrelated owners run.
- `gl004-callback-sandbox-probe.log`: the same 50 cases pass after protected
  callback preparation and sandbox initialization; the callback interruption
  child now exercises `GLDispatch` rather than constructing a raw coroutine.

The pinned C++ VM asserts that a caught Lua exception belongs to the protected
thread. Protecting an anchor while allocating on a different coroutine is unsafe.
Callback creation therefore uses `lua_cpcall` on the anchor; argument conversion
uses a protected call on the new callback coroutine itself. The context is
synchronous and does not survive dispatch. Execution still uses the existing
Resume/scheduler, including depth-eight deferral.

Sandbox sealing runs after trusted native registration/stdlib bootstrap and
before the first gameplay owner. `luaL_sandbox` freezes intrinsic libraries and
the root environment. Existing mutable custom service facades, `_G` and `shared`
are restored to their prior mutability; intrinsic-library aliases stay frozen.
Owners use `luaL_sandboxthread`. Reused environments disable safeenv import
optimizations. This preserves native capabilities; GL-003 and GL-005 remain open.

These are intermediate results on uncommitted sources. Native compilation and
behavior, explicit sandbox regressions, hard memory enforcement, safe resource
failure/retirement, admission quotas/configuration, Linux/sanitizers and hosted CI
remain outstanding. The domain allocator is still accounting-only: its low-level
quota rejection is tested, but no production domain memory cap is enabled yet.
GL-004 remains open and this branch has not been published as qualified.

## Protected-memory implementation checkpoint

The subsequent uncommitted implementation protects VM/bootstrap setup, owner
environments, registry rooting, module result retention, callback preparation,
synchronous invocation, native property conversion and external waiter argument
preparation. It adds terminal memory-failure disposition, admission caps,
configuration validation and host resource diagnostics. The selected policy is
recorded in [ADR-002](adr-002-domain-resource-policy.md); defaults remain subject
to representative workload qualification.

`gl004-memory-admission-probe.log` initially reported one sandbox-test failure:
the test incorrectly expected replacing an owner's own environment metatable to
fail. The pinned API freezes the proxy metatable itself, not that compatibility
operation. The corrected test checks mutation of the shared proxy metatable.

The first native sandbox probe compiled but failed BootstrapContract/ModuleScript
assertions (`gl004-sandbox-probe/integration-0.stdout.log`). Gameplay ModuleScript
environments still had safeenv enabled: intrinsic fastcalls bypassed custom
typeof. Disabling safeenv for all gameplay owners fixes the actual native
compatibility failure without removing typeof/getfenv/setfenv.

`gl004-protected-memory-native-build.log`: Windows Debug core passes 57 cases,
including allocator quotas, caught-OOM retirement/recovery, marshalling OOM and
task/coroutine/reference/owner admission. The actual GDExtension builds with two
jobs. `gl004-protected-native/regression/results.json` then records all eight
existing native lifecycle/network actors passing, including GL-022. This is an
intermediate configuration result, not cross-platform/sanitizer qualification.

`gl004-resource-probe-build.log`: Windows Debug core passes 60 cases (50 normal
and ten isolated execution children), including synchronous invoke, marshalling
reentry and shared-module quota exhaustion. Native resource probing first passed
execution/module/callback/invoke/memory, then found that its task-cleanup assertion
incorrectly expected zero tasks. The embedded runtime has an existing service
poller. The corrected fixture measures baseline tasks and requires cleanup back
to that baseline without exceeding the configured cap. All eight children pass
in `gl004-protected-native/resources-baseline-fixed` (each 15-second watchdog).

The provisional one-second default interrupts the existing million-call Debug
require benchmark. With explicit profiling `--resume-ms 0`, the same actual
native workload completes in 2,443.2885 ms, peak VM 1,098,880 bytes, peaks of three
tasks/six coroutines/two owners/one external reference. Results:
`gl004-require-measurement/results.json`. The default is changed to ten seconds
to retain that Debug workload with roughly fourfold observed headroom. Gameplay
projects can configure shorter limits per domain; failure children explicitly use
10–25 ms. Native population and final-default qualification remain pending.

## Cross-domain and protected-return checkpoint

Further source review found two boundaries requiring explicit coverage: a
synchronous Server/Client call could otherwise receive a fresh budget, and a
source allocation rejection during result copying could be lost when destination
conversion threw. Active synchronous scopes now retain ancestor constraints;
result-copy unwinding checks the source before rethrowing. New isolated children
disable the child domain's own timer/count to prove ancestor enforcement, including
A-to-B-to-A reentry. A caught ancestor allocation rejection also prevents entering
a child VM; the rejecting domain retires at its own protected return.

Owner replacement now keeps the old owner alive until nonterminal admission has
succeeded. Trusted bootstrap fails closed if embedded initialization catches an
admission rejection; a cumulative admission counter detects this even when the
outer protected call returns success. Native fixtures exercise a one-coroutine
bootstrap cap, independent Client operation and explicit fresh-scene recovery.

Intermediate source `04f1d1c1d22cfb04f7bd5fd9d4b1db2e5cc9dc8a50984fe4c66b8e6c63c2d18e`
passed six 62-case core configurations and 180 native actors, plus Windows SCons
Debug/Release builds and resource actors. This predates the ancestor and
bootstrap changes and is **not** the final qualification source. Subsequent
65-case Windows/Linux Debug core and eight resource actors per platform passed
at source `766be995f49904ed4840bc914e19cc6fbf3242805969c92c08c183ed9e3d4873`.

Verification corrections retained in worker logs: numeric-error regression uses
`error(Number, 0)` so the builtin does not stringify inside protected execution;
JUnit output requires the existing 65,536-byte CI capture size, since CTest's
default 1,024 bytes truncates passing case markers. Windows incremental linking
reported LNK1163 in an existing object. Relinking with cache-local
`CMAKE_SHARED_LINKER_FLAGS_DEBUG=/INCREMENTAL:NO` succeeded without dependency or
product source changes; fresh hosted CI remains required.

The first complete candidate native input fingerprint was
`44e9739c67987153a50b1ef3aa11d1c02371872501a8e4b9c38dbb9652f39b89`
(75 LF-normalized native inputs). The final core suite has 66 cases: 50 normal
cases and 16 separately contained resource children. Results below will identify
completed configurations; earlier checkpoints remain historical evidence.

Final review then found that synchronous result copying checked allocator
rejection but did not check an elapsed deadline after returning from native
conversion. Invoke now checks that boundary and cancels the registering owner.
The isolated invoke child also exercises a native 20-ms copy under a 10-ms
deadline, invalidation of its callback and survival of an unrelated owner.
This changes the qualified native fingerprint to
`8037d8046c9136d3dc9736fe06a6308d5b38698c0b4e381b47f4092784d79a7c`.
All required configurations are rerun against that source; the previous
66-case/180-actor candidate remains superseded evidence. One Windows orchestration
attempt rejected an already existing output directory before launching a fixture;
the rerun uses the fresh `gl004-8037-*` namespace and preserves prior artifacts.

## Final local qualification

The [qualification manifest](evidence/gl004-execution-limits-2026-10-29.json)
retains the final source, fixture, binary, engine, JUnit and log digests, worker
paths and measured resource dictionaries. Both workers match all 24 normalized
Python/GDScript/configuration harness hashes and both raw C++ fixture hashes.
Pins remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

| Final configuration | Core | Native |
| --- | ---: | ---: |
| Windows MSVC Debug | 66/66 | 36/36 |
| Windows MSVC Release | 66/66 | 36/36 |
| Windows MSVC ASan | 66/66 | not qualified; existing GL-018 |
| Linux GCC Debug | 66/66 | 36/36 |
| Linux GCC Release | 66/66 | 36/36 |
| Linux GCC ASan/LSan | 66/66 | 36/36 |

Native groups are eight lifecycle/GL-022, ten authority/network, ten functional
animation and eight isolated resource actors. All four GL-022 integration
markers remain present. Native resource watchdogs are 15 seconds; other actor
groups use 60 seconds. No resource watchdog kill is counted as a pass.
The Linux sanitizer engine is the matching minimal headless Godot build at
`a13da4feb8d8aefc283c3763d33a2f170a18d541`; engine and extension are instrumented.
`gl004-asan-runtime-defaults.log` confirms detect_leaks and leak_check_at_exit
are true. No ASan/LSan finding appears in these runs. Minimal-engine font warnings
are retained; no renderer/real-physics qualification is inferred.

SCons 4.5.2 builds actual template_debug and template_release products on both
workers with `-j2`; each product passes all eight resource actors (32 total).
SCons products do not contain CMake's test-only scene teardown hook. Linux Release
HotPathBenchmarks also passes 1,000 operations, including concurrent require,
manual coroutine completion, cancellation/reaping and shutdown. Its idle pending
tick makes one C++ allocation, not an allocation per retained task.
Process-containment tests pass all 14 Linux cases; Windows passes eight applicable
cases and skips six Linux /proc cases.

Representative actual native Debug runs use the final production defaults:

| Workload / metric | Windows | Linux |
| --- | ---: | ---: |
| 1,000-script startup, ms | 1596.004 | 508.527 |
| Population VM peak bytes | 50,508,704 | 50,475,984 |
| Task / coroutine peaks | 33,002 / 34,004 | 33,002 / 34,004 |
| Owner / external reference peaks | 1,001 / 1,000 | 1,001 / 1,000 |
| Million cached requires, ms | 2473.0294 | 625.4181 |
| Require VM peak bytes | 1,098,880 | 1,098,880 |

Each population script requires the shared module, performs 100 cached requires
and 32 defer/cancel pairs, then waits through scheduler frames. The module runs
once. Both workloads record zero allocation/admission rejections, available host
operations and a nonclosing domain. Population destruction returns owner/reference
counts to the service baseline; coroutine memory can remain until GC/VM close.
These are one-trial compatibility measurements, not statistically established
speed comparisons or bounds for every game. The ten-second elapsed default gives
about fourfold headroom over the slower measured Debug require entry. The task
cap is about twice the retained-task high-water mark, the coroutine cap about
3.8 times its mark, and the VM cap over ten times the observed allocator peak.
Projects should choose lower elapsed limits where their content permits it.

Commands, using the existing configured build/cache directories:

```text
cmake --build <build> --target ExecutionDomainTests GodotLuauAdapter --parallel 2
ctest --test-dir <build> --output-junit <report> --test-output-size-passed 65536 --test-output-size-failed 65536 --output-on-failure
python tests/runtime/CheckCoreCI.py report <report>
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh>/regression --teardown --coordinated-close --timeout 60
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh>/security --security --timeout 60
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh>/animation --animation --timeout 60
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh>/resources --resources --timeout 15
scons platform=<windows|linux> target=<template_debug|template_release> -j2
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh>/population --benchmark --counts 1000 --repeat 1 --timeout 90
python tests/runtime/RunRequireBenchmark.py --godot <engine> --extension <library> --output <fresh>/require --calls 1000000 --repeat 1
```

Windows ASan builds only ExecutionDomainTests. Windows SCons uses the previously
approved portable module through RunSConsPortable.py, not a global installation.
All heavy work runs on the configured workers. Local Python AST, documentation
link/source review and git diff whitespace checks pass. No dependency/vendor,
asset, release workflow or updater file changes are included.
The hosted record below completes qualification on the published implementation
and its fixture follow-up.

## Hosted qualification

Implementation `1e201ed9f229a5d9b39043c303e573e9566fa69c` is published on
`runtime/gl-004-execution-limits`. Main remains
`8aec90252d10f7dcec97e97423ca390467087711`. Fresh
[core run 40855056067](https://github.com/gmoddev/GodotLuau/actions/runs/40855056067)
passes Windows/Linux Debug, 66 distinct cases each. Both downloaded core artifact
ZIP digests match GitHub metadata; local replay of CheckCoreCI discovery/report
passes on each. The independently triggered
[native run 40855056031](https://github.com/gmoddev/GodotLuau/actions/runs/40855056031)
passes Linux Debug with 36 actors. Its downloaded ZIP digest, source/harness
identity and all retained log hashes verify. Windows compilation and all eight
lifecycle actors passed, but Handler client1 failed `valid subsequent 2D state`
in the network group. Animation/resources were skipped. The native workflow is
failed, not qualified by its successful build or Linux result. Failed Windows
artifact `12888959312` verifies as SHA-256
`bce66b4130640f1ee473fc64c2c46c5cef47506cd456f34b9c80afaaec661331`.

The fixture sent each valid positive state once over an explicitly unreliable
RPC, then slept 250 ms before asserting observation; it also acknowledged only
client2 before advancing. Receive-state handlers are unchanged by GL-004, and
the logs contain no GL-004 resource failure. The logs do not prove whether the
packet was late or lost. The positive control now resends the same real valid
RPCs every 50 ms for at most five seconds and requires **both** clients to
acknowledge exact state observation. Clients have their own five-second state
deadline and report the actual position on failure. Authority configurations,
wrong-peer attacks, rejection assertions, exact expected positions and failing
exit behavior are retained. This is a bounded delivery fixture correction, not
a network runtime change or a weaker successful-state assertion.

The updated network fixture passes Windows Debug/Release and Linux
Debug/Release/ASan using the identical native binaries: all 50 actors pass.
Five additional Windows Debug Handler trials pass all 15 actors. Earlier
full-core/native/resource/SCons results retain their original fixture hashes;
the manifest records the changed fixture and follow-up log/result digests
separately. Runtime source remains `8037d8046c9136d3dc9736fe06a6308d5b38698c0b4e381b47f4092784d79a7c`.
Fresh hosted CI is required for the fixture follow-up before final qualification.

Fixture follow-up `040996e7d176bd4427644b14f5b4bf30ac45ce9d` is published without
rewriting implementation history. Fresh
[core 40857805897](https://github.com/gmoddev/GodotLuau/actions/runs/40857805897)
passes both platforms, 66 cases each; downloaded artifact digests and result
reports verify. Fresh
[native 40857806041](https://github.com/gmoddev/GodotLuau/actions/runs/40857806041)
passes Windows and Linux with all 36 actors each and the corrected fixture hash.
All four hosted jobs complete successfully on `040996e`. The previous failed
native run remains counterevidence, not overwritten or counted as passing.

All four downloaded artifact ZIP SHA-256 digests match GitHub metadata. Both core
discovery/JUnit reports pass local CheckCoreCI replay. Both native summaries bind
the exact hosted revision, the 75-input native fingerprint, all 24 effective
harness hashes, official engine identities and 36 zero actor exits. Every retained
native log digest verifies (94 Linux, 96 Windows), including the actual four GL-022
and eight GL-004 resource markers. The manifest retains run/job/artifact IDs,
digests and scope. Fresh Windows native compilation also succeeds without the
worker's cache-local incremental-link workaround.

**FIXED AND QUALIFIED on the development branch**, within ADR-002's resource and
compatibility contract. Main remains `8aec90252d10f7dcec97e97423ca390467087711`.
Implementation `1e201ed` and fixture follow-up `040996e` are retained; this final
follow-up changes documentation/evidence only. Runtime source, build inputs and
fixtures equal the hosted revision. Release publication and runtime updating
remain disabled. No PR, upstream message, distribution or main merge is created.
GL-003/005, Windows native ASan GL-018, GL-020 adversarial qualification and other
independent limitations remain open. The owned Linux qualification container is
stopped; caches/logs are preserved and unrelated services remain untouched.

## Main integration

Starting local/remote main: `8aec90252d10f7dcec97e97423ca390467087711`.
Qualified local/remote branch tip: `f38e4faa06498ff748a8733b9f11bbc54500a816`.
One clean worktree, no active claims, three commits ahead and no divergence.
Normal merge `55a9c20827dda9dda67372e655e67803e21236b1` preserves `1e201ed`,
`040996e` and `f38e4fa`, without conflict, squash, rebase or force-push.
The merge's entire tree equals the qualified tip. Its runtime, policy, build,
fixtures, workflows and pins also equal hosted source `040996e`.
Native fingerprint remains `8037d8046c9136d3dc9736fe06a6308d5b38698c0b4e381b47f4092784d79a7c`
(75 inputs). There is no policy/default, hook, allocator or registration change.

Fresh worker verification passes Windows/Linux Debug and Release core (66 cases
per configuration), plus Debug native lifecycle/GL-022 and all eight resource
actors (16 per platform). Incremental builds use two jobs and unchanged caches.
Worker native fingerprints and all 24 harness hashes match the qualified source.
The [integration manifest](evidence/gl004-main-integration-2026-10-29.json)
retains fresh JUnit/result digests. The historical
six-configuration core, 180-actor native, SCons, sanitizer and workload evidence
above is reused within its original scope, not described as newly executed.
Release jobs remain manual-only, read-only and job-disabled; updater admission
still returns false. No binary/archive publication or upstream operation occurs.
Fresh main hosted core/native CI remains pending. GL-003/005, GL-018 and GL-020
adversarial qualification remain independent; VM quotas do not bound native RSS,
and Luau interrupts cannot preempt arbitrary native blocking calls.
