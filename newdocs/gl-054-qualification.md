# GL-054 qualification

Status: qualified within the profiles and limitations below; ready for integration
review. Work remains on `feature/gl-054-engine-production`, unmerged. The
[development journal](gl-054-engine-development.md) retains failed attempts,
corrections, commands, timing context and qualification limits.
The [compact receipt](evidence/gl054-qualification.json) records the final identities
and scoped outcomes for subsequent integration review.

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
| Native | [43379513518](https://github.com/gmoddev/GodotLuau/actions/runs/43379513518), final [43387293637](https://github.com/gmoddev/GodotLuau/actions/runs/43387293637) | 141 existing actors per platform, actual editor/index/snapshots, full-host physics/navigation, 44 Foundry checks/restart, corrected marker fixture |
| Full-native sanitizers | [43379555285](https://github.com/gmoddev/GodotLuau/actions/runs/43379555285) | Windows 26 / Linux 27 controls; 87 core cases, 141 native actors, zero unexpected reports |
| Windows rendered Foundry | `foundry-rendered-f1a` retained local evidence | 44 assertions, three sectors, 24 world rebuilds, actual native input/physics/combat, reload, authority, Unicode, durable restart |
| Windows graphical editor | `graphical-editor-f1a-03`, focused reopen receipt | 52 established editor assertions and seven fresh-process reopen assertions; inspected captures |
| Windows rendered production API | `production-rendered-f1a` | Native expansion plus real texture readback/immutable result, physics and navigation cases |
| Four production profiles and packages | [43387294744](https://github.com/gmoddev/GodotLuau/actions/runs/43387294744) | Accepted non-publishing Windows/Linux Debug/Release; 87 core cases and 141 native actors each, actual SCons Foundry/restart, extracted companion starts |
| Windows standalone applications | [43399518780](https://github.com/gmoddev/GodotLuau/actions/runs/43399518780) Windows jobs | Foundry Debug/Release export/start/restart, Orb Run export and Relay Siege extracted startup |
| Relay Siege regression | Same run's passing Package job | Solo 26 checks, recovery seven, four-player listen and dedicated with late join; every actor exits zero |
| Linux standalone applications | [43400803390](https://github.com/gmoddev/GodotLuau/actions/runs/43400803390) | Foundry Debug/Release export/start/restart with verified native bytes and executable companion; unchanged Windows/game proof reused explicitly |

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

## Production identity and corrections

The accepted candidate uses `678469610dbada94ecc1b210bc930c890d9ebb30`, tree
`157b4111950718d6dbc6875e2c2f823d351c29e9`, and the same native fingerprint above.
Windows archive SHA256 is
`0861a94d7870d9a3523049b8f8aebce59839292f9b6e2f77adaf827f6459cf90`;
Linux is `dd5400e283a7c1b0341d3f8f27b88fd4b95f48d687c34bcfac379933075fe95d`.
Both packages start Debug/Release companions successfully. Acceptance artifact
digest is `641ad833eb24377e2124f57513d6ccd0e1c0cc0e1738914896903d8940b33d2a`.

The initial candidate 43379558294 rejected a real fixture marker race. A 75 ms
writer stall reproduced NewPeer=0 and the failed reconnect predicate. Atomic
marker publication preserves every network assertion/deadline; the same stalled
control and final native/production cohorts pass. The corrected candidate's first
Linux attempts failed at the Ubuntu package mirror before compilation. Retrying
only failed jobs succeeded without changing source, packages or signed verification.
All attempts remain retained; no failed cohort was relabeled as accepted.

GL-060 corrects two Linux packaging mode losses. Staging restores verified ZIP
modes; after checking exported native byte hashes, export finalization restores
the companion's executable mode. Both corrected Linux configurations record
0755 staged, 0644 copied by Godot and 0755 final, then complete the initial
DataStore read in both starts. Manual editor export requires the same documented
chmod step. Source built products are reused; no native dependency, authority or
storage protocol changed. Focused Linux artifact digest is
`98fe930abf9fa0575b2ede084b7222b0b8bcf388ab60de4313c36aaab2a64fac`.

The complete Windows Package job passes solo/recovery and actual four-player
listen/dedicated sessions. Listen has four actors; dedicated has a server plus
four players. Every actor reports zero failures, including late join and retained
authority/lifecycle/persistence assertions. Evidence artifact digest is
`d02d068f101810b056b72b10d2733e5f12bb359f7286708a15b9c0f146f60700`.
The focused Linux run intentionally skips that unchanged Windows job; it does
not turn a skipped job into a passing multiplayer claim.

## Remaining boundaries

Standalone exports establish packaging, entrypoint/initial DataStore startup and
restart. Full gameplay is qualified with the actual production library on the
full-featured host; it is not relabeled as a full exported-gameplay observer pass.
The ordinary templates do not run that external observer through --script.

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
