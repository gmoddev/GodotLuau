# GodotLuau issue ledger

Initial triage: 2026-10-26. Source baseline:
`7044a11c1bcc2eac2a91155e829a5821d92ab66e` / v1.16.12.
Historical evidence is preserved below. GL-001/GL-002 are resolved for their
specific captures, GL-014 is integrated into main and source-qualified, and GL-019
is optimized, qualified and integrated into main. GL-006/GL-008 are also integrated
into main and resolved for their qualified endpoints; GL-020 records a
separate animation authority gap. Other entries remain open. This file does not
create upstream or GitHub issues.

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
| GL-001 | P1 | Resolved within stated scope | Live receiver resolution; native ASan lifecycle evidence |
| GL-002 | P1 | Resolved within stated scope | ObjectID captures; service replacement and pending invoke cleanup |
| GL-003 | P1 | Verified exposure; boundary needs review | Native file global bypasses higher-level role restrictions |
| GL-004 | P1 | Verified control gap; impact needs review | No explicit VM sandbox or execution/memory quotas found |
| GL-005 | P2 | Verified blocking path; boundary needs review | HTTP blocks the calling thread and has no capability gate |
| GL-006 | P1 | Integrated; resolved within stated scope | Qualified native state/removal sender and receiver-role enforcement |
| GL-007 | P1 | Verified acceptance; gameplay impact needs review | Character state is relayed without semantic validation |
| GL-008 | P2 | Integrated; resolved within stated scope | Qualified server-owned chat identity, typed/bounded messages and receive authority |
| GL-009 | P1 | Verified persistence defect | DataStore lacks competing-writer and crash-atomic semantics |
| GL-010 | P1 | Verified release gap | Windows artifacts are reused from a committed ZIP |
| GL-011 | P1 | Verified qualification gap | Release workflow has no automated runtime or sanitizer gates |
| GL-012 | P2 | Verified history-loss behavior | Workflow attempts to delete older releases and tags |
| GL-013 | P2 | Verified maintainability concern | Large implementation headers concentrate subsystems |
| GL-014 | P2 | Integrated; source-qualified | Main contains shared domains; remaining limitations stay independently tracked |
| GL-015 | P2 | Needs review | Asset provenance is not established by root MIT license |
| GL-016 | P1 | Verified fork distribution gap | Enabled updater still downloads upstream packages |
| GL-017 | P2 | Reproduced external engine defect | Godot simultaneous-disconnect relay sends to reset peer and leaks packet |
| GL-018 | P2 | Native sanitizer qualification gap | Windows stock host plus ASan DLL hangs on exit, also with baseline |
| GL-019 | P2 | Integrated; optimized and source-qualified | Main retains revision-aware cache, smaller snapshots and measured tradeoffs |
| GL-020 | P1 | Verified static animation authority defect | Animation receive/relay RPCs still accept unauthorized presentation changes |

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

**Migration update (2026-10-26):** WaitForChild now resolves its receiver's
ObjectID at invocation and records guarded waits with the domain host. The
headless native fixture passed valid/pending/timeout paths, destruction while
waiting and retained invocation after target destruction (returns nil), plus
scene replacement. See [validation](shared-domains-validation.md). Kept open:
the Godot adapter/executable were not sanitizer-instrumented and this does not
establish universal binding lifetime safety. Original evidence above is historical.

**Resolution (continuation qualification):** The full Linux engine, pinned
bindings, adapter and Luau now run with ASan/LSan. Ten repetitions (80 native
process results) cover the retained closure after target free, valid/pending/
timeout cases, destruction while waiting, script cancellation and scene
replacement. Windows Debug/Release pass the same native fixture. The stated
capture's closure criteria are satisfied; GL-018 separately bounds Windows native
sanitizer coverage. See [continuation evidence](shared-domains-validation.md#continuation-qualification-2026-10-26).

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

**Migration update (2026-10-26):** NetworkService method closures now retain
ObjectIDs and resolve the expected service type through GLNodeUpvalue. Native
listen/network fixtures passed valid getters/mutators, retained GetPeerId and
Disconnect after service destruction, yielding callbacks and cancellation of an
outstanding response. Kept open for broader native adapter lifetime/sanitizer
qualification; these focused results do not qualify every binding.

**Resolution (continuation qualification):** Added live service replacement
while a surviving script retains getters/mutators; stale methods cannot act on
the replacement. A newly reproduced pending-invoke teardown failure is fixed by
disconnecting/failing pending calls at active service exit. Windows Debug/Release
and full Linux ASan/LSan lifecycle stress pass these paths. The stated capture's
criteria are satisfied; this does not qualify every service binding. See
[continuation evidence](shared-domains-validation.md#continuation-qualification-2026-10-26).

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

**Status (2026-10-27): INTEGRATED AND RESOLVED for state/2D-state/removal endpoints
in main through `2e69d8ac703d3f968e42054871511111ab8471be`.** Original static
evidence and counterevidence are preserved below. The unchanged main runtime's
state/removal effects were subsequently reproduced over actual ENet.

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

**Correction and executed closure:** Implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6` adds authority RPC configuration and
native Client-role/actual-server-sender checks before mutation. Client-origin
state relays also require a Server role and active assigned transport sender,
closing the direct-relay-to-client path. Positive mapped target identities are
required for state; legitimate removal can follow transport departure. Server
session indices replace client-chosen name indices. Callback reentrancy is
followed by ObjectID/sender revalidation before forwarding.

Actual two-client transport attacks against server and victim cover forged/self/
invalid targets, both dimensions, removal and teardown timing. Player/character
state and removal callbacks remain unchanged; legitimate state and real disconnect
cleanup pass. Tests also relax RPC filtering to ANY_PEER and establish native
handler rejection separately. Windows/Linux Debug/Release and matching Linux
full-native ASan/LSan pass. See the [authority report](network-authority-validation.md)
and [immutable qualification manifest](evidence/gl006-008-qualification-2026-10-27.json).
GL-007 and GL-020 remain independent; this closes the named position/health/
removal entry points, not all player presentation or networking authority.
The [main integration record](network-authority-validation.md#main-integration-2026-10-27)
distinguishes fresh integrated-revision checks from retained branch qualification.

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

**Status (2026-10-27): INTEGRATED AND RESOLVED within the qualified chat/session
scope in main through `2e69d8ac703d3f968e42054871511111ab8471be`.** The original finding
is preserved below; baseline ENet tests subsequently reproduced name spoofing.

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

**Correction and executed closure:** Implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6` resolves the active transport sender to
its live server-owned PlayerObject and matching assigned session UserId. Submitted
names are ignored, and first-state display indices can no longer poison that
record. Receive and relay handlers validate receiver role and transport sender.
Original Variant types are checked before conversion: a real Array attack showed
that Godot's binder could stringify invalid text despite reporting an error.

The shared acceptance path rejects missing/stale records, invalid/oversized text,
and excessive rate before display/relay. The policy is 256 Unicode scalars,
five burst tokens and one token/second. Sender UI waits for accepted server echo;
single-player/system chat, including no Players service, remains supported.
RPC argument counts/order and valid string wire payloads remain unchanged.

Transport tests demonstrate replacement of other-player/system names, rejection
of raw receive/relay spoofing, pre-initialization/disconnected/invalidated records,
malformed/oversized/control text, Unicode bounds and bursts. They also establish
normal multi-client/server/local UI chat, refill/independent allowance and real
reconnect/record replacement. Platform and sanitizer coverage is the same as
GL-006; see the [report](network-authority-validation.md) and
[manifest](evidence/gl006-008-qualification-2026-10-27.json).
Session identities are not authenticated accounts. Deterministic numeric peer-ID
collision, mixed historical-client versions and malformed UDP framing were not
forced. GL-017/018 and unrelated capability/security findings remain open.
The [main integration record](network-authority-validation.md#main-integration-2026-10-27)
retains these limits and records fresh focused checks without a new security phase.

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

**Continuation:** Manual same-source Windows/Linux qualification builds and the
explicit-input local package are recorded in the shared-domain validation report.
The inherited release workflow still reuses its ZIP; GL-010 remains open for
published release provenance and workflow correction.

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

**Continuation:** Bounded cross-platform runtime runners, focused regressions and
native Linux ASan/LSan evidence now exist under `tests/runtime`. They are manual
qualification gates; the inherited release workflow still does not enforce them,
so GL-011 remains open.

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

## GL-014: Shared execution domains — integrated and source-qualified

**Evidence:** Per-executable-script `L_main` at `luau_script.h:960`; require's
registry cache at `1806-1828`; README explicitly documents isolated module state.

**Original classification:** Design decision. The baseline model was real;
calling it inherently wrong or too slow was not established.

**Implemented:** The owner explicitly requested migration on 2026-10-26.
Implementation commit:
[`521265c338fc890a0e30b9e8a556f6346baf7d00`](https://github.com/gmoddev/GodotLuau/commit/521265c338fc890a0e30b9e8a556f6346baf7d00).
[ADR-001](adr-001-shared-execution-domains.md) compares per-script, per-domain,
universal and Actor-like ownership and records compatibility before runtime edits.
GLExecutionDomain owns the VM/cache/scheduler and script/module identities;
GLDomainHost owns applicable Server/Client domains for the running scene/process.
No per-executable VM or permanent legacy scheduler remains. Environments,
sticky module failures, invalidation, shared state, shutdown, role boundaries and
native callback ownership are described in [current architecture](current-architecture.md).

**Executed evidence:** 35 production-core regressions pass in Windows MSVC
Debug and ASan, including deep require/spawn dispatch after an ASan-discovered
stack overflow was fixed. Actual GDExtension fixtures pass single-player,
listen-host, dedicated server plus two clients, and editor-style two-client
launch flags. They exercise native signals/remotes, script/module lifecycle,
Instance value replication, identity and wrong-role checks. See exact commands,
limits and artifact identity in [validation](shared-domains-validation.md), and
the investigation history in [work log](shared-domains-work-log.md).

**Status: OPEN for qualification.** Implementation and exercised functional
acceptance are delivered. Representative old/new startup/memory/scheduler costs
have not been measured; no performance or scalability claim is made. Linux,
release/SCons packaging, a full graphical editor session, coordinator deployment
and sanitizer-instrumented Godot/native adapters were not qualified. ENet
`max channels: 0` teardown diagnostics occurred in a passing multi-process run;
baseline attribution remains unresolved. Close only with linked qualification
evidence and an explicit disposition of these remaining acceptance/proof gaps.
GL-003 through GL-009 and GL-016 remain independent issues.

**Continuation disposition (2026-10-26): CLOSED for the requested migration and
source-qualification scope; CONDITIONALLY READY for source integration.** The
historical open status above describes the initial report. Windows/Linux CMake
and SCons Debug/Release, 36 core cases with repeated Debug/Release/
ASan suites, and full Linux native ASan/LSan stress establish the exercised
acceptance facts. Controlled old/new 10/100/1,000-script benchmarks show lower
startup/RSS and slower cached require/task bookkeeping. The validation report
records exact figures, build/package disposition, commands and limitations.
Remaining independent engine, Windows sanitizer-host and performance follow-ups
are GL-017/GL-018/GL-019; graphical editor/coordinator/production content remain
unqualified. This closes neither production distribution nor unrelated issues,
and does not authorize merging main or publishing binaries.

**Authorized integration (2026-10-26): INTEGRATED WITH QUALIFICATION LIMITATIONS.**
Normal merge `dd68cda850fb548aa7713242275ff73c183e813c` integrates source
`9423fed4051bec2fba798d9a49eaec7dea6cca3b` into main, preserving all four
source commits without conflicts. The merge tree is identical to that qualified
source. Fresh Windows/Linux Debug/Release builds and native fixtures plus core
ASan checks pass; exact scope and reused immutable evidence are in the
[integration record](shared-domains-validation.md#main-integration-2026-10-26).
GL-014 remains closed for its implementation/source-qualification scope and is
now integrated. GL-017/GL-018/GL-019, production networking, persistence,
capabilities and distribution limitations remain independently open. The
integration does not publish production binaries or change updater behavior.

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

**Branch implementation (2026-10-27): IMPLEMENTED AND FUNCTIONALLY VERIFIED on
`maintenance/gl-016-fork-updater`; NOT MERGED.** Runtime checks/download/apply,
callbacks, history, unverified backup restore, staging/swap/restart and destructive
startup cleanup fail closed before side effects. Enabled editor tools and explicit
model/custom-autocomplete downloads remain available. Both Windows/Linux actual
headless editor fixtures pass 596 assertions across 42 blocked operations and two
localhost optional-data downloads, preserving installed files/backups/metadata.
See [policy/recovery/limits](fork-updater-isolation.md) and
[evidence](evidence/gl016-updater-isolation-2026-10-27.json). Main still requires
separate authorized integration; no fork production update channel or distribution
provenance is established. Original evidence and GL-010/011 remain independent.

## GL-017: Godot simultaneous-disconnect relay targets reset peers

**Status: OPEN; reproduced external engine defect, P2 for source integration.**
Godot 4.7.1 at `a13da4feb8d8aefc283c3763d33a2f170a18d541` reproduces
zero-channel sends with two disconnects before a server poll, without loading
GodotLuau. The full engine-only ASan/LSan probe also leaks 54 bytes (48+6).
Relay-off isolates the engine notification; synchronous application sends add a
second timing hazard, corrected here by deferred NetworkService callbacks.

**Boundary:** Production engine relay remains enabled; diagnostics and failed
leak gate remain visible. Ordered-close native stress isolates extension lifetime
checks but does not fix this engine edge. No upstream issue/message was created.

**Closure:** A separately reviewed Godot patch or verified engine version must
pass the existing simultaneous-close probe with relay on, no diagnostics and
ASan/LSan clean exit, then pass native two-client teardown. Preserve the exact
engine/source reproduction in [validation](shared-domains-validation.md).

## GL-018: Windows full-native sanitizer host remains unqualified

**Status: OPEN; bounded qualification gap.** MSVC-instrumented adapter/bindings/
Luau reaches functional PASS under stock Godot, then times out at exit. A
registration-only inherited baseline and candidate both reproduce the timeout
without any script/domain/network. Core ASan and normal Windows Debug/Release
native fixtures pass; full native Linux ASan/LSan passes ordered lifecycle stress.

**Closure:** Build a matching Windows Godot sanitizer host with compatible runtime
and rerun registration plus native lifecycle fixtures with bounded clean exit.
Do not label the current timeout as successful native coverage, infer all Windows
bindings safe from Linux evidence, or suppress the failure.

## GL-019: Shared-domain cached require and task overhead regresses

**Original status: OPEN; measured P2 performance tradeoff.** Three counterbalanced Linux
Release trials at 1,000 scripts measure 100,000 cached requires at median
129.327 ms baseline versus 194.723 ms shared, and 32,000 create/cancel pairs at
7.803 versus 19.973 ms. Startup/RSS improve substantially in that workload.
Source trace identifies source/path construction before the shared cache lookup,
plus rooted owner/task records and deferred safe reaping. Exact cost fractions
and isolated scheduler CPU time are not established.

**Correction already made:** A much larger pilot cancellation regression came
from unconditional native scene/guard scans; a registered-native-wait bit removes
irrelevant scans while preserving actual wait cleanup. Final figures above are
after that correction, not the failing pilot.

**Closure:** Profile cache/task paths, optimize only demonstrated costs while
preserving source invalidation/owner guarantees, and repeat the controlled
benchmark/regressions. Add a scheduler-only CPU measurement if making a scheduler
speed claim. [Raw data](evidence/shared-domains-benchmark-2026-10-26.json) and
[method/limits](shared-domains-validation.md) are retained.

**Resolution (2026-10-26): OPTIMIZED AND QUALIFIED on `perf/gl-019-hot-paths`; not
merged into main.** Runtime commit `1756cc2600e5a59ea948e69a684f5abd93e32229`
follows measured native perf sampling and controlled baseline reproduction.
Native cache hits validate module/resource identity and source revision, loading
source/path only on misses. Source revision increments before changed-signal
delivery. Task snapshots preallocate and avoid unused live-record shared_ptr
copies while preserving strong references during dispatch/cleanup.

At 1,000 scripts, seven counterbalanced pre/post trials measure cached requires
198.230 → 82.433 ms, startup 290.204 → 171.446 ms and RSS growth
57.203 → 56.230 MiB. The captured-module loop falls from 1,054.330 to
163.508 ms per million calls. Core snapshots allocate once rather than eleven
times at 1,000 tasks. Create/cancel bursts remain about 20 ms versus the original
per-script baseline's ~8 ms: strong task/owner records and their two C++ allocations
are retained. Pools/raw-pointer records were not adopted; they do not remove the
initial burst's lifetime requirements and add unjustified complexity/risk.

The established 36 cases plus three focused metadata/revision cases pass five
times in Windows/Linux Debug/Release/core ASan; normal native fixtures and full
Linux native ASan/LSan also pass, including a changed-subscriber ordering check.
This completes the measured optimization task under its stated acceptance
criteria, not a claim that every task operation beats the old architecture.
No public behavior, VM ownership, environments, pins or updater changed. Further
task-creation work is an optional profiled follow-up; no additional evidence is
required to retain these changes. See the [GL-019 report](shared-domains-validation.md#gl-019-optimization-2026-10-26)
for all spreads, CPU/allocation limits, rejected candidates and raw records.

**Integration (2026-10-26):** Main now preserves all three GL-019 commits through
normal merge `6badbae4b467a5544ffd027a1c7d7bd505cd0d46`, with no conflicts.
Its complete source tree equals qualified branch revision
`ad200aa468be56edf4812bb3a03daeb31d5bbdd8`; runtime/build/test code equals
`1756cc2600e5a59ea948e69a684f5abd93e32229`. The
[integration record](shared-domains-validation.md#gl-019-main-integration-2026-10-26)
distinguishes fresh checks from reused historical measurements. GL-019 stays
resolved for its measured scope. GL-017/GL-018 and the independent capability,
networking, persistence, asset and distribution issues remain open.

## GL-020: Animation RPCs omit sender and receiver-role authority

**Status (2026-10-27): OPEN; source-verified independent presentation authority
defect, P1. No adversarial animation runtime reproduction is claimed.**

**Evidence:** At security implementation
`b839ea4a6d1ce46cceef9eb4eb58a7b210ea56c6`, `_setup_rpcs` still configures
`_relay_anim` and `_recv_anim` as ANY_PEER (roblox_network.h:703-704).
`_recv_anim:2027-2031` checks only whether payload `who` is the local peer, then
`_apply_anim_puppet:2032-2040` writes `peer_anim[who]` and invokes `gl_anim_apply`
on an existing puppet. `_relay_anim:2022-2026` likewise lacks receiver-role/
current-sender membership enforcement before applying and relaying.

**Boundary and scope:** A connected peer can choose a different remote puppet's
animation state via these entry points. This is a static presentation-authority
defect; no position/health mutation, player removal or chat sink is reached by
these animation methods. It therefore does not bypass the qualified GL-006/008
endpoint corrections, but prevents a general claim that every presentation RPC
is protected. GL-007's movement semantics are separate too.

**Closure:** Apply server-origin/client-origin role and transport-sender checks,
preserve valid ownership/late-join animation behavior, and demonstrate actual
two-client rejection without animation/cache/relay effects plus valid play/stop.
Do not close based only on a helper test or compilation. No animation fix is
included in the GL-006/008 branch.

**Functional implementation (2026-10-27): delivered on
`fix/gl-020-animation-lifecycle`; security qualification remains OPEN.** Runtime
commits `f9b27c6b6bb3caa3b8b617e029d45c858a546f9a` and
`7212b87e71f539a80d8e6b6977510fa075c0a2ba` add existing execution-role/
transport-sender guards, current service/session validation and AUTHORITY receive
configuration. Cached animation records bind the server-assigned UserId, preserve
pre-puppet/late-join updates and clear at character/session/service boundaries.
Tracks resolve AnimationPlayers by ObjectID; settings/completion replicate and
loaded clips are independent per character. No wire signature or shared-domain/
GL-019 ownership/hot-path change is introduced.

The [functional record](animation-lifecycle-validation.md) and its evidence
manifest distinguish exercised playback/lifecycle checks from closure acceptance.
GL-020 is **partially qualified**, not closed: actual two-client forged animation
receive/relay traffic, native handler guards with RPC authority relaxed, and
proof of rejection without cache/animation/relay effects remain for the security
follow-up. Existing GL-006/008 adversarial regressions are retained and passing;
they are not animation security qualification. GL-017/GL-018 remain independently
open. This branch is not merged into main and publishes no binaries.

**Executed functional qualification:** Windows/Linux Debug/Release core and
native groups, Windows core ASan and Linux full-native ASan/LSan pass. The 39-case
core runs in six configurations; four SCons builds pass and run their animation
fixtures. All 180 final native process results pass (90 animation, 40 existing
multiplayer/lifetime, 50 GL-006/008). Source/fixture and binary hashes match across
the checkout/workers; the [manifest](evidence/gl020-animation-qualification-2026-10-27.json)
retains exact evidence and failed fixture-attempt dispositions. No full animation
security closure is inferred from these results.

**Integration (2026-10-27): INTEGRATED FUNCTIONAL IMPLEMENTATION — SECURITY
QUALIFICATION PENDING.** Normal merge `6b140427e8ab39d97e12ee693f7cbda72abc7bba`
preserves all four GL-020 commits with a tree identical to qualified branch
`8e21d18a5504e0d703efbcf2a71a53d56314058e`. The
[integration record](animation-lifecycle-validation.md#main-integration-2026-10-27)
distinguishes fresh functional checks from reused immutable qualification.
GL-020 remains OPEN for animation-specific adversarial transport/handler evidence;
the historical finding and closure requirements above remain applicable. No
deferred adversarial qualification, binary release or general security certification
is performed by this integration. GL-007/GL-017/GL-018 remain independent.
