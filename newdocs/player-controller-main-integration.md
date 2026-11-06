# Scripted Character controller integration

Main contains normal merge `2b0f846`; its tree exactly matches qualified source
`d76d689`. Candidate packages and post-merge core/native CI pass. Native is the
default; Scripted remains opt-in. Integration requires no runtime correction.

## Preparation — 2026-11-06

Authorized target is remote main `9ef59d12dbfbd8b1a695e09c993760b5b458a375`.
Qualified source branch `codex/scripted-character-control` is retained at
`d76d6896db5790bc0b99f1b40de12a2663a2c9db`, three commits above that exact base.
It contains implementation `9b1d67e`, fixture correction `0325c3c` and the
documentation-only handoff. Its exact source tree is
`93ab58b36cf01eeaf58b983778e53cec51e8061f`. The local main ref predates the documented history
compaction, so integration uses a separate branch/worktree from verified remote
main rather than resetting that local history.

Native source fingerprint is
`2278df21b72670c189c6206a5a49582a50d4cd835448f3f0708629ae0fd7d52e`
(101 files). Implementation, examples, fixtures and workflow inputs are unchanged
between qualified `0325c3c` and source tip `d76d689`; only documentation changes.
The [retained qualification](evidence/player-controller-qualification-2026-11-06.json)
and [development journal](player-controller-development.md) remain authoritative
for exact configurations and previous failures.

Review of the controller bridge, lease/generation/transport checks, Character
physics and hardware gates, bindings, example lifecycle and regression coverage
finds no demonstrated integration blocker in the qualified paths. Native remains
the constructor default and legacy path. Scripted requires an explicit live
Client selection for the actual local Player.Character. It supplies bounded
one-tick intent to the same native body; health, configuration, prediction,
animation, networking and GL-007 movement admission retain their existing owners.
No runtime correction, dependency or admitted-host change is required by review.

The outstanding controller candidate/package check is dispatched as
[42216970390](https://github.com/gmoddev/GodotLuau/actions/runs/42216970390) at the
exact source tip. Existing rejection/retention and Linux core sanitizer gates
pass; source profiles and extracted packages are pending. Linux Release job
`127889463272` times out in the existing five-minute compiler provisioning step,
before host/extension build or tests. The missing product artifact follows that
early failure. Other profiles continue. GitHub does not permit rerunning this
job while the run is in progress; retry only that failed profile after completion,
without changing source, dependencies, hosts or timeouts. This document
does not treat pending checks as passing or the Input foundation's older package
receipt as controller package qualification.

Attempt 1 subsequently passes both complete Debug profiles. Windows Release
builds successfully but fails one existing animation assertion:
`animation-Dedicated-client2`, replacement life received within five seconds
before the stale-life attack. Its server and client1 pass; this branch changes
neither `AnimationAdversarial.gd` nor NetworkService. This is an observed
convergence failure, not evidence that the stale-life attack was accepted.
The retained Windows Release log SHA256 is
`324dc977b14a3421125bc9a85345ea3bf7565a2ca14a6f51aaddabe91d477eb9`.
After inspecting those diagnostics, `gh run rerun 42216970390 --failed` requests
one bounded retry of the two failed Release profiles and their dependent gates,
preserving the successful Debug, policy and sanitizer jobs. No assertion,
deadline, product source or qualified infrastructure is changed for the retry.

Reuse the qualified Windows/Linux core/native/full-native sanitizer and Windows
rendered evidence within their unchanged-input scope. After candidate acceptance,
merge normally, verify the merge tree against `d76d689`, and allow ordinary
post-merge main CI. As in the preceding Input integration, an identical merge
does not require manually repeating the same sanitizer/rendered/candidate suites.

## Retained limits

Physical keyboard/gamepad/touch, OS mouse capture, Linux graphical behavior,
older-glibc/pristine-consumer portability and broader allocation profiling remain
unqualified. Windows LSan remains unsupported. The mixed local Debug extension /
older Release host shutdown failure remains an unsupported unresolved profile;
matching supported profiles pass. GL-040/041 remain separate Character findings.

## Candidate acceptance and merge

Attempt 2 of [42216970390](https://github.com/gmoddev/GodotLuau/actions/runs/42216970390)
passes all ten gates. All four Windows/Linux Debug/Release source profiles pass
85 core cases and 141 native actors each. Both extracted packages pass Debug
and Release startup using the actual DataStore companion. The unchanged
Windows Release retry passes the previously failed animation observation and
the complete remaining suite. The original failed attempt remains failed;
the passing retry does not establish its exact underlying timing cause.

Downloaded accepted manifest, both ZIPs, all native members, embedded provenance
and startup logs pass the existing `ReleaseCandidate.CheckJobs` and
`CheckPackage` verification. The Linux companion retains mode 0755. Source,
tree, native fingerprint and dependency pins match the identities above.
The [integration receipt](evidence/player-controller-main-integration-2026-11-06.json)
records the package/artifact hashes and retained failed attempts.

Immediately before integration, remote main and the source branch still match
their stated SHAs. Normal merge
`2b0f846864b6eef3273421dd32f1a723fba42461` has parents `9ef59d12` and `d76d689`;
its exact tree is `93ab58b36cf01eeaf58b983778e53cec51e8061f`, equal to the
qualified source tree with no runtime correction. A normal push advances remote
main to that merge. No published commit is rewritten.

Ordinary post-merge [core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42233498213)
and [native CI](https://github.com/gmoddev/GodotLuau/actions/runs/42233498273)
pass at the exact merge SHA. Downloaded core reports confirm 85 distinct
production-core cases and 29 graph assertions on each platform. Downloaded
native summaries confirm 141 actors each, including all seven actual ENet
controller actors with case counts `40 / 16 / 10 / 10 / 15 / 10 / 10` and zero
failed controller assertions. Both summaries have the same 101-file native
fingerprint and 100 harness/example hashes as the accepted source candidate.
The unchanged full-native sanitizer and rendered results are reused; no
additional identical manual run is required.

The documentation follow-up updates this record, its receipt and the current
architecture/ADR/index/journal links only. It changes no runtime, example,
fixture, dependency, host or workflow input, so the verified merge CI remains
applicable within that exact scope. Working trees and remote main are checked
after the normal documentation push.

Release publication and runtime updater distribution remain disabled. Candidate
acceptance and this merge do not authorize distribution.
