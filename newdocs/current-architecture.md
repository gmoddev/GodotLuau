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

## Script capabilities and scheduling

Domain setup publishes `_FileAccess` and `_HTTP` into gameplay VMs.
The native file bridge accepts script paths directly without a role/capability
check or extension-level root confinement. The higher
level DataStore wrapper rejects network clients, but this does not remove the
native global. OS permissions and platform restrictions still apply.

HTTP uses synchronous `HTTPClient` polling and delays on the calling thread
in `luau_script.h`. It has a nominal ten-second timeout; this is not a
nonblocking scheduler or a demonstrated bound on every network/body path.
No explicit sandbox setup, instruction-interrupt budget, or custom memory quota
was found in extension VM initialization or the searched extension source.
Imported/community script isolation is not an established supported contract.

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
schedule new work, and yielded close hooks are cancelled. A running non-yielding
script/close hook has no instruction budget (GL-004). Local synchronous
RemoteFunction fallback remains non-yielding; network handlers support yields.
Native stack guards use per-thread OS bounds on Windows/Linux and real frame/
return-slot addresses so ASan fake-stack locals are not mistaken for exhaustion.

## Networking and persistence

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
It serializes local JSON through `_FileAccess`; `UpdateAsync` is read/transform/
write, without a cross-process transaction or compare-and-swap. Worlds can share
`user://`, so competing processes can lose updates. The write bridge overwrites
the target directly. `backend/` contains an optional Nakama/PostgreSQL development
stack and future integration plans; it is not the active persistence authority.

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

GL-012 is integrated, preserving `maintenance/gl-012-release-retention` at
`169fd98be216c4322f4c820c7d77f3081761982b`. A bounded read-only release/tag-absence
preflight rejects reused identities before package/commit/publish; workflow
publishing runs are serialized and asset overwrite is disabled. Existing build
provenance and runtime-gate gaps remain GL-010/011. See
[retention policy](release-retention.md).

## Task routing

| Area | Read implementation first | Related issues |
| --- | --- | --- |
| VM, require, tasks, shutdown | `src/core/gl_execution_domain.h/.cpp`, `gl_domain_host.h/.cpp`, `luau_script.h` | GL-001, GL-004, GL-014 |
| Native object methods | `src/core/luau_api.h`, `gl_runtime.h` | GL-001, GL-002, GL-013 |
| File/HTTP permissions | `src/core/luau_script.h`, `luau_stdlib.h` | GL-003, GL-004, GL-005 |
| RPCs, players, replication | `src/services/roblox_network.h`, `src/core/gl_net_bridge.h`, `src/gameplay/roblox_remote.h` | GL-006, GL-007, GL-008 |
| Persistence | DataStore section of `luau_stdlib.h`, native file bridge, `backend/README.md` | GL-009 |
| Build and release | `SConstruct`, `.gitmodules`, `.github/workflows/build-release.yml`, `.github/workflows/runtime-core-ci.yml`, `tests/runtime/CMakeLists.txt`, `tools/generar_release.py` | GL-010, GL-011, GL-012 |
| Editor updates and autocomplete | `addons/GodotLuauUpdater/plugin.gd`, `src/editor/luau_autocomplete.h` | GL-016 |
| Imported/bundled assets | `src/importer/`, `GodotLuau/assets/`, `GodotLuau/licenses/` | GL-015 |

Pinned submodules at baseline: `godot-cpp` =
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`; `luau` =
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.
