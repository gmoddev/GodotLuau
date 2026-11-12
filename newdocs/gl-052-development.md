# GL-052 development and qualification

Baseline: freshly fetched main `e43e981d423cea99edff9eb9d186a0b9a4758b73`.
Branch: `feature/gl-052-luau-authoring-workflow`. Main is not a delivery target
without separate authorization. Releases and updater distribution stay disabled.

## Acceptance journey

Start with an empty project and the qualified extension, without Relay Siege or
its bootstrap. Use the native editor to create a Luau scene/entrypoint, edit a
`.luau` resource, preview native geometry, inspect it, explicitly save a fresh
native PackedScene, run/stop/edit/reload, recover from a deliberate error, reopen
the saved project and export/launch independently. Developer application sources
must contain no GDScript. Qualification observer scripts may use GDScript, and
must not substitute their behavior for production authoring or gameplay.

Fresh changed-boundary coverage must include preview denial of runtime services,
bounded execution, cancellation, repeated rebuilds, resource/owner retirement,
non-overwriting save, reload and error recovery. Actual editor automation and
graphical interaction are separate evidence classes. A successful game launch
alone cannot close this campaign.

## Source baseline

GL-051's registry, SceneScope ownership, native editor completion/diagnostics,
generated definitions and qualification are reused. Source inspection finds:

- LuauLanguage/LuauLoader/LuauSaver advertise `.lua` only.
- LuauScript advertises `_can_instantiate=true` but `_instance_create` returns
  null. Attaching it to an arbitrary native node is not an executable workflow.
- LocalScript/ServerScript already associate a LuauScript resource with a real
  native node and use the shared domain host, owner cancellation and source
  changed notifications. They need no developer GDScript bootstrap.
- Editor script execution is deliberately disabled. No preview/save authority
  exists. Enabling gameplay bootstrap in the editor would expose inappropriate
  services and is not an acceptable implementation.
- Runtime chunks use node names, limiting source-path diagnostics. Module
  resolution currently requires ModuleScript node handles.

These are source-verified baseline facts, not graphical qualification or crash
reproductions. Controlled editor baseline and implementation results follow.

## Implementation order

1. Establish the executable clean-project fixture and retain missing capabilities.
2. Support `.luau` alongside `.lua`, native scene/entrypoint creation, source-path
   diagnostics and project-local module imports using existing domain ownership.
3. Implement explicit editor preview and save under ADR-016, without gameplay
   bootstrap, services, network, persistence or arbitrary editor-object access.
4. Exercise the workflow in a new small Luau-only native game; qualify actual
   editor use, failure/reload recovery, native serialization and export.
5. Run relevant Windows/Linux runtime, type, sanitizer and existing-game checks;
   distinguish actual graphical/export results from remaining gaps.

GL-050 stays separate. No dependency or admitted-host change is selected.

## First implementation cohort

The unchanged qualified GL-051 Windows product (candidate `43063482878`) runs the
new baseline observer in an actual headless Godot 4.7.1 editor. All three baseline
observations pass: `.lua` only, no native create-scene action and no preview action.
Logs/results are retained under `gl052-20261111/baseline-editor` in the normal
local artifact root. This is baseline evidence, not GL-052 feature qualification.

Implementation now recognizes `.luau` and `.lua`, declines unsupported arbitrary
Object attachment, and uses source resource paths for executable chunk names.
The existing native editor plugin gains a Luau Authoring panel, explicit scene
and entrypoint creation, isolated preview, hierarchy/Inspector selection and
non-overwriting PackedScene Save As. Runtime entrypoints reuse native LocalScript
and existing shared Client-domain ownership; application code needs no GDScript.

Preview uses only value types and the approved Scene bindings, with no gameplay
bootstrap or service globals. It has 100 ms/500000-safepoint execution, 64 MiB VM
memory and bounded task/owner/reference admissions; construction/callback yields
reject. Rebuild retires the old generation before root deletion. The private
preview physics space is inactive and audio playback is denied. Save duplicates
authored native content and transforms into plain nodes, without live SceneScope
capabilities. New files never replace existing targets. Native lifetime and
trusted-resource-loading limits still apply; save is an explicit editor action,
not a script-visible filesystem capability.

The two new/changed editor translation units pass lightweight syntax-only probes
against pinned headers (about 2–3 seconds each). These are not runtime passes.
The existing actual-editor runner now hosts the clean-project observer, including
fresh creation, preview, independent native reload, overwrite rejection,
service denial, errors, repeated rebuild, timeout/yield cancellation and stale
generation checks. It is part of native CI; its first production execution is
pending. Arbitrary ScriptInstance attachment, project module paths, full debugger,
new acceptance gameplay, graphical interaction and export remain unfinished.

DockerPC's heavy lease is held by unrelated `StudioCreatorFoundation3` at the
initial admission check. No worker load is started or lease bypassed; sustained
compilation uses the existing hosted CI. No full native build runs locally.

## Project modules, recovery and diagnostics

The first cohort is `a1b14d7`; hosted core `43121590203` passes Windows/Linux.
Native `43121590194` is still building. No runtime or graphical preview pass is
inferred from the successful syntax probes.

The next source cohort adds `require("res://Module.luau")` / `.lua` through the
existing domain evaluator/cache. A per-domain native cache retains at most 64
project script resources, each limited to 1 MiB on admission. Existing
ModuleScript-node require retains its resolver/lifetime contract. String modules
have a resource identity rather than a native node; factories receive the caller's
scope explicitly and do not acquire an editor/gameplay node through `script`.
Explicit resource reload updates the source revision and normal runtime owners
use their existing changed/cancellation behavior. Preview rebuild invalidates its
module initializers/results as well as retiring the selected script generation,
so a yielding module cannot survive a failed preview and poison later rebuilds.

The native panel now offers explicit Reset Context, without automatically
restarting exhausted VMs or touching game domains. Editing the active source
clears the old preview rather than permitting an unnoticed stale save.

Source review against the admitted engine's
[ScriptLanguage adapter](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/object/script_language_extension.h)
verifies an inherited lookup contract error: arguments were reversed and result
was a documentation string rather than an integer Error. Correct that interface
and provide bounded top-level function, explicit project-module path and approved
native-class navigation. The observer requests declaration navigation through
the actual ScriptEditor CodeEdit signal; a helper result alone is not UI proof.

Runtime errors now also use Godot's supported EngineDebugger message capture to
the native authoring panel, with bounded source/message/trace and explicit Open
Runtime Error navigation. This does not implement breakpoints/stepping. Actual
editor-run message capture remains pending qualification. Adapter artifacts are
retained for bounded interactive investigation; they include test hooks and are
not production distribution or accepted export candidates.

The diagnostics cohort `481afaf` contains a C++ Ref assignment ambiguity caught
by the local syntax probe. Its superseded native run `43123601596` is canceled;
`9afbafd` makes the retained Ref construction explicit and passes the corrected
probe. Core `43123668530` passes at that corrected revision; native
`43123668484` remains pending. The earlier successful core runs are retained.

First native cohort `43121590194` compiles and passes GL-051's actual editor
checks on Linux, then fails the new workflow. Its log identifies the new default
template's unsupported Camera3D.Current assignment, followed by missing-save
cascades. Remove that assignment instead of widening camera takeover authority;
the new standalone scene/private viewport uses native camera selection. Preserve
the failed log and keep all original preview/save assertions. The observer only
loads a saved scene when it exists, preventing secondary loader noise from
obscuring the original failure.

The new `examples/luau-only` Orb Run sources contain only native scenes/resources
and Luau application/composition logic. They use a native RigidBody orb, qualified
semantic input, reusable PackedScene markers, a project module factory, UI,
gradient texture, procedural audio, owned scene replacement and shutdown. They
reuse no Relay Siege bootstrap. Source inspection catches the correct existing
material name AlbedoTexture; no camera or material authority expansion is needed.
Preview adds the generated API's X/Y Vector2 constructor shape and bounded print,
and closes its domain while plugin state remains alive. Game, graphical editor,
export and latest native qualification are still pending.

## Actual new-game runtime and production-profile gates

Native `43123668484` at `9afbafd` retains the known default-camera failure on
both platforms; real ScriptEditor declaration navigation already passes there.
At `b357239`, core `43125078056` passes on both platforms and Linux native
`43125078160` passes the corrected clean-project authoring workflow before
finishing the retained runtime suites. Windows is still building at this entry.

Use its retained Windows Debug adapter for bounded local diagnosis, not as a
production package or Release result. The first game attempt omitted the normal
editor-created extension cache and never loaded the extension. The second
loads it and exposes an example error: opaque native resource handles require
`Scope:Configure(Ground, {AlbedoTexture = ...})`, not userdata field assignment.
Correct the example without expanding authority. Preserve both failed logs.
The third run (`game-9af-headless-3`) passes all ten actual-game checks: native
floor collision, keyboard movement, jump impulse, UI signal scene replacement,
disable/re-enable teardown and runtime module revision invalidation. It uses
the real Luau entrypoint/factory; external GDScript is only the observer. It is
headless and does not establish graphical or export qualification.

Extend the same observer to exercise collection, round completion and transition.
Stage projects only into fresh paths, with explicit candidate or test-adapter
identity. Add the authoring workflow to existing SCons production profile checks
and the game to existing adapter checks; no second qualification framework.
The language adapter now truthfully rejects unsupported file inheritance,
recognizes Luau type/export keywords and supplies native function navigation
and a deliberate no-op indentation hook. A pinned-header syntax probe passes.
Interactive editor, debugger transport, rendered game and export remain pending.

Generated types `43128057457` and core `43127995082` pass both platforms at
`44ae713`. Candidate `43128050676` and full-native sanitizers `43128053718`
are started through their existing non-publishing workflows, unchanged gates.
The focused game rerun `game-9af-headless-4` also passes collection, round
completion and scene transition. No performance improvement is inferred.

The actual Windows project manager starts with the existing official editor and
isolated profile. Computer Use returns a black capture and activation fails with
`GetCursorPos: Access is denied (0x80070005)`. Fresh window selection still gives
an unusable capture. No UI inputs are attempted through that failure; the owned
project-manager process is stopped. Interactive qualification is blocked by the
desktop environment, separately from actual headless-editor integration.

The first independent export probe uses the older `9afbafd` Debug test adapter.
Its clean editor import exits `3221225477` after loading editor layout, before
export. Keep `export-9af` commands/stdout/stderr. This is an actual failed import,
not an accepted production export or a claim against a newer untested binary.
Investigate with the pending current Windows product before changing code.

A delayed editor reopen (`--quit-after 120`) succeeds with that same test
adapter. Export then succeeds, but independent startup reproduces a concrete
resource-loading defect: `Scope:Load` rejects `res://Pattern.tres`, because Godot
exports it as `.res` behind a `.remap` and the source file is absent. Inspection
of the actual packed sidecars confirms the same conversion for Marker.tscn.
Add one-hop export remap handling to the existing load boundary: metadata at most
16 KiB, string target, both paths checked by the existing project confinement,
encoded target at most 16 MiB, then normal ResourceLoader/type validation. No
raw path, new resource class, dependency or authority is exposed. Imported
texture feature variants are not newly promised by this focused correction.
The existing native authoring actor gains successful binary remap composition,
outside-root rejection and metadata/target bounds. Preserve the failed exported
startup; a successful pack operation alone is not acceptance.

Both platforms pass complete native `43125078160` at `b357239`. Its Windows
adapter runs the expanded actual editor observer locally. Actual game preview
and native save pass. Real EditorInterface play/stop transports the deliberate
Luau failure to the native debugger with `res://Failure.luau:2`, and rerun executes
the recovery marker. Two assertions expose real remaining issues: composition
rejects Godot's serialized DirectionalLight3D.transform, and explicit error
navigation selects row 0 instead of row 1. Preserve `workflow-b357-expanded`.

Admit only the native serialized equivalent of already permitted bounded
position/rotation/positive-scale properties, rejecting shear, reflection,
degeneracy and out-of-range translation/scale. Clear the preview world's implicit
camera-current flag on the off-tree saved copy, preserving takeover rejection.
Pass the debugger's 1-based line to EditorInterface rather than subtracting it.
Add native CodeHighlighter configuration to the existing Luau-only editor hook;
keywords, common types, numbers, strings and basic comment regions are colored.
No complete lexer/type-checker or theme-aware custom highlighter is claimed.
The actual CodeEdit observer checks its installed native highlighter.

The old exported adapter directory contains only the application and extension;
Godot does not infer the companion EXE. Add platform-specific dependency metadata
using the [supported export mechanism](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/gdextension_file.html)
so it is emitted beside the application/library. Preserve normal fork archive
packaging. Production profile/candidate cohorts at `44ae713` and `eedd4fe` are
canceled as superseded before accepting any of their artifacts. Final current
native/production/sanitizer checks remain required after these concrete fixes.

Fast clean `--editor --import` exits with an access violation for both the
retained GL-051 product and older GL-052 adapter in isolated empty projects.
Root cause is not established; this is a retained stock-editor/import exit
limitation, not a newly attributed GL-052 defect. Normal bounded editor reopen
succeeds. Do not claim the fast-import profile is qualified or change admitted
engine patches/dependencies to hide it.

## Rendered new game and remaining shutdown investigation

`game-b357-official-rendered` passes all fourteen production-game observations
and clean process exit under the existing official editor, using the retained
`b357239` Debug adapter. The offscreen/no-focus profile reuses Relay Siege's
established mechanism. The captured 960x640 frame shows the native floor, orb,
three markers and readable UI; it is visually inspected. This is actual Windows
rendering, not interactive editor manipulation or a production Release result.

The same adapter under the admitted Release renderer runs every observation but
exits `3221226356` during shutdown, both rendered and headless. Keep both attempts
as failures. Do not attribute this to graphics or accept a printed PASS marker
over a bad exit. Matching production profiles and a new-game invocation within
the existing full-native sanitizer runner will investigate this concrete failure;
no additional qualifier or weakened cleanup/assertion is introduced.

DockerPC remains held by StudioCreatorFoundation3 at 00:57 UTC; no worker job or
lease bypass is attempted. The accepted native source is still pending at
`4dba726`: candidate `43130538511`, sanitizers `43130541887` and ordinary hosted
native/core CI. The fixture/export follow-up keeps that native code unchanged.

The existing game-package workflow now additionally stages the real Luau-only
game from a verified matching candidate, opens the editor, exports through
Godot, verifies emitted library/companion bytes and launches independently from
the standalone directory. It retains separate logs/results and checks no
application GDScript. New-game staging omits the disabled updater addon, which
is not needed by the application; it never alters the verified fork archive.

Shutdown isolation narrows the failed mixed profile: four tiny scenes (print
only, string module, owned node and module factory) all exit `3221226356` under
the admitted Release host with the older Debug adapter, while all four exit 0
under the official editor. The retained GL-051 production Debug library also
fails the same print-only Release-host case. This does not identify a new module
or graphics defect. Keep the nine case logs in `shutdown-isolation`; qualify
matching production profiles and preserve this unsupported mixed-profile limit.
No runtime behavior is changed merely to hide shutdown behind fixture teardown.

The successful actual editor preview loop at `b357239` records 142.94 ms for
twenty rebuilds including observer/editor frame processing (about 7.15 ms per
iteration). OS static allocation readings are 409,673,062 before and 409,823,634
bytes after. These bounded observations are not isolated API costs, a leak-free
proof or a performance improvement claim. Final current-product measurements
remain separate.

Native `43130537900` Linux fails at GL-051's existing real-editor completion
after the direct CodeHighlighter assignment. Keep the failed output: compilation
and the first source checks pass, then the process stops at completion request.
The [supported editor contract](https://docs.godotengine.org/en/stable/classes/class_editorsyntaxhighlighter.html)
requires EditorSyntaxHighlighter subclasses. Remove the direct assignment and
register a native per-script Luau subclass through ScriptEditor instead.
It uses the pinned Luau lexer, with a 1 MiB source, 8,192 line and 65,536 token
budget; UTF-8 byte locations are converted to Godot character columns. The admitted
editor's `_create` virtual uses the existing ptrcall encoding support without
changing the pinned 4.3 binding dependency. New syntax-only probes pass for its
implementation, plugin and registration. Runtime editor qualification is pending;
all original completion assertions remain required.
