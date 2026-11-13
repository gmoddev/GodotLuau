# ADR-018: Native Luau debugger execution and inspection

Status: accepted for GL-055 implementation; actual delivery and qualification
remain in the [campaign record](gl-055-debugger-development.md).

## Execution authority

Use the pinned Luau breakpoint/single-step callbacks and Godot's supported
EngineDebugger.script_debug break loop with LuauLanguage stack/variable hooks.
The running game keeps its exact live coroutine, call frames and owner generation
on the existing protected execution stack. Resume returns through that stack.
No second scheduler, VM, gameplay transport, scene graph or native object registry
is introduced. Snapshot inspection remains a separate historical facility.

Interactive admission requires a connected debugger, an editor-capable runtime
host, the main thread and gameplay execution. Never enter a break loop in the
editor's own EditorPreview domain or during shutdown, memory failure, inspection
or a non-yieldable Luau/native boundary. Export templates do not silently acquire
interactive debugging. Unsupported stops must be reported honestly.

Godot's existing loop handles editor commands/disconnect while the game process
is paused; the editor remains a separate responsive process. All main-thread
Server/Client execution, physics and rendering in that game process pause
together. Other peers continue and may time out. Preserve the actual transport,
queue, storage and cancellation contracts; do not invent pause replication.

Godot's initialized debugger flag is not a live-connection check. Require a
session/domain/StopId-bound acknowledgment before entering its break loop,
bounded to one second, and detach both domains if it is missing. Distinguish
an uncommanded native-loop return from an explicit resume/step and detach after
disconnect. Include this measured handshake in debugger pause time.

Exclude only measured time spent in debugger suspension/handshake from all
currently active ADR-002 wall-clock deadlines. Keep instruction/safepoint,
allocation, admission and owner limits intact. Compilation, inspection and
ordinary native work do not gain an unbounded gameplay budget.

## State and lifecycle

Detached -> Attached -> Running. A bounded pause request enters PauseRequested;
an admitted breakpoint or safe step enters Suspended. Resume goes through
Resuming to Running or Stepping. A new safe stop returns to Suspended. Detachment
goes through Disconnected and clears hooks/references; failures enter Faulted;
shutdown/retirement enters Terminating before cleanup. Never resume a retired
owner. Invalidation clears admitted code references and live inspection context.
Explicit stopped-source reload uses the established resource changed signal and
generation retirement before resuming; replacement entry remains deferred. Failed
file reload leaves the stop intact. No state-preserving soft reload is promised.
The break loop must return on disconnect/termination under Godot's existing
lifecycle. No raw inspection reference survives resume.

Breakpoints have bounded source/line records and explicit unresolved/admitted
locations. Reinstall against each loaded source generation using the pinned VM's
actual executable-line result. Do not silently promise textual remapping after
arbitrary edits. Step into/over/out use Luau source/depth observations; native
internals and asynchronous continuations are explicit boundaries. Disable
single-stepping when detached. The pinned VM chooses its interpreter mode at
entry: attached execution uses the debug interpreter so a stop can step immediately
without unwinding arbitrary native stacks. Measure that attached cost separately
from the unchanged detached interpreter. Conditional evaluation, if added,
must use the same restricted read-only evaluator as watches.

## Inspection and transport

Inspect the selected live suspended coroutine only, labeling domain, generation,
coroutine and stop identity. Bound frames, names, bytes, tables, recursion and
total copied values. Copy primitive values and raw table entries without
metamethods or Lua execution. Cycles/shared references and truncation are explicit.
Arguments/upvalues remain distinct from locals. No arbitrary globals/registry,
native memory, capability tokens or raw Object Variants are returned.

Native handles resolve through existing ownership and binding checks. Report
destroyed/restricted identities without keeping native objects alive. Only
approved observational properties may be projected. Watches cannot execute
functions, mutate state, call networking/filesystem/persistence or cross owners.

Use Godot's existing debugger connection and supported editor plugin interface.
No new listening endpoint. Custom messages require version/session/correlation,
type/size/count limits, bounded feedback and stale/duplicate rejection. No custom
message is a gameplay capability. Development profiling/indexing is opt-in and
bounded; collection cannot retain native objects or prevent teardown.

## Compatibility

Debugger-disabled code retains ordinary compilation and execution. Native remains
default and Scripted opt-in. Existing network/health/animation/storage authority,
dependency pins, admitted hosts and publication/updater guards are unchanged.
The journal must distinguish delivered/qualified, partial, deferred and unsupported
features; this decision alone establishes none of their runtime evidence.
