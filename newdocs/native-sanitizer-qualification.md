# GL-018: full-native sanitizer qualification

**Latest outcome: PARTIALLY QUALIFIED; GL-018 remains OPEN.** The
[binding-retirement follow-up](#binding-retirement-follow-up-from-dfa700a)
resolves the reproduced production unload crash in narrowly admitted instrumented
hosts. Linux completes 80 core cases and 110 native actors locally and in hosted
ASan/LSan CI. Windows hosted ASan still rejects competing DataStore increments;
its full native profile is not accepted. See the
[final outcomes and concrete next step](#qualification-outcome-and-remaining-blocker).
Earlier failures below are historical evidence, not discarded or retroactively
reclassified as passes.

## Scope and source identity

This work starts at main `83cd0887968d73d61d050650718d8ada6e124579` on
`qualification/gl-018-native-sanitizers`. The initial investigation changes
qualification infrastructure. The [follow-up](#follow-up-from-66362c7) also fixes
locale-dependent public URL encoding. Main, dependency pins, release publication and
updater admission are unchanged. GL-017 remediation is outside this work.

The initial production native input fingerprint is 89 files, LF normalized,
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

## Initial qualification status (055d8f0)

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

Initial integration recommendation: **HOLD**. Continue GL-018 with supported Linux
persistence storage, an appropriate instrumented asset/runtime host and isolated
binding-unload/Windows utilities controls before claiming complete closure.

## Follow-up from 66362c7

**PARTIALLY QUALIFIED; HOLD. GL-018 remains open.** This follow-up starts at
`66362c737f4185461f2da4de218e9eeb127cb10e`. Runtime correction
`241396b46f193ea48e63294594bce2d7104f6966` and final fixture inputs
`246601599e581bd1c34cc403adcafcc404f89ae7` remain separate from evidence-only
publication. The new 89-file LF-normalized native fingerprint is
`2706e1685bdf0207e55eacc2f877e4578a3164603ea5861c183009348c7d1bc8`.
The instrumented hosts, compiler/runtime requirements and dependency pins are
unchanged. No engine, godot-cpp, networking, persistence or updater patch is made.

### Binding-only isolation

The C ABI probe now obtains an engine-owned Engine singleton binding using
`object_get_instance_binding` and explicit create/free callbacks. It links no
godot-cpp, Luau or GodotLuau. Five clean minimal reloads exit zero on both
platforms. Five binding reloads with explicit `object_free_instance_binding`
before each unload also exit zero: five bindings installed and five freed,
with Linux leak detection enabled. Leaving those bindings attached reproduces
Windows ASan access violation and Linux SIGSEGV after the fixture prints PASS.
Neither platform frees any of the five surviving bindings before library unload.

The Windows stack calls an unloaded address from `Object::~Object()` at pinned
engine `core/object/object.cpp:2363`, matching the production VM-cycle mechanism.
Pinned `GDExtensionManager::unload_extension()` deinitializes and removes the
library without the `clear_instance_bindings()` used by editor reload. These
controls isolate a host/binding retirement boundary; GodotLuau and godot-cpp are
not necessary to reproduce it. They do not prove that every possible production
unload failure has the same cause. No unsafe extension-side global-pointer cache,
blanket binding cleanup or unqualified engine patch is substituted for a fix.

Linux GDB child-process console traces show both the C ABI and production failures
after PASS. The existing Linux host is stripped, so the observed traces show
addresses and thread stacks without source-line resolution. Diagnostic execution
uses `handle_segv=0` to let GDB capture the fault; ASan instrumentation and
`detect_leaks=1` remain enabled. GDB/ptrace execution is diagnostic evidence, not
LSan-clean qualification. Ordinary qualification continues to use the original
sanitizer options and treats both exits as failures.
The recovered original GDB log files are empty, and the diagnostic metadata JSON
is missing after the backing-disk failure. A short observed console excerpt is
explicitly transcribed from tool output; it is not represented as original
process-log bytes. The command source, empty raw files and this proof gap remain
retained. A new symbolized diagnostic run is still required for durable full
Linux teardown traces.

The first probe attempted `object_set_instance_binding` on a surviving singleton;
that API is intended for binder creation and produced an additional four-byte
Linux probe leak on repeated reuse. Its failed controls and reports are retained.
The corrected get/create-callback control passes cleanup on both platforms.
That probe error is separate from the historical 29,400-byte gameplay report.
`binding-investigation PASS` in the runner means the diagnostic collector
completed; the failed production gate and unexpected reports still reject the
full profile.

### Filesystem and worker recovery

The follow-up Linux profile moves user data and qualification output to a new
task-owned Docker volume. `statfs` identifies ext-family `0xef53`, admitted by
ADR-005; v9fs and tmpfs remain denied. Regression, authority, animation, Character,
resource, filesystem, HTTP, HttpService and caller groups have recovered complete
passing actor records. The console also reported DataStore PASS, but the recovered
structured evidence is incomplete. That console marker does not qualify the
group or the full profile.

The volume exhausted DockerPC's C: backing disk during this attempt. C: reached
114,688 bytes free, Docker's filesystem became read-only, and the full runner
exited 120 before completing presentation/performance/core and the strict gate.
This is a retained infrastructure failure, not a sanitizer pass. The capacity
mistake was choosing volume-backed output without reserving enough physical host
space for all fixture library copies. No filesystem restriction or test bound
was relaxed. The final URL-correction Linux sanitizer profile remains unqualified.

Recovery relocates 1,024,409,044 bytes of the task's Windows ASan binding cache
to E: and preserves its original path with a junction. Following explicit user
approval, the failed Docker Desktop backend is restarted. The two containers
running before the failure return to running; the pre-existing Character
qualification container remains stopped. The task volume is copied to E:,
binding records/products and the recovered text archive are verified, then only
the task container and volume are removed. Original caches and failed attempts
remain retained. See the follow-up evidence and cleanup records below.

Another Linux full run requires capacity admission for the complete profile,
supported persistent storage and enough host backing space. No fresh Linux
candidate pass is inferred from the earlier source's successful groups.

### Character asset preparation

Template hosts require runtime `.remap` files rather than editor `.import`
metadata. Adding mappings exposes a second issue: loading the imported R6 mesh
through the template rejects its external compressed texture's generic
`Texture2D` hint. The fixture preparation now uses the matching verified official
editor to bundle each original mesh with an ImageTexture of the original decoded
image. It asserts identical surface arrays, bounds, texture dimensions and every
decoded texture byte before and after saving/reloading all six meshes. Runtime
mappings name and hash those actual bundled products. Source assets are unchanged;
no synthetic rig or replacement texture is introduced.

The initial editor-mode bundler idled until its deadline. A subsequent binary
bundle retained a broken external texture reference and failed the byte/identity
assertions. Both failures are retained. The corrected text bundle embeds the
original image, passes the six-mesh preparation control, and preserves existing
presentation/gameplay assertions. Headless sanitizer fixtures do not qualify
rendering, graphical appearance or devices. Linux's historical failed-asset leak
report remains untriaged until the corrected full fixture completes under LSan.
On the final Windows candidate, the actual R6 and custom single-player actors
pass 47 assertions each; listen host/client actors pass 20/19/19. Dedicated
server/client presentation records fail their existing ENet creation, movement
and animation checks. The two later custom multiplayer cases are not reached.
Thus asset loading is corrected, but complete presentation qualification remains
open. The performance actor exceeds its unchanged 180-second deadline.

### URL encoding and remaining actors

The Windows production-handler diagnostic reproduces `UrlEncode` returning raw
bytes AA, E9 and FF. Luau `%w` follows the process C locale and therefore does not
express RFC3986 ASCII unreserved bytes in this host. The single runtime correction
uses explicit `A-Za-z0-9` ranges. The existing core and native utilities cases now
assert every byte 0 through 255, alongside UTF-8, NUL and argument checks. This
corrects the established [API contract](httpservice-api.md), with migration noted
there. GL-005 transport, origin grants, cancellation, request and response limits
are unchanged.

Windows full-profile attempts still reject HTTP frame-progress peaks and bounded
DataStore conflict exhaustion. Their 250 ms progress bound and eight-attempt
transaction contract remain unchanged; neither failure establishes corrupted
commits or unauthorized I/O. The candidate attempt also records execution-budget
and animation-completion failures while worker recovery is occurring. Temporal
overlap is not proof of causation. A bounded idle follow-up retains both successes
and failures instead of replacing the original run or repeatedly retrying until
acceptance.
The native utilities script completes the added 256-byte assertions and UUID/JSON
checks, then fails the unchanged frame-progress gate at **526.582 ms**. This is
encoding-correctness evidence, not a passing utilities actor. The candidate's
complete core ASan report passes all 80 cases on Windows. Its final full-native
profile and strict checker fail; 110 sanitizer actors are not qualified.

The idle follow-up passes all ten GL-020 actors, 510 authority cases and 1,003
observed assertions. It still fails integration's Identity resume budgets, HTTP
progress and DataStore contention. Two interleaved trials each of the retained
original DLL and the candidate, on the same host with the unchanged Integration
fixture, reproduce the Identity budget failure in both versions. This rejects a
candidate-exclusive explanation in those trials; it does not establish a precise
per-call performance cause or justify changing the budget. No further retries or
runtime optimizations are used to force acceptance.

### Hosted evidence and closure

The previously pending [sanitizer run](https://github.com/gmoddev/GodotLuau/actions/runs/41295811200)
completed with both profiles failed. Downloaded Windows artifact `13080425872`,
SHA-256 `c782a218079a0b09415155fdd777121d804d3dc6b1300c343abd205174f2604e`,
verifies 349 report hashes. Linux artifact `13079900738`, SHA-256
`b26ac173de9703fc91f45d52dc56e152e52db21dd750a730876308d5adc83cc1`,
verifies 451. Both retain failed production unload and presentation gates;
Linux's ordinary filesystem/HTTP/HttpService/DataStore groups pass on that hosted
profile. These artifacts remain distinct from fresh follow-up execution.

Fresh source `2466015` [core CI](https://github.com/gmoddev/GodotLuau/actions/runs/41388787592)
passes 80 cases on Windows and Linux. Both downloaded artifacts pass the existing
strict discovery/report checker on DockerPC: Windows `13116825836`, SHA-256
`9752c18fc04b3c63a4b9a59cb795583cb17be0f9de00e6814bf560be95818c33`;
Linux `13116183921`, SHA-256
`6542c8035044c65bd0573a226dbb5220ba62bf18f13c8215966405076320f615`.
Fresh [native CI](https://github.com/gmoddev/GodotLuau/actions/runs/41388787434)
and [sanitizer CI](https://github.com/gmoddev/GodotLuau/actions/runs/41388787401)
must be reported from their actual observed states; pending required jobs are
not passes. Final observed states, local outcomes, archive identity and cleanup
are recorded with the follow-up evidence.

Current-source Windows native artifact `13117471093`, SHA-256
`2049238c3d4ada6f5c66ab9fcbf8c2a6121b477244396bd8f0bf48f9bbe2c9ec`,
verifies 110 actors, 71 immutable-source harness hashes, 335 log hashes and ten
complete GL-020 records with 510 cases and 1,003 assertions. The reported binary
and companion hashes are preserved; the downloaded ordinary CI artifact contains
qualification evidence rather than independently rehashed production binaries.
Linux's first ordinary native job fails the existing positive-state-delivery
deadline. Its artifact `13116608407`, SHA-256
`fe6cd9549a0b28fd6d80312aac352f0d0a5dee4627f7eb5113286e4e696647c0`,
is preserved and verifies eight completed regression actors, not a complete
110-actor gate. The first retry API request is rejected while Windows is still
running; one Linux-only retry is dispatched once that workflow finishes. Its
observed state remains separate from the initial failure.

Intermediate [ordinary native CI at 241396b](https://github.com/gmoddev/GodotLuau/actions/runs/41387684571)
passes 110 actors on each platform at the same production fingerprint
`2706e168...`. Both artifacts verify 71 harness inputs against that immutable
commit, 335 log hashes each and all ten GL-020 actors/510 cases/1,003 assertions.
This is useful counterevidence but does not replace current-source failed or
pending checks. Exact identities are in the follow-up records.

At **2026-11-02 04:59:57 UTC**, core and Windows ordinary native are passing;
the Linux ordinary native retry and both full sanitizer jobs remain pending.
See the [bounded CI snapshot](evidence/gl018-followup/ci-observation.json),
[local outcomes](evidence/gl018-followup/local-results.json) and
[selected evidence index](evidence/gl018-followup/README.md). The exact-byte
[archive identity](evidence/gl018-followup/archive.json) covers 6,573 files,
17,418,067 bytes, SHA-256
`52cc3c3bcb7c6dd71640d9239fa739d0039d0aad4b1fb7364c1f2703808ecbfa`.
Its final collection has no read failures. Raw histories, failed bundle/probe
attempts and complete available logs are retained; incomplete Linux records
remain explicitly incomplete.

The [final observation](evidence/gl018-followup/final-ci-observation.json) at
**2026-11-02 05:12:14 UTC** supersedes that pending snapshot. Ordinary core and
native CI pass on Windows/Linux: 80 core cases and 110 native actors per platform.
The successful Linux native retry artifact `13117414498`, SHA-256
`d1a6ed59239038e8c961381e589ffa02cd74a25bb0de38dbe7845e795142a44e`,
verifies 71 source-bound harness inputs, 335 logs and all ten GL-020 actors,
510 authority cases and 1,003 assertions. The first attempt remains preserved.

Both fresh full sanitizer jobs finish **FAIL**, with downloaded artifacts and
all available report hashes independently checked on DockerPC:

| Fresh sanitizer fact | Windows | Linux |
| --- | --- | --- |
| Strict core report | 80 PASS | 80 PASS, LSan enabled |
| Basic UAF/clean-exit controls | PASS | PASS, including leak detection |
| Production VM reload | ASan violation after PASS | SIGSEGV after PASS |
| Completed native actors in whole passing groups | 52 | 95 |
| Complete 110-actor sanitizer profile | FAIL | FAIL |
| Verified artifact report hashes | 380 | 503 |

Windows artifact `13117239562` is SHA-256
`25083c579935e0849ef371f3a7a79bc4bc1e3bd586b47d7bec5526214bfcdb2a`;
Linux artifact `13117223830` is SHA-256
`1a15aa983ed6cfa8011f38a60df98a5c495dcccc54876151ffbfbe1d7e9c3b0a`.
The [verified sanitizer records](evidence/gl018-followup/final-sanitizers.json)
retain actual group counts, exits, reports and animation-record completeness.
Linux's 95 actors include all 23 DataStore and ten GL-020 actors. This supplies
fresh hosted supported-filesystem, HTTP/HttpService, persistence and core-ASan
evidence that the interrupted local attempt could not provide. It does not
complete presentation, performance or unload qualification.

Both hosts reject dedicated presentation and time out the performance actor.
The Windows hosted presentation also prints PASS/exit zero but emits a GDScript
`previously freed` error at `CharacterPresentation.gd:482`; the strict checker
correctly rejects it. The fixture retains a Character reference across waits,
requiring a focused liveness/session trace rather than a speculative production
ownership change. There is no qualified full-native leak-clean run, and the
historical failed-rig LSan finding remains unresolved. Later downloaded CI ZIPs
are retained independently from the earlier local archive; their exact identities
and verified execution evidence are versioned here.

The smallest next investigation is a separately documented host/binding unload
correction, validated first against these no-VM controls and a symbolized Linux
host. It must retire surviving callbacks before unmapping the library, then pass
production VM cycles and the unchanged full profiles on properly provisioned
storage. The current work stops without an engine patch or acceptance workaround.
GL-017, Windows LSan, rendered/device/editor coverage and other toolchains remain
outside closure. Main stays at `83cd0887968d73d61d050650718d8ada6e124579`;
release publication and updater distribution remain disabled.

## Binding retirement follow-up from dfa700a

Investigation commit `44fe8c2fe635cbce3a8d8385b839ca783913799d` adds a
diagnostic loader and durable Linux child-debugger capture. Host correction
`0119017696b60901a7f0af981387446d82833230` admits one explicit qualification-host
patch. The GodotLuau production source remains identical to `dfa700a`:
89 LF-normalized inputs, SHA-256
`2706e1685bdf0207e55eacc2f877e4578a3164603ea5861c183009348c7d1bc8`.
Neither commit changes gameplay, VM ownership, the transport, persistence, runtime
limits or pinned submodules. Main remains unchanged. Full GL-018 acceptance still
requires both complete, clean 80-core/110-native sanitizer profiles.

### Ownership and reproduced mechanism

The engine stores binding tokens and raw free/reference callbacks on each Object
(`core/object/object.cpp`, `get_instance_binding`, `free_instance_binding`, and
`Object::~Object`). Pinned godot-cpp uses the library token and creates wrappers
for native objects lazily. These wrappers are distinct from the Luau ObjectID
wrappers and from the native objects themselves. The godot-cpp native-class free
callback destroys/frees its C++ wrapper; it does not destroy the engine object.
Production's scene/domain shutdown and language unregistration therefore do not
retire every wrapper attached to a longer-lived engine object.

The stock explicit `GDExtensionManager::unload_extension` deinitializes the
extension and removes its library reference. It does not invoke the binding
cleanup used by editor reload. That registry/cleanup is under `TOOLS_ENABLED`
and additionally depends on extension-reload admission. It is unavailable in
the tested template hosts. `GDExtension::close_library` consequently unmaps the
library while its callbacks can remain on live engine objects. Correct ObjectID
resolution inside GodotLuau cannot repair that engine callback pointer.

The diagnostic loader forwards the unchanged production entry point and records
get/create binding calls. It observes exactly seven surviving native bindings per
cycle on both platforms: Engine, OS, ProjectSettings, ResourceLoader,
ResourceSaver, SceneTree and the root Window. Registration without domain work
exits cleanly. Direct VM/module reload and observation through the loader both
print PASS then fail: Windows ASan violation; Linux SIGSEGV, exit -11. Retiring
the surviving library-token bindings after production deinitialization makes all
five cycles exit cleanly on both platforms. This rejects a VM-only or
godot-cpp-only explanation; the independent C ABI control remains counterevidence
against attributing the engine boundary solely to GodotLuau.

The loader's retirement mode is a diagnostic intervention, **not a production
fix or a qualification substitute**. Its dispatch and library lifetime differ
from the normal loader. The corrected-host direct-production comparison is the
separate acceptance evidence for the host change.

### Durable Linux teardown diagnosis

The diagnostic relink uses the existing instrumented engine objects and removes
only the linker's `-s`. It changes no engine source or compile instrumentation.
Original stripped host SHA-256 remains
`bbfe7aabcd410ea9493eb9dec7ce9ffe74bf26803926be9072f0ef3d89692409`;
the symbol-retaining diagnostic binary is
`d02ad8a32227f82d54c7713d66f26863f0cd34afe26436e815c54dca59bfe187`.
The original executable is restored after relinking. Function symbols resolve
the production failure through `Object::~Object`, `Node::~Node`,
`Viewport::~Viewport`, `Window::~Window`, `SceneTree::finalize`,
`OS_LinuxBSD::run` and `main`, with the callback PC unmapped. Other threads and
library mappings are captured too. Line/local-variable DWARF is unavailable in
these reused objects; no source-line debugging claim is made.

`DiagnoseSanitizerUnload.py` opens the durable destination before launching its
bounded child debugger, flushes/fsyncs its log, and records source/binary/log and
loaded-library identities. New original-byte logs live on DockerPC's E: under
`E:/Sandbox/Codex/NativeSanitizers/retirement/`, outside the disposable container.
GDB uses `handle_segv=0` only for diagnosis, with leak detection still enabled.
LSan is unsupported under ptrace: a successful GDB command exit is never a
sanitizer-clean process result. The separate ordinary execution still exits -11.
The earlier empty GDB files and transcribed excerpt remain retained as failures.

### Narrow host correction and admission

The demonstrated C ABI and production failures justify a qualification-host
correction to pinned Godot's `GDExtension::close_library`. The patch snapshots
ObjectIDs under ObjectDB's lock, then releases that lock, resolves every ID again
and invokes `free_instance_binding(this)` while the library is still mapped.
This avoids retaining raw object pointers across callbacks or invoking them
under ObjectDB's lock. Only bindings using that library token are retired; other
libraries' tokens are untouched. No callback is suppressed or replaced by a
no-op, and no engine-owned object is destroyed by the host scan.

The scope is the standard library-token bindings exercised by pinned godot-cpp
and the repository's C ABI probe, after production work and native extension
instances have retired. It does not establish safe arbitrary hot-unload with
live extension instances, active callbacks, custom binding tokens, other
providers, editor reload or other engine versions. The host patch is maintained
here for qualification; it is not an upstream submission or a production engine
distribution, and it does not remediate GL-017.

`SanitizerHosts.json` pins the original engine revision/archive plus the patch
and exact admitted result. `BuildSanitizedGodot.py` checks all 13,985 original
archive inputs; only `core/extension/gdextension.cpp` may be original or the exact
reviewed patched result. Patch bytes and that file's admitted result use LF
normalization to account for Git's Windows checkout conversion. The manifest
also records the actual patched-file bytes separately. Unknown patch/source
results fail before compilation; both rejection paths are exercised and retained.
The full runner requires the matching patch policy in the host manifest.

| Qualification host input | SHA-256 |
| --- | --- |
| Original engine file | `a7f2f64bd1b05461f430ab499a5d2e4d87913179b2cbca223b9aa90a9c7a1d8b` |
| Patch, LF | `adfde942eb64b8f99e5a4dab4075678e201693cf3069a01675697c64b49b3fa1` |
| Patched engine file, LF | `1160e48c8bbf5dc9c22c3d70062dbe3ebd18fc6bd67886f1363d4ff115b51aa8` |
| Windows corrected executable | `96a64e425ae1aac600014e6fbe8489b3178c8d09b210c47fd4a03f18edcafdb0` |
| Linux corrected executable | `4e2a235ab539a164fac338f1e236dec52e4d2b26540bd5f7af6b2a7b2d6b7bd8` |

Both corrected hosts pass the direct unchanged-production five-cycle
registration and VM/module unload controls, and the clean/binding-only controls.
Linux intentional UAF and leak controls still detect their injected defects.
This resolves the reproduced unload mechanism in these hosts; it does not
qualify the complete native profile.

### Capacity and remaining qualification

DockerPC is the only local execution worker in this follow-up. Capacity is
checked before extraction/building; large products, logs and cache archives
remain on E:. A bounded tmpfs contains the reused build cache. The task-owned
ext-family profile volume contains user data only. The harness's optional
`GL_QUALIFICATION_PROFILE_ROOT` separates those profiles from repeated library
copies; the default layout and native ADR-005 filesystem restrictions are
unchanged. Original caches, failed setup attempts and source/binary comparisons
remain retained. No unrelated container or workload is modified.

Fresh source-`0119017` core CI passes all 80 cases on Windows/Linux. Both downloaded
artifacts are independently hashed and checked with the existing discovery/XML
checker on DockerPC. Native and full-native sanitizer CI are observed separately;
pending jobs cannot supply acceptance. The local complete Windows attempt again
rejects HTTP frame progress and DataStore conflict exhaustion while its unload
gates pass. Neither the 250 ms frame bound nor eight-attempt transaction contract
is increased. Current full-profile results and the remaining focused diagnostic
findings are recorded below as they complete. Historical failed-rig leaks and
timeouts remain unresolved until an actual complete clean run establishes more.

### Asset and storage follow-through

Fixture correction `92659bae6cc5d7b321b075848b905e9d660b47df` follows actual
phase/lifetime diagnostics. With the text bundles, the Windows performance actor
reaches only ten process frames in 171.6 seconds, before entering any measured
character-count window. Dedicated clients lose their peer connections while the
server constructs the rigs. This is distinct from the unload callback defect.

A no-extension control on the same corrected ASan host loads all six original
meshes in three interleaved text/binary pairs. It uses deep cache bypass, records
load time before identity hashing, and verifies all geometry-array hashes,
bounds, decoded texture hashes and integer dimensions. Total six-mesh times:

| Serialization | Three trial totals, milliseconds | Median |
| --- | --- | --- |
| Text | 15,672.038; 15,007.454; 14,570.402 | 15,007.454 |
| Binary | 150.430; 166.311; 143.468 | 150.430 |

Binary bundles contain the same explicitly embedded ImageTexture of the original
decoded image. The earlier failed binary attempt retained an external compressed
texture; that failure is not discarded or equated with this corrected bundle.
Only the fixture serialization extension changes from `.tres` to `.res`.
Existing original/round-trip assertions remain unchanged. The first comparison
control incorrectly compared JSON float dimensions to integer Dictionary values
and stalled after its assertion; its source, logs and 180-second failure are
retained. A separate type report verifies all actual identities, and the corrected
comparison explicitly checks integer dimensions and every original hash.

On the unchanged Windows production DLL and corrected host, all 14 headless
presentation actors now pass, including dedicated/custom/listen cases. The
unchanged performance workload (1/16 characters, 120 samples, original lifecycle
samples and 180-second actor bound) also completes. No graphical or allocator
event-count qualification is inferred from these headless results.

The first local Linux full attempt still fails DataStore admission because its
separate sub-runner overrides the selected profile root. `92659b` routes both
Godot writer profiles and native interruption-probe storage through the same
optional supported-storage selector. Logs/products stay on E:, and native
filesystem admission stays unchanged. Default paths are preserved, separate
projects are isolated, and reused named profiles fail rather than admitting
stale state; dedicated directory controls verify those properties. The original
failed attempt remains separate from the corrected full rerun.

### Qualification outcome and remaining blocker

**PARTIALLY QUALIFIED; GL-018 remains OPEN.** Qualified fixture/host inputs are
`92659bae6cc5d7b321b075848b905e9d660b47df`, with the same 89-input native source
fingerprint as starting branch tip `dfa700a`. This follow-up adds no production
GodotLuau source change. The [evidence manifest](evidence/gl018-binding-retirement/manifest.json)
indexes original-byte logs, diagnostic sources, failed attempts, downloaded CI
archives, host/build identities and independently verified reports. The raw ZIP
contains `raw-files.json`; every indexed entry was rehashed after collection.

| Fresh profile | Core | Native acceptance | Result |
| --- | --- | --- | --- |
| DockerPC Linux, corrected host, ASan/LSan, ext-family data | 80 | 110, strict checker passes | PASS |
| DockerPC Windows, corrected host, original Debug ASan DLL | 80 | Full attempt fails HTTP/utilities, DataStore and old text-asset presentation/performance | FAIL retained |
| DockerPC Windows, corrected binary-asset follow-up | Existing 80-case evidence | 14 presentation actors and original performance workload pass | Focused PASS |
| Hosted Linux, `92659b`, full-native ASan/LSan | 80 | 110, strict checker passes | PASS |
| Hosted Windows, `92659b`, full-native ASan | 80 | 87 actors in complete passing groups; DataStore group incomplete | FAIL |
| Hosted ordinary Windows/Linux Debug, `92659b` | 80 each | 110 each | PASS |

Local Linux verification checks all 406 summary-file hashes, 73 normalized fixture
inputs and 280 native log hashes. All ten animation authority actors complete:
510 cases and 1,006 assertions, including actual ENet transport. The injected
UAF and Linux leak controls are detected; engine-only, minimal reload, direct
production registration and five VM/module unload cycles exit cleanly. No
unexpected sanitizer report, leak, script failure, crash or timeout remains in
that complete profile. This is headless qualification, with no GPU/device claim.
Expected wrong-role RPC, ServerStorage and TLS rejection diagnostics remain
visible. Local asset preprocessing also reports unavailable fontconfig and ignored
OBJ ambient material settings; system-font/rendered appearance is not qualified.

The fresh hosted Windows profile passes its detection/unload gates, all HTTP and
HttpService groups, all Character/animation/presentation/performance groups and
all 80 core cases. Its increment B actor exhausts the eight-attempt conflict
budget, then fails its completion assertion. The strict checker rejects the
missing complete DataStore result; neither the group nor the full profile is
accepted. Its ten GL-020 actors still execute all 510 authority cases; their raw
JSON assertions are checked separately without changing that strict rejection.

A focused Windows diagnostic wraps the existing public `UpdateAsync` transform
to print attempts while leaving the original `IncrementAsync`, comparison,
backoff, helper and eight-attempt limit intact. One writer reads values 12
through 19 on eight consecutive attempts while the other commits. It then
raises `Conflict retry limit exceeded`; the other writer finishes. The wrapper
alters scheduling and is diagnostic evidence, not a qualification substitute.
This supports a bounded-conflict/fairness explanation. It does not establish a
lost update, memory fault, helper crash or incorrect successful acknowledgment.

ADR-005 explicitly permits conflict exhaustion. The current fixture nevertheless
requires both unsynchronized twenty-increment writers to complete all operations
and reach 40. Arbitrary interleaving cannot guarantee that with eight attempts.
Guaranteeing fair completion would require a separately reviewed persistence
admission/protocol change, or a separately approved qualification-contract change.
Neither belongs in this host-lifetime correction, and weakening the fixture,
increasing retries or rerunning until green would not resolve that conflict.
**The smallest next investigation is the two-writer increment fairness/acceptance
contract, followed by a complete Windows sanitizer rerun after its resolution.**

An investigative Windows Debug `/O1` build instruments all 1,160 translation
units with the matching compiler and keeps assertions enabled. Compared with
the unchanged `/Od` build on the same selected local data filesystem, both
DataStore groups pass, but both HTTP and HttpService groups fail frame/timing
checks. An earlier comparison omitted the compiler environment and caused
companion startup failures; that attempt is retained separately. The first
experimental core run also exceeds the unchanged ten-second watchdog while
writing its file-stress data on E:. A private diagnostic runner selecting C:
working data passes all 80 cases with the same watchdogs. Neither `/O1` nor that
private core-runner change is adopted: they do not demonstrate a reliable fix for
the remaining qualification failure. The 250 ms frame bound, helper deadlines,
retry count, test assertions and admitted build profile stay unchanged.

### Historical leak and diagnostic limitations

The original Linux report still records **29,400 bytes in 135 allocations**, with
15 leaked ObjectDB instances, after missing imported meshes and a null
`R6Animator` script error. Historical function symbolization identifies Node3D
construction, metadata and instance-binding allocation paths. Extension frames
are unavailable after unload; this does not identify one responsible source line.
The complete corrected Linux profile does not reproduce the leak. Two additional
sixteen-world controls, one with no rig assets and one with the original broken
remaps, free the worlds, drain deferred work and exit without LSan findings or
orphan-node output. Those controls explicitly clean up; they do not reproduce
every early script-error exit path of the historical performance fixture.
The historical leak remains unexplained beyond that narrowed setup/lifetime
association and is not suppressed or declared universally fixed.

A bounded GNU `objcopy` attempt on E: damaged a disposable diagnostic symbol copy.
The original cache and raw GDB logs were preserved. Recovery uses the original
host from the retained cache plus the complete GNU temporary symbol output;
read-only ELF parsing verifies identical `.text` virtual addresses, 110,388,560
text bytes and text SHA-256
`541cb19d172caed5b613f1e936599a989508574175b212de7f6fb058244a44bb2`.
Distinct full-file hashes and failed diagnostic attempts remain recorded.
This recovery supplies function names only, not fresh execution or DWARF lines.
An initial downloaded-harness audit also rejected Windows CRLF checkout bytes;
the final audit checks the exact Git input or its explicit Windows CRLF conversion
and separately verifies the normalized fixture identities. No runtime checker
or acceptance assertion is relaxed by either diagnostic correction.

### Hosted verification and retention

All observations are terminal, rather than pending jobs labeled successful:

| Source | Workflow | Actual outcome |
| --- | --- | --- |
| `0119017` | [Core 41396797875](https://github.com/gmoddev/GodotLuau/actions/runs/41396797875) | Windows/Linux 80 each |
| `0119017` | [Native 41396797859](https://github.com/gmoddev/GodotLuau/actions/runs/41396797859) | Windows/Linux 110 each |
| `0119017` | [Sanitizers 41396797854](https://github.com/gmoddev/GodotLuau/actions/runs/41396797854) | Both fail; unload controls pass; old asset/time/contention failures retained; Windows also rejects an old-life animation assertion |
| `92659b` | [Core 41400476513](https://github.com/gmoddev/GodotLuau/actions/runs/41400476513) | Windows/Linux 80 each |
| `92659b` | [Native 41400476618](https://github.com/gmoddev/GodotLuau/actions/runs/41400476618) | Windows/Linux 110 each |
| `92659b` | [Sanitizers 41400476522](https://github.com/gmoddev/GodotLuau/actions/runs/41400476522) | Linux full PASS; Windows FAIL at DataStore increments |

[Downloaded artifact verification](evidence/gl018-binding-retirement/latest-ci-verified.json)
records all eight new artifact IDs/archive hashes, complete report/log hashes,
source and fixture identities, ASan flags for every translation unit, matching
host/extension compiler identity, actual GL-020 case execution and reported
product hashes. Both core XML reports pass the existing strict discovery/output
checker. Both ordinary native artifacts and the full Linux sanitizer artifact
contain all 110 successful actor results. These evidence artifacts contain logs
and provenance, not distributable native binaries: reported hosted binary hashes
are not independently rehashed binaries or a reproducible-build claim.

Windows LSan, stock-host unload safety, arbitrary live hot-unload/custom binding
tokens, other engine/compiler profiles, GL-017, rendered/device/editor coverage,
allocation-event profiling and complete historical early-error leak attribution
remain outside acceptance. No fresh Windows/Linux Release profile is inferred
from these Debug sanitizer runs. Existing normal Release evidence stays separate.

All local execution uses DockerPC. Current warmed Linux host/native caches and
ext-family profile data are archived with hashes on E: before removal of only
the task-owned container and profile volume. Existing caches and failed attempts
remain. Task native build/test processes are stopped; unrelated container IDs and
states are checked unchanged. The recovered Docker backend had inherited the
task's SSH job. Exact job membership/handle checks allow clearing only that job's
kill-on-close dependency before closing the SSH control; Docker remains running.
No persistent SSH/service policy or fixture process-job limit changes. Main stays
`83cd0887968d73d61d050650718d8ada6e124579`, publication/updater remain disabled,
and upstream is untouched. Work stops at this partial qualification and concrete
persistence acceptance blocker, without merging or starting GL-017.
