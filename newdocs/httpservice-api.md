# HttpService compatibility contract (GL-023)

Applies to `fix/gl-023-httpservice-compatibility`; main integration is a separate
decision. [Qualification and retained failures](httpservice-validation.md).
GL-005's [ADR-004](adr-004-asynchronous-http.md) still defines transport,
authority, scheduling, cancellation, input/output limits and TLS. No new backend,
VM, origin grant, dependency or distribution channel is introduced.

## HTTP and availability

`GetAsync(url, noCache?, headers?)` and
`PostAsync(url, data, contentType?, compress?, headers?)` return byte strings on
2xx, including an empty string for 204. Admission/transport failures and non-2xx
raise errors. Non-2xx errors include the status code and at most 128 reason bytes;
use `RequestAsync` when the application needs the failure body/status/headers.
Transport failures have no partial successful response. Errors do not include
the supplied URL. Use `pcall` at application recovery boundaries.

`RequestAsync(options)` returns `Success` (2xx), `StatusCode`, actual HTTP
`StatusMessage`, `Body`, `Headers` and the extension `HeaderValues`. Non-2xx is a
normal result with `Success=false`; transport/admission failures raise. Supported
fields are `Url`, optional `Method` (default GET, normalized uppercase), `Headers`,
`Body` and `Compress`. GET/HEAD must omit Body entirely. Only the seven methods
already allowed by GL-005 are accepted. Unknown fields, including per-request
`Timeout`, are rejected before I/O. The trusted project timeout remains the sole
deadline policy. `Compress=nil` or `Enum.HttpCompression.None` (0) is supported;
Gzip (1) and other values are explicitly unsupported. PostAsync's boolean
`compress` must be nil/false; true raises before I/O.

Response headers have lowercase ASCII names and OWS-trimmed values. Ordinary
duplicates are joined with `", "` in wire order. `set-cookie` exposes its first
field in `Headers`, without invalid comma folding; `HeaderValues[name]` contains
every original field as a separate array entry, including cookies. The additional
capture is bounded to 128 fields, 128-byte names and the existing 16 KiB wire
header budget (including status line/CRLF). Invalid ASCII, obsolete folding and
overflow fail the entire request. Trailers are not response-header fields. No
cookie jar, redirect, retry or decompression behavior is added.

`noCache` must be nil/boolean. True sends `Cache-Control: no-cache` and
`Pragma: no-cache`; conflicting supplied cache headers raise. It requests cache
revalidation at the peer and cannot promise that remote intermediaries obey.
Caller header tables are copied. Injected headers count toward native limits.
PostAsync maps `Enum.HttpContentType` numeric values 0..4 to application/json,
application/xml, application/x-www-form-urlencoded, text/plain and text/xml.
Default is application/json. Explicit nonempty MIME strings (up to 256 bytes,
then native header validation) remain a fork compatibility extension. Duplicate
Content-Type is rejected; content-type selection does not serialize the body.

`HttpEnabled` is a read-only native availability query for the current live
Server owner, valid configured origin grants and native non-client role. It is
false for Client, disabled/invalid configuration, closing or failed domains.
It is not a promise that a particular URL is authorized or that admission space
or a reachable peer exists. Every request independently checks the original
native boundary. The service and its metatable are frozen; replacing `_HTTP`
fields cannot change its captured native query/request functions. The legacy
mutable `_HTTP` facade remains available under its original native checks.
Direct `_HTTP.request` retains StatusCode=0 failure dictionaries; direct get/post
retain non-2xx bodies. Its request dictionary now includes bounded headers and
actual reason text too. Public error handling intentionally changes.

## JSON

The HttpService codec is independent of the legacy private `_JSON` conversion
and GL-009 DataStore serialization. It runs in the caller's existing Luau VM,
under GL-004 execution/allocation accounting. Input/output limits are 1 MiB,
traversal budget 16,384, and nesting depth 32 with the root at depth zero.
Traversal charges values and object keys; decoding also charges string escapes.
Limits may reject an otherwise syntactically valid document. Domain resource
limits can be reached first; catching an error cannot revive a retired domain.

Supported values: booleans, finite binary64 numbers, valid UTF-8 strings,
consecutive positive-integer arrays and string-key objects. Null encodes from
nil or `HttpService.JSONNull`; decoding null returns that immutable unique
sentinel. Null array elements and object properties are preserved. Untagged empty
tables encode as `[]`, matching Roblox's empty-table convention. Decoded empty
objects/arrays retain their kind through a private weak-key association, so `{}`
round-trips as `{}`. Altering a decoded container into the other key shape raises.
New nonempty string-key tables encode as objects; object order is unspecified.

Malformed syntax, duplicate object keys, trailing input, raw controls, invalid
UTF-8, unpaired UTF-16 surrogates, nonfinite numbers, cycles, sparse/mixed keys,
unsupported key/value types and exceeded bounds raise explicit errors. Metamethod
iteration is not used. Shared acyclic tables may appear more than once. Strings
support escaped embedded NUL and surrogate pairs. Numbers use finite binary64
semantics; precision beyond that range is not preserved. Output is compact JSON,
not a canonical signing representation. No fallback substitutes `{}` or null for
an unsupported value. Duplicate-key rejection, explicit null, strict mixed-table
rejection, no buffers/nonfinite extensions and tighter limits are intentional
differences from Roblox.

## UUID and URL encoding

`GenerateGUID(wrapInCurlyBraces?)` uses 16 bytes from Godot Crypto's random provider,
sets UUID v4/version and RFC variant bits, and returns lowercase 8-4-4-4-12 hex.
Omitted/nil/true includes braces (38 bytes); false omits them (36 bytes). Other
argument types raise. Provider failure raises; no timestamp/weak fallback exists.
The fixed six bits leave 122 random bits; uniqueness is probabilistic, not a
registry guarantee. It needs no HTTP grant and exposes neither entropy buffers
nor native handles. Tests sample independent processes, not all future outputs.

`UrlEncode(input)` requires a string, at most 1 MiB. It percent-encodes original
bytes outside ASCII letters/digits and `-._~`, using uppercase hex. Space is %20,
percent is %25, UTF-8 is encoded bytewise and embedded NUL is %00. Arbitrary byte
strings remain supported. The proven byte behavior is retained; automatic
`tostring` coercion is removed. RFC3986 unreserved punctuation remains unescaped,
an intentional difference from examples that escape a dot. This is component
encoding, not URL authorization or a full-URL builder.

## Migration and scope

Remove assignments to HttpEnabled and monkey patches to this service. Configure
trusted native origin grants instead. Catch HTTP/JSON errors explicitly, use
RequestAsync for non-2xx bodies, look up lowercase header names, and use
HeaderValues for repeated fields. Handle JSONNull explicitly rather than testing
truthiness for null. Applications expecting empty-object fallbacks, nil holes,
mixed-table filtering, numeric URL coercion or unbraced default GUIDs must change.
Pass false to GenerateGUID to retain bare formatting.

Compared against the official [HttpService reference](https://create.roblox.com/docs/reference/engine/classes/HttpService),
[content types](https://create.roblox.com/docs/reference/engine/enums/HttpContentType)
and [Godot Crypto](https://docs.godotengine.org/en/stable/classes/class_crypto.html)
on 2026-10-31. This is a bounded compatibility contract, not full Roblox parity,
hostile-project isolation, an authentication-secret API or graphical qualification.
GL-017/018 and the wider GL-020 security gate remain open. Releases and the
GL-016 updater/distribution channel remain disabled and unqualified.
