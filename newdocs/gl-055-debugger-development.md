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
