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
