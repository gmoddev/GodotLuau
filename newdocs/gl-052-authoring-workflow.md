# Luau-first native authoring workflow

GL-052 is an unmerged implementation campaign. See the
[qualification record](gl-052-qualification.md) for qualified inputs and remaining
interactive input gap, and the [journal](gl-052-development.md) for failures.
There is no published fork release or updater channel. Use an explicitly verified
non-publishing candidate; test adapters include qualification hooks and are not
distribution products.

## Start with a new native project

Create a project in Godot 4.7.1 with the Compatibility renderer. Extract the
verified candidate into the project root, retaining its root `.gdextension`,
`GodotLuau` directory, platform libraries as supplied, persistence companion and
generated `Types` directory. Leave its updater plugin disabled. Open/reopen the
project so Godot scans the extension.
The native Luau Authoring panel registers automatically; no GDScript addon,
autoload or developer bootstrap script is needed. Do not substitute an arbitrary
Godot executable for the admitted runtime when qualifying multiplayer.

Open the **Luau Authoring** bottom panel and choose **New Luau Scene**. Select a
fresh project path such as `res://Main.tscn`. The action creates that native scene
and `Main.luau`, associates the source with a native LocalScript child named
Main, and opens both. It sets the project's main scene only if none was selected.
Neither an existing scene nor its companion source is overwritten. If the second
save fails, the source remains available for recovery.

The root is an ordinary Node3D. LocalScript's `codigo_luau` resource is the
executable association; arbitrary attachment of LuauScript to a native Node is
not supported. Use ServerScript for established server-domain entrypoints.
`.lua` remains readable; newly authored sources use `.luau`. Do not rename user
project content automatically.

## Compose, inspect and save

For example, an entrypoint may construct an owned native scene:

```luau
local Scope = Scene.new(script.Parent)
local Material = Scope:New("StandardMaterial3D", {Color = Color3.new(1, 0.6, 0.2)})
Scope:New("MeshInstance3D", {
    Mesh = Scope:New("BoxMesh", {Size = Vector3.new(1, 1, 1)}),
    Material = Material,
})
Scope:New("DirectionalLight3D", {RotationDegrees = Vector3.new(-45, 0, 0)})
Scope:New("Camera3D", {Position = Vector3.new(0, 2, 5), RotationDegrees = Vector3.new(-20, 0, 0)})
```

**Preview Luau** evaluates the selected source explicitly. It creates a private
static world and hierarchy, separate from the edited scene and gameplay domains.
Select a preview hierarchy item to use Godot's native Inspector. Changing source
clears the old preview; rebuild explicitly. **Clear Preview** retires it.
**Reset Context** creates a fresh editor context on its next use. Preview does
not simulate physics, play audio, initialize gameplay services, write storage or
make network requests. It rejects asynchronous/yielding construction and applies
fixed execution/memory/resource limits. An exhausted context does not silently
restart. [ADR-016](adr-016-luau-editor-authoring.md) defines this boundary.

**Save Preview As** writes a fresh independent `.tscn` through Godot's native
PackedScene serializer. It preserves authored native nodes, resource references
and transforms, replacing transient SceneScope roots with plain native roots.
It does not serialize live callbacks, capabilities or execution generations.
Instantiated PackedScene nodes become independently owned snapshot content; their
instance paths are cleared so expanded children are not loaded twice. Native
resource references remain; changes to the original scene do not rebuild a snapshot.
Open that scene for ordinary native editing and saving. Keep the source scene
for procedural reconstruction; rebuilding it does not overwrite saved user edits.
Saving a preview is not a live synchronization or merge system.

Reuse project-local modules as factories:

```luau
-- World.luau
return function(Scope: NativeSceneScope)
    return Scope:New("Node3D", {Name = "World"})
end
```

```luau
-- Main.luau
require("res://World.luau")(Scene.new(script.Parent))
```

String imports use explicit project `.lua`/`.luau` paths and the existing shared
domain module evaluator/cache. They do not admit `user://` or arbitrary files.
Pass the caller's scope into factories; a project resource module has no Node
`script`. Explicit resource reload advances its revision. Preview reconstruction
retires all preview module initializers/results. Native PackedScenes, resources,
reparenting, lookup and supported transforms retain the
[Scene API](native-scene-api.md) and [GL-051 policy](gl-051-native-api.md).
Opaque native Resource handles use `Scope:Configure(Resource, Properties)`.
Godot text-resource export remaps are followed for the encoded-input check with
bounded metadata and the same project-path/16 MiB target constraints. This does
not provide hostile-resource isolation or promise every importer feature variant.

## Edit, run and recover

The normal Godot ScriptEditor supplies Luau highlighting and bounded diagnostics,
approved native completion and documentation. Source lookup supports top-level
named functions, explicit project module paths and approved native classes.
Generated `GodotLuau/Types/Native.d.luau` supplies external type definitions.
This is not a complete embedded Luau type checker, formatter or breakpoint
debugger. File inheritance and arbitrary ScriptInstance attachment are not
advertised. Automatic indentation currently preserves source unchanged.

Run the native main scene using Godot's Play action. LocalScript/ServerScript use
the established shared gameplay domains, generation ownership and teardown.
Changing a loaded resource's source or explicitly reloading it retires the old
owner through the existing lifecycle. Stop, edit and rerun normally. File watchers
do not imply automatic invalidation of every dependent project module.

Runtime chunks carry project source paths. When connected to Godot's debugger,
the native panel receives bounded source, error and stack information.
**Open Runtime Error** navigates explicitly; an error does not take focus
automatically. Preview errors appear in the panel and leave later rebuilds usable
unless the context exhausted its memory budget. Inspect the first source error,
correct it, then rebuild/rerun. Breakpoints and single stepping are not implemented.

## New game and export

[Orb Run](../examples/luau-only/README.md) is a new small native game. Its gameplay
and composition sources are entirely Luau. World is a factory module; Marker is
a native reusable scene; Pattern is a native texture. Movement, jumping,
collection, round transition, restart, audio and UI use production native APIs.
The example does not change Character V2 or the Native/Scripted controller policy.

`examples/luau-only/PrepareProject.py --candidate <directory> --output <fresh-path>`
stages that game from a verified candidate and checks its native source identity.
Supply `--engine <existing-admitted-template> --host-manifest <manifest>` to create
an explicit Windows export preset. This stages existing inputs; it does not
download or install templates, enable releases or activate the updater.
Adapter mode is explicitly qualification-only. Open/import the staged project in
the native editor before normal play or export so Godot records the extension.

Use Godot's normal **Project → Export** workflow. The explicit custom template
must match the intended profile; `.lua` and `.luau` sources are included. Keep
the extension libraries and companion beside the exported application as emitted
by Godot. Launch from an independent directory without source-tree paths.
Windows accepted-candidate export and independent startup pass in
[run 43164852674](https://github.com/gmoddev/GodotLuau/actions/runs/43164852674).
The [qualification record](gl-052-qualification.md) separately records actual
Windows rendering, passing fresh-process reopen checks and the remaining input gap. A staging
preset or successful headless game run alone does not qualify those workflows.

GL-050 remains unresolved and separate. Existing headless evidence does not
establish physical gamepad, Linux rendering or unavailable interactive UI behavior.
