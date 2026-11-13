# Current architecture

The unmerged [GL-055 debugger campaign](gl-055-debugger-development.md) implements
live Luau execution control through Godot's supported debugger loop under
[ADR-018](adr-018-native-luau-debugger.md). Windows/Linux native protocol/editor
journeys pass within their [recorded source scopes](gl-055-debugger-qualification.md),
including selective reload, opt-in profiling and weak ownership diagnostics.
Final core/native, production Debug/Release, candidate/package and available
Windows/Linux sanitizer profiles pass within those scopes. External engine-editor
cleanup and synchronous large-index latency remain explicit limits. This does not change the
integrated-main qualification claims below or turn error snapshots into live state.

The normally [merged GL-054 campaign](gl-054-main-integration.md) extends the
same dispatcher with typed scoped collections and additional native feature
families. Its [contract](gl-054-native-development.md) also defines bounded
error-time primitive-local snapshots over the existing editor debugger transport;
these are historical copies, not suspended execution. Qualification remains
separate from implementation and unchanged integrated evidence below. Merge
`a419b93` preserves all 23 feature commits and their exact tree; fresh main
Windows/Linux core/native/declaration CI passes at `9ec63eb`, separately recorded
from retained feature qualification and its profile limits.

The [integrated GL-053 native expansion](gl-053-main-integration.md) extends the
existing policy dispatcher with bounded pure values/collections, observation
properties, scoped Node payloads, checked defaults and useful 2D/UI/resource
families. Its [API contract](gl-053-native-api.md) separates implementation from
[scoped qualification](gl-053-native-qualification.md); it does not establish
broad Godot API parity. The branch also implements sealed owned value-track
animation under ADR-017, native physics/navigation and skeleton observations,
nested/inherited scene preflight, transitive project-module invalidation and
native editor/templates/acceptance projects. Existing Godot graphs, resources,
domains, callbacks and native authority remain authoritative. Normal merge
`47bbb6d` preserves all 30 feature commits and the qualified tree. The integration
record separates retained qualification from fresh main CI and profile limits.

The [integrated GL-052 change](gl-052-main-integration.md) provides native editor
actions that create a plain scene and
LocalScript-associated `.luau` entrypoint. The existing runtime domains remain
the execution authority. [ADR-016](adr-016-luau-editor-authoring.md) defines a
separate restricted EditorPreview domain using the same scheduler/limits, with
explicit evaluation, private native hierarchy/world, no gameplay bootstrap and
no runtime service capabilities. Save As produces independent native PackedScene
content rather than serializing VM scopes. Project-local module resources use
the existing require evaluator and per-domain cache. The
[qualification record](gl-052-qualification.md) records passing cross-platform
native/production checks, Windows game rendering and native export. Supported
Windows interactive acceptance also passes, including error recovery, native
editing/restart and UI export/independent rendered launch. The final default-script
`print` follow-up passes core/native CI, all four production profiles, both strict
packages and actual game export/startup.
Snapshot serialization clears copied
PackedScene instance paths before packing expanded native children; fresh-process
reopen checks pass on both platforms. The [journal](gl-052-development.md) retains
failed attempts. [GL-053](gl-053-default-damage.md) removes the unconfigured
default GameManager damage endpoint; native health/network authority is unchanged.

The [integrated GL-051 change](gl-051-main-integration.md), under
[ADR-015](adr-015-policy-driven-native-bindings.md),
replaces manual native selection lists with a checked declarative policy against
the unchanged pinned Godot metadata. Generated descriptors drive runtime dispatch,
Luau definitions and editor diagnostics/completion. Checked native calls and
preflighted PackedScene/clone/reparent operations extend the same GL-049 scope,
ObjectID/Ref ownership and owner-aware callbacks. No new VM, graph, scheduler or
filesystem authority is introduced. The [API](gl-051-native-api.md) and
[journal](gl-051-development.md) record coverage and qualification separately.

The [integrated GL-049 change](gl-049-main-integration.md) in `gl_scene_authoring.cpp` adds an opt-in
SceneScope in the existing Godot hierarchy, fixed typed native properties and
Ref-backed resource slots. Existing ObjectDB/GLReference/shared domains remain
authoritative. Owner invalidation retires scopes; network publication excludes
their local subtrees. [ADR-014](adr-014-native-scene-authoring.md) and the
[API](native-scene-api.md) define the new boundary; the
[journal](native-authoring-development.md) records qualification status. Relay
Siege now authors arena/UI/audio in Luau with a native session/lifecycle bootstrap.

The [integrated GL-044/045 follow-up](gl-044-045-main-integration.md) reuses the existing
Model CFrame constructor for Node3D/Camera getters and retains Vector3 method
receivers as userdata upvalues. Colon and legacy dot calls share the same native
value math. No new transform representation, VM, physics or networking layer is
introduced. The [work and qualification record](gl-044-045-relay-development.md)
distinguishes exact qualified native, fixture, sanitizer, package and rendered
game inputs. Integration preserves those inputs and their documented limits.

The integrated [GL-043 correction](gl-043-main-integration.md) changes only existing
physics bindings: bounded ancestry-based raycast Include/Exclude filtering,
typed finite Vector3/legacy-table impulse input, and ObjectID-backed impulse
closures. Its [scoped API contract](gl-043-physics-api.md) preserves the current
distance convention and authority checks. Windows/Linux qualification passes
within the documented scope. No physics solver, dependency, wire format or game
collision configuration changes.

The [Relay Siege example integrated on main](e2e-game-main-integration.md) composes these
existing systems under `examples/e2e-game`: Server Luau owns round/combat/save
rules, Client Luau supplies semantic input and reads server snapshots, and a
project-specific Godot scene builds geometry/UI/local soft-body presentation.
It adds no transport, VM, solver or persistence backend. The controller example
has an optional additional application suspension gate for result screens.
Cooperative game hulls retain world collision masks but use layer 0 to avoid
ally/query collisions. These are game scene choices, not new native defaults.

Integrated on main by [normal merge](input-main-integration.md), native `InputService`, `InputContext`,
`InputAction` and `InputBinding` Nodes author one disposable `GLInputGraph`.
`src/core/gl_input_actions.cpp` supplies the typed Luau surface and owner-aware
dispatch; `src/gameplay/roblox_input.h` remains the physical Godot adapter, with
a bounded post-GUI commit barrier shared by raw and semantic events. This foundation
does not replace Character V2 polling or network authority. See the
[API/migration contract](input-actions-api.md), [ADR-012](adr-012-input-actions.md)
and [journal](input-action-development.md) for implemented scope and test limits.
The foundation also supplies `src/core/gl_local_motor.cpp`: an independent local
CharacterBody3D motor with bounded commands consumed after existing Stepped
callbacks, and owner-scoped camera/capture leases. Frame/physics input samples
have separate accumulators. Scene-authored motors are inert until Client
adoption. Local input/motor subtrees are excluded by existing network stamping,
replication and reference admission; no protocol or Character controller is
replaced. [Performance evidence](input-action-performance.md) separates the
evaluator, real event routing and callback publication costs.

Integrated on main by [normal merge](player-controller-main-integration.md), the optional
[Character controller](player-character-control.md) supplies bounded local intent
to the existing Character V2 body. `src/core/gl_character_controller.cpp` owns a
script/generation lease checked against the exact native Player.Character and
current transport. Scripted mode gates native hardware movement/look polling;
Native remains the default. The existing physics, Animator, health and protocol
admission paths remain authoritative. [ADR-013](adr-013-scripted-character-control.md)
defines dormant retirement and explicit switching; the
[journal](player-controller-development.md) distinguishes implemented source from
completed qualification.

GL-018's development branch qualifies the admitted matching headless sanitizer
hosts and production extension at `46427d0`: Windows ASan and Linux ASan/LSan each
pass 80 core cases and 110 native actors. See [closure and retained limits](gl018-closure.md).
The derived engine binding-retirement correction does not establish stock-host
unload safety. Main now preserves this historical branch through the combined
[GL-018/GL-029 integration](gl018-gl029-main-integration.md).

Main integrates GL-007 through normal merge `4d4694e8ea5f05120ded9b116bcd06a2c95e4ead`
and Model-based Character V2 through `1c3176c0d9331dc1fa6849b98f8ed8e90e59c110`.
The latter tree equals retained `46f65e0`, with runtime/test inputs identical to
qualified `d7905dd`. See the [integration record](character-main-integration.md)
for fresh verification and the retained platform/graphical limitations.

Character presentation/performance is integrated by normal merge
`bee07b7d4fc948556e69aa2ae0306b0ad1a52fb4`, identical to retained source tip
`57d0083e66ea50893fb28f57f0d29ef2e71b8ce3`. Qualified runtime `2bd4374` and
fixture inputs `432b06a` are preserved. The
[presentation integration record](character-presentation-main-integration.md)
distinguishes fresh main verification from retained performance/sanitizer evidence.

Current development baseline: optimized shared-domain `main` with GL-006/008's
qualified state/removal/chat authority corrections, integrated on 2026-10-27.
GL-020's functional animation/session implementation is integrated through normal
merge `6b140427e8ab39d97e12ee693f7cbda72abc7bba`, with the same tree as qualified
branch `8e21d18a5504e0d703efbcf2a71a53d56314058e`. The dedicated
[adversarial follow-up](animation-authority-qualification.md) records current
transport/handler evidence and remaining sanitizer boundaries. Its four commits
are integrated by normal merge `9f4a4d165abcc5e8b97af65fe7fda1eb191eba8f`, with
a tree identical to retained source tip `83e498b7c7ffd203857806488c8c3790439e9560`.
The [authority integration record](animation-authority-main-integration.md) records
fresh main checks separately from retained branch qualification. See the
[animation integration record](animation-lifecycle-validation.md#main-integration-2026-10-27).
Security runtime merge `2e69d8ac703d3f968e42054871511111ab8471be` equals qualified
source `462969bd967bd26fcbeccdca1bd6ae60335347f4`. See the
[security integration record](network-authority-validation.md#main-integration-2026-10-27).
The preceding GL-019 merge `6badbae4b467a5544ffd027a1c7d7bd505cd0d46` matched
`perf/gl-019-hot-paths` at `ad200aa468be56edf4812bb3a03daeb31d5bbdd8`;
its execution-domain and module-cache implementation remains unchanged. See the
[GL-019 integration record](shared-domains-validation.md#gl-019-main-integration-2026-10-26).
The earlier migration merge `dd68cda850fb548aa7713242275ff73c183e813c`
and historical branch `runtime/shared-domains` at
`9423fed4051bec2fba798d9a49eaec7dea6cca3b` retain their
[original integration evidence](shared-domains-validation.md#main-integration-2026-10-26).
Shared-domain implementation lineage: `5f61bea0e273e7473260f351fa4fb321116090ee` (initial
migration `521265c338fc890a0e30b9e8a556f6346baf7d00`, followed by qualification fixes).
The initial runtime baseline was `7044a11c1bcc2eac2a91155e829a5821d92ab66e`;
the migration started at `8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
[Qualification evidence](shared-domains-validation.md) distinguishes executed
Windows/Linux tests from remaining production/platform gaps. The continuation
qualification records targeted network teardown, task cleanup and stack-guard
corrections following the initial migration.
GL-019 on main adds metadata-based cache validation and smaller scheduler
snapshot allocations without changing Server/Client VM ownership. The source
branch remains a historical reference. See the
[GL-019 evidence](shared-domains-validation.md#gl-019-optimization-2026-10-26).

## Runtime and ownership

GodotLuau is a Godot C++ GDExtension embedding official Luau. `SConstruct`
compiles Luau VM/compiler/AST/Common sources and the extension's core `.cpp`
files. It does not select LuaJIT. `src/core/register_types.cpp` registers the
language, resource handlers, and Roblox-style native classes.

`ScriptNodeBase` derives from Godot `Node`; `ServerScript`, `LocalScript`, and
`ModuleScript` derive from it. `GLDomainHost` owns at most one Server and one
Client `GLExecutionDomain`, lazily created for eligible script roles. The host
belongs to the running current scene (root fallback before a scene exists).
Scene replacement shuts down old domains and defers native destruction until
active calls return. Separate operating-system processes never share Lua state.
Dedicated-server/editor server-view processes run Server; remote clients run
Client; local single-player/listen-host can run both. RunContext=Client selects
Client for a ServerScript; LocalScript remains Client. Starter templates do not
execute. Existing deferred network server startup is retained.

`gl_execution_domain.cpp` is the only extension source allocating, resuming and
closing VMs. Each executable run owns an anchor/environment and independent main
coroutine, rather than a VM. Its `L_main` now denotes that owner anchor. Modules
have their own owners and initializer coroutines. The core is independent of
Godot; the host supplies ObjectID resolution, environment setup and native waits.

Each environment has its own `script` and ordinary global assignments, inheriting
domain builtins/services. `_G` and `shared` are intentional domain-shared tables;
they do not include ordinary script globals. `game`/`workspace` refer to native
scene objects through wrappers; separate Lua domains may wrap the same native
objects in a listen host. This is not native scene duplication. Luau getfenv and
setfenv remain available and can deliberately change accessible environments;
this is not a hostile-script sandbox.

Require caches by live ModuleScript ObjectID and loaded source revision. One
initializer runs per entry; concurrent callers join it even if the first caller
is destroyed. One non-nil result is required, including false/scalars; tables and
functions retain identity within the domain. Cycles fail predictably. Errors are
sticky until invalidation/source change. Rename/reparent preserves identity;
source changes, exit/destruction, or replacement invalidate that module's work
and cache in both domains. Already returned Lua values remain ordinary values.
An unrelated executable's destruction does not evict module entries.

The native resolver validates the live ModuleScript and resource ObjectIDs plus
the resource's monotonic source revision on each require. LuauScript increments
that revision before emitting its changed signal; even an earlier subscriber
must see the new revision. UTF-8 source and full chunk path are loaded only on
cache misses. Replacing a resource with another at the same revision still
invalidates identity. Explicit invalidation and loading/cycle/sticky-error paths
remain in place. Core resolvers without resource metadata retain content-based
comparison. The cache stores numeric identities, not persistent native pointers.

`GodotObjectWrapper` stores a Godot ObjectID, resolved through ObjectDB on access.
WaitForChild resolves its receiver wrapper at invocation; NetworkService method
closures now retain ObjectIDs and resolve the expected type. Focused retained
method tests now pass native Linux ASan/LSan lifetime qualification, including
destruction/replacement. GL-001/GL-002 are resolved for their specific captures;
this does not establish universal binding safety.
Callback references use non-recycled public IDs tied to a live owner, preventing
stale native handles from aliasing a replacement VM/anchor. External waits also
retain guards, including sources detached from the scene tree.
Tasks record whether they registered a native wait; pure deferred tasks skip
scene/guard scans when cancelled. Actual native waits retain their cleanup path.

Many Instance-facing classes adapt Godot Nodes; for example `RobloxPart` derives
from `RigidBody3D`. There are also Luau table-backed services and value datatypes.
Do not describe every exposed value or service as a Godot Node, or describe an
engine-neutral Instance ownership layer as already implemented.

## Native value binding boundary (GL-013)

Main integrates `refactor/gl-013-luau-api-extraction` at
`1c9f4c6296bc955a6a5969a6da0668d137e46ed1` through normal merge
`bdd57fd3097537bb1cf0f8a0b7c08ae7e312d0d7`. `luau_value_bindings.cpp` owns the
native Vector3/Color3 userdata allocation, exact-metatable checks, math callbacks
and registration. Its declaration header exposes the existing two layouts and
five bridge helpers plus two registration calls. It forward-declares `lua_State`;
the implementation includes only public Luau headers and standard math/string
headers, with no Godot, execution-domain or large implementation-header dependency.
Callback functions retain internal linkage; shared bridge helpers and registration
have one ordinary C++ definition. No new static state or registration singleton
is introduced. Both qualified source commits and the historical branch remain.

Domain bootstrap in `luau_script.cpp` calls registration at the same two per-domain initialization
points: metatables before globals, preserving the intervening Instance setup.
`luau_api.h` consumes the narrow declaration header for its existing conversions
and Instance operations. Godot Variant/property reflection, CFrame/Vector2 Lua
bridges, Instance dispatch, script scheduling and native ObjectID resolution stay
with their existing owners. The value module neither allocates nor retains VMs.
The VM still owns userdata allocation/collection; existing math-method native
captures are preserved, not newly qualified for retained use across collection.

The [extraction record](shared-domains-validation.md#gl-013-first-value-binding-extraction)
records dependency analysis, build measurements, compatibility and qualification.
Both CMake and SCons discover core `.cpp` sources; the new implementation must
remain in that discovered set. Other large headers and their remaining coupling
remain GL-013 work, not additional extractions in this change.

## Generic Variant conversion (second GL-013 extraction)

Normal merge `21d10d91769ee81c85ae2e1d2029e683feeb51ba` integrates
`refactor/gl-013-variant-bindings`, based on prior main
`174efcc2bdb59c5072ba21d27645c5380c61e8e9`, separates the two generic conversion
functions into `luau_variant_bindings.cpp`. Its header forward-declares only
`lua_State` and Godot `Variant`, exposing the existing two boolean conversion
functions. The implementation depends on public Luau, Godot value types and the
native value-binding interface; it includes no Node, Instance dispatch, ObjectID
wrapper, service, execution-domain or large implementation header. There is no
registration, retained state or new initialization order.

Luau numbers/booleans/strings and exact Vector3/Color3 userdata convert to Variants.
Godot BOOL/INT/FLOAT/STRING/VECTOR3/COLOR convert back, with the inherited double
numeric and C-string conventions. Nil, collections, functions and Instance
references are unsupported by these helpers; false preserves the output/stack
contract. The existing caller still decides whether to ignore, raise its existing
invalid-member error, or use
the table-Offset fallback. At integration, `gl_has_property`, reflection and
metadata fallback remain in `luau_api.h`; the third extraction below moves that
stateless subset. ObjectID resolution remains in `gl_runtime.h`. Both qualified
source commits are preserved. See the
[second extraction record](shared-domains-validation.md#gl-013-second-generic-variant-extraction).

## Instance property adapter (third GL-013 extraction, integrated)

Normal merge `b7ec9fd614bd0e92ce418859de68b835180a7d7c` integrates both commits
from `refactor/gl-013-instance-reflection`, based on prior main
`752bb2063f61a533c3e59b481196a0d8aa88f1ba`. The generic `_gl_bridge` read/write
blocks and Godot property-list membership helper now belong to
`luau_instance_reflection.cpp`. Its forward-only header exposes three internal
functions: `HasLuauInstanceProperty`, `PushLuauInstanceProperty` and
`WriteLuauInstanceProperty`. It retains no object, state, callback or registration.
The caller still resolves ObjectID immediately before dispatch. Synchronous raw
Object parameters are borrowed for the existing call only; this is no new
ownership model or general reentrant native-lifetime guarantee.

Dependencies now point from Instance dispatch to reflection to the separate
Variant conversion and native value bindings. Reflection includes public Luau and
Godot Object/value headers; it does not include Node, services, networking,
execution domains, `gl_runtime.h`, `luau_script.h` or `luau_api.h`. Conversion and
native value implementations are unchanged. There is no reverse dependency or
include cycle. Both existing build globs discover the owned implementation.

Membership still enumerates `get_property_list` by exact name without filtering
usage/read-only flags. Reads try native properties, then `_glp_` metadata using the
existing converters; false leaves child, lowercase alias and invalid-member error
fallback with Instance dispatch. Writes try conversion and native `set` or metadata,
then the existing numeric table-Offset fallback; nil/unsupported values remain
ignored. The adapter does not check Godot `set` success or synthesize notifications.
Lua Offset metamethod execution/errors remain part of the existing operation.

Class-specific identity overrides, wrappers, hierarchy, all special-case Roblox properties/methods,
callback bindings, Changed/attribute watchers, property-specific signals and
replication hooks remain in their original owners. `Anchored` fallback uses the
same extracted membership helper without moving its class-specific policy.
No public Lua API, capability, pin, wire format or VM/cache lifetime changes.
See the [analysis and qualification](shared-domains-validation.md#gl-013-third-instance-property-extraction).
The merge tree equals qualified tip `90776e7c1c5ba2b087d4efc4b9ecc2e50a223058`.
GL-013 remains open for remaining header coupling.

## Class identity adapter (fourth GL-013 extraction, integrated)

Normal merge `35c993ce3711076a61dace5324f74691f4fb77ef` integrates all four
commits of `refactor/gl-013-class-identity`, based on prior main
`4e3db8496e189b6e09148b015eff28b1c8ae29b6`. `luau_class_identity.cpp` owns the
existing native-to-Roblox name mapping and generic IsA predicate. Its forward-only
header declares `GetLuauClassName(Object*) -> String` and
`IsLuauClass(Object*, const char*) -> bool`. It depends only on public Godot
Object/String and cstring, with no Luau, Node, domain, service, reflection, value
binding or large implementation header. Instance dispatch resolves ObjectID and
keeps its class-specific identity dispatch and error/hierarchy policy. Player/Value
overrides precede generic ClassName; the existing Mouse ClassName branch follows
that unconditional generic return, and its ordering is preserved.
All alias entries and exact/custom-parent/Godot is_class rules are preserved.

The old unmapped-name result borrowed a TU-local static CharString; mapped names
borrowed static literals. Current callers compare or copy immediately, with no
retained pointer or lookup/yield in between. No supported-call lifetime defect is
established. The new compilation boundary returns an owned Godot String instead
of introducing a shared mutable process-wide UTF-8 buffer. IsA owns its UTF-8
conversion locally; Lua push/error call conversions remain alive for their full
expression and are copied by Luau. Neither native objects nor query pointers are
retained. This is an explicit internal storage/interface change with preserved
public behavior, not a concealed fix for a confirmed defect. The mapping table is
immutable and no registration or mutable cache is added. No concurrent
Godot/Luau binding execution guarantee is introduced.

Both core-source build globs discover the owned implementation. The merge tree equals qualified tip `eb53661072999887d2a124e5d4ece2f458c7bb30`;
qualification and the [string lifetime audit](shared-domains-validation.md#gl-013-fourth-class-identity-extraction)
distinguish tested serialized callbacks/GC/shutdown from unsupported concurrency
and existing broader lifetime/sanitizer limitations. GL-013 remains open.

## Remaining implementation coupling (GL-013 assessment)

At integrated main `08b2bb83b7093a361c80b147b4827eb22715ad32`, the source contains
64 native project headers and eight core implementation units. Static includes
and retained qualified Linux Debug compiler dependencies agree: API/script/network
and GUI implementation still reach host, script and registration TUs; completion
reaches script and registration. No project include cycle is found. The four
extracted implementation units each have only one or two project-header dependencies.

The [focused assessment](gl013-boundary-assessment.md) records the full inventory,
responsibility/lifetime map, compiler evidence, historical comparison and ranked
proposals. The preferred future change is script bootstrap plus narrow Instance
access in existing `luau_script.cpp`; host wrapper/service/codec calls must first
be made explicit. Moving only InitializeDomain cannot remove all API dependencies.
Completion ownership, GUI metadata/style adaptation and inert-signal helpers rank
after it. These are proposals, not delivered boundaries. GL-021 separately records
the source-observed inert lowercase-alias gap. No production implementation or
ownership contract changes in this assessment; GL-013 remains open.

## Script bootstrap boundary (fifth GL-013 extraction, integrated)

`refactor/gl-013-script-bootstrap` starts at integrated main
`ce5e19fa8aea1cf65da875d07cda13c1696fc08c`. Normal merge
`109bd6d838410509da9831b1502dfffb023ad823` integrates qualified branch tip
`9171199fc6b3b43a2aa07a98f3f20977abc43533` with an identical tree. See the
[integration record](gl022-child-relay-validation.md#stage-1-gl-013-script-bootstrap-integration-2026-10-29).
`luau_script.cpp` owns the existing InitializeDomain, RemoteFunction setup and
child-event relay bodies plus their private JSON/HTTP helpers. `luau_script.h`
retains script/resource declarations, editor/template handling and execution
startup/cancellation. The three moved bodies are exact after class indentation;
JSON/HTTP helper text is unchanged. This changes compilation ownership, not VM,
module, callback, service or persistence authority.
That statement describes the integrated extraction. The later dedicated GL-005
branch removes the blocking HTTP helper and installs the manager described below;
its legacy private JSON helpers remain in this compilation unit. GL-023's public
HttpService JSON codec runs in the existing Luau VM instead; DataStore's GL-009
codec remains separate.

`luau_instance_access.h` forward-declares lua_State and Godot Node and exposes
only `PushLuauInstance`. Its implementation delegates to the existing `wrap_node`
in the same CPP, preserving nil, ObjectID userdata and GodotObject metatable.
It owns no object, cache, VM or registry. `GLPushNodeHandle` is not substituted:
that function does not install the metatable. Host environment and resume paths
resolve ObjectIDs and call the facade synchronously. The metatable must already
be installed for non-null wrappers.

At this historical extraction checkpoint, host service/codec/error/runtime
includes became explicit and Humanoid preceded network implementation. Character
V2 now uses RBXCharacter in that position and registers Model/Animator/body before
Character; see its ownership section below. Native
service, network, core VM/scheduler, compatibility runtime, dispatch, stdlib and
the previous four adapters otherwise remain unchanged. No TU is added.

Compiler records on both platforms/configurations match the source graph: API
and stdlib now reach only script CPP (three TUs before); host project-header
closure falls 42 → 21, registration 63 → 57, script CPP grows 45 → 46.
Script header still reaches three TUs; its own closure falls 41 → 7. A new wrapper
declaration affects host and script only. The graph has no project include cycle.

External-inline shared state remains shared. Template cache and script counter
storage remain where they were; codec error/trace slots retain TU-local linkage.
Dispatch attribute watchers remain private to API implementation, now compiled
only in script CPP, rather than being moved to a singleton. All live watcher
entry points and registration stay together. The old unused API copies are no
longer instantiated in host/registration. `_GL_VM_ID`'s function-local counter
and RemoteFunction source literal retain their function storage duration; no
initialization flag or global registry is introduced. This is serialized native
execution, not a new thread-safety guarantee.

Local Windows/Linux Debug/Release core39/native28 and fresh hosted Debug core39/
native28 on both platforms pass at implementation `50f1c0e`. See the
[fifth qualification record](shared-domains-validation.md#gl-013-fifth-script-bootstrap-boundary).
GL-013 stays open. GL-022 separately records the reproduced baseline shared-module
child-relay connection conflict; distinct relay targets pass both-domain coverage.
The next ranked independent candidate remains editor completion ownership, with
its missing editor-specific fixture requirements. It is not implemented here.

## Child signal subscriptions (GL-022 integrated)

Main integrates `fix/gl-022-cross-domain-child-relay` at qualified tip
`ef8a6b47e918cc72d26e572f3e4a539a5db66161` through normal merge
`f1e1b9c492e56549a72739ad3086ad3ec9c32ee9`. Child subscriptions use a custom native
Callable keyed by immutable callback reference and receiver ObjectID. Godot's
signal map ignores bind arguments, merging the previous bound-method identity
on a shared native ModuleScript. The existing scene domain host tracks native
connections and disconnects by owner/reference, preserving the other VM's work.
Dispatch resolves ObjectIDs and the existing reference mapping; no VM pointer
is captured by the Callable. Dead targets are reaped before the next host tick.
The [GL-022 record](gl022-child-relay-validation.md) preserves the failing baseline,
mechanism, lifecycle contract and passing Windows/Linux/ASan/hosted qualification.
The integrated implementation is identical to the qualified source. Fresh main
CI status is recorded in the integration section of that record.

## Script capabilities and scheduling

Before GL-003, main `2e89995` publishes an unrestricted `_FileAccess` bridge and
`_HTTP` into gameplay VMs. Normal merge `5ba96ad0ca74f63ac92910633ba1c0d4fd6050e2`
integrates both GL-003 source commits with the same tree as qualified tip
`9824faf5937654ba48558b43d09a3064d25a71fa`. Main replaces the raw file
operations with native denial and typed native service operations, with live
owner/domain and native role checks. Storage uses the same shared `user://`
filenames through bounded, handle-relative platform operations. Client persistence
is denied; Client Messaging stays local. Editor structure mutation and arbitrary
network helper dispatch are gated; dynamic assets receive only trusted-project
resource access. See [ADR-003](adr-003-native-storage-authority.md) and its
[qualification record](filesystem-capabilities-validation.md) for exact authority,
compatibility and limits. Fresh main hosted CI status is in the integration record.

Before GL-005, main `3d390a0` uses synchronous `HTTPClient` polling and delays in
`luau_script.cpp`, with a nominal ten-second timeout checked incompletely during
body reads. Normal merge `b7d108b08b9b55c8333a1799743204441b424dba` integrates
`runtime/gl-005-async-http` at `4a5ebbd`, with an identical tree, replacing that path with
`GLHttpManager` in `gl_http.cpp`, owned by the existing scene domain host.
Native HTTP is default-denied and requires a live Server owner, non-client native
role and a trusted project exact-origin grant. Arguments/admission are checked
before DNS/send; admitted coroutines yield and complete through protected native
host ticks. Owner/thread/module/scene retirement closes requests before VM close.
Manual coroutine resumes cancel the old HTTP operation and raise an error.
No worker Lua VM, generic capability registry or storage authority is introduced.

Integrated GL-023 captures native request/availability/UUID functions in the frozen
HttpService facade. Public HTTP failures raise, RequestAsync preserves actual
reason text and bounded lowercase headers/duplicate arrays, HttpEnabled queries
live native availability, and offline JSON uses a bounded strict Luau codec with
an explicit null sentinel. UUID v4 uses Godot Crypto. The asynchronous manager,
owner cancellation and grants above are retained. See the [API/migration contract](httpservice-api.md)
and [qualification record](httpservice-validation.md); this branch is not merged.

The manager uses Godot's nonblocking DNS/TCP/validated TLS and HTTPClient parser
through an internal metered StreamPeer. Finite per-tick and cumulative wire/header
limits bound the parser's work, with a per-stage monotonic deadline, four requests
per host and two per owner. The API delivers at most 4 MiB, with explicit failure
and no partial successful body on truncation/overflow/timeout. HTTP bodies preserve
binary/UTF-8 lengths; legacy storage encoding remains unchanged. No redirects,
decompression or TLS bypass is enabled. Exact settings, bounds, compatibility and
DNS/native-allocation limits are in [ADR-004](adr-004-asynchronous-http.md);
executed results and fresh main integration status are in the [HTTP record](http-validation.md#main-integration-2026-10-29).
After GL-004 integration on main, VM creation uses an allocator-backed domain
account with a hard requested-byte quota. Trusted registration/stdlib bootstrap
precedes sandbox sealing; intrinsic libraries/root globals become read-only,
while existing mutable custom facades and `_G`/`shared` retain their contracts.
Owner environments use luaL_sandboxthread with safeenv disabled so custom typeof,
mutable facades and getfenv/setfenv keep their actual behavior. GL-004 itself
introduces no filesystem or HTTP gate. Imported/hostile script isolation remains
outside the supported claim. See [ADR-002](adr-002-domain-resource-policy.md)
and the [qualification/integration record](execution-limits-validation.md).

Gameplay resumes, synchronous invokes and native argument preparation use
protected boundaries on the state that allocates/executes. Active C++ execution
scopes share elapsed/safepoint constraints through nested Server/Client calls,
including reentry into an already active domain. A thread-local domain scope
chain exists only during synchronous execution; it does not retain Lua pointers
or change scheduler/VM ownership. A yield ends the attempt; later managed resumes
start fresh budgets. Ordinary per-entry limits do not establish a frame latency
budget, and blocking native/compiler work cannot be preempted by Luau.

Execution violations cancel participating owners; module initialization keeps
sticky failure semantics. Allocator rejection is sticky even if Lua catches it
with elapsed enforcement disabled. At the protected return the domain retires,
rejects admission, invalidates owners/references and skips close hooks. Actual
lua_close waits for normal host destruction, preserving allocator context lifetime.
There is no automatic restart. Task, live-coroutine, external-reference and
retained-owner admission caps plus host resource statistics are configurable
separately for Server/Client. Earlier native/Lua mutations are not rolled back.

The domain scheduler owns task roots and snapshots its work before dispatch.
Snapshots reserve their current task count and keep shared_ptr ownership across
reentrant resumes. Reaping inspects live entries before taking a temporary strong
reference; cancelled records still retain that reference through reset/unref.
Spawn runs immediately up to eight nested native resumes; deeper dispatch is
deferred to a later tick. Defer/delay/timed waits, native signal waits, child
waits, invoke responses and module waits retain their owning script or module.
Numeric/empty yields in managed tasks are timed/next-tick waits; other yields
await external resume. Manually driven coroutines join managed scheduling on
task.wait, require-pending or native waits; ordinary explicit yields stay manual.
Coroutine resume/wrap reject retired owners and cancelled tasks. Native and
shared Lua service callbacks execute under their subscriber, including yields.
Messaging polling is domain-owned, so destroying the first subscriber does not
stop the service. Its temporary bootstrap spawner is hidden before gameplay.

Disable/destroy/source reload invalidates a run's callbacks, waits and tasks;
re-enable/reload starts a fresh environment. Unrelated owners and module caches
survive. Shutdown closes admission in both domains before a finite BindToClose
snapshot, then invalidates owners; close hooks cannot initialize modules or
schedule new work, and yielded close hooks are cancelled. Integrated GL-004 adds
VM safepoint/elapsed interruption and one aggregate close-hook deadline. Local synchronous
RemoteFunction fallback remains non-yielding; network handlers support yields.
Native stack guards use per-thread OS bounds on Windows/Linux and real frame/
return-slot addresses so ASan fake-stack locals are not mistaken for exhaustion.

## Networking and persistence

Main integrates `foundation/networking-2` at compacted source `cb2014f`, preserving
its three foundation commits and the qualified runtime/test inputs. See the
[controlled integration record](networking-foundation-2-work.md#main-integration-2026-11-05).
This adds the
[ADR-010 RemoteFunction lifecycle](adr-010-remotefunction-terminal-outcomes.md):
finite request/handler deadlines, full-width correlation, existing native
publication/session admission, exact serving-task cancellation and protected
terminal completion. The [campaign journal](networking-foundation-2-work.md)
separates exact-revision qualification, retained failures and broader coverage
limits. Historical source/merge SHAs below remain evidence for their original
revisions in the retained archive, rather than fresh integrated-main qualification.

The same branch implements the opt-in [ADR-011 projection and batching
contract](adr-011-peer-replication-relevance.md). The native catalog and spatial
index feed bounded desired/planned/known/materialized peer views through the
existing NetworkService tick and GL-029 queue/admission capability. Immutable
reliable structural groups, cached property snapshots and explicit application
ACKs are distinct from native transport ACKs. Runtime physics carries view
generation/session identity; unanchored bodies remain global. This is a narrow
runtime anchored-leaf-Part slice, disabled by default, with matching-build/setting
requirements and explicit Remote-reference restrictions. At `436850a`, all four
hosted workflows and targeted repeated 1/16/32-peer Release workloads verify;
broader campaign coverage remains distinct. The journal records actual limits.
GL-031 fixes static-parent late join; GL-032 adds the missing ObjectValue Instance
getter/setter without broadening scalar conversion or reflection authority.
The GL-034 implementation extracts the existing record validator into bounded private
cache/index sweep turns and refreshes only affected published reparent closures.
New peer selection waits for sweep completion while accepted immutable frames
drain; native identity/visibility is revalidated before new admission. Sweep state
retires with NetworkService reset. GL-034 closes with exact current
[runtime](evidence/networking2-436850a-runtime-verification.json),
[candidate](evidence/networking2-436850a-candidate-verification.json) and
[Release](evidence/networking2-436850a-release-qualification.json) receipts.
GL-039's bounded FIFO drain submits up to eight frames and 60 KiB per peer visit
within the existing cooperative submission budget and 64-frame application-ACK
window. Clients apply up to eight FIFO frames within a cooperative four-ms turn,
revalidating native lifetime after each application. Queue/native ownership and
timeout limits are unchanged. Its repeated 32-peer Release measurements improve
the prior roughly seven-second final-counter convergence to 0.299/0.226 ms in
64-object worlds and 75.159/699.938 ms in 512-object worlds. The
[receipt](evidence/gl039-release41-qualification.json) retains a failed legacy
large-world warmup and the independent candidate runs. Final Windows/Linux
sanitizer verification at `903b10c` closes GL-039 within the
[recorded scope](evidence/gl039-final-verification.json); GL-040/041 remain open.
No general latency, graphical or 64-player guarantee follows from these profiles.

Main includes the qualified Phase 1 native RemoteEvent
DeliveryType (reliable ordered/unreliable unordered), Server-owned frozen
configuration, per-session descriptors/readiness and ObjectID-bound publication.
Event bodies use a bounded event-only byte codec; RemoteFunction and generic
replication keep their existing wire behavior. No sequenced mode, general
scheduler or new execution domain is added by Phase 1; see
[ADR-008](adr-008-remoteevent-publication.md) and the
[qualification record](remoteevent-phase1-qualification.md) for status and exact
compatibility changes, including preserved native legacy class identity and
strict UTF-8 event dictionary keys. Functional loopback qualification uses the
explicit carrier profile in ADR-008; production ENet defaults remain unchanged.

The integrated later phase adds [ADR-009](adr-009-bounded-remote-delivery.md)
bounded Remote-owned send/dispatch queues, fair peer service, GER2 sequencing and
unsent supersession. A hash-pinned Godot/ENet host adapter bounds native retained
data packets/commands and propagates RPC admission failures. It also provides
read-only actual RPC call context; NetworkService checks target/method/carrier/
channel before accepting event traffic. Stock hosts fail closed at network
startup. It preserves the native storage, HTTP, character/animation, replication
and RemoteFunction authorities. Normal merge `6a7fedf` preserves the qualified
tree; [fresh main verification](gl018-gl029-main-integration.md) passes at
`ac119bc`, including downloaded evidence and both extracted packages. The
[qualification record](remoteevent-completion-qualification.md) verifies the
Windows/Linux profiles and extracted packages, and records latency costs and
the bounded 32-peer comparative performance scope. The
[work record](remoteevent-completion-work.md) preserves earlier failed attempts.
Native data ceilings do not bound total RAM, receive predecode or native
control/ACK storage.

Integrated `security/gl-007-character-authority` source `3bb641a` introduced
protocol 2 character grants/snapshots, native server health, bounded pose admission,
and a startup presentation-animation catalog. Its bounded contract and executed
qualification are separated in [ADR-006](adr-006-character-authority.md) and the
[qualification record](character-authority-validation.md). Character V2 extends
that same authority mechanism with protocol 3 below; legacy state RPCs are inert.

Normal merge `1c3176c` integrates the stacked `runtime/character-v2-model` source,
replacing the 3D Humanoid with
`RBXCharacter : RBXModel`, genuinely exposed as Character/Model. A single internal
top-level CharacterBody3D drives the Character world pose; explicit Model
transforms synchronize that body under a feedback guard. HumanoidRootPart is a
direct identity-transform proxy. The root owns health and observed movement;
the internal body retains camera/input behavior, and a real Animator owns tracks.
Visual rig bodies are passive to prevent competing collision responses. R6 and
StarterCharacter factories produce the same actual root as remote puppets.

Protocol 3 extends existing grants/snapshots with exact full-pose/configuration
dictionaries, preserves GL-007 admission and server health, and rejects legacy
readiness/malformed contracts. Explicit removal creates a session/life tombstone
before deferred lifecycle delivery; stale pose/animation cannot resurrect it.
A trusted new life can replace it. ObjectID references and exact-clip playback
leases protect Animator/track/rig destruction and late completions. Native Player
lifecycle remains separate; reentrant spawning coalesces, and direct native
Character deletion emits CharacterRemoving once before clearing Player.Character.
2D keeps its existing controller/Humanoid2D path.

See [ADR-007](adr-007-model-character.md), the [public API](character-v2-api.md),
and the [qualification record](character-v2-validation.md). The retained branch
and its full qualification matrix are distinct from fresh main integration checks
in the [integration record](character-main-integration.md).

`NetworkService` combines connection setup, ENet RPCs, players, puppet state,
replication, remote invocation, physics ownership, chat, and coordinator/world
process support in `src/services/roblox_network.h`.

Peer-disconnect application callbacks are deferred until the transport poll
completes. Destroying the active service disconnects its transport, resolves
outstanding invokes with the existing peer-left error and clears service identity
before destruction. Retained ObjectID method closures cannot act on replacement
services. Godot 4.7.1's independent simultaneous-disconnect relay send/leak remains
reproducible without the extension (GL-017); production relay is still enabled.

Current character input uses `_relay_character` with transport-derived identity,
live Server role/session, epoch/sequence freshness and bounded finite prediction.
Server grants and snapshots require the connected Client-role/server-origin guard
and the exact protocol-3 contract before mutation. The legacy `_relay_state`,
`_relay_state2d`, `_recv_state` and `_recv_state2d` handlers do nothing.
GL-006/008's removal/chat receive authority and assigned-session checks remain.
Chat derives its name from the matching live server PlayerObject and validates
original string Variants, message bounds and a per-session token bucket.
The sender waits for accepted server echo. Explicit local/system chat remains
available, including scenes without a Players service. See the
[authority qualification record](network-authority-validation.md) for exact
rules, compatibility, source identity and fresh integration transport evidence.
Structural replication, RemoteFunction reply and owned-physics checks are
preserved. Client-supplied movement follows ADR-006/007; independent animation
RPC authority is addressed by the integrated GL-020 implementation below; its full
security transport qualification remains independent. No general networking
security claim is made.

GL-007 makes legacy `_relay_anim`/`_recv_anim` handlers inert and uses
`_relay_anim_v2`/`_recv_anim_v2`. Sender/receiver role and session checks remain;
client input also binds the correction epoch and server playback binds the life.
Finite speed (0–20), identity/name bounds, per-peer rate limits, checked assets
and active gameplay-timeline protection apply before cache mutation/relay.
The GL-020 follow-up receives raw Variants and validates canonical field types
before conversion, including integer epoch/life and positive 32-bit target peers.
Normal AnimationTrack packet shapes remain unchanged; implicit malformed-field
coercion is rejected. Qualification is recorded in the
[authority follow-up](animation-authority-qualification.md).
ADR-006 documents the epoch-zero pre-puppet case. Protocol-3 removal tombstones
also reject stale animation for a removed life. This preserves GL-020's existing
replication mechanism while explicitly versioning the character wire contract.

`peer_anim` stores the assigned UserId with each transport peer's latest state,
including stops. It admits mapped sessions before PlayerObject/puppet creation;
3D puppet initialization and late-join replay validate that same session binding.
Puppet exit/removal, peer departure, server loss, disconnect, transport replacement
and service exit clear obsolete cache entries. Puppet exit callbacks include the
character ObjectID so an old queued character cannot erase a replacement's state.
Local character exit sends a stop through the existing animation wire path while
the service/session is live; scene/service shutdown admits no animation work.
UID assignment/server startup replays already-playing local tracks, recovering
preconnection playback. No separate session authority is introduced.

AnimationTrack resolves its AnimationPlayer ObjectID on use. Active speed/loop
changes and natural completion notify the network; stop/completion notifications
precede user callbacks, whose lists are copied for reentrant dispatch.
Client-selected presentation uses plain checked copies from the startup catalog
or validated named rig clips, with independent loop configuration. Trusted Server
gameplay timelines retain their separate loading contract. Temporary playback slots
restore the exact overwritten clip and preserve later trusted replacements.
Character V2's Animator/track lease uses ObjectIDs and exact clip identity;
retirement releases callbacks and cannot stop a newer gameplay timeline.
Applying the current clip's settings preserves playback position.
`GetAnimationStates()` is a native
read-only diagnostic snapshot of the actual cache (including UserId), not an RPC.
The [animation record](animation-lifecycle-validation.md) preserves historical
functional qualification; the [authority follow-up](animation-authority-qualification.md)
records the subsequent adversarial scope. Shared domains,
GL-019 paths and owner-based coroutine cancellation are unchanged.

The coordinator uses local process discovery/heartbeat files. Upstream documents
no account authentication and no incoming connection validation against
`host.key`. The presence of that key is not authentication.

`DataStoreService` is embedded Luau in `src/core/luau_stdlib.h`.
Before GL-003 it serializes local JSON through `_FileAccess`; integrated main
uses typed native service storage instead. Main `bc8ca88` still had the
nontransactional read/transform/write implementation reproduced by GL-009.
Normal merge `fc923d2` integrates GL-009's [ADR-005](adr-005-transactional-datastore.md):
`gl_datastore.cpp` owns bounded, owner-aware requests on the existing host;
`src/persistence/worker_main.cpp` performs only native I/O through the confined
`gl_datastore_backend.h`. One stable root lock serializes cooperating local
writers; raw-content conditional commits detect yielding-transform conflicts.
Stage/sync/relative atomic replace/final flush precedes acknowledgment. Remove
writes a null tombstone and returns committed previous data; Get no longer uses
stale cache for missing/error cases. Strict DataStore-only codecs preserve legacy
encoding while rejecting invalid/lossy candidate shapes. Ordered sorting remains
local cache, and public version methods remain compatibility stubs. The implementation
has no cross-key transactions or mixed-old-writer guarantee. Qualification status
and deployment/recovery limits are in the [work record](datastore-validation.md).
The [integration record](datastore-integration.md) records writer exclusion,
legacy-file preservation, side-by-side companion packaging and fresh main CI.
MemoryStore/Messaging retain ADR-003's existing operations. `backend/` contains
an optional Nakama/PostgreSQL development stack; it is not this authority.

## Editor and release path

The updater plugin includes configuration, autocomplete/model management, import
tools, and guarded update/restart code. Inherited URLs still name
`Pimpoli/GodotLuau`, but `RuntimeUpdatesAllowed()` is literal false and every
runtime replacement entry/completion and cleanup/rollback/restart path rejects
before side effects. The enabled plugin retains editor tools and explicit
optional JSON data downloads, with visible disabled-runtime controls. There is
no qualified production channel or user-setting override. See the
[fork updater policy](fork-updater-isolation.md).

The inherited `.github/workflows/build-release.yml` is disabled during fork
integration: only manual dispatch remains, both jobs have literal false admission
conditions, repository permissions are read-only, and checkout credentials are
not persisted. Ordinary pushes cannot start its builds, archive commits or release
publication. Normal merge `b88a88b64c3f576d8b51e51908c0141ac9231a18` integrates
the GL-010/011 candidate pipeline, preserving all six development commits.
Its dormant build delegates to the separate non-publishing candidate workflow;
no committed ZIP supplies Windows binaries or repository archive commits. The
[candidate contract](release-candidate-qualification.md) records source-built
four-profile qualification, provenance and required Linux core ASan/LSan gates;
fresh main qualification and exact artifact identities remain in that record.
Historical release/tag deletion stays
removed by GL-012. Main integrates the qualified core CI branch via
`f0199004d56485ec7a9de14d5454d1907822ba11`. The separate
`runtime-core-ci.yml` builds the production `ExecutionDomainTests` target and
runs its current 80 cases through CTest on hosted Windows/Linux Debug. Read-only access,
recursive pinned checkout, two build jobs, explicit deadlines and checked
discovery/completion are independent of publication. Only diagnostic reports/logs
are uploaded. Fresh hosted integration succeeds on Windows/Linux; outcomes and the continuing
GL-011 gaps are in the [CI record](shared-domains-validation.md#gl-011-independent-core-ci-2026-10-27).
The `test_chat/` fixture is not an
automated qualification gate. Re-enabling distribution requires a reviewed change;
manual dispatch does not bypass this interim policy.

Main integrates `ci/gl-011-native-integration` at `cebc64919e4fbf67624b19e075f31ef25941d136`
through normal merge `9029d01a24d904deaa1ecd7a9c30fc483e13757f`.
`runtime-native-ci.yml` additionally
builds the actual Debug CMake adapter on Windows/Linux and runs the qualified
single-player/listen/dedicated/editor fixtures plus network, animation, Character,
resource, filesystem, HTTP and DataStore groups (86 actors per platform).
The [Character integration record](character-main-integration.md) records the
historical 73-core/86-native gates. Integrated GL-023 raises its gates to
80 core cases and 92 native actors, adding six actual public HttpService fixtures
and retained UUID samples; its [qualification record](httpservice-validation.md)
verifies both platforms' hosted artifacts. The
[HttpService integration](httpservice-main-integration.md) adds three published
caller migration actors (95 native total) and records fresh main verification.
The integrated graphical/performance work initially adds eight headless presentation
actors and one performance-fixture actor (104 native total); additional custom
listen/dedicated coverage raises presentation to fourteen and native to 110.
Core remains 80 cases. Its exact first-person endpoint check strengthens the
earlier substantial-fade check (GL-028).
Hosted fixture execution is distinct from the actual DockerPC NVIDIA captures
and repeated comparable benchmarks in the
[work record](character-presentation-performance.md); headless CI cannot qualify
graphical appearance and its single performance actor is not a speed gate.
The runner owns
child process
trees, isolates profiles, and requires complete actors and PASS outcomes. Official
Godot 4.7.1 archive bytes/version are verified against pinned provenance before
execution. At the original native CI milestone, both hosted Debug builds and
all 28 actors per platform passed at
`216066131b64bdd81efdd48cedc04277e5a74919`; integrated runtime/build/test inputs
were identical at integration. The subsequent Linux proc-stat liveness-test
correction changes only process inspection in the launcher tests and adds
deterministic coverage; native/build/workflow inputs and pins remain unchanged.
See the [correction record](shared-domains-validation.md#linux-process-liveness-correction-2026-10-27)
for fresh results. The source branch is retained.
Sanitizers and release enforcement
remain separate. See the [native CI record](shared-domains-validation.md#gl-011b-native-ci-2026-10-27).
The original [GL-018 follow-up](native-sanitizer-qualification.md#follow-up-from-66362c7)
adds host/build/test controls and a bounded public URL-encoding correction: ASCII
unreserved bytes no longer depend on the process C locale. Matching instrumented
hosts resolve the minimal loader/exit controls. C ABI controls reproduce surviving
instance-binding callbacks after explicit library unload without GodotLuau;
production unload and complete profile gates remained unqualified at that checkpoint.
It introduces no runtime ownership, capability, networking or distribution change.

The subsequent [binding-retirement investigation](native-sanitizer-qualification.md#binding-retirement-follow-up-from-dfa700a)
keeps the GodotLuau production tree unchanged and admits one hash-pinned patch
to the instrumented qualification host. It retires surviving library-token
bindings before unmapping the DLL/SO. These derived hosts are distinct from
unmodified Godot and from any distributed engine; production distribution stays
disabled. Direct production unload controls pass on both derived hosts. The
corrected Linux profile passes 80 core cases and 110 native actors locally and
in hosted CI. Windows remained incomplete at that checkpoint because competing increments exhausted
GL-009's existing eight-attempt conflict budget; no persistence semantics or
qualification assertions were changed to obtain acceptance. Other retained
sanitizer and graphical limitations remain separate.

The subsequent [GL-018 closure](gl018-closure.md) resolves the admitted-host
headless scope, with successful detection/reload controls on both platforms.
The combined qualified branch additionally passes 81 core cases, 116 native
actors and ADR-009's host fixtures. Main now preserves that source through
`6a7fedf`; fresh main results are recorded separately in the
[integration record](gl018-gl029-main-integration.md). Stock-host unload, Windows
LSan and graphical/editor/device limits remain separate.

GL-012 is integrated, preserving `maintenance/gl-012-release-retention` at
`169fd98be216c4322f4c820c7d77f3081761982b`. A bounded read-only release/tag-absence
preflight rejects reused identities before package/commit/publish; workflow
publishing runs are serialized and asset overwrite is disabled. Production
publication and historical provenance gaps remain GL-010/011;
the bounded non-publishing candidate gates are integrated and verified. See
[retention policy](release-retention.md).

## Task routing

| Area | Read implementation first | Related issues |
| --- | --- | --- |
| VM, require, tasks, shutdown | `src/core/gl_execution_domain.h/.cpp`, `gl_domain_host.h/.cpp`, `luau_script.h/.cpp` | GL-001, GL-004, GL-014 |
| Native object methods | `src/core/luau_api.h`, `gl_runtime.h` | GL-001, GL-002, GL-013 |
| File/HTTP permissions | `src/core/gl_service_storage.h`, `gl_storage.h`, `gl_http.cpp`, `luau_stdlib.h` | GL-003, GL-004, GL-005 |
| RPCs, players, replication | `src/services/roblox_network.h`, `src/core/gl_net_bridge.h`, `src/gameplay/roblox_remote.h` | GL-006, GL-007, GL-008 |
| Persistence | DataStore section of `luau_stdlib.h`, `gl_datastore*`, `src/persistence/worker_main.cpp`, ADR-005 | GL-009 |
| Build and release | `SConstruct`, `.gitmodules`, `.github/workflows/build-release.yml`, `.github/workflows/runtime-core-ci.yml`, `.github/workflows/runtime-native-ci.yml`, `tests/runtime/CMakeLists.txt`, `tools/generar_release.py` | GL-010, GL-011, GL-012 |
| Editor updates and autocomplete | `addons/GodotLuauUpdater/plugin.gd`, `src/editor/luau_autocomplete.h` | GL-016 |
| Imported/bundled assets | `src/importer/`, `GodotLuau/assets/`, `GodotLuau/licenses/` | GL-015 |

Pinned submodules at baseline: `godot-cpp` =
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`; `luau` =
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.
