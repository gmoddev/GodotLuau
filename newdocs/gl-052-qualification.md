# GL-052 qualification record

Disposition: implementation and qualification in progress, unmerged. Main remains
`e43e981d423cea99edff9eb9d186a0b9a4758b73`. Releases and updater distribution are
disabled. [ADR-016](adr-016-luau-editor-authoring.md), the
[development journal](gl-052-development.md) and
[authoring guide](gl-052-authoring-workflow.md) define the implemented workflow
and preserve failures. This checkpoint does not close GL-052.

## Source identities

Current native cohort: `1197f3d91a4a9f1f841e8eb5e48e2cbb1b4d4e21`.
Native fingerprint: `1d66c498a57007337b68502c99133abc4cac0531b16a8fed2bd72ee80db9e31a`,
121 files with compiler-equivalent LF normalization. Dependency pins and admitted
engine/renderer patches are unchanged.

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
| Native `43135983475`, `e393c0d` | Pending, unchanged 121-file native source with corrected observer |
| Candidate `43135980287`, `e393c0d` | Pending; Linux Release mirror timeout occurs before compilation and needs targeted retry after remaining profiles finish |

Superseded candidate/sanitizer/native cohorts are canceled when concrete source
fixes invalidate their inputs. Their failures/logs remain in the journal and
artifacts; cancellation is not a pass. No original assertion, core/native count,
sanitizer control or acceptance gate is weakened.

## Actual workflow facts

Intermediate actual-editor evidence exercises native scene/source creation,
LocalScript association, explicit restricted preview, native hierarchy, Save As,
independent PackedScene reload, overwrite rejection, module factories/revisions,
runtime-service denial, timeout/yield retirement, error recovery and declaration
navigation. Expanded checks exercise real EditorInterface play/stop, native
debugger capture and rerun. New current checks require correct error navigation,
native serialized-transform composition and the registered lexer highlighter.
Their current runtime outcomes remain pending.

Orb Run is a new native 3D game with no developer GDScript or Relay Siege
bootstrap. The retained rendered frame shows native geometry, markers and UI.
Headless/rendered observers remain external qualification code. Candidate staging
omits the unnecessary disabled updater addon. Production export is a separate
gate: Godot must export, emit byte-identical library/companion products and launch
the game independently. A preset, pack operation or adapter screenshot is not
an accepted production export.

Twenty intermediate preview rebuilds take 142.94 ms including editor/frame
processing. OS static allocation readings change from 409,673,062 to 409,823,634
bytes. This is bounded observation, not isolated call latency, a leak-free proof
or a speed improvement. Current-product measurements remain separate.

## Retained limitations and failures

- Interactive native-editor creation/edit/inspect/save/reopen/export is blocked
  by black desktop captures and `GetCursorPos: Access is denied`; no UI interaction
  or full interactive qualification is claimed. Actual headless editor execution
  and offscreen game rendering are separate evidence.
- Fast clean stock-editor `--editor --import` exits with an access violation for
  both retained GL-051 and older GL-052 products. Root cause is not established.
  Normal bounded editor reopen succeeds. This profile remains unqualified.
- The older Debug extension under the admitted Release host exits with heap
  corruption even for a print-only scene, including with retained GL-051.
  Matching production profiles must be used; successful in-game observations
  do not erase a failed exit.
- The old export fails startup because encoded-resource bounds check source text
  paths that Godot remaps to binary resources. The current bounded remap fix must
  pass fresh production export. Imported texture feature variants are not promised.
- Breakpoint/step debugging, full embedded Luau type checking, complete lexical
  navigation, theme-aware syntax palettes, arbitrary ScriptInstance attachment,
  file inheritance and automatic editor-to-running-child hot reload are not
  implemented. Explicit source-resource reload and normal stop/edit/rerun are
  supported paths with their stated evidence.
- Existing Linux graphical, physical device and Windows LSan limits remain.
  Headless full-native sanitizer coverage does not establish editor/rendering
  execution coverage. GL-050 stays separate and unresolved.

Final Windows/Linux production/native/sanitizer results, standalone export and
fresh relevant Relay Siege regression must be appended before integration
readiness is assessed. Main is not a delivery target for this campaign.

## Current fixture correction

Native `43132629698` passes the original editor checks on both platforms. The
expanded Linux workflow passes construction/save/composition/highlighting but
fails the first child launch's display requirement; Windows's native checks pass
but its inherited-stdout recovery assumption fails. These are retained fixture
failures, not complete native passes. Configure headless play before editor
startup and observe recovery in the actual editor Output control with a bounded
deadline. The focused Windows rerun `workflow-1197-output-ready` passes every
expanded assertion and clean exit with the unchanged 121-file current adapter.
Cross-platform/profile reruns are pending. Current full-native sanitizers are
reused because their native sources and runtime fixture inputs are unchanged.

The current Windows adapter SHA256 is
`9291b03534b053b167c2d57650423e700b9f5eb0832dfc69c8dcf082a2d0f305`.
Twenty current preview iterations record 140.658 ms including editor frames,
with OS static readings 409,685,266 and 409,835,838 bytes. These observations use
the same bounded interpretation as the intermediate measurement above.
