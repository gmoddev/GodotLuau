# GL-018 and GL-029 branch combination

**Current status:** [GL-018 is closed within the admitted matching-host scope](gl018-closure.md)
after exact-source hosted core/native/sanitizer verification. Its fixes and
closure are retained by normal merge `a6bd710`. GL-029 remains open; the
[resumed qualification record](remoteevent-phase1-qualification.md#resumed-after-gl-018-closure)
documents its reproduced failures and small fixture corrections. The original
integration assessment below retains its publication-time conclusions.

Date: 2026-11-02. **Combined development branch; not ready to merge into main.**
This combines existing work at the user's request. It does not complete either
issue's outstanding qualification or authorize release/updater distribution.

## Inputs and merge policy

- Main: `83cd0887968d73d61d050650718d8ada6e124579`.
- GL-018: `0e61db4a418c606deff50fad27f9831dc6204981`.
- Research: `9ea782bb739cc35deba06474a82582a12529df6d`.
- GL-029: `1e5e2f62b6b85f97e29bd03bacf469182fa4467d` (Phase 1 checkpoint).
- Destination: `integration/gl-018-gl-029-remoteevents`.

The sanitizer branch was fetched, checked out with origin tracking and pulled
with `--ff-only`. The integration branch starts at that exact tip and uses normal
non-squash merges for research and implementation, preserving all input commits.
Only README/issue-ledger documentation conflicted; the implementation checkpoint
status wins over the older research-only status, and research documents remain.
The original branches and main are not moved.

## Readiness assessment

**GL-018 remains open.** The GitHub API independently confirms source `92659b`
has successful Windows/Linux core and ordinary native jobs, successful Linux
full-native ASan, and failed Windows full-native ASan. See
[run 41400476522](https://github.com/gmoddev/GodotLuau/actions/runs/41400476522)
and the [retained qualification](native-sanitizer-qualification.md#qualification-outcome-and-remaining-blocker).
The Windows two-writer increment fixture requires all operations to finish,
whereas ADR-005 permits exhaustion of eight optimistic conflict attempts.
Resolve that acceptance/fairness contract with review, then rerun the complete
Windows sanitizer profile. Do not increase retries, relax assertions or rerun
until green as a substitute. The corrected sanitizer host is a derived host;
stock-host unload safety, Windows LSan and historical early-error leak attribution
are not established by the passing Linux profile.

**GL-029 remains WIP.** Its final candidate13 products compiled on both platforms;
the final dictionary writer, queued-Wait polling, service routing and startup
atomicity changes have not run. First run the six actual ENet actors on those
inputs (or matching combined products), resolve failures, then run all 80 core
cases and 116 native actors on Windows/Linux Debug/Release, appropriate sanitizers,
candidate gates and hosted artifact verification. Earlier narrower passes do not
qualify the final source. See the [handoff](remoteevent-phase1-handoff.md) and
[attempt history](remoteevent-phase1-qualification.md). Later sequencing/MTU/
retention/fairness phases and GL-030 remain separate.

## Integration adjustment

The GL-018 runner previously invoked only the original 110 actors, while GL-029's
strict checker requires six additional Remote actors. `RunNativeSanitizers.py`
now executes the existing `--remote` group before strict checking. The sanitizer
workflow admits this integration branch and names the required 116 actors.
This preserves every existing assertion and detection control. It supplies no
new runtime qualification by itself. The ASCII URL-encoding correction and
GL-029's enum installation both survive their automatic source merge.

## Fresh checks

- `python tests/release/ReleaseCandidateTests.py`: 14 pass.
- `python tests/release/ReleaseRetentionTests.py`: 12 pass.
- `python tests/packaging/PackagingTests.py`: 5 pass.
- GL-018 raw evidence archive SHA-256, all 8,895 indexed ZIP entries and all
  12 selected manifest hashes match.
- Merged runner/checker Python syntax, review links and final diff checks pass.
- Dependency pins remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
  and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.

These are integration/tooling checks, not a new native build, runtime matrix or
qualification of the combined source. Hosted results must be assessed against
the combined revision; the source-branch results above do not transfer to it.
Releases and updater admission remain disabled; no tag, release, upstream write
or main merge is performed.

## Published combination

Merge `084d29fac658d27e40811a9854b0a1bddc1d6b58` preserves all three exact
input tips as ancestors, confirmed with `git merge-base --is-ancestor`.
The combined native fingerprint is
`d5c7c67af9f03686bc0235365dcba7dbfe26aa8f6031e10dfdbd3329d1d1ffcf`
(90 inputs, LF normalized). The remote tip was verified after push; main and
source branch tips remain unchanged. Release workflow and updater source have
no difference against main.

Initial hosted observation for this merge (not completed qualification):

- [Core 41440952721](https://github.com/gmoddev/GodotLuau/actions/runs/41440952721): in progress.
- [Native 41440952582](https://github.com/gmoddev/GodotLuau/actions/runs/41440952582): in progress.
- [Sanitizers 41440952693](https://github.com/gmoddev/GodotLuau/actions/runs/41440952693): queued.

These states are a publication-time snapshot and must not be reported as passes.
Use explicit `--repo gmoddev/GodotLuau` or the fork API path for GitHub checks:
this checkout's default GitHub CLI repository resolves to the upstream project.
