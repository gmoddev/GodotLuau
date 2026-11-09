# GL-043 — raycast filters and Vector3 impulses

## Preparation — 2026-11-09

Branch `fix/gl-043-raycast-impulses` starts from verified remote main
`eee10f8779a1002c664a81267d9ab96d1dae1e62` in an isolated worktree. The shared
feature checkout and existing worktrees are preserved. Main's core/native and
package integration evidence is retained; no release, updater, dependency or
admitted-host change is authorized.

Source in `src/core/luau_api.h` reads MaxDistance but ignores both raycast filter
fields. The two impulse closures read only X/Y/Z tables, so native Vector3
arguments become zero impulses. They also retain raw Part pointers. The bounded
fix will reuse existing typed Vector3 and ObjectID helpers in these bindings;
there is no header extraction, solver change or math-binding refactor.

Acceptance: Include/Exclude roots cover the root and descendants, empty filters
have explicit semantics, nearest eligible hits retain original distance/normal
and unfiltered distance behavior. Native Vector3 and legacy numeric component
tables produce actual linear/angular velocity changes. Invalid/nonfinite values
must fail before mutation, destroyed references remain safe, and existing native
authority checks stay in place. Filter work must have finite explicit limits.
Other RaycastParams options and historical normalized-direction behavior are
outside this issue.

DockerPC's worker-heavy slot is held by another campaign. No build is started
there and no workload is disturbed. Existing GitHub Actions core/native,
candidate and sanitizer workflows provide Windows/Linux qualification. A short
headless baseline probe may reuse existing qualified binaries on MainPC without
compilation, visible windows or foreground crash UI.

The focused physics cases are added to the existing native Model fixture, so
the established ordinary/candidate/sanitizer runners execute the real production
bindings without another qualification framework. Baseline reproduction and
implementation results remain pending at this checkpoint.

## Controlled baseline and correction

The isolated MainPC headless probe returns exit 1 with empty
stderr. Against the unchanged main native fingerprint it reproduces seven failed
assertions: Exclude, Include, eligible-hit distance/normal, empty Include,
duplicate exclusions, native linear impulse and native angular impulse. The
unfiltered/default Exclude/distance checks and legacy table impulses pass.
Both native Vector3 impulse velocities remain exactly zero. This is reproduced
binding behavior, not a reproduced crash. Logs and identity are retained under
`gl043-20261109/baseline` in the local artifact root.

The correction stays in one production header. It uses the existing typed value
reader and ObjectID capture helpers. Raycasts reject ineligible collision RIDs
and query the same original segment again, preserving nearest-hit ordering,
position, normal and distance. Work is bounded to 64 dense filter entries,
128 native queries and 256 ancestry steps per hit. Exhaustion raises an explicit
error after native containers leave scope. No scene-wide traversal, collision
layer mutation or physics solver change is used. Empty Include returns no hit;
empty Exclude preserves ordinary casting. Dead/queued roots do not match.

Finite native Vector3 and explicit numeric X/Y/Z tables are accepted; malformed,
nonfinite and wrong-userdata input is rejected. Plain fields are read without
Lua metamethod callbacks. Existing normalized-direction/MaxDistance behavior,
including the zero-direction fallback, remains. IgnoreWater/RespectCanCollide
and broader Roblox ray semantics are not added by this fix. Qualification is
pending; no issue closure or passing build is claimed yet.

Source review corrects the new Character-specific fixture before qualification:
RBXCharacter::ConfigureVisual deliberately freezes and disables collision on
added rig Parts. Query its existing PhysicsBody at the actual capsule center
instead. The production patch is unchanged. Superseded runs are retained as
cancelled, not passing or product failures; final qualification uses this
corrected test input. An earlier superseded native run at `a784073` was also
cancelled while building after the bounded ancestry lookup was tightened.

Compatibility review also retains anonymous Godot PhysicsServer bodies: an
unfiltered hit can have a nil Instance and must still return position/normal/
distance. Keep a separate hit-present flag and exercise a real anonymous native
body. This is a correction to the new filtering implementation, not a new API
or a change to existing no-hit semantics. Final qualification must use this
complete production/fixture input; earlier superseded runs remain recorded.

## Qualification checkpoint

Production and fixture inputs are frozen at `36ec322`, native fingerprint
`9dcb962297bccdefe173c2a26b78c9d47d322e1fa3a4ccd12b36a4123916e18b`
(101 files). The second baseline uses the corrected fixture with the old native
binary and reproduces eight failures, including Character-body exclusion. Its
anonymous-body and other compatibility checks pass, with empty stderr. Both
baseline logs and original hashes are retained in the
[qualification receipt](evidence/gl043/qualification-2026-11-09.json).

Current core CI `42608023119` passes. Native `42608023128`, four-profile
non-publishing candidate `42608030253`, and matching Windows/Linux full-native
sanitizers `42608033830` are running at that exact source. These are existing
workflows with unchanged assertions, dependencies, hosts and publication policy.
No renderer or engine patch is changed. Do not treat pending runs as qualified.

Linux Debug candidate `42608030253` fails SCons compilation before runtime tests:
Luau's lua_pushcfunction macro treats commas in three local declarations inside
the lambda as argument separators. Split those declarations in place; no runtime
algorithm or test assertion changes. The failed profile artifact and scons.log
remain retained under `gl043-20261109/failed-Linux-Debug-1`. Other jobs using
the same uncompilable header are superseded; this is an actual compile failure,
not a passing candidate or a runtime physics failure.

The corrected source is `3227290`, fingerprint
`7d540a81ecf0bcf83742e94386796df6e4df36310ad330ec1d9bfe54bdac2f56`
(101 files). Core `42610522541` passes. Native `42610522588`, candidate
`42610528726` and full-native sanitizers `42610532744` run against this input.
The failed profile's full log hash is retained in the receipt. Main, dependency
pins, admitted patches, release policy and updater code remain unchanged.

Linux ordinary native CI passes all 141 actors. The Model fixture passes 96
checks, including 20 new physics checks; native Vector3 impulse velocities are
now linear X=3.966778 and angular Y=2.380067, versus zero in the baseline.
Include/Exclude, Character PhysicsBody ancestry, anonymous bodies, legacy input,
finite validation, owner retirement/destruction and explicit work exhaustion all
pass within that fixture. Matching Linux full-native ASan/LSan also passes with
FullQualification=true, detection controls passed and no unexpected reports.
Downloaded source identity matches the corrected 101-file fingerprint. Windows
and the complete candidate matrix remain pending; the issue is not closed yet.

Windows ordinary native now also passes all 141 actors and 96 Model checks,
including the same 20 focused checks and measured impulse velocities. Both
downloaded native summaries identify `3227290` and the same production
fingerprint. Linux Debug candidate qualification passes; full candidate
acceptance and Windows full-native ASan remain pending. No runtime assertion
has failed on the corrected source at this checkpoint.

Full-native `42610532744` finishes successfully on both platforms. The Windows
receipt confirms detection controls, full qualification and zero unexpected
reports at the same native fingerprint. This does not claim Windows LSan support.
Linux Debug and Release candidate profiles pass. Windows candidate profiles and
extracted-package acceptance remain the only pending checks.
