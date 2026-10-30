# Current architecture

Current development baseline: optimized shared-domain `main` with GL-006/008's
qualified state/removal/chat authority corrections, integrated on 2026-10-27.
GL-020's functional animation/session implementation is integrated through normal
merge `6b140427e8ab39d97e12ee693f7cbda72abc7bba`, with the same tree as qualified
branch `8e21d18a5504e0d703efbcf2a71a53d56314058e`. Full animation-specific
adversarial transport/handler qualification remains pending. See the
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
its JSON helpers remain in this compilation unit.

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

The qualified, unmerged `security/gl-007-character-authority` source `3bb641a` implements protocol 2
character grants/snapshots, native server health, bounded pose admission, and a
startup presentation-animation catalog. Its bounded contract and executed
qualification are separated in [ADR-006](adr-006-character-authority.md) and the
[qualification record](character-authority-validation.md). The historical main descriptions below
still describe main's protocol 1 baseline.

The stacked `runtime/character-v2-model` source replaces the 3D Humanoid with
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
and the [qualification record](character-v2-validation.md). The branch is unmerged;
qualification status must be read from that record, not inferred from this source
description.

`NetworkService` combines connection setup, ENet RPCs, players, puppet state,
replication, remote invocation, physics ownership, chat, and coordinator/world
process support in `src/services/roblox_network.h`.

Peer-disconnect application callbacks are deferred until the transport poll
completes. Destroying the active service disconnects its transport, resolves
outstanding invokes with the existing peer-left error and clears service identity
before destruction. Retained ObjectID method closures cannot act on replacement
services. Godot 4.7.1's independent simultaneous-disconnect relay send/leak remains
reproducible without the extension (GL-017); production relay is still enabled.

On main, state/removal/chat receive RPCs use RPC_MODE_AUTHORITY
plus connected Client-role/transport-sender-1 checks. Their client-origin state
and chat relays require a connected Server role and active assigned remote peer.
State relays derive the presentation index from the server's session UserId;
chat derives its name from the matching live server PlayerObject and validates
original string Variants, message bounds and a per-session token bucket.
The sender waits for accepted server echo. Explicit local/system chat remains
available, including scenes without a Players service. See the
[authority qualification record](network-authority-validation.md) for exact
rules, compatibility, source identity and fresh integration transport evidence.
Structural replication, RemoteFunction reply and owned-physics checks are
preserved. Client-supplied movement values remain GL-007; independent animation
RPC authority is addressed by the integrated GL-020 implementation below; its full
security transport qualification remains independent. No general networking
security claim is made.

On main, `_relay_anim` keeps its reliable ANY_PEER
client-to-server configuration and requires the existing Server-role/sender
guard, current service/transport and assigned session. `_recv_anim` uses reliable
AUTHORITY plus the Client-role/server-origin guard and a positive mapped target;
the local target is ignored. Both reject nonfinite/out-of-range speed (0–20),
IDs over 1,024 characters, names over 128 characters and empty play names before
mutation. RPC names, arguments and wire shapes remain unchanged.

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
precede user callbacks, whose lists are copied for reentrant dispatch. Per-player
Animation resources duplicate loaded clips so loop configuration is independent.
The loader reuses the default library for clip replacement. Applying the current
clip's settings preserves playback position. `GetAnimationStates()` is a native
read-only diagnostic snapshot of the actual cache (including UserId), not an RPC.
The [animation record](animation-lifecycle-validation.md) separates functional
qualification from outstanding adversarial transport acceptance. Shared domains,
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
publication. Its dormant implementation still extracts Windows binaries from a
committed ZIP. Historical release/tag deletion has been removed by GL-012. No
sanitizer workflow exists yet. Main integrates the qualified core CI branch via
`f0199004d56485ec7a9de14d5454d1907822ba11`. The separate
`runtime-core-ci.yml` builds the production `ExecutionDomainTests` target and
runs its 39 cases through CTest on hosted Windows/Linux Debug. Read-only access,
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
builds the actual Debug CMake adapter on Windows/Linux and runs the unchanged
single-player/listen/dedicated/editor fixtures plus GL-006/008 and functional
animation groups (28 processes per platform). The runner owns child process
trees, isolates profiles, and requires complete actors and PASS outcomes. Official
Godot 4.7.1 archive bytes/version are verified against pinned provenance before
execution. Both fresh hosted Debug builds and all 28 actors per platform pass at
`216066131b64bdd81efdd48cedc04277e5a74919`; integrated runtime/build/test inputs
were identical at integration. The subsequent Linux proc-stat liveness-test
correction changes only process inspection in the launcher tests and adds
deterministic coverage; native/build/workflow inputs and pins remain unchanged.
See the [correction record](shared-domains-validation.md#linux-process-liveness-correction-2026-10-27)
for fresh results. The source branch is retained.
Sanitizers and release enforcement
remain separate. See the [native CI record](shared-domains-validation.md#gl-011b-native-ci-2026-10-27).

GL-012 is integrated, preserving `maintenance/gl-012-release-retention` at
`169fd98be216c4322f4c820c7d77f3081761982b`. A bounded read-only release/tag-absence
preflight rejects reused identities before package/commit/publish; workflow
publishing runs are serialized and asset overwrite is disabled. Existing build
provenance and runtime-gate gaps remain GL-010/011. See
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
