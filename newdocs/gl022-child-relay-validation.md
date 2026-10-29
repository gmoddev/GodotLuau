# GL-013 integration and GL-022 child relay work record

## Stage 1: GL-013 script-bootstrap integration (2026-10-29)

Verified clean local checkout and refreshed origin. Remote main is
`ce5e19fa8aea1cf65da875d07cda13c1696fc08c`; qualified source branch
`refactor/gl-013-script-bootstrap` remains at
`9171199fc6b3b43a2aa07a98f3f20977abc43533`. Local main was behind and advanced
by fast-forward before integration. One worktree, no active file claims or
unrelated changes. Pinned dependencies are unchanged.

Normal merge `109bd6d838410509da9831b1502dfffb023ad823` preserves implementation
`50f1c0e4b7f569bbacf3163651dcf16fa0e9a8f4` and its documentation/evidence
follow-up. No conflicts. Its complete tree equals the qualified branch; the
evidence follow-up changes no runtime, fixture, build, workflow or dependency
input. The existing core/native hosted runs on implementation `50f1c0e` both
report success. Their original qualification scope remains unchanged.

Source review confirms bootstrap/RemoteFunction/child receiver ownership in
`luau_script.cpp`, the existing wrap_node delegation, unchanged ObjectID/metatable
representation, and declaration-only methods in the script header. CMake/SCons
retain discovery of all eight implementation units. Host/registration explicit
includes preserve initialization order. No new mutable store or duplicate
bootstrap is introduced; template-cache ownership remains in its existing header.

Release workflow is manual-only with both jobs disabled; updater runtime paths
remain blocked by fork policy. Core/native CI remain enabled. Hosted integration
verification completed successfully below. GL-022's known baseline
reproduction remains open and predates this extraction.

Fresh focused worker checks pass Windows/Linux Debug and Release core39 and
actual adapter builds (two jobs, warm dependency caches). Each platform's Debug
native lifecycle/startup group passes eight actors with `--teardown
--coordinated-close --timeout 60`, preserving the expanded bootstrap assertions.
The original four-configuration core39/native28 qualification and successful
hosted implementation runs are reused within their original scope; no extra
stress or sanitizer qualification is claimed for this unchanged extraction.
All 106 tracked source/build/runtime-test inputs match both worker mirrors after
synchronization. Native fingerprint remains
`31175d5b7c336134577b5ba78b8b6e8475d9bfdd55cd1f7e8545e40680ef335e` (74 files).
Private orchestration/logs are under worker `Builds/GodotLuau/gl022/stage1`
and `/work/builds/gl022/stage1`; no worker tools or settings changed.

Main push/readback revision: `84f42297cf90847ff0d66d805136ad4047e22d21`.
Fresh hosted [core 40822047619](https://github.com/gmoddev/GodotLuau/actions/runs/40822047619)
and [native 40822047626](https://github.com/gmoddev/GodotLuau/actions/runs/40822047626)
both complete successfully on that exact SHA. Core jobs `123276512512` and
`123276512733` each log 39 PASS markers and 39 passed / zero failed. Native
jobs `123276512354` and `123276512688` each log passing 8 lifecycle, 10 network,
10 functional animation actors and the 28-process admission check. Observed
within a 25-minute bound; native completed at 05:31:30 UTC after creation at
05:12:32 UTC. Pending snapshots were never reported as passing.

Stage 1: **INTEGRATED AND VERIFIED**, within the original qualification limits.
This evidence follow-up is documentation only; the main publication tip is its
Git commit immediately following `84f4229`. No further extraction, release,
updater change or GL-022 correction is included in Stage 1. Stage 2 starts from
that verified main, not from the historical extraction branch.

## Stage 2: baseline and mechanism (2026-10-29)

Development branch `fix/gl-022-cross-domain-child-relay` starts at verified
post-integration main `67b88c4202a5c6b9eee46cc7dd5faa4c3fcc1e01`.
Before production edits, the extended existing Integration fixture reproduces
GL-022 against the unchanged Windows/Linux Debug libraries. One native
ModuleScript is required twice within each independent domain. Both callers
retire before adding GL022First. Server count is one; Client count is zero.
Each log shows one native child_entered_tree connection to that ModuleScript,
bound reference 268435466, and is_connected with unrelated ref -12345 is true.
The per-domain labels and independent module tables remain distinct. _GL_VM_ID
returns a new diagnostic number per call, not a stable VM address; its captured
3/4 values are supplementary markers, not the domain-isolation proof.

The actual matching Godot source confirms the mechanism: Object::connect,
is_connected and disconnect index signal slots by get_base_comparator;
CallableCustomBind::get_base_comparator delegates to the unbound callable.
Different bind(ref) arguments therefore do not distinguish the common native
ModuleScript + _gl_child_event pair. The registration guard silently skips the
second logical subscription. Its disconnect lookup can also select the first.
GLReference uses one process-wide, non-recycled counter and owner mapping;
numeric VM registry collision and requiring-caller retirement are not the cause.
No module-cache or authority failure is inferred.

Failing stdout/stderr and the original fixture copy are preserved in each
worker's gl022/baseline-shared-target output. The runner exits nonzero, retaining
the failure. Distinct-target bootstrap relays still pass beforehand.

Correction boundary: give each child subscription a genuinely distinct native
Callable identity, using the existing immutable callback reference and native
receiver ObjectID. Retain the existing reference-to-owner/VM dispatch. Track
native connections in the scene's existing domain host so owner invalidation,
explicit disconnect and scene shutdown disconnect only that subscription and
release its reference. No competing VM/scheduler or global subscription registry.

### Implementation and focused checks

Both first corrected Linux Debug runs pass all eight lifecycle actors. Expanded
coverage passes shared-target/multiple subscription, caller retirement, independent
disconnect, self/peer disconnect during dispatch, reentrant/yielded callbacks,
module invalidation/deletion, script disable/re-enable/reload, ChildRemoved,
dead native target handles and repeated scene generations with a surviving emitter.
No production compile/fixture failure occurred in these two candidate runs.

GLChildCallable stores receiver ObjectID plus immutable public reference; base
comparison includes that identity. Dispatch resolves the live receiver and owner,
then uses existing _gl_child_event/GLResume. Host records hold weak target IDs,
Callables, references and comparison-only anchor identities. Owner invalidation
disconnects entries before registry release. Explicit disconnect erases its entry
before native disconnection; dead targets are reaped before the next host tick.
The native Callable retains no VM pointer. Signal handles resolve ObjectIDs.
The receiver rejects closing domains before creating work; existing scheduler
roots protect reentrant/cancelled work. No cache/hot-path semantics change.

ChildAdded/ChildRemoved retain Connect/connect and Disconnect/disconnect;
Connected reflects live reference ownership. These signals had no Once/Wait
methods in the baseline; service Once/Wait/cancellation fixtures retain their
separate contracts. No unrelated signal or inert lowercase-alias fix is added.

Only the CMake qualification adapter defines GL_RUNTIME_TESTS and binds
_gl_test_reset_domain. The fixture calls it outside Lua after retiring all
executable callers, destroys Server, checks Client still receives, and creates
a fresh Server VM without stale delivery. Shipping SCons builds do not expose
partial teardown. Existing native CI runs the expanded Integration process;
CheckNativeCI now requires child-relay, independent-domain and scene-generation
PASS markers. No separate workflow or process group is introduced.

At implementation publication, full platform/sanitizer/hosted checks were pending.
Completed results follow below. The branch must not be merged automatically; GL-017/018,
GL-020 adversarial evidence and other open issues retain their separate scope.

### Final local qualification

Implementation `1469da696565ef7ed77ee0b5f3adb800500e4d0a` is published only
to the development branch. Fixture follow-up
`0cdaed65f0a9592c7a19302d837e5a0e68db5c58` adds scene shutdown inside active
child dispatch: shutdown cancels the other VM's pending delivery, disconnects
the external emitter, and never resumes the retired yielding callback. It changes
no production/build input. The earlier branch native CI run `40825013772` was
cancelled by this task as superseded, not counted as passing or a product failure.
Fresh hosted core/native runs on the final fixture revision pass as recorded below.

Final local results:

| Configuration | Core | Native lifecycle / network / functional animation |
| --- | --- | --- |
| Windows Debug | 39/39 | 8 + 10 + 10 pass |
| Windows Release | 39/39 | 8 + 10 + 10 pass |
| Linux Debug | 39/39 | 8 + 10 + 10 pass |
| Linux Release | 39/39 | 8 + 10 + 10 pass |
| Windows core ASan | 39/39 | Full-native host remains GL-018 |
| Linux full-native ASan/LSan | 39/39 | 8 + 10 + 10 pass, detect_leaks=1 |

The final lifecycle fixture was rerun in all five native configurations after
the dispatch-shutdown addition. Unchanged network/animation groups retain their
earlier same-implementation evidence. Every group's relevant executed fixture
matches final source. Final local count is 112 normal native actors plus 28
Linux sanitizer actors; earlier iterations are retained but not added to it.
No ASan/LSan report files were produced. Both worker native fingerprints match
the checkout, all 74 normalized inputs:
`6b68311d1dac1af0d3e84049620a7138f5518bb2aba980dc5633a08d4efc218d`.
All 22 runtime harness hashes match. Windows pinned revisions and Linux vendor
archive hashes match prior qualification. There are no dependency changes.

The archived engine signal implementation was checked byte-for-byte against
immutable Godot commit `a13da4feb8d8aefc283c3763d33a2f170a18d541`:
[Object signal keys](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/object/object.cpp#L1557)
and [bound base comparator](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/variant/callable_bind.cpp#L90).
The mirror has no Git metadata; these checked files establish the traced
mechanism, while the existing qualified sanitizer host retains its original scope.

Expected ServerStorage denials and GL-006/008 rejected-RPC diagnostics remain
visible. No zero-channel diagnostics occurred in these ordered-close groups;
GL-017's independently failing reproduction remains unchanged. The minimal
sanitizer host emits dummy-physics warnings and FreeType/font-cache errors during
functional fixtures. Logs preserve them; this qualifies callback/memory and
exercised animation logic, not fonts, rendering or physics. No diagnostics were
suppressed and no GL-020 adversarial animation case was executed.

Build commands use existing caches, two jobs, `ExecutionDomainTests` and
`GodotLuauAdapter`, followed by verbose CTest with a 30-second deadline. Native
groups use existing `RunQualification.py --teardown --coordinated-close`,
`--security`, and `--animation` with 60-second actor bounds; full Linux sanitizer
uses the existing matching instrumented engine, 90 seconds and
`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=<task-output>/asan-report`.
Actual commands, snapshots and logs stay under worker gl022 task roots. No new
shipping SCons/package qualification is claimed; the partial-domain fixture
requires the CMake qualification adapter described above.

### Hosted verification and disposition

**FIXED AND QUALIFIED on the development branch; not merged to main.**
Fresh [core 40825275734](https://github.com/gmoddev/GodotLuau/actions/runs/40825275734)
and [native 40825275692](https://github.com/gmoddev/GodotLuau/actions/runs/40825275692)
pass on final input revision `0cdaed65f0a9592c7a19302d837e5a0e68db5c58`.
Both core logs contain 39 distinct PASS cases and zero failures. Native jobs
`123286770282` (Linux) and `123286770541` (Windows) each build the real Debug
adapter and pass eight lifecycle, ten network and ten functional animation
actors, including the strengthened admission check. Native completed at
06:05:09 UTC after creation at 05:46:02 UTC, within the 25-minute observation bound.

Both downloaded diagnostic ZIP digests match GitHub's metadata. Their summaries
match revision, native fingerprint, all 22 harness hashes and all 28 zero exits.
Both actual Integration stdout files contain GL-022 PASS, independent-domain
destruction/replacement, dispatch-shutdown PASS and scene-generation PASS markers.
The new case is executed by existing native CI. Artifacts contain diagnostics
only. The [manifest](evidence/gl022-child-relay-2026-10-29.json) retains digests,
source/fixture/library identities, baseline observations, results and limits.

GL-022 is resolved for the exercised child relay/ownership scope on this branch.
Main stays at Stage 1 revision `67b88c4202a5c6b9eee46cc7dd5faa4c3fcc1e01` and
retains the baseline defect until separately authorized integration. The final
evidence commit changes documentation/data only; production/build/fixture inputs
remain identical to the qualified revisions. No force push, main merge,
upstream write, release or binary publication occurs.

The task-owned Linux container is stopped after confirming no active build/test
process remained; unrelated services stay healthy. Windows processes are finished.
Source/caches/binaries/failing baseline and final logs remain under each worker's
gl022 roots; local receipts are ignored under `.runtime-tests/gl022`. GL-013 stays
open after its fifth integration. GL-017/018, GL-020 adversarial qualification,
GL-021 and unrelated capability/input/persistence/provenance/distribution issues
remain unchanged. No further extraction or development task is started.
