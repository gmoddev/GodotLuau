# GL-023 HttpService correctness work and qualification

## Starting point and acceptance

Work starts from clean local and remote main
`0d8942aff3cd8554ef0e3f1fb970a91ac7b7dbdd`, on the dedicated branch
`fix/gl-023-httpservice-compatibility`. Main and upstream must remain unchanged.
Dependency pins and release/updater admission remain unchanged. GL-005's native
owner/origin grants, asynchronous transport, bounds and cancellation remain the
governing contract; this task changes its public API and bounded response data.

Acceptance requires meaningful HTTP errors and statuses, bounded real response
headers/duplicates, native availability without Lua authorization, explicit strict
JSON semantics/bounds, native UUID v4 generation, supported or explicitly rejected
optional arguments, and demonstrated URL argument corrections. Existing frame,
authority, lifetime, TLS, resource, persistence and Character regressions remain.
Windows/Linux Debug/Release, both core sanitizers, matching Linux native ASan/LSan
and verified hosted core/native execution are required before final qualification.

## Controlled baseline

`RunHttpServiceBaseline.py` runs the unchanged qualified Debug adapters against
owned loopback servers in separate enabled/unavailable processes on each worker.
The production input remains the integrated 88-file native fingerprint
`e64dffcbd69a806aedadcf98dc97507a3a17eaff88ced4a38d9fbd7d4ac427db`.
The source/test overlay and historical worker Git HEAD are distinct; the tested
adapter identity is checked separately during evidence collection.

Both Windows and Linux reproduce:

- Public denied GET and successful 204 both return an empty string.
- RequestAsync loses real response headers; its non-2xx status/body are already
  preserved, while GetAsync returns the non-2xx body without an error.
- Malformed JSON and JSON null return tables; an unsupported function encodes
  as JSON null. The malformed parse also emits the engine's parser diagnostic.
- Default GenerateGUID omits braces, and HttpEnabled stays true in Client and
  explicitly disabled native configurations.
- UrlEncode already preserves UTF-8 and embedded NUL as percent-encoded bytes;
  its demonstrated argument discrepancy is coercing numeric input to a string.

No forbidden request reached either fixture server. These are API correctness
reproductions, not an origin-grant bypass or a reproduced native crash.

Accepted baseline output roots are `gl023-baseline-v2-{windows,linux}-debug`
under the established worker results directories. Commands use the official
Godot 4.7.1 engine and matching cached CMake Debug adapter:

```text
python tests/runtime/RunHttpServiceBaseline.py --godot <engine> --extension <adapter> --output <fresh-baseline>
```

The initial Linux fixture omitted the scene's `Game` name and collected no
completion metadata; its failure and parser diagnostics remain at the separate
`gl023-baseline-linux-debug` root. Correcting fixture setup gives the v2 results
above without changing production. The first Windows launcher resolved the Store
Python alias; the corrected command uses the existing controlled Python and
installed Debug CRT. No runtime execution is claimed for that launcher failure.

## Selected API direction

The official [Roblox HttpService source reference](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/HttpService.yaml)
and [content-type values](https://create.roblox.com/docs/reference/engine/enums/HttpContentType)
were checked on 2026-10-31. They establish v4 GUID/default braces, JSON errors,
request/response fields and optional arguments. They are external API comparison
points, not evidence that this fork implements every Roblox feature.

Public requests will propagate failures through the existing yielding native
request entry, preserving its direct transport compatibility and cancellation.
The native response captures bounded header values and status text. HttpEnabled
is a read-only view of native Server availability, with origin checks still at
each request. Unsupported compression/options fail before I/O. HttpService JSON
uses a bounded Luau codec so its allocations/execution remain under GL-004;
DataStore's separate native codec and legacy private JSON bridge are unchanged.
Exact JSON null/container and migration differences require the API contract
before implementation qualification. UUID randomness comes from Godot's existing
Crypto provider; no transport backend or dependency is replaced.

## Implementation and focused qualification

The [public API/migration contract](httpservice-api.md) defines the implemented
semantics and deliberate differences. Native request capture and UUID randomness
are added to the existing native manager/facade. HttpService JSON stays in the
existing caller VM; legacy private JSON and transactional DataStore codecs are
unchanged. Dependency pins, transport scheduling, owner lifetimes and all grants
remain unchanged. No assertion was removed to accommodate the new behavior:
the retained GL-005 facade assertions now require errors/read-only availability
and actual reason text instead of its documented old fallback behavior.

Focused Windows/Linux Debug output roots:
`gl023-candidate-v4-{windows,linux}-debug`. Both pass 80 distinct core cases and
10 native actors (four retained GL-005 plus six GL-023). The GL-023 runner checks
2,000 native UUIDs in each of two processes, 4,000 unique values overall, and
retains all samples. Both fixture servers observe zero forbidden requests.
The new six actors cover API/status/headers/options, default/Client denial,
manual-resume/owner-reload/shutdown, TLS, and offline JSON/UUID in two processes.
Core tests execute the production HttpService fragment with a transport double;
native actors exercise the actual full bootstrap, VM, transport and Crypto.

Retained candidate failures are part of this record:

- v1/v2 Linux core: 59 pass, five fail because the new service tried to freeze
  a table whose metatable was already protected. v2 exposes the exact bootstrap
  diagnostic. Construction order was corrected before the passing v3 core.
- v3 Linux native: API/denial/lifecycle/TLS pass, Utilities compilation fails
  because GDScript consumed Luau string escapes. A raw fixture string fixes the
  harness; v4 executes the JSON and UUID assertions. No production assertion
  was weakened. The failed fixture output/logs remain in their v3 root.
- The first Windows candidate driver could not quote its compiler setup through
  cmd. A task-owned batch file captures the configured toolchain environment;
  v4 builds/tests successfully. This was a launcher failure, not a runtime pass.

The full matrix uses the established hidden Linux container and Windows worker,
two build jobs, official Godot 4.7.1 for Debug/Release, and the existing matching
Linux ASan/LSan engine for native sanitizers. Completed fixture library copies
are deduplicated only after SHA256 equality against immutable evidence copies;
mutable build outputs are never linked into those evidence files.

## Qualification status

Focused qualification complete; full matrix and hosted CI pending.
GL-017/018, broader GL-020 security and graphical limitations remain independent.
No merge, release publication or updater distribution is authorized.
