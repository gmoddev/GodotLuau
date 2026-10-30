# GL-005 HTTP investigation and qualification

## Starting checkpoint (2026-10-29, America/New_York)

Dedicated branch: `runtime/gl-005-async-http`. Starting local/remote main is
`3d390a03d2f8078795333622e876ad1754202d58`. The checkout is clean, has one
worktree and no competing file claims. Dependency pins are unchanged. No main
merge, release publication, updater enablement or unrelated development is part
of this task. GL-003 storage and GL-004 execution/resource contracts are retained.

## Source investigation

All three native `_HTTP.request/get/post` entry points in `luau_script.cpp` call
`gl_http_perform`. HttpService is a Lua pcall facade, not an authorization gate.
`HttpEnabled`, Lua role globals and private-looking tables cannot grant authority.
The baseline helper loops and sleeps on the calling thread. Its nominal ten-second
deadline is checked only for empty body chunks; continuous data can bypass that
check. It sets Success from the status before body completion, so timeout or
truncation can retain a successful 2xx disposition. These are source observations;
controlled native timing/truncation reproduction is still pending.
The later controlled-baseline section records the executed reproduction; this
paragraph describes the initial investigation checkpoint.

Inputs, accumulated response bytes, headers and request concurrency have no
HTTP-specific bounds. Header conversion lacks CR/LF/NUL validation; URL parsing
has authority/port/query ambiguities, unknown methods become GET, and C-string
conversion truncates embedded NUL. Public GET/POST return strings; RequestAsync
returns Success/StatusCode/StatusMessage/Body/Headers. JSON helpers are independent.
The inherited implementation does not follow redirects and uses normal validated
TLS. Local Nakama is a documented consumer and needs an explicit loopback origin
grant rather than globally allowing loopback.

The fix-finding workflow's independent read-only investigation confirms these
paths and the existing native wait/reference/invalidation hooks. No reproduction,
remote exploit or SSRF result is inferred from source alone.

## Implementation direction and acceptance

Use the existing Server domain and native owner/ref admission, host-owned request
records, cancellation hooks and protected ResumePrepared completion. No new VM,
background Lua callback, duplicate owner registry or storage authority is needed.
New requests must fail closed without a trusted project-configured exact origin
grant, and on Client/stale/closing/failed-memory contexts. Check inputs and
capacity before DNS/connect/send. Preserve public API names and successful shapes;
document any encoding/error correction explicitly. No redirects or unsafe TLS.

The pinned Godot engine's `HTTPClientTCP::poll` reads response headers in a loop
until it runs out of bytes or sees a terminator, without a header-size bound.
Its chunked-body parser can allocate a chunk before delivering it. One poll per
frame is therefore insufficient by itself. A bounded StreamPeer adapter is being
evaluated to meter parser reads/writes, cap header/wire bytes before consumption,
and return no available bytes when the current tick's allowance is exhausted.
Godot remains the protocol/TLS implementation; no new HTTP parser or dependency
is selected. This prototype and its lifecycle/EOF behavior require actual tests.

Acceptance requires baseline and corrected slow/truncated/streaming cases;
frame/timer/other-owner progress; native grant, URL/header/body and admission
rejection with zero server-observed forbidden requests; bounded response/deadline
failures; ordinary methods and non-2xx behavior; TLS and disabled redirects;
cancellation/disable/reload/module/scene/shutdown/OOM cleanup; and preservation of
the GL-003/004 and existing core/native regressions across qualified platforms.
Worker builds reuse pinned incremental caches with bounded parallelism. Expected
failures run headlessly with captured output, crash UI suppression and timeouts.

## Controlled baseline and first prototype

`HttpIntegration.gd --baseline` runs through the existing bounded launcher against
the unchanged main Debug extension on both workers, with an owned loopback server
and disposable profile. Server and Client both perform direct GET/POST/request and
public HttpService calls. A deliberately incomplete Content-Length response reports
Success=true with `partial` as its body. The measured peak frame gap is 0.952084 s
on Windows and 0.836248 s on Linux. Both baseline actors exit zero with the expected
baseline PASS marker. The fixture uses a two-second GL-004 resume budget solely to
observe the blocking result; this is not a production-policy change. Original
binaries/logs/results are retained in worker `gl005-baseline` directories.

The first async native prototype compiles on Windows/Linux Debug and passes the
same legitimate loopback methods, native Client denial and corrected truncation
failure. Other-owner timers advance during the delayed GET. Peak frame gaps are
0.067750 s and 0.025958 s respectively, below the declared 0.25 s fixture threshold.
Forbidden server-observed requests remain zero. These are focused functional
measurements, not universal frame-time guarantees or final qualification.
`gl005-prototype` results remain separate from the baseline. The fixture label
`http-baseline` was reused by this initial launcher; its PASS marker and selected
mode distinguish candidate from baseline, and final groups will use explicit labels.

The implementation uses a host-owned bounded queue and metered StreamPeer over
Godot's connected TCP/TLS stream, with a separate HTTPClient parser. It never
polls or sleeps waiting for I/O on a Lua call stack. Native waits use the existing
owner/thread roots and protected completion. The original mutable `_HTTP` facade
is retained; native context/grants, not table visibility or mutability, authorize
operations. Header/parser, TLS, admission and lifecycle edge coverage, the policy
decision, independent candidate review and full qualification remain pending.
GL-005 remains open.

## Expanded coverage and corrections

The existing core runner/checker now requires 72 cases (56 ordinary plus the same
16 isolated resource children). Three added cases use the production URL/header
policy and wire-budget code. Native HTTP adds four cases in the existing launcher:
enabled methods/bounds/progress, default/Client denial, lifetime/admission/OOM,
and validated TLS with hostname/untrusted-certificate/stalled-handshake rejection.
The checker/workflow will require all 43 native actors, including the unchanged
39 actors from GL-003/004 and existing lifecycle/network/animation groups.
Loopback servers settle observations after bounded cleanup; forbidden paths must
have zero hits. TLS uses newly generated, explicitly public test-only keys and
certificates plus the engine's trusted-project CA-bundle setting. No certificate
validation bypass is added to the runtime. PEM inputs are included in fixture hashes.

Intermediate `gl005-probe-1` stops on fixture errors: changing a C-function
environment is unsupported by Luau, and GDScript decoded CR/LF inside a Luau
source literal. A Lua delegate with a forged environment and correctly escaped
injection bytes now reach the native boundary. Probe 2 stops at its wire-limit
assertion. Read-ahead originally covered headers only, making the engine's
one-byte chunk/trailer parser too slow to reach the 8 MiB limit before timeout.
Bounded body read-ahead fixes that path; later probes hit the actual byte-limit
disposition and pass enabled/default-denied cases on both platforms.

Probes 3–5 expose fixture lifetime assumptions and an insufficient OOM trigger.
GL-004's default VM quota is 512 MiB, so 128 MiB is not a quota test. The fresh
OOM scene now chooses the existing supported 8 MiB quota and attempts 16 MiB.
The close-hook owner must remain alive until host shutdown; Godot's exit traversal
uses reverse insertion order, not move_child's cached sibling order. Registering
the hook from the first owner, and capturing its origin/store before shutdown,
matches the established GL-003 fixture. No GL-004 or storage implementation is
changed. Its one exact terminal-quota diagnostic is expected; other script errors
still fail the HTTP fixture. Probe 6 passes lifecycle/admission/GL-003 close-save
checks on both platforms.

Probe 6's TLS positive control then fails. The server observes its valid GET,
but Godot StreamPeer's Array API drops partial bytes when TLS encounters EOF in
the same oversized read. TLS fetches are now bounded to currently decrypted bytes,
using a one-byte probe when none are buffered. This preserves normal certificate
and hostname validation while avoiding a read beyond the current TLS record.
Probe 7 passes core72, all four HTTP actors, filesystem3, resource8 and regression8
on Linux. Windows passes enabled/default-denied/lifecycle but its one-second TLS
fixture reaches no transport. Probe 8 gives TLS five seconds (production default
remains ten); Windows still reaches no listener. Its localhost resolves ::1 first,
while the fixture listened only on IPv4. The fixture now owns both loopback
families on the same port. Windows TLS probe 9 passes validated GET/binary POST,
hostname/untrusted rejection and the stalled-handshake deadline. Settled connection
counts are Tls=3, Untrusted=1 and Stall=1. Linux probe 8 passes all focused groups.
No certificate-validation bypass or system resolver modification is used.

The single independent candidate review identifies two concrete defects. Pinned
Godot compares transfer coding case-sensitively, while native validation accepted
mixed-case Chunked. Probe 10 reproduces rejection with Connection: close; default
keep-alive could instead produce an empty successful body. The stream now
normalizes only the transfer-coding parser input, retaining checked original wire
bytes. Fixtures cover both connection variants and require the decoded body.

The reviewer also traces manual coroutine resumption: task.spawn(Thread, ...) or
coroutine.resume can leave an old HTTP completion targeting a newer wait. Probe
11 confirms that manual resumption supplies a forged successful return instead
of rejecting the pending call. HTTP closures now have a native continuation:
normal completion removes the record first; any other resume cancels that record
and raises a bounded error before another wait starts. Both manual-resume APIs
are covered, including a subsequent delayed request that must receive its own
result. This changes no generic scheduler or GL-004 execution implementation.

Probe 12 initially stops at compilation because the continuation used lua_error
as an integer expression; the pinned API returns void. Correcting that call is
part of the candidate, with focused runs pending. Failed logs and actor server
observations remain under distinct probe directories. Full qualification is not
yet claimed.

After the corrected continuation compiles, probe 12 passes core72, HTTP4,
filesystem3, resources8 and regression8 on Linux. Windows reaches the same group
sequence after its HTTP4 pass; its final process result is checked before the
matrix starts. The auxiliary build-and-probe wrapper initially failed because
its nested exec retained the wrapper's __file__; running the unchanged probe as
its own process fixes orchestration without changing runtime/tests. The matrix
will freeze native source and effective fixture hashes before Debug/Release/ASan
and SCons qualification.

The first frozen matrix passes Windows/Linux Debug and Release (core72/native43)
and all six core configurations, but Linux native ASan/LSan stops in HTTP default
denial. LSan reports 11,208 bytes/56 allocations from the fixture's two generic
HTTPRequest instances. The alternate-path test created unparented nodes without
destroying them. It now calls Destroy after checking that request is unavailable.
No runtime change or sanitizer suppression is involved. The original matrix's
failed logs remain distinct; corrected final qualification will use fresh v2
directories and effective fixture hashes.

The cleanup probe then passes enabled/default-denied/lifecycle under ASan/LSan,
but TLS fails explicitly: the existing minimal matching engine was built without
HTTPS support. BuildSanitizedGodot.sh now enables Godot's existing mbedTLS module
at the same pinned engine revision. Rebuilding uses the same incremental cache,
two jobs and the owned worker container; no tool installation, system trust
change or leak-detection suppression is involved. TLS sanitizer qualification
requires the rebuilt engine and is not inferred from the earlier HTTP passes.
Its first shell invocation rejects CRLF in the transferred script before SCons
starts. The worker executes an LF-normalized copy of the same script; the
incremental mbedTLS engine rebuild then exits zero in 18.81 seconds. Caches and
the pinned engine revision are preserved.

Corrected v2 CMake Debug/Release and all core configurations pass on both workers;
Linux ASan/LSan HTTP4 now passes with HTTPS enabled and proceeds to existing groups.
Windows SCons Debug passes HTTP4/resource8 but its unchanged filesystem reader
asserts in the one-line expiration check, then the writer times out waiting for
reader-done. The reader's stored Expiring entry has a one-second integer wall-clock
expiry. The log does not distinguish its immediate-read assertion from its
post-two-second assertion; clock-boundary sensitivity is a hypothesis, not a
confirmed cause. GL-003 source/fixtures and GL-004 are unchanged. The failed
directory is preserved and the exact filesystem case is rerun in a fresh retry
directory before continuing SCons Release. A successful retry will not erase this
counterevidence or establish stronger TTL/concurrency semantics than GL-009.

## Qualification commands and identity

Implementation commit is `4dbecc8ddf38a375457d5603f73184db6e061cf1`;
fixture cleanup/TLS build configuration is `fce3637b7625d9086e28d78314cb7ed50ae1aa34`.
Native input fingerprint is
`cbb0115097636e91cac3f0228f6dd49abfb51a4c8dcc86f1a0189d58aeaf51cc`
(81 files, LF-normalized). Core test CPP is
`67357a54722b532a0de27f6e5ecd87e46c508480fb5a5bdfa4b0b045c5d6db20`.
The 32 effective Python/GDScript/PEM/CMake/distribution inputs are hashed separately.
The sanitizer-engine build script is recorded separately from those fixture inputs.
Pinned godot-cpp/Luau content is checked against the existing tracked-file digest,
including the Linux tar-tree workspace that has no submodule Git metadata.

Windows uses `C:\Sandbox\Codex\Workspaces\GodotLuau`, persistent
`Builds\GodotLuau\runtime-msvc-{debug,release,asan}`, MSVC via vcvars64, CMake
3.31.10 and portable SCons 4.5.2. Linux uses `/work/source` and
`/work/builds/linux-{debug,release,asan}` in the owned qualification container.
Every native build uses two jobs and incremental dependency caches. Native engines
are official Godot 4.7.1, or its matching pinned ASan/LSan headless build with
mbedTLS for the Linux sanitizer actors. Windows full native ASan remains GL-018;
only its core sanitizer configuration is claimed.

The worker orchestration captures these commands in separate per-stage logs:

```text
cmake --build <config> --target ExecutionDomainTests GodotLuauAdapter --parallel 2
ctest --test-dir <config> --output-junit <report> --test-output-size-passed 65536 --test-output-size-failed 65536 --output-on-failure
python tests/runtime/CheckCoreCI.py report <report>
python tests/runtime/RunQualification.py --godot <engine> --extension <library> --output <fresh-group> --http --timeout 60
```

The other native groups use the same launcher with `--teardown --coordinated-close`,
`--security`, `--animation`, `--resources --timeout 15`, or `--filesystem`.
SCons runs `platform=windows|linux target=template_debug|template_release -j2`;
Windows invokes the already approved RunSConsPortable.py and its isolated tool path.
Each SCons product runs HTTP4/resource8/filesystem3 with the same launcher.
FixtureProcessTests.py checks process ownership/failure cleanup. The sanitizer
engine uses BuildSanitizedGodot.sh with `/work 2`, including use_asan/use_lsan;
leak-at-exit detection stays enabled. Reproduced baseline, failed probes and final
`gl005-qualified-v2-*` outputs remain separate. Hosted CI additionally runs the
strict core/native result checkers and retains actual source/harness/engine/log
identity; green workflow status alone is not the artifact-verification receipt.

## Final local qualification

The corrected v2 matrix passes. The [evidence manifest](evidence/gl005-asynchronous-http-2026-10-29.json)
retains input identities, engine/binary hashes, JUnit/result/log digests and
settled HTTP observations. No forbidden request reaches an endpoint; native
default-denied actors observe no HTTP requests. TLS actors reach the legitimate,
wrong-hostname, untrusted-chain and stalled-handshake transports. Byte/deadline,
binary/non-2xx/method, scheduling and lifetime controls all pass. The original
slow-frame and truncated-success defects no longer reproduce in candidate mode.

| Worker/configuration | Core | Native actors | HTTP enabled peak gap |
|---|---:|---:|---:|
| Windows MSVC Debug | 72 | 43 | 0.072591 s |
| Windows MSVC Release | 72 | 43 | 0.013630 s |
| Windows core ASan | 72 | Not claimed (GL-018) | Not applicable |
| Linux Debug | 72 | 43 | 0.026918 s |
| Linux Release | 72 | 43 | 0.008474 s |
| Linux matching ASan/LSan engine + adapter | 72 | 43 | 0.058842 s |

Each native row includes HTTP4 plus all existing regression8/security10/
animation10/resource8/filesystem3 actors. SCons Windows/Linux template_debug and
template_release each pass HTTP4/resource8/filesystem3 (15 actors per product).
The Windows template_debug filesystem result uses its explicit fresh retry;
the original failed expiration assertion remains described above. Fixture process
ownership tests pass 14/14 on Linux; Windows passes eight with six POSIX-only
cases explicitly skipped. No unrelated storage, scheduler or dependency source
is changed. GL-003 close-save and GL-004 retirement/recovery are exercised in the
HTTP lifecycle case as well as their original groups.

The native source and 32 effective fixture hashes match both workers and the
local checkout. Both official engine hashes match their previously verified
4.7.1 distributions. The matching Linux engine now has mbedTLS and a new recorded
binary hash; it is not misidentified as the earlier TLS-disabled engine. Build
tools/caches remain on workers. The owned Linux container has been stopped after
qualification; no fixture server/process remains running, and unrelated host
workloads were not changed.

Hosted core [40989908872](https://github.com/gmoddev/GodotLuau/actions/runs/40989908872)
passes 72 cases per platform at the fixture-corrected revision; both ZIP digests,
discovery and JUnit completion are downloaded and checked. Hosted native
[40989908863](https://github.com/gmoddev/GodotLuau/actions/runs/40989908863) passes
43 actors per platform at `fce3637`. All four artifact ZIP digests are verified;
both native summaries match the local native fingerprint, all 32 fixture hashes
and the official engine hashes. Every recorded native log hash (Windows115/Linux113),
GL-022/resource/filesystem/HTTP PASS marker, actor result and settled HTTP server
observation is checked. Forbidden HTTP hits remain zero, and default-denied actors
make no HTTP requests. The earlier implementation-only core/native runs also pass;
the final receipt uses the fixture-corrected revision rather than substituting
that earlier success.

GL-005 is fixed and qualified within ADR-004 on this dedicated branch. This is
not main integration: main remains `3d390a03d2f8078795333622e876ad1754202d58`.
The final follow-up changes only documentation/evidence; native, core-test and
fixture input identities remain those qualified above. Release jobs still have
false admission/read-only permissions; RuntimeUpdatesAllowed still returns false.
No release dispatch, updater enablement, main merge or history rewrite occurs.

The contract requires explicit native origin grants and intentionally corrects
HTTP binary/NUL handling. It does not establish hostile-project/OS isolation,
DNS-rebinding prevention, a hard real-time frame budget or total-process memory
limits. The parser's native chunk bound can exceed the delivered API-body bound.
GL-009, GL-017/018 and adversarial GL-020 remain separate. The observed Windows
filesystem expiration failure and successful exact-case retry remain in this
record; they are not reclassified as a resolved storage/TTL defect.
