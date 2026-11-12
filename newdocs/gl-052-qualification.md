# GL-052 qualification record

Disposition: implemented and qualified within the scopes below; **Windows
interactive acceptance complete; final print-template candidate pending; unmerged**.
The snapshot duplication defect is fixed and
fresh-process editor regressions pass on Windows/Linux. The owner-requested
[GL-053 default damage correction](gl-053-default-damage.md) is also qualified.
The supported Windows interactive journey now passes, including native export
and independent rendered standalone launch. Main remains
`e43e981d423cea99edff9eb9d186a0b9a4758b73`. Releases and updater distribution are
disabled. [ADR-016](adr-016-luau-editor-authoring.md), the
[development journal](gl-052-development.md) and
[authoring guide](gl-052-authoring-workflow.md) define the implemented workflow
and preserve failures. The final print-template production candidate is still
running. The compact
[qualification receipt](evidence/gl052-qualification.json) records exact source,
package and workflow identities.

## Source identities

Latest implementation: `71e997b31b3cea65080757e4f305fcf40c06c869`. Its only
runtime-input change after the preceding qualified cohort replaces 17 `dprint`
calls in nine shipped default scripts with ordinary `print` and updates the
matching embedded literals. Native fingerprint:
`140406f7ae825ba24e3400779c8ed5a016fc42fc1f9a68f374f23d2dedd96fd1`
(121 LF-normalized files). Core and native CI pass; the candidate is pending.
The legacy native debug helper remains available to existing customized scripts.

The complete preceding product cohort, used for the interactive journey, is
`60913fbf1ab849a7e354ba7397f8fbc5845cad55`, tree
`0527d7cbc67b26862cfc2609e4f097bf777de2d5`.
Native fingerprint: `9a59cfbcce5626fe954d232f5f8be71d4452ddf85cea0263eb627973886f49bc`,
121 files with compiler-equivalent LF normalization. Dependency pins and admitted
engine/renderer patches are unchanged.

The preceding checkpoint's source is `e393c0d310f096263fb8c0ec2c8e3fe13d80584a`,
tree `d78becf205bdbd948ba320b750765876c3de806a`, native fingerprint
`1d66c498a57007337b68502c99133abc4cac0531b16a8fed2bd72ee80db9e31a`.
Its accepted package repair uses tooling revision
`6852ae5b197e4565892c832a4d02824b59b7e199`. It reuses immutable source-built
products and records the tooling identity separately; later documentation does
not relabel those products as builds of a newer commit. Its unchanged historical
[receipt](evidence/gl052-e393-qualification.json) is retained separately.

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
| Pre-fix fresh-process saved-scene reopen | Native EditorInterface opens both Generated and OrbSaved with their native content, but scene switching emits two Godot dialog errors; retained failure, superseded by current passing checks |
| [Core `43154348664`](https://github.com/gmoddev/GodotLuau/actions/runs/43154348664), `60913fb` | Windows/Linux pass |
| [Native `43154348629`](https://github.com/gmoddev/GodotLuau/actions/runs/43154348629), `60913fb` | Windows/Linux pass: 141 actors, 19 inherited editor, 37 authoring, seven fresh-process reopen and 13 game checks per platform; GL-053 passes inside Integration |
| [Sanitizers `43154353439`](https://github.com/gmoddev/GodotLuau/actions/runs/43154353439), `60913fb` | Windows/Linux pass, 26/27 stages, zero unexpected reports; GL-053 passes within both native Integration actors |
| [Candidate `43154350153`](https://github.com/gmoddev/GodotLuau/actions/runs/43154350153), `60913fb` | All four profiles, both strict packages and acceptance pass; extracted Debug/Release companion startup exits 0 on Windows/Linux |
| [Package/export `43164852674`](https://github.com/gmoddev/GodotLuau/actions/runs/43164852674), `60913fb` | Relay Siege extracted startup and actual Orb Run export/independent startup pass, with exact emitted DLL/worker bytes |
| Current rendered Orb Run | `game-609-rendered`: 14 checks, inspected native scene/UI capture and clean exit; current Debug adapter under official editor, separate from production export |
| Windows interactive journey, `60913fb` products | Actual native edit/save, preview/Inspector, snapshot/edit/fresh-process reopen, Play/Stop, runtime source-line navigation/recovery, UI Release export and independent rendered standalone all pass; editor and standalone exits 0 |
| [Latest core `43188368995`](https://github.com/gmoddev/GodotLuau/actions/runs/43188368995), `71e997b` | Windows/Linux pass |
| [Latest native `43188368944`](https://github.com/gmoddev/GodotLuau/actions/runs/43188368944), `71e997b` | Windows/Linux pass; unchanged complete runtime/editor/authoring/reopen/game checks and DefaultScripts regression |
| [Latest candidate `43188370124`](https://github.com/gmoddev/GodotLuau/actions/runs/43188370124), `71e997b` | Pending |

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
Seven fresh-process checks now open both saved scenes through EditorInterface,
require exactly one Visual per Marker, preserve the external texture and reject
load-warning dialogs. Snapshot copies clear their instance paths before packing
expanded descendants; original preview/source content is preserved.

Orb Run is a new native 3D game with no developer GDScript or Relay Siege
bootstrap. The retained rendered frame shows native geometry, markers and UI.
Headless/rendered observers remain external qualification code. Candidate staging
omits the unnecessary disabled updater addon. Production export is a separate
gate: Godot exports, emits byte-identical library/companion products and launches
the game independently in current run `43164852674`. Its `OrbRun-Windows-Export`
artifact contains `results.json`, all four successful commands and their log
hashes. This is headless editor/export/startup evidence, not interactive export
or rendered standalone qualification.

The later [interactive receipt](evidence/gl052-interactive-qualification.json)
closes that separate Windows UI gap. The actual UI-created disposable project is
edited/saved in ScriptEditor, previewed and inspected, then saved independently
as InteractiveSnapshot.tscn. Native editing renames Cube to EditedCube; a fresh
editor process restores it without load dialogs. A deliberate runtime error at
Main.luau:8 reaches Output and the native authoring panel; explicit navigation
moves the caret to 8:1. Restoring valid source clears its diagnostic and reruns
successfully. Project → Export emits a Release executable with byte-identical
60913fb DLL/companion products. With the editor closed, only exported files are
copied to an independent directory and launched without source paths: the cube
renders, Ready is logged, and normal exit is 0 with empty stderr. The small UI
project complements the separate Orb Run gameplay qualification; it is not a
claim that every Orb Run script was typed during this session.

Twenty current hosted preview rebuilds take 129.344 ms on Windows and 129.743 ms
on Linux, including editor/frame processing. Static readings change from
396,988,836 to 397,141,024 bytes on Windows and 406,850,580 to 407,003,848 on Linux.
The retained preceding Release Relay Siege solo records 59.511 seconds, 1,702 frames, 33.483 ms
mean, 147.803 ms peak and 175 native objects at the existing 30 FPS cap. These
bounded observations are not isolated API latency, leak-free proof or a speed
improvement. Intermediate measurements remain in the development journal.

Accepted Windows archive SHA256:
`7a32df524ad403270176a87ef0fc76f53cfcc32248a2c0b995ddaacf08e99161`.
Accepted Linux archive SHA256:
`8b0e83d3fb5f1afa4c6b28244653757266435339bc10b0ee89061835b811233e`.
Exported Windows Release DLL SHA256:
`7f674f7410c9adaa601e91b1effaf122c6d0a60373b1f8332db7ccd30da81249`;
companion SHA256:
`0fae6ef38308a68caaa77b28eb49305ab5b8970880a1a9e76b848d42050882de`.

## Retained limitations and failures

- Initial black captures and `GetCursorPos: Access is denied` block UI access.
  Later `--single-window` work observes actual project creation, native Luau
  scene/source creation and source opening/highlighting. With current accepted
  products installed, editor captures render but activation fails twice with
  `failed to activate captured window`. Preserve these interrupted attempts.
  The later supported `--single-window` session completes the native Windows UI
  journey; it supersedes the input gap without erasing earlier failures. Linux
  graphical and physical-device claims remain outside this evidence.
- In a fresh isolated project, positional and `--scene` editor invocations restore
  Generated rather than prove OrbSaved opened. A subsequent external @tool
  observer uses native `EditorInterface.open_scene_from_path`: both roots open,
  but switching to OrbSaved reports `Attempting to parent and popup a dialog that
  already has a parent` twice. Retain `snapshot-reopen` logs; do not label this a
  clean historical pass. Investigation identifies duplicate expanded PackedScene
  children. Fix `33d448b`, qualified at `60913fb`, supersedes that gap with seven
  passing fresh-process checks per platform. Initial observer errors are retained.
  No application GDScript is added by the external observers.
- Fast clean stock-editor `--editor --import` exits with an access violation for
  both retained GL-051 and older GL-052 products. Root cause is not established.
  Normal bounded editor startup exits cleanly. The fast import profile remains
  unqualified; the separate saved-scene duplication defect is fixed.
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
Retained Windows Relay Siege solo, persistence/restart, menu failure/retry and
listen/dedicated multiplayer regressions pass within unchanged gameplay,
controller and networking paths. Fresh current extracted startup passes
separately. Native remains the default and
Scripted remains opt-in; no controller/network/persistence redesign is included.
The implemented headless, Windows rendered and Windows interactive paths are
qualified within the recorded scopes. The snapshot defect and GL-053 are fixed
and qualified. Latest print-template candidate verification remains pending.
The preceding sanitizer/rendered evidence is reused because this last change
only changes informational template calls; native output, ownership, authoring,
authority and their fixture inputs are unchanged. Main is not a delivery target.

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

The preceding Windows adapter SHA256 is
`9291b03534b053b167c2d57650423e700b9f5eb0832dfc69c8dcf082a2d0f305`.
Twenty preceding preview iterations record 140.658 ms including editor frames,
with OS static readings 409,685,266 and 409,835,838 bytes. These observations use
the same bounded interpretation as the intermediate measurement above.
