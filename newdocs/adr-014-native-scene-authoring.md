# ADR-014: Owner-scoped native scene authoring

Status: accepted for implementation on `feature/luau-native-authoring`.
Baseline: `5d5bb84cfecfff46d7d5048db3171a199fd754be`.

The existing Instance bridge resolves Nodes through ObjectDB, converts scalar,
Vector3 and Color3 values, and discards non-Node constructor results. Relay Siege
therefore constructs meshes, materials, collision resources and presentation in
GDScript. Expanding unrestricted reflection would not establish resource ownership
or a reliable typed contract.

`Scene.new(Parent)` creates a native `SceneScope` owned by the current execution
owner. It uses the existing Server/Client VM, Godot hierarchy, ObjectID handles
and owner invalidation hook. Scope construction is permitted only beneath a
plain scene/bootstrap container, never beneath a Character, physics object or
network-owned gameplay subtree. Authored subtrees are process-local and excluded
from network identity/reference publication. Each process authors its environment;
this API does not replicate scene edits or confer Character authority.

`Scope:New(Class, Properties, Parent?)`, `Configure` and `Get` admit fixed native
families/properties with exact type and finite bounds. Validate a whole property
batch before changing native state. No arbitrary ClassDB or method invocation is
added. Nodes remain real Godot Nodes with existing Instance identity. Reparenting,
generic cloning and serialized restoration of live scope ownership are unsupported.
Reconstruct scenes from Luau on startup; no user project is rewritten.

Resources use a separate exact userdata type holding a shared ownership slot with
a Godot Ref. Ordinary GC releases the last handle when no native consumer retains
the resource. Scope retirement clears surviving slots, disconnects subscriptions
and queues its subtree for deletion. Retained handles cannot mutate another owner,
a replacement script generation or a Server resource from Client execution.
Loaded project resources are immutable through this API, including cache hits;
native consumers retain their ordinary Godot resource references.

Loading reuses GLProjectResourcePath and typed ResourceLoader checks, bounded
encoded input size and admitted classes. It remains trusted project loading:
serialized dependencies/import decoding are not a hostile-resource sandbox or a
hard decoded-memory/time bound. No external/user paths, PackedScene, scripts or
arbitrary resource classes are admitted.

Callbacks use existing GLReference dispatch and ObjectID-resolved native endpoints.
Owner retirement denies new operations before disconnecting; reentrant callbacks
must not access a deleted scope after dispatch. Limits cover scopes, nodes,
resources, properties, text, geometry tessellation and subscriptions.

This adds a construction/lifetime boundary, not a new scene graph, scheduler,
physics solver, network protocol or persistence authority. Native Character
control remains the default; Scripted remains explicit opt-in. Releases and
updater distribution remain disabled. Qualification status belongs in the
[development journal](native-authoring-development.md), not this decision.
