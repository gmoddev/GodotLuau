# ADR-019 — Incremental editor project analysis

Status: implemented on the unmerged GL-067 branch; Windows/Linux worker, native
editor and Linux ASan/LSan qualification passes within the
[recorded scope](gl-067-development.md#final-index-lifetime-and-hosted-native-records).
Builds on ADR-015–018 without changing gameplay authority or execution.

## Decision

Give each native editor plugin an owned analysis service with one worker thread.
The main thread copies the project root and bounded open-buffer strings. The
worker discovers confined project files and uses the pinned Luau parser/frontend;
it never invokes Godot APIs or executes Luau. Results are copied strings,
coordinates and counters. No Godot objects, AST pointers, native handles or VM
references leave the worker. Destruction cancels and joins the worker before its
state is released.

Requests carry monotonic generations. New requests replace queued obsolete work;
the worker checks cancellation between files and through Luau's cancellation
token during semantic analysis. Only the latest completed generation is exposed.
Active buffers take precedence over saved files. Invalidation follows changed
source and reverse module dependencies. Unchanged cached documents survive
partial queries; deleted files are removed after discovery completes.

Discovery skips hidden directories, links and Windows reparse points and rejects
hard-linked files. Paths are project-relative `res://` module names. As with the
existing editor resource reader, this is a trusted local project boundary, not
an OS sandbox against a concurrent hostile project writer. Packed exports do not
run this editor-only service.

Bound file count, source bytes, per-file syntax/semantic work, retained index and
result pages independently. A report labels incomplete discovery, analysis,
diagnostics and results explicitly. A result page is not a complete index.
Main-thread calls submit/poll bounded pages rather than waiting for analysis.
The last complete snapshot may remain visible while a request is pending and is
labelled with its generation. Rename produces revision-bound edits for exact
lexical bindings only; it must refuse ambiguous/dynamic cross-module mutation.

## Compatibility and limits

The former synchronous project report becomes an asynchronous request/poll API;
editor actions must display pending state and refresh completed results. Existing
single-buffer language hooks remain available. Static `require("res://...")`
dependencies are supported. Dynamic module expressions are not invented edges.
This does not alter runtime require caching, persistent data, Character
controllers, network protocols, native authority, releases or updater admission.

Definition-only `.d.luau` files are excluded from runtime-module discovery and
open-buffer capture. Native globals load from the exact generated declaration
snapshot through the frontend's definition-file grammar. Project declaration
files are not implicitly merged into that authority; custom definition loading
remains unsupported. This classification does not change runtime require.

Luau analysis adds no dependency revision: use the already pinned Analysis and
Config components. Input/complexity limits and observed process-memory/latency
measurements are documented separately; they do not establish a hard RSS quota.

User-defined type functions are excluded from semantic admission. Source review
finds that pinned Luau executes them in a compiler VM whose allocator directly
uses C++ new/delete, outside the editor source bounds. The pinned lexer detects
their declarations even in incomplete source; syntax navigation marks the
limitation explicitly. No engine/dependency patch or alternate VM is introduced.
The worker does not evaluate project Luau, including type functions.
