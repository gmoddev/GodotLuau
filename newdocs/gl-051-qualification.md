# GL-051 qualification

Status: **in progress on the unmerged feature branch**. The
[journal](gl-051-development.md) preserves implementation and failed attempts;
[ADR-015](adr-015-policy-driven-native-bindings.md) and the
[API guide](gl-051-native-api.md) define supported behavior. No release or updater
distribution is authorized.

## Source identities

Baseline remote main: `c60919a42416d5e6c72d2b23f7801500879c3195`.
Branch: `feature/gl-051-first-class-luau`.

| Input | Identity |
| --- | --- |
| Policy | `8322ba0504ed0b2f4d45a5d89b87ef20ba65e154bbb79b7bf898dfee5607585f` |
| Pinned extension API, LF SHA256 | `dfd54f071d53ef63d9c1be51150b38f5c55abdd68eb8b2caa357abeab4086a0f` |
| First sanitizer-qualified native input set, `6a04029` | `1555b83381465ae18844c0de09f40484d924cf1d13fbf2fb8fc3581b5a3495a0`, 112 files |
| Current native input set, `a276111` / `358d613` | `e855b3faeac811a7c276cd2c73255816b13efb89b4dbe18542145a919752d108`, 112 files |

The later native differences correct editor completion response fields/status
and supply required public-metadata hooks. They are not relabeled as part of the
earlier sanitizer product. Dependency pins and admitted engine profiles remain
unchanged. The pinned API describes Godot 4.3; runtime/editor hosts remain 4.7.1.

## Established outcomes

| Evidence | Actual outcome |
| --- | --- |
| [Core 43052421400](https://github.com/gmoddev/GodotLuau/actions/runs/43052421400), `a276111` | Windows/Linux Debug pass: 85 core cases and 29 input assertions; current core inputs unchanged. |
| [Definitions 43050098215](https://github.com/gmoddev/GodotLuau/actions/runs/43050098215), `2b2aab4` | Windows/Linux pinned Luau checker loads generated definitions, passes eleven positive/negative cases and the actual RelayFactory module; nine policy tests pass. Downloaded declarations/catalog match the branch. |
| [Initial native 43049375469](https://github.com/gmoddev/GodotLuau/actions/runs/43049375469), `6a04029` | Linux extension compiles and initial binding/lifecycle stage passes. Full job fails at the actual editor fixture; this is partial evidence, not a full native pass. |
| [Full-native sanitizers 43049541634](https://github.com/gmoddev/GodotLuau/actions/runs/43049541634), `6a04029` | Windows ASan and Linux ASan/LSan pass: controls, reload/lifetime, 85 core cases and 141 native actors per platform, including expanded binding cases. No unexpected sanitizer reports. |

The sanitizer records verify 1167 instrumented translation units, 25 Windows /
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

## Pending final cohort

The latest ordinary native run at `a276111` has a Linux provisioning failure
before compilation: mirror DNS/TLS timeouts. The journal records the bounded
correction. Windows is still running.

The [current candidate 43053904413](https://github.com/gmoddev/GodotLuau/actions/runs/43053904413)
at `358d613` retains all existing Windows/Linux Debug/Release/core/native/package
gates and adds the actual editor fixture against each SCons production library.
It uses the already provisioned official editor. The
[current sanitizer cohort 43055223210](https://github.com/gmoddev/GodotLuau/actions/runs/43055223210)
qualifies the final native input set. These runs are pending; no acceptance is
inferred from dispatch.

The real editor fixture loads a `.lua` resource, shares production diagnostics
cases and requests completion through Godot CodeEdit/ScriptLanguage. Its first
failure exposed a fixture root-selection error and inherited missing required
metadata hooks; both are corrected. Native/legacy completion results also now
follow the exact admitted Godot adapter contract. Actual UI completion still
needs a passing execution at those corrected inputs.

Relay Siege's representative migration and extracted package still need actual
local/listen/dedicated/restart playtests. Use the existing drivers and retained
renderer/asset identities; no additional gameplay framework is introduced.
The unchanged driver reports frame timing/node counts. The retained GL-049 solo
reference is 33.489 ms mean at the deliberate 30 FPS cap and 170 nodes at its
reporting point; it does not establish candidate performance.

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
