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
