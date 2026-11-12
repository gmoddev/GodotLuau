# GL-053 native expansion qualification

Status: in progress. Branch `feature/gl-053-native-api-expansion` remains
unmerged. Main baseline is `16e8597cb342a1bbc888f190680c678ecf9ba055`.
The [journal](gl-053-native-development.md) preserves failed attempts and fixes;
the [API contract](gl-053-native-api.md) describes implemented bounds, not parity.

## Source and scope

Current native build fingerprint: `685cbd6a9978bea0516265967c5ffc4da22f67fda438d39f5735aeed76481149`,
123 LF-normalized files. The descriptor/effect follow-up changes the preceding
`e2735ec54012feb7c62032d50c87e325c6cf9dc4` fingerprint
`ce6e7638ae6386d6d4eef5d6df66962eb303e8f155d3c1616b0027bb9a5699c5`.
Preceding component evidence is retained with its actual identity.

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

- Core run [43234499930](https://github.com/gmoddev/GodotLuau/actions/runs/43234499930)
  passes Windows/Linux at the current native implementation: 71 ordinary and 16
  isolated cases, including transitive module invalidation.
- Definitions run [43233643869](https://github.com/gmoddev/GodotLuau/actions/runs/43233643869)
  passes the unchanged current generated declarations on both platforms, actual
  approved calls, Relay Siege and the shipped 2D/3D factory type probes.
- Earlier native execution passes expansion headless checks, ten project-module
  revisions, nested/inherited scene binding cases and native animation. This is
  component evidence; the overall native run failed and is not qualified.
- The `e2735ec` Debug adapter passes actual native pathfinding, rendered expansion
  and all shipped 2D/UI/3D gameplay logic on the verified official Windows host,
  exiting normally. Headless native editor creation/preview/save/reopen passes.
  Retained logs: `gl053-native-20261112/e273-components-2` and `e273-editor`.
  These precede the descriptor/effect optimization and do not qualify that change.
- Rendered viewport captures of the actual shipped scenes pass visual inspection
  at 960x640 and 1280x800 with `e2735ec`; native UI keyboard focus/slider changes
  pass. This is automated rendered game evidence, not interactive editor evidence.

## Required remaining evidence

Fresh complete Windows/Linux native runs, full-native sanitizers, all four
production profiles and both extracted non-publishing packages remain pending.
Also pending: final rendered expansion and native acceptance play, interactive
editor/restart/export, production standalone startup, Relay Siege regressions,
and the repeated dispatch/conversion measurements after metadata indexing.
Reuse existing runners and unchanged evidence within their documented scope.
Native [43234500028](https://github.com/gmoddev/GodotLuau/actions/runs/43234500028),
sanitizer [43234536332](https://github.com/gmoddev/GodotLuau/actions/runs/43234536332)
and candidate [43234541985](https://github.com/gmoddev/GodotLuau/actions/runs/43234541985)
are the current in-flight `3a5adb6` cohort.

Interactive editor access is currently blocked: black capture and repeated
`GetCursorPos: Access is denied (0x80070005)`. The task-owned editor was stopped;
no interactive pass or normal-exit claim is made from that attempt. Continue
independent qualification; retain this gap if desktop access remains unavailable.

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
