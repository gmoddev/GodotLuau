# ADR-004: Native asynchronous HTTP authority

Status: implemented, qualified and integrated into main through normal merge
`b7d108b08b9b55c8333a1799743204441b424dba`, preserving the qualified branch.
Extends ADR-001/002 and preserves ADR-003. Actual evidence is in the
[HTTP work record](http-validation.md), including fresh main integration checks.
Release publication and runtime updates remain disabled.

## Authority and configuration

Gameplay HTTP is denied by default. A trusted host project must set
`godot_luau/http/enabled=true` and supply `godot_luau/http/allowed_origins` as an
Array or PackedStringArray of at most 32 exact `http(s)://host[:port]` origins.
The settings are snapshotted when the scene's native domain host initializes its
HTTP manager. Empty/malformed grants or configuration fail closed. No wildcard,
path ACL, userinfo, proxy or script-controlled grant exists. Explicit HTTP origins
are permitted for services such as loopback Nakama; they are not implicit grants.

Only a current live Server owner in a native non-client process may issue a
request. Module initializers and delegated functions use the current native owner.
Client domains cannot borrow Server authority by changing Lua globals, service
tables, HttpEnabled or function environments. Bootstrap IDs, stale references,
closing domains and latched VM allocation failure grant no network authority.
HTTP cannot start in BindToClose; ADR-003's storage-only closing exception remains.
The mutable `_HTTP` facade is preserved and is not the security boundary.

Origin comparison normalizes DNS host case and decimal ports, with scheme and
port included. Hostnames use strict ASCII DNS labels; Unicode/IDN callers must
use an explicitly granted punycode hostname. IPv6 literals, userinfo, fragments,
backslashes, whitespace/control/NUL and malformed percent/port syntax are rejected.
Paths and queries stay on the granted origin; query-only URLs acquire `/`.
DNS and routing for a granted hostname remain trusted platform/host operations;
this is not an IP-address allowlist, DNS-rebinding defense or process sandbox.

## Scheduling, ownership and cancellation

Each scene host owns one finite request collection, with at most four active
requests and two per owner. All arguments, grants and capacity are checked before
retaining a native wait; task/reference admission uses GLCaptureWait. No DNS,
connect or send begins until admission succeeds. A fixed native context binds
the closure's host ObjectID/domain; no public numeric token grants HTTP access.

The coroutine yields through the existing external-wait path. Native host ticks
advance nonblocking transport; no Lua thread, main-thread wait loop, sleep, worker
Lua callback or new VM is introduced. Completion removes its record before Lua
reentry, validates the live non-recycled reference and resumable owner, and builds
results through ResumePrepared under ADR-002 protection. Module initialization
retains module ownership when its first requiring script retires.
The HTTP C continuation rejects manual coroutine resumption and cancels its old
request before Lua can start a new wait. A live coroutine identity alone cannot
authorize delivery into a later wait.

Cancellation, disable/reload, owner/thread destruction, memory failure and domain
shutdown close transports and release roots before VM reclamation. Admission is
closed before shutdown cleanup. No network wait is retained by close hooks.
Cancellation cannot undo a request already observed or acted on by a remote
server; the guarantee is local cancellation and no stale coroutine completion.

## Transport and bounds

Use Godot's asynchronous connection/DNS and normal TLSOptions::client validation.
A second HTTPClient parses the connected stream through an internal StreamPeer
adapter. The adapter meters reads/writes and checks header/wire bounds before
the parser consumes them. It returns a successful zero-byte read on tick-budget
exhaustion, leaving work for a later frame. This prevents Godot's internal
header-reading loop from monopolizing a tick. There are no redirects, automatic
retries, connection reuse or response decompression.
Transfer-coding parser input is case-normalized because the pinned engine's
chunked comparison is case-sensitive; original wire bytes remain validated.

Bounds per request are 4,096 URL bytes, 1 MiB supplied body, 32 supplied headers
(128-byte names, 4,096-byte values, 16 KiB aggregate), 16 KiB response headers,
4 MiB delivered response body and 8 MiB response wire data. Fixed native framing
headers and POST's content type have separately bounded overhead. Each active
request gets at most 64 KiB socket reads, 64 KiB writes and 2 KiB header delivery
per host tick. Four active records bound aggregate work; TLS/DNS/OS calls are not
preempted or a hard real-time guarantee.

The default monotonic admission-to-completion timeout is ten seconds, configurable
as integer `godot_luau/http/timeout_milliseconds` from 1 to 30,000. Every stage and
body tick checks the deadline, even while bytes keep arriving. Expiration, overflow,
malformed framing or truncated content produce failure with no partial body and
no successful status. Body/string allocations are bounded separately from the VM.
The engine's chunk parser can allocate up to its 16 MiB chunk bound before a chunk
is delivered; the 4 MiB API body limit is not a claim that every native allocation
is at most 4 MiB. TLS, DNS, engine and total process allocations are not VM bytes.
Deadline handling runs on host ticks; pausing the host defers processing until
its next tick, which fails an expired request before further network work.

For the existing local Nakama example, a trusted project can explicitly configure:

```ini
[godot_luau]
http/enabled=true
http/allowed_origins=PackedStringArray("http://127.0.0.1:7350")
```

This grants every path on that origin to Server scripts. Treat project settings
and DNS for named grants as trusted; changing HttpService.HttpEnabled in Lua does
not change the native snapshot. Other deployments must select their own origins.

## API and compatibility

The following paragraph records GL-005's original qualified API. GL-023 on its
dedicated branch supersedes the public fallback/headers/options/JSON behavior
with the [HttpService API contract](httpservice-api.md), while retaining every
authority, transport, scheduling and cancellation requirement above. Its native
response capture adds a 128-field/128-byte-name bound inside the existing 16 KiB
budget. Direct `_HTTP` transport failure/non-2xx dispositions remain compatible;
response headers and actual reason text are additive/corrected output fields.
GL-023 qualification is [recorded separately](httpservice-validation.md).

Keep GetAsync/PostAsync/RequestAsync and direct `_HTTP.get/post/request` names.
Successful GET/POST return byte strings, and RequestAsync retains its existing
fields (including its existing empty Headers table). Non-2xx bodies remain
available with Success=false. Direct request retains its four existing fields.
Transport failures raise through direct GET/POST; public pcall facades retain
their empty-string fallback, with bounded diagnostics that omit supplied URLs.
Direct/public request failures have StatusCode=0, Success=false and empty Body.
NoCache/compress remain accepted but unused; JSON conversion is unchanged.

Wire request/response bodies now preserve explicit Lua byte lengths, UTF-8 bytes
and embedded NUL instead of the inherited Latin-1/C-string truncation. URL/header
text is strict ASCII. This deliberate HTTP-only correction does not change
ADR-003's legacy storage encoding. Unsupported methods are rejected instead of
becoming GET. GET/HEAD bodies, duplicate headers/content types, invalid header
tokens and caller-supplied Host/framing/proxy/encoding headers are rejected before
I/O. Only supported complete HTTP/1.x framing is accepted; interim/upgrade and
unsupported encodings fail explicitly. Validated TLS remains mandatory for HTTPS;
there is no gameplay certificate-bypass flag.

Previously unrestricted calls require explicit project grants. This is intentional
capability tightening, not silent migration to another backend. GL-009 persistence,
GL-017/018 platform limitations, adversarial GL-020 and hostile-project/OS isolation
remain separate. The linked work record and evidence manifest establish the
executed branch qualification, including retained failures and platform limits.
