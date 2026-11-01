# GL-010/011 release-candidate qualification

Starting main: `34ab42ee4e160a6d8ba85bded00bd9dce1c1cd93`.
Development branch: `ci/gl-010-011-release-qualification`. Main remains unchanged.
**PARTIALLY QUALIFIED overall; the bounded non-publishing candidate profiles are
qualified.** Qualified implementation:
`ca8cefbafbe6012e6ae0699ae433b7d5355edfa6`. Production publication/updater admission
and the remaining qualification boundaries below are not enabled or closed.

## Baseline and bounded correction

The starting disabled release workflow source-builds Linux only, uploads `.so`
files without the GL-009 companion, and extracts Windows binaries from the
committed `GodotLuau.zip`. Source inspection establishes these failure modes;
the dormant publisher is not executed to reproduce them. A successful archive
hash alone cannot establish a common source revision or runtime qualification.

The correction retains SCons as the production build entry point and reuses the
existing CMake test adapter, core/native fixtures and strict checkers. No native
runtime, dependency gitlink, API, wire format or updater behavior changes.
The inherited two release jobs remain literal-false/read-only; their Windows
archive reuse and archive commit/push path are removed. GL-012's existing-tag/
release guard, no asset overwrite, serialized publication and historical
retention remain. A future publication change still requires separate authority
and qualification; this workflow does not establish a production channel.

## Candidate contract, schema 1

The separate `release-candidate.yml` supports manual/reusable dry runs and
bounded development-branch push checks. Every checkout uses the immutable
`github.sha`, recursive pinned dependencies and no persisted credentials.
Only `contents: read` is granted. No tags, GitHub Releases, repository commits,
updater installation or deployment occur. Actions artifacts expire after seven
days; evidence retained for this task is separate from permanent release history.

Four profiles are required: Windows/Linux x86_64, Debug/Release, single precision.
SCons production products and the native persistence companion are built from
the same clean source. Godot/godot-cpp/Luau identities are verified before use.
SCons 4.10.0 is version/hash-pinned to its
[official wheel](https://pypi.org/project/SCons/4.10.0/); existing hosted compiler,
CMake and SDK versions are recorded, not advertised as a hermetic toolchain.
Source tree/revision, 89-file native fingerprint, complete fixture hashes,
dependency revisions, compiler identity, build commands/configurations and
product/evidence hashes are recorded in `profile.json`.

Each profile requires the existing complete 80-case core and 110-actor native
qualification, including lifecycle/multiplayer and GL-003/004/005/007/009/019/
020/022/023 behavior. The native test adapter retains its explicit
`GL_RUNTIME_TESTS` distinction; it is never included in the candidate package.
Production SCons products receive separate actual extracted-package tests.
All fourteen presentation actors and the five performance windows execute;
the hosted profile is headless and does not claim graphical or speed qualification.

Linux core ASan/LSan is a required independent gate, with instrumented compile
commands, binary ASan symbol, environment and complete 80-case output checked.
Policy/rejection tests run on Windows and Linux. A final always-run admission
job rejects any failed, skipped, cancelled, timed-out or missing required job.
Missing/incomplete evidence, mixed revisions, changed pins, product/log hashes,
malformed/unsafe archives and mismatched fixtures also reject admission.

Packaging downloads only same-run profile artifacts, rechecks their hashes and
reruns the unchanged strict core/native validators against retained reports.
Windows log-path separators are normalized for comparison without changing the
checker or log bytes. Inputs are staged from immutable Git archive bytes through
the existing ZIP builder, with only the two selected source-built libraries and
one matching Release companion. Required dependency license notices are included.
The inherited builder's UTF-8 BOM removal applies only to disposable staged text.
No committed ZIP supplies binaries. Extra/missing native payloads are rejected.

Each platform ZIP preserves normal `GodotLuau/bin` names, root descriptor and
assets/scripts/updater-tool layout. Linux companion ZIP mode must be `0755` and
respectful extraction must leave it executable. Both packaged extension
configurations must run the existing public DataStore integration fixture with
that packaged Release companion. The official test host has debug features;
the extracted Release test copy redirects the descriptor's debug selection to
the packaged Release library, leaving archive contents unchanged.

`GodotLuau/release-provenance.json` embeds source, build/gate identities and
explicit limitations. External `candidate.json` records the complete member and
archive digests plus actual startup/log identities, avoiding a self-referential
archive hash. `accepted.json` binds both platforms and all required job outcomes.
These are trusted-workflow integrity records, not signed third-party attestations
or independent proof of byte-for-byte reproducibility.

## Execution and evidence

Local builds/tests are restricted to DockerPC, with MainPC as fallback. Initial
DockerPC source staging and a subsequent read-only retry fail because its reverse
SSH endpoint refuses the connection. MainPC's established route also requires
DockerPC; no other worker is substituted and no infrastructure is changed.
Hosted Actions are explicitly permitted and will supply the source builds,
tests and package startup qualification. Unrun local checks are not called passing.

DockerPC subsequently becomes reachable without infrastructure changes. On
immutable tooling revision `ca8cefbafbe6012e6ae0699ae433b7d5355edfa6`, its isolated
Windows execution passes all 14 candidate rejection tests, 12 retention tests,
five packaging tests and eight applicable process-ownership tests. Six existing
Linux `/proc` cases are not applicable on Windows; the Linux policy job runs
those cases. No required core/native case is omitted by that platform distinction.
All 95 executed source/tool/fixture inputs match that revision's Git blobs after
LF normalization, and the transferred tooling/log archive verifies SHA256
`2a0ab04b82af85db5886e5b375cf1b37c0099408dc936adb73c4b329da1af2e9`.

The initial local metadata collector includes one derived `__pycache__` file
after importing the process helper, so Git-blob verification rejects that extra
entry. The original record is retained. A corrected collection uses the exact
95 source-archive members, retains the original record's hash and passes the
source comparison; no test is rerun or assertion weakened. This is a collection
failure rather than a runtime/test failure.

Qualification commands, revisions, hosted runs, artifacts, failures and outcomes
will be appended after execution. The existing failed CTest truncation and all
Character performance/graphical evidence remain unchanged.

The first hosted attempt at `2360e9ffcfac575574bb5bb7f8ae566bfd431669`,
[run 41272667561](https://github.com/gmoddev/GodotLuau/actions/runs/41272667561),
is rejected before any job executes: YAML treats the colon/space in the pip
`--only-binary=:all:` command as syntax. That command is changed to a block
scalar. This is a preserved workflow parsing failure, not runtime qualification.

At `fa58c436f6d7260c2948f54c384ee4a30062135f`,
[run 41272716651](https://github.com/gmoddev/GodotLuau/actions/runs/41272716651),
Linux rejection/retention checks and the 80-case core ASan/LSan gate pass.
The Windows rejection test fails because Python's Windows ZIP writer normalizes
the fixture's backslash name before the extractor sees it. The test now assigns
the raw `ZipInfo.filename` after construction, keeping the same rejection and
no-output assertions. Profiles/packages are skipped and acceptance fails; no
candidate is accepted. The final job now checks required outcomes before trying
to download missing candidate artifacts, preserving the same fail-closed policy.
Windows also normalizes names while reading ZIP entries, so admission checks
the preserved `orig_filename` as well as the normalized filename. Control/NUL
characters are rejected before extraction. The hostile-path assertions remain.

The intermediate `35a578ee4f78a035a5163ec8e10da6508d5bdb49` run
[41272811593](https://github.com/gmoddev/GodotLuau/actions/runs/41272811593)
retains the Windows original-name failure; profiles remain skipped. At
`fea42f459a40f4e634fba8f48c66f29edcb5a724`,
[41272852559](https://github.com/gmoddev/GodotLuau/actions/runs/41272852559),
both policy jobs and core ASan/LSan pass and all four source builds begin.
That task-owned run is intentionally cancelled after source inspection identifies
a later preflight false positive: SCons object outputs beside Luau sources are
not covered by Luau's own ignore file. This is not presented as a reproduced
runtime failure or completed profile qualification. Clean-input checks now allow
only untracked `.o`/`.os`/`.obj` files corresponding to tracked C++ inputs, including
the explicit profile suffix. Modified tracked files and new source/header inputs
still reject. A focused regression preserves both sides of that boundary; the
same identity check also runs immediately after the production build.

## Remaining boundaries

This gate does not automate Windows core/full-native sanitizers or qualify a
matching instrumented Godot host. GL-017/018, broader GL-020 adversarial animation
security, GL-027 template authoring and GL-015 asset redistribution rights remain
independent. Headless presentation does not establish GPU rendering or physical
input ergonomics. Production-scale performance and arbitrary assets remain
unqualified. No release/updater admission or byte reproducibility claim is added.
Hosted Windows qualification has the installed MSVC runtimes available; pristine
consumer machines are not qualified here. Linux candidates target the existing
Ubuntu 24.04 CI profile, not a demonstrated older-glibc compatibility floor.
Compiler/SDK image availability is not a hermetic toolchain guarantee. The
legacy manual `tools/release.ps1` is not invoked or admitted by this pipeline;
future publication must use separately authorized, verified candidate inputs.
Existing Character allocation-event profiling and sanitizer limitations remain
in their retained qualification records.

## Completed hosted qualification

[Run 41273217042](https://github.com/gmoddev/GodotLuau/actions/runs/41273217042)
passes all ten jobs at the exact qualified implementation revision above:

| Required profile | Production SCons extension + companion | Existing core | Existing native |
| --- | --- | --- | --- |
| Windows Debug | Built from source | 80 PASS | 110 PASS |
| Windows Release | Built from source | 80 PASS | 110 PASS |
| Linux Debug | Built from source | 80 PASS | 110 PASS |
| Linux Release | Built from source | 80 PASS | 110 PASS |

Both platform policy jobs pass all 14 candidate tests, 12 retention tests and
five packaging tests. The process suite executes all 14 Linux cases and eight
applicable Windows cases. The independent Linux Clang 18.1.3 ASan/LSan job
passes 80 cases; its downloaded record verifies two instrumented translation
units, `__asan_init` and `detect_leaks=1:halt_on_error=1`.

Each native profile runs lifecycle 8, network 10, animation 10, Character 20,
resources 8, filesystem 3, HTTP 4, HttpService 6, caller migration 3,
presentation 14, performance 1 and persistence 23 actors. The strict unchanged
checkers are rerun against all four reports during both package jobs. Source,
all 63 runtime-fixture hashes, both dependency pins and actual product/log
hashes match. No full native suite is claimed against the SCons production
library: the existing CMake adapter is explicitly identified, while the actual
SCons libraries receive extracted-package startup and separate graphical checks.

Both platform package jobs pass actual Debug/Release public DataStore startup,
including the yielding transform, large payload, frame progress and close-write
checks with the single packaged Release companion. Linux ZIP executable mode
`0755` is checked before and after extraction. Both packages contain 133 members,
including the source layout, dependency notices and embedded provenance.

| Package | Bytes | SHA256 |
| --- | --- | --- |
| `GodotLuau-Windows.zip` | 8,055,437 | `e2e1ca74ed5af0ccb6748d43d760867258788cf2270f8c8af471875179f9c0bd` |
| `GodotLuau-Linux.zip` | 10,849,126 | `5096ef1cb8609535f00577120fe088b80b724dcaceb0d8d73e3c014bfedc3681` |

All eight Actions ZIPs are downloaded and verified against GitHub's artifact
digests. Read-only inspection also verifies every declared profile product,
native log, candidate member and startup-log hash, the 80 distinct core markers
per profile, 110 zero-exit actors per profile and final accepted source identity.
An initial observer reads raw XML with a line regex and reports incomplete
markers; parsing the actual JUnit `system-out` fixes that observer and verifies
all 80. The hosted strict checker already parsed XML and was not changed.

The accepted artifact is explicitly `ACCEPTED_NONPUBLISHING_CANDIDATE`.
No GitHub Release, source tag, repository archive commit, updater installation
or deployment occurs. All raw reports, source-built profiles, packages, accepted
manifest and earlier failed/cancelled artifacts are retained under
`C:/Users/aiden/.codex/artifacts/godotluau/release-qualification/`.

## Fresh actual rendered package qualification

DockerPC runs the existing graphical fixture on the actual extracted Windows
candidate DLLs using cached official Godot 4.7.1, the packaged rig/shader assets
and the packaged Release companion. Both Debug and Release pass **14 real
NVIDIA/OpenGL actors, 454 assertions and 48 hashed PNG captures each** on the
GTX 1650 SUPER. Source fixture and asset hashes match embedded candidate inputs.
Local/default R6/custom rigs, listen/dedicated peers, camera/input simulation,
movement/body synchronization, animation, death and respawn execute. All six
first-person fade uniforms finish exactly at 1. Fresh R6 third-person and custom
first-person captures are visually inspected separately from numeric assertions.

The actual packaged Debug DLL SHA256 is
`6a6a818f693c3ace0eff260f031055125525f38e39c4de8ac868b9fc63385e65`;
Release is `9324792e571d0c58021316e309708b1b3bfdc2c4feed1b72d8c3969c2c547b49`.
The complete 96-capture/rendering collection, including original candidate ZIP
and helper/diagnostic records, is `graphical-packages-ca8cefb.zip`, SHA256
`2007ad8310133181f22781e15f114fbb30cc8ed447b900f67fa907a414d1cf46`.
No Linux GPU, Vulkan, other GPU or physical-device ergonomics qualification is
inferred. Hosted presentation remains explicitly headless. No new performance
comparison or general FPS/reproducibility claim is made.

## Integration readiness and closure boundaries

Ready for review/integration of this **candidate-only** pipeline within the
documented profiles. No merge is performed. GL-010's inherited Windows ZIP reuse
is corrected and candidate source/build provenance is exercised, but this does
not retroactively establish historical binary provenance or qualify an enabled
production publishing channel. GL-011's candidate admission is now enforced and
rejects failed/skipped jobs, with the stated sanitizer and platform limits.
Production release enforcement remains dormant and must not be enabled merely
by changing a job condition. Any future publishing path must consume verified
immutable candidate inputs and retain GL-012's fail-closed new-tag/release guard
and no-overwrite/history policy.

The evidence publication follow-up changes documentation/evidence only.
Packages and CI results claim the exact qualified implementation revision,
not a build of the later documentation-only commit. Native runtime, fixtures,
dependency pins, updater admission and qualified Character/HTTP contracts remain
unchanged from starting main.

The [machine-readable evidence](evidence/release-candidate-2026-11-01.json)
records all ten job identities, eight artifact IDs/digests, every production
and adapter product hash, configuration/compiler details, actual package and
startup identities, graphical capture hashes, local tooling inputs and preserved
failed/cancelled attempts. The graphical archive transfer digest is independently
verified on the controlling PC; no builds or runtime tests execute there.
