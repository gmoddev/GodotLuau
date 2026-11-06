# GL-009 controlled main integration (2026-10-30)

Preparation starts on the clean retained branch
`persistence/gl-009-transactional-datastore` at `d5e855b39a9bcee0c074c96f321e2472235583af`.
Local and fetched remote main are `bc8ca88771a2170350e539de48f2cff89044d924`.
The four original commits and ADR-005 qualification evidence must remain intact.
No release/updater enablement or production-root activation is authorized.

## Writer exclusion and data preservation gate

Read-only preflight finds no Godot/Luau process names or loaded `godot_luau`
native modules on the controlling Windows PC, Windows worker dockerbox or Linux
worker linuxbox. Module inspections report no permission failures. The owned
Linux qualification container is stopped. Known default application paths on the
controlling PC contain no DataStore JSON files. No running game/editor is stopped.

This is source integration and isolated qualification, not a production rollout.
No existing application persistence root is activated or mutated. Legacy-format
compatibility uses a disposable profile seeded by the preserved pre-GL-009
library, then waits for that owned process to exit before backing up all files
and loading the new library/companion. Original bytes and backup hashes must
remain identical across read-only CMake/SCons Debug/Release readers on each OS.
Do not run old/new writers together or treat lock acquisition as exclusion of
legacy binaries, which do not implement the transaction protocol.

Further results, merge identity and fresh hosted evidence follow as established.

## Controlled merge and focused results

The refreshed writer gate passes on all three known hosts immediately before
merge at `2026-10-30T04:36:12Z`: no candidate processes/native modules and no
inspection failures. The sequential legacy seed actors have exited. A separate
read-only inventory finds no DataStore JSON in known default application roots;
existing
qualification roots are preserved and are not used as live application roots.

Normal merge `fc923d2713c39e39fa8db87576bd8e7a5b91ef6d` has parents `bc8ca88`
and retained branch tip `d5e855b`. Its entire tree equals the qualified branch;
all four original commits are ancestors. The native fingerprint remains
`c88311513a6a91e195a6f37712a19dada19754c02222f26ad02b7ac6048e622c` (87 inputs),
and the original ADR-005 machine evidence is unchanged.

Both workers pass fresh Debug/Release core suites (72 cases each), the 23-actor
DataStore group with native commit/recovery probes, and three filesystem actors.
This exercises deterministic Update/Set/Remove conflicts, atomic increments,
interrupted commits, fresh-process recovery, BindToClose saves, cancellation,
manual-resume rejection, owner/module/scene/OOM cleanup and helper admission.

Each OS also passes old-format read compatibility through CMake Debug/Release
and SCons Debug/Release products. A genuine pre-GL-009 writer creates eight JSON
files and an unrelated sentinel in a disposable profile, then exits. All nine
files are backed up and remain byte-identical after new readers, including legacy
Unicode value bytes, Unicode filenames, scope aliases, ordered data and BOM input.
Decoded false is intentionally corrected to false. No data-file migration occurs;
only the new protocol's private lock may be added. The archived
[fixture](evidence/gl009-integration-fixtures/Compatibility.gd) and
[runner](evidence/gl009-integration-fixtures/QualifyIntegration.py) reproduce the
sequential handoff. Existing application data is never passed to these fixtures.

## Companion archive follow-up

Directory-package checks expose an inherited ZIP-builder gap: its extension
filter excludes the Windows `.exe` and extensionless Linux companion. A bounded
follow-up includes only the two exact companion names, selects the matching
platform, writes Linux executable metadata and rejects a missing required helper
before replacing an existing archive. Five real-archive tests cover both OS
selections, unified inclusion, bytes/mode and missing-helper rejection. Native CI
now runs those tests and records packager/test source digests.

Publication remains disabled. The inherited release workflow still stages only
Linux `.so` files and reuses Windows binaries from an old ZIP. These GL-010/011
distribution gaps are not enabled or relabeled as qualified; its jobs remain
literal false with read-only permissions. Disposable source-built archives and
respectful Unix-mode extraction are qualified separately below. The updater is
unchanged and still rejects runtime installation.

The actual Windows/Linux native subset archives also pass extraction and runtime
reads using the normal `GodotLuau/bin` paths. Both Debug and Release libraries
start with the one packaged, source-matching Release companion. Archive entries
match the qualified library/helper hashes, and Linux extraction respects the
stored mode `0755`. All original legacy files and backups remain unchanged.
These are local disposable qualification archives, not published release assets.
The [archive fixture](evidence/gl009-integration-fixtures/ArchiveIntegration.py)
records package/member digests and startup results.

The first Linux archive-smoke attempt lacked the packager in the worker's explicit
source overlay and exited before creating an archive. That environment failure
is retained separately; the required source was synchronized and attempt `v2`
passes on both OSes. No failing attempt is labeled a runtime/package PASS.

## Current verification checkpoint

The narrow packaging follow-up is `31d0f1f502f75dfa1c530acdf5a21ab1b1d3c16d`.
It changes the ZIP builder/tests and native CI, with no change to the qualified
native runtime, dependency pins, release workflow or updater. Five packaging
tests pass on Windows and Linux, including rejection before archive overwrite.

Fresh hosted core/native CI passes on this main revision, with the complete
66-actor suite and five packaging tests on both platforms. The initial
merge-only native run was cancelled as superseded, rather than substituted for
the packaging follow-up's verification. Final artifact verification follows below.

The Windows worker has no remaining Godot/helper processes. Scoped Linux
controllers reap owned descendants; inspection finds none, and the task-owned
container is stopped. Caches, canonical products, compatibility backups and logs
are retained. Linux has 18 GiB free; unrelated services remain unchanged.

## Final disposition

**GL-009 is integrated into main and verified within ADR-005's supported scope.**
Merge `fc923d2` preserves all four original commits, the qualified branch tree and
the immutable original qualification record. The necessary packaging follow-up
`31d0f1f` is also on main; native source remains identical to the qualified branch.

Fresh hosted [core run 41004373508](https://github.com/gmoddev/GodotLuau/actions/runs/41004373508)
and [native run 41004373448](https://github.com/gmoddev/GodotLuau/actions/runs/41004373448)
pass all four Windows/Linux jobs at exact revision `31d0f1f502f75dfa1c530acdf5a21ab1b1d3c16d`.
Both platforms pass 72 core cases, 66 native actors and five packaging tests. All
four downloaded ZIP digests match GitHub metadata. Native source, all 43 harness
hashes, official engine digests and packager/test source digests match the records;
all 426 native log hashes and result groups are verified.

The [integration evidence](evidence/gl009-main-integration-2026-10-30.json) retains
the writer gate, commit/qualification preservation, local results, nine-file
backup/read compatibility, native package members/modes, lifecycle checks and
hosted artifact identities. The original
[ADR-005 qualification evidence](evidence/gl009-transactional-datastore-2026-10-30.json)
is byte-identical in Git (blob `61935d69cd73258317988b5df2ba6044876e81ad`).
The final documentation/evidence commit changes no qualified runtime or packaging
input and does not restart the path-filtered runtime workflows.

No existing application persistence root is activated and no production data
migration is attempted. Compatibility covers supported legacy JSON shapes and
ADR-005 limits, not every possible historical/corrupt/oversized record. Unknown
deployments require their own stopped-writer inventory, offline backup and data
assessment before activation. Runtime updater distribution and both release jobs
remain disabled; their source files are unchanged from `bc8ca88`. No release
assets or native binaries are published. GL-010/011 distribution gaps, host reaping,
Windows native ASan GL-018 and the other recorded limitations remain explicit.
