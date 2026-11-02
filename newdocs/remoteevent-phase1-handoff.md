# GL-029 Phase 1 checkpoint handoff

Date: 2026-11-02. **PARTIALLY QUALIFIED / WIP; NOT READY FOR INTEGRATION.**
The user requested cleanup, a handoff, commit and publication before completing
qualification. Resume this phase only; do not merge, implement sequenced delivery,
change RemoteFunction deadlines, enable releases/updater distribution or modify
upstream. Main stays `83cd0887968d73d61d050650718d8ada6e124579`.
The checkpoint is on `network/gl-029-unified-remoteevents`; its enclosing commit
is the checkpoint identity. Research input remains
`9ea782bb739cc35deba06474a82582a12529df6d`.

## Implemented work awaiting acceptance

Read [ADR-008](adr-008-remoteevent-publication.md), the
[qualification attempt history](remoteevent-phase1-qualification.md), architecture,
invariants and issue ledger before changing code. The branch adds:

- Native Server-owned, publication-frozen `DeliveryType`, default ReliableOrdered,
  optional UnreliableUnordered, and fixed legacy unordered behavior. Enum identity
  2 is reserved; UnreliableSequenced is not exposed. Actual inherited legacy
  ClassName/IsA behavior is retained, including `UnreliableRemoteEventNode`.
- Session/endpoint/generation descriptors, readiness acknowledgement and activation,
  ObjectID revalidation, retirement and bounded receive admission in the existing
  NetworkService. Event data no longer chooses replacement targets by NodePath.
- An event-only bounded codec, strict payload validation before side effects,
  stable replicated/root/Player references, retained-method ObjectID captures,
  subscription bounds and generation-checked queued Wait cancellation.
- Six real ENet actors in `RemoteEvents.gd`, using the existing runner and strict
  checker. Expected inventory becomes **80 core cases / 116 native actors** (the
  original 110 remain required). Ordinary native CI and non-publishing candidate
  gates include the new group. No separate qualification framework is added.

Key source boundaries: `src/gameplay/roblox_remote.h`,
`src/services/roblox_network.h`, new `src/core/gl_remote_payload.h`,
`src/core/gl_net_bridge.h`, `src/core/gl_domain_host.cpp`, and the Luau bindings.
The startup correction installs a new transport only after successful creation;
the existing RemoteFunction deadline/terminal policy is deliberately unchanged.
This substantial WIP still needs independent correctness review and qualification.

## Exact latest build identity

Both DockerPC Windows/Linux **Debug builds passed**, not runtime qualification.
Attempt `candidate13` is the final source/test snapshot at this checkpoint.
The controller compared all staged `src/`, `tests/` and `SConstruct` archive entries
with the current checkout (LF normalized): no differences.

| Input/product | SHA-256 |
| --- | --- |
| Native source fingerprint, 90 files, LF normalized | `22b690a3872189a0d41c604c35ab694a087b8b755526d8acbf43432a7b3a1310` |
| Source candidate13 ZIP | `03752b11afe2e67c4ba6db7d00cad03c99548fba5ed9956269f0b78b39359aa2` |
| Windows Debug extension | `0ba08a4672c360d6e92f1232484ee6ac1f162a4e833c0b45d31b60f6eee27ece` |
| Windows Debug persistence companion | `bc48d49174dbc515d846537569464d6cf9977e3164f944258228e65057adcbde` |
| Linux Debug extension | `1ede9d012340c47b99e2235741eb92fecc88200d64d7c039adeae34d6b5ab208` |
| Linux Debug persistence companion | `1b8447392519485e33adf66dc3648d1918d3f2998a07104967b0c367213af6e9` |

Windows uses MSVC 14.51.36231; Linux uses Ubuntu clang 19.1.1. The unchanged pins
are godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. The test host is Godot 4.7.1.
Build commands, exits, compiler/product hashes and source identities are retained
in each `build-debug-candidate13` and `products-candidate13/debug` directory.

Earlier inputs passed Windows core 80 cases and six Windows/Linux ENet actors,
but expanded fixtures subsequently failed. Preserve those attempts as failures:

- Multi-string dictionary encoding incorrectly returned an empty string to key
  validation. The latest writer correction compiled but has not run. Earlier
  broad diagnostics did not prove a payload-size failure.
- The queued-Wait cancellation fixture polled too early. It now flushes without
  receiving, then uses one production poll. This corrected fixture is unrun.
- Concurrent Windows reconnect exposed the retained GL-017 boundary; the fixture
  now coordinates reconnects as the existing harness does. No deadline was raised.
- Canonical property lookup, legacy identity and Lua-only API fixture assumptions
  were corrected with the original failures retained in the history.

Final active-service routing, constructor provenance, reference materialization,
startup atomicity and expanded adversarial cases require fresh runtime evidence.
A successful build or earlier narrower pass does not establish their acceptance.

## Durable evidence and cleanup

All local builds/tests ran on **DockerPC**, not the controlling PC or LinuxBox.
Windows evidence and source archives: `E:/Codex/GL029` on DockerPC.
Linux working evidence: `/work/gl029` in the existing
`codex-character-qualification-linux-v1` Docker volume. A full Linux checkpoint
is copied to DockerPC's `E:/Codex/GL029/linux-checkpoint-20261102.tar.gz` before
stopping the task-started `codex-character-linux` container. Archive SHA-256:
`cf88e922401bc881cb8730d28b19014adea1ac8418f3eac1b5a7d95e2e6b7997`.
The copy completed and the container is stopped; unrelated `drycreek-bot` and
`directus-db` remain running. Preserve the archive,
volume, build caches and failed reports; do not remove unrelated containers.

The latest build workers completed and no fixture processes were running at
cleanup inspection. The container has only its idle bounded keeper before stop.
DockerPC C: had about 5 GB free at cleanup: Docker's backing disk lives there,
even though E: and the volume report much more space. Recheck backing capacity
before any build. No new dependencies were installed for this phase.

## Smallest restart steps

1. Verify remote branch/main SHAs and clean checkout, read `AGENTS.md` and active
   file claims. Verify source fingerprint/product hashes; never reuse products
   after changing native inputs. Confirm DockerPC capacity and existing tools.
2. On DockerPC, run focused `candidate13` Windows and Linux ENet fixtures first.
   Resolve any remaining dictionary/reference, queued-cancellation or service
   lifetime failure before launching an expensive matrix. Do not weaken checks.
3. Review and qualify the new frame codec and RPC compatibility boundary, actual
   sender/session/generation validation, malformed and oversized inputs, no-side-
   effect rejection, local/listen-host dispatch, replaced endpoints, reconnect,
   failed startup preservation, ObjectID lifetime and callback teardown.
4. Run Windows/Linux Debug/Release core and full native regression groups with
   the strict checker requiring exactly 80/116 and all six Remote actor records.
   Run release-candidate rejection tests because their required inventory changed.
5. Run appropriate core ASan and supported native sanitizer profiles. Preserve
   GL-017/018 gaps: no new sanitizer result exists for this branch, and the
   separate GL-018 development branch is not included. Do not suppress findings.
6. Inspect hosted core/native CI, download artifacts and verify source/harness/
   binary identities and actual Remote fixture execution. Pending/skipped jobs
   are not passes. Update the existing qualification record and issue status.

Existing ignored task drivers are copied on DockerPC at
`C:/Sandbox/Codex/GL029Worker.py` and `C:/Sandbox/Codex/GL029Linux.py`;
Linux also has `/work/gl029/GL029Linux.py`. They are convenience checkpoint
drivers, not qualified repository infrastructure. Review before reuse.
Example focused resume commands on DockerPC (source snapshots are immutable):

```text
C:/Sandbox/Codex/Tools/python-3.12.6-controlled-v1/python.exe C:/Sandbox/Codex/GL029Worker.py remote --attempt candidate13 --mode debug
docker start codex-character-linux
docker exec codex-character-linux python3 /work/gl029/GL029Linux.py remote --attempt candidate13 --mode debug
```

Windows caches remain at `C:/Sandbox/Codex/Builds/GodotLuau/runtime-msvc-debug`,
Linux at `/work/build-debug`; both last configured against candidate13. The
repository's `RunQualification.py --remote` is the authoritative fixture path.
Task drivers create fresh action directories and intentionally reject overwriting
existing attempts; use a new attempt/snapshot when rerunning a completed action.

## Limits and next decision

No Release matrix, final full native suite, final core run, sanitizer matrix,
performance comparison or hosted artifact verification is claimed. Phase 2
sequencing/supersession, native ENet retention/ACK accounting, complete-packet MTU
profiles and fairness remain separate proof gates. Graphical/device scope and
GL-003/004/005/007/009/019/020/022/023 contracts must remain intact. Keep GL-030
separate. Resume focused Phase 1 qualification; this checkpoint is not approval
to integrate or ship.
