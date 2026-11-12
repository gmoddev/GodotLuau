# GL-053 native expansion qualification

Status: in progress. Branch `feature/gl-053-native-api-expansion` remains
unmerged. Main baseline is `16e8597cb342a1bbc888f190680c678ecf9ba055`.
The [journal](gl-053-native-development.md) preserves failed attempts and fixes;
the [API contract](gl-053-native-api.md) describes implemented bounds, not parity.

## Source and scope

Current native build fingerprint: `ce6e7638ae6386d6d4eef5d6df66962eb303e8f155d3c1616b0027bb9a5699c5`,
123 LF-normalized files. `e2735ec54012feb7c62032d50c87e325c6cf9dc4` introduces
the latest native implementation. Later fixture/docs corrections do not change
that fingerprint; their workflow identities still remain separate.

| Approved Scene surface | Integrated baseline | Current implementation |
| --- | ---: | ---: |
| Constructible classes | 48 | 94 |
| Property descriptors | 118 | 306 |
| Methods | 27 | 167 |
| Signals | 12 | 33 |
| Enum constants | 22 | 49 |

Counts describe approved entries, including inherited dispatch. They do not mean
complete class coverage. The pinned 4.3 metadata has 920 classes and 14,379
declared methods; the complete generated inventory retains unsupported and
restricted entries. Editor/runtime hosts remain 4.7.1 with unchanged pins.

## Established results

- Core run [43230722372](https://github.com/gmoddev/GodotLuau/actions/runs/43230722372)
  passes Windows/Linux at the current native implementation: 71 ordinary and 16
  isolated cases, including transitive module invalidation.
- Definitions run [43229476368](https://github.com/gmoddev/GodotLuau/actions/runs/43229476368)
  passes the unchanged current generated declarations on both platforms, actual
  approved calls, Relay Siege and the shipped 2D/3D factory type probes.
- Earlier native execution passes expansion headless checks, ten project-module
  revisions, nested/inherited scene binding cases and native animation. This is
  component evidence; the overall native run failed and is not qualified.
- Selected rendered expansion checks pass with the earlier `cb35958` Debug
  adapter on the verified official editor, normal exit. Current final rendering,
  gameplay and editor acceptance remain pending.

## Required remaining evidence

Fresh complete Windows/Linux native runs, full-native sanitizers, all four
production profiles and both extracted non-publishing packages remain pending.
Also pending: final rendered expansion and native acceptance play, interactive
editor/restart/export, production standalone startup, Relay Siege regressions,
and the repeated dispatch/conversion measurements after metadata indexing.
Reuse existing runners and unchanged evidence within their documented scope.

## Profile limits and deferred surface

| Area | Supported scope / retained limit |
| --- | --- |
| Navigation | Real path checks require the verified full-featured official host. Admitted GL-018/029 headless/renderer hosts omit navigation; they must reject unsynchronized calls. |
| Rendering | Headless dummy renderer cannot qualify MultiMesh state or shader uniforms. Exact renderer-backed checks remain separate. |
| Windows Debug rendering | Use the verified official editor. A Release renderer template paired with either retained baseline or campaign Debug adapters exits 0xC0000374 even for module-only controls. |
| Animation | Bounded sealed owned TYPE_VALUE clips and procedural skeleton poses. AnimationTree, rig/root motion, arbitrary tracks, native Tween/Callable remain unexposed. |
| Global engine access | No raw SceneTree, Window/Viewport construction, OS, arbitrary ClassDB, RID, server mutation, or privileged ProjectSettings authority. |
| Additional native families | Unreviewed tiles, CSG/joints/vehicles, low-level mesh/server operations, render textures and UI drag/drop are inventoried, not advertised as implemented. |
| Editor | Bounded syntax/metadata hints, source-local references and project import navigation. No full project semantic index, breakpoint suspension, stepping or local inspection. |
| Reload | Reverse dependency closure invalidates cached modules and retires callbacks. Returned values remain snapshots; no automatic runtime state migration or rollback to stale executable generations. |
| Devices/platforms | No Windows LSan, Linux graphical/device claim, or physical gamepad/mobile device claim. Preserve the existing admitted sanitizer limits. |

GL-050 remains separate and unresolved. Native remains the default Character
controller; Scripted remains explicit opt-in. No networking, persistence,
production release or updater authority changes are part of this campaign.
