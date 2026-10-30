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
The current helper loops and sleeps on the calling thread. Its nominal ten-second
deadline is checked only for empty body chunks; continuous data can bypass that
check. It sets Success from the status before body completion, so timeout or
truncation can retain a successful 2xx disposition. These are source observations;
controlled native timing/truncation reproduction is still pending.

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
