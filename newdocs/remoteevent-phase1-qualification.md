# GL-029 Phase 1 qualification

## Sanitizer follow-up from `78897d3`

### Strict UTF-8 dictionary-key correction

A separate production-API probe reproduces an encoding defect on the combined
Windows ASan runtime: local RemoteEvent delivery preserves ASCII `foo='ascii'`,
but lookup by a valid U+96EA key returns nil. The same encoder serves network
events. The first probe attempt had a GDScript type-inference error and is not
runtime evidence; the corrected probe completes with `ASCII=ascii Unicode=nil`
and exit 1, without script/sanitizer errors. Outputs are retained under
`C:/Sandbox/Codex/GL029Continuation/unicode-baseline-v2`.

Source confirms dictionary keys use `String(const char*)`, whose pinned
implementation calls the Latin-1 constructor. Strict event values already use
UTF-8. The one-line correction uses `String::utf8` only for StrictRemote keys;
RemoteFunction/replication legacy conversion remains unchanged. Actual ENet
fixtures add U+96EA keys with U+1F600 values to Server, echo and Wait assertions
for all delivery classes. This conforms to the existing version-1 UTF-8 contract;
no wire-format, public API, storage encoding or ownership refactor is introduced.
The same public probe passes after the correction (`ASCII=ascii Unicode=snow`,
exit 0, empty stderr). The final non-diagnostic matching Windows ASan run passes
all 20 focused actors: six RemoteEvents, seven existing network actors, three 2D
Character actors and four HTTP actors. The RemoteEvent actors include the new
Unicode Server/echo/Wait assertions. This focused run excludes the separately
retained identity-GC stress failure and does not constitute full-suite acceptance.

Fix `eec239779e873c54982c81ec9984c7ff98b8f6b8` has native source fingerprint
`ac6706375ad4dfa912b6424bf9c17d767262e51ed62dbc5ebfeaf614e8ec2ffc`
(90 LF-normalized inputs), DLL SHA-256
`5721e2092827dba585e817192a9b4fbe0ceff23b0769112d78b3b542658c68e5`
and corrected matching host SHA-256
`96a64e425ae1aac600014e6fbe8489b3178c8d09b210c47fd4a03f18edcafdb0`.
Outputs: `C:/Sandbox/Codex/GL029Continuation/asan-final-focused-utf8-v1`.
Fresh complete hosted native, sanitizer and non-publishing Debug/Release candidate
gates remain required; core CI 41531861167 passes both platforms at this revision.

Retained archive: `C:/Sandbox/Codex/GL029Continuation/utf8-qualification-evidence.zip`,
copied to `C:/Users/aiden/.codex/artifacts/godotluau/gl029-working/utf8-qualification-evidence.zip`.
SHA-256: `2ec1db7e4cac1ef24bc074bc610ad8d3223d7868df774d5e0c772e5e058fe18d`.
All 565 indexed files rehash after download. The four executed final fixture
files match the committed inputs after LF normalization. The archive retains
diagnostic/failing attempts, build/product identities, the negative and positive
Unicode probes and the final focused results. No unexpected ASan report is
present in that final focused output; it does not erase the separate broad
regression failure. Core tests were disabled in this local native rebuild.

Exact-source hosted gates (in progress at this observation):

- [Native 41531861106](https://github.com/gmoddev/GodotLuau/actions/runs/41531861106).
- [Full-native sanitizers 41531861175](https://github.com/gmoddev/GodotLuau/actions/runs/41531861175).
- [Non-publishing Debug/Release candidate 41532697897](https://github.com/gmoddev/GodotLuau/actions/runs/41532697897).

The candidate workflow has read-only contents permissions and qualifies source
products, extracted companion packaging and runtime checks; it does not enable
the dormant publication workflow or updater distribution.

The locally rebuilt matching Windows ASan diagnostic confirms ENet's adaptive
unreliable throttle reaches 0/32 during startup, with further reductions around
reconnect. It also reproduces the missing reconnect echo, without an application
rejection or sanitizer finding. A fixture-only connected-peer callback configures
`throttle_configure(5000, 32, 0)` on both ends, including replacement connections,
and checks the configured deceleration. Production transport defaults are not
changed. This explicitly qualifies an unthrottled functional loopback profile;
default-throttle/congestion/induced-loss behavior remains separate Phase 2 work.
No delivery assertion, native admission, retry policy or timeout is relaxed.
The focused Windows ASan execution above passes this controlled profile.

The diagnostic and subsequent non-diagnostic Windows ASan Remote groups both
pass six actors with that profile on the combined `d5c7c67...` native source.
The callback ignores relayed client IDs, configuring only real ENet links; the
strict native checker now requires its profile assertion for every actor.

The local original 2D diagnostic passes all three actors with default throttle
varying 24–32. That is counterevidence to a universal 2D runtime defect. The 2D
functional fixture nevertheless assumes its finite pose samples arrive, and
its hosted failure is retained. Apply the same explicit functional carrier
profile only to its TwoD mode; keep movement/authority assertions and all other
modes unchanged. The focused Windows ASan execution passes; hosted verification
remains required.

HTTP diagnostics reproduce a 428.698 ms frame while the replacement scene starts
both cold domains. Stagger Client setup over three frames before the fresh Server
script: no clock/peak reset, raised threshold or removed lifecycle assertion.
Initialize the initial domain counters before the existing three-frame warmup
as well, preserving the close-hook owner order and the baseline blocking probe.
All four focused HTTP actors pass after that setup correction.
The local broad regression attempt separately reaches the existing identity-GC
stress loop's resume deadline on this compiler profile; it is retained as a
failure, without changing resource policy or calling the full suite qualified.

Ordinary hosted native CI `41518023025` passes all 116 actors on Windows and
Linux. Sanitizer CI `41518023028` fails both platforms: Remote listen completion
fails on each; Windows additionally fails the old dedicated network startup,
2D Character admission and HTTP lifecycle timing. Both sanitizer summaries
record no unexpected sanitizer finding. These are failed profiles, not memory
safety passes inferred from functional markers.

The Windows legacy network client calls FireServer after transport connection
but before the new RemoteEvent publication activates, raising `Remote not ready`.
The fixture now waits for the Event's actual Ready state within its existing
600-frame connection loop. Native readiness enforcement and deadlines are not
weakened. The remaining Remote Once failure and separate timing/admission cases
need instrumented attribution before further changes.

DockerPC starts an incremental Windows native ASan build against immutable
combined source `348c5e9`, using the existing matching corrected host and pinned
dependencies, two compiler jobs and captured logs. A preparation guard detects
that the shared driver checkout's core-test CPP differs; it is preserved, and
this local build selects only the native adapter/probe, with core tests off.
No shared source or dependency is overwritten. Existing GL-018 native products
are copied aside before the cache is reconfigured. Build success alone will not
be reported as runtime qualification. Current work remains on the integration
development branch, without a main merge, publication, updater or refactor.

## Resumed after GL-018 closure

2026-11-02: the [GL-018 closure](gl018-closure.md) independently verifies all six
core/native/sanitizer jobs at `46427d0`. Its fixes are carried forward by normal
merge on `integration/gl-018-gl-029-remoteevents`, preserving original GL-029 tip
`1e5e2f62b6b85f97e29bd03bacf469182fa4467d` and every research/source commit.
Main remains unchanged. This does not transfer GL-018 qualification to the new
90-input combined source. Resume actual six-actor ENet coverage first, make only
necessary small fixes, and obtain permission before refactoring. Preserve the
116-actor strict checker and existing release/updater denial. Phase 2 and GL-030
remain out of scope. The checkpoint history below retains its original status.

### First resumed runtime reproduction

DockerPC Windows runs the original immutable candidate13 Debug product before
changing production code. Source fingerprint `22b690a...` and every product hash
match the checkpoint handoff. The actual ENet listen group fails late-join
completion; Client2 reports `ClientAPI:18`, while Server subsequently fails its
late-join and rejection-count checks. Outputs are retained under
`C:/Sandbox/Codex/GL029Continuation/baseline-candidate13`, including input/product
identities and the original logs. This is baseline evidence, not qualification
of the GL-018-combined fingerprint `d5c7c67...`.

A diagnostic fixture copy keeps the same native products and assertions while
printing event labels/recipient IDs. Reliable Echo retains nil, mixed-table keys
and values. The expected unordered echoes are absent; a later ReconnectEcho
reaches a still-pending Once callback and fails its expected Echo assertion.
Determine rejection versus permitted unreliable loss before selecting a fix;
the first script assertion is downstream evidence, not proof of a codec defect.
Additional admission diagnostics are pending. No timeout/assertion is weakened
and no production networking change or refactor has been made at this point.

Fresh combined core CI passes at `a6bd710`; native and sanitizer builds are
running. Those builds/results must be assessed separately from candidate13.

The admission diagnostic narrows this failure: in the failed dedicated run each
Client delivers exactly 19 reliable events (Legit, sixteen ordered events, large
fragmented payload and numeric sample), with **zero native rejections** before
adversarial traffic. The two unordered events do not reach the native handler.
The listen diagnostic in the same attempt delivers all 21 with zero rejections.
This is counterevidence to the suspected receiver-size mismatch; that production
check remains unchanged. No dictionary corruption is established by this failure.

A five-line fixture correction waits, within ten seconds of the existing
fifteen-second outer bound, for reliable order/fragment/numeric echoes before
sending the one-shot unordered functional probes. No retries, longer deadline,
removed assertion, delivery-mode change or networking refactor is introduced.
It separates functional validation from congestion/loss behavior; it does not
claim guaranteed delivery of unreliable events. Fresh execution is required.

The barrier candidate clears the listen group's late-join/payload checks but
still fails the immediate adversarial rejection-count assertion. Client-side
file completion marks submission, not server-side processing. Wait for the same
26 native rejections within the existing 15-second bound before checking that
dispatch stayed unchanged; retain the exact count and report the observed delta.
Do not lower the count or assume this resolves a lost unreliable attack packet.
This follow-up remains unqualified until fresh runtime results are checked.

### Focused correction result

The bounded-barrier plus server-observation fixture passes all **six real ENet
actors** on the original candidate13 Windows Debug runtime: Listen and Dedicated,
each Server and two Clients including late join. The listen server observes 27
native adversarial rejections, satisfying the unchanged minimum of 26; all
original case records are complete and pass. No caller retries or production
networking changes are involved. Candidate fixture SHA-256 (original Windows
bytes): `a821a5cf2e38f34bfe87873e0f72a6f8f39be421fe044314b7c73d9e944d3214`.
Outputs: `C:/Sandbox/Codex/GL029Continuation/barrier2-candidate13`.

The earlier failure histories remain separate and retained. This focused pass
qualifies the fixture correction against candidate13; it does not qualify the
GL-018-combined source, other configurations or the full 116-actor suite.
`python tests/release/ReleaseCandidateTests.py` also passes all 14 admission/
rejection cases. Fresh combined hosted native/sanitizer evidence remains required.

### Retained evidence and fresh hosted gates

Fix `78897d3c22cc13ce1603761759dad416f0be2a2e` changes eight fixture lines and
documentation; no production networking or other runtime source is modified.
The passing focused record contains six actors and **193 passing assertions**.
All 335 indexed retained files rehash after download, including prior failures;
the executed fixture matches the committed file after explicit LF normalization.
Archive SHA-256: `4e9915f5a651c4723e928ea9869af47b1f4e19ff73088e25ee26ce69159cafcf`.
Copies: `C:/Sandbox/Codex/GL029Continuation/resume-evidence.zip` on DockerPC and
`C:/Users/aiden/.codex/artifacts/godotluau/gl029-resume/resume-evidence.zip` locally.

Exact-fix hosted jobs have started; none is reported passing at this observation:

- [Core 41518022846](https://github.com/gmoddev/GodotLuau/actions/runs/41518022846).
- [Native 41518023025](https://github.com/gmoddev/GodotLuau/actions/runs/41518023025).
- [Full-native sanitizers 41518023028](https://github.com/gmoddev/GodotLuau/actions/runs/41518023028).

Require fresh combined-source runtime verification, remaining platform/build
configurations and artifact checks before accepting GL-029 Phase 1. GL-018's
qualified branch remains preserved and main stays unchanged. Release publication
and updater distribution are disabled. No refactor has been performed.

Status: **PARTIALLY QUALIFIED; WIP checkpoint at the user's request on 2026-11-02.
Not ready for integration.** No merge or distribution authorization. The
[handoff](remoteevent-phase1-handoff.md) records restart steps and exact final
build identities. Starting main is `83cd0887968d73d61d050650718d8ada6e124579`;
branch is `network/gl-029-unified-remoteevents`. Research input is
`9ea782bb739cc35deba06474a82582a12529df6d`. The
[decision/API/migration contract](adr-008-remoteevent-publication.md) is authoritative
for this Phase 1 implementation; the earlier three-mode proposal remains a plan.

## Retained development attempts

All builds/tests run on DockerPC. Source snapshots, commands, logs and products
are retained under `E:/Codex/GL029` (Windows/durable host storage) and
`/work/gl029` in DockerPC's existing Linux qualification volume. No LinuxBox or
external test worker is used. Compiler parallelism is two. DockerPC's C: capacity
is checked because its Docker backing disk shares that volume; task source and
Windows evidence use E: rather than consuming its remaining capacity.

- `prototype1`: Windows Debug build and the existing regression group passed.
  This establishes early integration only, not final-source qualification.
- `prototype2`: Windows Debug compiled. The new fixture failed because it called
  the Lua-only StartServer API through a nonexistent GDScript binding. The
  fixture now uses the public Lua API; no native capability was added for it.
- `prototype3`: Windows Debug compiled. Setup rejected the fixture's assumed
  legacy Roblox ClassName/IsA alias. Source proves that alias never existed;
  tests now require the inherited native identities to remain unchanged. A
  freed GDScript lambda capture was also replaced with a numeric instance-ID
  check. The original logs remain.
- `prototype4`: Windows Debug compiled. The same-named-child assertion failed:
  the outer GodotObject metatable wrapper resolved children before reaching
  the canonical getter. The implementation now gives DeliveryType precedence
  in that wrapper as well. The assertion is retained.
- `prototype5`: all six Windows real ENet actors passed, and Windows Debug core
  passed 80 cases. Further source review added private-ancestor checks and native
  constructor provenance for listen-host Client-created Remotes.
- `prototype6`: matching Windows/Linux Debug builds completed and the six Linux
  ENet actors passed. A Windows dedicated reconnect/finish attempt failed while
  the peers disconnected/reconnected concurrently. The failure/logs remain;
  subsequent fixtures coordinate reconnects as the existing regression harness
  does for GL-017, without increasing their deadlines or changing the engine.
- `fixtures7` against the exact `prototype6` native fingerprint and `candidate10`:
  expanded typed/reference dictionaries exposed an event-writer defect. Its
  string-writing path returned an empty value to dictionary-key validation,
  falsely reporting duplicate keys. The writer now returns the actual input
  string; multi-key dictionaries, typed values and references remain required.
  CFrame assertions remain on reliable delivery; unordered uses a smaller bounded
  tuple. The broad earlier limit diagnostic did not establish an actual byte-size
  failure and is now separated into invalid-encoding and measured-size errors.
  Original failures remain failures.
- `candidate10` also exposed an early poll in the queued-Wait fixture. Godot's
  send path already flushes ENet; that extra poll could receive the event before
  the intended cancellation boundary. The fixture now flushes without receiving,
  then performs one controlled production poll. Its queued-cancellation assertion
  is retained; no timeout was increased.

Reference compatibility review additionally retained logical Player and canonical
scope-root references without restoring arbitrary network path fallback. Queued
Wait retirement is tested with controlled production ENet polling and the existing
RemoteFunction primitive; its implementation/deadline policy is unchanged.

- `candidate13`: Windows MSVC and Linux clang-19 Debug configure/build commands
  exited zero. Both record native source fingerprint
  `22b690a3872189a0d41c604c35ab694a087b8b755526d8acbf43432a7b3a1310`
  (90 files, LF normalized). Current source/test inputs match that staged archive.
  **Neither final product has run the fixtures.** The dictionary-writer correction,
  controlled queued-Wait poll, active-service routing and failed-start atomicity
  remain runtime-unqualified on these inputs.

No final full native matrix, Release profiles, sanitizer profiles or hosted
artifact verification was completed before this checkpoint. Earlier passes do
not qualify the final source. Complete those gates before accepting Phase 1.

## Required current fixture inventory

The existing core inventory remains 80 cases. Six new real ENet Remote actors
(Listen and Dedicated, each Server plus two Clients including a late join)
increase native discovery from 110 to 116. The existing runner, process owner,
strict checker and hosted native workflow are extended; old actors/assertions
remain required. Non-publishing candidate gates require the same enlarged
inventory, without enabling publication or updater installation.

`RemoteEvents.gd` covers supported modes, legacy configuration/identity, native
and Lua configuration paths, publication readiness, legitimate Player arguments,
nil/mixed tables, Once/Wait, malformed/oversized payloads, wrong role/session/mode,
forged controls, same-scope reparenting, dynamic replacement, retained methods,
wait cancellation, disconnect and fresh-session admission. Captured fixture
records and required assertion names must pass the strict native checker.

## Remaining scope

No sequenced mode, supersession queue, general scheduler, spatial replication or
RemoteFunction deadline change is implemented. GL-029 remains open for later
phases; GL-030 is unchanged. Native ENet retention/ACK visibility, complete-packet
MTU profiles and broader fairness remain Phase 2 proof gates. GL-017/018 and
full-native sanitizer limitations must remain visible. Headless native checks
do not expand graphical or device qualification claims.
