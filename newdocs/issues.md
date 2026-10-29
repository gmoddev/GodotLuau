# GodotLuau issue ledger

Initial triage: 2026-10-26. Source baseline:
`7044a11c1bcc2eac2a91155e829a5821d92ab66e` / v1.16.12.
Historical evidence is preserved below. GL-001/GL-002 are resolved for their
specific captures, GL-014 is integrated into main and source-qualified, and GL-019
is optimized, qualified and integrated into main. GL-006/GL-008 are also integrated
into main and resolved for their qualified endpoints; GL-020 records a
separate animation authority gap. GL-022 is fixed and qualified on its dedicated
branch and now integrated into main. Other entries remain open. This file does not
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
| GL-004 | P1 | Integrated qualified source; main CI pending | Shared-domain sandbox, interruption, allocator/admission limits |
| GL-005 | P2 | Verified blocking path; boundary needs review | HTTP blocks the calling thread and has no capability gate |
| GL-006 | P1 | Integrated; resolved within stated scope | Qualified native state/removal sender and receiver-role enforcement |
| GL-007 | P1 | Verified acceptance; gameplay impact needs review | Character state is relayed without semantic validation |
| GL-008 | P2 | Integrated; resolved within stated scope | Qualified server-owned chat identity, typed/bounded messages and receive authority |
| GL-009 | P1 | Verified persistence defect | DataStore lacks competing-writer and crash-atomic semantics |
| GL-010 | P1 | Verified release gap | Windows artifacts are reused from a committed ZIP |
| GL-011 | P1 | Open; core and qualified native CI integrated | Sanitizers and release enforcement remain manual/incomplete |
| GL-012 | P2 | Integrated; resolved within stated scope | Historical releases/tags retained; publication disabled |
| GL-013 | P2 | Open; five extractions integrated | API/stdlib fan-out three to one; bootstrap owned by script CPP |
| GL-014 | P2 | Integrated; source-qualified | Main contains shared domains; remaining limitations stay independently tracked |
| GL-015 | P2 | Needs review | Asset provenance is not established by root MIT license |
| GL-016 | P1 | Integrated; resolved within isolation scope | Runtime updates fail closed; editor tools remain available |
| GL-017 | P2 | Reproduced external engine defect | Godot simultaneous-disconnect relay sends to reset peer and leaks packet |
| GL-018 | P2 | Native sanitizer qualification gap | Windows stock host plus ASan DLL hangs on exit, also with baseline |
| GL-019 | P2 | Integrated; optimized and source-qualified | Main retains revision-aware cache, smaller snapshots and measured tradeoffs |
| GL-020 | P1 | Verified static animation authority defect | Animation receive/relay RPCs still accept unauthorized presentation changes |
| GL-021 | P2 | Verified construction-order discrepancy; runtime unexercised | Inert signals omit lowercase once/wait aliases |
| GL-022 | P2 | Integrated; fixed and qualified | Distinct native subscription identities and owner cleanup on main |

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

## GL-004: Explicit VM sandbox and execution limits

**Inherited evidence:** `src/core/luau_script.h:960-983` uses `luaL_newstate()` and
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

**Development status:** `runtime/gl-004-execution-limits`, based on main
`8aec90252d10f7dcec97e97423ca390467087711`, implements explicit intrinsic/root
sandbox sealing, private owner environments, shared attempt deadlines, actual
allocator quotas with terminal domain retirement, admission caps and diagnostics.
The [policy decision](adr-002-domain-resource-policy.md) distinguishes gameplay
from trusted bootstrap and preserves GL-003/005 as separate capability issues.
The [work/validation record](execution-limits-validation.md) and linked manifest
record six final 66-case core configurations, 180 native actors, four SCons
products with 32 resource actors, representative default-policy workloads and
the failures/corrections that led to this source. Implementation `1e201ed` and
fixture follow-up `040996e` preserve published history. Fresh hosted
[core 40857805897](https://github.com/gmoddev/GodotLuau/actions/runs/40857805897)
passes 66 cases on both platforms; fresh
[native 40857806041](https://github.com/gmoddev/GodotLuau/actions/runs/40857806041)
passes all 36 actors on both. All downloaded artifact digests, source/harness/
engine identities and retained native log hashes verify. The initial Windows
fixture failure remains recorded, with bounded positive-state delivery correction
and 65 passing follow-up actors across the existing worker configurations/trials.
**FIXED AND QUALIFIED on this branch**, within the linked resource contract.
It is not a hostile-script isolation claim. Normal merge `55a9c20` integrates the
qualified source; fresh main CI remains pending. See the integration record below
the historical branch evidence in [the work record](execution-limits-validation.md#main-integration).

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

**Original evidence:** One tracked Actions workflow performs build/package/release steps
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

**First CI milestone (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`f0199004d56485ec7a9de14d5454d1907822ba11` preserves source branch
`ci/gl-011-core-qualification` at `95167299ad8a102b23fb3b25284a751483815779`.
Adds a separate read-only, non-publishing
Windows/Linux Debug workflow for the existing 39-case production-core suite.
Recursive pinned checkout, bounded compilation and deadlines, explicit discovery
and full completion checks reject missing/partial evidence. No new runtime or
duplicate scheduler is introduced. Diagnostic artifacts exclude production
binaries. See [commands, actual outcomes and limitations](shared-domains-validation.md#gl-011-independent-core-ci-2026-10-27).
Hosted [run 40475254435](https://github.com/gmoddev/GodotLuau/actions/runs/40475254435)
passes both Windows MSVC and Linux GCC Debug jobs, 39 cases each, including
discovery/report checks and diagnostic uploads. Fresh main integration
[run 40476321167](https://github.com/gmoddev/GodotLuau/actions/runs/40476321167)
also passes both jobs, all 39 cases each, with reports and diagnostics retained.
The release workflow stays disabled. Native Godot, multiplayer/lifecycle/security
fixtures, sanitizers, persistence failures and release enforcement remain manual
or independently incomplete. This milestone does not close GL-011 or qualify
GL-020's deferred adversarial cases.

**GL-011B native milestone (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`9029d01a24d904deaa1ecd7a9c30fc483e13757f` preserves both commits of qualified
source `ci/gl-011-native-integration` at `cebc64919e4fbf67624b19e075f31ef25941d136`.
The separate read-only
Debug workflow builds `GodotLuauAdapter` on Windows/Linux, verifies pinned official
Godot 4.7.1 assets and reuses 8 lifecycle/network, 10 GL-006/008 and 10 functional
animation process fixtures per platform. New launcher ownership/cleanup and eight
bounded failure tests address process trees and partial startup. Equivalent worker
runs pass all 28 actors on each platform. Actual hosted
[run 40478173463](https://github.com/gmoddev/GodotLuau/actions/runs/40478173463)
also passes fresh Windows/Linux adapter builds, eight launcher checks and all
28 native actors each (56 process results), with diagnostic-only uploads verified.
This is Debug/x86_64 coverage, distinct from manual sanitizer evidence. See
[native CI evidence and sanitizer assessment](shared-domains-validation.md#gl-011b-native-ci-2026-10-27).
No sanitizer job or release enforcement is introduced; no GL-020 adversarial
animation test is added or executed. GL-011 remains open.
The merge tree exactly matches qualified source; following integration notes
change documentation only. Existing hosted qualification is reused within its
Debug/x86_64 scope. No expensive local matrix is repeated; automatically triggered
integration runs are observed for a bounded period and are not assumed to pass.

The integrated Linux run `40483447902` subsequently exposed a launcher-test
proc-stat check/read race before provisioning or compilation; Windows passed.
The [focused correction](shared-domains-validation.md#linux-process-liveness-correction-2026-10-27)
uses one guarded read with narrow disappearance handling. Complete worker tests
pass (Linux 14; Windows eight plus six Linux-only skips); deterministic baseline
reproduction fails as expected. Fresh corrected-main core run `40618765032` passes
39 cases per platform; native run `40618765012` passes both actual adapter builds,
process suites and all 28 actors per platform. Both diagnostic summaries verify
the correction and unchanged native fingerprint. The race is fixed and
hosted-verified; historical evidence remains separate.
This CI reliability correction does not close GL-011 or expand runtime scope.

## GL-012: Release workflow deletes prior provenance references

**Original evidence:** The final release step lists up to 100 releases and attempts
`gh release delete --yes --cleanup-tag` on every tag except the current release.

**Consequence/limits:** This can remove useful published assets and source tags,
hindering rollback and historical verification. The workflow's existence does not
prove that all earlier releases were deleted.

**Closure:** Adopt an explicit retention policy preserving immutable release
tags, artifacts and provenance. Validate the changed workflow without performing
destructive deletion of real published history. Do not dispatch the inherited
workflow as a documentation check.

**Integration (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`3551bcce8f5f68ed2ee47c2ac41e2e85f74a4feb` preserves qualified branch
`maintenance/gl-012-release-retention` at `169fd98be216c4322f4c820c7d77f3081761982b`.
Removes historical release/
tag deletion, rejects reuse of a published release or Git tag before package/
commit/publish, serializes this workflow's publication and disables asset
overwrite. Twelve mocked/read-only tests and parsed YAML structural checks pass;
no live publishing/deletion or remote tag change is performed. See
[retention policy and continuation assessment](release-retention.md) and
[evidence](evidence/gl012-release-retention-2026-10-27.json). The interim policy
also removes automatic triggers and disables both publishing-workflow jobs with
read-only permissions. GL-010/011 and repository-wide immutability/external
publisher coordination remain independent gaps.

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

**First extraction (qualified 2026-10-27; integrated 2026-10-28):** Starting main
`eb638bfa6ff16abc91d11742625b3cc034f53178`; branch
`refactor/gl-013-luau-api-extraction` moves native Vector3/Color3 userdata bindings
to a separately compiled unit with no Godot/domain dependency. The original
header is 290,353 LF bytes at this main baseline, reduced to 281,472; the historical
294,380-byte finding above remains tied to its original revision. The narrow
header exposes layouts/helpers and two initialization calls; math callbacks stay
private. CMake compiles the new unit; SCons dry-run discovery includes it.
See the [extraction record](shared-domains-validation.md#gl-013-first-value-binding-extraction)
and [measurements](evidence/gl013-value-extraction-2026-10-27.json).

Local Windows/Linux Debug/Release each pass 39 core cases and 28 native actors.
Implementation `83bc42d2bcea9d66d21cfd4d2df2650b6c87a06c` also passes fresh hosted
core run `40626224165` (39 per platform) and native run `40626224232` (actual Debug
builds, 28 actors per platform and verified diagnostic summaries). Disposition:
**GL-013 — Incremental modularization underway; four extractions qualified.**
Normal merge `bdd57fd3097537bb1cf0f8a0b7c08ae7e312d0d7` integrates both commits
through source `1c9f4c6296bc955a6a5969a6da0668d137e46ed1`; the merge tree exactly
matches qualified source. The [integration record](shared-domains-validation.md#first-extraction-main-integration-2026-10-28)
distinguishes reused qualification from fresh main CI observation. Existing shared-domain ownership, userdata layout,
registration order, reflection and networking remain unchanged. The original
header still couples Instance dispatch, services and Godot properties; this first
boundary does not close GL-013. An exploratory physics-backed baseline fixture
also exposed a Linux shutdown failure after PASS; its diagnostic evidence is
retained as an independent qualification limitation, not fixed by extraction.

**Second extraction (2026-10-28, integrated):**
`refactor/gl-013-variant-bindings` starts from integrated main `174efcc2bdb59c5072ba21d27645c5380c61e8e9`.
Only the two generic Luau/Variant conversion bodies move to an owned `.cpp` and
two-declaration forward-only header; Instance reflection, ObjectID validation and
property/Offset/error dispatch stay with their existing owners. No type support,
ownership, registration or conversion logic is added. `luau_api.h` decreases from
281,472 bytes/4,946 lines to 280,183 bytes/4,923 lines. See the
[second extraction record](shared-domains-validation.md#gl-013-second-generic-variant-extraction)
and [separate measurements](evidence/gl013-variant-extraction-2026-10-28.json).
All Windows/Linux Debug/Release worker builds/core39/native28 pass. Implementation
`5f72f4cda1c5e3bb76edd33bb11e276cff07ac10` also passes hosted core run `40631078253`
(39 per platform) and native run `40631078251` (fresh actual Debug builds and28
actors per platform). Diagnostic summaries verify exact source/fixture identity.
Normal merge `21d10d91769ee81c85ae2e1d2029e683feeb51ba` preserves both commits
with an identical tree. Fresh main core/native observation is recorded below.
Disposition: **SECOND EXTRACTION QUALIFIED AND INTEGRATED**. Baseline tests establish that unsupported reads retain invalid-member
errors and Lua non-ASCII strings retain the existing Latin-1 constructor behavior;
these are preserved, not silently fixed. The first extraction's historical
measurements/limitations remain. GL-013 stays open.

**Third extraction (2026-10-28, integrated):**
`refactor/gl-013-instance-reflection` starts from verified integrated main
`752bb2063f61a533c3e59b481196a0d8aa88f1ba`. Exact property-list membership and
the two generic `_gl_bridge` read/write blocks move to an owned Object adapter,
with a three-declaration forward-only interface. Dependencies now point from
Instance dispatch through reflection to Variant conversion and native values;
no Node/service/domain header, retained object, registry or registration is added.
Class identity, method/signal/callback bindings, ObjectID validation, class-specific
properties, child/error fallbacks and replication remain in their existing owners.
The API header decreases from 280,183 bytes/4,923 lines to 278,169 bytes/4,885 lines.
The new interface is 1,007 bytes/18 lines; implementation is 1,878 bytes/53 lines.
See [third extraction analysis and qualification](shared-domains-validation.md#gl-013-third-instance-property-extraction)
and its [separate manifest](evidence/gl013-instance-reflection-2026-10-28.json).
Baseline production fixtures establish read-only/property/metadata/Offset/error
and Changed behavior before code moves; those semantics are preserved. GL-013
remains OPEN for broader Instance/service/editor header coupling. Normal merge
`b7ec9fd614bd0e92ce418859de68b835180a7d7c` preserves both commits with a tree
identical to qualified tip `90776e7c1c5ba2b087d4efc4b9ecc2e50a223058`.
**THIRD EXTRACTION QUALIFIED AND INTEGRATED**: Windows/Linux
Debug/Release core39/native28 pass (112 local actor results); hosted core
`40643325332` passes39 per platform and native `40643325389` passes fresh Debug
builds/process checks/all28 actors per platform. Exact revision/source/fixture
identities are verified in digest-checked diagnostic archives. A one-unit
implementation edit boundary is measured; no general build-speed or native
lifetime/sanitizer guarantee is inferred.

**Fourth extraction (2026-10-28, integrated):**
`refactor/gl-013-class-identity` starts from integrated main
`4e3db8496e189b6e09148b015eff28b1c8ae29b6`. The generic native/Roblox class map
and exact/custom-parent/Godot IsA predicate move to an Object/String-only unit with
an owned String result and two forward declarations. The old fallback used a
TU-local mutable CharString, but current callers immediately copied/compared it;
no supported-call lifetime defect is confirmed. Returning an owned value avoids
introducing shared mutable fallback storage at the new compilation boundary.
Player/Value overrides, Mouse branch ordering, ObjectID resolution and error/
hierarchy dispatch remain unchanged. No separate lifetime fix or ownership model
is introduced. The [audit and qualification](shared-domains-validation.md#gl-013-fourth-class-identity-extraction)
and [new manifest](evidence/gl013-class-identity-2026-10-28.json) retain exact
analysis, baseline fixture failure and measurements. The API header decreases
278,169 bytes/4,885 lines -> 274,780 bytes/4,838 lines; the interface is 748 bytes/15
lines. Local Windows/Linux Debug/Release core39/native28 pass (112 actors total).
**FOURTH EXTRACTION QUALIFIED**: hosted core `40646744969` passes 39 per platform
and native `40646744985` passes fresh Debug builds/process checks/all 28 actors per
platform. Digest-checked summaries verify exact revision/source/fixture identity.
No supported-call lifetime defect is confirmed; no new sanitizer matrix is run
because native object ownership is unchanged. Normal merge
`35c993ce3711076a61dace5324f74691f4fb77ef` preserves all four commits and equals
qualified tip `eb53661072999887d2a124e5d4ece2f458c7bb30`. GL-013 remains OPEN. No general speed/lifetime/sanitizer guarantee is inferred.
EOF-only follow-up `688fd5b` removes one trailing blank line; implementation code
is unchanged. Fresh follow-up core39 passed while native run `40648770257` was still
building at that earlier bounded observation. Both cleanup workflows subsequently
passed; fresh merge core `40651973151` and native `40651973098` also pass Windows/Linux
39 core cases / 28 native processes each. Final main is
`08b2bb83b7093a361c80b147b4827eb22715ad32`, with identical tested inputs.

**Remaining-boundary assessment (2026-10-28): complete, GL-013 still OPEN.**
The [assessment](gl013-boundary-assessment.md) and
[inventory/compiler evidence](evidence/gl013-boundary-assessment-2026-10-28.json)
record 64 headers/eight implementation units, no project include cycles and exact
matches of eight qualified compiler include closures. Four isolated owners are a
maintainability improvement; API-header edits still affect three TUs and no general
build-speed improvement is established. Prefer script bootstrap/Instance access in
existing `luau_script.cpp`, followed by completion ownership and GUI metadata/style
adaptation. Inert helpers rank below these; earlier next-helper suggestions are
historical. State/dispatch/network boundaries need their stated proof before a
future extraction. GL-021 records a separate static compatibility discrepancy.
No fifth extraction, production/test/build/workflow change or unrelated closure.

**Fifth extraction (development branch, 2026-10-28): FIFTH EXTRACTION QUALIFIED.**
`refactor/gl-013-script-bootstrap` begins at main
`ce5e19fa8aea1cf65da875d07cda13c1696fc08c` after assessment integration. Bootstrap,
RemoteFunction setup and child relay move to existing script CPP, with one narrow
wrapper-push declaration and explicit host/registration include prerequisites.
VM, scheduler, module cache and network/dispatch implementations remain unchanged.
Compiler dependency closures match the graph in all eight before/after/platform/
configuration sets (64 objects): API and stdlib fan-out three → one; script-header
touch still rebuilds three. All four candidate configurations pass 39 core cases
and 28 native actors (112 candidate actors); unchanged baseline passes the final
expanded eight-actor regression group in all four configurations.
The [fifth qualification record](shared-domains-validation.md#gl-013-fifth-script-bootstrap-boundary)
and [manifest](evidence/gl013-script-bootstrap-2026-10-28.json) retain timing/size
increases, include failures, baseline callback finding GL-022 and qualification
limits. Implementation `50f1c0e4b7f569bbacf3163651dcf16fa0e9a8f4` is pushed and
remote identity read back. Fresh hosted core `40661531131` passes 39 distinct cases
per platform and native `40661531193` passes fresh Debug builds, process-runner
self-checks and all 28 actors per platform. Digest-checked summaries match exact
source/pins/all 22 harness hashes. Both complete within the 25-minute bound.
The evidence follow-up changes no tested input; this is not merged to main.
GL-013 remains OPEN; no sixth extraction or unrelated issue closure is implied.

**Fifth extraction integration (2026-10-29):** Normal merge
`109bd6d838410509da9831b1502dfffb023ad823` preserves both source commits and
exact qualified tree `9171199fc6b3b43a2aa07a98f3f20977abc43533`. Fresh checks
and hosted outcomes are recorded in the [integration record](gl022-child-relay-validation.md).
GL-013 stays open. GL-022's shared-target reproduction predates this extraction
and is not treated as an introduced refactor regression.

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

**Original evidence:** `addons/GodotLuauUpdater/plugin.gd:4-39` hardcodes Pimpoli's
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

**Integration (2026-10-27): INTEGRATED AND VERIFIED.** Normal merge
`abf7776dfb1d7dfde1abfc7b7cb468047575f738` preserves qualified source
`maintenance/gl-016-fork-updater` at `ed7211a2e354aa29516c646a3ee40f2459f87106`.
Runtime checks/download/apply,
callbacks, history, unverified backup restore, staging/swap/restart and destructive
startup cleanup fail closed before side effects. Enabled editor tools and explicit
model/custom-autocomplete downloads remain available. Both Windows/Linux actual
headless editor fixtures pass 596 assertions across 42 blocked operations and two
localhost optional-data downloads, preserving installed files/backups/metadata.
See [policy/recovery/limits](fork-updater-isolation.md) and
[evidence](evidence/gl016-updater-isolation-2026-10-27.json). Fresh Windows/Linux
integration fixtures each repeat 596 assertions and 42 rejected operations; the
historical branch results remain separate. Release publication stays disabled.
No fork production update channel or distribution provenance is established.
Original evidence and GL-010/011 remain independent.

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

## GL-021: Inert signals omit lowercase once/wait aliases

**Classification: Verified construction-order discrepancy; runtime unexercised.**
Source revision `08b2bb83b7093a361c80b147b4827eb22715ad32`:
`src/core/luau_api.h:63-71` copies Connect/Wait/Once to connect/wait/once only when
each uppercase field already exists. `_gl_push_inert_signal` at `172-190` creates
a new table, installs Connect, calls that copier at `185`, then installs Once and
Wait at `186-189`. Thus the constructed table has connect but no once/wait fields.
The source's stated legacy signal contract includes all three lowercase names.
`GetPropertyChangedSignal` at `1290-1295` returns this inert table.

**Impact and limits:** scripts expecting the documented lowercase inert methods
would find nil. This is a source trace, not an executed failure, native lifetime
defect or security finding. Uppercase behavior and connection reference handling
are not reclassified. No focused assertion for these lowercase inert fields was
found in the current native fixtures. No code or tests changed during assessment.

**Separate follow-up:** reproduce with actual production GetPropertyChangedSignal;
decide and document the intended alias contract; correct construction order in a
focused compatibility fix. Require Connect/connect, Once/once, Wait/wait,
Disconnect/disconnect, Connected=false, nil Wait result, repeated calls with no
references or callbacks, GC and fresh-domain teardown. Preserve the inert nature.
Close only with linked implementation and executed regression evidence. Do not
silently combine this behavior change with the next GL-013 extraction.

## GL-022: Shared ModuleScript loses the second domain's child relay

**Original classification: Reproduced baseline callback compatibility gap; cause needs review.**
The first fifth-extraction fixture runs the same native ModuleScript in Server
and Client domains, with each module connecting game.ChildAdded. Both requiring
callers retire; a later child reaches the Server callback but the Client marker
never appears. This fails on unchanged production main `ce5e19f` / native fingerprint
`653e3ce3b6c3e4555365f53bea7490b1cd09664921deb9d6000ee8e7bd70f6c3`, Windows and
Linux Debug, before the refactor. Windows diagnostic replay shows only one native
child_entered_tree connection, targeting the shared ModuleScript with one bound ref.

`luau_api.h:1239-1286` selects the owner's native script node and uses
`Callable(sn, "_gl_child_event").bind(ref)` with an is_connected guard. Domains
share the same native ModuleScript receiver even though references/VMs differ.
The trace identifies the missing connection; exact callable equality/registration
cause and any broader signal impact remain unproven. No UAF, authority defect or
cache-isolation failure is established. Source, failed logs and diagnostic replay
are retained under worker `gl013-bootstrap/baseline-qualification1-debug` and
`baseline-diagnostic2-debug`; see the fifth manifest for hashes and scope.

Distinct native relay ModuleScripts pass the same both-domain/caller-retirement
assertions in baseline Windows/Linux Debug/Release. The final extraction fixture
uses those targets, retains shared-module cache/metatable checks and adds
cross-domain attribute watchers. The failed shared-target expectation is preserved,
not reported as passing or fixed. No production callback/ModuleScript logic is
changed to address this finding. The refactor's qualification does not close it.

**Separate follow-up:** reproduce the shared-native-target case, trace connection
identity and owner/reference cleanup, and implement a focused fix with two-domain,
same-domain multiple connection, disconnect, caller/module destruction and fresh
domain tests. Close only with linked fix and executed evidence.

**Resolution (2026-10-29): FIXED AND QUALIFIED on the development branch.**
The [record](gl022-child-relay-validation.md#stage-2-baseline-and-mechanism-2026-10-29)
reproduces the shared-target failure on both unchanged Debug platforms. Godot
source and native is_connected diagnostics confirm bound arguments are excluded
from signal identity; public references are process-wide/non-recycled. The
development branch uses distinct base Callables and host-owned cleanup, preserving
module-owned callbacks after caller retirement. Windows/Linux Debug/Release
core39 and 112 native actors pass; Windows core ASan and Linux core/full-native
ASan/LSan pass (28 native actors). Final hosted core39/native28 pass per platform
on `0cdaed65f0a9592c7a19302d837e5a0e68db5c58`; verified artifacts exercise all
four required GL-022 markers. The record preserves baseline failures, the child
signals' Connect-only protocol, test-adapter teardown access and limits.
This resolves the exercised scope on `fix/gl-022-cross-domain-child-relay`,
not main or unrelated findings. GL-017/018 and deferred GL-020 adversarial
qualification remain open.

**Main integration:** Normal merge `f1e1b9c492e56549a72739ad3086ad3ec9c32ee9`
preserves all three qualified GL-022 commits without conflicts. Runtime/build/
fixture inputs are unchanged from qualified revision `0cdaed6`; see the
[integration record](gl022-child-relay-validation.md#main-integration) for fresh
main CI results and retained limitations. Historical branch evidence above is
preserved; no broader issue closure or distribution readiness is inferred.
