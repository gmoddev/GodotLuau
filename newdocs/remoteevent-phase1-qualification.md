# GL-029 Phase 1 qualification

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
