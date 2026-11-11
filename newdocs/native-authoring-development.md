# Luau-first native authoring development

## Baseline and acceptance — 2026-11-11

Isolated branch `feature/luau-native-authoring` starts at verified main
`5d5bb84cfecfff46d7d5048db3171a199fd754be`. Shared original checkout and existing
worktrees are preserved. Native/core main workflows `42764545584` and
`42764545794` have completed successfully; the prior integration document's
pending native observation is historical. Dependency pins and admitted hosts stay
unchanged.

Source inspection confirms Node-only ObjectID wrappers, narrow scalar/value
conversion, and no retained native Resource constructor in `_InstanceNew`.
Relay Siege's geometry/material/lighting/collision/cloth and bot presentation are
still GDScript. Existing UI/Sound wrappers have separate inherited callback gaps;
the new surface will use fixed native families and existing owner-aware dispatch
without rewriting those legacy systems.

Implementation sequence: establish [ADR-014](adr-014-native-scene-authoring.md),
implement typed scope/resource construction and focused actual-native tests,
migrate the arena and presentation, then qualify game and package inputs. Expand
UI/audio only where a complete slice can be tested. Preserve game rules, network
readiness, persistence, native Character physics and controller behavior.

Acceptance requires native property effects and invalid-batch rejection without
mutation, type/size bounds, owner/domain rejection, resource GC and retirement,
destruction/reload and callback edges, then actual migrated game scenarios.
Headless/rendered/package/sanitizer evidence must remain distinct. Unsupported
families and platform/device gaps stay explicit. No main merge is authorized.

## Worker admission

At 06:21 UTC DockerPC's heavy lease is held by `SDKCleanWindows20261111`, with
3.70 GiB disk free. No build is admitted there, no workload is terminated and no
cache/evidence/source is removed. MainPC has approximately 222 GiB free disk.
Use hosted CI for sustained builds while the worker is unavailable; keep local
runtime checks bounded and capture output with crash UI suppressed.

## First implementation milestone

`SceneScope` uses existing ObjectID Node wrappers and separate Ref-backed resource
slots. Batches validate before native setters; fixed families include primitives,
materials, shapes, lights/cameras, native controls/audio and local SoftBody3D.
Loaded/getter resources are immutable, native input is bounded, and owner
invalidation retires subscriptions/resources before queued subtree deletion.
Native and generic network publication paths exclude the subtree. Legacy unbound
Destroy/Clone/ClearAllChildren entrypoints also validate scene ownership.

Read-only independent review caught concrete callback-identity, detached cleanup,
source-deletion, StringName and generic replication/mutation gaps. Corrections
stay within the new boundary; no legacy bridge refactor is bundled. The focused
production fixture is part of the existing Integration actor, not a new framework.

Arena.luau now constructs geometry/materials/light/environment/collision/cloth and
updates bot/relay visuals with shared resources. Presentation.luau constructs the
menu/HUD/results and native audio and consumes existing snapshots/intents.
Game.gd retains transport/session/lifecycle bootstrap and observation handles for
the existing playtest. UI/arena readiness is bounded at five seconds. Native
Character construction can precede deferred arena construction; gameplay starts
after readiness, and actual spawn/physics qualification must exercise this order.

Both new Luau files pass `luau-compile --null`; `git diff --check` passes.
Runtime/platform qualification has not yet run at this milestone.

## Hosted qualification started

Implementation milestone `b8c09bcf18e6dad807a3768e7d01c59c3170936f` is pushed and
remote-verified. Native fingerprint is
`2cbc7deb03c7f898ee1edca14a92e0c6dbb48468d2198bf617cbb445797657fb`
(103 LF-normalized input files). Both dependency pins are unchanged. The
[core run](https://github.com/gmoddev/GodotLuau/actions/runs/42975096443)
passes Windows/Linux Debug; downloaded XMLs independently pass existing
`CheckCoreCI.py report` (85 cases each), and input graph logs pass 29 assertions.
The optional benchmark-host export job was not requested and is skipped.

The [native run](https://github.com/gmoddev/GodotLuau/actions/runs/42975096521)
is building its admitted hosts. No native runtime success is claimed yet.
DockerPC's heavy lease is still held at 06:52 UTC; no worker build is admitted.
Godot 4.7.1 headless `--check-only` passes Game.gd, RelaySiege.gd and
NativeAuthoringCases.gd with empty stderr after correcting fixture type inference.
This syntax observation is distinct from executing native runtime cases.

### First native compile correction

Run `42975096521` fails Linux compilation in the new adapter: the soft-body mesh
getter returns `Ref<Mesh>`, making a conditional with `Ref<ArrayMesh>` ambiguous;
the internal helper `Mesh` also conflicts with the imported Godot class name.
Use explicit checked Ref assignment and rename only that internal helper to
BuildMesh. The public API is unchanged. The Linux job log is retained under
`native-authoring-20261111/failed-b8c09bc/Linux-job.log`; the obsolete Windows
job is canceled instead of continuing inputs known to fail. No runtime pass is
attributed to this attempt. Retry uses these concrete compilation corrections.

### Native execution and physics fixture phasing

At `9bd790f`, Linux compiles and runs the new native cases. The only reported
authoring failure is the impulse velocity assertion: construction called impulse
before Godot's first mass update. The controlled native-only Godot 4.7.1 baseline
(`a13da4feb`, no extension) reproduces velocity `(3.986678,0,0)` for mass 2,
impulse 4 immediately after construction, versus `(1.993339,0,0)` after physics
initialization. This is an engine initialization assumption in the fixture;
it does not justify changing physics or broadening the assertion.

Match the established GL-043 fixture phasing: await native physics initialization,
request the Luau impulse, then observe native velocity after physics frames. Keep
the strict velocity assertion and record the observed value. The public API
documents Godot's initialization rule and keeps direct native impulse behavior.
Other checks execute without reported authoring failures, but the failed actor
does not qualify a complete suite. The native graph workload initially records
64 children, 16048 microseconds including script/bootstrap/load work, and monitor
deltas of 121 Objects/1 Resource; those coarse engine monitors are not allocation
profiles or claims of steady-state memory cost. Raw failed job/output and the
controlled baseline script/log remain in `native-authoring-20261111` artifacts.

## First complete native platform result

At `c9f680746afca627f214a2fa1729986f8b7812ec`, the
[Linux native job](https://github.com/gmoddev/GodotLuau/actions/runs/42979197181/job/130385333282)
passes all 141 required process results. Downloaded summary/source/logs retain
native fingerprint `f9658ea9a6105f754e1e55c355e65b326f89069af60c199c0ae8bcde4b249c9d`
(103 files) and authoring fixture hash
`4d18f636de2f861d014c2e9bbf36c407b506610a8fdc00b34f437a1b260fbf8b`.
The Integration log reports `[Scene:Qualification] PASS` with initialized
rigid-body velocity `(1.996667,0,0)`. Its 64-child construction sample is
16519 microseconds with monitor deltas 121 Objects/1 Resource, with the same
measurement limitations as the earlier sample. Windows native, full-native
sanitizers, four candidate profiles and actual migrated gameplay remain pending.
At this checkpoint, C++ inputs remain those of `9bd790f`.

## Native gates and first rendered gameplay

At `c9f6807`, Windows/Linux native run `42979197181` and full-native sanitizer
run `42979198239` pass. All four downloaded summaries retain the same 103-file
fingerprint and authoring fixture hash, 141 actors and `[Scene:Qualification] PASS`.
Windows ASan retains the established LSan limitation. Construction samples are
42.590 ms Windows Debug, 16.519 ms Linux Debug, 128.844 ms Windows ASan and
71.734 ms Linux ASan/LSan; these include bootstrap/loading and are not isolated
API benchmarks. The coarse monitor reports 121/122 Objects and 1 Resource, not
an allocation profile. Initialized impulse velocity is 1.996667 on all lanes.

Candidate `42979201593` first passes Windows Debug/Linux Release, but Linux Debug
exceeds the existing 250 ms synchronous close-save budget in HTTP lifecycle
(explicit indeterminate outcome), and Windows Release times out on the existing
adversarial replacement-life receipt barrier. Those actors pass the ordinary
native/sanitizer lanes. Attempt 2 retries only the two failed profiles, preserving
the original logs and every assertion/deadline. It is not yet accepted.

The retained source-built SCons products support a private development game,
explicitly marked `DEVELOPMENT_BUILD_UNACCEPTED`; no accepted package is claimed.
With the unchanged admitted MainPC renderer, actual local play passes 27 checks
(victory, defeat, saves, respawn, UI consumption, impulse and pin release), fresh
process recovery passes, and four-player rendered listen play passes. Runtime
stderr is empty for local play. DockerPC admission is Busy with another owner;
only runner files were staged there, with no heavy process started or lease held.

### Corrected native environment enum

Review of the rendered output prompted a pinned-engine constant inspection:
Godot 4.7.1 reports BG_COLOR=1, AMBIENT_SOURCE_COLOR=2, AMBIENT_SOURCE_SKY=3.
The first API mislabeled/admitted 3 as Color. Correct the one schema entry using
the native C++ constants, change the arena input to 2, and assert the actual
native ambient source in the integration actor. This is a confirmed contract
discrepancy, not a reproduced renderer crash. The preceding receipts retain
their original inputs and do not qualify the changed enum/caller. Fresh changed-
source qualification follows; no host, dependency, protocol or solver changes.

The corrected revision is `b6b21a0913f35acff56434eb5ff71daffa2c519f`, native
fingerprint `350392bb4f5613a1722333e3de44f60adb9a4ac4b08ded4430a26a42e9f94b68`
(103 files). Core `42987291392`, native `42987291389`, full-native sanitizers
`42987292678` and candidate `42987296894` are the new cohort. The obsolete
candidate retry at `c9f6807` was canceled to release the serialized candidate
lane for corrected inputs; neither original timing failure is erased or claimed
resolved by that canceled retry. Current-source profile results will be recorded
separately. Prior gameplay includes 27 rendered local checks, successful restart
recovery and rendered four-player listen play, all on its explicitly retained
development inputs. It is not relabeled as corrected-enum qualification.
