# GL-018: full-native sanitizer qualification

## Scope and source identity

This work starts at main `83cd0887968d73d61d050650718d8ada6e124579` on
`qualification/gl-018-native-sanitizers`. It changes qualification infrastructure,
not production runtime behavior. Main, dependency pins, release publication and
updater admission are unchanged. GL-017 remediation is outside this work.

The production native input fingerprint remains 89 files, LF normalized,
`c651c1ff730bb2de8c16da996c09d2567e26d45865dfa25118df812d1f51d91f`.
Dependencies remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`.

All local builds and execution use DockerPC. The Linux environment is a
task-owned Docker container on DockerPC, not another worker. Two compiler jobs,
explicit timeouts, Windows job objects/POSIX sessions, hidden Windows processes
and isolated fixture profiles bound execution. Original caches and unrelated
workloads are retained. MainPC and LinuxBox are not used.

## Reproduced mechanisms and responsibility

### Windows stock-host shutdown

The historical registration-only baseline and GodotLuau candidate both reach
functional PASS and hang during exit under stock Godot plus an ASan extension.
Those original reports remain in [shared-domain qualification](shared-domains-validation.md)
and [GL-018](issues.md#gl-018-windows-full-native-sanitizer-host-remains-unqualified).

A new minimal GDExtension uses only the pinned C interface header, malloc/free,
and initialization/deinitialization callbacks. It contains no godot-cpp, Luau,
GodotLuau, domains, gameplay or networking. Under official Godot 4.7.1 it completes
one and five actual library load/unload cycles, prints PASS, then exceeds a
30-second process-exit deadline. Engine-only stock Godot exits zero. A standalone
LoadLibrary/FreeLibrary control exits cleanly with either an instrumented or an
uninstrumented EXE; intentional stale reads in the DLL are detected in both.

Thus GodotLuau and godot-cpp are not necessary to reproduce this shutdown failure.
These controls identify a stock-host/sanitizer interaction, not an extension
memory-safety defect or a proven particular loader-lock call chain. The supported
candidate profile instruments the Godot executable, extension and dependencies
with the same compiler/runtime. Microsoft's
[ASan limitations](https://learn.microsoft.com/en-us/cpp/sanitizers/asan-known-issues?view=msvc-170)
also distinguish fully instrumented processes from partial instrumentation and
DLL-unload behavior; that guidance alone is not a reproduction of this hang.

### Linux stock-host loader rejection

The current ASan extension, official Godot 4.7.1 and Clang 19's matching preloaded
runtime reproduce the explicit sanitizer rejection of `RTLD_DEEPBIND` before
the registration fixture can pass. The failed process/report is preserved.
This is a loader admission failure, not a clean native sanitizer run.

The exact pinned engine's
[`drivers/unix/os_unix.cpp`](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/drivers/unix/os_unix.cpp)
already selects `RTLD_NOW` when `ASAN_ENABLED` is defined, and
`RTLD_NOW | RTLD_DEEPBIND` otherwise. The corrected profile builds the unchanged
engine with its supported `use_asan=yes` configuration. It uses no loader shim,
interposition, engine patch, ignored rejection or sanitizer preload in the
qualified runtime process. Linux leak detection stays enabled.

## Build and harness changes

[`SanitizerHosts.json`](../tests/runtime/SanitizerHosts.json) pins engine source
`a13da4feb8d8aefc283c3763d33a2f170a18d541` and source-archive SHA-256
`98c5c1c101d15d43de5e3dca81cfb57ef3698495d67eeaf5e34db739b751bbb9`.
SCons 4.10.0 uses the existing hash-pinned release build requirement. The host
builder validates every original engine file when reusing a source/build cache
and records an aggregate source index, compiler hash, exact command, policy
hash, executable hash, runtime DLL hashes, timeout, exit status and build log.
It never changes engine source or project submodule pins.

| Profile | Host and extension | Leak detection |
| --- | --- | --- |
| Windows x86-64 Debug | Same MSVC installation, `/fsanitize=address`, compatible dynamic Debug CRT, no `/RTC` or incremental link | MSVC LSan unsupported; no Windows leak-clean claim |
| Linux x86-64 Debug | Same Clang 19, ASan, frame pointers; host ASan/LSan and lld | `detect_leaks=1`, no suppressions |

The host is a headless `template_debug` developer build with actual 2D/3D
physics, GDScript, ENet/multiplayer, TLS and fallback text support. Path overrides
are explicitly enabled for the existing `--path` fixtures. It is not an editor
or renderer qualification. The official, hash-verified editor at the same engine
revision preprocesses Character fixture assets in a project with no GDExtension;
the actual gameplay actors still execute on the instrumented host. The optional
`--asset-godot` arguments preserve ordinary presentation/performance defaults and
all existing assertions. Asset input and importer identities are retained.

The native builder applies sanitizer flags to both C and C++ and records source,
dependency, compiler, compilation-database and product identities. The native
runner rejects mismatched hosts, compilers, products, source fingerprints,
official importers or incomplete instrumentation. It runs the existing runners
and strict checkers rather than duplicating their gameplay assertions:

- Intentional standalone and in-Godot use-after-free detection; Linux intentional
  leak detection, separately isolated from clean controls.
- Engine-only shutdown and five minimal C ABI load/unload cycles.
- Five production registration cycles and five VM/module/owner-retirement cycles.
- Existing complete 80-case core qualification and 110 native actors, including
  GL-020 actual ENet adversarial evidence and GL-022 ownership markers.
- All GL-003/004/005/007/009/019/020/022/023 groups, Character V2 presentation
  assertions and performance fixture execution. Performance is not a speed gate.

Unexpected sanitizer reports fail qualification even if an actor printed PASS
or returned zero. Intentional failure controls require the specific diagnostic,
a nonzero exit and a bounded non-timeout process. Absolute quoted report paths
survive Godot's working-directory changes and Windows drive separators. No leak
suppression, disabled detection, altered gameplay authority or relaxed assertion
is used to obtain acceptance.

## Reproduction

Use a prepared matching MSVC developer environment on Windows, or Clang 19,
libclang-rt-19-dev, lld, pkg-config and Ninja on Linux. Do not install or enable
the runtime updater. With fresh output directories:

```text
python -m pip install --require-hashes --no-deps -r tools/ReleaseBuildRequirements.txt
python tests/runtime/ProvisionGodot.py --output <official-editor>
python tests/runtime/BuildSanitizedGodot.py --output <host> --jobs 2
python tests/runtime/BuildNativeSanitizers.py --output <build> --jobs 2
python tests/runtime/RunNativeSanitizers.py --godot <host-executable> --host-manifest <host>/sanitizer-host.json --extension <build>/native/<library> --build <build>/native --build-identity <build>/build-identity.json --probe <build>/probes/<probe-library> --loader <build>/probes/<loader-executable> --asset-godot <official-editor-executable> --asset-provenance <official-editor>/provenance.json --revision <immutable-commit> --output <fresh-evidence>
```

The [dedicated workflow](../.github/workflows/runtime-native-sanitizers.yml) is
read-only and non-publishing, triggered on this qualification branch or manual
dispatch. Normal core/native CI remains separate. It uploads successful and
failed reports, actual actor evidence, compilation identities and build logs.

## Failed attempts retained

- Portable SCons 4.5.2 is rejected by the Windows engine build. The isolated
  hash-pinned SCons 4.10.0 frontend corrects the prerequisite; no global toolchain
  is replaced.
- Initial controls reject an unquoted Windows ASan drive path, then report
  missing adjacent Debug CRT/ASan DLLs. Corrected controls preserve both failures
  and demonstrate the actual stock-host shutdown timeout.
- The first Windows instrumented template rejects `--path` because its default
  disables path overrides. Its original binary, manifest and logs are retained;
  the corrected host explicitly enables this supported build option.
- Source extraction on a Windows Docker bind mount was interrupted before any
  compiler/test ran. The task-owned replacement uses bounded tmpfs workspace
  storage with persistent evidence on E:, avoiding pressure on nearly full C:.
- [First hosted attempt](https://github.com/gmoddev/GodotLuau/actions/runs/41294066758):
  Windows environment setup fails quoting; Linux host compilation fails for
  missing `sanitizer/asan_interface.h`. The Linux artifact, ID `13078093437`,
  SHA-256 `f95fcc5bd1aea7aa0ea2883b8a98995180a34cba4f2b354bef1fae283c80a9bc`,
  was downloaded and inspected. The complete original job logs are preserved.
- An initial reused Linux compilation database has one uninstrumented C entry
  for the excluded Luau CLI's isocline target. This is not evidence that the
  runtime links that CLI. The strict new gate rejects the incomplete configuration;
  subsequent build configuration supplies consistent C and C++ flags.
- The first in-host intentional UAF cannot create its relative report path
  after Godot changes directories. The gate correctly rejects it. Absolute quoted
  paths produce the required actual report; leak detection remains enabled.

## Qualification status

**PARTIALLY QUALIFIED; GL-018 remains open.** Implementation input revision is
`055d8f07440cbe9035937a2e8b22dba476e7356b`. The matching Windows host is
SHA-256 `ac5c5977f282c7c0b500357cbf10fb5d513dfc094beaac21ec2806ddea50a153`.
The Linux host is SHA-256
`bbfe7aabcd410ea9493eb9dec7ce9ffe74bf26803926be9072f0ef3d89692409`.
Both platforms pass the engine-only, five-cycle minimal C ABI reload, standalone
UAF and in-Godot UAF controls. Linux additionally detects the intentional leak.
These are actual detection/exit checks, not just successful compilations.

The first full Windows attempt passes five production registration cycles but
finds an ASan access violation after five VM/module cycles print PASS. The stack
enters an unloaded address through `Object::~Object()` at engine
`core/object/object.cpp:2363` while `SceneTree::finalize()` destroys the root
Window. That line calls an instance-binding free callback. This is evidence of
a remaining unload/binding lifetime problem; attribution between the extension,
godot-cpp and the engine requires a binding-only control. It is not the original
stock-host exit hang, and no engine or extension fix is asserted from this trace.
The Linux production VM reload also fails; its complete report is retained.

Other first Windows full-profile failures remain visible:

- GL-005's existing 250 ms HTTP frame-progress assertion rejects a 330.418 ms
  observed peak. Its bound and production transport are unchanged.
- The GL-023 utilities actor fails the existing line-15 URL-encoding assertion.
  Its later diagnostic banner is not evidence that the incomplete actor passed.
  The host/CRT interaction needs isolation; this is not attributed to JSON or
  fixed by weakening the assertion.
- GL-009's competing increment actor reaches the existing conflict retry bound.
  Retry, admission and timeout limits are unchanged.
- Character presentation cannot load the imported R6 OBJ resources through this
  template host's project layout. Separate editor preprocessing alone is therefore
  insufficient in the tested profile. Export/remap preparation or an instrumented
  editor needs qualification; this is not a proven Character V2 runtime defect.

The completed local Linux attempt also exposes a qualification workspace error:
its output/profile root `/evidence` is a Docker Windows bind mount, reported by
`statfs` as **v9fs**. Existing `GLDataStoreBackend::Local()` deliberately admits
only ext-family, XFS and Btrfs filesystems on Linux. The persistence actor's
`Storage/helper unavailable` disposition is therefore required for that root.
Tmpfs is outside the whitelist too. Linux persistence, filesystem/persistence
integration and the HTTP final-close persistence assertions require a supported
filesystem rerun; the current attempt does not qualify them. This is a test
workspace mistake, not evidence of a new persistence defect or a reason to relax
the production filesystem admission check. See the
[filesystem record](evidence/gl018/filesystem-profile.json).

Linux VM reload exits with signal 11 after its PASS marker, with no ASan report;
that is a failed teardown, not sanitizer-clean execution. The failed Linux
performance fixture also emits a real LSan report: **29,400 bytes in 135
allocations**, alongside missing-rig script errors and 15 leaked ObjectDB instances.
The incomplete fixture prevents attributing that finding to an otherwise valid
gameplay run. The original report is retained without suppression or attribution
to GL-017.

| Completed local check | Windows | Linux |
| --- | --- | --- |
| Core ASan, complete strict report | 80 PASS | 80 PASS, LSan enabled |
| Engine/minimal load-unload/detection controls | PASS | PASS, including LSan detection |
| Production registration, five actual loads/unloads | PASS | PASS |
| Production VM/module reload, five cycles | ASan access violation after PASS | SIGSEGV after PASS |
| Fully recorded passing native actors | 62 | 59 |
| GL-020 adversarial actors / authority checks | 10 / 510 | 10 / 510 |
| Observed GL-020 assertions, all passed | 1,008 | 1,006 |
| Complete 110-actor sanitizer gate | FAIL | FAIL |

The passing groups and partial attempts are recorded in
[local results](evidence/gl018/local-results.json); they do not replace the
failed complete gate. Assertion totals can vary with exercised update callbacks;
the raw per-actor records remain in the archive.

The original
[hosted failure](https://github.com/gmoddev/GodotLuau/actions/runs/41294066758),
[setup follow-up](https://github.com/gmoddev/GodotLuau/actions/runs/41294189593),
[prerequisite follow-up](https://github.com/gmoddev/GodotLuau/actions/runs/41294439976)
and [current full-native run](https://github.com/gmoddev/GodotLuau/actions/runs/41294973654)
are separate attempts, not substituted passes. Ordinary
[core CI](https://github.com/gmoddev/GodotLuau/actions/runs/41294973673) and
[native CI](https://github.com/gmoddev/GodotLuau/actions/runs/41294973588) both
pass on Windows/Linux at implementation revision `055d8f0`. All four downloaded
artifact digests, complete 80-case core reports, 110 native actors, 68 harness
inputs and 334 log hashes per native platform were independently verified on
DockerPC. Each hosted native platform contains ten GL-020 actors, 510 authority
checks and 1,003 observed assertions. Exact artifact IDs/digests and product hashes
are in the [artifact verification record](evidence/gl018/hosted-artifact-check.json).
At the bounded final observation, both full sanitizer jobs were executing their
fixture step. The [recorded job states](evidence/gl018/hosted-sanitizers-observed.json)
are pending, not passing. Documentation/evidence follow-ups preserve the
implementation, native inputs, fixtures and workflow at `055d8f0`.

## Evidence retention and cleanup

The [manifest](evidence/gl018/manifest.json) indexes **3,456** preserved files.
The exact-byte raw text/source archive is SHA-256
`b9c63552e80b391c1db09896a9ca862b463057e5199dad4815b8c09e80b29aeb`
(9,304,659 bytes), retained on DockerPC at
`E:/Sandbox/Codex/NativeSanitizers/qualification-raw-text.zip` and copied to the
controlling checkout's ignored `.runtime-tests/NativeSanitizers/` directory.
Selected readable original diagnostics, host identities, full gate results and
core reports are versioned beside the manifest; Git may normalize their text
newlines. Original raw bytes and all failed attempts remain in the hashed archive.
No generated production binaries or dependency changes are committed.

The task-owned Linux host/native build caches, source and probes were archived
before container cleanup: SHA-256
`863890114d8aa5df26f0f78b5b03d04b9b09e96204f82706fbe6c131c2e071ba`
(565,183,833 bytes). Both task containers were stopped and removed. The existing
Character container was restored to its original stopped state, its shared volume
was read-only throughout the replacement runs, and caches/evidence on E: remain.
See the [cleanup record](evidence/gl018/cleanup.json).

No complete Windows/Linux full-native sanitizer pass is claimed. GL-017,
rendered/device/editor coverage, other toolchains/configurations, Windows LSan,
broader adversarial/security claims and release/updater qualification remain
separate. No suppression, leak-disable option, changed gameplay bound or unrelated
runtime correction is included.

Integration recommendation: **HOLD**. Continue GL-018 with supported Linux
persistence storage, an appropriate instrumented asset/runtime host and isolated
binding-unload/Windows utilities controls before claiming complete closure.
