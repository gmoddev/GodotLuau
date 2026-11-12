# ADR-016: Explicit Luau editor authoring

Status: accepted for implementation on GL-052; qualification is recorded in the
[campaign journal](gl-052-development.md).

Use Godot's native LocalScript/ServerScript resource association for executable
Luau entrypoints. Do not claim arbitrary ScriptExtension attachment works while
the extension has no ScriptInstance implementation. Native editor actions can
create a plain native root, associate a Luau resource with its script child,
save/open the scene and select the source. Existing projects and `.lua` resources
remain supported. New authored sources use `.luau`.

Editor previews use an explicit EditorPreview execution domain with the existing
GLExecutionDomain scheduler, quotas and generation ownership. This is one editor
context, separate from the existing gameplay Server/Client VMs; it is not a new
runtime scheduler or a per-game-script VM. Do not run InitializeDomain's gameplay
bootstrap in it. Install only value types, policy-controlled Scene operations,
restricted owned-node handles and project-local module factories. No gameplay
services, filesystem capability, HTTP, persistence, networking or editor object
handles are admitted. Trusted project resource loading retains ADR-015's limits.

Only an explicit editor action evaluates the selected source. Construct under a
private root/driver, then present the result in a separate preview world. Never
run arbitrary opened scripts automatically. Construction must finish synchronously
within fixed preview limits; pending tasks/yields reject and retire the run.
Preview teardown retires callbacks/resources/owners before deleting its native
root. Syntax/runtime failures must leave the context usable for a later rebuild;
memory-exhausted contexts remain closed under GL-004.

Preview and authored project scenes have distinct identities. Explicit Save As
duplicates only authored native content into a plain native scene, sets Godot
owners and uses PackedScene/ResourceSaver. It serializes neither SceneScope nor
live VM capabilities, callbacks or execution generations. Save As refuses existing
targets rather than overwriting user edits. It grants no script-visible write
operation and is not gameplay DataStore persistence. Normal Godot editing and
scene saving apply after opening that independent saved scene.

The snapshot flattens instantiated PackedScene nodes into independently owned
native descendants. Clear their scene-instance paths before packing so the saved
file cannot both instantiate a source scene and serialize its expanded children.
Native resource references and the authored node properties/transforms remain;
later edits to the original PackedScene do not reconstruct a saved snapshot.

Godot stores Node3D position/rotation/scale as a native Transform3D in saved
scenes. Composition admits this serialization only for classes already allowed
those properties, with their existing position/positive-scale bounds, finite
values and a non-sheared right-handed basis. It does not expose a raw transform
setter or broaden node classes. Snapshot save clears the preview viewport's
implicit camera-current flag; explicit camera takeover remains denied.

The clean-project fixture and actual editor qualification must exercise these
production paths. Full breakpoint debugging, unrestricted reflection, resource
sandboxing and automatic migration are not implied by this decision. Releases
and updater distribution remain disabled; GL-050 is unchanged.
