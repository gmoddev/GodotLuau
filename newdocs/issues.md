# GodotLuau issue ledger

Initial triage: 2026-10-26. Source baseline:
`7044a11c1bcc2eac2a91155e829a5821d92ab66e` / v1.16.12.
All entries are open. This file does not create upstream or GitHub issues.

Evidence is static unless explicitly stated otherwise. `Verified` establishes the
described implementation fact, not a reproduced crash/exploit. `Needs review`
identifies a missing material fact. `Design decision` is not a confirmed defect.
P1 = address before relying on the affected production feature; P2 = planned
engineering/design work. Priorities are not security severity scores.

See [review validation](review-validation.md) for the original claims,
counterevidence, security verdicts, and scope. Source line numbers below refer to
the baseline; preserve IDs when a refactor moves the implementation.

## Index

| ID | Priority | Classification | Summary |
| --- | --- | --- | --- |
| GL-001 | P1 | Verified lifetime hazard | WaitForChild closure retains raw Node pointer |
| GL-002 | P1 | Verified lifetime hazard | NetworkService closures retain raw service pointers |
| GL-003 | P1 | Verified exposure; boundary needs review | Native file global bypasses higher-level role restrictions |
| GL-004 | P1 | Verified control gap; impact needs review | No explicit VM sandbox or execution/memory quotas found |
| GL-005 | P2 | Verified blocking path; boundary needs review | HTTP blocks the calling thread and has no capability gate |
| GL-006 | P1 | Verified authority defect | State/removal receivers accept any-peer RPCs without sender guards |
| GL-007 | P1 | Verified acceptance; gameplay impact needs review | Character state is relayed without semantic validation |
| GL-008 | P2 | Verified identity defect | Chat display name comes from the sender's payload |
| GL-009 | P1 | Verified persistence defect | DataStore lacks competing-writer and crash-atomic semantics |
| GL-010 | P1 | Verified release gap | Windows artifacts are reused from a committed ZIP |
| GL-011 | P1 | Verified qualification gap | Release workflow has no automated runtime or sanitizer gates |
| GL-012 | P2 | Verified history-loss behavior | Workflow attempts to delete older releases and tags |
| GL-013 | P2 | Verified maintainability concern | Large implementation headers concentrate subsystems |
| GL-014 | P2 | Design decision | Evaluate per-script versus per-domain VM ownership |
| GL-015 | P2 | Needs review | Asset provenance is not established by root MIT license |
| GL-016 | P1 | Verified fork distribution gap | Enabled updater still downloads upstream packages |

## GL-001: Retained WaitForChild closure can outlive its Node

**Evidence:** `src/core/luau_script.h:988-1042` installs the actual metatable
lookup. At `1015` it captures `Node*` as lightuserdata; invocation at `1017-1023`
checks only non-null before dereferencing. `src/core/luau_api.h:375-391` exposes
destruction that queues the object for freeing. A retained method closure can
survive a different node's destruction while its calling script VM remains live.

**Consequence/limits:** Potential stale native dereference, contradicting universal
ObjectID-safety claims. Ordinary wrapper resolution is safer
(`gl_runtime.h:98-111`), but does not protect the captured pointer. No crash or
exploit was reproduced; security triage remains `needs_review`.

**Fix boundary and closure:** Replace the persistent native capture with stable
identity and live/type resolution on invocation. Test retaining the method,
freeing the target across a frame, then invoking it from a surviving VM. Also
test valid lookup, pending wait, timeout, and script shutdown. Define the stale
target result and prove no native crash or abandoned coroutine.

## GL-002: NetworkService method closures retain service pointers

**Evidence:** `src/core/luau_api.h:2333-2353` captures `nsvc` and later calls
members after only a null check. `2410-2429` repeats the pattern for queries.
These bindings are reached through `godot_object_index` from the script metatable.

**Consequence/limits:** Retained methods may outlive a destroyed/replaced service.
Non-null is not live-object validation. Actual service teardown timing and native
failure were not exercised; security triage is `needs_review`.

**Fix boundary and closure:** Use ObjectID-backed captures and resolve the expected
type at invocation. Cover service destruction/replacement with a surviving script,
stored getters and mutators, valid behavior, and pending callbacks. Review other
captures separately rather than claiming this entry covers all bindings.

## GL-003: FileAccess global bypasses DataStore's role guard

**Evidence:** `src/core/luau_script.h:1604-1642` unconditionally installs
`_FileAccess.read/write/exists/delete/list`; supplied paths reach FileAccess or
DirAccess without a native role, capability, or root check.
`src/core/luau_stdlib.h:627-633` rejects network clients only at the DataStore layer.

**Consequence/limits:** A running gameplay script can call the lower-level global
directly. This is not evidence that a remote player can inject script code, and
the supported hostile-package boundary is undocumented. OS/platform permissions
still apply. Security verdict: `needs_review`, rank 1 in that queue.

**Fix boundary and closure:** First specify trusted-host versus gameplay grants.
Enforce grants and canonical root confinement at native entry points, including
alternate path forms and failure paths. Test denied client/ungranted access,
absolute/traversal paths, permitted server persistence, and no partial mutation.
Keep any intentionally trusted host API distinct and explicit.

## GL-004: Explicit VM sandbox and execution limits are absent

**Evidence:** `src/core/luau_script.h:960-983` uses `luaL_newstate()` and
`luaL_openlibs()`. Targeted searches of `src/` found no sandbox initialization,
instruction-interrupt callback installation, or custom VM memory quota. Task and
callback execution resumes Luau synchronously; importer batching is unrelated.

**Consequence/limits:** No demonstrated isolation or protection against runaway
gameplay scripts. This does not prove a sandbox escape or disable Luau's internal
limits. No infinite loop or exhaustion test was executed. Security verdict:
`needs_review` pending the supported trust/resource contract.

**Fix boundary and closure:** Define grants, per-VM/domain resource accounting,
bounded resume/cancellation, and error propagation before implementation. Add
headless bounded tests for non-yielding work, excessive allocation, denied globals,
valid tasks, and shutdown. Run failure cases with crash UI suppressed.

## GL-005: HTTP is synchronous and broadly exposed

**Evidence:** `src/core/luau_script.h:293-439` implements `gl_http_perform` with
polling/delays; `_HTTP` is installed at `1725-1760` and used by HttpService.

**Consequence/limits:** Calls can stall the calling thread. The helper has a
nominal ten-second timeout, so it is incorrect to claim no timeout exists; this
is not a proven universal deadline or nonblocking execution. No native capability
or domain allowlist is present. Hostile-script/network impact needs deployment
context; no SSRF exploit or timing benchmark was performed.

**Fix boundary and closure:** Specify permitted hosts/grants and request/response
bounds, then use asynchronous I/O with coroutine completion, cancellation, and
shutdown-safe ownership. Test slow/failing endpoints, byte limits, denial, valid
requests, and continued frame/scheduler progress against explicit budgets.

## GL-006: Server-origin RPC receivers omit authority checks

**Evidence:** `src/services/roblox_network.h:616-630` configures state and removal
RPCs as ANY_PEER. `_recv_state`, `_recv_state2d`, and `_recv_remove` at `1825-1836`
do not validate the actual sender or receiver role. Removal reaches
`_remove_peer_player:1110-1117`, erases player tracking and queues the Player free.

**Boundary:** A connected peer's chosen RPC arguments reach operations documented
as server-to-client state/removal. This is a confirmed static authority defect,
rank 1 in the confirmed security queue. Exact client/server/topology effects have
not been reproduced. It is not a claim of unauthenticated Internet code execution.

**Counterevidence:** Structural replication checks sender 1 at `1737-1778`;
RemoteFunction replies check the expected peer at `1283-1291`; owned physics
checks the actual sender/owner at `1439-1449`.

**Fix handoff (`$fix-finding`):** Gate allowed receiver role and transport sender
before trusting `who`, updating puppets, or removing players. Choose appropriate
RPC authority configuration and retain defense at handlers. Test malicious
connected-client calls against server and another client, with no mutation,
callbacks, removal, or relay on rejection; preserve legitimate server updates
and disconnect cleanup. Pin the peer/topology configuration in evidence.

## GL-007: Character relay trusts supplied movement and health

**Evidence:** `src/services/roblox_network.h:1813-1822` derives sender identity,
then updates/relays supplied pose, display index, health, speed, and air state
without finite/range/movement checks in the relay.

**Consequence/limits:** The demonstrated sink is puppet/display state. Effects on
authoritative gameplay health, damage, progression, or economy were not
established. Transport-derived sender identity is positive counterevidence
against arbitrary identity selection on this particular path. Security verdict:
`needs_review`, rank 2 in that queue.

**Fix boundary and closure:** Document authority for each field and separate
client input from server-owned state. Enforce allowed role, finite values,
transitions, rate/size limits and game-specific movement policy before mutation
or relay. Test wrong-role, NaN/infinite/out-of-range/impossible updates plus valid
movement. Trace authoritative consumers before claiming a gameplay exploit.

## GL-008: Chat display identity is client supplied

**Evidence:** `src/services/roblox_network.h:1854-1862` reads the transport peer
ID but displays/relays the caller's `name`; `_show_chat:1841-1845` forwards it to
TextChatService. `_recv_chat` also lacks a server-sender guard.

**Boundary/limits:** A connected peer controls another displayed identity.
Confirmed static display-spoofing defect, rank 2 in the confirmed security queue.
The peer ID itself is not forged; this does not establish account takeover.

**Fix handoff (`$fix-finding`):** Derive sender identity/name from server-owned
player/session data, bound text and rate, and gate server-origin reception before
display. Test a connected client supplying another name or raw receive RPC,
unknown/disconnected senders, valid chat, and rejection without display or relay.

## GL-009: DataStore loses updates and has no crash-atomic write protocol

**Evidence:** `src/core/luau_stdlib.h:639-677` implements Get/Set/Update/Increment
as local JSON access. `UpdateAsync` is Get/transform/Set with no lock, version,
transaction, or CAS. Native writes at `luau_script.h:1614-1619` directly overwrite
the target. README's coordinator limits explicitly document shared `user://`.

**Consequence/limits:** Two world processes can read the same value and overwrite
one another; interruption can leave incomplete JSON. A single non-yielding
transform is not cross-process serialization. No corruption or competing-writer
failure was reproduced. The optional Nakama stack is not wired into DataStore.

**Fix boundary and closure:** Select/document one persistence authority and
concurrency/durability contract. SQLite or Nakama are options, not accepted
decisions. An atomic rename alone does not fix lost updates. Cover independent
process writers, retries/conflicts, cancellation, disk failure, interrupted commit,
restart, and preserving the previous committed value on failure.

## GL-010: Windows release binaries lack same-revision build evidence

**Evidence:** `.github/workflows/build-release.yml` builds Linux debug/release
with SCons, then extracts Windows binaries from `GodotLuau.zip`. It does not
compile Windows at the tagged source revision.

**Consequence/limits:** A mixed ZIP may combine binaries from different source
revisions; this workflow cannot establish their equivalence. It does not prove
every existing Windows DLL is stale or unsafe.

**Closure:** Build supported Windows/Linux variants from the same immutable
revision and pinned dependencies; record compiler/configuration, source digest,
binary hashes and required check results in release provenance. Remove committed
archive reuse as a substitute for source builds.

## GL-011: Automated runtime qualification is missing from release gates

**Evidence:** One tracked Actions workflow performs build/package/release steps
without runtime tests, multiplayer integration, or sanitizers. `test_chat/` has a
small scene/script fixture; it is not executed by the workflow.

**Consequence/limits:** Successful builds do not establish lifetime, scheduler,
authority, or persistence behavior. Private/untracked/manual tests may exist;
their absence was not proved. No runtime qualification was attempted here.

**Closure:** Introduce headless, bounded regression gates covering the relevant
bugs and supported configurations, including lifetime/reload, rejected RPCs,
multiple peers/processes, and persistence failures. Add appropriate native
sanitizer coverage and retain evidence. Keep docs-only checks lightweight.

## GL-012: Release workflow deletes prior provenance references

**Evidence:** The final release step lists up to 100 releases and attempts
`gh release delete --yes --cleanup-tag` on every tag except the current release.

**Consequence/limits:** This can remove useful published assets and source tags,
hindering rollback and historical verification. The workflow's existence does not
prove that all earlier releases were deleted.

**Closure:** Adopt an explicit retention policy preserving immutable release
tags, artifacts and provenance. Validate the changed workflow without performing
destructive deletion of real published history. Do not dispatch the inherited
workflow as a documentation check.

## GL-013: Implementation headers concentrate unrelated responsibilities

**Evidence:** Git blob sizes: `luau_api.h` 294380 bytes; `roblox_network.h` 154252;
`luau_autocomplete.h` 138520; `luau_script.h` 121617; `luau_stdlib.h` 116928;
`roblox_gui.h` 102551. `luau_script.cpp` is 172 bytes. These headers contain
implementations, not just declarations.

**Consequence/limits:** Review and dependency boundaries are difficult to isolate.
Compilation/rebuild cost was not measured. Header size alone is not a runtime
bug and does not justify a sweeping rewrite.

**Closure:** Extract cohesive implementation units incrementally with explicit
ownership/interfaces, preserve behavior, and measure build impact when claimed.
Avoid mixing mechanical movement with unrelated runtime changes.

## GL-014: Decide VM ownership using compatibility and measurements

**Evidence:** Per-executable-script `L_main` at `luau_script.h:960`; require's
registry cache at `1806-1828`; README explicitly documents isolated module state.

**Classification:** Design decision. The model is real; calling it inherently
wrong or too slow is not established. VM-per-domain may change shared state,
failure isolation, resource accounting, callback ownership, and require behavior.

**Closure:** Record requirements, compare per-script/domain/Actor-like isolation,
measure representative script-count memory/startup/scheduler costs, and select a
model with a migration plan and require/reload/cancellation tests. Do not mark
this as fixed merely by choosing the review's preference.

## GL-015: Establish asset-specific redistribution provenance

**Evidence:** Root LICENSE and `GodotLuau/licenses/` cover the project and named
software dependencies. `GodotLuau/assets/avatars/`, branding, and imported content
need their own provenance review before broad redistribution.

**Classification/limits:** Needs review; no infringement or ownership defect is
asserted. Filenames and similarity are not evidence of missing rights.

**Closure:** Inventory shipped assets, record origin/license/permission and
required notices, distinguish user-imported content, and replace or omit any
asset whose redistribution rights cannot be established.

## GL-016: Fork updater still installs from upstream

**Evidence:** `addons/GodotLuauUpdater/plugin.gd:4-39` hardcodes Pimpoli's
version, ZIP, hash, tag/history and model URLs. `project.godot:18` enables the
plugin. Creating the GitHub fork does not change those endpoints.

**Consequence/limits:** Using the updater can install upstream packages over fork
work or mix distributions. This docs-only bootstrap did not launch the editor,
download packages, change updater behavior, or publish fork binaries.

**Closure:** Decide fork update policy before distributing builds. Options
include disabling automatic updates or selecting verified, pinned fork releases.
Cover all version/archive/hash/history/model endpoints as appropriate, preserve
upstream attribution, verify failure paths, and distinguish inherited ZIPs from
fork-built artifacts. A URL replacement alone does not establish provenance.
