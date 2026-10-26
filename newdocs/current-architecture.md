# Current architecture

Updated for the shared-domain migration on `runtime/shared-domains`, 2026-10-26.
The initial runtime baseline was `7044a11c1bcc2eac2a91155e829a5821d92ab66e`;
the migration started at `8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
[Qualification evidence](shared-domains-validation.md) distinguishes executed
Windows tests from remaining production/platform gaps.

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

`GodotObjectWrapper` stores a Godot ObjectID, resolved through ObjectDB on access.
WaitForChild resolves its receiver wrapper at invocation; NetworkService method
closures now retain ObjectIDs and resolve the expected type. Focused retained
method tests passed; GL-001/GL-002 remain open for broader lifetime qualification.
Callback references use non-recycled public IDs tied to a live owner, preventing
stale native handles from aliasing a replacement VM/anchor. External waits also
retain guards, including sources detached from the scene tree.

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

## Networking and persistence

`NetworkService` combines connection setup, ENet RPCs, players, puppet state,
replication, remote invocation, physics ownership, chat, and coordinator/world
process support in `src/services/roblox_network.h`.

RPC dictionaries use `RPC_MODE_ANY_PEER` in `_bind_methods`, relying on individual
handlers to enforce authority. Some do: structural replication checks sender 1,
RemoteFunction returns match the expected peer, and owned physics updates check
the owner. Character-state/removal receivers lack the same sender guard; state
relays trust supplied values and chat relays trust supplied display names.
See GL-006 through GL-008 for scope and missing runtime evidence.

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
tools, and update/restart behavior. Its URLs still target `Pimpoli/GodotLuau`
(`addons/GodotLuauUpdater/plugin.gd:4-39`), and `project.godot` enables the plugin.
Fork source changes do not automatically change its distribution source.

The single tracked Actions workflow, `.github/workflows/build-release.yml`,
builds Linux debug/release binaries, extracts Windows binaries from a committed
ZIP, packages releases, writes the archive back, and deletes older releases and
tags. It has no runtime-test or sanitizer step. The `test_chat/` fixture is not
an automated qualification gate.

## Task routing

| Area | Read implementation first | Related issues |
| --- | --- | --- |
| VM, require, tasks, shutdown | `src/core/gl_execution_domain.h/.cpp`, `gl_domain_host.h/.cpp`, `luau_script.h` | GL-001, GL-004, GL-014 |
| Native object methods | `src/core/luau_api.h`, `gl_runtime.h` | GL-001, GL-002, GL-013 |
| File/HTTP permissions | `src/core/luau_script.h`, `luau_stdlib.h` | GL-003, GL-004, GL-005 |
| RPCs, players, replication | `src/services/roblox_network.h`, `src/core/gl_net_bridge.h`, `src/gameplay/roblox_remote.h` | GL-006, GL-007, GL-008 |
| Persistence | DataStore section of `luau_stdlib.h`, native file bridge, `backend/README.md` | GL-009 |
| Build and release | `SConstruct`, `.gitmodules`, `.github/workflows/build-release.yml`, `tools/generar_release.py` | GL-010, GL-011, GL-012 |
| Editor updates and autocomplete | `addons/GodotLuauUpdater/plugin.gd`, `src/editor/luau_autocomplete.h` | GL-016 |
| Imported/bundled assets | `src/importer/`, `GodotLuau/assets/`, `GodotLuau/licenses/` | GL-015 |

Pinned submodules at baseline: `godot-cpp` =
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`; `luau` =
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.
