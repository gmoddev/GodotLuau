# GL-052 main integration

On 2026-11-12, the owner authorized a normal merge of qualified
`feature/gl-052-luau-authoring-workflow` into main, preserving every commit and
keeping releases and updater distribution disabled.

Normal merge `8a374060f03d069705f8c8b732621e63c4254ce5` has parents
`e43e981d423cea99edff9eb9d186a0b9a4758b73` (verified main) and
`9e285920c58479d52f2cf2ba3a09da6816720da1` (qualified feature tip).
All 25 feature commits remain ancestors. The merge tree exactly equals the
qualified source tree `f93bee9d1eb7f36627cade8fb250c94daee99480`.
There are no conflicts or runtime corrections. Following integration commits
update documentation only. The retained source branch is unchanged.

The [integration receipt](evidence/gl052-main-integration-20261112.json) records
parents, preserved commits, native identity and original evidence hashes.
Historical no-merge statements in the [development journal](gl-052-development.md)
describe the earlier authorization boundary and are superseded by this request.
The original branch qualification JSON receipts and ADR-016 remain unchanged.

## Qualification reused

The 121-file native fingerprint remains
`140406f7ae825ba24e3400779c8ed5a016fc42fc1f9a68f374f23d2dedd96fd1`
with compiler-equivalent LF normalization. Dependency pins, native code, fixture
inputs, gameplay, approved bindings, admitted hosts and build policy are unchanged
by integration. The [qualification record](gl-052-qualification.md) retains exact
cohort identities, failures and limitations:

- [Core 43188368995](https://github.com/gmoddev/GodotLuau/actions/runs/43188368995)
  and [native 43188368944](https://github.com/gmoddev/GodotLuau/actions/runs/43188368944)
  pass Windows/Linux at implementation `71e997b`. Native qualification includes
  141 runtime actors, 19 inherited editor checks, 37 authoring checks, seven
  fresh-process reopen checks and 13 game checks per platform. Default-script
  authority regressions pass; all 17 shipped informational `dprint` calls use
  ordinary `print` in disk and embedded templates.
- [Accepted candidate 43188370124](https://github.com/gmoddev/GodotLuau/actions/runs/43188370124)
  passes all four source-built production profiles, both strict packages and
  extracted companion startup. [Game/export 43196708702](https://github.com/gmoddev/GodotLuau/actions/runs/43196708702)
  passes Relay Siege extracted startup and Orb Run native export/independent
  startup. Emitted library/companion identities match the accepted candidate.
- [Full-native sanitizers 43154353439](https://github.com/gmoddev/GodotLuau/actions/runs/43154353439)
  pass Windows/Linux at `60913fb`, with 26/27 stages and zero unexpected reports.
  The later print-only template change preserves native output, authoring,
  ownership and authority implementation; its reuse boundary is unchanged.
- The [interactive receipt](evidence/gl052-interactive-qualification.json)
  preserves actual Windows creation/edit/preview/Inspector/error recovery,
  snapshot edit/save/fresh-process reopen, UI Release export and independent
  rendered standalone launch at the recorded 60913fb products. The fresh editor
  and standalone exit 0. Earlier desktop failures remain historical evidence.
- Generated declarations and rendered Orb Run / Relay Siege solo, recovery,
  menu, listen and dedicated evidence retain their documented unchanged-input
  reuse scope. Integration does not require another expensive production,
  sanitizer or graphical campaign.

Retained archives keep their original source identities. They are not newly
built main archives. No new package, release or updater channel is introduced.

## Fresh integrated CI

Status: **source integrated; fresh main CI pending** at this checkpoint.

Push the normal merge and integration notes to main, verify the remote revision,
and require fresh Windows/Linux core/native CI. Run the existing generated-binding
workflow on the same revision. Record final results and relevant artifacts here;
retry only for an actual diagnosed failure. Documentation-only closing commits
do not require repeating those unchanged runtime inputs.

## Preserved contracts and limitations

[ADR-016](adr-016-luau-editor-authoring.md), existing execution domains/quotas,
owner-aware lifetime retirement and native storage/network/health/animation
authority remain intact. Native remains the default Character controller;
Scripted remains explicit opt-in. GL-053's default damage example correction is
integrated within its existing template-only scope; customized scripts require
the documented review. GL-050 remains separately unresolved.

Fast-import and mismatched Debug-extension/Release-host profiles remain
unqualified. Breakpoint/step debugging, a full embedded type checker, arbitrary
ScriptInstance attachment, file inheritance, complete navigation, theme-aware
palettes and automatic editor-to-child hot reload are not implemented. Linux
graphics/physical devices and editor/rendering sanitizer execution are not claimed;
Windows LSan remains unsupported. Trusted project loading is not hostile-resource
isolation. The authoring/API guides retain their precise supported boundaries.

Both publication jobs remain explicitly disabled with read-only permissions.
Runtime updater admission remains fail-closed. No dependency, admitted-host,
publication-policy or unrelated repository changes are included.
