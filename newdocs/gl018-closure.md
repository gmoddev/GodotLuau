# GL-018 qualified closure

Main integration (2026-11-03): normal merge `6a7fedf` preserves the combined
qualified source and this original evidence. The
[integration record](gl018-gl029-main-integration.md) tracks fresh main checks
separately. Release publication and updater distribution remain disabled.
The original branch qualification below retains its checkpoint disposition.

2026-11-02: **RESOLVED within the admitted matching-host headless Debug sanitizer
profile, on the development branch; not merged into main.** Qualified revision:
`46427d0e9ec10eb066202742255ef1881394f348`. All six hosted jobs are terminal
successes, and the downloaded evidence has been checked independently.

| Profile | Windows | Linux |
| --- | --- | --- |
| [Ordinary core 41505018403](https://github.com/gmoddev/GodotLuau/actions/runs/41505018403) | 80 cases | 80 cases |
| [Ordinary native 41505018353](https://github.com/gmoddev/GodotLuau/actions/runs/41505018353) | 110 actors | 110 actors |
| [Full-native sanitizers 41505018104](https://github.com/gmoddev/GodotLuau/actions/runs/41505018104) | ASan: 80 core / 110 native | ASan/LSan: 80 core / 110 native |

## Acceptance facts

The full profiles pass deliberate UAF detection, Linux leak detection, clean
engine-only/registration/minimal unload controls and five production VM reload
cycles. No unexpected sanitizer reports, incomplete groups, crash, timeout or
failed actor remains. Required native groups include HTTP/HttpService, all 23
DataStore actors, interruption/recovery, close hooks, cancellation, actual ENet
animation authority, Character, presentation and performance workloads. Each
native profile embeds all ten animation authority records (510 cases), and
HttpService records all 4,000 unique cross-process UUID samples. Core discovery
and JUnit output pass the existing strict 80-case checker.

The [independent verification record](evidence/gl018-final-ci-verification.json)
records source, reported product/compiler identities, hashes and actual counts.
Both sanitizer builds instrument all 1,160 native translation units plus three
probe units, using the matching host/compiler and admitted engine patch. Each
native artifact verifies its 73 normalized harness hashes and all 332–336 log
hashes. Sanitizer harness inputs match the exact Git source or explicit Windows
CRLF conversion. The 89-input production fingerprint remains
`2706e1685bdf0207e55eacc2f877e4578a3164603ea5861c183009348c7d1bc8`.

Windows verifies all 516 summary-indexed files. Linux verifies 520 files; its
summary additionally indexes one temporary GL-003 mailbox JSON absent from the
uploaded archive. Its path and expected hash are retained in the verification
record. No log, result or qualification input is missing. This is an explicit
ephemeral-data retention gap, not a claim that every indexed byte was retained.
Hosted product hashes are reported build identities; the evidence archives do
not contain distributable binaries for independent product rehashing.

## Fix scope and retained limits

The [original investigation](native-sanitizer-qualification.md) retains the
binding-retirement correction to the derived Godot qualification host, asset
preparation, locale-independent URL encoding and every failed attempt. The
[DataStore follow-up](gl018-increment-qualification.md) corrects the unsupported
fair-completion assumption while checking exact acknowledgments. The
[HTTP follow-up](gl018-http-frame-investigation.md) separates bootstrap from
transport timing, batches the synchronous UUID sample loop and accepts either
the byte cap or the original deadline as a bounded oversized-trailer rejection.
The 250 ms frame/shutdown assertions and runtime retry/admission/deadline limits
remain; a 350 ms injected stall is still rejected. Local close-time failures are
retained separately from the successful complete hosted profiles.

This closes the matching-host qualification gap. It does not qualify stock-host
unload safety, arbitrary hot-unload/custom bindings, Windows LSan, other compiler/
engine profiles, graphics/editor/devices, physical power loss or every historical
early-error leak path. No fresh Release matrix or production distribution claim
is inferred. GL-017 and unrelated issues remain separate. GL-029 has a different
source fingerprint and must obtain its own qualification.

Downloaded artifacts and verifier are retained under
`C:/Users/aiden/.codex/artifacts/godotluau/gl018-final-ci`. Main remains
`83cd0887968d73d61d050650718d8ada6e124579`. Source branches/commits, prior raw
evidence and failure history are preserved. Releases and updater stay disabled.
