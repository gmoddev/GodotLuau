# Current architecture

Source-verified baseline: `7044a11c1bcc2eac2a91155e829a5821d92ab66e`,
checked 2026-10-26. No extension build, editor launch, runtime test, or network
exercise was performed for this documentation change. This describes structure,
not production qualification.

## Runtime and ownership

GodotLuau is a Godot C++ GDExtension embedding official Luau. `SConstruct`
compiles Luau VM/compiler/AST/Common sources and the extension's core `.cpp`
files. It does not select LuaJIT. `src/core/register_types.cpp` registers the
language, resource handlers, and Roblox-style native classes.

`ScriptNodeBase` derives from Godot `Node`. `ServerScript`, `LocalScript`, and
`ModuleScript` derive from it. Eligible executable script nodes create their own
`L_main` through `luaL_newstate()` and open libraries
(`src/core/luau_script.h:916-983`). ModuleScript returns before VM creation and
runs in the requiring script's VM; module results are cached in that VM's
registry (`1806-1828`). A module required by separate scripts does not therefore
share a cached result. Tasks use Luau coroutines inside those script VMs.

`GodotObjectWrapper` stores a Godot ObjectID, resolved through ObjectDB on access
(`src/core/gl_runtime.h:98-111`). This is not universal lifetime protection:
the local `WaitForChild` binding and NetworkService methods capture raw native
pointers (GL-001/GL-002). The live-state registry at `114-125` is a guard used by
callbacks, not proof that every native closure or shutdown path is safe.

Many Instance-facing classes adapt Godot Nodes; for example `RobloxPart` derives
from `RigidBody3D`. There are also Luau table-backed services and value datatypes.
Do not describe every exposed value or service as a Godot Node, or describe an
engine-neutral Instance ownership layer as already implemented.

## Script capabilities and scheduling

Per-script setup publishes `_FileAccess` and `_HTTP` into gameplay VMs.
The native file bridge accepts script paths directly without a role/capability
check or extension-level root confinement (`luau_script.h:1604-1642`). The higher
level DataStore wrapper rejects network clients, but this does not remove the
native global. OS permissions and platform restrictions still apply.

HTTP uses synchronous `HTTPClient` polling and delays on the calling thread
(`293-439`, `1725-1760`). It has a nominal ten-second timeout; this is not a
nonblocking scheduler or a demonstrated bound on every network/body path.
No explicit sandbox setup, instruction-interrupt budget, or custom memory quota
was found in extension VM initialization or the searched extension source.
Imported/community script isolation is not an established supported contract.

## Networking and persistence

`NetworkService` combines connection setup, ENet RPCs, players, puppet state,
replication, remote invocation, physics ownership, chat, and coordinator/world
process support in `src/services/roblox_network.h`.

RPC dictionaries use `RPC_MODE_ANY_PEER` (`616-659`), relying on individual
handlers to enforce authority. Some do: structural replication checks sender 1,
RemoteFunction returns match the expected peer, and owned physics updates check
the owner. Character-state/removal receivers lack the same sender guard; state
relays trust supplied values and chat relays trust supplied display names.
See GL-006 through GL-008 for scope and missing runtime evidence.

The coordinator uses local process discovery/heartbeat files. Upstream documents
no account authentication and no incoming connection validation against
`host.key`. The presence of that key is not authentication.

`DataStoreService` is embedded Luau in `src/core/luau_stdlib.h:603-763`.
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
| VM, require, tasks, shutdown | `src/core/luau_script.h`, `gl_runtime.h`, `gl_errors.h` | GL-001, GL-004, GL-014 |
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
