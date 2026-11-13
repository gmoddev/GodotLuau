# Native Luau debugger

Implementation on `feature/gl-055-native-debugger`, unmerged. Core execution
control passes the recorded Windows/Linux scenarios; native protocol, editor,
cross-profile and sanitizer qualification remains in progress. Consult the
[journal](gl-055-debugger-development.md) for actual results. This guide describes
the implemented interface, not a completed qualification claim.

## Starting and controlling a session

Run a project from Godot's editor using an editor-capable host. A connected
native debugger is required; ordinary export templates do not enable this
facility. Set Luau source breakpoints in the ScriptEditor gutter. The native
Debugger's Luau tab shows requested and actually admitted executable lines, hit
counts, domain and state. An unresolved location is not an active breakpoint.
The pinned VM can remap a comment/empty line to its next executable line.

Use the Luau tab's Server/Client selector and Pause button for a safe Luau pause
request. The native Godot stack/variable panes inspect the actual stopped
coroutine. StepInto, StepOver, StepOut and Continue operate from that stop.
Native C++ internals and bootstrap frames remain opaque. Stepping ends when its
resume attempt yields/completes; an asynchronous continuation is not promised to
retain a source step. Separate module/coroutine breakpoints remain supported.
Detach clears admitted breakpoints/code references and resumes through Godot's
existing loop. Stop the application through Godot's normal Stop control.

After saving an edit to the stopped source, use the Luau tab's Reload button to
retire that generation before continuing. It reloads the selected cached file,
cancels its owned work and rebuilds through the established deferred entry.
Successful acknowledgment continues; read/path failure leaves the session paused.
Reload does not preserve script-local state. Saving alone does not replace the
live suspended frame: Godot's ordinary reload request runs at idle after resume.
Reload-all remains unsupported; select sources or restart the application.

The game process pauses on its main thread. Server/Client, physics and rendering
in that process stop together; other peers continue and may time out. This adds
no gameplay pause protocol. EditorPreview retains historical error snapshots;
it cannot block the editor's own UI in a live break loop.

## Inspecting and watching values

Frames label the active execution owner generation and a weak, bounded coroutine
identity. Locals, arguments and upvalues come from the selected live frame. No
value remains live after resume. C closures and unregistered bootstrap sources
cannot expose private native upvalues. Node/resource projections resolve through
the existing SceneScope ownership checks, reporting alive, destroyed, restricted
or unsupported state. They return primitive identity/approved property copies,
never a new Object/Resource capability. Fixed native mathematical values remain
pure value copies. The generation label is the executing owner; it does not
claim precise lexical-definition version tracking for every retained closure.

The Watch field uses the specified zero-based live frame. Its restricted Luau
AST evaluator supports local/upvalue lookup, bounded table/native-property
projections, finite arithmetic/comparison, boolean operations and bounded string
concatenation. Calls, constructors, assignment, global services, native mutation,
file/network/persistence access and arbitrary evaluation are rejected. A missing
projected entry in a truncated collection reports an explicit limit; cyclic/shared
reference expansion beyond the copy is unsupported. This is a read-only
projection of the stopped context, not a second executing Luau environment.

Inspection limits include 64 frames, 64 locals, 16 arguments, 32 upvalues,
256 copied values, depth four, at most 64 entries per table and 16 KiB of copied
string/native-projection budget per variable-group query. Four native handles
and eight approved properties per handle bound native inspection. Strings have
bounded previews with explicit length/binary/truncation metadata. Sensitive
names are redacted; name heuristics do not identify arbitrary secrets embedded
in otherwise ordinary user data. No unrestricted global/registry dump is offered.

## Development contracts

At most 128 breakpoint records and 256 retained compiled chunks per domain are
admitted through existing owner/reference budgets. BreakOnHit is a bounded exact
hit target; arbitrary conditional execution is not enabled. Reattachment/source
changes require new source admission; textual remapping across arbitrary edits
is not guaranteed. Old owners retire before new callback authority.

Custom messages use Godot's existing debugger connection, schema 1, a random
session nonce and monotonic request IDs. Closed typed fields, bounded strings,
32 commands/second and a 64 KiB custom response bound reject malformed/stale
input without creating domains or granting gameplay capabilities. The nonce
binds messages to the current connection; it does not replace Godot's transport
admission. No new runtime listener is created.

A `Suspending` notification requires an `AcknowledgeStop` bound to its domain
and StopId before the native blocking loop starts. The supported editor plugin
handles this automatically. Missing acknowledgment detaches after one second;
unexpected native-loop exit detaches both domains. This avoids interpreting
Godot's initialized debugger flag as proof that its peer is still connected.

Editor tooling can obtain bounded copied session descriptors through the native
editor plugin's `GetDebuggerSessions()`: connection generation, runtime state,
stop/domain identity and admitted locations. These omit session nonces and
live object handles, and are unavailable to executing gameplay Luau. Their
connection generation distinguishes repeated Play/Stop sessions.

The native authoring dock's Project Symbols command uses the existing bounded
project cache for function/type definitions and static imports, opening selected
locations in the ScriptEditor. Editor tooling can request `IndexProject("", "")`
for copied per-file entries, source hashes and exact lexical local-reference
definition locations. Unsaved active buffers participate in cache invalidation.
Global/member names and native class constructor patterns are syntactic candidates;
they do not establish whole-program types or runtime authority. Reports cap at
4,096 entries, 512/file, within the existing 256-file/8-MiB project read bounds;
partial files/reports are explicitly marked. The existing 250-ms scan deadline
is checked between bounded operations, not a hard preemption of an AST parse.

Only time actually spent in the native break loop is excluded from active
wall-clock execution deadlines. Allocation, safepoint and admission bounds
remain enforced. Attached execution uses the pinned VM's debug interpreter;
disabled execution keeps its original interpreter. Attached/disabled overhead
and later profiling/indexing features need their own recorded measurements.
Releases and updater distribution remain disabled.
