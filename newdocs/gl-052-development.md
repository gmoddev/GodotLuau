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
