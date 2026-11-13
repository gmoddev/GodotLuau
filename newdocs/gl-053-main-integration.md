# GL-053 native expansion main integration

Status: pre-merge; final hosted qualification is running. Main remains
`16e8597cb342a1bbc888f190680c678ecf9ba055`.

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
- Non-publishing candidate 43346831705 is pending.
- Declarations 43342974114 pass the unchanged policy/type-fixture inputs.

The failed Linux sanitizer attempt 43343586993 is preserved. Its new fixture
supplied a trailing root separator rejected by the confined Linux opener; its
controls pass, no unexpected sanitizer reports exist and close-save contains
`99`. The correction changes the fixture input, preserving native confinement.
Older indeterminate close-save observations remain separate from GL-050's
controlled receive/exit defect.

## Integration and post-merge verification

Pending the final platform/package results. Preserve a merge tree equal to the
completed feature tree and verify fresh core/native/declarations against the
integrated main revision. No release workflow or updater channel is enabled.
