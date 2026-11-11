# ADR-015: Policy-driven native bindings and scene composition

Status: accepted; implemented and [qualified within recorded scope](gl-051-qualification.md)
on unmerged `feature/gl-051-first-class-luau`.
Baseline: `c60919a42416d5e6c72d2b23f7801500879c3195`.

GL-049 establishes exact execution-generation ownership, real ObjectID-backed
Nodes and Ref-backed resource handles. Preserve that boundary. A second object
registry, VM or scene graph is unnecessary. Its manually maintained constructor,
property and signal tables are the scalability barrier addressed here.

A versioned declarative policy selects approved classes and members, aliases,
argument/property bounds, construction/loading permissions and mutating versus
observational operations. Generation validates selections against the unchanged
pinned godot-cpp extension metadata, then emits runtime descriptors, Luau
declarations and editor metadata from that same policy. The pinned metadata is
Godot 4.3; admitted runtime hosts remain the existing 4.7.1 profiles. Newer-only
engine APIs are not inferred from the runtime version or advertised implicitly.

Discovery reports admitted metadata; discovery itself grants no execution
permission. Construction uses only approved constructible class descriptors.
Reads/writes/calls/connections validate the live scope, owner, target, types and
policy before touching native state. No raw ClassDB, arbitrary method, property
name, filesystem path, ObjectID or callback target is exposed as a capability.
Legacy GL-049 names and bounds remain supported.

Method signatures, defaults, signals, enum values and inheritance come from
metadata. Explicit policy bounds supplement those types. Unsupported Variant
forms, varargs and unrestricted Object methods fail generation or runtime
admission. Native callbacks validate and copy bounded values before existing
owner-aware dispatch; owner retirement disconnects them before releasing refs.
Loaded and getter resources remain immutable, including mutating method calls.

PackedScene admission remains trusted project loading, not hostile-asset
isolation. Before instantiation, inspect SceneState: enforce node/depth budgets,
approved native classes/properties and no scripts, stored signal connections,
groups or unreviewed nested/inherited scenes. Adopt every resulting Node under
the existing scope before tree entry. Reparent/clone operations stay within the
same live scope and preserve native identity/lifetime rules. No gameplay or
network-owned hierarchy becomes authorable through this API.

Live scopes, callbacks and owner capabilities are not a serializable persistence
format. Do not restore those from scenes. Reusable Luau module factories and
approved project PackedScenes provide composition; writing scenes/resources
would require a separately defined storage authority and is outside this change.
Synchronous trusted resource loading is retained initially. Async admission
requires a bounded owner-aware completion/cancellation contract first.

Editor completion uses generated policy data rather than advertising arbitrary
Godot members. Generated declarations describe actual admitted APIs, including
nullable handles and overloads where Luau can represent them. Syntax/type or
binding diagnostics must preserve source locations and never execute game code
to obtain completion. This does not replace Godot's editor or promise a native
debugger where the existing ScriptLanguageExtension does not implement one.

Native controller defaults, Scripted opt-in, domains, networking, persistence,
dependency pins and admitted hosts are unchanged. GL-050 remains separate.
Qualification and implementation progress belong in the campaign journal.
No main merge, release publication or updater distribution is authorized.
