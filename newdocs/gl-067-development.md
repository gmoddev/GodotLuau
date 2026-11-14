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
