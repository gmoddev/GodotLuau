# GL-020 controlled main integration

Integration date: 2026-11-01. **INTEGRATED WITH LIMITATIONS.** Fresh Windows/Linux
core/native CI and downloaded artifact inspection pass. This record is separate from the retained
[branch qualification](animation-authority-qualification.md) and its
[immutable evidence](evidence/gl020-animation-authority-2026-11-01.json).

## Source and merge identity

- Starting local/remote main: `3d1cf07cd44c999450b1e611b1435e64403103c0`.
- Retained source branch: `security/gl-020-animation-qualification` at
  `83e498b7c7ffd203857806488c8c3790439e9560`.
- Qualified runtime/fixture input: `358d6ffc491303e498d512792d09bdb62332bb25`.
- Normal merge: `9f4a4d165abcc5e8b97af65fe7fda1eb191eba8f`.
- Merge/source-tip tree: `4c1bb205171a1a964d30893599db37ba8a23f4b8`.
- Native fingerprint: `c651c1ff730bb2de8c16da996c09d2567e26d45865dfa25118df812d1f51d91f`
  (89 files, LF normalized); 64 runtime fixture inputs.

The merge has the starting main and retained source tip as its two parents. All
four source commits are preserved: tests `edaaa670bdfdfc875e01ad50fafa8d450178481b`
and `ede79e449b27b37e1697be386d86d598660c57ae`, correction
`358d6ffc491303e498d512792d09bdb62332bb25`, evidence
`83e498b7c7ffd203857806488c8c3790439e9560`. No squash, rewrite, conflict resolution
or additional runtime correction occurs. The complete merge tree equals source
tip; the final source evidence commit changes documentation only. Later integration
evidence also preserves qualified runtime, fixture, dependency and workflow inputs.

## Fresh verification

Before publishing, fetch/remote SHA checks confirm the expected main and source
tips, clean checkout and four-commit ancestry. Whole-tree equality, protected-input
diffs and whitespace checks pass. The native correction remains limited to original
Variant validation in the two animation handlers. Normal RPC shapes, protocol 3,
Character/Animator ownership, playback/catalog/life/admission behavior and callback
lifetimes remain unchanged. No GL-017/018 fix is bundled.

Remote main is verified at the merge SHA after push. The unchanged push-triggered
workflows start fresh on that exact revision:

- [Windows/Linux core](https://github.com/gmoddev/GodotLuau/actions/runs/41289952133).
- [Windows/Linux native](https://github.com/gmoddev/GodotLuau/actions/runs/41289952131).

| Fresh hosted Debug profile | Core cases | Native actors | Authority checks | Animation assertions |
| --- | --- | --- | --- | --- |
| Windows | 80/80 | 110/110 | 510/510 | 1,003/1,003 |
| Linux | 80/80 | 110/110 | 510/510 | 1,003/1,003 |

All four jobs finish successfully on the merge revision. The downloaded artifact
ZIP digests match GitHub's recorded hashes. Independent inspection on DockerPC
matches the native fingerprint and all 64 fixture hashes against inputs archived
from the merge commit, archive SHA256
`ea23f85b52434c4e15296a04c04bdf10e43b73d54c7911e65f797c46156e5ced`.
Both native records bind the exact revision, dependency pins, adapter/companion
identities and raw log hashes. Complete core reports contain 80 distinct passes.

Each native profile contains all ten complete animation actor records. Every
required phase and assertion passes, including default and relaxed authority,
malformed input, replay, ownership, life/reconnect, callback and teardown cases.
Actor stdout markers match the embedded records. All 23 client-input and 20
server-input matrices execute in each network mode, with unchanged before/after
cache, playback/resource/loop/speed, health, signal and initializer snapshots.
Positive controls, integer speed, settings/completion, Character replacement and
actual late-join behavior also execute. These are real ENet/production-handler
results; no mocked authorization replaces transport.

The surrounding 110-actor suite also verifies existing Character/GL-007 delayed
transport, lifecycle/security, resource, filesystem, HTTP/JSON/UUID/caller,
headless presentation, performance-execution and persistence regressions. No
graphical or performance-speed claim follows from these checks.

The independent inspection record SHA256 is
`e110752919421294603f754cd8c9bdb8ee5fafa80ae6274776bc44a6802f0052`.
Raw ZIPs and metadata remain under the local artifact directory
`C:/Users/aiden/.codex/artifacts/godotluau/animation-authority/`, with complete
inspection records in `.runtime-tests/AnimationSecurity/`. Exact artifact IDs,
ZIP/product hashes and scope are in the
[integration manifest](evidence/gl020-main-integration-2026-11-01.json).

The original branch evidence archive still matches SHA256
`2c37badc51249298c7287f63970a7cd9d72d832b02f181d6d3978b516272c577`.
No local build or runtime test is relabeled as fresh integration execution. Local
work consists of Git/workflow/documentation checks and artifact inspection.
No task-owned native/verifier process remains on DockerPC; its cached Linux
container remains stopped and no worker service/container is started or changed.
Integration documentation is the only follow-up change after verified merge CI.

## Retained limitations and distribution

Branch Windows/Linux Debug/Release and core sanitizer qualification is retained
by exact input identity, not relabeled as fresh integration execution. Current
hosted workflows provide fresh Debug core/native execution. No fresh Release or
sanitizer run is claimed by this integration.

Linux stock-host native ASan fails before assertions because of RTLD_DEEPBIND;
the original failure and missing optional fontconfig diagnostic remain retained.
Windows full-native ASan remains GL-018's host gap. GL-017's independent engine
disconnect defect remains open. Full native sanitizer qualification, hostile
project/general engine security, graphical/device coverage, allocation profiling,
production transport and broader release portability are not established here.
Authenticated same-life duplicate state remains idempotent; older epoch/life
traffic is rejected without introducing a new sequence protocol.

The inherited publishing workflow still has read-only permissions and disabled
jobs. Updater admission remains fail-closed. No release-candidate dispatch,
release publication, updater installation, dependency change or upstream write
occurs. Only the user's fork main receives the controlled merge and integration
evidence; the development branch and all historical failures remain retained.

GL-020's bounded authority closure criteria are satisfied on integrated main.
The overall qualification remains limited by the native sanitizer boundaries
above. No GL-017/018 closure or broader engine-security certification is claimed.
