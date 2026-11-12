# Native API expansion contract

Unmerged GL-053 campaign extension of [ADR-015](adr-015-policy-driven-native-bindings.md).
Qualification status lives in the [journal](gl-053-native-development.md).
The generated [catalog](../bindings/NativeCatalog.json) is the exact admitted
surface; [coverage](../bindings/NativeCoverage.json) is an inventory, never a grant.

## Shared dispatch

Every class/property/method/signal policy entry explicitly declares OwnedScene
authority. Existing exact owner/domain, mutable owned-resource and stale-object
checks apply before dispatch. Metadata discovery grants no reflection authority.
Window, Viewport, SceneTree, arbitrary Object, scripts, RIDs, Callables and native
Signal objects remain unavailable. Owned Node arguments and results stay within
the same live SceneScope; foreign signal-node arguments become nil.

Property resolution selects the most derived approved descriptor. Observation
properties such as Timer.TimeLeft, ItemList.ItemCount and sprite frame state are
read-only, including constructor and Configure batches. Failed validation leaves
the batch unapplied. Configure is not a transaction across native notifications.

Methods accept at most eight checked arguments, with metadata-verified scalar,
string/StringName, null resource/node and Vector2 defaults. Collection operations
validate their live index, existing/absent name and capacity before invocation.
ItemList has at most 1,024 items; SpriteFrames has at most 16 animations and 64
frames per animation; Gradient has at most 256 points. Native const metadata
determines immutable-resource eligibility; some native observation methods are
non-const and therefore still require an owned mutable resource.

## Pure values

Scene.Value(TypeName, Value) copies, validates and freezes a pure native value.
Tags distinguish compound values inside Variant/collections; a tag is not an
object handle. Existing Vector3 userdata and Color3 properties remain compatible.
Vector2 remains an X/Y table. New representations are:

| Native type | Luau fields |
| --- | --- |
| Vector2i / Vector3i / Vector4 / Vector4i | X, Y, Z, W as applicable |
| Quaternion | X, Y, Z, W |
| Color | R, G, B, A, each in [0,1] |
| Rect2 / Rect2i / AABB | Position, Size; AABB size is nonnegative |
| Basis | X, Y, Z Vector3 columns |
| Transform2D | X, Y, Origin Vector2 columns |
| Transform3D | Basis, Origin |
| Plane | Normal, D |
| Array / packed arrays | Dense one-based sequence |
| Dictionary | Bounded string keys; __NativeType is reserved |

Packed byte, int32, int64, float32, float64, string, Vector2, Vector3, Color and
Vector4 arrays are supported. Integers must be losslessly representable as Luau
numbers, with descriptor bounds applied as well. Arbitrary full-width int64
fidelity is not promised. Conversions reject nonfinite numbers, cycles, holes,
mixed array/map keys, functions, foreign userdata and unsupported native values.
Bounds: depth 8, 4,096 visited cells, 1,024 collection elements, 8,192 UTF-8 bytes
per string; dictionary input keys are at most 128 bytes. The new pure-value
converter returns recursively immutable tables. Existing Vector2 properties
retain their ordinary copied X/Y table representation. No Object/Resource
authority travels inside pure Variant.

```luau
local S = Scene.new(script.Parent)
local Frames = S:New("SpriteFrames", {})
S:Call(Frames, "AddAnimation", "pulse")
S:Call(Frames, "AddFrame", "pulse", S:Load("Texture2D", "res://Icon.tres"))
local Sprite = S:New("AnimatedSprite2D", { SpriteFrames = Frames })
S:Call(Sprite, "Play", "pulse")
local Timer = S:New("Timer", { WaitTime = 0.5, OneShot = true })
S:Connect(Timer, "Timeout", function() print("[Game:Timer] elapsed") end)
S:Call(Timer, "Start")
```

## Effects and resource workflows

Timer and audio/sprite playback are runtime-only. EditorPreview also rejects
active autostart/autoplay through New, Configure, direct writes and PackedScene
preflight. Static scene/resource inspection retains the existing preview scope.

MultiMesh has at most 256 instances. Allocation format and UseColors are applied
before InstanceCount in one validated batch. Reset InstanceCount to zero in a
separate operation before changing an allocated format. Per-instance methods
check the live count, dimension and color allocation. Transform/AABB values stay
bounded; raw GPU buffers and RIDs are not exposed.
VisibleInstanceCount cannot exceed the final validated InstanceCount and is applied
after allocation. Sprite playback custom speed is bounded to [-16,16].

Shader is load-only from project assets. An owned ShaderMaterial may set declared
scalar, vector, RGBA and matrix uniforms with exact native type checks. Unknown
uniforms, texture/Object and array uniforms are rejected. At most 256 declared
uniforms and 256 distinct written names per material lifetime are admitted; scope
bookkeeping is bounded by the existing resource limit. Shader source mutation,
arbitrary include synthesis and global renderer access are not admitted. Loaded
and getter-derived resources remain immutable.

2D bodies, areas and collision shapes use Godot's native physics and existing
main-thread dispatch. This phase does not grant physics-server/RID access or
promise deterministic simulation. Direct space queries and character movement
phase synchronization are described in the later gameplay section below.

## Gameplay expansion (qualification pending)

Standalone native CharacterBody2D/3D exposes bounded velocity/configuration and
MoveAndSlide/observed contacts. MoveAndSlide and forced RayCast2D/3D updates require
a runtime physics callback, such as existing RunService.Stepped. Calling them from
ordinary process callbacks or preview rejects. These nodes do not replace or
change RBXCharacter's Native/Scripted controller ownership or replication.

Raycasts expose checked collision masks, hit positions/normals and same-scope
exceptions. GetCollider projects native Object results into an optional owned
CollisionObject node: foreign world hits remain observable spatially but return
nil as a handle. No RID, direct-space-state or arbitrary Object is returned.

NavigationRegion3D accepts immutable project NavigationMesh resources.
NavigationAgent3D path observations run only during physics and after the native
map's first synchronization. Retry on Scene:Phase while the map initializes.
Paths use the shared bounded PackedVector3Array conversion. Avoidance/server RID
mutation, dynamic baking and path metadata containing native capabilities are
not exposed. Native navigation/physics remains world-owned by Godot.
The host must include Godot's navigation module. Existing admitted GL-018/029
headless profiles omit it and reject path operations as unsynchronized; they do
not gain navigation through a Luau binding. Actual path qualification uses the
verified official full-featured host separately from those sanitizer profiles.

Skeleton3D supports up to 128 uniquely named bones, topologically ordered parent
assignment and bounded position/unit-quaternion/positive-scale poses and rest
transforms. Bone indices are validated against the live skeleton before calls.
SetBoneParent requires parent index less than child index (-1 means no parent),
which prevents cycles. Singular/mirrored rest bases reject. This enables
procedural animation; imported dynamic bone-property serialization, physical-bone
simulation and arbitrary AnimationPlayer tracks are separate unsupported paths.

## Editor productivity

The existing syntax/metadata analyzer now completes enum families/constants and
pure Scene.Value type names. Method suggestions and native call hints include
actual pinned argument names, value/resource types, defaults and return types.
Observation writes have source-located E_NATIVE_READONLY diagnostics. Local Scene
shadowing suppresses global enum/value inference. Runtime checks remain the
authority; these bounded syntax diagnostics are not a complete Luau typechecker.
Generated declarations continue to be checked by the actual pinned Luau frontend.
Editor previews receive their own World2D as well as their existing World3D.

Debugging still uses bounded runtime errors/tracebacks with source and domain
identity, native call errors, explicit preview error recovery and the existing
timing/resource observations. Godot editor breakpoints, stepping and suspended
local inspection are not implemented. The language extension currently returns
an empty `_debug_get_current_stack_info`; it has no bridge that safely suspends
and resumes the shared-domain scheduler for a debugger. That is a separate
runtime/debugger integration task, not a claimed engine prohibition or a feature
provided by completion/navigation. The bounded existing diagnostics remain the
supported debugging path.

## Native value-track animation

[ADR-017](adr-017-owned-native-animation.md) admits ordinary AnimationPlayer,
AnimationLibrary and Animation construction through the same Scene API. Create
the owned target hierarchy, add TYPE_VALUE tracks, set relative native property
paths and insert bounded typed keys, then attach a library and play its clip.
Attached clips/libraries are sealed against mutation through every alias.

```luau
local Stage = S:New("Node3D", {})
S:New("MeshInstance3D", {Name="Visual", Mesh=S:New("BoxMesh", {})}, Stage)
local Player = S:New("AnimationPlayer", {}, Stage)
local Clip = S:New("Animation", {Length=1})
local Track = S:Call(Clip, "AddTrack", Scene.Enums.Animation.TrackType.TYPE_VALUE)
S:Call(Clip, "TrackSetPath", Track, "Visual:position")
S:Call(Clip, "TrackInsertKey", Track, 0, Vector3.new(0,0,0))
S:Call(Clip, "TrackInsertKey", Track, 1, Vector3.new(2,0,0))
local Library = S:New("AnimationLibrary", {})
S:Call(Library, "AddAnimation", "move", Clip)
S:Call(Player, "AddAnimationLibrary", "", Library)
S:Call(Player, "Play", "move")
```

NodePath values use bounded strings; a path confers no node/filesystem authority.
Simple typed native array observations retain their element type in generated
signatures and immutable sequence outputs. Typed-array inputs and native object
collections remain restricted. AnimationPlayer's bounded relative value-track
path does not admit AnimationTree, arbitrary rig tracks, method/audio tracks,
root motion, native Tween/Callable handles or automatic playback during preview.
Runtime qualification is pending; this section documents the implemented contract.

## Nested and inherited PackedScenes

Scene.Instantiate now preflights native nested instances and inherited overrides
recursively before Godot constructs any node. An ephemeral metadata map resolves
inherited class identities; it is discarded before instantiation and is not a
second runtime graph. The final native tree still passes existing adoption and
ObjectID/lifetime checks. Combined expansion remains within 2,048 scope nodes,
32 hierarchy levels, 16 nested resource levels and 16,384 metadata entries.
Scripted nodes, stored connections, groups, placeholders, unresolved overrides,
capability classes and out-of-bounds properties reject across the entire chain.
Node2D's serialized radian rotation is checked against its approved degree bounds.

These scenes use ordinary Godot PackedScene/SceneState resources. Instantiation
preserves native shared resources and inherited property overrides; the existing
editor snapshot Save As still flattens content into an independent scene under
ADR-016. It does not preserve live inherited linkage in that independent snapshot.

## Module navigation and reload

Godot's existing lookup hook now resolves project require aliases and exported
function members, including local function aliases in returned tables. It uses
the pinned Luau AST and reads at most 1 MiB from an explicit valid res:// .luau/.lua
target. It never evaluates the module or loads arbitrary Script resources.
Cursor-aware lexical lookup preserves shadowed local identity and returns up to
128 source-local references. The inspectable LuauScript.NavigateNativeCode API
uses the same hook implementation for qualification and editor tooling.

Dynamic imports/exports, full project-wide semantic reference search and a live
language-server index remain unsupported. Existing generated definitions are
checked with the real pinned Luau frontend; bounded syntax inference does not
claim to replace whole-program type analysis. Transitive runtime module reload
behavior and retained snapshot semantics are recorded under GL-054 in the journal.

## Native starter scenes

The authoring panel's existing New Luau Scene action now offers 3D (the existing
default), 2D, UI and Empty. CreateLuauScene(Path, Profile?) preserves one-argument
callers and rejects unknown profiles before writing. Empty/2D/UI use a plain Node
bootstrap; 3D retains Node3D. Both retain a real LocalScript .luau entrypoint and
owned SceneScope content. Existing projects are never overwritten.

Canonical sources live under GodotLuau/DefaultScripts/NativeAuthoring and are
embedded by the existing template generator. The 2D starter uses real
CharacterBody2D physics, keyboard/gamepad actions and jump requests. The UI starter
uses native tabs, lists, text entry, tooltips, keyboard focus and signals. Preview
constructs static content without entering gameplay services. FullRect layout
presets apply before explicit offsets in validated batches.

The qualified Relay Siege project remains the multiplayer starting point;
the new-scene selector does not synthesize multiplayer authority or deployment.
These starter templates are not substitutes for the campaign's acceptance projects.
