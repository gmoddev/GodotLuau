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
- Hosted core run [41175214979](https://github.com/gmoddev/GodotLuau/actions/runs/41175214979)
  passes Linux but fails Windows compilation at `4066b02`: MSVC 2022 reports
  C2026 because one expanded stdlib literal exceeds its per-literal limit.
  The newer worker MSVC accepts it. Splitting the literal corrects the portable
  build; concatenated Luau bytes remain identical. No test or dependency changes
  accompany this correction. The original run and diagnostics remain retained.

The full matrix uses the established hidden Linux container and Windows worker,
two build jobs, official Godot 4.7.1 for Debug/Release, and the existing matching
Linux ASan/LSan engine for native sanitizers. Completed fixture library copies
are deduplicated only after SHA256 equality against immutable evidence copies;
mutable build outputs are never linked into those evidence files.

## Qualification status

Qualified source is `aa5b765adfe09e2b4f3c7ee998bdbbdbc9cbc8d4`, retaining the
regression commit `918db6611c745f95995007a2b2d2d4d74271ef50` and behavior commit
`4066b02a2c5be531543cb95f44eb8a53c18a8c72`. The portability correction only splits
an embedded literal: 127,863 assembled Luau bytes remain identical, SHA256
`68175de14e3638d3f8f6c5e0be1e9c859b47c11b966891a4fc2b8eaa696f72cf`.
Maximum individual literal falls from 20,379 to 14,465 bytes. The final 89-file
native source fingerprint is
`71c663fbb978b34559a00a92b5315a8d6ff637f6db09ec04867e6cf5ddd8149f`.
Dependency pins remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.

| Final source configuration | Core | Full native regression actors |
| --- | --- | --- |
| Windows Debug | 80 pass | 92 pass |
| Windows Release | 80 pass | 92 pass |
| Windows core ASan | 80 pass | Not claimed (GL-018) |
| Linux Debug | 80 pass | 92 pass |
| Linux Release | 80 pass | 92 pass |
| Linux core/native ASan + LSan | 80 pass | 92 pass |

The five full native configurations retain all eight previous groups (86 actors)
and add the six GL-023 actors. Actual Model checks (76), manual Character actors,
GL-007 delayed/reordered traffic, GL-022 relay lifecycle, GL-003 confinement,
GL-004 quotas, GL-005 HTTP and GL-009 interruption/concurrency remain exercised.
DataStore native evidence remains four fault stages, four killed-writer stages
and 40 independent increments; hardware power loss is not claimed.

Both SCons `template_debug` and `template_release` products on both platforms
also pass all 10 old/new HTTP actors, plus the 14 process-ownership and five
packaging cases. These are local qualification products, not released builds.
The first full matrix at `4066b02` also passes its applicable configurations;
the final source matrix above is separately executed, not inferred from identical
Luau bytes. Final worker output roots use `gl023-aa5b765-<platform>-<mode>` and
`gl023-aa5b765-scons-<platform>-<target>`.

[Hosted core run 41175369764](https://github.com/gmoddev/GodotLuau/actions/runs/41175369764)
passes 80 actual cases on each platform.
[Hosted native run 41175369757](https://github.com/gmoddev/GodotLuau/actions/runs/41175369757)
passes all 92 actors on each platform. All four ZIPs were downloaded through the
GitHub connector and matched GitHub's SHA256 digests. JUnit cases, all six GL-023
PASS markers per platform, JSON/UUID markers, the actual 4,000 UUID samples per
platform, zero forbidden server hits, 55 harness hashes, and every one of 277 log
hashes per native artifact were checked. Source, dependency, DataStore and
Character evidence also match. Observation completed within a bounded 30-minute
window from the final runtime push. Evidence-only commits do not change these
qualified runtime, harness or workflow inputs.

The original [native run 41175215037](https://github.com/gmoddev/GodotLuau/actions/runs/41175215037)
also fails Windows C2026 at `4066b02` while Linux passes. Both failed hosted runs
and all four original artifacts are retained separately from the passing runs.
The first Windows diagnostic bundle omitted hashed Godot profile logs; the
verifier rejected it. Its original ZIP remains retained, and complete v2 bundles
include those logs without weakening verification. Linux collection initially
assumed a Git checkout; that worker actually uses an exported source tree. Its
dependency files are compared against the exact pinned Git trees: 165 godot-cpp
and 852 Luau tracked files, zero missing/changed files after compiler-equivalent
text newline normalization (841 Luau checkout files have CRLF). The initial raw
blob mismatch is an export/line-ending distinction, not a dependency edit.

The [evidence manifest](evidence/gl023-httpservice-2026-10-31.json) records exact
revisions, configuration flags, artifact/worker archive digests, actual commands,
per-configuration timing, binary identities and retained failures. Raw diagnostic
bundles stay in `.runtime-tests/GL023` locally and the established worker results
roots. Hosted artifacts have seven-day retention; the manifest retains their
identities independently. No runtime binary is committed or distributed.

Frame responsiveness passes the existing 250 ms maximum-gap assertions; the
largest final worker gap is 83.774 ms (Windows Debug). Hosted maxima are 51.383 ms
(Linux) and 50.291 ms (Windows). This includes
the public slow-response checks advancing another script's counter by more than
five ticks. Exact measured maxima are in the manifest. UUID sampling covers two
independent processes per configuration; it establishes observed uniqueness, not
a guarantee against future collisions. The Crypto failure branch is source
checked but not forced by an entropy-provider fault injection. JSON traversal and
VM budgets are independent limits, not production throughput measurements.

GL-023 is qualified within the [documented compatibility contract](httpservice-api.md)
on its dedicated branch. Main remains
`0d8942aff3cd8554ef0e3f1fb970a91ac7b7dbdd`; integration requires a separate task.
GL-017/018, broader GL-020 security and graphical limitations remain independent.
No merge, release publication or updater distribution is authorized.
