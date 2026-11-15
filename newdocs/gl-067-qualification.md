# GL-067 platform qualification

Status: the implemented multi-phase checkpoint is qualified at `b11347b`,
including both reproduced editor corrections, final production profiles/packages
and actual SCons Release authoring. Earlier game/render/export receipts retain
their original identities and unchanged implementation scopes.
Branch `feature/gl-067-development-platform` is preserved by the normal
[main integration](gl-067-main-integration.md); the wider
expansion remains open under the limits below. The [journal](gl-067-development.md) preserves failed attempts
and corrections; the [guide](gl-067-editor-api.md) defines supported behavior.
This is substantial multi-subsystem expansion, not complete Godot API parity.

## Source identity

Baseline main: `f54aa44265ae36b98fccfbc0622c4b61c4f6db06`.
Native implementation: `b11347b21f1bae19c98be78014a2aa68a090ce3d`, tree
`f9a8891d3bf807ac9880e1c1feb2bab9b9d7c0dd`.
The 139-file LF-normalized native fingerprint is
`320853995024f3809d849d5fda742f41f84d4dfef060a8efbc53d3577fe68124`.
Later commits extend tests, reports and documentation without changing those
native inputs. Earlier receipts identify `533e108` and its `556013c8…` fingerprint;
the import correction `d8090a0` uses `558733a6…`. Only editor literal-import and
declaration-file classification changes separate those final native checkpoints.

Pins remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Official editor/templates and existing
admitted hosts retain Godot 4.7.1 `a13da4feb8d8aefc283c3763d33a2f170a18d541`
and the established GL-018/GL-029 patches. No dependency or host change is made.

## Evidence and its scope

| Boundary | Result |
| --- | --- |
| [Core 43603467149](https://github.com/gmoddev/GodotLuau/actions/runs/43603467149) | Windows/Linux pass all 87 original and eight debugger/profiler scenarios at `f83d98b` |
| [Import-fix core 43606301059](https://github.com/gmoddev/GodotLuau/actions/runs/43606301059) | Windows/Linux pass all 87 original and eight debugger/profiler scenarios at `d8090a0` |
| [Declarations 43594486137](https://github.com/gmoddev/GodotLuau/actions/runs/43594486137) | Windows/Linux policy, five generated outputs and actual pinned Luau type checks pass; declaration/policy inputs unchanged afterward |
| [Index 43603467132](https://github.com/gmoddev/GodotLuau/actions/runs/43603467132) | Windows/Linux Release and Linux ASan/LSan pass actual production service: typed imports, definitions, completion, diagnostics, lexical rename, cache/edit/delete, pagination, cancellation, type-function exclusion and disposal/recovery |
| [Import-fix index 43606301119](https://github.com/gmoddev/GodotLuau/actions/runs/43606301119) | Same three profiles pass with the empty-module import regression at `d8090a0` |
| [Native 43598864037](https://github.com/gmoddev/GodotLuau/actions/runs/43598864037) | Windows/Linux pass 141 required actor results, native bindings/lifetime/authority, actual editor workflows, Foundry/restart and seven debugger protocol modes |
| [Import-fix native 43606301218](https://github.com/gmoddev/GodotLuau/actions/runs/43606301218) | Windows/Linux pass all 141 actor results, seven debugger modes and actual 72-check authoring/reload/recovery workflow, including the corrected import case and fresh scene reopen |
| [Full-native sanitizers 43599608700](https://github.com/gmoddev/GodotLuau/actions/runs/43599608700) | Windows ASan and Linux ASan/LSan pass detection controls, production VM reload, core, 141 actors and actual debugger cases; no unexpected reports |
| Windows rendered editor | Matching Debug adapter passes actual breakpoint, native stack/locals, stepping and saved-source reload; four retained captures inspected |
| Windows rendered Foundry | Matching Debug adapter passes 44 checks plus persistence restart; menu/world/completion captures inspected |
| [Candidate 43599606392](https://github.com/gmoddev/GodotLuau/actions/runs/43599606392) | All four SCons profiles, Linux core sanitizers, both extracted packages/companion startup and aggregate acceptance pass at `533e108` |
| [Production debugger 43605411113](https://github.com/gmoddev/GodotLuau/actions/runs/43605411113) | Windows/Linux SCons Release products pass all seven protocol cases and actual 36-check native editor journey |
| [Game/export 43605497766](https://github.com/gmoddev/GodotLuau/actions/runs/43605497766) | Windows/Linux Foundry Debug/Release standalone export/restart and Windows Relay Siege solo/recovery/listen/dedicated pass |
| [Import-fix candidate 43606352703](https://github.com/gmoddev/GodotLuau/actions/runs/43606352703) | All four source profiles, both extracted packages/companion starts and aggregate acceptance pass |
| [Final core 43611375744](https://github.com/gmoddev/GodotLuau/actions/runs/43611375744) | Windows/Linux pass all 87 original and eight debugger/profiler scenarios at `b11347b` |
| [Final index 43611375891](https://github.com/gmoddev/GodotLuau/actions/runs/43611375891) | Windows/Linux Release and Linux ASan/LSan pass both reproduced index corrections and the established semantic/lifetime/scale checks |
| [Final native 43611375892](https://github.com/gmoddev/GodotLuau/actions/runs/43611375892) | Windows/Linux pass 141 actors each, seven debugger modes, actual 73-check authoring/reload/recovery workflow with shipped declarations and fresh scene reopen |
| [Final candidate 43611376440](https://github.com/gmoddev/GodotLuau/actions/runs/43611376440) | All four SCons source profiles, Linux core sanitizers, both extracted packages/companion startup and aggregate nonpublishing acceptance pass |
| [Final production Release 43617455444](https://github.com/gmoddev/GodotLuau/actions/runs/43617455444) | Both actual SCons Release libraries pass seven protocol modes, 36 debugger-editor checks, 73 authoring/semantic-index/reload/recovery checks and saved-scene reopen, with shipped declarations present |

The [compact hosted record](evidence/gl067/ci-qualified.json) retains source,
product and summary identities. [Rendered editor](evidence/gl067/graphical-debugger.json),
[Foundry](evidence/gl067/foundry-rendered.json), [index timing](evidence/gl067/editor-index.json)
and [focused debugger](evidence/gl067/debugger-focused.json) receipts remain
separate from CI. Existing qualified infrastructure is reused without another
test layer around its artifact checks.
The correction has separate [current worker](evidence/gl067/import-navigation-index.json)
and [actual native editor](evidence/gl067/import-navigation-native.json) receipts,
paired with its [reproduced baseline failure](evidence/gl067/import-navigation-baseline.json).
The unchanged runtime/authority/lifetime paths retain prior full-native sanitizer
evidence; the changed worker path passes its current Linux ASan/LSan profile.
The final declaration correction has its own [worker](evidence/gl067/definition-files-index.json)
and [actual native editor](evidence/gl067/definition-files-native.json) receipts,
with the [shipped-file reproduction](evidence/gl067/definition-files-baseline.json)
kept separately. Definition-only files are excluded from module discovery and
open-buffer capture; native globals use the embedded definition authority.
The [final production receipt](evidence/gl067/final-production-qualified.json)
retains the accepted source tree, pins, native fingerprint, archive/product and
summary hashes, extracted companion startup and actual Release authoring results.
Windows/Linux archives hash to `1cca1f0c62b3335429e7232d6e7114212097add17b6016bb266be8725817f7b6`
and `d825128557e5ddbb2a33d2608147bb1f456ef79fd7ea9ec988346dddc63e2f62`.
The optional hosted performance job was intentionally off; the paired retained
benchmark is the performance evidence, not a passing claim for a skipped job.

## Implemented and measured behavior

The worker indexes up to 4,096 files/32 MiB, returns 256-entry pages, cancels stale
generations, prioritizes active buffers and uses the existing pinned Luau
frontend/generated native declarations. Semantic working sets are bounded to
256 modules/4 MiB with 50 ms per-module limits. User type functions are excluded
because their compiler VM allocator has no project quota. Dynamic names remain
unresolved candidates. Rename is a source-preconditioned lexical preview only.
Filesystem cancellation occurs between bounded file operations; it does not
preempt a stalled operating-system read or establish a hard RSS limit.

On the retained 256-module/661,760-byte editor workload plus 14 auxiliary modules,
main-thread submit calls take 0.073–0.374 ms and maximum polls 1.248–1.316 ms.
Frames continue while cold analysis takes 1,431.403 ms on the worker. The previous
GL-055 observation occupied the main thread for approximately 250 ms and did not
fully warm its scan. This establishes responsiveness, not faster total analysis.
The separate 1,205-file typed catalog measures cross-module/cache behavior; it is
not relabelled as a thousand-module production game. Hosted Release process
peaks are approximately 53 MiB Windows / 60 MiB Linux; ASan measurements are
reported separately in the journal.

Read-only breakpoint conditions share Watch restrictions. False/nil skips a
stop; invalid evaluation stops as ConditionError. Manual detach/attach on the
same live transport rotates session identity, retires old inspection roots and
admits new/reloaded generations. Physical disconnect still fails closed.
Inclusive callback/require timing and domain allocator observations extend the
existing opt-in profiler. Paired DockerPC MSVC Release disabled medians are
2,682.2 / 2,742.9 us for 100,000 operations (+2.3%), with zero counted C++
allocations and identical VM peaks. This short synthetic comparison is not a
general gameplay speed claim.

Saved-source reload validates the entire bounded batch before publishing any
revision. Failed compile/file validation preserves previous source/generations;
success publishes those exact snapshots through existing dependent-module and
owner retirement. Repeated reload/preview and failure recovery pass. Runtime
side-effect rollback and automatic state migration are not promised.

Native Theme styling, RichTextLabel parsed text, Skeleton3D traversal and bounded
navigation-obstacle configuration expand the existing owned-resource/scene
dispatcher. Inventory grows from 113/384/225 to 114 constructible classes,
391 properties and 238 methods; signals/constants remain 41/51. The
[machine report](evidence/gl067/native-invocations.json) separates metadata,
admitted/generated surface, host availability, 617 invoked domain/member pairs
in native fixture logs and 127 pairs in actual Foundry logs. Invocation counts
are not substituted for assertion or application correctness.

## Limits and readiness

The implemented phases are ready for integration review within these limits.
Core, native, index, declarations, appropriate sanitizer scopes, production
source/package and actual Release authoring gates pass. Preceding rendered/game/
export receipts retain their original identity and unchanged behavior scopes.
No unverified runtime or distribution channel is inferred from this checkpoint.
Main is unchanged, Native remains the
default controller, Scripted stays opt-in, and releases/updater stay disabled.

The wider campaign remains open. Foundry is the real acceptance game, with its
existing scene inheritance, animation, navigation, resources, transactional
progress and generation reconstruction. A hundreds-module runtime game is not
qualified: the existing loader retains a 64-path-per-domain admission limit.
Editor scale measurements do not raise that runtime resource contract.

Unrestricted AnimationTree target graphs, raw Callable/Signal/RID authority,
privileged viewports/windows, function sampling and automatic state-migrating
reload remain unimplemented. Physical debugger reconnection/editor restart cannot
reuse the pinned public Godot transport factory; same-transport manual Attach
does not claim that capability. These need additional ownership/compatibility
contracts rather than superficial registry entries.

GL-065 retains the external engine editor's eight leaked TreeItem/TextParagraph
objects at rendered debugger exit, with reproducible source/verbose evidence.
No pinned engine patch is introduced. Windows LSan, Linux graphical presentation,
physical input and universal leak freedom remain unsupported claims. Rendered
journeys use an isolated non-input desktop and programmatic native actions.
