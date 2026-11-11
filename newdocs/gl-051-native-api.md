# Policy-driven native authoring

This GL-051 branch extends the [qualified GL-049 API](native-scene-api.md).
[ADR-015](adr-015-policy-driven-native-bindings.md) defines the selection and
composition contract. The [campaign journal](gl-051-development.md) distinguishes
implementation from qualification. Nothing here grants arbitrary ClassDB,
filesystem, network or Character authority.

## One policy, runtime and tooling

[`NativePolicy.json`](../bindings/NativePolicy.json) selects approved classes,
public aliases, typed properties/methods/signals, loading types and enums. The
generator validates selections against the unchanged pinned godot-cpp 4.3
metadata, then emits C++ descriptors, [a catalog](../bindings/NativeCatalog.json)
and [Luau definitions](../GodotLuau/Types/Native.d.luau). The admitted host remains
4.7.1; newer-only APIs are not inferred. Construction additionally checks native
availability. A supported Variant-shaped member normally needs a policy entry
and focused runtime coverage, rather than another hand-written binding.

```text
python tools/GenerateNativeBindings.py
python tools/GenerateNativeBindings.py --check
python tests/bindings/NativePolicyTests.py
```

The build rejects generated drift. Unsupported signatures, varargs, structural
mutation and unrestricted Object dispatch fail selection. Numeric/resource bounds
and exact live execution ownership remain runtime requirements even with types.

`Scene.Classes()` lists admitted classes and their base closure.
`Scene.Describe(Name)` returns detached metadata or nil, including inheritance,
construction/availability, property bounds and typed methods/signals. Discovery
does not make a base class constructible. Editing a description grants no
capability. `Scene.Enums` contains approved constants; it and Scene are readonly.
Policy/API SHA256 values identify generated inputs.

## Coverage

There are 48 constructible classes, 118 property entries, 27 selected native
methods and 12 signals. Inheritance expands usable members without duplicating
policy entries. The generated catalog is the exact list.

| Area | Additions to GL-049 |
| --- | --- |
| Presentation | TextureRect, Sprite2D/3D, native texture/material slots; margins, grids, scroll/center containers; check buttons, sliders and progress bars |
| Layout | Bounded anchors, offsets, layout/grow/focus modes, clipping and existing size/position presets |
| Resources | Plane/Quad/Cylinder/Capsule meshes, Capsule/Cylinder shapes, Font/PackedScene loading, native font overrides and shared texture references |
| Calls | Selected transforms, visibility, focus, text/range/button operations, audio, texture/mesh queries and mutable material roughness |
| Signals | Pressed/text-submitted/audio-finished plus boolean toggles, text/number changes, button up/down, focus, visibility and resize |

`Scope:Call(Target, PublicMethod, ...)` checks owner, member, arity, types and
bounds before native invocation. Optional arguments use pinned checked defaults.
Raw native method names do not bypass selection. Loaded/getter resources remain
immutable, including calls. Void calls return no values; scalar/vector results
are checked before conversion. Existing Play/Stop/Impulse/Mesh/Pin/Tone remain.

Handles retain Godot Ref ownership. Repeated loads share Godot's cache; live
handles compare resource identity under their scope. Get/Load return opaque
readonly resources, without raw Resource objects, paths or engine singletons.

## Composition

```luau
local Scope = Scene.new(script.Parent)
local Template = Scope:Load("PackedScene", "res://Scenes/Relay.tscn")
local First = Scope:Instantiate(Template)
local Copy = Scope:Clone(First)
Scope:Reparent(Copy, First, true) -- preserve global transform
```

Instantiate preflights SceneState before creating nodes: classes and stored
properties must be approved and fit the existing 2048 live-node and 32-level
bounds. Stored scripts, groups, connections and nested/inherited scenes reject.
Resource graphs have bounded inspection and reject scripted resources. Nodes are
adopted into the live scope before tree entry. Clone uses native duplication
without scripts/groups/signals/packed-instance flags; resources keep normal
shared Ref semantics. Reparent/Clone require live, fully owned subtrees within
one scope. Cycles, foreign/privileged targets and stale generations reject.

Pass the caller's scope and resources into reusable Luau module factories.
Module caches should retain factory code rather than live owner capabilities.
[RelayFactory.luau](../examples/e2e-game/RelayFactory.luau) is the production
example. Script retirement disconnects subscriptions, releases handle refs and
deletes the scope. Yielded callbacks use existing owner-aware cancellation.

Live execution scopes/callbacks cannot be saved as a restart-safe ownership
format. There is no scene-save/filesystem capability. Replay factories or load
approved PackedScenes instead. Nested scene inheritance needs a separate
preflight contract; it is not silently flattened or instantiated.

Loading is synchronous trusted `res://` loading with existing top-level encoded
size/path checks. It does not bound decoded assets/dependency I/O or isolate
hostile resources. Async loading is deferred until bounded owner-aware completion
and cancellation exist. Yielding around a synchronous load would not make disk
work nonblocking.

## Editor and types

Use Native.d.luau as a language-server definition file; never execute/require it.
It models inherited classes, literal constructor/property/getter/method/signal
overloads, optional arguments, nullable resources and readonly handles. It covers
Scene, not every Roblox compatibility global. A separate pinned Luau checker
qualifies definitions without an Analysis dependency in the native runtime.

Godot's actual language completion/validation hooks share bounded AST/native
policy inspection. They complete known native constructors, properties, calls,
signals and getters, and report obvious unknown members, literal type/bounds,
arity and immutable-handle errors with source locations. Dynamic child lookup
and unrelated legacy completion remain. Analysis never executes game code.
`LuauScript.InspectNativeCode(Code, Path)` exposes the same readonly analysis.

An editor-only plugin configures the existing ScriptEditor CodeEdit for Luau's
colon member syntax through public APIs. Godot's default prefix set lacks `:`.
The plugin applies only to Luau tabs, keeps no tab/resource pointers and uses
ordinary deferred editor callbacks with explicit signal cleanup. It changes no
engine build, project settings or desktop focus.

Inference is partial: it is not a full embedded type checker, flow-sensitive
language server or debugger. Runtime errors retain script identity; the existing
debug-stack callback remains unimplemented. Stepping, breakpoints and live stack
inspection are not supplied by completion support. Full static checking uses the
external generated-definition workflow.
