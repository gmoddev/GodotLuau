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
