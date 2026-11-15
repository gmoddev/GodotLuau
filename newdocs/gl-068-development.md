# GL-068 development campaign

## Baseline and acceptance — 2026-11-14

Branch `feature/gl-068-scalable-runtime` starts at verified remote main
`1fe0083286a3c79f9b4b9f23f8405c508c2e1db7`, after the normal GL-067 merge.
GL-067's final Windows integration CI and closing documentation are being handled
in their separate integration checkout. No GL-068 change is authorized for main.
Releases/updater stay disabled; Native remains default and Scripted opt-in.

This is an implementation campaign across bounded runtime modules, reload,
native interoperability, representative game architecture and qualification.
The acceptance target is enforceable accounting and meaningful larger workloads,
not changing 64 to a larger unexplained constant. Existing VM/domain, authority,
generation retirement, scheduler and persistence contracts remain authoritative.
Reuse unchanged evidence; each changed behavior requires focused actual tests.

## Initial source audit

`src/core/gl_project_modules.cpp` owns a per-domain map of strong Script resource
references keyed by project path. `Resolve` refuses a 65th distinct path, checks
project confinement and one MiB per file, and maps the resource ObjectID/revision
to domain module identity. Source is loaded lazily through `Load`. `Retire`
invalidates retained resources but does not erase that map. These are source
observations, not a newly executed capacity reproduction.

`GLExecutionDomain::BeginRequire` already provides result reuse, sticky errors,
initializer/waiter ownership, import-cycle checks and revision-aware identity.
`InvalidateModule` already finds transitive dependents and detaches their closure
before cancelling owners/native registrations. These must be extended/reused,
not replaced. Individual modules cap direct dependency sets at 256. VM allocation,
owners/coroutines/tasks/references already have domain budgets under ADR-002.

Compilation currently runs synchronously through pinned Luau, outside VM
interruption/accounting, producing a temporary bytecode string. Module records
retain C++ source and registry-rooted results; the project resource map retains
Godot source resources separately. Merely raising path admission would leave
aggregate source/compiler/bytecode/dependency work insufficiently accounted.
Default domain VM quota is 512 MiB and retained-owner admission 16,384; these
are not process RSS limits and must not be silently relaxed to reach a scale.

## Next implementation work

Trace source publication/reload and host settings, establish disposable baseline
reproductions, then record the focused module-budget/identity decision before
changing admission. Implement explicit per-domain accounting and diagnostics,
bounded graph/compile/cache behavior and regression cases. Qualify scales
64/128/256/512/1024 as measured targets, keeping synthetic controls distinct from
representative game systems. Independent reload/interoperability phases follow
once the module contract and qualified implementation support them.

No runtime change, larger admitted capacity, bytecode-cache improvement or
large-game qualification is claimed by this preparation record.

## Executed native admission baseline

`capacity-baseline-01` uses the existing isolated native fixture/process helpers,
verified official Windows 4.7.1 host and retained Debug adapter from native run
`43606301218` (native fingerprint `558733a6…`). Its runtime module implementation
is identical to current main; later GL-067 changes affect editor indexing only.
The controlled probe creates 65 typed item/configuration modules, validates
their returned fields and catches the first rejected import. Exactly 64 load;
the 65th reports `DomainRequire:5: [Runtime:Require] Expected a live ModuleScript`.
The process exits zero under the explicit baseline expectation of 64, with empty
stderr. `tests/runtime/ModuleCapacity.gd` retains the reproducible workload.
Raw logs/result are under the local `gl068/capacity-baseline-01` artifact root.
This is a synthetic admission reproduction, not a 65-module production game,
new-capacity qualification or compile/memory performance measurement.
