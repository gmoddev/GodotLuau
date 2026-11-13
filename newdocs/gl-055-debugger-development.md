# GL-055 native debugger campaign

Status: implementation in progress on `feature/gl-055-native-debugger`; unmerged.
This campaign is distinct from the resolved historical GL-055 native layout
preset issue. Its ID and evidence remain unchanged.

## Verified baseline

On 2026-11-13 remote main is `b5389f0ff08c50e38bc11d868dbe12729a293535`.
The clean feature worktree starts there. GL-054's integration retains 23 feature
commits, native fingerprint
`ba44f2ac38c33ed616d305434cef2f8beca232bffc0455d7c5159efa50c5e49d`
(128 LF-normalized inputs), passing Windows/Linux core/native/declarations and
the separately scoped sanitizer/production/export/rendered evidence. Read the
[integration record](gl-054-main-integration.md) and linked GL-049/051/052/053
contracts before extending the existing domains, editor or ownership boundary.

Dependencies remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and
Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`. Native stays the default
Character controller, Scripted opt-in; releases/updater remain disabled.

## Source findings and decision

The pinned VM exposes `lua_breakpoint`, `lua_singlestep`, debug callbacks,
`lua_getinfo`, argument/local/upvalue inspection and `lua_isyieldable`. A
`lua_break` cannot cross a non-yieldable native boundary. Existing scheduler
completion treats statuses other than LUA_YIELD as completion/error; silently
inserting LUA_BREAK there would require new lifecycle and nested-coroutine rules.

The pinned Godot metadata already exposes EngineDebugger.script_debug,
line_poll, breakpoint and stepping controls; ScriptLanguageExtension exposes
live stack/variable hooks. The existing implementation leaves those hooks empty.
Godot's remote debugger owns the game-process break loop and standard editor UI.
Use that supported route at safe Luau opcode hooks, preserving the live VM/native
stack rather than inventing a second scheduler or passing snapshots as live state.
[ADR-018](adr-018-native-luau-debugger.md) defines the implementation contract.

Primary references: pinned `luau/VM/include/lua.h`, `VM/src/ldo.cpp`,
`VM/src/ldebug.cpp`, `tests/Conformance.test.cpp`; pinned godot-cpp
`gdextension/extension_api.json`; Godot's
[EngineDebugger API](https://docs.godotengine.org/en/4.3/classes/class_enginedebugger.html),
[language hooks](https://docs.godotengine.org/en/4.3/classes/class_scriptlanguageextension.html)
and [remote break loop](https://github.com/godotengine/godot/blob/4.3/core/debugger/remote_debugger.cpp).
Metadata is the extension API authority; runtime hosts remain the admitted 4.7.1
profiles. No engine or dependency patch is authorized or needed for this route.

## Acceptance and phase record

Implement and qualify real breakpoints, resume and step into/over/out, live frames
and bounded read-only variables first. Then extend native inspection, restricted
watches, editor integration, reload/domain lifecycle, project navigation and
development-only profiling as independently testable phases. Acceptance must use
the production core and actual Godot debugger protocol/editor, including callbacks,
imports, coroutines, rejection/bounds, disconnect and retirement. Core-only tests
do not establish successful graphical editor interaction.

Record commands, exact source/fixture identities, actual failures and corrections,
Windows/Linux Debug/Release/native/declaration/sanitizer results and comparable
disabled/attached performance here. Reuse unchanged game/export evidence within
its proven scope; changes to debugger/runtime inputs need their own relevant
regression. Do not relabel GL-054 snapshots as interactive debugging.

## Runtime control implementation checkpoint

The first code phase adds a host-only GLDebugger using real patched Luau
breakpoints, admitted executable-line reporting, bounded hit targets, safe opcode
pause/step hooks and live frame identity. The existing scheduler still owns every
resume/task. Godot integration will supply the native break loop; the core fixture
supplies commands directly to exercise the actual pinned VM and production core.
Seven focused scenarios cover live locals/continue, into/over/out, disabled and
remapped breakpoints/hit target, coroutine/import stops, retirement during a stop,
paused wall time/detach and domain isolation. These are implementation inputs,
not yet passing qualification evidence.

The pinned VM chooses its debug interpreter at entry. Attached threads therefore
keep single-step hooks available, even between explicit step requests; detached
execution keeps its original interpreter and compilation policy. This attached
cost must be measured. A status-only scheduler LUA_BREAK implementation is not
introduced. Real Godot editor integration/inspection remains in progress.

DockerPC's worker-heavy generation 121 belongs to StudioCreatorFoundation3;
no workload is started, stopped or reserved there. Use hosted core CI for the
first checkpoint while continuing independent editor implementation.

Core CI 43424637985 compiles both platforms but rejects the additional CTest
entry at the existing exact discovery guard, before executing tests. Keep that
guard and its 87 legacy assertions intact: invoke DebuggerTests through the
existing bounded RunCoreTests process wrapper, and additionally require seven
distinct debugger scenario markers. The original failed attempt remains visible;
compilation alone is not runtime qualification. No fixture assertion is relaxed.

The corrected discovery run 43425256561 executes the production core: the first
live breakpoint/local case and exact step sequence 6 -> 2 -> 3 -> 7 pass on both
platforms. The hit-count scenario incorrectly expects the for-loop setup line to
execute repeatedly. Separate its comment-to-executable-line admission check from
the hit target on the actual repeating loop body. Keep the one-stop hit assertion
and disabled-breakpoint assertions unchanged; retain the failed run.

Run 43426485509 passes real locals/continue, exact stepping, hit-target/remapping
and coroutine/module stops on both platforms. The retirement scenario's compound
assertion assumes one error report, whereas existing scheduler cancellation
deliberately suppresses ordinary script failures for an already retired owner.
Split the assertions into execution rejection, dead owner, no ordinary error and
the existing unchanged-mutation sentinel. This preserves inherited cancellation
semantics. No runtime failure or post-retirement mutation was demonstrated by
that compound fixture failure.

## Native editor and inspection implementation checkpoint

The next source phase wires the real Godot script_debug loop and LuauLanguage
stack/local/upvalue hooks, domain-aware native session controls, native breakpoint
gutter changes/admission feedback and bounded raw table/native-handle projection.
It requires an active debugger on an editor-capable gameplay host, rejecting
editor preview and ordinary export templates. Godot owns the game-process pause;
the scheduler is unchanged. Native wrappers resolve through existing SceneScope
ownership, and no raw Object Variant or new gameplay capability is returned.
Custom command envelopes use a crypto-generated connection nonce, monotonic
request IDs, closed primitive fields and a 32-command/second bound. Editor
breakpoint updates coalesce and drain under that bound. These changes still need
actual native compilation, protocol, editor, lifecycle and sanitizer evidence.

Intermediate native rerun 43425256514 is canceled because its native inputs equal
the original checkpoint, while core-only fixture correction is being established.
It is not a passing result. No existing acceptance assertion is removed.

Core 43427400040 passes Windows/Linux at `b3e18af`: all 87 existing cases and
seven actual debugger scenarios. Native run 43427400110's Linux adapter compile
finds one const-reference mismatch: project path validation accepts a mutable
String for canonicalization, while breakpoint registration passes its const
input. Validate a local copy and retain that canonical path. Static review also
removes a namespace-scope Godot String before extension binding initialization;
use an ordinary std::string for the session nonce. The startup risk was not
reproduced by the compile-blocked run.

Add a real Godot Variant-protocol editor peer fixture: actual breakpoints, native
stack/locals/upvalues, into/over/out, imported module, separate Client frame,
signal callback, destroyed native wrapper, malformed/stale/session rejection and
disconnect while stopped. Both processes use existing bounded ownership helpers
and headless crash-UI suppression. Native CI now requires this fixture; its
four test-owned processes remain separate from the existing 141-actor cohort.
A focused workflow can reuse the exact adapter artifact after fixture-only
corrections, enforcing the unchanged native fingerprint rather than rebuilding
the same native source. Neither fixture has passed yet; graphical editor
interaction, restricted watches and later phases remain outstanding.

Before running the fixture, source review corrects two fixture assumptions:
resource handles use Scope:Get/Call rather than direct userdata ClassName
indexing, and a stale-sequence test must first admit a valid request (malformed
requests deliberately do not consume the sequence). Keep the actual resource
inspection and four-rejection assertions. These fixture-only corrections can
reuse the identical native product and do not constitute passing evidence.

## Restricted inspection and watches checkpoint

Native 43429591460 and fixture-only 43432075758 reject the new inspection unit's
missing direct Variant include before runtime qualification. Add that dependency.
Bounded MSVC /Zs probes using the existing pinned generated headers also find and
correct non-iterable Godot Array range loops and the command-window name colliding
with godot::Window. Eight affected native translation units pass these syntax
probes, in single-compiler invocations of approximately 3–9 seconds; no dependency
build, local sustained compilation, vendor modification or runtime pass is claimed.

Implement a restricted evaluator using the pinned Luau AST, without executing Lua.
It reads bounded copies of live frame locals/upvalues, raw table entries and
approved owned native-property projections. Calls/constructors, mutation, globals,
non-finite arithmetic, excessive depth/work and out-of-projection reads reject.
The supported native session tab adds frame selection and Watch, with seven actual
protocol queries and an unchanged-state sentinel for rejected function calls.

Native C frames and unregistered bootstrap-source frames remain opaque, preventing
private C/native-service upvalues from entering variable inspection. Coroutine
labels use bounded weak identities erased on thread destruction; step state also
retires at resume/native async boundaries. Tagged redaction, binary/truncated
string previews and UTF-8 prefix handling preserve explicit inspection state.
The source-admission map labels the executing owner; exact lexical definition
versions of arbitrarily retained module closures are not claimed.

The [debugger guide](gl-055-debugger.md) records implemented controls, projection
limits, source/reload constraints and the custom message envelope. Primary native
protocol execution, graphical editor interaction, lifecycle/adversarial expansion,
profiling/indexing, cross-profile/sanitizer and performance qualification remain
outstanding. Main, dependencies, default controllers and publication guards are
unchanged. Do not close this campaign from core or syntax checks alone.

## Native editor journey preparation

Core 43437162294 passes Windows/Linux at `1e46bc5` (87 existing and seven
debugger scenarios). Native 43437162267 is still building the actual adapter.
Add an editor-only, main-thread session descriptor with copied state and a
connection generation, excluding transport nonces and live VM/native handles.
The existing editor runner's separate `--debugger` mode opens actual Luau source,
sets its native CodeEdit gutter, starts a real game process and exercises the
native Luau tab's Watch, into/over/out/continue, application Stop, fresh Play and
detach. It uses the cached headless child arguments before editor startup.
Godot 4.7.1 parses the journey successfully; execution remains pending the new
native binary. The automated headless journey is not graphical or physical-input
qualification. No controller, host, dependency or publication setting changes.

## Cached project navigation checkpoint

Extend the existing GL-054 AST/cache scan rather than adding a second parser or
index service. Empty Module/Member requests return bounded per-file symbols,
type aliases, static require edges, lexical local-reference definition locations,
imported members and explicitly syntactic global/member/native-class candidates.
The editor's Project Symbols command opens these source locations in the existing
diagnostics tree. Existing exact module-member queries retain their contract.
Navigation has its own truncation state, 512 records/file and 4,096 records/report,
under the existing file/byte/traversal bounds. Unsaved current buffers and hashes
continue using the established invalidation path. Extend the actual native editor
fixture for types/functions/imports/lexical definitions and navigation latency.
Three changed native units pass bounded MSVC syntax checks; runtime/editor
execution remains pending. Dynamic/global/type resolution is not claimed.

## First actual native stop and protocol correction

Native 43437162267 compiles on Linux and reaches a real, continuable Luau stop,
returning its stack and variable count. The peer rejects the first variable
payload: the admitted Godot 4.7.1 host appends a fifth type-hint field, unlike the
four-field 4.3 source originally consulted. Its actual upstream
`core/debugger/debugger_marshalls.cpp` confirms this wire shape. Correct the peer
to require the five typed fields; retain all value/authority/stepping assertions.
The fixture-only qualification branch reuses the exact `1e46bc5` native adapter
through the existing focused workflow, avoiding a duplicate native build. This
is partial execution evidence, not a passing debugger result.

GitHub cannot manually dispatch the new focused workflow before it exists on
default main. Use its push trigger on this qualification-only branch with the
explicit original adapter run, retaining exact native-source admission. Cancel
43440700078/43440700081: the fixture repair changes no native/core implementation.
No default-branch modification or additional native rebuild is needed for it.

Focused 43441210614 exposes a peer-only grouping bug: context `State` overwrites
the script local of the same name when the peer flattens Godot's separate groups.
Keep context names separate. Focused 43441438055 then passes actual cyclic/native
inspection, all seven restricted watches, into/over/out, module, Client and signal
callback stops. Its final pure local alias has no instruction (requested line 25
correctly remaps to executable 26); place that fixture marker on the actual assert.
Retain the destroyed-handle assertion. The unexpected-disconnect attempt also
shows a product issue: Godot's `is_active()` remains true after losing the peer,
so later Luau stops invoke an unavailable native session. Keep its no-error gate
and fix the product lifecycle separately; no full debugger pass is claimed.

## Disconnect lifecycle correction

Godot's public `is_active()` reports initialization, not connection liveness.
Before entering its blocking loop, request a nonce/sequence/domain/stop-bound
acknowledgment through the existing capture; allow one second of measured pause
time, then detach both domains if it is absent. Godot's public `line_poll()`
itself polls every 2,048 calls, so use a bounded burst only during this handshake
and source admission, when ordinary engine frames cannot advance. During a native
break loop, a negative lines-left sentinel distinguishes an uncommanded return
(disconnect) from native Continue/Into/Over/Out. Detach both domains and release
breakpoint roots before any subsequent stop can invoke a disconnected session.
Also map Godot's native positive-depth Out command to Luau Out.

Extend the actual native peer for disconnect while suspended and a distinct
disconnect after native `debug_exit`, before the next stop. Existing no-error,
target completion and ownership assertions remain required. The actual editor
plugin acknowledges stops automatically, without exposing the transport nonce.
Two changed native units pass bounded MSVC syntax checks; runtime qualification
of the correction is pending. This bounded handshake is justified by the observed
disconnect defect, not a new gameplay transport or scheduler.

Focused 43442092977 confirms the unchanged `1e46bc5` Linux product completes all
eight local stops and four malformed/stale rejections without target errors,
including all seven restricted watch queries. Its separate disconnect case
retains the observed target errors and therefore fails the overall run. Windows
artifact admission is pending the original build. Do not relabel this mixed run
as complete cross-platform qualification.

## Linux native control and navigation qualification

Native 43442668524's Linux job 131943989757 passes at `71e8bfd`: actual local,
suspended-disconnect and running-disconnect debugger cases, native editor journey,
all 141 existing native actors, Foundry/restart, networking and production editor
regressions complete. Windows is still building. Core 43442668486 passes both
platforms (87 existing/seven debugger cases). This establishes the disconnect
correction and cached navigation within that Linux Debug profile. It does not
establish Release, sanitizer, graphical or new selective-reload evidence.

## Selective saved-source reload checkpoint

Godot's newer `_reload_scripts(Array, bool)` virtual was a compatibility no-op.
Decode its actual Array ABI and use the existing LuauScript reload/source-change
path, bounded to 256 resources on the trusted main thread. Editor tool reload
shares it. File reads retain the existing confined project-path/16-MiB limits;
export/gameplay callers gain no reload capability. Godot queues its ordinary
reload until idle, so it cannot retire a paused owner before resumption by itself.
The Luau tab's explicit Reload command therefore reloads only its actual stopped,
already-cached source through the existing capture. The changed source retires
the old owner/callbacks/scopes synchronously; only successful acknowledgment
continues Godot's native loop, and the replacement starts through the existing
deferred script entry. Failed reload stays paused. There is no state-preserving
soft reload; unchanged source simply continues. The all-scripts virtual remains
unsupported; restart or selected source reload is explicit.

Add an actual native reload fixture with a live scope, signal and delayed callback.
It replaces the isolated saved file at a breakpoint, requires a fresh owner and
new executable breakpoint, and checks the old instruction/callbacks cannot run
and native objects are destroyed. Both new GDScript peers parse under verified
Godot 4.7.1; the three affected C++ units pass bounded syntax checks. Execution
qualification of reload is pending; no new engine patch or scheduler is added.
## Editor stack/variable readiness correction

Focused 43443105126 executes the actual Linux native editor journey: gutter,
watch, four stop identities, Continue, Stop/Play and detach assertions pass. The
editor still logs Godot DAP missing-scope errors. The driver currently advances
when the native stop appears, without waiting for the requested native stack and
variable replies. Require the actual Stack Frames row and debugger inspector's
live local value/StopId before advancing each step, and allow bounded teardown
frames before exit. This also establishes the previously untested displayed
stack/variable acceptance facts. Keep the unhandled-error gate unchanged; this
initial run is not clean editor qualification. The corrected script parses under
the verified host; runtime rerun is pending.

Focused 43444009583's Linux editor report then passes all native displayed-stack,
live-variable, Watch and control/restart/detach checks without unhandled editor
errors. It records four ObjectDB exit warnings; no graphical or leak-free editor
claim is made. The overall workflow still fails its known old-product disconnect
case. The newer `71e8bfd` Linux native job independently passes the fixed protocol
and editor checks together with the full existing native suite.

## Controlled reload observer ordering
Selective-reload run 43446022999's Linux peer reaches the replacement owner and
new breakpoint, but the target observer inspects the old scope after it has already
been retired and destroyed. Replace its one-frame assumption with an explicit
primed/observed barrier: the old source cannot reach its breakpoint until the
target captures both native IDs. Arm the cancellation timer only after that
barrier. Retain all old-code/callback/destroyed-object assertions. This fixture
correction changes no native input; reuse the exact `24dd94b` adapter in focused
qualification. Cancel sanitizer 43450112103 early because it uses this known bad
observer ordering; restart with the corrected fixture, retaining the attempt.

## Bounded development profiling and ownership snapshots

Add explicit ProfileStart/ProfileStop/Profile controls through the admitted
debugger capture and a bounded native tab report with CopyProfile JSON export.
Collection defaults off. Core instrumentation records per-owner inclusive resume
and protected-call wall time, compile/module-compile duration, callback admissions,
require requests and coroutine creation. It excludes measured debugger waits and
keeps overlapping nested entries explicit; this is not per-function CPU sampling
or native-only dispatch timing. Starting/stopping during a live execution excludes
that in-flight interval. Successful native operation counts reuse the existing
dispatcher trace points; the separate GL_RUNTIME_TESTS coverage recorder retains
its prior behavior. Ordinary products have only a disabled collection branch.

Records cap at 128 copied owner identities and 256 native operation names/domain,
with bounded source strings. Snapshot previews cap at 24 owners/64 operations and
mark truncation. They include existing VM/resource stats plus weak scope/node/
resource/subscription counts, selected ObjectIDs and queued/destroyed states.
Scope snapshots cap at 16 live-guard scopes and 4,096 node observations; retired
owners without a valid guard are deliberately excluded, while profile records
retain their retired disposition. Nothing retains Lua references, native Objects,
Resources or callback capabilities. Host allocation rejection drops observations.

Extend core qualification to eight debugger/profiler scenarios (87 original cases
unchanged), including measured pause exclusion, 140 real owners overflowing the
bounded report without changing execution, retirement/reference release and
start/stop/reset. The actual native peer checks accepted Button construction and
signal dispatch counts, module compilation, callback activity, Client exclusion,
destroyed node slots and stable VM-reference counts across repeated snapshots.
Changed native units pass bounded MSVC syntax probes and the peer parses under
verified Godot. Profiling/runtime/overhead qualification is pending; no exact
arbitrary Lua function-call count, sampling profiler or native-only timing is
claimed. Dependencies, execution architecture and publication guards are unchanged.

Windows `71e8bfd` native protocol passes all three cases, but its older editor
driver fails waiting for the Watch response before native variables settle. The
displayed-stack/variable-ready fixture is included in the next revision; retain
that failed attempt. Core 43446023196 passes Windows/Linux at `24dd94b`; native
43446022999 is building that selective-reload checkpoint.

Core 43448830124 executes all eight debugger/profiler scenarios successfully on
both platforms, but the existing outer runner still requires the old seven-case
summary. Update that final summary gate to eight, matching the already-updated
distinct-case verifier. Preserve its watchdog and all 87 prior cases. This is a
runner synchronization correction; the native implementation is unchanged.

## Explicit dedicated development host admission

The admitted sanitizer/dedicated hosts intentionally omit editor tools, so the
original editor-feature-only admission cannot exercise native inspection/reload
under ASan. Add an explicit `--gl-luau-debugger` user-argument opt-in restricted
to debug hosts with an initialized existing debugger and successful stop exchange.
Release templates and ordinary debug-template launches stay closed. This changes
only debugger admission, not engine revisions/patches, admitted hosts, gameplay
capabilities, listeners or distribution defaults. It also provides the requested
dedicated development debugging path. The existing full-native sanitizer runner
now runs the actual four-case debugger fixture with this opt-in, preserving its
detection controls and all existing core/native gates. ASan/LSan execution is
pending; no sanitizer result or dedicated ENet pause coordination is implied.
That profile also requires an actual no-opt-in negative case: the same debug
template, initialized remote connection and configured Luau breakpoints must run
to completion with zero Luau stops when the explicit flag is absent.

## Windows/Linux focused debugger qualification

Focused [43454399358](https://github.com/gmoddev/GodotLuau/actions/runs/43454399358)
passes both platforms using the immutable `5466af1` adapter. All four actual
protocol cases, profiling/weak ownership checks and the native displayed-stack/
variable/control/restart/detach editor journey pass. Correct the expected signal
counter to its registry declaring class `BaseButton.Pressed`, preserving the count
assertion. Retain copied profile receipts without transport nonces. The editor
driver also selects the session tab by its actual bound session ID, avoiding an
ambiguous first/last tab when Godot creates multiple sessions. These changes do
not alter native source. Sanitizer 43450756992 is canceled early because it uses
the known incorrect expected counter; rerun with the corrected fixture. Candidate
43450118761 remains relevant because its unchanged core/native/package inputs do
not exercise that peer-only assertion. Main remains untouched.
