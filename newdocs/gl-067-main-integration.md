# GL-067 main integration — 2026-11-14

The owner authorized normal integration of the qualified implemented phases.
Merge `e8dfee7c3f7fd7302fa0dcef9b4756d70f19d5a6` preserves all 26 feature
commits through `2df900ba5b7b0d09eab730ccbe4d21504c682c25`. Its first parent
is verified main `f54aa44265ae36b98fccfbc0622c4b61c4f6db06`; its second parent
is the unchanged feature HEAD. No conflict, squash or history rewrite occurred.
The merge tree `b05caca6c4676a90e92619442f821775a72f4ebd` exactly equals
the qualified feature tree. Other checkouts and unrelated work are preserved.

## Retained qualification and fresh main checks

The [qualification record](gl-067-qualification.md) and original receipts remain
unchanged evidence for their recorded inputs. Native implementation `b11347b`
has 139-file LF-normalized fingerprint
`320853995024f3809d849d5fda742f41f84d4dfef060a8efbc53d3577fe68124`.
Integration changes documentation only after the identical-tree merge. Pins,
fixtures, workflows, declarations, production/package inputs and native code are
unchanged, so existing sanitizer, four-profile/package, production Release-editor,
rendered and game/export evidence is reused within its documented scope.

Fresh main Windows/Linux core, native, declaration and project-analysis checks
are pending. Their actual run identities, results and native artifact summaries
will be recorded here; pending checks are not passing claims. No runtime fix or
additional qualification infrastructure is planned for this integration.

Core `43670569229` passes Windows/Linux at integrated revision `1fe0083`.
Index `43670569309` initially passes Windows/Linux Release but fails Linux ASan
during compiler provisioning: mirrors.edge.kernel.org times out fetching Ubuntu
packages (exit 100), before configuration/build/tests. The missing-artifact failure
is consequent to that provisioning failure. Only failed job `132679460150` is
retried, with source, assertions and toolchain policy unchanged. That failed
attempt remains part of the record; it is not a sanitizer/product test result.

## Completed main verification

All four workflows pass at `1fe0083286a3c79f9b4b9f23f8405c508c2e1db7`:

| Boundary | Run | Result |
| --- | --- | --- |
| Core | [43670569229](https://github.com/gmoddev/GodotLuau/actions/runs/43670569229) | Windows/Linux pass 87 original and eight debugger scenarios |
| Native | [43670569223](https://github.com/gmoddev/GodotLuau/actions/runs/43670569223) | Windows/Linux pass 141 actors each, seven debugger modes, 73 editor checks/reopen and Foundry/restart |
| Declarations | [43670569272](https://github.com/gmoddev/GodotLuau/actions/runs/43670569272) | Windows/Linux policy/generator/type checks pass |
| Project analysis | [43670569309](https://github.com/gmoddev/GodotLuau/actions/runs/43670569309) | Windows/Linux Release and Linux ASan/LSan pass; provisioning-only failed job retry recorded above |

The [integration receipt](evidence/gl067/main-integration.json) records actual
native product, companion and summary hashes and the expected source identity.
No product, fixture, assertion, dependency or host-policy correction was needed.
Closing documentation changes only Markdown/receipts; qualified source and
tested inputs remain unchanged and do not require redundant rebuilds.

## Preserved boundaries

Native remains the default Character controller and Scripted remains explicit
opt-in. Domain isolation, native storage/network authority, resource limits and
generation/lifetime rules are retained. The implemented phases are integrated;
the broader engine expansion remains open. Runtime module admission remains
64 paths/domain; full state migration, physical debugger reconnection, raw native
handles and broader AnimationTree authority remain outside this checkpoint.
GL-065, Windows LSan, Linux graphical and physical-input limitations remain
visible in the original qualification record.

The disabled release workflow and fail-closed runtime updater are byte-for-byte
unchanged from baseline. No release workflow, publication or updater distribution
is authorized or enabled by this merge.
