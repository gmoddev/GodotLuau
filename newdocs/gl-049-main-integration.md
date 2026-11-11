# GL-049 native authoring main integration

On 2026-11-11, verified main `5d5bb84cfecfff46d7d5048db3171a199fd754be`
normally merges `feature/luau-native-authoring` at
`99fdfcfc0cdec6532c5b014bc6dbf3526af8dda7` through merge
`f11c4537bc705096c2872b209b805fbc2cb215ab`. Both refs were freshly fetched;
there were no newer remote commits. All 15 feature commits remain ancestors.
The two merge parents match those refs, and the merge tree exactly equals the
qualified feature tree `fec5e04fd8835a1de8784fc46ecf405af0788f8b`.
There are no conflicts or additional runtime changes.

The following documentation commit records integration; it does not change
native code, fixtures, gameplay or packaging behavior. The source branch and
its [qualification receipt](evidence/native-authoring/qualification-20261111.json)
are preserved. Historical unmerged/no-merge statements in the
[journal](native-authoring-development.md) describe the earlier campaign and are
superseded by this user-authorized integration.

## Reused exact-input qualification

The [API](native-scene-api.md), [ADR-014](adr-014-native-scene-authoring.md) and
[qualification record](native-authoring-qualification.md) retain the delivered
scope and limits. The 103-file native fingerprint remains
`350392bb4f5613a1722333e3de44f60adb9a4ac4b08ded4430a26a42e9f94b68`.
Both pinned dependencies remain unchanged. No persistence implementation,
admitted host, wire format, Character controller or authority change is added.

GitHub confirms these completed branch runs are successful:

- [Core 42999540021](https://github.com/gmoddev/GodotLuau/actions/runs/42999540021)
  and [native 42999540348](https://github.com/gmoddev/GodotLuau/actions/runs/42999540348)
  at `7f78ed4`: Windows/Linux, 85 core cases, 29 input graph assertions and
  141 native actors per platform within their respective suites.
- [Full-native sanitizers 42987292678](https://github.com/gmoddev/GodotLuau/actions/runs/42987292678)
  at `b6b21a0`: matching Windows ASan/Linux ASan-LSan, detection controls and
  85 core/141 native actors. Windows LSan remains unsupported.
- [Accepted native candidate 42987296894](https://github.com/gmoddev/GodotLuau/actions/runs/42987296894):
  Windows/Linux Debug/Release, policy/core sanitizer, both extracted-companion
  configurations per platform and aggregate acceptance pass.
- [Game package 43005466053](https://github.com/gmoddev/GodotLuau/actions/runs/43005466053)
  at `55a0c5f`: all 160 payload hashes verified, actual extracted startup passes
  with empty stderr. Windows native DLLs/companion are byte-identical to the
  retained rendered-game inputs.

Actual Windows gameplay retains 27 local, 55 listen and 57 dedicated checks,
plus recovery and menu teardown/reload. Native/fixture/gameplay inputs are
unchanged by integration, so those sessions and the expensive sanitizer and
candidate matrices are reused. No local engine build or game replay is needed
for this source-identical merge.

## Fresh integrated CI

Fresh Windows/Linux core and native CI will run on the pushed integrated
revision. Their results are pending at this preparation checkpoint and are not
counted as fresh passes. Final results will be recorded here after completion.

## Preserved limits and publication policy

Native remains the default Character controller; Scripted remains explicit
opt-in. The typed authoring API admits fixed native families. Trusted project
loading is synchronous and does not establish hostile-resource isolation or a
decoded-memory bound. Clone/save/reparent, arbitrary ClassDB/method dispatch,
automatic analyzer declarations and unsupported native families remain outside
the slice. Linux rendered gameplay, physical devices, OS capture and complete
rendered-game sanitizer coverage remain unqualified.

The original candidate failures are retained with their unproven cause, and
GL-050 remains a separate source-verified follow-up. No deadline or assertion is
weakened. Existing GL-017/018 engine/platform, asset provenance and distribution
limitations remain. Release jobs stay disabled with read-only permissions;
runtime updater admission remains fail-closed. No publication workflow is
dispatched and no upstream changes are made.
