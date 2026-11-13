# GL-054 qualification

Status: native/editor/game implementation qualified within the profiles below;
production package/export and current multiplayer completion are pending. Work
remains on `feature/gl-054-engine-production`, unmerged. The
[development journal](gl-054-engine-development.md) retains failed attempts,
corrections, commands, timing context and qualification limits.

## Identity and implementation

Baseline main is `e3d7b53e78dd483e3765d64995e862810d94c6f8`. The corrected native
implementation is `f1a996b5f6fc9be1e4190d21ecd021ac279a9ab3`, tree
`4a5bdfd564f055cab1225619a5e854be0460c5ba`, with 128 LF-normalized native inputs:
`ba44f2ac38c33ed616d305434cef2f8beca232bffc0455d7c5159efa50c5e49d`.
Later commits change documentation/fixtures, not those native inputs. Pins remain
godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

Implemented phases include exact typed/scoped collections, useful physics/
navigation/image/texture/particles/lighting/UI families, bounded editor error
snapshots, a bounded cached project-use index, and the modular Luau-only Foundry
Expedition game. GL-056/057/058 correct reproduced plain-root bootstrap, shared
ancestor authority and attribute-value UTF-8 defects. The
[contract](gl-054-native-development.md) defines authority, bounds and compatibility.
No VM, scheduler, persistence backend, dependency, network protocol or admitted
host was replaced. Native remains default; Scripted remains explicit opt-in.

## Surface measurements

Pinned metadata denominators remain 920 classes, 14,379 methods, 3,676 properties,
447 signals, 647 enum declarations and 155 standalone class constants.

| Measurement | Baseline | Current |
| --- | ---: | ---: |
| Selected constructors | 94 | 113 |
| Selected methods | 167 | 225 |
| Selected properties | 306 | 384 |
| Selected signals | 33 | 41 |
| Selected enum values | 49 | 51 |
| Observed successful constructors | 61 | 82 |
| Observed successful methods | 61 | 126 |
| Observed property reads / writes | 22 / 116 | 22 / 165 |
| Observed signal deliveries | 11 | 12 |
| Observed pure-value constructors | 26 | 26 |

Selection and generated typing do not imply executable coverage. Current
generated handles total 153, including nonconstructible bases/return types. All
19 added constructors and 58 added methods are observed in the final cohort;
unobserved property/signal selections remain visible in the generated inventory.
The current corpus includes rendered cases absent from the initial baseline, so
these observations describe exercised surface, not a performance comparison.

The existing NativeCoverageReport produces the final cohort from native CI
43379513518 Linux plus the current Windows rendered production fixture: 16 logs,
587 distinct domain/member pairs. Raw report SHA256 is
`3fd4d8ee01b1293f3677f09b9b0ea0bc427d06bfe8b9bbfb29c3cb2bad788cbb`.
Policy identity is `c47c8e9f8a634510278c5ec30ce47850b7898b969399790cbb5c5adab9231ace`;
API identity is `dfd54f071d53ef63d9c1be51150b38f5c55abdd68eb8b2caa357abeab4086a0f`.
The journal retains the independently passing Windows native cohort as well.

## Completed gates

| Gate | Evidence | Scope |
| --- | --- | --- |
| Core | [43379513552](https://github.com/gmoddev/GodotLuau/actions/runs/43379513552), later [43382538818](https://github.com/gmoddev/GodotLuau/actions/runs/43382538818) | Existing Windows/Linux core qualification |
| Generated declarations | [43379561987](https://github.com/gmoddev/GodotLuau/actions/runs/43379561987), later [43380937977](https://github.com/gmoddev/GodotLuau/actions/runs/43380937977) | Both pinned-frontend platform jobs, generation/policy and positive/negative calls |
| Native | [43379513518](https://github.com/gmoddev/GodotLuau/actions/runs/43379513518) | 141 existing actors per platform, actual editor/index/snapshots, full-host physics/navigation, Foundry/restart |
| Full-native sanitizers | [43379555285](https://github.com/gmoddev/GodotLuau/actions/runs/43379555285) | Windows 26 / Linux 27 controls; 87 core cases, 141 native actors, zero unexpected reports |
| Windows rendered Foundry | `foundry-rendered-f1a` retained local evidence | 44 assertions, three sectors, 24 world rebuilds, actual native input/physics/combat, reload, authority, Unicode, durable restart |
| Windows graphical editor | `graphical-editor-f1a-03`, focused reopen receipt | 52 established editor assertions and seven fresh-process reopen assertions; inspected captures |
| Windows rendered production API | `production-rendered-f1a` | Native expansion plus real texture readback/immutable result, physics and navigation cases |

Local evidence root is `C:\Users\aiden\.codex\artifacts\godotluau\gl054`.
Windows worker Debug adapter SHA256 is
`c7d551e8e62f8d4a0a1bf59f0ab6a67278c2432488468f564f79bccacc529208`.
The journal records the two-job incremental cache, preservation of prior worker
edits and release of lease generation 119. No worker remains reserved for this build.

## Performance and reliability

The same retained seven-trial Windows Debug fixture, excluding warmup, measures
42.917 ms / 10,000 Position set-read pairs, 0.695 ms / 64-node construction and
11.454 ms / 2,000 Transform3D roundtrips. GL-053 measured 40.124/0.642/11.021 ms.
This records an observed modest increase in that test-adapter profile, including
disabled recorder call sites; no production speedup/regression is inferred.
Twenty editor previews take 142.61 ms in the retained index-era observation;
22-file index queries take 38.688/28.047/27.978 ms cold/warm/changed-buffer.
These are scoped observations, not hard-real-time guarantees.

The corrected rendered game completes 24 native world rebuilds in 5.532 seconds,
with exactly two scopes after every cycle and zero observed native object/resource
count delta. Entrypoint replacement retires old world/UI identities; a stale input
producer cannot keep moving the body. Completed sectors become acknowledged only
after GL-009 commits; fresh-process restart reads them. No general leak freedom,
exactly-once arbitrary callback execution or live debugger suspension is claimed.

## Remaining boundaries

Production candidate [43379558294](https://github.com/gmoddev/GodotLuau/actions/runs/43379558294)
rejected Windows Release at the existing reconnect fixture; the other three
profiles pass. GL-059's partial marker publication is reproduced and corrected
without a network implementation change; its focused stalled-writer control
passes all seven actors. A corrected coherent candidate cohort is required. Accepted package
extraction, both-platform Debug/Release standalone exports and fresh Relay Siege
solo/listen/dedicated evidence remain to be completed before campaign readiness.

Graphical editor/game observations use programmatic native actions and offscreen
rendering. They are not physical keyboard/gamepad/mobile or human-interaction
qualification. Linux graphical presentation is untested. Foundry is a solo game;
Relay Siege remains the supported multiplayer regression. Ordinary full-host
navigation/rendering is outside the lightweight sanitizer-host profile. Preserve
GL-018's Windows leak-sanitizer limitations.

Raw native RID/Callable/Signal values, arbitrary object graphs, live breakpoints,
stepping/evaluation, dynamic whole-program indexing and unrestricted Godot API
parity remain unsupported. The explicit callback, capability and bounded Variant
contracts remain authoritative. Release publication and updater distribution stay
disabled; no main integration is authorized by this campaign.
