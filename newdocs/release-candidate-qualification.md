# GL-010/011 release-candidate qualification

Starting main: `34ab42ee4e160a6d8ba85bded00bd9dce1c1cd93`.
Development branch: `ci/gl-010-011-release-qualification`. Main remains unchanged.
Status: implementation under qualification; no candidate result is claimed yet.

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

## Remaining boundaries

This gate does not automate Windows core/full-native sanitizers or qualify a
matching instrumented Godot host. GL-017/018, broader GL-020 adversarial animation
security, GL-027 template authoring and GL-015 asset redistribution rights remain
independent. Headless presentation does not establish GPU rendering or physical
input ergonomics. Production-scale performance and arbitrary assets remain
unqualified. No release/updater admission or byte reproducibility claim is added.
