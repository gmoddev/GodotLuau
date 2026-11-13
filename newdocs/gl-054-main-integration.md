# GL-054 main integration

Status: normally merged locally; fresh integrated core/native/declaration CI
pending. The owner separately authorized this integration on 2026-11-13.

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

CI results, exact tested revision and remote verification will be recorded here
before marking integration complete. There is no reason to repeat unchanged
candidate/sanitizer/export campaigns merely to qualify their established fixtures.

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
