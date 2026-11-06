# Scoped inherited API audit

Scope: source at `4ea53113a98961a64347c672890f65bf9b5c8a54`, plus the staged
character work. This is an API/character adjacency audit, not a repository-wide
security scan. No HttpService implementation change is authorized in these stages.

## HttpService: GL-023 follow-up recommendation

Historical observations below describe the audited source. GL-023 now implements
the bounded [public contract](httpservice-api.md) on its dedicated branch;
[fresh qualification](httpservice-validation.md) is distinct from the original
source review and from main integration. The original evidence is preserved.

The [Roblox HttpService reference](https://create.roblox.com/docs/reference/engine/classes/HttpService)
was checked on 2026-10-30 for public method signatures, response examples and the
default `GenerateGUID` braces argument. It documents request methods as yielding,
response headers, and a default braces argument of true. These external facts are
comparison points, not a requirement to copy Roblox's internal transport.

| API | Source-verified behavior and classification | Recommended separate change |
| --- | --- | --- |
| HttpEnabled | `luau_stdlib.h:784` is an ordinary mutable Lua field, always initially true. It neither reads nor grants native origin authorization. Contract discrepancy; not a GL-005 grant bypass. | Expose read-only native effective configuration with clearly documented origin-specific limits. Assigning a Lua flag must never enable I/O. |
| GetAsync/PostAsync | `luau_stdlib.h:797–813` catches native errors, emits a generic warning and returns an empty string. An empty successful body and a rejected/failed request become indistinguishable. Source-verified error-contract discrepancy. | Propagate transport/admission errors; explicitly decide non-2xx handling without losing the existing asynchronous native owner/cancellation path. |
| RequestAsync | `luau_stdlib.h:815–833` reconstructs a table with empty Headers. More fundamentally, `gl_http.cpp` completion constructs only Success/StatusCode/StatusMessage/Body: native response headers are not exposed either. This is an end-to-end compatibility limitation, not merely discarded populated native headers. | Add bounded native response-header capture and a documented duplicate/header-name representation, then preserve it in the facade. Keep redirect/TLS/wire limits. |
| JSONEncode | The facade catches conversion failures and substitutes `"{}"`. `_JSON.encode` in `luau_script.cpp` uses the legacy Variant converter and Godot stringify, independently of GL-009's stricter DataStore JSON codec. Source discrepancy; malformed/cyclic/unsupported value outcomes need targeted runtime probes. | Specify supported values, UTF-8, cycles, arrays/objects, depth/size and explicit errors. Do not silently replace arbitrary input with an empty object. |
| JSONDecode | Empty input returns a table. `_JSON.decode` uses `JSON::parse_string`; its nil result is converted to an empty table by the facade's boolean fallback. JSON null, malformed input and an empty object are not reliably distinguished by the public contract. Source-verified limitation; no runtime crash claim. | Use an error-reporting parser and define null representation before changing callers. Reuse qualified bounds where applicable without replacing DataStore's codec incidentally. |
| Optional arguments | `noCache` and `compress` appear in signatures but are unused. PostAsync forwards contentType as a string to the native validated header path; Roblox-style enum input is not translated by this facade. Source-verified compatibility limitation. | Implement documented behavior or reject unsupported options explicitly. Avoid silently advertising compression/cache controls. |
| GenerateGUID | The format contains version/variant-like nibbles, but repeats the same millisecond timestamp in two fields and draws only 58 variable random bits for a fixed millisecond. Omitted braces are false in this implementation. Source discrepancy; collision rate/seed behavior is unmeasured and cryptographic unpredictability is not established. | Use an appropriate native UUID source, define default formatting, and test cross-process generation. Do not use the inherited generator as an authentication secret. |
| UrlEncode | Source percent-encodes bytes outside its unreserved pattern and coerces arbitrary input with tostring. No demonstrated defect in ordinary string encoding; input coercion is a compatibility choice. | Test UTF-8 bytes, embedded NUL, percent, spaces and non-string rejection/coercion explicitly before changing it. |

The native `_HTTP` path in `gl_http.cpp` checks the live Server owner/domain,
exact-origin grant, yieldability, admission, URL/method/header/body limits and
deadline before/during work. It yields through the existing HTTP wait and resumes
through owner-aware protected completion. Cancellation removes native requests;
closing, cancelled or failed-memory owners cannot receive stale completions.
These GL-005 properties remain unchanged. The public facade's pcall can hide an
error, but cannot authorize an origin or restore a cancelled coroutine.

Priority order for a separate GL-023 implementation:

1. Explicit public HTTP/JSON errors and honest capability/optional-argument
   semantics. Reproduce empty-body versus failure and malformed/null JSON first.
2. Bounded response headers across native completion and public RequestAsync.
3. GUID generation/format and deterministic byte-oriented URL encoding tests.

Acceptance should extend the existing GL-005 HTTP fixture server: denied origins
must produce zero forbidden hits; normal/empty/non-2xx/timeout/TLS/cancellation
cases must retain progress and bounds. JSON and GUID probes need their own
scoped compatibility tests. None of these findings justify replacing GL-005.

## Character-adjacent observations

| Classification | Evidence | Disposition |
| --- | --- | --- |
| Confirmed runtime defect | CharacterBaseline on both platforms demonstrated client position/health authority and overwriting server damage. | GL-007 staged implementation and qualification. |
| Source-verified contract discrepancy | `luau_class_identity.cpp` maps RobloxPlayer to Player; remote AnimatableBody3D has a different public identity. Neither inherits RBXModel. | Character V2 must fix actual native inheritance and both local/remote identity. |
| Architectural weakness | Movement/health/state in Humanoid, camera/input in RobloxPlayer, remote presentation in NetworkService, and name-based HRP/Humanoid discovery duplicate character assumptions. | Explicit Character V2 migration table and composition contract; not a vulnerability classification by itself. |
| Source-backed lifetime concern | Player/character event functions and several Humanoid movement-method closures retain raw targets across callbacks or as upvalues. Destruction/reload behavior is not established by the presence of ObjectID wrappers elsewhere. | Touched lifecycle paths require native destruction tests. Audit retained method closures during Character V2; do not claim all callback lifetime is repaired by GL-007. |
| Compatibility limitation | Humanoid accepts several movement signal names without an implementation trigger; state requests do not establish actual swimming/climbing physics. | Character V2 must mark unsupported observed states honestly instead of recreating misleading stubs. |
| Source-verified Model limitation | `RBXModel::_collect_aabb` currently uses world center and local size; rotated/scaled part bounds need correctness probes. Pivot methods keep a separate world_pivot. | Verify the inherited methods against Character V2 transform/parent cases before promising Model correctness. |
| Optional improvement | Character-specific component boundaries can reduce hierarchy searches and reflection. | Measure representative comparable workloads; no performance gain is inferred from the proposed design. |

Existing GL-021 and GL-018 remain separate signal-alias and Windows full-native
sanitizer gaps. No unrelated fixes are bundled into this audit.
