# GL-053 native expansion qualification

Status: supported native/headless/rendered/export scope qualified; interactive
editor acceptance blocked by desktop access. Branch `feature/gl-053-native-api-expansion` remains
unmerged. Main baseline is `16e8597cb342a1bbc888f190680c678ecf9ba055`.
The [journal](gl-053-native-development.md) preserves failed attempts and fixes;
the [API contract](gl-053-native-api.md) describes implemented bounds, not parity.
The [versioned receipt](evidence/gl053-native/qualification-20261112.json)
retains source/package identities, current measurements and application evidence.

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

- Core run [43236560018](https://github.com/gmoddev/GodotLuau/actions/runs/43236560018)
  passes Windows/Linux at the current native implementation: 71 ordinary and 16
  isolated cases, including transitive module invalidation.
- Definitions run [43249386432](https://github.com/gmoddev/GodotLuau/actions/runs/43249386432)
  passes the unchanged current generated declarations on both platforms, actual
  approved calls, Relay Siege and the shipped 2D/3D factory type probes.
- Native run [43236559864](https://github.com/gmoddev/GodotLuau/actions/runs/43236559864)
  passes all 141 required actors on Windows/Linux, plus native editor workflows
  and actual pathfinding on the verified official host at current source `b9123fa`.
  Earlier run 43234500028 also passes at `3a5adb6`, which has the same native
  implementation and executable fixture cases.
- Windows full-native ASan passes in attempt 1 of
  [43234536332](https://github.com/gmoddev/GodotLuau/actions/runs/43234536332):
  detection controls, lifecycle/reload, 87 core cases and 141 native actors,
  with no unexpected reports. Linux's first attempt fails an unchanged
  DataStore BindToClose write with an indeterminate outcome, with no unexpected
  sanitizer reports. The single failed-job-only fresh-runner retry passes the
  complete Linux ASan/LSan profile, including close-save value 99. Both platforms
  pass detection controls, 87 core cases and 141 native actors. Keep the initial
  functional failure; neither the retry nor this campaign resolves GL-050.
- The current `3a5adb6` Debug adapter passes actual native pathfinding, rendered expansion
  and all shipped 2D/UI/3D gameplay logic on the verified official Windows host,
  exiting normally. Headless native editor creation/preview/save/reopen passes.
  Retained logs: `gl053-native-20261112/3a-components-final` and `3a-editor`.
- Rendered viewport captures of the actual shipped scenes pass visual inspection
  at 960x640 and 1280x800 with `3a5adb6`; native UI keyboard focus/slider changes
  pass. This is automated rendered game evidence, not interactive editor evidence.

## Production and application acceptance

Corrected candidate
[43236570162](https://github.com/gmoddev/GodotLuau/actions/runs/43236570162)
uses immutable `b9123fa`, correcting consumed-file receipt identity only; native
implementation and executable fixture cases remain identical to `3a5adb6`.
All four Windows/Linux Debug/Release profiles, production core ASan/LSan,
retention/rejection checks, both strict packages and extracted companion startup
pass. The final receipt is ACCEPTED_NONPUBLISHING_CANDIDATE. The earlier candidate
was cancelled on the concrete receipt mismatch, not accepted or silently relabeled.

Windows archive SHA256: `60339f20925f2e148bbc9d8fb665bb595c211097b9b85f1d9cf47b4491d9d4c1`.
Linux archive SHA256: `74493783968bf0eb70bdf7538f475c1ab97259a596525b3d0e3824121db812f4`.

Native2D, Native3D and UI stage from that accepted engine, export through the
verified official editor, and start independently with matching emitted DLL and
companion. All exit zero without workflow errors. Their actual Windows Release
standalone applications also render 30 recorded frames each on the existing
admitted renderer host; inspected frames show sprites, materials/instancing,
animation and themed native controls. This is automated rendered/export evidence,
not interactive editor acceptance. Admitted-host navigation limits still apply.

The application-only `4ff0ab4` follow-up makes the 2D sprite visibly alternate
between two original gradient textures. Native build/declaration/package inputs
remain unchanged. Fresh focused actual-input gameplay, distinct native texture
assertion, Release export/startup/render and Windows/Linux factory type checks
pass. Its application staging hashes are separate from the accepted engine's
older executable fixture inputs; those full-matrix receipts are not relabeled.

The unchanged Relay Siege workload passes fresh rendered solo gameplay (27
checks), fresh-process recovery of acknowledged career data, four-player
listen-host and dedicated-server sessions, including late join, authority
rejection, death/respawn, round transitions and persistence. Solo records 65.253 s,
1,873 frames, 33.469 ms mean, 150 ms peak and 175 native nodes at the existing
30 FPS cap. These are representative observations, not an isolated speedup.

## Remaining integration gap

## Performance observations

The same seven-trial Windows Debug fixture (first trial excluded) measures
10,000 Position set/read pairs: retained `60913fb` baseline 42.873 ms, first
expansion 76.257 ms, metadata index alone 77.203 ms, final descriptor/effect
follow-up 66.921 ms. The last change reduces these observed times by 13.3%, but
remains 56.1% above the retained baseline. This is a known Debug dispatch cost;
no production performance improvement is claimed. Baseline binding/API paths
are unchanged between `60913fb` and integrated baseline `16e8597`.
Final 64-node construction is 0.772 ms; 2,000 new Transform3D roundtrips are
11.340 ms. Raw samples/binary/fixture hashes are retained in binding-measurements.json.

A bounded 100-revision native project reload observation has a 6.896 ms median,
6.922 ms maximum observed iteration, including frame/task scheduling. All stale
callbacks remain cancelled and unrelated imports remain cached. Native static
memory changes from 28,159,274 to 28,237,694 bytes and objects from 1,501 to 1,503.
Observed Lua heap changes from 492 to 895 KiB with natural GC; no forced collection
or memory improvement/leak-free claim is made. Current foundation previews have
24–27 nodes and observed preview times of 6.8–14.8 ms, excluding later save/reopen.

Interactive editor access is currently blocked: black capture and repeated
`GetCursorPos: Access is denied (0x80070005)`. The task-owned editor was stopped;
no interactive pass or normal-exit claim is made from that attempt. Continue
independent qualification; retain this gap if desktop access remains unavailable.
It remains unavailable at this checkpoint. Do not call the complete interactive
editor campaign finished or merge on that basis. All feasible independent gates
above are complete. Main, release publication and updater admission are unchanged.

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
