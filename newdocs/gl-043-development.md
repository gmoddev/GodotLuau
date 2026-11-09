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
