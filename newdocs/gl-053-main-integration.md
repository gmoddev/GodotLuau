# GL-053 native expansion main integration

Status: **INTEGRATED AND VERIFIED WITH RETAINED LIMITATIONS**.

Merge `47bbb6d05e8e71c5042dcb22370f7815d3cfda95` has parents
`16e8597cb342a1bbc888f190680c678ecf9ba055` (verified main) and
`3e40b95a489fa78bcfe8674542adcd30e8136447` (completed feature tip).
All 30 feature commits remain ancestors, with no conflicts or history rewriting.
The merge tree exactly equals feature tree
`7acb85c26d58fe5627cb7730060c51bf431771c7`. Following integration notes change
documentation only. The [integration receipt](evidence/gl053-native/main-integration-20261112.json)
preserves the complete commit list and evidence identities.

The owner authorizes a normal merge preserving all feature commits, followed by
fresh main CI. Releases and updater distribution remain disabled. Historical
no-merge statements in the [journal](gl-053-native-development.md) describe the
earlier authorization boundary.

## Source and evidence

Runtime implementation `0af6e4d66908f6ab4dade30a4290455f982c5b4a` has native
fingerprint `fda36b81c44f8dc11a2c3b52d17687fbda78b5b2f911ea230fd544a54e6b1cb2`
(123 LF-normalized inputs). Qualification revision
`bb15aab1e47c22e63199909049fa19dfbe7b522e` corrects one test-only root argument
and documentation; native products are unchanged. Dependency pins, admitted
hosts, Character V2, networking, default Native controller and explicit Scripted
opt-in remain intact.

The [qualification record](gl-053-native-qualification.md) and
[final correction receipt](evidence/gl053-native/final-corrections-20261112.json)
separate source identities, performance measurements, controlled GL-050
before/after evidence, actual Windows interaction and final automated editor
reopening. The [preceding receipt](evidence/gl053-native/qualification-20261112.json)
remains unchanged with its own accepted packages and retained failures. Earlier
rendered/export/game evidence is reused only for unchanged behavior within its
documented scope. No old archive is relabeled as a new main build.

Corrections are bounded: live-type property descriptor lookup, one Assignment
batch per write, helper exit snapshot before draining, ASCII UI status separators
and the Linux fixture's root input. No new dependency, storage protocol, scheduler,
replication authority or controller design is introduced.

## Hosted qualification

- Core 43346809940 passes Windows/Linux.
- Native 43346810000 passes Windows/Linux: 141 actors per platform and the
  existing editor, authoring, fresh-process reopen and actual pathfinding checks.
- Full-native sanitizers 43346827388 pass Windows/Linux: 26/27 stages,
  detection controls, 87 core cases, 141 native actors and no unexpected reports.
  Preserve existing Windows LSan and admitted-host limitations.
- Candidate 43346831705 passes all four Windows/Linux Debug/Release source-built
  profiles and core sanitizer/policy/retention gates. Its original package startup
  failures are preserved: production libraries correctly exclude the private
  test method that the shared fixture incorrectly required.
- [Repackage 43355306613](https://github.com/gmoddev/GodotLuau/actions/runs/43355306613)
  reuses the exact qualified products with the reviewed checker repair at
  `2d8b16f`. Both strict archives, all extracted Debug/Release startups and final
  acceptance pass. No runtime or dependency change accompanies the repair.
- Declarations 43342974114 pass the unchanged policy/type-fixture inputs.

The failed Linux sanitizer attempt 43343586993 is preserved. Its new fixture
supplied a trailing root separator rejected by the confined Linux opener; its
controls pass, no unexpected sanitizer reports exist and close-save contains
`99`. The correction changes the fixture input, preserving native confinement.
Older indeterminate close-save observations remain separate from GL-050's
controlled receive/exit defect.

## Integration and post-merge verification

All pre-merge gates are established and exact-tree/history checks pass.
The normal merge and initial documentation notes are pushed to main at
`502bcbe495a07ca2419e78761963731a8fb2a54c`, verified against the remote ref.
Fresh core [43356044244](https://github.com/gmoddev/GodotLuau/actions/runs/43356044244)
passes Windows/Linux. Declarations
[43356044238](https://github.com/gmoddev/GodotLuau/actions/runs/43356044238) also
pass both platforms. Native
[43356044217](https://github.com/gmoddev/GodotLuau/actions/runs/43356044217) passes
Windows/Linux with 141 required actors each, the expected native fingerprint and
the controlled GL-050 marker. Native editor, authoring, fresh-process reopen,
official-host pathfinding, authority, lifetime, persistence fault/recovery and
controller checks pass. All three workflows identify that exact main revision.
Closing integration notes change documentation only; native and fixture inputs
remain those tested at `502bcbe`. The still-running source-branch native
run 43355305605 was superseded by fresh main CI with identical runtime/fixture
inputs; no failed result was hidden or retried.
The feature/native/sanitizer/candidate receipts remain unchanged. No release
workflow or updater channel is enabled. Native stays the default Character
controller; Scripted remains explicit opt-in.

Retained limits remain explicit: no Windows LSan or Linux graphical/device claim,
no broad Godot API parity/full debugger claim, and no admission of navigation on
the reduced headless/renderer hosts. Neither earlier failed attempts nor qualified
archives are relabeled. Main and source-branch receipts retain their own identities.
