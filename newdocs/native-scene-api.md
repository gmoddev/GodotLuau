# Native scene authoring API

This records the qualified GL-049 surface. The unmerged GL-051 campaign extends
it with [policy-driven bindings, resources, composition and tooling](gl-051-native-api.md);
see that branch's journal for fresh qualification status.

Implementation/qualification work is tracked in the
[journal](native-authoring-development.md). [ADR-014](adr-014-native-scene-authoring.md)
defines ownership. This surface is opt-in; existing Instance APIs are unchanged.
The [qualification record](native-authoring-qualification.md) separates supported
native behavior, rendered gameplay and remaining platform/package limits.

```luau
local Scope = Scene.new(script.Parent)
Scope.Name = "Arena"
local Shape = Scope:New("BoxShape3D", {Size = Vector3.new(8, 1, 8)})
local Body = Scope:New("StaticBody3D", {Position = Vector3.new(0, -1, 0)})
Scope:New("CollisionShape3D", {Shape = Shape}, Body)
local Mesh = Scope:New("BoxMesh", {Size = Vector3.new(8, 1, 8)})
local Material = Scope:New("StandardMaterial3D", {
    Color = Color3.new(0.2, 0.5, 0.8), Roughness = 0.8,
})
Scope:New("MeshInstance3D", {Mesh = Mesh, Material = Material}, Body)
```

The parent must be the executing script's native parent, with a plain bootstrap
container ancestry. Scope ownership is the exact execution generation, including
Server/Client identity. A script completing its initial chunk keeps its scope;
disable/reload/destruction retires it. Ordinary Node wrappers retain ObjectID
identity. Safe scalar/transform reads and hierarchy queries are observable by
other scripts; mutation, resources and scope operations require the creator.
This first slice admits ancestry made from Node, Node3D, RobloxWorkspace, Folder
and the root Window. Native template-specific root classes, SubViewport and
authoring beneath Player/Character hierarchies are outside this admission profile.
Properties are checked at runtime; this change does not regenerate editor/analyzer
declarations or promise static typing for arbitrary native classes.
Position, RotationDegrees and Scale use local Godot coordinates, including when
these authored Nodes are reached through ordinary Instance hierarchy queries.
Raycast result positions remain world coordinates. Existing Character/Part
transform aliases are unchanged; arbitrary global-transform setters are not
part of this slice.

| Operation | Contract |
| --- | --- |
| `Scene.new(Parent)` | Create owner-scoped Node3D subtree; errors on foreign/privileged parent. |
| `Scope:New(Class, Properties, Parent?)` | Create a fixed native Node or Resource; Node parent defaults to Scope and must be inside it. Validate before attaching. |
| `Scope:Configure(Target, Properties)` | Validate the entire batch before native setters. Bad input leaves previous values intact. Native notifications may destroy a target during application. |
| `Scope:Get(Target, Property)` | Read an admitted property; resource results are immutable handles. |
| `Node:Destroy()` | Owner-only queued deletion; destroying Scope retires all its handles/subscriptions. |
| `Scope:Mesh(Primitive)` | Bounded primitive-to-ArrayMesh copy for native soft bodies; immutable result. |
| `Scope:Pin(SoftBody, Vertex, Pinned)` | Native pin operation on one-surface active mesh, validated vertex index. |
| `Scope:Impulse(RigidBody, Vector3)` | Finite central impulse on a body created in this scope. No Character/body lease is granted. |
| `Scope:Tone(Frequency, Seconds)` | Immutable mono 22050 Hz 16-bit decaying sine WAV; 20–20000 Hz, 0.001–1 second. |
| `Scope:Play(AudioPlayer)` / `Stop` | Native playback, with a live scoped target. |
| `Scope:Connect(Node, Signal, Callback)` | `Pressed` on Button, `TextSubmitted` on LineEdit, `Finished` on AudioStreamPlayer. Returns `Disconnect()` and dynamic `Connected`. |
| `Scope:Load(Type, Path)` | Immutable project-only Texture2D, AudioStream or Mesh; admitted path and encoded file ≤16 MiB. |

Nodes support `Name`, `Parent` (read only), native `ClassName`, `IsA`,
`FindFirstChild`, `GetChildren`, `GetDescendants`, `Destroy`, and the properties
below. Direct property writes follow the same validation as Configure. No
generic method invocation, arbitrary property fallback, reparent, Clone, scene
save or ownership restoration is exposed. FullRect is a write-only layout preset.

| Family | Properties (in addition to inherited admitted properties) |
| --- | --- |
| Node3D | Position, RotationDegrees, Scale, Visible |
| MeshInstance3D | Mesh, Material |
| StaticBody3D | CollisionLayer, CollisionMask |
| RigidBody3D | CollisionLayer, CollisionMask, Mass, GravityScale, Freeze |
| CollisionShape3D | Shape, Disabled |
| DirectionalLight3D / OmniLight3D / SpotLight3D | Color, Energy, ShadowEnabled; Range on Omni/Spot |
| Camera3D | Fov, Near, Far; camera takeover/Character follow leases are not provided here |
| WorldEnvironment | Environment |
| Label3D | Text, Billboard, FontSize |
| CanvasLayer | Layer |
| Control / ColorRect / PanelContainer / VBoxContainer / HBoxContainer / Label / Button / LineEdit | Position, Size, MinSize (Vector2); Visible, MouseFilter, Modulate, FontSize, FullRect. Color on ColorRect; Separation on VBox/HBox; Text on Label/Button/LineEdit; PlaceholderText on LineEdit. |
| AudioStreamPlayer | Stream, VolumeDb, PitchScale |
| SoftBody3D | Mesh (ArrayMesh), Material, CollisionLayer, CollisionMask, SimulationPrecision, TotalMass |
| BoxMesh / BoxShape3D | Size |
| SphereMesh | Radius, Height, RadialSegments, Rings |
| SphereShape3D | Radius |
| StandardMaterial3D | Color, Roughness, EmissionEnabled, Emission |
| Environment | BackgroundMode (1/color), BackgroundColor, AmbientLightSource (2/color), AmbientLightColor, AmbientLightEnergy |

Numeric properties reject NaN/infinity and out-of-range values. Positions allow
±100000, rotations ±360000 degrees, scales 0.001–100, shape dimensions
0.001–10000, colors 0–1, light energy 0–64, mass 0.01–10000, collision masks
whole unsigned 32-bit values. UI sizes are 0–100000, font sizes 1–256, text
≤8192 UTF-8 bytes (names ≤128). Sphere tessellation is bounded to 64 radial
segments and 32 rings. Mesh conversion and pins admit at most 8192 vertices.
Scopes admit 2048 live Nodes, 1024 live resource handles, 128 subscriptions,
32 properties per batch and 32 authored hierarchy levels. The process admits
256 scopes. These native bounds supplement existing VM execution/memory limits.

Resource GC releases its Ref slot; assigned consumers hold their normal Godot
Refs. Retirement clears surviving handle slots, disconnects subscriptions, then
queues native subtree deletion. Native consumers may retain resources until that
deletion fence. Loaded/cache-hit resources and resources obtained through getters
cannot be configured. Subscriptions share existing execution ownership: destroying
the script cancels suspended callbacks; source deletion prevents future delivery.
Callbacks already executing belong to their script and may finish if only their
source is removed. Partial application interrupted by native destruction does not
roll back arbitrary external notification effects.

Physics operations retain Godot initialization rules: allow physics frames after
constructing/configuring a body and shape before mass-dependent impulses. An
impulse issued during construction can use the engine's initial inverse mass.
The API does not add a second physics scheduler or silently defer commands.

Loading remains synchronous trusted project loading. The encoded size bound
does not bound decoded/imported dependencies or make hostile Godot resources
safe. PackedScene, scripts, external/user paths, arbitrary resource subclasses,
resource saving and asynchronous loading are unsupported. Texture loading is a
typed reference foundation; texture display/material texture configuration is
not yet admitted. Serialization/cloning of live scopes is unsupported; replay
the Luau scene description instead. Local soft-body configuration is not vertex
replication. Nothing in this API changes native Character, network, persistence,
release or updater authority.

## Native UI and audio example

In a LocalScript beneath a plain bootstrap Node, create controls and subscribe
through the same owner scope. No GDScript signal adapter is required:

```luau
local Scope = Scene.new(script.Parent)
local Layer = Scope:New("CanvasLayer", {Name = "Interface"})
local Button = Scope:New("Button", {
    Text = "PLAY TONE",
    Position = Vector2.new(24, 24),
    MinSize = Vector2.new(200, 48),
}, Layer)
local Audio = Scope:New("AudioStreamPlayer", {
    Stream = Scope:Tone(440, 0.12),
    VolumeDb = -12,
})
local Connection = Scope:Connect(Button, "Pressed", function()
    Scope:Play(Audio)
    Button.Text = "PLAY AGAIN"
end)

-- Connection:Disconnect() ends this subscription early.
-- Scope:Destroy() retires the entire authored subtree early.
-- Script disable/reload/destruction also retires its scopes automatically.
```

See [Presentation.luau](../examples/e2e-game/Presentation.luau) for live menus,
layout, results, audio and input consumption, and
[Arena.luau](../examples/e2e-game/Arena.luau) for shared materials, geometry,
collision, lights and bounded soft-body pins. Those examples consume existing
game snapshots; the scene API does not grant gameplay authority.
