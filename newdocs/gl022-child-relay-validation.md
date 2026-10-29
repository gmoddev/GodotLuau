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
verification is pending. GL-022's known baseline
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
