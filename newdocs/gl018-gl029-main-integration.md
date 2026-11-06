# GL-018 / GL-029 main integration

Date: 2026-11-03. Status: **INTEGRATED AND VERIFIED within the admitted-host scope.**
All four fresh main workflows pass on their first attempt, and downloaded
artifacts pass independent verification. Branch qualification remains separate
from fresh main evidence in the
[versioned main receipt](evidence/gl018-gl029-main-verification-2026-11-03.json).

## Source and history

Previous remote main: `83cd0887968d73d61d050650718d8ada6e124579`.
Retained integration branch: `integration/gl-018-gl-029-remoteevents` at
`d6afbe683479505e447436365cb45a712400a023` (39 commits ahead, no main-only commits).
Normal merge: `6a7fedf8354cf00a0fc9eb417bcc24d3eeb1b851`, with those two exact
parents. Its tree is identical to the qualified branch:
`2b5260cde48a53e4d7ac05a1b0fa49432e9e34da`.

The local main started at older `4ea5311` and was fast-forwarded to verified
remote main before the normal merge. No squash, rebase, force-push or dependency
update is involved. The checkout was clean and has no other active worktree.
Original GL-018, research, RemoteEvent and subsequent qualified commits remain
ancestors; retained source branch refs are not moved.

Native fingerprint remains
`27822f8ec52e43c440c20dad7f6038d6d70fc8d28332b6665eabb2b8c6d279fa`
(91 LF-normalized inputs). godot-cpp stays at
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`, Luau at
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. The documentation checkpoint after
the merge changes no runtime, fixture, host-policy or workflow input.

## Acceptance and verification

Preflight rechecks the terminal successful branch runs: core `41618226624`,
ordinary native `41618227155`, full-native `41618226865`, and non-publishing
candidate `41620026268`. Their source identities and the versioned
[GL-029 receipt](evidence/gl029-completion-verification-2026-11-03.json) match the
retained branch. GL-018's [scoped closure](gl018-closure.md) and all historical
failures remain retained.

Fresh verification targets the integrated main checkpoint and passes:

- Windows/Linux strict core discovery and all 81 distinct cases.
- Windows/Linux ordinary native: all 116 actors and both native host fixtures.
- Matching-host Windows ASan / Linux ASan-LSan, including detection controls,
  reload/lifetime checks, all required actors and no unexpected reports.
- All four source-built Debug/Release profiles, exact products and both extracted
  companion packages, followed by non-publishing acceptance.
- Independent downloaded evidence checks for source/harness/host identity,
  required outcomes, log/product/member hashes and package startup.

Core/native push workflows apply to main. Full-native push admission names the
development branches, so that existing workflow was explicitly dispatched on
main, as was the existing non-publishing candidate workflow. Future push-trigger
admission remains unchanged. No publication workflow is dispatched or enabled.
All 16 required jobs across these four workflows pass without a retry; no failed,
cancelled, skipped or timed-out required job is treated as success.

Published main verification checkpoint:
`ac119bc72e609577b6024ceae19765f7cd21ba75`. Remote main was verified after push;
the integration branch remains at `d6afbe6`. All four runs target that exact main
checkpoint:

| Workflow | Run | Verified outcome |
| --- | --- | --- |
| Core | [41641774898](https://github.com/gmoddev/GodotLuau/actions/runs/41641774898) | Windows/Linux PASS; downloaded strict discovery/JUnit verifies 81 distinct cases each |
| Ordinary native | [41641774764](https://github.com/gmoddev/GodotLuau/actions/runs/41641774764) | Windows/Linux PASS; 116 actors and two host fixtures each; downloaded evidence verified |
| Full-native sanitizers | [41641774730](https://github.com/gmoddev/GodotLuau/actions/runs/41641774730) | Windows ASan / Linux ASan-LSan PASS; downloaded controls, instrumentation, outcomes and hashes verified |
| Non-publishing candidate | [41641778925](https://github.com/gmoddev/GodotLuau/actions/runs/41641778925) | All ten jobs PASS: policy, Linux core ASan/LSan, four source profiles, both packages and final acceptance; downloaded evidence verified |

Core/native/sanitizer artifact report hashes are retained locally under
`C:/Users/aiden/.codex/artifacts/godotluau/gl018-gl029-main` and summarized in the
versioned receipt.
Ordinary/sanitizer product and compiler identities are reported build identities;
the candidate profiles and packages additionally retain binaries for independent
product rehashing. These are distinct evidence checks.

Fresh ordinary native results include 459 Linux / 461 Windows Remote assertions,
all 80 normalized harness hashes and all 359 Linux / 365 Windows native log
hashes. Both retain 4,000 independently rechecked GUID samples. Each full-native
profile passes 81 core cases, 116 native actors and both host fixtures, with all
24 Linux / 23 Windows sanitizer checks passing and no unexpected reports or
timed-out results. Instrumentation records cover 1,160 native and three probe
translation units. All 562 Linux / 557 Windows available summary-indexed files
rehash; each manifest retains one consumed transient GL-003 mailbox JSON absent
from upload. Sanitizer GUID summaries are verified by the hosted strict checker;
raw GUID text is outside that upload pattern. These retained evidence limits are
unchanged and do not hide a missing required input, result or log.

The unchanged production profile/native verifiers recheck all four downloaded
Windows/Linux Debug/Release profiles: 81 core cases, 116 actors, both host
fixtures, six product/evidence file hashes and 4,000 unique GUID samples each.
All four profiles measure the complete 816-byte-frame RPC at the 256-byte UTF-8
path as 1,066 uncached / 819 cached bytes, one native command, within MTU 1,392 /
unfragmented budget 1,364.

Both packages contain 133 independently verified members, with exact archive,
member, provenance and startup-log hashes. Each runs Debug and Release extension
startup with the packaged Release persistence companion after extraction.
Archive SHA-256:

- Linux: `7e29272d82270ad840988888ce24e4379ab780d7a21750a7082f0e74299108a8`.
- Windows: `a6e6e91579cadd773e576041ada1516e53f138e3e9b75a5aee17aad045ee2110`.

Final acceptance is `ACCEPTED_NONPUBLISHING_CANDIDATE`; its receipt SHA-256 is
`3eb55832e63c91dc9e880650a5d0bab6ce43a8b50b97df1d5cce14f4ac794af9`.
The final documentation/evidence follow-up changes no qualified runtime,
fixture, workflow, host-policy or dependency input. It does not require repeating
the identical source qualification or imply any new performance measurement.

## Compatibility, qualification limits and publication

Main now includes ADR-008/009's three delivery modes, bounded application/native
data ownership and the hash-pinned host adapter. Network startup requires the
admitted host; stock hosts fail closed. GER2 peers must match. The
[API/migration contract](remoteevent-api.md) remains authoritative; no automatic
scene/project migration or patched-engine distribution is performed.

The [branch qualification](remoteevent-completion-qualification.md) retains real
UDP faults and paired 1/16/32-peer Debug ASan performance. Response latency
increases while frame progression improves in that workload. Neither 64-peer
performance nor production Release speed is established. These measurements are
reused branch evidence, not a new integration benchmark.

GL-018 retains its admitted matching-host/headless scope, Windows-LSan and
stock-host/custom/editor/device limitations. Native data caps exclude total RAM,
receive predecode and control/ACK queues. Earlier Character observation failures
passed unchanged replays; no root-cause correction is inferred. GL-017 and GL-030
remain separate. Existing transient-mailbox/raw-GUID retention limits stay visible.

The release workflow is byte-identical to previous main, read-only, and both jobs
remain explicitly disabled. `RuntimeUpdatesAllowed()` still returns false and
the updater file is unchanged. No release, tag or updater channel is created.
