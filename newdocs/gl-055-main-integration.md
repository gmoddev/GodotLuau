# GL-055 main integration

Status: **INTEGRATED AND VERIFIED WITH RETAINED LIMITATIONS**. Fresh main core,
native and declaration CI passes Windows/Linux.
The owner authorized the normal merge on 2026-11-13, superseding the feature
campaign's earlier no-merge boundary. Release publication and updater
distribution remain disabled.
The [integration receipt](evidence/gl055-main-integration-20261113.json) records
the exact history, source, workflow outcomes and native artifact identities.

## History and identity

Normal merge `9ecfc9ebf1509a50247c5104b2e09d6429a9804e` has parents
`b5389f0ff08c50e38bc11d868dbe12729a293535` (verified remote main) and
`9b77fdab6425c1f026917b342298ed86e0ba0d5b` (qualified feature tip).
All 43 feature commits remain ancestors, including the normal qualification
branch merges. There are no conflicts or rewritten commits. Its tree exactly
equals qualified feature tree `873eda1f42b886e609c9bf5ca279524c49a9badc`.
Integration notes change documentation only. Existing workspaces and the feature
ref remain untouched.

The 136-file LF-normalized native fingerprint remains
`ad749d8f7db2bf367e07eb35255d08056384797a2b185a98436a731992819b83`,
identical to qualified native implementation
`fd86f83223ae4bb3c87b333b875cdd6307903a12`. Dependency pins remain godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Publication/updater files equal
the pre-merge main versions. No runtime, fixture, dependency, admitted host or
protocol correction is required for this integration.

## Reused qualification and fresh acceptance

The [qualification record](gl-055-debugger-qualification.md),
[journal](gl-055-debugger-development.md), [ADR-018](adr-018-native-luau-debugger.md)
and [retained receipts](evidence/gl055/hosted-qualification.json) preserve their
original identities, failed attempts, corrections, performance measurements and
rendered captures. Their prior unmerged labels describe historical feature
checkpoints. No old binary/package is relabeled as a fresh main build.

Reuse the passing Windows/Linux core/native, four production Debug/Release,
package/startup, production Release debugger, Windows full-native ASan and Linux
ASan/LSan results within their unchanged input scopes. The actual Windows
rendered journey, ENet timeout/reconnection, selective reload and lifetime
observations remain valid for the identical implementation and fixture inputs.

Fresh hosted checks on the integrated revision must cover:

- Core: Windows/Linux 87 original cases and eight debugger scenarios.
- Native: Windows/Linux existing 141 actors, real five-case debugger protocol,
  native editor journey, Foundry/restart, authority, lifetime, storage, HTTP and
  Native/Scripted controller regressions.
- Declarations: Windows/Linux approved policy/generation drift and pinned
  frontend positive/negative type checks. Dispatch explicitly because unchanged
  declaration paths do not trigger this workflow automatically.

The merge and initial documentation are pushed to main at
`4838cd9a774eaa05bda4be68ac5c2891fb0cb026`, verified with `git ls-remote`.
The feature ref stays at `9b77fda`. All three fresh workflows identify that
integrated revision:

| Boundary | Run | Result |
| --- | --- | --- |
| Core | [43514235000](https://github.com/gmoddev/GodotLuau/actions/runs/43514235000) | Windows/Linux pass |
| Native | [43514235142](https://github.com/gmoddev/GodotLuau/actions/runs/43514235142) | Windows/Linux pass |
| Declarations | [43514259015](https://github.com/gmoddev/GodotLuau/actions/runs/43514259015) | Windows/Linux pass |

Both native artifacts identify the tested revision and expected native
fingerprint. Each records 141 required process results, five real debugger cases
with stop counts `[8, 1, 1, 2, 1]`, a passing native editor journey and 44 Foundry
checks. Reload, disconnect, ENet timeout/reconnection, profiling/ownership,
authority, lifetime, HTTP/storage interruption/recovery and Native/Scripted
controller regressions pass. All three workflows pass on their first attempts;
no runtime/fixture change or retry is needed for integration. Fresh native
results are headless; retained Windows rendered and sanitizer evidence keeps its
original identity and scope.

Native artifact digests are Windows
`4f99e05d2b4dfb46b03b5869f8ffdef677d54349296c2c829738c313269139c1`
and Linux `9297cdbaf4acacaff662b320a8c1b6971751913663153839b30c2ab7c9098263`.
Their IDs, downloaded summary hashes and extension/companion identities are in
the integration receipt.

The current quick start now distinguishes GL-054 historical error snapshots from
GL-055 live debugging. These documentation corrections do not alter qualified
runtime, fixture, workflow, package or declaration inputs.
Closing notes and the receipt also change documentation only. Those inputs equal
qualified `9b77fda` and tested main `4838cd9`; all original feature receipts remain
unchanged. No redundant rebuild is required for these closing notes.

## Preserved boundaries and limits

Native remains the default Character controller; Scripted is explicit opt-in.
Existing physics, health, animation, networking, storage authority, owner
retirement and resource limits retain their established contracts.

The game process pauses as a unit; remote peers may time out. Watches are
restricted read-only projections, not arbitrary evaluation. Async/native stepping,
module lexical-version labels, reload/reattach, profiler attribution and syntactic
navigation keep their documented limits. Large index queries can occupy the
main thread for roughly the existing 250-ms soft deadline and report partial
results. GL-065 remains an external Godot editor breakpoint-row cleanup defect.
Windows LSan, Linux graphical presentation and physical input remain outside the
qualified scope. Integration neither hides those limits nor patches the engine.

Release jobs remain disabled with read-only permissions; runtime updater
admission continues to fail closed. This merge does not enable distribution.
