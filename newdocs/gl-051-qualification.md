# GL-051 qualification

Status: **qualified within the recorded scope; normally integrated into main**.
The [integration record](gl-051-main-integration.md) separates retained branch
evidence from fresh main CI. The original
[versioned receipt](evidence/gl051/qualification-20261111.json)
records immutable sources, CI outcomes, package and retained evidence hashes. The
[journal](gl-051-development.md) preserves implementation and failed attempts;
[ADR-015](adr-015-policy-driven-native-bindings.md) and the
[API guide](gl-051-native-api.md) define supported behavior. No release or updater
distribution is authorized.

## Source identities

Baseline remote main: `c60919a42416d5e6c72d2b23f7801500879c3195`.
Branch: `feature/gl-051-first-class-luau`.
Final implementation/candidate revision: `5f876d3705d2506c6e243cd72a0f27a224fc3785`,
tree `692d059c2ed48a75e795376e4b8563eb56770410`. Subsequent campaign commits
only document qualification; they do not change native or fixture inputs.

| Input | Identity |
| --- | --- |
| Policy | `8322ba0504ed0b2f4d45a5d89b87ef20ba65e154bbb79b7bf898dfee5607585f` |
| Pinned extension API, LF SHA256 | `dfd54f071d53ef63d9c1be51150b38f5c55abdd68eb8b2caa357abeab4086a0f` |
| First sanitizer-qualified native input set, `6a04029` | `1555b83381465ae18844c0de09f40484d924cf1d13fbf2fb8fc3581b5a3495a0`, 112 files |
| Next sanitizer-qualified set, `a276111` / `358d613` | `e855b3faeac811a7c276cd2c73255816b13efb89b4dbe18542145a919752d108`, 112 files |
| Current native input set, `5f876d3` | `728d0c69fb1f717448897166514b500ee097c50815c777e574fdc866f2d2b5dc`, 114 files |

The later native differences correct editor completion fields/status, required
metadata hooks, UTF-8 classification and icon shutdown lifetime, and add the
editor-only colon-prefix plugin. They are not relabeled as part of the earlier
sanitizer product. Dependency pins and admitted engine profiles remain
unchanged. The pinned API describes Godot 4.3; runtime/editor hosts remain 4.7.1.

## Established outcomes

| Evidence | Actual outcome |
| --- | --- |
| [Core 43063379932](https://github.com/gmoddev/GodotLuau/actions/runs/43063379932), `5f876d3` | Windows/Linux Debug pass: 85 core cases and 29 input assertions. |
| [Definitions 43050098215](https://github.com/gmoddev/GodotLuau/actions/runs/43050098215), `2b2aab4` | Windows/Linux pinned Luau checker loads generated definitions, passes eleven positive/negative cases and the actual RelayFactory module; nine policy tests pass. Downloaded declarations/catalog match the branch. |
| [Initial native 43049375469](https://github.com/gmoddev/GodotLuau/actions/runs/43049375469), `6a04029` | Linux extension compiles and initial binding/lifecycle stage passes. Full job fails at the actual editor fixture; this is partial evidence, not a full native pass. |
| [Current native 43063379869](https://github.com/gmoddev/GodotLuau/actions/runs/43063379869), `5f876d3` | Windows/Linux Debug each pass all 141 native actors and 19 actual editor checks. All 425 Windows / 420 Linux native log hashes verify, source is the current 728d/114-file set, and both editors have no unhandled errors. |
| [Full-native sanitizers 43049541634](https://github.com/gmoddev/GodotLuau/actions/runs/43049541634), `6a04029` | Windows ASan and Linux ASan/LSan pass: controls, reload/lifetime, 85 core cases and 141 native actors per platform, including expanded binding cases. No unexpected sanitizer reports. |
| [Candidate 43049547160](https://github.com/gmoddev/GodotLuau/actions/runs/43049547160), `6a04029` | Accepted non-publishing candidate: Windows/Linux Debug/Release source profiles, policy/core sanitizer, both extracted-companion profiles per platform and aggregate acceptance pass. Downloaded Windows package/startup hashes and aggregate CheckJobs verify. |
| [Full-native sanitizers 43055223210](https://github.com/gmoddev/GodotLuau/actions/runs/43055223210), `358d613` | Windows/Linux pass at the e855 native inputs. All 679/684 retained file hashes verify, all 25/26 stages pass and no unexpected reports occur; this does not include subsequent editor fixes/plugin. |
| [Final full-native sanitizers 43066333042](https://github.com/gmoddev/GodotLuau/actions/runs/43066333042), `d4d8711` | Windows ASan / Linux ASan-LSan pass at the final 728d inputs: 1168 instrumented translation units, 25/26 stages, all detection controls, 85 core cases and 141 native actors per platform, no unexpected reports. All 680/684 retained file hashes verify. |
| [Final candidate 43063482878](https://github.com/gmoddev/GodotLuau/actions/runs/43063482878), `5f876d3` | Accepted: all ten jobs pass, including four production Debug/Release profiles, core sanitizer, rejection/retention checks, both extracted packages and aggregate acceptance. All four production libraries also pass 19 actual editor checks each. Both downloaded packages pass CheckPackage; aggregate acceptance passes CheckJobs. |
| [Final game package 43073257426](https://github.com/gmoddev/GodotLuau/actions/runs/43073257426), `94de286` | Current native inputs match the accepted candidate. Extracted self-contained Relay Siege startup passes with empty stderr; all 167 archived payload hashes verify, including all three candidate native products. |

The earlier sanitizer records verify 1167 instrumented translation units, 25 Windows /
26 Linux stages and actual expanded-binding PASS markers. All 679 Windows / 685
Linux retained file hashes verify without mismatches. One transient filesystem
messaging JSON from each snapshot manifest is absent from the upload; required
logs, identities and qualification records are retained. This cache artifact is
not an added qualification gate.

Actual native assertions exercise texture/font/material reuse, metadata/enums,
typed native methods/defaults and signals, immutable handles, PackedScene
preflight, node/depth budgets, clone/reparent, wrong owner/domain rejection,
yielded callback retirement and stale handles. Existing GL-049 reload/destruction
coverage remains intact. Source inspection alone is not claimed as a crash
reproduction or graphical qualification.

## Final candidate and editor outcomes

The older ordinary native run at `a276111` failed Linux provisioning before
compilation and failed Windows editor completion. The journal preserves both
failures and their corrections; the current native run passes both platforms.

Candidate `43053904413` at `358d613` fails at real-editor completion. Its retained
products enable focused diagnosis; they are not accepted as a complete candidate.
The final candidate at `5f876d3` retains all existing gates and the production
editor check, and is accepted. Ordinary
[native CI 43063379869](https://github.com/gmoddev/GodotLuau/actions/runs/43063379869)
passes those corrected editor inputs on both platforms. The native and candidate
artifacts match the current 728d/114-file native fingerprint.

The final sanitizer cohort at documentation tip `d4d8711` passes and verifies
the current native/fixture inputs on both platforms. Its extra instrumented
translation unit is the new editor plugin. All Windows manifest files are retained;
Linux omits one disposable GL-003 messaging JSON, as in earlier uploads, with no
missing required evidence. All four Windows/Linux production Debug/Release
profiles pass, including all 19 actual editor checks against each SCons library.
Final candidate and game package acceptance are complete.

The real editor fixture loads a `.lua` resource, shares production diagnostics
cases and requests completion through Godot CodeEdit/ScriptLanguage. Its first
failure exposed a fixture root-selection error and inherited missing required
metadata hooks; both are corrected. Native/legacy completion results also now
follow the exact admitted Godot adapter contract. Actual UI completion passes on
both platforms at the corrected inputs. Follow-up fixes remove Debug
CRT assertions on signed UTF-8 cursor bytes and the legacy static icon's renderer
shutdown diagnostic. A small editor-only plugin adds Godot's missing colon
completion prefix through public APIs for Luau tabs. A manual diagnostic prefix
experiment proves attribution, not final automatic-plugin qualification.
Both current executions verify automatic colon configuration, native and
legacy completion, GDScript-tab isolation and clean editor shutdown.

## Actual rendered Relay Siege

The accepted `6a04029` Windows runtime, unchanged admitted renderer SHA256
`09130cf169b0904be4f0f4cc566aaa58519553dcc1ca1a4563999553c3dd0ebc`
and existing verified R6 bundle run the actual migrated game on MainPC. DockerPC
remains leased by another task at the 16:18 UTC admission check. Processes use
the existing bounded offscreen/no-focus drivers and isolated data roots.

| Workload | Outcome |
| --- | --- |
| Solo | 27 checks, zero failures; victory, save, another round, input cleanup and rendered screenshot |
| Fresh-process recovery | Seven checks, zero failures |
| Menu/retry/teardown | Five checks, zero failures |
| Four-player listen | Leader 28 checks plus three observers with nine each; zero failures, late join included |
| Dedicated with four rendered clients | Server two checks, leader 28 plus three observers with nine each; zero failures |

Solo records 65.482 seconds, 1883 frames, 33.476 ms mean, 150 ms peak and 175
nodes at the reporting point. The retained GL-049 reference is 33.489 ms mean,
144.856 ms peak and 170 nodes with the same 30 FPS cap. These comparable samples
do not establish a speed improvement or isolated per-call costs. The five extra
nodes correspond to relay composition roots, module and texture control.
The captured victory frame was visually inspected. A fresh non-publishing archive
using those inputs verifies all 166 payload hashes after extraction, including
factory, scene, texture and generated declarations; independent headless solo
startup passes. These rendered results qualify the recorded runtime/game inputs.
The six later native file changes are editor-only; scene bindings, gameplay and
the expanded binding fixture are unchanged. Their final native/sanitizer/editor
cohorts pass separately. Final current-product game package/startup also passes
at `94de286`, with 167 payload hashes verified and the same admitted renderer.
Its Windows Release extension SHA256 is
`beca43a24d214c3ba92a69f71c4dc66361e1a02ba83e47ab2d7a2a0635e8a645`;
the archive SHA256 is
`d7c4225f2aad0523620bfee3834e8140e490630608e29d2229ed13754164f6d5`.
The receipt records both input sets instead of relabeling rendered runs as fresh
executions of later binaries. No new regression is observed in these profiles.

## Delivery disposition

The registry, native dispatch/ownership, composition/resources, generated types,
editor completion/diagnostics and representative Relay Siege migration are
implemented and qualified within this record. At the branch qualification
checkpoint, the feature was pushed unmerged and main remained
`c60919a42416d5e6c72d2b23f7801500879c3195`. The later authorized
[normal integration](gl-051-main-integration.md) supersedes that disposition and
preserves the original receipt. Release/updater code, dependency pins
and admitted hosts are unchanged. Native remains the default controller and
Scripted remains explicit opt-in. No task-owned game or editor process remains.

## Remaining scope limits

- Native scene inheritance/nesting, live-scope saving and async loading are not
  admitted. Factories and preflighted flat PackedScenes are the supported reuse.
- Loading trusts project resources; top-level encoded bounds do not bound decoded
  assets/dependencies or provide hostile-resource isolation.
- Editor analysis is bounded native inference, not a complete embedded type
  checker, debugger or navigation system. External definitions cover Scene,
  rather than every inherited Roblox compatibility global.
- Windows LSan remains unsupported. Linux rendered play and physical devices
  are not qualified by headless/native tests or Windows rendering.
- GL-050 remains separate and unfixed. Character/controller, network, persistence
  and release/updater authority contracts are preserved.
