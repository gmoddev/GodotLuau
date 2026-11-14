# GL-067 editor and iteration guide

Applies to the unmerged `feature/gl-067-development-platform` branch. See the
[development/qualification journal](gl-067-development.md) and
[worker decision](adr-019-incremental-editor-index.md). Native remains the default
Character controller; Scripted remains opt-in. Releases/updater remain disabled.

## Project tools

The native authoring panel offers Project Symbols, Project Uses, Definition,
Completion, Diagnostics, Symbol Search and Next Page. Select a Luau source and
place the caret on the relevant name. Results use the existing source-location
tree; dynamic member candidates are labelled explicitly. Diagnostics and type
completion come from pinned Luau Analysis and the exact generated Native types.
The ordinary synchronous ScriptEditor language hooks retain their existing
single-buffer syntax/metadata implementation.

The trusted native editor plugin also exposes `QueryProject(Options)` and
`PollProject(Generation)`. Gameplay and EditorPreview Luau cannot invoke this
service. Options accept these primitive fields only:

| Field | Type/default | Meaning |
| --- | --- | --- |
| Query | string, `Symbols` | Symbols, References, Search, Dependencies, Diagnostics, Complete, Definition or Rename |
| Module | string, empty | Exact `res://` module for a References query |
| Member | string, empty | Reference name, search term or completion prefix; max 128 bytes |
| Line / Column | integer, 1 / 1 | One-based active-buffer coordinates; columns count UTF-8 bytes |
| Offset | integer, 0 | Result-entry offset, normally advanced by 256 |
| Replacement | string, empty | New lexical identifier for a Rename preview |
| Refresh | boolean, false | Force a disk refresh for interactive snapshot queries |

`IndexProject(Module,Member)` remains a convenience submission method. It now
returns `result`, `Generation` and `Pending`, rather than waiting for a complete
synchronous scan. Poll while `Pending` is true. A source-change cancellation
returns `Stale`; submit again. The UI does this with a 150 ms debounce. Each
completed response reports source revisions, work counts, worker time and
explicit `Incomplete`/`More` flags. A result page contains at most 256 entries;
dependency pages bound total edges, not just node count. `Documents` groups the
entries in that page and is not an inventory of every indexed file.

Interactive queries update supplied open buffers and reuse the last discovered
project snapshot. Full symbols/references/diagnostics refresh saved files; the
existing filesystem signal also invalidates the UI snapshot. Built-in Script
resources without a standalone project module path are skipped. Sources are
limited to 4,096 files/32 MiB, 256 KiB/file. Syntax navigation retains at most
512 entries/file. Semantic working sets retain at most 256 modules/4 MiB, with
50 ms frontend limits per module. There is no hard process-RSS quota.

Static literal requires, lexical locals/arguments, imported functions and exported
table properties are supported. Dynamic module expressions, arbitrary metatables
and reflective names are not invented definitions. User-defined type functions
are explicitly excluded from semantic evaluation; the worker never runs project
Luau. Rename returns exact lexical edits with source preconditions in `Revisions`;
it does not apply writes. It refuses incomplete bindings, potential capture and
cross-module/dynamic field rename. Any external consumer applying a preview must
first compare its complete source precondition and refuse a stale edit.

For literal import navigation, place the caret on `require` and choose Definition.
An existing target opens at line one even when it returns only an empty table or
constant and has no indexed declarations. Missing targets remain unresolved.

## Debugging

The existing Watch restrictions also govern breakpoint conditions. In the Luau
debugger tab, enter an expression and choose Set Condition while stopped at the
desired source line. Empty input restores an unconditional breakpoint. Conditions
may read bounded locals/upvalues, raw tables and approved native projections;
calls, mutation, globals/capabilities, files and networking remain forbidden.
Lua truthiness applies. False/nil skips a stop; evaluation failure pauses with
`ConditionError`. Hit counts count visits before filtering. Changing a condition
resets that record; identical replay preserves it.

Detach resumes execution and drops code/inspection roots and profiling. Attach
supports a manually detached runtime while its original Godot connection remains
active. It rotates the session nonce and request sequence, rejecting old commands.
It does not restore old inspection roots: new/reloaded script generations regain
source inspection and breakpoints. Physical transport disconnect/editor restart
still requires a new runtime session with the pinned public Godot API. Suspended
execution is not retained indefinitely. Older runtimes do not advertise Attach
and the new editor action stays inert for them.

Profile snapshots now include inclusive synchronous callback/require durations
and domain allocator observations. `DomainLiveBytesAtExit` and
`DomainLifetimePeakBytes` are domain-wide, not per-owner allocations. Nested
durations can overlap; debugger waits are excluded. Function sampling and native
exclusive timings are not provided. Collection remains opt-in and bounded.

## Saved-source reload

The normal selective language reload and trusted editor `ReloadScripts(Array)`
stage every saved candidate and compile the whole bounded batch first. A syntax
or file failure publishes no revisions and preserves current generations.
Success publishes those exact snapshots through the existing module-dependent
and owner-generation invalidation. Limits: 256 resources, 1 MiB/file, 16 MiB total.
This provides validation rollback, not rollback of later gameplay side effects
or automatic state/scene migration. Successful replacement retires old native
handles/callbacks; reconstruct state explicitly.

## Native styling and traversal

```luau
local Scope = Scene.new(script.Parent)
local Style = Scope:New("Theme", {DefaultFontSize = 18})
Scope:Call(Style, "SetColor", "font_color", "Label", {R=0.9, G=0.97, B=1, A=1})
Scope:Call(Style, "SetFontSize", "font_size", "Label", 24)
local Label = Scope:New("Label", {Text="Expedition", Theme=Style})
```

Themes support default font/scale settings and bounded color, constant and
font-size operations. Keys/types are identifiers of at most 64 bytes, with
16 types/theme and 64 items/category/type; existing items remain updatable at
capacity. Missing getters fail before native dispatch. Loaded themes remain
immutable and handles remain generation/scope-owned. Foundry's Client interface
uses native theme inheritance without changing Server authority.

The same policy adds RichTextLabel.GetParsedText, Skeleton3D.GetBoneChildren /
GetParentlessBones and bounded obstacle height/3D-avoidance/navigation-mesh flags.
Generated declarations and the machine inventory describe the admitted surface;
invocation receipts and fixture/application assertions establish exercised scope.
Raw Callable/Signal/RID handles and unrestricted AnimationTree/viewport targeting
are not added.
