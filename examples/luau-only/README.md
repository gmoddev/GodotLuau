# Orb Run — new-project acceptance workload

This GL-052 project starts from a plain Godot scene and native LocalScript
resource association. Every developer gameplay/composition source is Luau;
there is no GDScript adapter or Relay Siege bootstrap.

With the extension staged in the project, open Main.luau in Godot and use the
Luau Authoring panel's Preview Luau action. The same source constructs a private
static preview without runtime services. Select a native node in the preview
hierarchy to inspect it; Save Preview As creates an independent native scene.
The original authoring scene/entrypoint stays distinct and is not overwritten.

Run Main.tscn through Godot. WASD/left stick rolls the physics orb; Space/ButtonA
jumps. Collect the three markers, then use Next Round to replace the owned native
scene with a new arrangement. Restart, UI signals, procedural audio and Quit use
native systems through Luau. Native Character control remains unchanged; this
small offline game uses an independent scoped RigidBody rather than a Character.

The reusable World module, project PackedScene, native gradient texture and
resource references exercise the new workflow. Physical gamepad support is an
API path, not a claim of physical-device qualification. The
[GL-052 journal](../../newdocs/gl-052-development.md) records actual editor, game,
export results and remaining gaps. This sample's existence is not qualification.
