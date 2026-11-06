# GL-023 main integration and caller migration

## Source identity and acceptance

Main starts at `0d8942aff3cd8554ef0e3f1fb970a91ac7b7dbdd`. Normal merge
`669feae9d0602ae385f295390d4e348d8d667e57` preserves all four source commits:

- `918db6611c745f95995007a2b2d2d4d74271ef50` — regression/baseline.
- `4066b02a2c5be531543cb95f44eb8a53c18a8c72` — implementation.
- `aa5b765adfe09e2b4f3c7ee998bdbbdbc9cbc8d4` — qualified portable implementation.
- `479baa563b5f67c2f0a7e671ff9ccbad7265e4c5` — qualification evidence and retained branch tip.

The merge tree exactly equals the source tip. Subsequent integration changes
affect documentation and tests only. Native source identity remains 89 files,
SHA256 `71c663fbb978b34559a00a92b5315a8d6ff637f6db09ec04867e6cf5ddd8149f`
(LF normalized). Both dependency pins remain unchanged. The original
[qualification record](httpservice-validation.md) and
[manifest](evidence/gl023-httpservice-2026-10-31.json) remain historical evidence;
Debug/Release, core sanitizers, Linux native ASan/LSan and SCons qualification are
retained for that identical implementation. They are not new integration runs.

Acceptance requires compatible repository callers, explicit migration of the
published HTTP example, rejection/recovery without silent empty-string/object
substitution, unchanged GL-005 origin/owner/cancellation/resource contracts, fresh
Windows/Linux checks and bounded hosted observation. No release, updater,
dependency, upstream or unrelated runtime development is authorized here.

## Consumer audit and migration

The retained source-tip audit covers public GetAsync/PostAsync/RequestAsync,
JSONEncode/JSONDecode, HttpEnabled and `_HTTP`/`_JSON` usage in source, scripts,
tests and documentation. The backend README is the only executable public HTTP
usage example outside tests; there are no executable public HttpService JSON
callers outside tests and its implementation. Generated Roblox declarations,
editor completion descriptions and model token datasets are not executable
consumers and are not regenerated.

Teleport, Messaging and MemoryStore use the separate private `_JSON` bridge;
DataStore uses GL-009's native codec. GL-023 leaves these paths unchanged. Their
existing tests remain regression coverage, not a claim of public JSON migration.
External/imported games remain outside this audit and need their own migration.

The backend example now requires explicit trusted exact-origin grants and uses
pcall around both calls. Empty successful bodies remain successful; non-2xx
RequestAsync responses take an explicit failure branch; admission/transport
failures remain exceptions. The [JSON recipe](httpservice-api.md#migration-and-scope)
validates application schema after decoding, handles JSONNull and false, and
returns explicit encode/decode errors before side effects. It supplies no `{}`
fallback. Root README HTTP status descriptions now reflect asynchronous operation.

`RunHttpServiceCallers.py` extracts both published Lua snippets directly from
Markdown. Only the two external endpoint literals are replaced with owned
loopback URLs. Three real native Server actors exercise status 418, successful
empty 204 and an ungranted origin (zero requests). Each also runs malformed,
oversized and valid JSON, null/schema/false checks, cycle/unsupported/oversized
encoding and empty array/object round trips. Snippet hashes and exact server
requests are retained and required by the CI checker. The 92 original native
actors remain; integration adds three, for 95 per platform. Core remains 80.

## Fresh verification

The tested main input is `0a66b4ab6c291917745c698728d952657b2d5abf`, containing
the pure merge plus caller migration/tests. The final evidence commit changes
only documentation and this manifest; runtime, dependencies, workflows, test
harness and both executed published snippets remain identical to the tested
input. [Machine-readable integration evidence](evidence/gl023-main-integration-2026-10-31.json)
records identities, archive digests, jobs, executed actor groups and limitations.

Fresh Windows and Linux Debug worker runs at `gl023-main-v1` each pass 80 core
cases and 13 focused native actors: GL-005 HTTP (4), GL-023 public API (6), and
published caller migration (3). Both run the cached adapter after a successful
bounded two-job CMake build, with the unchanged 89-file native fingerprint.
The native source and test overlay identify these inputs independently of the
worker checkout's historical Git HEAD. Command:

```text
python Worker.py probe gl023-main-v1 debug
```

The task-owned worker driver invokes CMake, CTest/CheckCoreCI, then
`RunQualification.py --httpservice`, `--http` and `--callers` with headless Godot
4.7.1, isolated profiles, captured diagnostics and process timeouts. Its output
retains source/harness/library/engine and log hashes. All 57 harness files and
39 native logs per worker match their collected hashes; adapter and engine
hashes also match retained qualification. Three caller cases pass on each
platform and both report zero unauthorized requests; all 4,000 UUID samples per
platform are unique. Worker peak public HTTP frame gaps are 33.972 ms (Windows)
and 31.443 ms (Linux), below the existing 250 ms fixture bound.

Fresh hosted main jobs and downloaded artifacts both pass:

| Workflow | Windows Debug | Linux Debug |
| --- | --- | --- |
| [Core 41178250541](https://github.com/gmoddev/GodotLuau/actions/runs/41178250541) | 80 distinct cases | 80 distinct cases |
| [Native 41178250647](https://github.com/gmoddev/GodotLuau/actions/runs/41178250647) | 95 actors | 95 actors |

The four ZIP digests match GitHub artifact metadata. Core XML/discovery confirms
the actual 80 cases, including public HttpService coverage. Native artifacts
match the 89-file runtime fingerprint, pins and all 57 committed harness hashes;
286 Windows and 285 Linux log hashes are verified. Both contain actual PASS
markers for all six GL-023 actors and all three caller actors, with matching
published snippet hashes and exact expected server hits (none for denied
origins). Each platform retains 4,000 unique valid UUID v4 samples. Hosted peak
public HTTP frame gaps are 128.116 ms (Windows) and 51.667 ms (Linux), below
250 ms; these fixture samples are not application performance guarantees.

The retained Model fixture executes 76 checks, all three manual Character actors
execute, and both real delay/reordering proxies forward traffic with zero drops.
DataStore artifacts preserve four fault stages, four process-kill stages and
40 independent increments; they do not establish power-loss durability.
All original groups remain present, with no weakened assertions.

Observation was bounded from 06:51:05 to 07:21:05 UTC on 2026-10-31. Both native
jobs were observed successful by 07:05:42; artifact verification finished within
that window. There are no pending integration jobs. Raw worker ZIPs and all four
hosted ZIPs remain in ignored `.runtime-tests/GL023Main`; the manifest preserves
their hashes and the worker locations below. Hosted artifacts expire after
seven days and are not permanent distribution.

Worker outputs remain at
`DockerPC:C:/Sandbox/Codex/Artifacts/GodotLuau/gl023-main-v1-windows-debug` and
`linuxbox:/opt/codex/godotluau/results/gl023-main-v1-linux-debug` (container
`/work/results/...`). Worker archives are `C:/Sandbox/Codex/gl023-main-windows.zip`
and `/opt/codex/godotluau/gl023-main-linux.zip`. Prior qualification records and
failed attempts remain unchanged. No new runtime/test qualification failure
occurred in this integration; an initial read-only Windows inspection used the
wrong remote shell separators and was corrected before running tests.

## Retained limitations

GL-017 engine limits, GL-018 Windows full native sanitizer limits, broader
GL-020 adversarial/security qualification and graphical limitations remain open.
Source equality preserves prior qualification scope; it does not expand it.
Public API changes still require external caller migration as documented in the
[contract](httpservice-api.md). Releases and GL-016 updater distribution remain
disabled and unqualified. Source branches and original failed attempts remain.
