# GL-067 development platform campaign

## Baseline — 2026-11-14

Branch `feature/gl-067-development-platform` starts at verified remote main
`f54aa44265ae36b98fccfbc0622c4b61c4f6db06`. The shared checkout and historical
worktrees are preserved. This branch is not authorized for integration. Releases
and updater distribution remain disabled. Dependency and admitted-host pins stay
unchanged. GL-056–066 retain their existing meanings.

The GL-055 qualification and main integration records remain applicable to
unchanged inputs within their stated scope. In particular, the retained
256-module index observation is approximately 250 ms of synchronous editor work,
with truncated results. Source inspection finds directory traversal, disk reads,
hashing, parsing, and result formatting in `GLIndexProjectModule` on the main
thread. Its cache also evicts files not reached by a partial query. These are
source findings; no new benchmark has run yet.

## Acceptance and phases

1. Move project discovery and analysis off the editor thread, retaining bounded
   immutable results, active-buffer priority, incremental invalidation and
   cancellation. Reuse pinned Luau analysis; distinguish lexical/static evidence
   from dynamic expressions. Qualify semantic, cancellation and scale behavior.
2. Extend existing debugger/profiling and reload contracts where source supports
   safe improvements. Retain owner/generation retirement and restricted watches.
3. Expand usable native families, editor/scene/resource workflows and a meaningful
   acceptance project. Generated declarations must match actual authorization and
   runtime conversion behavior.
4. Qualify changed boundaries on Windows/Linux, appropriate sanitizer and package
   profiles. Reuse identical qualified inputs; retain failures and limitations.

Implementation, measured evidence and outstanding work will be recorded here as
they occur. This entry does not claim the campaign is implemented or qualified.

## Index authority decision

[ADR-019](adr-019-incremental-editor-index.md) defines the worker/snapshot boundary.
The editor worker is development tooling, not a gameplay scheduler or a VM.
No gameplay native capability, Godot object, Lua thread or AST pointer crosses
the boundary. Runtime modules and existing Server/Client execution stay intact.

## First implementation and focused Windows evidence

`acf57b9` implements a persistent pure-C++ worker using the pinned Luau parser
and Analysis frontend, copied open buffers, static require dependencies and
lexical references. Query kinds include symbols, references, search, dependency
pages, diagnostics, type-aware completion, function definition resolution and
conservative lexical rename previews. Dynamic member definitions are labelled
candidates rather than semantic proof. No rename applies project writes.

DockerPC reused the same-project MSVC Debug/dependency cache, two build jobs,
host-local worker lease generation 125. `ProjectIndexTests` passed 14 acceptance
checks against the production service. A 1,203-file typed item/economy workload
measured 22 us submission, 505,080 us cold worker processing and 274,417 us warm
worker processing (203,388 bytes). This is not a Godot frame-time or production
gameplay measurement. The worker still traverses and reads unchanged saved files;
syntax reparse count is zero when warm. Source/index bounds are 4,096 files,
32 MiB source, 256 KiB/file, 512 syntax entries/file, 256 result entries/page.
Semantic graphs are demand-driven and bounded to 256 modules/4 MiB source, with
50 ms per-module frontend limits. These are input/complexity bounds, not a hard
process-RSS limit.

The first actual official-Godot headless editor workflow failed one navigation
assertion. Investigation retained `editor-01` and `editor-02` under the worker's
`Artifacts/GodotLuau/gl067`: 22 files and 2,268 matches exceeded the first
256-entry page, occupied by Controller.luau. The legacy fixture expected every
document in a synchronous response. It now explicitly follows result pages;
the result-window bound is unchanged. This is a consumer migration, not a claim
that the failed attempts qualified editor navigation.

## Saved-source reload and profiler extension — qualification pending

Selective reload now stages and compiles every saved candidate before emitting
any source-change notification. An invalid candidate rejects the entire batch,
preserving previous source revisions and live generations. A successful batch
publishes those exact validated snapshots through existing generation/module
invalidation. Bounds are 256 resources, 1 MiB/file and 16 MiB aggregate. Built-in
resources remain unchanged. This is compile-validation rollback; it does not
promise rollback of runtime side effects after a valid script executes, scene
state migration, or preservation of old native handles after successful reload.

Profiling adds inclusive synchronous callback/require durations, excluding known
debugger waits, plus domain allocator live bytes at interval exit and lifetime
peak bytes. These observations are explicitly domain-wide, not per-function or
per-owner allocations. Existing record caps, opt-in behavior and epoch handling
remain. Function sampling and native-only dispatch timing are not implemented.

The `86a8600` Windows build and both CTests passed (87 existing core scenarios,
eight debugger/profiler scenarios and index checks). Its actual editor attempt
`editor-03` hit a fixture parse error from a newly shadowed `File` variable and
timed out; stderr retained. The diagnostic fixture now uses distinct names.
No product crash is inferred from this fixture failure.

Interactive completion/definition/rename now reuse the discovered source
snapshot, updating supplied buffers first; explicit `Refresh` requests rescan
disk. Full symbol/reference/diagnostic queries still refresh saved files. The
snapshot contract is visible rather than implying disk freshness without a
scan. Cross-platform Release worker checks are in `project-analysis.yml`.

`1908a79` passes the actual official-Godot Windows headless authoring workflow
and native-scene restart (`editor-04`). Both Windows/Linux Release worker jobs
pass in hosted run `43593686285`; both core jobs pass in `43593686220`. These
results do not establish graphical/physical editor interaction. The revised
Windows workload measured 23 us submission, 505,747 us cold, 270,226 us warm,
and 87,770 us for the first interactive completion (including frontend setup).
Warm interactive latency and native UI frame impact remain to be measured.

## Native family extension — qualification pending

Theme construction, default font settings and color/constant/font-size methods
use the existing scoped resource boundary. Native dispatch restricts keys/types
to bounded identifiers, 16 types/theme and 64 items/category/type. Existing
items can still be updated at capacity. Missing observational keys return a
bounded Luau error before Godot dispatch, rather than native error output.
Loaded immutable themes remain immutable and foreign owners cannot read/write
their handles. Foundry's Client-owned interface uses one reusable theme for
inherited native control styling; no Server authority or input protocol changes.

The metadata extension also adds RichTextLabel parsed-text observation,
Skeleton3D child/root traversal and obstacle height/3D-avoidance/navigation-mesh
configuration. New raw Callable/Signal/RID access, privileged PopupMenu/Viewport
construction and unrestricted AnimationTree target paths are not admitted by
these changes. Those need a coherent lifetime/authority design, not extra names
in the policy. Fifteen generator/policy checks and drift verification pass;
native/type/application qualification is pending.

## Declaration-backed semantic snapshots

The generator now embeds the exact shipped Native.d.luau text as editor-only
data, so the worker uses one declaration authority without main-thread project
reads or a second type model. Existing Lua gameplay facades remain dynamically
typed; this does not invent static schemas for their APIs. Semantic working sets
retain previous active modules up to the existing 256-module/4 MiB limit before
rebuilding, avoiding frontend recreation when switching between nearby modules.
New tests exercise native Theme authoring through that frontend, warm completion
and process peak-working-set measurements. Qualification is pending.

## Conditional debugger breakpoints — qualification pending

Breakpoint requests may now supply the existing bounded `Expression` field.
The exact same restricted Watch parser and copied local/upvalue/native-property
projection evaluate it before notifying the editor. Lua truthiness applies;
false/nil predicates skip the stop, while failed evaluation stops explicitly as
`ConditionError`. Hit counters count visits before the condition. Identical
condition replay preserves hits; editing the condition resets that record.
Multiple remapped breakpoints at one executable line combine as OR, with an
unconditional matching record taking precedence. No arbitrary Lua calls,
metamethods, mutation or gameplay capabilities are added.

The native debugger panel can set/clear a condition on the stopped source line.
It retains conditions when gutter state is replayed and erases them on breakpoint
removal. The original five real debugger modes remain mandatory; a sixth mode
checks false visits, a true live local and forbidden-call failure without a
gameplay side effect. Core checks extend an existing scenario without dropping
its original assertions. Actual protocol/editor qualification is pending.

Windows `5112d26` compiles and passes all 87+8 core cases. Its real debugger
attempt `debugger-06` passes the original five modes, including reload, ENet
timeout/reconnect, and both disconnect cases. The new conditional case fails
after its setup stop: the test peer sent three JSON-derived floating-point line
numbers, correctly rejected by the existing integer-only protocol. The peer now
casts those fields to integers and checks zero command errors. A focused case
selector permits rerunning that actual failed case without repeating unchanged
verified modes. The default CI run still requires all six modes.

The integer-corrected attempt `debugger-07-conditional` and diagnostic attempt
`debugger-08-conditional` show the true condition stopping at Index=3, with zero
protocol errors. Their unused-local probe lines emitted no distinct executable
instructions, so expecting them before the true stop was incorrect. The fixture
now uses observable native attribute writes for those two probes and requires
both to complete all five iterations. The implementation's executable-line
remapping contract and conditional assertions are preserved.

## Native editor semantic actions

The native authoring panel now exposes definition, completion, diagnostics,
symbol search and next-page actions backed by the worker. CodeEdit changes and
the existing EditorFileSystem change signal cancel obsolete work and debounce a
new snapshot request by 150 ms. Explicit polling reports stale generations,
allowing tools to retry after source changes. The editor fixture follows this
normal cancellation contract. Requests accept only the documented bounded
primitive fields; no arbitrary objects enter retained options or the worker.
The synchronous single-buffer language hooks remain their existing syntax/native
metadata implementation. These actions do not claim to replace every ScriptEditor
completion popup with asynchronous whole-project types.

Semantic definition additionally uses pinned Luau exported-table property
locations for static scalar members. Dynamic table/metatable cases remain
unresolved or explicitly labelled candidates. Type display uses Luau's bounded
stringifier options. Source/runtime/declaration identity and qualification remain
separate from these implementation notes.

## Final admission/bounds review

Dependency pagination now caps total returned edges at 256, including its copied
graph projection, rather than allowing 256 nodes each to return 128 edges.
Static imports account for compound and named-function reassignment. Diagnostics
deduplicate repeated dependency errors. Embedded/unsaved built-in Script resources
without a project module path are skipped by buffer collection. Semantic locations
only target indexed project modules and carry their source revision. The native
authoring toolbar wraps controls instead of stretching one horizontal row.

Pinned Luau source (`TypeFunctionRuntime.cpp` allocator,
`UserDefinedTypeFunction.cpp` execution) shows user type functions execute in a
compiler VM. Cancellation/deadlines are installed, but its new/delete allocator
has no quota. The index now rejects those declarations before semantic source
admission using the pinned lexer (also for incomplete source or a truncated AST
walk). It reports this unsupported profile explicitly and never evaluates that
project code. No OOM, crash or exploit was reproduced or claimed. This focused
source-backed exclusion preserves the worker's no-project-execution contract.
