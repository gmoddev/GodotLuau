# GL-020 animation lifecycle qualification

Investigation baseline: `132970c6f7270062952ef872d609844b762058f8`,
2026-10-27. Working branch: `fix/gl-020-animation-lifecycle`.

## Findings recorded before implementation

- `_setup_rpcs` configures both animation directions ANY_PEER. `_relay_anim`
  uses the transport sender without checking Server role or session membership;
  `_recv_anim` trusts `who` except for ignoring the local peer.
- `peer_anim` intentionally remembers updates before puppet creation and supplies
  late joiners. It has no assigned UserId binding. Server disconnect erases it,
  but client `_recv_remove`, server loss and external puppet destruction do not.
- Local `net_anim_state` ignores disconnected playback. No initialization replay
  recovers an animation already playing when session identity arrives.
- Tracks notify on explicit play/stop only. Speed/loop changes and natural
  completion do not update remote state. `gl_anim_apply` adds a new default
  animation library on replacement, potentially colliding with the old library;
  loaded Animation resources share mutable loop configuration.
- AnimationTrack retains a raw AnimationPlayer pointer. Stop/completion dispatch
  callbacks before network notification, permitting owner destruction before
  subsequent native access. Local respawn has no animation reset notification.

These are source traces, not reproduced crashes or adversarial transport proof.
Existing GL-006/008 sender helpers, server-assigned `peer_seq_uid`, ObjectID
resolution and bounded native fixture runner supply the implementation patterns.
No independent session registry or transport redesign is needed.

## Acceptance and scope

Exercise actual AnimationPlayers and cache snapshots through the existing Godot
fixture runner: play/stop, speed/loop changes, replacement, independent players,
pre-puppet delivery, late join, respawn, disconnect/reconnect, invalid roles and
missing sessions, service replacement and scene destruction. Run the unchanged
39-case core and existing multiplayer regressions on Windows/Linux Debug/Release,
Windows core ASan and Linux full-native ASan/LSan. Keep GL-017 diagnostics and
GL-018's Windows full-native host limitation visible. No full security closure
is claimed by this functional task. Final commands/results follow qualification.

## Implemented contracts

The existing Server/Client sender guards and `peer_seq_uid` remain authoritative.
Animation receives are reliable AUTHORITY RPCs; client relays remain reliable
ANY_PEER with Server-role and current transport/sender checks. Both directions
also require this live NetworkService to own the current transport. Targets need
a positive assigned session, not a completed puppet or PlayerObject. Cached
records include the assigned UserId, checked during puppet creation and late join.
Invalid role/session/service, nonfinite or out-of-range speed (0–20), overlong
ID/name (1,024/128 characters) and empty play name return without cache or relay.

Existing names, argument counts/order, wire representations, channel and reliable
delivery remain intact. AUTHORITY filtering is an intentional receive-policy
correction. No new wire message, session registry, VM model or foundational
dependency is introduced. Mixed historical application versions are not qualified.

Puppet exit/removal, session departure, server loss, full disconnect, transport
replacement and service shutdown clear animation state. Puppet exit callbacks
bind the exiting ObjectID so queued old characters cannot erase replacement state.
Local respawn sends the existing stop message while the session is live. Session
initialization replays tracks already playing, recovering preconnection playback.
The local character identity is numeric; no new long-lived raw pointer is stored.
AnimationTrack now resolves its AnimationPlayer ObjectID. Speed/loop changes and
natural completion replicate; callback notification order and copied callback
lists avoid accessing track members after user signal dispatch. Per-character
clip resources prevent loop changes leaking between characters. Default-library
reuse supports replacement; current-clip settings do not restart playback.

`NetworkService.GetAnimationStates()` returns a detached native Dictionary keyed
by transport peer with Id/Name/Speed/Looped/Play/UserId fields. It is a read-only
diagnostic, not an RPC or a second animation-state implementation. Fixtures assert
this actual cache and actual AnimationPlayer clip/speed/loop/playback/position.

## Reproduction and artifact locations

Runtime and final fixture source: `7212b87e71f539a80d8e6b6977510fa075c0a2ba`,
following initial runtime `f9b27c6b6bb3caa3b8b617e029d45c858a546f9a`.
All 65 normalized native inputs have SHA256
`a954a5541435b37246d6010e8384b21a579a420b950b25a64d6db944daad76dd`
on the checkout and both workers. Pinned submodules remain godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4` and Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Both workers began with the
main baseline's normalized native digest
`3f4e64b4477d228e9ed3580d5c054a4cc1f3d6d32abf53de842cf25daf78fd37`.

Reuse the existing worker configurations, four jobs maximum. Windows uses the
existing VS 18/MSVC 14.51.36231 environment, CMake 3.31.10 and portable SCons
4.5.2/Python 3.12.6. Linux uses the existing task-owned Ubuntu 24.04 container
(four CPUs, 10 GiB), GCC 13.3 and SCons 4.5.2. No tool/dependency upgrades or host
package installations were performed. Official normal hosts are Godot 4.7.1 at
`a13da4feb8d8aefc283c3763d33a2f170a18d541`; full-native Linux sanitizer checks
reuse the matching instrumented minimal host from earlier qualification.

```text
cmake --build <existing-runtime-msvc-or-linux-config> --target ExecutionDomainTests GodotLuauAdapter --parallel 4
ctest --test-dir <existing-config> --output-on-failure --timeout 30
python tests/runtime/RunQualification.py --godot <Godot-4.7.1> --extension <candidate-library> --output <new-directory> --animation --timeout 60
python tests/runtime/RunQualification.py --godot <Godot-4.7.1> --extension <candidate-library> --output <new-directory> --teardown --coordinated-close --timeout 60
python tests/runtime/RunQualification.py --godot <Godot-4.7.1> --extension <candidate-library> --output <new-directory> --security --timeout 60
scons platform=<windows-or-linux> target=template_debug -j4
scons platform=<windows-or-linux> target=template_release -j4
```

Windows SCons invokes `RunSConsPortable.py` with the existing controlled SCons
module directory. Windows core ASan builds only `ExecutionDomainTests` and adds
the existing MSVC ASan runtime directory to PATH. Linux ASan/LSan builds both
core and adapter and runs all native groups with
`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=<output>/asan-report`, the
matching instrumented engine, and `--timeout 90`. The runner starts hidden
Windows children after `SetErrorMode(0x8003)` and captures all stdout/stderr.
SCons libraries independently run the ten-process animation group.

Raw build/core/existing fixture records reside under Windows worker
`C:\Sandbox\Codex\Builds\GodotLuau\gl020-final3` and
`C:\Sandbox\Codex\Logs\GodotLuau\gl020-final3-*.log`. Linux equivalents are
`linuxbox:/opt/codex/godotluau/artifacts/gl020-final3`. Each root includes
`{debug,release,asan}-{animation,regression,security}` where applicable, and
`scons-{template_debug,template_release}-animation`.
Task-owned qualification helpers retain the exact subprocess commands in logs.
The checked-in runner/fixtures reproduce the behavior without those helpers.

## Retained failed fixture attempts

Initial Debug qualification passed before callback-deletion and additional
ordering assertions were added (`gl020-qualified`). The next fixture incorrectly
called `free()` on the object emitting a signal. Godot explicitly rejects freeing
a locked/emitting object; Windows/Linux `gl020-final` preserve the failed test
and its diagnostics. The fixture now uses supported queued deletion and checks
the next-frame destruction. No crash or sanitizer finding was reproduced there.

Windows Release then exposed a fixture sequencing race in
`gl020-qualified-final/release-animation/Dedicated`: client 1 could advance to
another clip before client 2 observed the previous phase. Observer acknowledgements
now prevent that ordering. Final animation results use fresh isolated directories;
the runtime binaries are unchanged by this fixture correction. Earlier failures
remain retained and are not counted as passing final qualification.

Final review then found that copied callback dispatch lists no longer pruned
retired records in the stored owner lists. `7212b87` restores pruning before
snapshotting, retaining the deletion-safe static dispatch. Fresh `gl020-final3`
builds and all core/native groups qualify that final source; earlier passing
`gl020-qualified-final`/`gl020-animation-final2` outputs remain historical.

## Qualification boundaries

These fixtures exercise native AnimationPlayers and actual ENet traffic, with
playback/cache assertions and controlled local clips. Skeletal pose rendering,
production content, coordinator deployment and a graphical editor session are
not qualified. Editor coverage uses the existing multiplayer launch flags.
Reconnect uses a real new ENet session and checks a fresh assigned UserId; numeric
transport peer-ID collision is not forced. Cached-state clearing on replacement
and ObjectID-safe callback connections also cover service/scene destruction.

The minimal Linux sanitizer host emits its known dummy-physics and missing
FreeType diagnostics; those remain captured, not suppressed. Its clean sanitizer
exit does not qualify real physics or rendering. GL-017's independent simultaneous
ENet close send/leak remains open; functional final closes are ordered after poll.
GL-018's Windows full-native sanitizer-host limitation remains open; Windows ASan
coverage here is core-only. No updater/release workflow, binary publication or
main merge occurs.

Full GL-020 security acceptance still requires actual two-client forged animation
receive/relay attempts (including relaxed-authority handler probes), invalid
sender/session cases and proof of no animation/cache/relay effects while valid
play/stop continues. Functional unknown-target, sender-zero, role and bounds
checks do not substitute for that work. Existing `--security` results exercise
GL-006/008's previously qualified endpoints, not the animation attack surface.

## Executed results and disposition

**FUNCTIONAL IMPLEMENTATION QUALIFIED — SECURITY QUALIFICATION PENDING.**
All final processes exit zero and satisfy their fixture PASS/assertion gates.

| Platform/configuration | Core cases | Existing native | GL-006/008 native | Animation native | SCons animation |
| --- | --- | --- | --- | --- | --- |
| Windows Debug | 39 | 8 | 10 | 10 | 10 |
| Windows Release | 39 | 8 | 10 | 10 | 10 |
| Windows core ASan | 39 | — | — | — | — |
| Linux Debug | 39 | 8 | 10 | 10 | 10 |
| Linux Release | 39 | 8 | 10 | 10 | 10 |
| Linux full-native ASan/LSan | 39 | 8 | 10 | 10 | — |

That is six core configurations, four successful SCons builds and 180 final native
process results: 90 animation, 40 existing multiplayer/lifetime and 50 existing
GL-006/008 authority/chat. No ASan/LSan report or GL-017 zero-channel diagnostic
appears in these final groups. Other expected diagnostics described above remain
captured. The [evidence manifest](evidence/gl020-animation-qualification-2026-10-27.json)
records exact source/fixture, library, build/core/result/log hashes and worker
locations. Every copied library matches its worker build; both worker native
and changed test inputs match the local checkout. All final3 groups use the
callback-pruning correction and acknowledgement-corrected fixture. Earlier runs
are retained separately and are not counted as fresh final-source qualification.

The diff leaves shared-domain/GL-019 core and host implementations, submodule
pins, SConstruct and updater/release workflow unchanged. The new diagnostic
snapshot is additive and has no wire exposure. Validation is functional source
qualification, not production distribution or full GL-020 closure. Recommend
reviewing this dedicated branch for functional integration while explicitly
retaining the security follow-up; do not represent it as fully security-qualified
or merge it automatically. The requested branch is committed/pushed separately
and `main` remains unchanged; exact ending/remote SHA is verified in the handoff.

## Main integration (2026-10-27)

**INTEGRATED FUNCTIONAL IMPLEMENTATION — SECURITY QUALIFICATION PENDING.**
The owner authorized source integration in a separate follow-up. Main began at
`132970c6f7270062952ef872d609844b762058f8`; the source branch remained
`8e21d18a5504e0d703efbcf2a71a53d56314058e`. Normal two-parent merge
`6b140427e8ab39d97e12ee693f7cbda72abc7bba` preserves all four source commits,
without conflicts. Its entire tree equals the qualified branch. The subsequent
integration-record commit changes documentation only.

Fresh Windows Debug and Linux Release cached-build checks and 39-case core runs
pass. Each platform executes `RunQualification.py --animation --timeout 60` and
`--teardown --coordinated-close --timeout 60`: 36 native process results total,
covering Local/Listen/Dedicated/Editor animation and existing multiplayer/lifetime
regressions. Every process exits zero with PASS; expected ServerStorage diagnostics
remain visible. No GL-017 zero-channel diagnostic is emitted. The tested binaries
match their qualified source-branch SHA256s, and all 65 native inputs plus the
actual animation/network fixture and runner hashes match across checkout/workers.
The initial Windows wrapper failed quoting before executing build/tests; its log
is retained separately from the corrected successful `win2` run.

The previous six core configurations, 180 native results, four SCons builds,
Windows core ASan and Linux full-native ASan/LSan are reused immutable evidence,
not fresh integration executions. No expensive historical stress matrix or
adversarial suite was rerun. Exact commands, log hashes, source identity and fresh
results are in the [integration manifest](evidence/gl020-main-integration-2026-10-27.json).
GL-020 remains OPEN for animation-specific adversarial transport/handler testing;
GL-007/GL-017/GL-018 and all prior qualification boundaries remain independent.

The merge and integration-record commits use `[skip ci]` so this authorized push
does not invoke the inherited main-push publishing/deletion workflow. This follows
[GitHub's documented push skip instruction](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).
No workflow was dispatched, binary published or remote release/tag changed.
