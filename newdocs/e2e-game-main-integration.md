# Relay Siege main integration

Main contains normal merge `025401f`, preserving all 12 feature commits and the
exact qualified source tree. Post-merge Windows/Linux core/native CI and the
non-publishing game package check pass. No runtime correction was needed.
Native remains the default controller and Scripted remains an explicit opt-in.

## Preparation and merge — 2026-11-09

The owner authorized a normal merge of qualified
`feature/e2e-gameplay-foundation` into main, preserving history and keeping
release publication and updater distribution disabled.

Immediately before integration, remote main was
`a3c62e9333fbf2a7dd7d095b9f12d9a3d71eba96` and the retained feature tip was
`1ed3ee555f07922f5bb3e18a4126e6bfd74d09e1`. The 12 feature commits descend
from that exact main revision. Both the shared checkout and active file claims
were clean. A separate worktree/branch from remote main preserves the shared
feature checkout and the older local main history.

Normal merge `025401f307c7dc8b47f84c36885158b01c4e402c` has those exact two
parents. Its tree is `a4b2fc4d3e1e33dae4cdb2593e9bbe5d194d9e1f`, equal to
the qualified feature tip. A normal push advances remote main to that merge;
the feature ref remains unchanged. No history is rewritten.

Review finds no demonstrated integration blocker requiring a runtime correction.
Native source, dependency pins, admitted GL-018/029 patches, release policy and
updater code are unchanged. The game composes the existing Character, input,
physics, networking and DataStore contracts; the controller example's optional
result-screen suspension does not change Native as the default or Scripted's
explicit opt-in. The two-line relevance fixture correction preserves the
server-motion, later client-owner grant and forged-state rejection assertions.

## Reused qualification

The [branch receipt](evidence/e2e-game-qualification-2026-11-09.json),
[gameplay qualification](e2e-game-qualification.md) and
[development journal](e2e-game-development.md) retain all prior source identities,
failed attempts and limits. Core/native CI at `78b7f65` passed both platforms,
including 141 required native actors each. Later feature commits only document
that evidence. The unchanged native fingerprint is
`2278df21b72670c189c6206a5a49582a50d4cd835448f3f0708629ae0fd7d52e`
(101 files).

Reuse the actual rendered local, four-player listen/dedicated, restart,
menu/package and matching ASan evidence within those documented scopes. The
exact merge introduces no changed game/fixture input warranting another full
rendered or sanitizer campaign. Native C++ and pinned dependencies also match
the existing accepted controller candidate. No new engine build profile or
dependency change is introduced by integration.

## Fresh integrated checks

Ordinary post-merge core/native CI is expected at the merge SHA. The existing
non-publishing package workflow is dispatched on main as
[42597457773](https://github.com/gmoddev/GodotLuau/actions/runs/42597457773).
It reuses the admitted rendered host and accepted native candidate, stages and
extracts the game, then starts the actual Main scene. It uploads an Actions
artifact only; this is not release or updater admission.

Post-merge [core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42597456749)
passes Windows/Linux Debug. The downloaded reports declare 85 core cases passed,
zero failed, and 29 input-graph assertions per platform. The package check also
passes: its ZIP identifies the merge SHA and starts with empty stderr. All 157
payload members match their manifest hashes and sizes and are identical to the
branch package's payload. Only the enclosing provenance revision changes. The
new ZIP SHA-256 is
`c189ffe29ed9f15cf64d7254cb56aab87b68dfd72306f298a30eb49bcf18e44c`.

[Native CI](https://github.com/gmoddev/GodotLuau/actions/runs/42597456728) also
passes Windows/Linux Debug at the exact merge SHA. Downloaded summaries confirm
141 required actors on each platform, the same 101-file native fingerprint and
all 103 harness/example hashes equal to the qualified branch. No retry or
assertion change was needed. The separate
[integration receipt](evidence/e2e-game-main-integration-2026-11-09.json) records
fresh artifact identities, digests and summary hashes without changing the
historical branch receipt. No required CI check remains outstanding.
Integration documentation commits change no runtime/package inputs.

## Retained limitations

The inherited peer-exit channel diagnostic remains, with its exact cause
unproven in the game profile. Full instrumented victory replays remain failed;
the separately passing ASan lifecycle does not relabel them. Windows LSan,
physical devices/actual OS capture, Linux rendered gameplay, WAN/NAT,
authentication and pristine-machine installation remain outside qualification.
GL-043/044/045, existing GL-017/018 and asset-provenance limits remain open in
their stated scopes. Integration does not broaden their closure.

Both dormant release jobs remain `if: false` with read-only permissions. The
runtime updater still fails closed, and game packages omit its add-on. No
release, tag, admitted patch or updater distribution setting is changed.
