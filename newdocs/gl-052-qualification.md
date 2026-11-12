# GL-052 qualification record

Disposition: implemented and qualified within the scopes below; **partially
qualified overall and unmerged**. Interactive editor acceptance remains blocked,
and the fresh-process scene-switch observation is not a clean pass. Main remains
`e43e981d423cea99edff9eb9d186a0b9a4758b73`. Releases and updater distribution are
disabled. [ADR-016](adr-016-luau-editor-authoring.md), the
[development journal](gl-052-development.md) and
[authoring guide](gl-052-authoring-workflow.md) define the implemented workflow
and preserve failures. This checkpoint does not close GL-052. The compact
[qualification receipt](evidence/gl052-qualification.json) records exact source,
package and workflow identities.

## Source identities

Current native cohort: `1197f3d91a4a9f1f841e8eb5e48e2cbb1b4d4e21`.
Native fingerprint: `1d66c498a57007337b68502c99133abc4cac0531b16a8fed2bd72ee80db9e31a`,
121 files with compiler-equivalent LF normalization. Dependency pins and admitted
engine/renderer patches are unchanged.

Final production/observer source is `e393c0d310f096263fb8c0ec2c8e3fe13d80584a`,
tree `d78becf205bdbd948ba320b750765876c3de806a`, with that same native fingerprint.
The accepted package repair uses tooling revision
`6852ae5b197e4565892c832a4d02824b59b7e199`. It reuses immutable source-built
products and records the tooling identity separately; later documentation does
not relabel those products as builds of a newer commit.

The earlier `b35723969ca951ad5a684dd51e02a471c7cc0a91` cohort has fingerprint
`a6acfecee325d0989f15a967acfe40aa828a7c68eabd3b00cc714923899107b6`
(119 files). Its retained Windows Debug adapter SHA256 is
`27f565a2708b0836fae9996ff7587828dccb64f7d35d706a3b1d0695996f36e3`.
These intermediate observations are not relabeled as qualification of newer code.

## Hosted and focused evidence

| Cohort/check | Result and scope |
| --- | --- |
| GL-051 baseline editor | Three actual headless-editor observations confirm missing `.luau`, new-scene and preview workflow |
| Core `43125078056`, `b357239` | Windows/Linux pass, existing complete core checks |
| Native `43125078160`, `b357239` | Windows/Linux pass: 141 existing runtime actors, 19 real-editor checks and 26 clean-project authoring checks per platform |
| Core `43127995082`, `44ae713` | Windows/Linux pass |
| Types `43128057457`, `44ae713` | Windows/Linux pass; approved policy and generated declarations unchanged by later editor-only work |
| Focused headless new game, `9afbafd` adapter | `game-9af-headless-4` passes movement, collision, jump, collection, completion, scene transition, restart, reload and runtime module revision/path checks |
| Expanded real editor, `b357239` adapter | Preview/save and actual debugger transport/play-stop/recovery pass; saved-scene composition and error-line navigation fail and are subsequently corrected |
| Windows rendered new game, `b357239` adapter | `game-b357-official-rendered` passes 14 checks and process exit under official editor; captured frame visually inspected |
| Core `43130537822`, `4dba726` | Windows/Linux pass |
| Native `43130537900`, `4dba726` | Linux fails completion after direct CodeHighlighter installation; superseded by registered EditorSyntaxHighlighter implementation |
| Core `43132629894`, `1197f3d` | Windows/Linux pass |
| Native `43132629698`, `1197f3d` | Original editor checks pass; expanded fixture fails display/stdout assumptions, retained and corrected |
| Candidate `43132635974`, `1197f3d` | Superseded by corrected observer; not accepted |
| Full-native sanitizers `43132639596`, `1197f3d` | Windows/Linux pass with zero unexpected reports, including actual new game, core and strict native gate; 26/27 runner stages respectively |
| Focused current Windows editor | `workflow-1197-output-ready`: all 37 expanded checks and clean exit pass |
| Focused current Windows renderer | `game-1197-official-rendered`: 14 checks and clean exit pass under official editor/Debug adapter |
| Native `43135983475`, `e393c0d` | Windows/Linux pass: 141 existing actors, 19 existing editor checks, 37 expanded editor checks and 13 game checks per platform |
| Candidate `43135980287`, `e393c0d` | All four production profiles pass at attempt 2; package jobs reject supplementary logs added after the recorded native summary; layout-only repair reuses products without accepting the failed package run |
| Current Release rendered Relay Siege | Solo 27, fresh-process recovery seven and menu/retry/teardown five checks pass with clean exits; exact successful Windows Release profile products, separately identified from candidate acceptance |
| Focused production Windows export | `export-profile-release`: normal editor open, native export and independent standalone startup pass; emitted DLL/companion hashes match the qualified Release profile and application contains no GDScript |
| [Accepted candidate repair `43149322873`](https://github.com/gmoddev/GodotLuau/actions/runs/43149322873) | Policy, Windows/Linux packages and final acceptance pass; original four qualified profiles are reused without rebuilding or weakening strict evidence checks |
| [Final game package/export `43149583568`](https://github.com/gmoddev/GodotLuau/actions/runs/43149583568) | Existing Relay Siege extracted-package startup and actual Orb Run native export/independent startup pass; emitted DLL and companion match the accepted candidate |
| Accepted-candidate Windows rendered multiplayer | `relay-candidate-listen` and `relay-candidate-dedicated` pass: four rendered players including late join, all actor exits 0 and no failed checks; dedicated server is headless |
| Fresh-process saved-scene reopen | Native EditorInterface opens both Generated and OrbSaved with their native content, but scene switching emits two Godot dialog errors; partial observation only, not a clean editor/reopen pass |

Superseded candidate/sanitizer/native cohorts are canceled when concrete source
fixes invalidate their inputs. Their failures/logs remain in the journal and
artifacts; cancellation is not a pass. No original assertion, core/native count,
sanitizer control or acceptance gate is weakened.

## Actual workflow facts

Current actual-editor evidence exercises native scene/source creation,
LocalScript association, explicit restricted preview, native hierarchy, Save As,
independent PackedScene reload, overwrite rejection, module factories/revisions,
runtime-service denial, timeout/yield retirement, error recovery and declaration
navigation. The 37 expanded checks pass on Windows/Linux, including real
EditorInterface play/stop, native debugger capture and rerun, correct source-line
navigation, serialized-transform composition and the registered lexer highlighter.
The 19 inherited editor checks and 141 inherited runtime actors also pass.

Orb Run is a new native 3D game with no developer GDScript or Relay Siege
bootstrap. The retained rendered frame shows native geometry, markers and UI.
Headless/rendered observers remain external qualification code. Candidate staging
omits the unnecessary disabled updater addon. Production export is a separate
gate: Godot exports, emits byte-identical library/companion products and launches
the game independently in final run `43149583568`. Its `OrbRun-Windows-Export`
artifact contains `results.json`, all four successful commands and their log
hashes. This is headless editor/export/startup evidence, not interactive export
or rendered standalone qualification.

Twenty current preview rebuilds take 140.658 ms including editor/frame processing.
OS static allocation readings change from 409,685,266 to 409,835,838 bytes.
Current Release Relay Siege solo records 59.511 seconds, 1,702 frames, 33.483 ms
mean, 147.803 ms peak and 175 native objects at the existing 30 FPS cap. These
bounded observations are not isolated API latency, leak-free proof or a speed
improvement. Intermediate measurements remain in the development journal.

Accepted Windows archive SHA256:
`bcec75e31caee58037ea893a0ef2b2d956b68ba437999c18975a9b7dd2266a46`.
Accepted Linux archive SHA256:
`7b44e351c62f60a444c0bfece51eff5bd163d691b1b8d3096f20d751c6a7ebb5`.
Exported Windows Release DLL SHA256:
`207a24e7a3c25742159723c60b4292c2ad950276c8f9c9e113cc1237defc759e`;
companion SHA256:
`0517138956ff84d241066ad421fcc14ac97e465515dbc6ea61b527034a592569`.

## Retained limitations and failures

- Interactive native-editor creation/edit/inspect/save/reopen/export is blocked
  by black desktop captures and `GetCursorPos: Access is denied`; no UI interaction
  or full interactive qualification is claimed. Actual headless editor execution
  and offscreen game rendering are separate evidence.
- In a fresh isolated project, positional and `--scene` editor invocations restore
  Generated rather than prove OrbSaved opened. A subsequent external @tool
  observer uses native `EditorInterface.open_scene_from_path`: both roots open,
  but switching to OrbSaved reports `Attempting to parent and popup a dialog that
  already has a parent` twice. Retain `snapshot-reopen` logs; do not label this a
  clean pass or infer its cause. The observer's first parse/type error and bounded
  timeout are also retained. No application GDScript is added by this observer.
- Fast clean stock-editor `--editor --import` exits with an access violation for
  both retained GL-051 and older GL-052 products. Root cause is not established.
  Normal bounded editor startup exits cleanly. The fast import profile remains
  unqualified; saved-scene switching has its separate limitation above.
- The older Debug extension under the admitted Release host exits with heap
  corruption even for a print-only scene, including with retained GL-051.
  Matching production profiles must be used; successful in-game observations
  do not erase a failed exit.
- The old export fails startup because encoded-resource bounds check source text
  paths that Godot remaps to binary resources. The current bounded remap fix passes
  focused production export and final accepted-candidate export. Imported
  texture feature variants are not promised.
- Breakpoint/step debugging, full embedded Luau type checking, complete lexical
  navigation, theme-aware syntax palettes, arbitrary ScriptInstance attachment,
  file inheritance and automatic editor-to-running-child hot reload are not
  implemented. Explicit source-resource reload and normal stop/edit/rerun are
  supported paths with their stated evidence.
- Existing Linux graphical, physical device and Windows LSan limits remain.
  Headless full-native sanitizer coverage does not establish editor/rendering
  execution coverage. GL-050 stays separate and unresolved.

Windows/Linux core, native, type, sanitizer, all four production profiles, both
packages and Windows standalone export are verified within their recorded scopes.
Current Windows Relay Siege solo, persistence/restart, menu failure/retry and
listen/dedicated multiplayer regressions pass. Native remains the default and
Scripted remains opt-in; no controller/network/persistence redesign is included.
The implemented headless and Windows rendered paths are ready for review, but
full interactive acceptance and clean editor scene-switch/reopen qualification
remain outstanding. Main is not a delivery target for this campaign.

## Retained fixture correction

Native `43132629698` passes the original editor checks on both platforms. The
expanded Linux workflow passes construction/save/composition/highlighting but
fails the first child launch's display requirement; Windows's native checks pass
but its inherited-stdout recovery assumption fails. These are retained fixture
failures, not complete native passes. Configure headless play before editor
startup and observe recovery in the actual editor Output control with a bounded
deadline. The focused Windows rerun `workflow-1197-output-ready` passes every
expanded assertion and clean exit with the unchanged 121-file current adapter.
The subsequent `43135983475` cross-platform native run and all four production
profiles pass with that correction. Full-native sanitizers are reused because
their native sources and runtime fixture inputs are unchanged.

The current Windows adapter SHA256 is
`9291b03534b053b167c2d57650423e700b9f5eb0832dfc69c8dcf082a2d0f305`.
Twenty current preview iterations record 140.658 ms including editor frames,
with OS static readings 409,685,266 and 409,835,838 bytes. These observations use
the same bounded interpretation as the intermediate measurement above.
