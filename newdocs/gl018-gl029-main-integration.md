# GL-018 / GL-029 main integration

Date: 2026-11-03. Status: authorized source merge created; publication and fresh
main verification pending at this preparation checkpoint. Branch qualification
is retained separately and is not presented as fresh main CI.

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

Fresh verification must target the integrated main checkpoint, with:

- Windows/Linux strict core discovery and all 81 distinct cases.
- Windows/Linux ordinary native: all 116 actors and both native host fixtures.
- Matching-host Windows ASan / Linux ASan-LSan, including detection controls,
  reload/lifetime checks, all required actors and no unexpected reports.
- All four source-built Debug/Release profiles, exact products and both extracted
  companion packages, followed by non-publishing acceptance.
- Independent downloaded evidence checks for source/harness/host identity,
  required outcomes, log/product/member hashes and package startup.

Core/native push workflows apply to main. Full-native push admission currently
names the development branches, so dispatch that existing workflow explicitly
on main. Dispatch the existing non-publishing candidate workflow on main too.
No publication workflow is dispatched or enabled. Do not describe queued or
running checks as passes. Preserve failed attempts and investigate before retry.

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
