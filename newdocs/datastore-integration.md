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
inspection failures. The sequential legacy seed actors have exited. Known default
application roots on these hosts contain no DataStore JSON records; existing
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
