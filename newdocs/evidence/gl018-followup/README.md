# GL-018 follow-up evidence

This directory contains selected readable records for the follow-up from
`66362c737f4185461f2da4de218e9eeb127cb10e`. The maintained interpretation and
limitations are in [qualification](../../native-sanitizer-qualification.md#follow-up-from-66362c7).
It does not replace the [initial evidence](../gl018/manifest.json).

- `local-results.json`: final Windows candidate, strict 80-case core report,
  idle retries, matched baseline comparison and partial presentation outcomes.
- `binding-*.json`, `windows-binding-asan.log`, `gdb-observed-excerpt.log` and
  `gdb-recovery.json`: C ABI isolation, actual callback retirement counts,
  observed crash addresses and the missing/empty recovered GDB records. The GDB
  excerpt is transcribed console output, not original process-log bytes.
- `bundled-assets.json` and `asset-inputs.json`: original asset identity and
  geometry/bounds/decoded-texture equivalence for all six bundled meshes.
- `core-hosted.json`, `native-windows.json`, `native-intermediate.json` and
  `previous-sanitizer-artifacts.json`: independently checked downloaded artifact
  identities, exact source revisions and actual execution counts. Intermediate
  source passes do not replace current-source failures or pending jobs.
- `ci-observation.json`: bounded hosted status, initial Linux failure and the
  single accepted Linux retry. `final-ci-observation.json` supersedes that pending
  snapshot with completed jobs. `native-linux-retry.json` verifies its 110 actors;
  `final-sanitizers.json` retains both failed full profiles and partial counts.
- `capacity-recovery.json` and `linux-cleanup.json`: worker recovery, cache-path
  preservation, verified recovered evidence and task-owned resource cleanup.
- `archive.json`: identity of the retained exact-byte follow-up archive. The
  archive includes raw failed attempts, original reports, command helpers,
  current fixture sources and bundled runtime products; its manifest lists
  every captured file and SHA-256. It is retained on DockerPC at the recorded
  E: path and copied to this checkout's ignored `.runtime-tests/NativeSanitizers/`.

Selected Git text can undergo newline normalization. Original bytes remain in
the verified archive, SHA-256
`52cc3c3bcb7c6dd71640d9239fa739d0039d0aad4b1fb7364c1f2703808ecbfa`
(17,418,067 bytes; 6,573 files; no read failures at final collection).
An earlier in-progress archive is retained too; it explicitly records two
rotated Windows profile logs that disappeared during collection. The stable
dedicated actor logs and all available final records are retained separately.
The later hosted artifacts are separate ZIPs on DockerPC under the same follow-up
directory (`native246-<artifact-id>.zip` and `sanitizer246-<artifact-id>.zip`), with
the recorded API archive digests independently verified. They are also downloaded
to the controlling checkout's ignored evidence directory. The final validation
record checks native products, 71 candidate harness inputs against `2466015`,
all 6,573 archived files, JSON/link validity and absence of task runtime/compiler
processes. It runs no additional runtime tests.

No full-native sanitizer acceptance is asserted. Main and distribution remain
unchanged. The historical 29,400-byte Linux leak report remains untriaged.
