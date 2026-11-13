# GL-054 main integration

Status: **INTEGRATED AND VERIFIED WITH RETAINED LIMITATIONS**. Fresh core,
native and declaration CI passes Windows/Linux. The owner separately authorized
this integration on 2026-11-13. The
[integration receipt](evidence/gl054-main-integration-20261113.json) records exact
source, history, workflow and native artifact identities.

## History and identity

Normal merge `a419b93ce0de0470d3ef2522a67f6015610d4827` has parents
`e3d7b53e78dd483e3765d64995e862810d94c6f8` (verified remote main) and
`bb7f505fddf29d74cb99a4575d0d5c68e01dc60a` (qualified feature tip).
All 23 feature commits remain ancestors. There were no conflicts or history
rewrites. The merge tree exactly equals feature tree
`368b314b16d4f59feb164b609ece0968793ce7c7`; integration notes change documentation
only. The original workspaces and the retained feature branch are unchanged.

`git fetch origin main feature/gl-054-engine-production`, ancestry inspection,
`git diff --quiet` for the publication/updater controls and dependency comparison
establish the baseline. `python tests/runtime/SourceFingerprint.py .` returns
128 LF-normalized inputs with SHA256
`ba44f2ac38c33ed616d305434cef2f8beca232bffc0455d7c5159efa50c5e49d`,
identical to the qualified native implementation at
`f1a996b5f6fc9be1e4190d21ecd021ac279a9ab3`. Pins remain godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

## Reused evidence and acceptance

The [qualification record](gl-054-qualification.md), unchanged
[branch receipt](evidence/gl054-qualification.json) and
[development journal](gl-054-engine-development.md) retain implementation,
fixture identities, failed attempts, corrections, package hashes and measurements.
The receipt's unmerged state describes its historical feature checkpoint.
Earlier no-merge instructions describe that campaign's authorization boundary;
the owner's new integration instruction supersedes them.

Existing Windows/Linux full-native sanitizers, four production profiles, accepted
non-publishing packages, Windows rendered editor/game, standalone exports and
Relay Siege multiplayer evidence are reused within their documented scope.
No old package is relabeled as a fresh main product. GL-056/057/058/059/060 fixes
enter main through their original feature commits. No new runtime correction,
dependency, admitted host, controller design or wire format is required for this
conflict-free integration.

Fresh hosted CI must pass on the integrated revision for all three boundaries:

- Runtime core qualification: Windows/Linux existing core regression cases.
- Runtime native qualification: Windows/Linux existing 141 actors, editor and
  authoring cases, full-host physics/navigation and Foundry/restart checks.
- Approved native bindings and Luau declarations: both pinned-frontend platform
  jobs, policy/generation drift and representative positive/negative calls.

The merge and initial documentation are pushed to main at
`9ec63eb9d07bf66380030f2f753f99a55574c8d2`, verified with `git ls-remote`.
The feature ref remains at `bb7f505`. Fresh push-triggered workflows identify
that integrated revision:

| Boundary | Run | Result |
| --- | --- | --- |
| Core | [43414942565](https://github.com/gmoddev/GodotLuau/actions/runs/43414942565) | Windows/Linux pass |
| Native | [43414942556](https://github.com/gmoddev/GodotLuau/actions/runs/43414942556) | Windows/Linux pass |
| Declarations | [43414942468](https://github.com/gmoddev/GodotLuau/actions/runs/43414942468) | Windows/Linux pass |

Both native artifacts record 141 required process results, 44 Foundry checks,
successful durable restart and the exact expected native fingerprint. Existing
editor/index/error-snapshot, authority, lifetime, Character V2, Native/Scripted
controller, networking, asynchronous HTTP, storage interruption/recovery and
full-host physics/navigation checks pass. These fresh native results are headless;
the retained Windows rendered evidence keeps its original identity and scope.
The three workflows pass on their first attempts, with no runtime/fixture changes
or retries required by integration.

Windows native evidence artifact digest is
`feabaf58bec9223f9757a04690c639a35ec9c93d9fa62136801e62b009621e06`;
Linux is `00671ce1a74db2549f889c73f151596f83b01f1820ea5ee92ecb3d6af35bf86d`.
The downloaded summaries identify the tested revision and fingerprint above.
Their SHA256 values and artifact IDs are in the integration receipt.

Closing notes and the receipt change documentation only. `git diff` confirms
that native build inputs equal `f1a996b`, while all runtime/fixture/workflow/package
inputs equal `bb7f505` and tested main `9ec63eb`. The original branch receipt is
unchanged. Existing candidate/sanitizer/export campaigns are reused within their
documented profiles; no redundant rebuild is required for these closing notes.

## Preserved boundaries

Native remains the default Character controller; Scripted remains explicit
opt-in. Character V2 physics, health, animation, networking, owner retirement,
capabilities and bounded execution retain their established authority.

The original Windows programmatic/offscreen scope, untested Linux graphical
presentation, unsupported live debugger/raw native variants, partial selected-API
coverage, standalone-startup scope and reduced sanitizer-host/Windows LSan limits
remain explicit in the qualification record. No stronger claim is introduced.
Release jobs remain disabled with read-only permissions. Runtime updater admission
still returns false. Neither publication nor updater distribution is enabled.
