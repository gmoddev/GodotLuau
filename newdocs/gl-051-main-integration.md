# GL-051 main integration

On 2026-11-11, the owner authorized normal integration of qualified
`feature/gl-051-first-class-luau`, preserving its commits and evidence.
Freshly fetched main `c60919a42416d5e6c72d2b23f7801500879c3195` merges source
`2307c043581e4f6dd785226a8926936ef102aff8` through normal merge
`11be0e8f6d5f1d1e2a0f8fb8ad70d74faba151d7`.

The merge parents match those two revisions. All 22 feature commits remain
ancestors, and the merge tree exactly equals the qualified source tree
`8a12d2c7d02fb0d3238216c5b314913f13397356`. There are no conflicts or runtime
corrections. Following integration commits update documentation only.
The source branch and original [qualification receipt](evidence/gl051/qualification-20261111.json)
are preserved unchanged. Historical unmerged/no-merge statements in the
[campaign journal](gl-051-development.md) describe the earlier authorization
boundary and are superseded by this explicit integration request.

## Qualification reused for unchanged inputs

The [API](gl-051-native-api.md), [ADR-015](adr-015-policy-driven-native-bindings.md)
and [qualification record](gl-051-qualification.md) retain supported behavior,
failed attempts and limitations. The 114-file native fingerprint remains
`728d0c69fb1f717448897166514b500ee097c50815c777e574fdc866f2d2b5dc`.
Both dependency pins, fixtures, gameplay, build policy and admitted hosts remain
unchanged by integration. GitHub confirms all retained workflows are successful:

- [Core 43063379932](https://github.com/gmoddev/GodotLuau/actions/runs/43063379932)
  and [native 43063379869](https://github.com/gmoddev/GodotLuau/actions/runs/43063379869):
  Windows/Linux core/native, including 141 native actors and 19 actual editor
  checks per platform.
- [Definitions 43050098215](https://github.com/gmoddev/GodotLuau/actions/runs/43050098215):
  generated definitions, eleven representative programs, actual RelayFactory
  and nine policy tests on Windows/Linux.
- [Full-native sanitizers 43066333042](https://github.com/gmoddev/GodotLuau/actions/runs/43066333042):
  matching Windows ASan / Linux ASan-LSan, 1168 instrumented translation units,
  all detection controls, 85 core cases and 141 native actors per platform.
- [Accepted candidate 43063482878](https://github.com/gmoddev/GodotLuau/actions/runs/43063482878):
  all ten jobs pass, including four source-built production Debug/Release profiles,
  19 actual editor checks per profile and both platforms' extracted-companion
  Debug/Release startup checks.
- [Game package 43073257426](https://github.com/gmoddev/GodotLuau/actions/runs/43073257426):
  final candidate identity matches, all 167 payload hashes verify and actual
  extracted-game startup passes with empty stderr.

Retained Windows solo/recovery/menu/listen/dedicated gameplay totals 151 passing
checks across twelve actors. Its documented reuse covers unchanged game/binding
inputs, with later editor corrections qualified separately. Integration changes
none of those inputs. Existing sanitizer, candidate, package and rendered results
are reused; no repeated expensive matrix or local engine build is required.
Retained packages keep their recorded source identities; they are not represented
as newly built main archives. Integration edits change documentation only.

## Fresh integrated CI

Status: **INTEGRATED AND VERIFIED WITH RETAINED LIMITATIONS**, testing main revision
`397dde847b736d8d14ea222754124c44dde2d38d` after the normal merge and initial
integration notes.

- [Core 43112156523](https://github.com/gmoddev/GodotLuau/actions/runs/43112156523):
  Windows/Linux pass. Both downloaded discovery/XML artifacts pass the existing
  CheckCoreCI checks for all 85 distinct cases; input logs pass 29 assertions each.
- [Native 43112156884](https://github.com/gmoddev/GodotLuau/actions/runs/43112156884):
  Windows/Linux each pass all 141 actors and 19 actual editor checks. Both
  downloaded summaries identify `397dde8` and the unchanged native fingerprint.
  All 424 Windows / 420 Linux native log hashes verify, expanded bindings report
  PASS and both actual editors shut down without unhandled errors.
- [Definitions 43112156562](https://github.com/gmoddev/GodotLuau/actions/runs/43112156562):
  Windows/Linux pass all eleven representative programs and the production
  RelayFactory module. Both downloaded definitions/catalogs match main.

The [main integration receipt](evidence/gl051/main-integration-20261111.json)
records exact merge parents/tree, all 22 preserved commits, original evidence
identity and fresh results/hashes. Optional benchmark export is correctly skipped
because it was not requested. No runtime correction, CI retry, assertion change,
deadline change or additional qualification layer was needed.

All commits after the merge update documentation only, including the staged
game's qualification/API guidance. Runtime, fixture, gameplay and build inputs
remain identical to tested main `397dde8`; closing documentation does not require
another native, sanitizer, candidate or gameplay replay. The source branch stays
at `2307c043581e4f6dd785226a8926936ef102aff8`.

## Preserved limits and distribution policy

Native remains the default Character controller; Scripted remains opt-in.
GL-049 ownership, execution domains, native network/health/animation authority
and persistence are preserved. GL-050 remains separately recorded and unfixed.

Loading remains synchronous trusted project loading; encoded-size bounds do
not isolate hostile resources or bound all decoded/dependency costs. Nested or
inherited PackedScenes, live-scope serialization and asynchronous loading are
not admitted. Editor inference does not provide a full embedded type checker,
debugger or navigation system. Linux rendered gameplay and physical devices
remain unqualified; Windows LSan remains unsupported. Other existing project
findings and admitted-host limitations retain their original scope.

Release jobs remain explicitly disabled with read-only permissions. Runtime
updater admission remains fail-closed. No publishing workflow, dependency change,
admitted-host change or upstream modification is part of this integration.
