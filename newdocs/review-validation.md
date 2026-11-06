# Validation of the supplied architecture review

Validated 2026-10-26 against upstream and initial fork source commit
`7044a11c1bcc2eac2a91155e829a5821d92ab66e` (`Version`: v1.16.12).
Upstream `main` still resolved to that revision at inspection time. The source
is MIT licensed under PimpoliDev's existing notice.

Method: targeted static source inspection, README/deployment context, tracked-file
inventory, workflow inspection, and GitHub metadata. No build, binary execution,
crash PoC, multiplayer session, filesystem abuse, backend launch, sanitizer run,
or load benchmark was performed. There is no applicable tracked `SECURITY.md` in
the reviewed tree; supported hostile-script isolation is consequently a proof
gap, not an assumed contract.

The supplied prose is a freeform external review, not a completed Codex Security
scan. Its source observations are largely supported, but its production verdict
and architectural preferences are judgments rather than measured results.

## Claim-by-claim result

| Supplied section/claim | Result | Evidence and qualification |
| --- | --- | --- |
| Identity: reviewed `main`, v1.16.12, MIT | Verified | Full commit above; `Version`, `LICENSE`. The link/image caption mentioning LuaJIT does not describe this runtime: `SConstruct` embeds official Luau sources. |
| 1. Broad Godot/Roblox integration | Supported structurally | `register_types.cpp`, API bindings, editor plugin, importer, gameplay/services. Feature presence does not establish feature completeness or production quality. |
| 2. One VM per executable script | Verified | [VM creation](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/core/luau_script.h#L916-L983); module cache in the same file at `1806-1828`. ModuleScript itself does not start an independent VM. |
| 2. Module state differs across scripts | Verified structurally | Registry-local require cache plus separate `L_main` states. Memory/initialization cost at scale was not measured. VM-per-domain is a proposal, not a demonstrated best choice here. |
| 3. ObjectID wrappers but raw closure captures | Verified lifetime hazard | [Wrapper resolution](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/core/gl_runtime.h#L98-L125) versus [WaitForChild capture](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/core/luau_script.h#L1014-L1041). NetworkService captures are in `luau_api.h:2333-2353`, not the cited script section. No crash/exploit was executed. |
| 4. Broad file/HTTP capabilities | Exposure verified; security boundary needs review | [Native file bridge](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/core/luau_script.h#L1604-L1642); HTTP at `1725-1760`. The DataStore role guard does not protect direct globals. OS/platform restrictions remain; hostile community-script support is not established. |
| 4. No explicit sandbox or instruction budget found | Supported within searched extension source | VM setup calls `luaL_newstate`/`luaL_openlibs`; no `luaL_sandbox`, `luaL_sandboxthread`, interrupt callback installation, or custom allocator quota found in `src/`. This is not proof of a demonstrated sandbox escape or total absence of Luau's own internal limits. |
| 5. Inconsistent RPC authority | Verified missing receiver guards | [RPC setup](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/services/roblox_network.h#L616-L659) and [state/removal handlers](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/services/roblox_network.h#L1813-L1836). ANY_PEER alone is not a defect; missing checks on server-origin operations are the issue. Actual connected-peer effects require integration tests. |
| 5. Movement/health payloads unvalidated | Verified acceptance; gameplay impact needs review | `_relay_state` derives sender ID but forwards supplied pose/health/animation values. The trace establishes puppet/display state, not arbitrary authoritative game-health, inventory, or currency mutation. |
| 5. Client-chosen chat identity | Verified | `_relay_chat` at `1854-1857` displays/relays the supplied name. This supports display spoofing, not account takeover. |
| 5. Existing checks on other paths | Verified counterevidence | Replication guards `1737-1778`; RemoteFunction expected-peer check `1283-1291`; owned physics check `1439-1449`. Preserve these rather than claiming there is no security logic. |
| 5. No account authentication; host key unused for connection validation | Supported | README security section; `host_secret` references in `roblox_network.h` cover loading, forwarding and local startup, not an incoming connection check. A public ENet endpoint is not evidence of authenticated player accounts. |
| 6. Nontransactional, non-atomic DataStore | Verified implementation gap | [Read/modify/write](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/src/core/luau_stdlib.h#L639-L677); native bridge opens target with WRITE and stores text. Shared-world storage is documented. No competing-writer/crash test was run. |
| 7. Large implementation headers | Verified | Exact Git-blob sizes below. Compile/rebuild/review cost is a plausible maintenance concern, not benchmarked evidence. |
| 8. Linux builds, Windows ZIP reuse | Verified | [Release workflow](https://github.com/Pimpoli/GodotLuau/blob/7044a11c1bcc2eac2a91155e829a5821d92ab66e/.github/workflows/build-release.yml) builds only Linux; release job extracts Windows binaries. Windows provenance cannot be inferred from the release's source revision. |
| 8. Successful build runs exist | Verified narrowly | GitHub metadata reported [run 36233859828](https://github.com/Pimpoli/GodotLuau/actions/runs/36233859828) successful for `329f20813c7ecf8440b8bc26fb93263743b653b2`. This is a different revision; logs and artifacts were not qualified. |
| 8. No meaningful automatic runtime gates | Supported for tracked workflow | One tracked Actions workflow; no test/sanitizer step or substantial tracked dedicated suite beyond `test_chat/`. This says nothing about untracked/private/manual tests. |
| 8. Deletes older releases and tags | Verified | Final workflow step runs `gh release delete --yes --cleanup-tag` for older entries returned by a list limited to 100 releases. It attempts deletion, rather than proving every historical release has been removed. |
| 9. Architecture replacements | Design proposals | Shared VMs, configurable services, engine-neutral Instances, separate coordinator, transactional storage, modular editor/gameplay, optional avatar/menu packages, and pinned updates need separate decisions and migrations. SQLite is one option; Nakama plans already exist. |
| 9. Every Instance type is backed directly by a Godot Node | Too broad | Many classes are Node adapters, but Luau service tables and value datatypes also exist. Scope the coupling claim to the Node-backed Instance facade. |
| 10. Components worth reusing | Supported as references only | ObjectID wrappers, conversions, signals, loaders, datatypes, replication, and `.rbxl` importer code exist. Their presence does not qualify them for safe standalone reuse. |
| Final: unsuitable as a public multiplayer foundation | Reasonable risk assessment, not measured certification | Confirmed boundary gaps justify qualification work before production adoption. This review neither proves every game unsafe nor supplies production/load acceptance results. The suggested `fernforestgames/luau-gdextension` comparison was not performed. |

## Header size check

Sizes are Git blob bytes at the baseline, before Windows checkout line-ending
conversion. The review's rounded values are accurate.

| File | Bytes |
| --- | ---: |
| `src/core/luau_api.h` | 294380 |
| `src/services/roblox_network.h` | 154252 |
| `src/editor/luau_autocomplete.h` | 138520 |
| `src/core/luau_script.h` | 121617 |
| `src/core/luau_stdlib.h` | 116928 |
| `src/ui/roblox_gui.h` | 102551 |
| `src/core/luau_script.cpp` | 172 |

## Security triage versus engineering facts

For supplied security claims, the static triage results preserve their order:

| Input | Security verdict | Confidence | Queue rank | Remaining fact |
| --- | --- | --- | --- | --- |
| GL-001 retained WaitForChild pointer | needs_review | medium | needs_review 3 | Runtime destruction timing and hostile-script/native boundary |
| GL-002 retained NetworkService pointer | needs_review | medium | needs_review 4 | Service destruction while another VM/closure survives |
| GL-003 filesystem capability exposure | needs_review | medium | needs_review 1 | Supported lower-trust script contract and deployment permissions |
| GL-004 sandbox/execution quotas | needs_review | medium | needs_review 5 | Supported isolation/resource contract and exercised exhaustion behavior |
| GL-005 synchronous broad HTTP | needs_review | medium | needs_review 6 | Script trust and deployment-specific host/network access |
| GL-006 missing RPC sender guards | confirmed | high | confirmed 1 | Reproduce exact peer/topology effects; static authority violation is established |
| GL-007 unvalidated character state | needs_review | medium | needs_review 2 | Consequences beyond accepted puppet/display state |
| GL-008 chat display identity | confirmed | high | confirmed 2 | Integration regression; no account identity claim is made |

The established remote boundary is a connected peer entering native RPC
handlers, then state mutation/removal or chat display. Native script hazards are
real engineering concerns, but undocumented script trust must not be replaced by
an invented attacker model. The [issue ledger](issues.md) supplies focused fix
boundaries and closure criteria. Nothing was fixed by this documentation change.
