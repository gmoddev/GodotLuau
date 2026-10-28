# Shared-domain implementation and qualification

## GL-013 first value-binding extraction

Branch `refactor/gl-013-luau-api-extraction` starts at verified local/remote main
`eb638bfa6ff16abc91d11742625b3cc034f53178`. This is one implementation extraction,
not a new runtime architecture; it is not merged into main.

### Source analysis and selected boundary

At this baseline `luau_api.h` contains 5,168 lines/290,353 LF bytes. Its free
functions have internal linkage (`static`, some also `inline`); LuauVector3's
class-body math methods are implicitly inline. `luau_script.h` includes it and
contains inline class implementation/registration. `luau_script.cpp` contributes
only the ordinary out-of-line `_get_language` definition. `luau_stdlib.h` owns a
TU-local embedded Lua program. `gl_runtime.h` supplies ObjectID wrappers, inline
compatibility bridges and existing state/hooks; VM ownership remains in
`GLExecutionDomain`/`GLDomainHost`, not in these value bindings.

The only direct `luau_api.h` include is `luau_script.h`. Its transitive consumers
include `luau_language.h`, `roblox_datamodel.h`, `rbx_importer.h` and three adapter
translation units: `luau_script.cpp`, `gl_domain_host.cpp`, `register_types.cpp`.
The last also performs Godot class registration. Broad includes bring gameplay,
services, networking and editor/importer dependencies into these units. Instance
index/newindex/methods depend directly on Godot types and domain-owned callbacks;
attribute watchers, classname buffers, virtual-container tables and replication
hooks retain their original TU/static ownership. No Luau private VM headers or
direct VM-structure access are used by the selected value functions: they call
the public Lua C API. Generic property conversion and Instance reflection stay
Godot-dependent in `luau_api.h`.

Native Vector3/Color3 is the first boundary because its allocation, type checking,
arithmetic and registration form a small cohesive subsystem with no Godot or
domain requirement. Instance dispatch would require a much wider cross-subsystem
interface; selecting it by line count would expand scope. Lua-backed CFrame,
Vector2, BrickColor and existing input-service value packing remain untouched.

`src/core/luau_value_bindings.h` is 31 lines/1,185 LF bytes: two existing layouts,
five existing native bridge declarations and two registration calls. It only
forward-declares `lua_State`. The 260-line/10,405-byte implementation includes its
own header first, public Luau headers and standard headers. It includes no large
implementation header, Godot type or domain host. Twelve callback functions stay
`static`; five bridge functions and the two new initialization functions have one
ordinary C++ definition. Five existing math member bodies move out of line.
All 17 moved free-function bodies compare exactly to baseline. No duplicate copy,
registry, abstract interface, shim, static initialization or new state is added.

`luau_api.h` now includes that declaration interface and is 4,946 lines/281,472
LF bytes, down 222 lines/8,881 bytes. Only its value implementation is removed.
`luau_script.h` replaces the two original registration blocks with calls at their
original positions. Metatable names, callback debug names, layouts, numeric
operations, stack effects and Lua-facing signatures are preserved; private bridge
linkage becomes shared within the extension. Godot class registration is unchanged.
The new include edge terminates at a forward declaration, adding no include cycle.
`roblox_input.h`'s pre-existing independent three-float packing remains a coupling
to the layout; this extraction does not change that service.

### Build and runtime qualification

Both existing build paths discover `src/core/*.cpp`: CMake's `CONFIGURE_DEPENDS`
glob and SCons' `Glob`. No build-file change is necessary. CMake actually compiles
and links the new unit on Windows/Linux Debug/Release. A Linux SCons `-n`
`platform=linux target=template_debug -j2` dry run explicitly lists the new unit;
this is source-discovery evidence, not a new SCons package qualification. Linux
`nm -C` confirms single registration/helper definitions and local math callbacks.

Measurements use the same task snapshot path, existing pinned-vendor build
objects, CMake/Ninja, two compiler jobs, MSVC 19.51.36260.0 on DockerPC and
GCC 13.3.0 in the task-owned Ubuntu container. A baseline archive of the starting
revision precedes edits. Candidate measurement deletes only snapshot/core-test
objects, retaining vendor objects. Cold figures include adapter and core-test
compilation/linking: six C++ units before, seven after. Header-touch figures
rebuild three adapter units in both versions. Touching the new implementation
rebuilds only that one unit. These are one trial per configuration, not statistical
performance claims; full dependency-clean rebuilds and peak compiler RSS are not
measured. Pinned dependency objects are deliberately warm in both comparisons.
Windows Debug is slower in this trial; no overall compile-speed improvement is
claimed. Exact seconds, object sizes, library sizes and warnings are in the
[evidence manifest](evidence/gl013-value-extraction-2026-10-27.json).

Reproduce with a baseline/candidate source snapshot under the same `<Source>`
and matching existing dependency build tree:

```text
cmake -S <PinnedWorkerSource>/tests/runtime -B <Build> -DGL_SOURCE_ROOT=<Source> -DGL_BUILD_CORE_TESTS=ON -DGL_BUILD_GODOT_ADAPTER=ON -DGL_BASELINE_SOURCE_ROOT=
cmake --build <Build> --target GodotLuauAdapter ExecutionDomainTests --parallel 2
ctest --test-dir <Build> --output-on-failure --verbose --timeout 30
```

Remove only the selected source/core-test objects for the extension-cold run;
retain dependency objects. Time each build using a monotonic wall clock; count
`Building CXX object` records. Touch only `luau_api.h`, rebuild/time, then in the
candidate touch only `luau_value_bindings.cpp` and rebuild/time. Record the active
adapter objects and extension byte sizes. Native runs use the existing
`RunQualification.py` commands above/below with `--teardown --coordinated-close`,
`--security` and `--animation` in separate fresh directories, timeout 60.

`Integration.gd` adds actual native constructor/constants/arithmetic/type-error,
Variant bridge round-trip, wrapper identity/destruction and fresh-domain checks;
both Server and Client run the value cases. Existing 39-case core, native loading,
owner teardown, reload, network and functional-animation gates remain intact.
An initial exploratory Part-backed fixture assumed one yield guaranteed deletion;
the baseline disproved that assumption. After bounded deletion observation it
passed assertions but Linux still exited -11 at shutdown with four ObjectDB
instances reported. Those baseline artifacts are retained at `gl013/baseline-values`
and `baseline-values-2`; no cause or fix is claimed. The final lightweight Beam
metadata bridge passes eight baseline Linux actors and exercises the selected
conversions without introducing physics resources. Baseline Windows also passes
eight actors with the earlier Part fixture after corrected deletion observation.
The final candidate fixture must pass on both platforms; a PASS marker alone
never overrides a nonzero exit.

Local qualification passes Windows/Linux Debug and Release: 39 production-core
cases in each configuration, actual GDExtension loading and all 28 required native
actors each (112 total). The final Beam/value fixture passes both platforms and
configurations, including fresh-domain initialization. Recorded native source
fingerprint is `ec0db95eb65d488a9b6a2037cffee8cc0d1b1cd83b2b12b7e5eabbc60af5ae41`
for 67 inputs; normalized changed-source/fixture hashes agree across workers and
the controlling checkout. Both workers retain the exact result/log/library hashes
in the manifest.

Implementation `83bc42d2bcea9d66d21cfd4d2df2650b6c87a06c` is pushed to the dedicated
branch. Fresh [core run 40626224165](https://github.com/gmoddev/GodotLuau/actions/runs/40626224165)
passes 39 cases on each hosted platform. Fresh
[native run 40626224232](https://github.com/gmoddev/GodotLuau/actions/runs/40626224232)
passes both actual Debug adapter builds, process checks, pinned Godot provisioning,
all 28 actors per platform and final summary/upload steps. Native completion takes
19m11s within the 25-minute observation bound. Hosted Windows uses MSVC
19.44.35229.0; Linux uses GCC 13.3.0. Both checkout logs confirm the unchanged pins.
Downloaded ZIP digests match hosted metadata; summaries match the exact commit,
67-input native fingerprint and extended fixture hash, with 8/10/10 zero-exit
actors and no production binary payload. These hosted elapsed times are not a
controlled baseline/candidate build-speed comparison.

Disposition: **FIRST EXTRACTION QUALIFIED** on the dedicated branch; main stays
at `eb638bfa6ff16abc91d11742625b3cc034f53178`. The final documentation/evidence-only
follow-up changes no tested input and claims no separate run. Worker source-root
configurations are restored; no test/Godot process remains, and the Linux task
container is stopped. The extraction is ready for review and a separately
authorized merge within this bounded scope. No merge is performed here.

| Configuration | Cold before/after seconds | API-header touch before/after seconds | New implementation touch seconds | Extension bytes before/after |
| --- | --- | --- | --- | --- |
| Windows Debug | 21.448 / 32.785 | 19.822 / 30.840 | 1.133 | 24,191,488 / 24,191,488 |
| Windows Release | 43.185 / 42.719 | 42.673 / 35.424 | 1.333 | 4,075,008 / 4,073,984 |
| Linux Debug | 22.692 / 22.649 | 21.841 / 21.749 | 1.116 | 78,957,184 / 78,938,272 |
| Linux Release | 41.574 / 41.824 | 40.321 / 40.471 | 0.565 | 12,519,496 / 12,515,920 |

No userdata/native
ownership rule changes, so no new sanitizer configuration is introduced. Existing
retained math closures still capture native value addresses under the inherited
semantics; safety across value collection is not established by this movement.
GL-003/004/005/007/009/010/011/017/018/020 limitations remain independent; no
dependency, updater, release or production publication behavior changes.

GL-013 stays open. Recommended next extraction for a separately authorized task:
the Godot Variant/property-conversion helpers, after defining their interface to
these values and the Instance bridge. The large Instance index/newindex dispatch
and header-heavy service/editor dependencies remain; no second extraction starts.

### First extraction main integration (2026-10-28)

Starting main `eb638bfa6ff16abc91d11742625b3cc034f53178`; qualified source
`1c9f4c6296bc955a6a5969a6da0668d137e46ed1`. Normal merge
`bdd57fd3097537bb1cf0f8a0b7c08ae7e312d0d7` preserves implementation `83bc42d`
and its evidence-only follow-up `1c9f4c6`, without conflicts. Its tree exactly
equals qualified source. The branch remains a historical reference.

Fresh checks inspect the actual diff, two-commit ancestry, unchanged normalized
source/fixture hashes and registration calls, declaration-only value interface,
single implementation and CMake/SCons source globs. Publication remains
dispatch-only/read-only with both release jobs false; updater admission remains
literal false. JSON/diff/source identity checks pass. No local native matrix is
repeated: the exact tested inputs retain the Windows/Linux Debug/Release and
hosted qualification recorded above. Historical limitations remain unchanged.

The merge is pushed and remote main read back. Fresh automatic
[core run 40629813359](https://github.com/gmoddev/GodotLuau/actions/runs/40629813359)
and [native run 40629813337](https://github.com/gmoddev/GodotLuau/actions/runs/40629813337)
target that merge. Initial observation is bounded at 90 seconds; pending jobs
are not assumed successful. Their later results may be recorded alongside the
authorized second extraction. Integration documentation changes no tested input.
GL-013 remains open; one further extraction is separately authorized on a new
branch from verified integrated main, without permission to merge that work.

Fresh main observation subsequently completes during Stage 2: both core jobs pass
39 cases per platform; both native jobs pass actual Debug adapter builds, process
checks and all 28 actors each, including final completeness checks. Native job logs
`122623327125` (Windows) and `122623327392` (Linux) confirm the 28-result PASS.
Both workflows target merge `bdd57fd`; canonical main `174efcc` changes documentation
only. Disposition: **INTEGRATED AND VERIFIED**. These are fresh main results,
distinct from reused source qualification. Existing limitations remain unchanged.

## GL-013 second generic Variant extraction

Stage 2 starts from verified integrated main
`174efcc2bdb59c5072ba21d27645c5380c61e8e9` on
`refactor/gl-013-variant-bindings`, not the historical first-extraction branch.
Its scope is only generic Luau/Godot value conversion; the branch is not merged.

### Selection, dependencies and preserved contracts

`gl_luau_to_variant` and `gl_variant_to_luau` were static free-function definitions
in `luau_api.h`, duplicated per including translation unit. Their only direct
consumers are the generic property read/write paths in that header: two reverse
conversion sites and one forward conversion site. They use public Luau calls,
Godot value types and the first extraction's exact-metatable checks/allocation.
They neither resolve native objects nor access VM internals, domain ownership,
callbacks or mutable static state. Registration remains entirely with existing
domain/value initialization; conversion needs the same already-created metatables.

`gl_has_property` inspects Godot Object property lists and remains TU-local with
Instance dispatch. Read/write dispatch also owns native liveness checks via
`gow_node`, property lookup/set/get, metadata fallbacks, table-Offset handling and
invalid-member errors. Those functions are not generic conversion and are not
moved together just because they shared a header. A larger Instance/property
adapter would require broader lifetime/dispatch contracts; it is rejected for
this extraction. A new collection/object conversion framework is also rejected:
the existing generic helper intentionally does not support those types.

The new `luau_variant_bindings.h` has only forward declarations for `lua_State`
and `godot::Variant`, and the two existing boolean function signatures. Its
implementation includes that header first, `luau_value_bindings.h`, public Lua,
Godot Variant/String/Vector3/Color and cstdint headers. It includes no Node, ObjectID
wrapper, service, domain, `luau_script.h` or `luau_api.h`. Dependencies point from
Instance dispatch to conversion to value helpers, with no reverse include cycle.
The value module remains Godot-free. The two bodies are byte-for-byte unchanged;
only their internal-to-TU linkage becomes one ordinary definition each. No new
registration, static initialization, state, public Lua API or ownership rule exists.

Forward conversion accepts numbers as Godot double, bool, strings and exact
Vector3/Color3 userdata. Reverse conversion accepts BOOL/INT/FLOAT/STRING/VECTOR3/
COLOR and retains double numeric semantics. Unsupported conversion returns false:
forward leaves the output and stack unchanged, reverse pushes nothing. The
Instance caller preserves existing ignored writes, table-Offset fallback and
invalid-member errors. Arrays/dictionaries/Instances are not newly supported.

The baseline fixture initially expected unsupported reads to return nil; both
workers showed the existing invalid-member error instead. A second initial
expectation of non-ASCII string round-trip equality also failed: pinned
godot-cpp `src/variant/char_string.cpp:159-160` implements `String(const char*)`
with `string_new_with_latin1_chars`. Thus Lua UTF-8 bytes for `héλ` return as
`hÃ©Î»`; native Godot strings still return UTF-8 correctly. Both behaviors are
preserved explicitly by golden assertions, without an encoding fix. Initial
failure artifacts remain in `gl013-variant/baseline-conversions` and
`baseline-conversions-2`; the corrected fixture passes all eight baseline actors
on both platforms at `baseline-conversions-3`. No runtime logic changed to obtain
those passes. Existing first-extraction math/physics limitations remain separate.

`Integration.gd` extends the existing Server/Client cases with native INT/BOOL/
FLOAT/STRING/VECTOR3/COLOR reads; numeric, boolean and string writes; retained
vector/color round trips; nil/unsupported table, array, function, userdata and
live/destroyed Instance rejection preserving the prior value; table-Offset
fallback; reflected integer property access; and caught error propagation.
Existing wrapper destruction and fresh-domain checks remain. These are real
production property/converter calls, not a mock or duplicate implementation.

### Measurements and qualification

Baseline source is archived before implementation to an isolated task snapshot;
the same snapshot path, worker hardware, pinned dependencies, compiler/configuration
and two build jobs are used before/after. Pinned vendor objects stay warm; task
adapter/core objects are cold for each cold measurement. Baseline compiles five
adapter plus two core-test units; candidate adds one converter unit. API-header
touch still rebuilds three adapter units; converter-implementation touch is measured
separately. Object and extension sizes, warnings, exact results/log hashes and
limitations are recorded in the
[second extraction manifest](evidence/gl013-variant-extraction-2026-10-28.json).
Previous measurements remain historical and are not overwritten. Full dependency-
clean time and peak compiler RSS are not measured; a single trial establishes no
general speed claim.

Local Windows/Linux Debug and Release builds pass, each with 39 core cases and
all 28 required native actors (112 total); both final baseline conversion runs
also pass eight actors. Native source fingerprint is
`24dd210d77dade0a6ae5279402f4c31c61d57049636f6a505b1a4e3934b08f17` for 69 inputs.
Changed source/fixture hashes match both workers and this checkout. CMake compiles
and links the new unit in all four configurations; Linux SCons dry-run discovery
lists it, and `nm -C` shows exactly one definition of each converter. Both build
systems retain their existing `src/core/*.cpp` discovery; no new build configuration
or workflow is needed. The API header decreases from 281,472 bytes/4,946 lines to
280,183 bytes/4,923 lines; the interface is 688 bytes/15 lines and implementation
1,601 bytes/36 lines, using normalized LF bytes.

| Configuration | Dependency-warm cold before/after seconds | API-header touch before/after seconds | Converter touch seconds | Extension bytes before/after |
| --- | --- | --- | --- | --- |
| Windows Debug | 21.118 / 25.409 | 19.307 / 23.181 | 1.023 | 24,192,000 / 24,192,000 |
| Windows Release | 31.639 / 34.776 | 30.746 / 32.462 | 1.361 | 4,073,984 / 4,073,984 |
| Linux Debug | 22.692 / 22.792 | 21.691 / 21.742 | 1.165 | 78,938,368 / 79,034,768 |
| Linux Release | 41.722 / 41.924 | 40.270 / 40.421 | 0.564 | 12,515,920 / 12,516,144 |

These single samples demonstrate a one-unit implementation edit boundary, not
overall faster compilation or smaller binaries. Exact object sizes are retained
in the manifest. Reproduction uses the first extraction's commands with the new snapshot
and `luau_variant_bindings.cpp` as the implementation-touch input. Both Windows/
Linux Debug and Release core/native gates pass; existing hosted core/native Debug
qualification completes on implementation `5f72f4cda1c5e3bb76edd33bb11e276cff07ac10`:
[core run 40631078253](https://github.com/gmoddev/GodotLuau/actions/runs/40631078253)
passes 39 cases per platform; [native run 40631078251](https://github.com/gmoddev/GodotLuau/actions/runs/40631078251)
passes both fresh actual Debug builds, process checks, verified Godot provisioning,
all 28 actors per platform and final completeness/uploads. Native run time is
19m13s, within the 25-minute observation bound. Both checkout logs confirm exact
dependency pins. Downloaded diagnostic ZIP digests match metadata; summaries
verify the tested commit,69-input fingerprint and extended fixture hash, with
exact8/10/10 groups and zero actor exits. No binaries are published or uploaded.

Disposition: **SECOND EXTRACTION QUALIFIED**. The branch is ready for review within
its bounded scope and remains unmerged; remote main stays `174efcc2bdb59c5072ba21d27645c5380c61e8e9`.
The final evidence-only follow-up changes no tested input and claims no additional
run. Worker Debug/Release source-root settings are restored; no task-owned test/
Godot process remains, and the Linux task container is stopped. No new sanitizer configuration is justified
by this ownership-preserving movement.

GL-013 remains open. The next separately authorized candidate is a bounded Instance
reflection adapter around `gl_has_property`, after mapping property/fallback and
lifetime contracts. Broad Instance dispatch and service/editor header dependencies
remain. No third extraction or unrelated runtime/dependency/publication change is
part of this task.

## GL-011 independent core CI (2026-10-27)

Branch `ci/gl-011-core-qualification` starts at canonical main
`f8681c32fc45c9a9f543fb09495768bf3ebfe8e6`, after GL-012 and GL-016 integration.
The original branch qualification below precedes the main integration recorded
at the end of this milestone. The independent workflow runs only the existing production
`ExecutionDomainTests` target (one CTest entry, 39 internal regression cases).
There is no runtime/native source, ownership, pin or wire-format change.
The [test instructions](../tests/runtime/README.md#independent-core-ci-gl-011)
give portable commands and all timeouts. The matrix selects hosted Windows 2022
with Visual Studio 17 2022/MSVC and Ubuntu 24.04 with Ninja/GCC, using existing
runner tools. No package installation or toolchain upgrade step is added.

The workflow explicitly grants `contents: read`, checks out pinned submodules
recursively without persisted credentials, and has no secrets, repository writes,
release/deploy/updater operation or dependency on the disabled publisher. Relevant
pushes/PRs and manual dispatch are declared. Bash error/pipefail handling preserves
configuration, build and CTest failures while capturing logs. Missing/mismatched
dependencies, zero/wrong CTest discovery, execution errors/timeouts and missing,
partial, failed or skipped 39-case results fail qualification. JUnit, discovery,
logs and CMake diagnostics are retained seven days, excluding binaries. No test
retry is configured. This is an independent development signal; branch protection
and release enforcement are not changed.

Fresh equivalent worker checks pass on Linux GCC 13.3/Ninja and Windows MSVC
19.51/Ninja, Debug, with two build jobs: configure, build, CTest discovery and all
39 cases, followed by the same evidence checker. Windows uses its existing worker
developer environment; these paths/generator are not copied into hosted CI.
Outputs are `/opt/codex/godotluau/builds/gl011-core-ci-2` and
`C:\Sandbox\Codex\Builds\GodotLuau\gl011-core-ci-msvc3`. Real Linux discovery/JUnit
also drive 16 local negative evidence checks (zero/wrong/extra discovery, malformed
JSON/XML, missing file/test, errors/failures/skips, wrong status/name and incomplete
completion). Parsed YAML checks confirm matrix, triggers, read-only permissions,
step/job deadlines and diagnostic-only upload. The inherited publisher remains
dispatch-only with both jobs disabled and no persisted credentials.

The first Linux run passed all cases but CTest truncated the JUnit passed output
at 1024 bytes, which the checker correctly rejected. Both success/failure retained
output limits are now 65536 bytes. Windows worker wrappers initially failed on
shell quoting and lost compiler/SDK PATH state before configuration; the corrected
wrapper preserves the existing developer environment. An intermediate GNU/Windows
build also passed 39 cases but is not substituted for MSVC evidence. Original
attempt directories/logs are preserved; no failing production test was retried
without a concrete harness correction.

The first hosted push at implementation `2f1c8199e5b47c9cfad4304f21b785317796ed4d`
completes successfully in [Actions run 40475254435](https://github.com/gmoddev/GodotLuau/actions/runs/40475254435),
2026-10-27 08:41:22–08:42:31 UTC. Both jobs pass recursive pinned checkout,
configuration, compilation, exact CTest discovery, all 39 cases and report
validation. `Core (Windows, Debug)` uses MSVC 19.44.35229.0/Visual Studio 17 2022;
`Core (Linux, Debug)` uses GCC 13.3.0/Ninja. This is actual hosted execution,
separate from the equivalent worker runs. No hosted retry or workflow defect
correction is needed. Diagnostic uploads succeed: Windows artifact 12721115200
(9776 bytes), Linux artifact 12719944156 (11214 bytes); both expire after seven
days. The [manifest](evidence/gl011-core-ci-2026-10-27.json) retains run/job IDs,
artifact digests, source/report hashes and limits beyond that retention period.
The subsequent evidence-only commit changes no workflow, checker, test, core
source or dependency input; it does not claim another hosted run.

Configuration semantics follow [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
and [CTest's documented discovery, no-tests and JUnit options](https://cmake.org/cmake/help/latest/manual/ctest.1.html).
All 65 normalized native inputs remain at fingerprint
`a954a5541435b37246d6010e8384b21a579a420b950b25a64d6db944daad76dd`, matching main
and both workers. Read-only Actions queries observe zero push runs at both
post-integration main checkpoints (`73634b7e41081d5f149012b0df055949c6180bbe` and
`f8681c32fc45c9a9f543fb09495768bf3ebfe8e6`); the publisher was never dispatched.

The original branch disposition was **OPEN; IMPLEMENTED — REVIEW PENDING**.
Native Godot integration, multiplayer/lifecycle fixtures, security rejection,
sanitizers, persistence failure coverage and enforced release gates remain manual
or independently incomplete. GL-010 provenance and GL-020 adversarial animation
qualification are not resolved or executed by this workflow.

### GL-011A main integration

Starting main `f8681c32fc45c9a9f543fb09495768bf3ebfe8e6`; normal merge
`f0199004d56485ec7a9de14d5454d1907822ba11` preserves both source commits,
ending at `95167299ad8a102b23fb3b25284a751483815779`. The merge has the exact
qualified branch tree. The evidence-only source commit changes no CI/runtime/test
or pinned dependency input. Parsed workflow/permission/trigger/deadline checks
pass, and the updater remains fail-closed while both publishing jobs remain
disabled. No release workflow is dispatched or repository protection changed.

The main push triggers [run 40476321167](https://github.com/gmoddev/GodotLuau/actions/runs/40476321167)
at the merge revision, completed **successfully** from 08:50:22 to 08:51:24 UTC
(62 seconds). Windows job 122095323119 and Linux job 122095323702 each pass
configuration, production-core compilation, exact discovery, **39 passed / 0
failed**, and report validation. Diagnostic upload succeeds for both jobs.
The existing [manifest](evidence/gl011-core-ci-2026-10-27.json) adds separate
integration run/job/artifact identities and digests, retaining the original
branch evidence. A following documentation-only commit changes none of these
tested inputs. Disposition: **INTEGRATED AND VERIFIED** for GL-011A; GL-011 stays
open for native integration, sanitizers and enforced release gates.

## GL-011B native CI (2026-10-27)

Branch `ci/gl-011-native-integration` starts at verified canonical main
`db132e45607056cf23c024599f95ed37deac09bd`, after GL-011A integration. It is
originally **NATIVE CI IMPLEMENTED AND HOSTED-QUALIFIED** on that branch. Main
integration is recorded below; the original qualification is preserved. The separate native
workflow builds the production adapter in Debug on hosted Windows 2022/MSVC and
Ubuntu 24.04/GCC using the existing CMake target, unchanged Luau/godot-cpp pins
and two build jobs. No native implementation or existing GDScript fixture changes.
The [test instructions](../tests/runtime/README.md#native-ci-gl-011b) record exact
portable commands, actor groups, deadlines and diagnostic retention.

Godot provisioning is pinned to the [official 4.7.1 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.1-stable).
The official release API supplies asset IDs, byte sizes and SHA-256 digests,
recorded in `GodotDistribution.json`; it does not grant permission to dynamically
trust replacement bytes at a mutable tag. Before executing anything the helper
requires the recorded archive size/digest, extracts only the named executable,
checks `4.7.1.stable.official.a13da4feb` and records executable SHA-256. The
[official source tag](https://github.com/godotengine/godot/tree/4.7.1-stable)
resolves to `a13da4feb8d8aefc283c3763d33a2f170a18d541`, matching the manual
qualification baseline. No fallback to another engine version or unverified
worker binary is allowed. Downloads have bounded reads and a total deadline.

Existing `RunQualification.py` is reused for 28 processes per platform: eight
registration/script/module/native/lifecycle/network processes across single-player,
listen, dedicated and editor; ten existing GL-006/008 security/regression actors;
ten existing functional animation actors. The fixture assertions, transport and
coordinated-close logic are unchanged. Full GL-020 adversarial animation
qualification remains deferred. Exact actor labels/counts and successful exits
are required by the summary checker; required PASS markers and failure/sanitizer
diagnostics are enforced by the runner itself.

The directly required launcher correction gives each fixture a POSIX session or
Windows kill-on-close job, closes output handles on partial startup, and retires
owned descendants even when their parent exits normally. Group cleanup runs on
normal/failure/timeout/partial-startup paths and process exit/interruption.
SIGTERM unwinds the runner; Windows job handles also close when its process dies.
Child profiles/output trees are isolated, fresh output is required, and Windows
crash/error dialogs remain suppressed. Existing ephemeral ports and 25575
preflight remain intact. Raw stderr and ENet diagnostics are retained; no broad
error suppression or ignored failure is added. Eight actual launcher regressions
cover tree termination and missing PASS/failure/nonzero/sanitizer rejection.

Fresh equivalent worker checks pass on both platforms, including official
download verification, all eight launcher checks and all 28 native actors. Cached
Debug adapter builds report no work after CMake reconfiguration: native inputs
are unchanged at fingerprint `a954a5541435b37246d6010e8384b21a579a420b950b25a64d6db944daad76dd`.
This reuses existing compiled native code with verified source identity; it is not
presented as a fresh full compilation. Logs/results remain at Windows
`C:\Sandbox\Codex\Builds\GodotLuau\gl011-native-ci-1` and Linux
`/opt/codex/godotluau/artifacts/gl011-native-ci-1`. Expected ServerStorage denials
and RPC authority rejection diagnostics remain visible. No zero-channel ENet
diagnostic appears in these ordered-close runs; GL-017 remains independently open.

### Hosted native results

Implementation `216066131b64bdd81efdd48cedc04277e5a74919` passes on the first
hosted attempt in [run 40478173463](https://github.com/gmoddev/GodotLuau/actions/runs/40478173463),
09:05:36–09:21:08 UTC (15m32s workflow wall time). Both platforms compile the
actual Debug GDExtension from a fresh checkout/build tree, verify the official
engine archive/version, pass all eight launcher regressions, and complete **28
native process results each** (8 lifecycle/network + 10 GL-006/008 + 10 functional
animation). Incomplete groups cannot pass. No hosted retry or code correction is
needed. The separate [core run 40478173545](https://github.com/gmoddev/GodotLuau/actions/runs/40478173545)
also succeeds on that implementation push; core CI itself remains unchanged.

| Hosted job | Compiler / generator | Total | Native build | Fixture groups |
| --- | --- | --- | --- | --- |
| Windows 2022 Debug | MSVC 19.44.35229.0 / Visual Studio 17 2022 | 15m28s | 13m53s | 10s + 18s + 16s |
| Ubuntu 24.04 Debug | GCC 13.3.0 / Ninja | 9m52s | 8m53s | 9s + 17s + 14s |

Cold compilation dominates: the Linux log records 970 godot-cpp binding units,
53 Luau units and four production core units. Official engine provisioning takes
three seconds on Windows and one on Linux. The Windows job explicitly discovers
the existing VS Debug CRT with `vswhere` and exposes its directory to fixture
children; it installs no runtime package or toolchain. No build cache is introduced
for this first independently verified milestone. A later cache should target the
costly binding build and bind OS/image, compiler, pins, configuration and source
identity; it must not silently substitute stale output.

Diagnostic artifact 12722526926 (Windows, 45665 bytes) and 12722041865 (Linux,
50512 bytes) upload successfully with seven-day retention. Both ZIP downloads are
verified against GitHub's artifact SHA-256 digests and inspected: 84/82 files,
respectively, with no DLL, SO, executable or package ZIP payload. Their summaries
record all 28 actors, exact implementation revision, engine/library hashes and
matching harness hashes. Both retain fingerprint
`a954a5541435b37246d6010e8384b21a579a420b950b25a64d6db944daad76dd` for all 65 native
inputs. No zero-channel ENet diagnostic appears; expected ServerStorage and RPC
authority rejection errors remain in raw stderr and structured results. GL-017
is not closed by the ordered-close matrix.

The [native manifest](evidence/gl011-native-ci-2026-10-27.json) preserves source,
pin, official engine, job/step timing, artifact/summary digest and worker identities.
The final evidence-only follow-up changes no hosted-tested workflow, helper,
fixture, native source or pin and claims no additional hosted run. That branch
checkpoint was left unmerged until the authorized integration below.

### GL-011B main integration

Starting main `db132e45607056cf23c024599f95ed37deac09bd`; qualified source
`cebc64919e4fbf67624b19e075f31ef25941d136`. Conflict-free normal merge
`9029d01a24d904deaa1ecd7a9c30fc483e13757f` preserves both source commits
(`216066131b64bdd81efdd48cedc04277e5a74919`, then its evidence-only follow-up).
The merge tree exactly equals qualified source. Integration notes change only
existing documentation/evidence; all runtime/build/test/workflow inputs and pins
retain their qualified identity. The source branch is retained.

Fresh lightweight checks validate both workflow YAML structures, Windows/Linux
matrices, recursive checkout/no persisted credentials, read-only permissions,
existing core/native targets, exact recorded harness hashes, Python syntax and
all 65 native input fingerprints. Publication remains dispatch-only with both
jobs disabled, and runtime updater admission remains literal false. Diff/graph
review contains no unrelated files or generated production artifacts.

Hosted [run 40478173463](https://github.com/gmoddev/GodotLuau/actions/runs/40478173463)
is rechecked as successful at the unchanged implementation: two fresh Debug
adapter builds, 28 native actors and eight launcher checks per platform. It is
reused within that documented scope, not presented as a fresh integration run.
No expensive local matrix, engine download, worker job, new configuration or
manual workflow dispatch is started. Automatically triggered integration CI is
observed for at most 90 seconds; its completion/pending state is reported at task
completion, without inferring success. Disposition: **INTEGRATED AND VERIFIED**
for the source-identical integration. GL-011 and GL-007/010/017/018/020 remain
open within their existing scopes. Publication and updater distribution stay
disabled. This completes the authorized session; no further development begins.

### Linux process-liveness correction (2026-10-27)

Starting main `dcc4b4c2bbe948d2d9a792991c02331b32bc5033` failed Linux
[native run 40483447902](https://github.com/gmoddev/GodotLuau/actions/runs/40483447902),
job `122119224290`, in `test_partial_startup_failure_cleans_prior_actor`:
`/proc/2658/stat` disappeared between `exists()` and `read_text()`.
The Windows job passed; Linux provisioning, compilation and native fixtures were
skipped. Prior successful source qualification remains historical evidence.

`fix/ci-proc-liveness-race` replaces that precheck with one Linux proc-stat read.
Only `FileNotFoundError`/`ProcessLookupError` indicate disappearance; zombie
detection and the subsequent zero-signal probe remain, including termination
between read and probe. Permission and unrelated I/O errors propagate. Windows
liveness, tree ownership, deadlines and all existing assertions are unchanged.

Six deterministic Linux tests cover the original race, ESRCH during read, zombie,
running process, disappearance during the subsequent probe and unexpected errors
at both operations. Running the new race test against the starting helper
reproduces `FileNotFoundError`; the corrected complete suite passes all 14 Linux
tests (0.257s). Windows passes the original eight with six Linux-only skips
(0.603s). Commands: Python 3.12 `tests/runtime/FixtureProcessTests.py` on DockerPC
and the task-owned Linux qualification container; baseline reproduction uses an
ignored harness substituting the original helper. Controller `python -m
py_compile tests/runtime/FixtureProcessTests.py` and `git diff --check` pass.
No local native rebuild is needed or performed.

Correction `a6411da5b1ac4f79e9f0b6163fb78827157863a1` is preserved by normal
merge `995401b03335bca26eb8e1b62d52848f89a69e1e`, pushed to fork main. The branch
is retained. Fresh [core run 40618765032](https://github.com/gmoddev/GodotLuau/actions/runs/40618765032)
passes 39 cases on each platform. Fresh [native run 40618765012](https://github.com/gmoddev/GodotLuau/actions/runs/40618765012)
passes both Debug jobs: complete process suites (Linux 14; Windows eight plus six
Linux-only skips), verified Godot provisioning, actual adapter builds, all three
fixture groups, final 28-actor checks and diagnostic uploads. Native elapsed run
time is 18m38s, completing within the 20-minute observation bound; no retry or
manual dispatch occurs. These runs target the corrected merge, not the old SHA.

Both downloaded diagnostic ZIP digests match hosted metadata; their summaries
identify the corrected helper hash and unchanged 65-input native fingerprint,
exactly 8/10/10 actors with zero exit codes, and no production binary payload.
Worker inspection finds no surviving test Python children; the Linux task
container is restored to stopped. AST comparison confirms every original test
method and Windows liveness branch unchanged. Disposition:
**FIXED AND HOSTED-VERIFIED**. The final evidence-only commit changes no tested
input and does not claim a separate run. The
[existing manifest](evidence/gl011-native-ci-2026-10-27.json) records correction
identity and results separately from historical qualification. GL-011 remains
open for sanitizer/release enforcement; all other recorded limitations and
disabled publication/updater policy remain unchanged.

### Sanitizer expansion assessment

No sanitizer job is added to routine CI. The existing full-native Linux ASan/LSan
qualification uses a matching instrumented Godot host built from the pinned
source, minimal headless modules and compiler/runtime settings; stock Godot's
RTLD_DEEPBIND loader is incompatible with simply preloading ASan. Its earlier
task container has a 10 GiB memory bound. The inspected official release lists
34 assets and no instrumented host. There is no separately qualified immutable
host artifact available to these hosted jobs. Rebuilding the instrumented engine
on every ordinary push would add a separate engine compilation and provenance
pipeline; no hosted sanitizer build time or resource claim is fabricated here.

The recommended later milestone is a separately triggered Linux instrumented-host
build with recorded source/compiler/configuration and verified reusable artifact
identity, followed by a bounded native ASan/LSan lifecycle job. Cache/admission
keys must bind engine revision, compiler/runtime, image, build options and native
inputs as appropriate; an ordinary stock executable is not equivalent. GL-018's
Windows sanitizer-host gap and the minimal host's graphics/physics limitations
remain unchanged. Current CI is Debug/native functional coverage, manual Linux
full-native sanitizer evidence remains manual, release-gate enforcement is absent,
and GL-010 provenance and GL-011's broader closure requirements stay open.

## Original shared-domain qualification

Date: 2026-10-26. Starting revision:
`8b163269cbe44cf7fcf7a9a0285620878a2345fd`.
Branch: `runtime/shared-domains` in the public `gmoddev/GodotLuau` fork.
Tested implementation commit:
[`521265c338fc890a0e30b9e8a556f6346baf7d00`](https://github.com/gmoddev/GodotLuau/commit/521265c338fc890a0e30b9e8a556f6346baf7d00).
The follow-up qualification commit only records this immutable identity; runtime
and fixture sources are unchanged from the exercised implementation.
The decision precedes implementation in [ADR-001](adr-001-shared-execution-domains.md).
[The work log](shared-domains-work-log.md) records investigation, failed checks
and fixes as they occurred. This report distinguishes implemented behavior from
production qualification; GL-014 remains open for the latter.

The sections through "Limits and remaining work" below are the preserved initial
report. The [continuation qualification](#continuation-qualification-2026-10-26)
records subsequent fixes, measurements and the current readiness decision.

## Build environment and reproduction

Pinned dependencies were initialized without modification: godot-cpp
`d5cc777a89d899665fb61f1650ef0dc0cf6488c4`, Luau
`9e2984fd0334414a2ef62ceede0c06dab7574d55`. Native work ran over SSH on
`dockerbox`/`HOSTPC`, workspace `C:\Sandbox\Codex\Workspaces\GodotLuau`, with
MSVC 19.51.36260, CMake 3.31.10, Ninja, existing controlled Python 3.12.6 and
`--parallel 4`. Existing dependency/object caches were retained. No toolchain was
installed, no worker machine settings changed, and no sustained native build ran
on the controlling PC.

Exact configure/build/test and local fixture commands are in
[tests/runtime/README.md](../tests/runtime/README.md). On this worker CMake/CTest
resolve to `C:\Sandbox\Codex\Tools\cmake-3.31.10\cmake-3.31.10-windows-x86_64\bin`;
the developer environment is initialized with
`C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat`.
Debug and ASan use separate build directories under
`C:\Sandbox\Codex\Builds\GodotLuau`. Final build logs are under
`C:\Sandbox\Codex\Logs\GodotLuau\shared-domains-final-qualification.log`.

Native fixtures use the existing Godot `4.7.1.stable.official.a13da4feb` executable
and the pinned Godot 4.3 binding API. Test processes are headless, hidden, bounded
to 30 seconds, and capture stdout/stderr with crash UI suppression. The isolated
project excludes the updater; inherited release automation was not dispatched.
These checks do not establish compatibility with every Godot 4.x version.

## Final executed results

| Check | Observed result |
| --- | --- |
| MSVC Debug adapter/core incremental build, parallel 4 | Exit 0; actual production extension linked |
| Debug CTest `ExecutionDomains`, timeout 30 | 1/1 target, 35 cases passed, 0 failed; 0.22 seconds |
| MSVC ASan core build and CTest, timeout 30 | Exit 0; 1/1 target, 35 cases passed, 0 failed; 0.71 seconds |
| `RunIntegration.ps1`, timeout 30 | Exit 0; PASS; required five-second child-wait warning/stack followed by successful continuation |
| `RunNetworkIntegration.ps1 -Mode Listen` | Exit 0; listen PASS; both domains remain separate |
| `RunNetworkIntegration.ps1 -Mode Dedicated` | Exit 0; server plus both clients PASS |
| `RunNetworkIntegration.ps1 -Mode Editor` | Exit 0; server plus both clients PASS using inherited editor flags |
| Build input synchronization | SHA256 matched all 22 changed/new production files plus test CMake/CPP between local checkout and worker |
| Documentation/diff checks | 11 policy/documentation files checked for local Markdown link targets; `git diff --check` passed |

Final locally exercised DLL SHA256:
`25C1EC0898FAEEC453F63043D5B99D8702C75CF62B0416A14A35A35934081358`.
The DLL remains an ignored qualification artifact at
`.runtime-tests/artifacts/godot_luau.dll`, not a distributed release.
Local evidence: `.runtime-tests/artifacts/core-debug.log`, `core-asan.log`,
`shared-domains-final-qualification.log`; isolated project/logs at
`.runtime-tests/final-integration`. Network logs were preserved separately in
`.runtime-tests/artifacts/network-Listen`, `network-Dedicated`, `network-Editor`
before the next mode could overwrite process labels. Final modes passed with
expected ServerStorage denials; earlier passing runs' ENet diagnostics remain
recorded under limits rather than being reclassified as fixed.

## Source boundaries

| Boundary | Changed production files |
| --- | --- |
| VM, environments, modules, scheduler, references | `src/core/gl_execution_domain.h`, `src/core/gl_execution_domain.cpp` (new) |
| Scene host, roles, native condition queues/cleanup | `src/core/gl_domain_host.h`, `src/core/gl_domain_host.cpp` (new) |
| Script bootstrap, wrappers, error/response bridges | `src/core/luau_script.h`, `luau_api.h`, `gl_runtime.h`, `gl_errors.h`, `gl_net_bridge.h`, `register_types.cpp` |
| Shared Lua services and subscriber ownership | `src/core/luau_stdlib.h` |
| Native services, network callbacks and invoke cancellation | `src/services/roblox_services.h`, `roblox_network.h` |
| Remotes and gameplay callback dispatch | `src/gameplay/roblox_remote.h`, `roblox_animation.h`, `roblox_input.h`, `roblox_interactive.h`, `roblox_tween.h` |
| Character/physics callbacks | `src/characters/humanoid.h`, `roblox_part.h` |
| UI callbacks | `src/ui/roblox_gui.h`, `roblox_billboard.h` |

`tests/runtime` contains production-core C++ tests, an optional native adapter
build, GDScript fixtures, bounded PowerShell runners and reproduction instructions.
No persistence/wire-format redesign, dependency upgrade, updater rewrite or
generated distribution artifact is included.

## Implemented acceptance coverage

| Area | Executable evidence |
| --- | --- |
| Domain/cache identity | Server A/B and Client A/B share results with explicit A-before-B ordering; Server/Client results and VMs are independent |
| Module loading | Concurrent and yielding initialization once; false/scalars/functions/tables; direct/indirect/concurrent dependency cycles; invalid return counts; sticky errors; unrelated scripts survive |
| Invalidation | Native module rename preserves identity; source reload affects both caches; destroy/replace produces fresh values; pending invalidation wakes errors; first-caller destruction does not cancel the initializer |
| Environments | Own script/module globals and script identity across yields; deliberate domain `_G`/shared; explicit getfenv/setfenv behavior; mutable compatibility context flags do not change native role |
| Scheduler | Spawn/defer/delay/wait arguments; external callbacks that yield; bounded 256-module/200-spawn chains; manually resumed coroutines adopting waits; cancellation and completed-thread guards |
| Ownership/lifecycle | Disable/reload/re-enable, pending child/signal/invoke waits, callback self-destruction, owner-bound Lua services, non-aliasing references, detached native wait source, fresh scene domains |
| Repetition/shutdown | 100 owner create/cancel/GC cycles, 20 domain initialize/shutdown cycles, finite close-hook snapshot with admission closed, repeated native script teardown |
| Roles/processes | Single-player both domains; listen-host separate domain caches; dedicated Server and two remote Client processes; editor-style server view plus two clients; template exclusion and RunContext |
| Native API regression | Yielding RunService/BindableEvent/RemoteEvent callbacks, local synchronous RemoteFunction, yielding network RemoteFunction handlers, pending invoke cancellation, Instance Folder/IntValue replication, retained native service methods |

The core fixtures compile the production implementation. They use a fake module
resolver and numeric script identity; the Godot fixtures exercise real native
objects, resource changes, services, ObjectIDs and ENet. Tests only prove the
specific paths/assertions run, not universal correctness of all service APIs.

## Migration compatibility

- Executables no longer allocate separate VMs. Services/builtins initialize once
  per applicable domain; they are shared mutable Lua objects within that domain.
- Ordinary global writes stay in each script/module environment. `_G` and shared
  intentionally share across scripts in one domain; Server/Client stay separate.
  getfenv/setfenv remain available; no hostile-script sandbox is claimed.
- Module results initialize once per ObjectID/source revision/domain; failures are
  sticky until invalidated. Exactly one non-nil return is required. Old returned
  values survive invalidation but module-owned pending work is cancelled.
- Destroying an executable no longer closes a VM or clears unrelated modules.
  Disable/reload cancels the old run; re-enable/reload creates a fresh environment.
- Callback references and waits are owner-bound; a publisher does not lend its
  identity/lifetime to another script's callback. Trusted shared-service polling
  survives first-subscriber destruction. Coroutine resume/wrap reject dead owners.
- Immediate native dispatch is capped at eight nested resumes; deeper spawn or
  require chains continue on later ticks. Defer runs on a subsequent scheduler
  tick. Managed numeric/empty yields are timed/next-tick; ordinary yields in
  manually driven coroutines stay manual until they enter a managed wait.
- BindToClose runs on domain/game shutdown, not on individual script destruction.
  Admission is closed; hooks cannot schedule work or initialize uncached modules,
  and yielding hooks are cancelled. There is no instruction quota for a hook
  that never yields. Local synchronous RemoteFunction fallback remains
  non-yielding; yielding network handlers are supported and tested.
- Domain capabilities derive from native ownership, not mutable role globals.
  Native scene objects/transport remain shared in a listen process as before;
  no new filesystem confinement, network protocol or persistence model was added.

## Limits and remaining work

The initial baseline was source-traced, not runtime-benchmarked or crash-reproduced.
No representative old/new initialization, memory or scheduler measurements were
made, so reduced VM count is an architecture fact, not measured improvement.
Linux, SCons distribution/release builds, full graphical editor launch, actual
coordinator/world deployment and production scene content remain unqualified.
The editor fixture tests the launch flags headlessly, not editor window behavior.

ASan instruments the production core and pinned Luau, not the Godot executable,
godot-cpp or the native adapter. It found a deep-dispatch stack overflow at an
earlier bound of 64; the final bound is eight and the regression passes.
Earlier mixed-header/object synchronization also caused a native crash; content
hash synchronization and fresh timestamps for changed inputs corrected it before
the final build. Both failures and their fixes remain in the work log.

Passing multi-process tests sometimes emit ENet `Unable to send packet on channel
0, max channels: 0` during peer teardown. Baseline reproduction/attribution is
unresolved. Expected ServerStorage client-denial logs are separate negative-test
evidence. Functional PASS markers do not erase transport diagnostics.

GL-001/GL-002 have focused fixes and passing retained-method regressions, but
remain open for broader native lifetime qualification. GL-003/GL-004/GL-005 and
GL-006 through GL-009 remain independent: shared VM ownership does not provide
sandboxing, quotas, nonblocking HTTP, RPC input validation or durable storage.
GL-016 remains open; inherited updater/binaries are not qualified fork releases.
No distribution archive, generated assets, dependency pins or updater policy
were changed.

## Continuation qualification (2026-10-26)

Starting revision: `0498efca0c3da15b16fff6fb30aac9658975c50a`, clean
`runtime/shared-domains`. This continuation performs targeted corrections and
qualification, with unchanged godot-cpp/Luau pins. No architecture decision changed;
ADR-001 remains the accepted design, including its historical unmeasured baseline.
Final runtime/build/fixture revision:
[`5f61bea0e273e7473260f351fa4fb321116090ee`](https://github.com/gmoddev/GodotLuau/commit/5f61bea0e273e7473260f351fa4fb321116090ee).
The following evidence commit updates documentation/data only. No main merge,
release, updater enablement or upstream
communication is part of this qualification.

### ENet findings and corrections

The zero-channel diagnostic is a real transport lifecycle defect in the exercised
Godot engine, with an additional application callback timing hazard. It is not
established as harmless logging or as a shared-VM defect.

1. During one ENet poll, multiple peers can already be reset before their queued
   disconnect signals are delivered. ENetMultiplayerPeer emits disconnection
   before erasing that peer from its map.
2. SceneMultiplayer's `_del_peer` sends a reliable six-byte peer-removal relay
   notification to other entries in its connected-peer set. Another reset peer
   can still be present. ENetPacketPeer rejects channel zero when channelCount is
   already zero. An unused packet then remains allocated on this failed send.
3. A synchronous application disconnection callback can send into the same
   incomplete poll state. NetworkService now defers that callback until polling
   has drained, before its removal/ownership RPCs and Lua subscriber dispatch.
   This corrects application timing; it does not fix the engine's internal relay.

Source trace at the exact engine revision:
[ENet poll](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_multiplayer_peer.cpp),
[SceneMultiplayer relay](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/multiplayer/scene_multiplayer.cpp),
[packet send rejection](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_packet_peer.cpp).
The allocation ownership explanation follows this source chain and the reproduced
48+6-byte leak; the minimally built engine lacked full local symbol information.

`ENetDisconnectProbe.gd` creates a server and two clients, closes both before one
server poll, and never loads the GDExtension, Luau, Game or NetworkService.
Five repetitions of each row passed their expected assertions on both official
Windows and Linux Godot 4.7.1 (`a13da4feb`), 25 cases per platform:

| Engine relay | Application callback send | Zero-channel diagnostic |
| --- | --- | --- |
| On | None | Reproduced |
| Off | None | Absent |
| Off | Synchronous reliable broadcast | Reproduced |
| Off | Deferred reliable broadcast | Absent |
| On | Deferred reliable broadcast | Engine diagnostic remains |

The fully instrumented engine-only relay-on probe reports a **54-byte LSan leak**
(48-byte allocation plus six-byte payload) and exits nonzero, matching the
uncoordinated native fixture. This failed adversarial gate is preserved. No log
filter, leak suppression, relay disablement or vendor patch was introduced.
This is tracked as GL-017 with a bounded engine follow-up.

A separate new regression proved an extension defect: destroying active
NetworkService while a surviving script awaited RemoteFunction left the caller
stranded. EXIT_TREE now invokes the existing disconnect/fail-pending path before
clearing service identity. The caller resumes with the existing peer-left error;
transport role resets and retained methods cannot act on a replacement service.
The fixture failed before this correction and passes after it. Script cancellation,
yielding response callbacks, peer cleanup, scene replacement and process exit are
also exercised. These checks do not establish all unreliable-RPC delivery edges.

### Additional targeted corrections

- A diagnostic 1,000-script pilot found about 6,046 ms in 32,000 pure deferred
  task cancellations: every cancellation traversed the scene and scanned all
  native wait guards. Tasks now record whether a native wait was registered;
  only such tasks run native detachment/guard cleanup. Real native wait cleanup
  still executes exactly once; focused coverage checks guards are released.
  This was a measured amplification fix, not a scheduler redesign.
- Full Linux ASan exposed a false native stack-overflow error when the legacy
  guard compared an address-taken local, relocated onto ASan's fake stack, with
  an unrelated stack high-water address. The guard now uses real native frame/
  return-slot addresses and Linux pthread stack bounds, with thread-local caches
  and integer address comparisons. Windows retains OS stack limits. The new
  shallow-stack/reserved-margin regression passes under ASan; fake-stack checks
  remain enabled. Other platforms retain the existing estimated-budget fallback.
- Actual SCons/MSVC builds exposed oversized UTF-8 raw literals (C2026), then
  the binding translation unit's COFF section limit (C1128). Adjacent smaller
  literals preserve the exact concatenated Lua bytes; `/bigobj` matches CMake's
  existing adapter flag. No dependency or generated binding was changed.

### Expanded sanitizer evidence

| Combination | Executed result and boundary |
| --- | --- |
| Windows MSVC 19.51 Debug/Release/core ASan | 36 cases, 20 consecutive suite runs in each configuration, all pass |
| Windows stock Godot + full MSVC ASan extension | Functional marker reached but shutdown timed out; **not qualified** |
| Windows registration-only ASan baseline/candidate | Both reached marker and timed out at exit without creating any domain, script, Game or peer |
| Linux GCC 13.3 Debug/Release/core ASan | 36 cases, 20 consecutive suite runs in each configuration, all pass |
| Linux stock Godot + instrumented adapter | ASan rejects stock loader RTLD_DEEPBIND; unsupported combination, not a clean run |
| Matching source-built Linux ASan/LSan Godot + instrumented godot-cpp/adapter/Luau | Ten ordered-close repetitions: **80 process results pass**, leak detection enabled |
| Matching full Linux ASan engine, simultaneous-close engine-only probe | Functional PASS then 54-byte leak/nonzero exit; preserved failure |

Linux core and full adapter use `-fsanitize=address -fno-omit-frame-pointer`,
Debug configuration, matching executable/shared linker sanitizer flags. All
pinned Luau and godot-cpp targets are instrumented. Engine source is exact
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, built with GCC using
`use_asan=yes use_lsan=yes use_static_cpp=no linker=lld dev_build=yes
debug_symbols=no optimize=none disable_path_overrides=no` and the minimal
GDScript/multiplayer/ENet modules. See the complete reproducible command in
`tests/runtime/BuildSanitizedGodot.sh`. Its custom-build version lacks a Git hash
because the source was an archive; the pinned download identifies the source.

`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=...` remains enabled.
Ordered-close stress explicitly waits for the server's completed disconnect poll
before the second client closes. It isolates native lifecycle acceptance from
GL-017; it does not replace the failed simultaneous-close gate or alter production
relay behavior. Minimal engine dummy-physics warnings are retained; renderer,
full physics and graphical editor behavior are outside this headless build.

Windows instruments the core, bindings, extension and Luau with
`/fsanitize=address`, `/Zi /Od`, `/INCREMENTAL:NO`; runtime DLLs must be beside the
extension for this loader. A registration-only inherited baseline reproduces
the shutdown timeout. This bounds attribution but does not prove every Windows
native lifetime path safe. GL-018's smallest next step is a matching instrumented
Windows Godot host. No UBSan, TSan or production-scene sanitizer claim is made.

### Build, runtime and stress matrix

Windows worker: existing MSVC 19.51.36260, CMake 3.31.10/Ninja, controlled Python
3.12.6. The owner approved portable SCons 4.5.2 at
`C:\Sandbox\Codex\Tools\GodotLuauSCons`; wheel SHA256:
`2f66a1c5c485068a496c12356583eefb2d79e17177278c7334b12b460f0503ce`.
No global installation or machine setting changed. Native builds use four jobs
and persistent project caches under `C:\Sandbox\Codex`.

Linux worker: actual Ubuntu 24.04 on `linuxbox`, Ryzen 9 7950X3D (32 logical
CPUs), with task container limited to four CPUs/10 GiB. GCC 13.3.0,
CMake 3.28.3, SCons 4.5.2, Python 3.12 and lld run inside Docker. The checked-in
Dockerfile pins the Ubuntu base digest and names tool packages, not every apt
package version. It reproduces the setup, not a bit-for-bit hermetic image.
No host-native packages or unrelated Outline/PostgreSQL/Redis workloads changed.
The task container was stopped after qualification; its filesystem/image and bind
tree retain source/build caches and logs. Existing unrelated containers remained
healthy. No persistent Windows build process or task service remains.

Both official runtime hosts are `4.7.1.stable.official.a13da4feb`, using the pinned
Godot 4.3 binding API. Tests are actual native executions, not cross-compilation.
Both build paths compile the production domain and host sources through their
core-source glob. Linux static Luau uses PIC when linked into the adapter.
All 65 native input files (src `.h`/`.cpp` plus SConstruct) match across local,
Windows worker and Linux worker after compiler-equivalent LF normalization:
SHA256 `6b9b752044b36b161a34868ad7d5b94258fdf831d0effb0d489403ce9735103c`.
`tests/runtime/SourceFingerprint.py` reproduces that comparison; dependency
identities are recorded separately by their unchanged pins.

| Gate | Result |
| --- | --- |
| Windows CMake Debug/Release | Core/actual adapter build pass; 24 Debug and eight Release native process results pass on corrected runtime |
| Windows core ASan | Build plus 20 suite repetitions pass; full native host limitation above |
| Windows SCons template_debug/template_release | Both production builds pass; eight native process results per configuration pass |
| Linux CMake Debug/Release/ASan | Core and full adapter builds pass; 20 suite repetitions each pass |
| Linux CMake Debug/Release native | Eight process results per configuration pass |
| Linux SCons template_debug/template_release | Both production builds pass; eight native process results per configuration pass |
| Linux fully instrumented native stress | 80 ordered-close process results pass; separate engine leak remains |
| Engine-only disconnect matrix | 25 cases per platform reproduce the exact expected diagnostic pattern |

Release extension libraries were exercised under the official headless Godot
executable, not a separately exported production game. This establishes those
extension build configurations, not every export/renderer/platform combination.

### Local qualification package and retained evidence

`PackageQualification.py` created
`.runtime-tests/qualification/GodotLuau-shared-domains-5f61bea-test.zip` from
the committed runtime revision above, the unchanged dependencies, and explicitly
supplied current SCons Windows/Linux debug/release binaries. It includes 129
runtime/descriptor/license files, 13,992,761 compressed bytes, and a manifest
containing every file's size/SHA256 and native source fingerprint. Every descriptor
resource is included; ZIP CRCs and all manifest hashes pass. Extracted-package
registration smoke tests load the **shipped descriptor and its actual library
paths** on Windows and Linux, exit zero and emit no diagnostics. These are
additional load checks; the identical binary hashes already have full fixture
coverage above. The archive excludes inherited binary inputs and the updater.

ZIP SHA256:
`31dc9ef586ad78bc03b12a8cf4f191f9afcc7790dad8876729fa8fa52089401e`.
Full library hashes/sizes, raw result-file digests, gate counts and failed gate
dispositions are retained in the
[qualification manifest](evidence/shared-domains-qualification-2026-10-26.json).
The [evidence index](evidence/README.md) records remote/local raw log locations.

Reproduce the archive from runtime revision `5f61bea0e273e7473260f351fa4fb321116090ee`
with the four explicit `--windows-debug`, `--windows-release`, `--linux-debug`,
`--linux-release` inputs as shown in the runtime README. ZIP file timestamps may
differ on regeneration; the source, pins and individual file hashes are the
identity checks, not a promise of byte-for-byte archive reproducibility.

This ignored local archive is a test artifact, not a GitHub Release or production
distribution. Asset-specific provenance remains GL-015; release automation,
retention and updater policies remain GL-010/GL-011/GL-012/GL-016. No production
publication is implied by successful local packaging.

The native fixtures cover single-player, listen host, dedicated server and two
clients, headless editor launch flags, per-domain module identity, environment
isolation, module invalidation, script disable/reload/destroy, pending waits,
retained native methods, network service destruction/replacement, callback owner
destruction, replicated Instance values, scene replacement and shutdown. Core
tests additionally cover concurrent/yielding/cyclic require, sticky failures,
reentrancy, domain separation, 100 owner cycles and 20 domain shutdown cycles.
The extra case tests the actual OS stack guard, rather than increasing counts
without a new acceptance fact. GL-001/GL-002 now have their own native sanitizer
and replacement/retained-call evidence; this does not qualify all bindings.

### Controlled performance measurements

Raw evidence: [90 phase records](evidence/shared-domains-benchmark-2026-10-26.json).
Reproduce with [runtime instructions](../tests/runtime/README.md) and
`SummarizeBenchmark.py`. Baseline `8b163269cbe44cf7fcf7a9a0285620878a2345fd`
has the inherited per-executable VM implementation. Baseline and candidate Release
adapters link the same pinned vendor builds in the same CMake tree with identical
GCC settings, same official Linux Godot, hardware and four-CPU container. No other
compiler/Godot workload was running when the final benchmark started.
An incremental Release rebuild after final raw-literal segmentation produced the
**identical candidate binary SHA256** as the benchmarked binary:
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.
Thus the MSVC packaging correction did not change the measured Linux runtime.

Three trials per script count, alternating baseline/shared order (odd trials
reverse it). Every script performs one initial require, 100 cached requires,
32 deferred task create/cancel pairs and 20 task.wait frames. Assertions verify
module result 5050 and cache identity. Baseline initializes the module N times;
shared initializes it once. The external runner samples process RSS at phase
handshakes. `os.clock` and engine ticks measure monotonic **elapsed** time, not
CPU time. Values below are medians across the three trials, baseline → shared.

| Scripts | Startup ms | RSS growth MiB | Initial requires ms, summed | 100 cache hits/script ms, summed | 32 create/cancel pairs/script ms, summed |
| --- | --- | --- | --- | --- | --- |
| 10 | 31.732 → 6.865 | 12.836 → 3.023 | 0.242 → 0.176 | 1.356 → 2.021 | 0.086 → 0.104 |
| 100 | 304.969 → 31.928 | 107.664 → 7.035 | 2.168 → 0.506 | 13.082 → 20.294 | 0.794 → 1.640 |
| 1,000 | 2,988.325 → 284.925 | 1,056.836 → 57.188 | 21.429 → 3.286 | 129.327 → 194.723 | 7.803 → 19.973 |

| Scripts | Script destruction ms | Game/domain shutdown ms | Frame interval median ms | Frame interval p95 ms |
| --- | --- | --- | --- | --- |
| 10 | 13.687 → 13.700 | 13.684 → 13.741 | 6.895 → 6.900 | 7.196 → 7.168 |
| 100 | 13.796 → 13.557 | 13.549 → 13.466 | 6.902 → 6.904 | 7.169 → 7.218 |
| 1,000 | 145.723 → 139.818 | 13.762 → 13.873 | 6.904 → 6.892 | 7.165 → 7.165 |

At 1,000 scripts, baseline startup spans 2,984.250–3,001.476 ms; shared spans
284.011–285.902 ms. RSS growth spans 1,056.813–1,056.891 versus
57.160–57.188 MiB. Cached requires span 128.699–129.910 versus
194.083–195.296 ms. Coroutine pairs span 7.762–7.813 versus
19.737–21.183 ms. The summarizer emits all min/median/max values.

These measurements support much lower startup time and RSS growth **for this
workload**, with real cached-require and task-bookkeeping regressions. At 1,000
scripts, each cached require averages about 1.29 → 1.95 microseconds; a create/
cancel pair about 0.244 → 0.624 microseconds. No universal scalability claim is
made from three trials on one machine.

Investigation: the new require resolver resolves/type-checks the native module,
copies its source and constructs its full chunk path before the shared cache
lookup; the baseline checks its registry cache before source retrieval. The
shared task path additionally owns rooted thread records, owner checks and a
hash-map/shared_ptr allocation, with reaping at a safe scheduler boundary. These
are source-established additional operations; their individual cost fractions
were not isolated. The measured catastrophic native-cleanup amplification was
corrected before final trials. Further cache/task optimization is GL-019 and
requires profiling, preserving source invalidation and lifetime guarantees.

Limits: startup includes VM allocation/bootstrap, script compilation, native node
creation and benchmark work; isolated luaL_newstate timing was not measured.
RSS is whole-process growth from Before to Startup, not Luau-only allocation.
Destruction/shutdown include two frame boundaries and allocator retention is not
automatically a leak. Frame intervals remain dominated by ~6.9 ms headless pacing
even at max_fps zero. TIME_PROCESS updates were stale/zero (one baseline sample
repeated startup time); those raw fields are retained but **excluded from all
conclusions**. Isolated scheduler CPU cost and graphical frame-rate impact remain
unmeasured. Reload semantics changed intentionally, so no equivalent old/new
reload-cost claim is made. Sanitizer results, not retained RSS, assess tested leaks.

### Readiness decision

**CONDITIONALLY READY for source integration.** Shared-domain acceptance behavior,
Windows/Linux Debug/Release CMake/SCons runtime coverage and expanded Linux native
sanitizer lifecycle coverage are established. The targeted pending-invoke,
stack-guard and cancellation defects have fixes and focused regressions.
GL-014's implementation/source-qualification scope is satisfied, with bounded
remaining work explicitly tracked as GL-017/GL-018/GL-019.

The independently reproduced Godot relay leak, unqualified Windows full-native
sanitizer host and unresolved finer scheduler/graphical performance measurements
limit production claims. They do not demonstrate an unresolved shared-domain
correctness regression requiring a redesign. A source merge recommendation is
separate from production binary publication. GL-003–GL-013 and GL-015/GL-016 retain
their own scope: public-network authority/input checks, persistence, script
capabilities/quotas, updater, automated release gates and asset provenance remain
unqualified. No full graphical editor, coordinator/world deployment or production
scene qualification occurred. Do not publish production binaries on this report.

## Main integration (2026-10-26)

**INTEGRATED WITH QUALIFICATION LIMITATIONS.** Main is the canonical shared-domain
development baseline. This section records source integration; the preceding
qualification reports, ADR and measured/failed outcomes remain historical evidence.

### Revision and merge record

| Identity | Revision |
| --- | --- |
| Starting local and remote main | `8b163269cbe44cf7fcf7a9a0285620878a2345fd` |
| Qualified source branch | `runtime/shared-domains` at `9423fed4051bec2fba798d9a49eaec7dea6cca3b` |
| Integrated main merge | `dd68cda850fb548aa7713242275ff73c183e813c` |
| Complete merge/source tree | `7b2185eef6afef8951afa7ad21d895244d654b0e` |

Neither branch advanced before integration. Main was the source branch's merge
base. `git merge --no-ff 9423fed4051bec2fba798d9a49eaec7dea6cca3b` used the
normal ort strategy with **no conflicts**, preserving `521265c`, `0498efc`,
`5f61bea` and `9423fed`. Fifty-five files changed relative to starting main;
`git diff --name-status 8b163269 9423fed` reproduces the exact file list.
No main functionality or source-branch commits were discarded. The source branch
is retained unchanged. An unrelated remote branch was not merged or modified.

Preflight found a clean working tree, one local worktree, no unmerged paths and
no active CodexLock claims. Origin is the public `gmoddev/GodotLuau` fork and its
default branch remains main. No upstream repository was modified.

The complete tree at the merge equals the qualified source tree, established by
matching Git tree IDs and an empty `git diff 9423fed dd68cda`. The follow-up
integration evidence commit changes documentation only. Runtime, test code, build
configuration and pinned dependencies remain identical to qualified source.
The 65-file native fingerprint remains
`6b9b752044b36b161a34868ad7d5b94258fdf831d0effb0d489403ce9735103c` on the
integrated checkout and both workers. Windows core build inputs additionally
match normalized digest
`916e2375f4d1e8d68bf18cbd950310bdaf210ab83ceac5390e27ebcb2c1e1cb6`;
Linux build/native-fixture inputs match
`234320629dc8a7505d58bf33b9a68c622f77a5afa58587b484ec65cd11f5dc6c`.
Windows native fixtures run from the integrated local checkout; those fixture
files are not required in the Windows build-only mirror.

### Fresh integrated checks

Existing MSVC/GCC CMake/Ninja caches and the previously configured Linux task
container were reused with four build jobs. No dependencies or toolchains were
installed, no worker settings changed, and no expensive stress matrix reran.

| Fresh gate | Actual result |
| --- | --- |
| Windows Debug core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Windows Release core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Windows ASan core build/test | Exit 0; 36-case core suite passes once |
| Linux Debug core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Linux Release core + native adapter incremental build | Exit 0; 36-case core suite passes once |
| Linux ASan core build/test | Exit 0; 36-case core suite passes once |
| Windows Debug native fixtures | Eight process results, all exit zero/PASS; known GL-017 diagnostic in dedicated server stderr |
| Windows Release native fixtures | Eight process results, all exit zero/PASS |
| Linux Debug native fixtures | Eight process results, all exit zero/PASS |
| Linux Release native fixtures | Eight process results, all exit zero/PASS |

Each native group runs single-player Integration, Listen, Dedicated with two
clients, and headless Editor launch flags with two clients. `--teardown` requires
RemoteFunction cancellation when NetworkService is destroyed. Existing assertions
also cover shared module identity, Server/Client separation, script environments,
script/coroutine ownership, owner cancellation, disable/reload/destroy, native
Instance liveness, retained methods, service replacement and scene shutdown.
The production core suite covers concurrent/yielding require, module errors/
invalidation, reentrancy and lifecycle bounds. Source inspection still finds the
single extension `luaL_newstate` call in GLExecutionDomain, with no executable-
script VM allocation. No new runtime behavior or optimization was introduced.

The Windows Debug dedicated-server stderr contained one `max channels: 0`
diagnostic. Functional exits/assertions passed; this is **not** a clean transport
claim. GL-017 remains independently reproduced and unresolved. No diagnostics
were suppressed and no sanitizer settings/checks were weakened.

Exact incremental commands, in the existing MSVC developer environment on
`dockerbox` (the full CMake/CTest paths are in the build-environment section):

```powershell
foreach ($Config in @('debug', 'release')) {
    $Build = "C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-$Config"
    cmake --build $Build --target ExecutionDomainTests GodotLuauAdapter --parallel 4
    ctest --test-dir $Build --output-on-failure --timeout 30
}
$Build = 'C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-asan'
cmake --build $Build --target ExecutionDomainTests --parallel 4
ctest --test-dir $Build --output-on-failure --timeout 30
```

Inside the existing `codex-godotluau-qualification` Linux container:

```sh
for Config in debug release; do
    cmake --build /work/builds/linux-$Config \
        --target ExecutionDomainTests GodotLuauAdapter --parallel 4
    ctest --test-dir /work/builds/linux-$Config --output-on-failure --timeout 30
done
cmake --build /work/builds/linux-asan --target ExecutionDomainTests --parallel 4
ctest --test-dir /work/builds/linux-asan --output-on-failure --timeout 30
for Config in debug release; do
    python3 /work/source/tests/runtime/RunQualification.py \
        --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
        --extension /work/builds/linux-$Config/godot_luau.so \
        --output /work/artifacts/integration-main-dd68cda-$Config \
        --teardown --timeout 45
done
```

Windows adapters were copied from the two worker build directories, then tested
headlessly from the integrated checkout:

```powershell
foreach ($Config in @('debug', 'release')) {
    C:/Python312/python.exe tests/runtime/RunQualification.py `
        --godot C:/Users/aiden/Downloads/Godot/Godot_v4.7.1-stable_win64.exe `
        --extension ".runtime-tests/qualification/main-dd68cda-windows-$Config.dll" `
        --output ".runtime-tests/qualification/main-dd68cda-windows-$Config" `
        --teardown --timeout 45
}
```

Fresh logs: Windows worker
`C:\Sandbox\Codex\Logs\GodotLuau\integration-main-dd68cda-builds.log`;
local `.runtime-tests/qualification/main-dd68cda-windows-{debug,release}`;
Linux `/opt/codex/godotluau/logs/integration-main-dd68cda-{debug,release,asan}.log`
and `/opt/codex/godotluau/artifacts/integration-main-dd68cda-{debug,release}`.
Fresh native binary/result-file hashes are recorded in the
[integration evidence](evidence/shared-domains-integration-2026-10-26.json).

### Reused evidence, publication control and next baseline

The source/tree identities justify reusing the prior Windows/Linux SCons
Debug/Release builds and native fixtures, 20-repeat core suites, 80-process full
Linux native ASan/LSan ordered-close stress, engine-only failure attribution,
controlled benchmark and explicit-input local-package evidence. Those tests were
not rerun or relabelled as new main executions. The recorded SCons libraries and
test archive remain artifacts of runtime revision `5f61bea`; they are applicable
to main's unchanged runtime content, not newly published main binaries. The fresh
Linux Release adapter still has the exact benchmarked SHA256
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.

The inherited release workflow is active and its path filter matches this merge.
The merge and integration-documentation commit messages include `[skip ci]`,
using GitHub's documented
[push-workflow skip directive](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).
Main had no branch protection or applicable branch rules; no protection was
bypassed. Workflow state/configuration and updater behavior are unchanged.
No workflow dispatch, GitHub Release, production binary publication or upstream
communication is authorized by this integration. The prior qualification's
no-merge restriction applied to that completed task; this task explicitly
authorizes integrating and pushing main.

GL-014 is integrated and remains source-qualified/closed within its established
scope. GL-017 (engine teardown/leak), GL-018 (Windows full-native sanitizer host)
and GL-019 (cached require/task overhead) remain open, alongside networking
authority/input validation, persistence, script capabilities/quotas, updater and
release provenance limitations. Integration resolves none of those issues.

The smallest coherent next task is **GL-019 profiling of cached ModuleScript
require**, starting with native source retrieval/path construction before the
cache lookup in `GLDomainHost::GetDomain`/`GLExecutionDomain::BeginRequire`.
Measure attributable costs before optimizing; preserve module revision
invalidation and owner lifetime guarantees. Coroutine bookkeeping remains part
of GL-019 but does not need to be bundled into the first profiling change.
No GL-019 implementation was performed here.

## GL-019 optimization (2026-10-26)

**OPTIMIZED AND QUALIFIED** on `perf/gl-019-hot-paths`; not merged into main.
Starting main: `aa5400321b8f838a75de8d2b4005b0c5165dab34`, verified clean and
unchanged on origin. Measurement harness:
`0427a3560ac01b191aa7dcc8b2c144f8eccda2dd` (production code unchanged from main).
Runtime optimization: `1756cc2600e5a59ea948e69a684f5abd93e32229`.
The following evidence commit changes documentation/data only. ADR-001 and the
Server/Client ownership model are unchanged; previous results above are preserved.

### Comparable baseline and attribution

Reused the existing linuxbox Ubuntu 24.04 container, four-CPU/10-GiB limits,
GCC 13.3/CMake Release `-O3 -DNDEBUG`, pinned vendors and official Godot 4.7.1.
No tools/packages/settings changed. Builds were finished before timed/profiled
runs. Source/native input identity is recorded in the
[qualification manifest](evidence/gl019-qualification-2026-10-26.json).

Fresh original/shared baseline: five counterbalanced trials at 10/100/1,000
scripts using the **unchanged population benchmark**. At 1,000, original
per-script startup is 2,979.038 ms, RSS growth 1,056.820 MiB, cached requires
129.808 ms and create/cancel pairs 7.876 ms. Pre-GL-019 shared results are
287.317 ms, 57.191 MiB, 195.620 ms and 20.140 ms, respectively. This reproduces
the historical regression closely enough for direct pre/post comparison.

Pre-GL-019 library SHA256:
`8ea4e9c2faeb4218157059415e93aab6700eebce41283a1ab0b20106aff66ee9`.
Final optimized Release library SHA256:
`d9398aed311dab4e4493b022fc0df8e4ed81e569e778d562aeb3695248544883`.
All 65 native input files match local/Windows/Linux, LF-normalized digest
`40e2cbadfae3cef7fdc39e17d6b9feec94f635aa5e8926614bdcdb27c324045d`.
The dependency pins remain exactly those recorded in the initial report.

Added a captured-module workload using the existing bounded runner helpers.
It removes `game.ReplicatedStorage.Counter` property/hierarchy lookup from the
timed loop. Native perf sampled only the task container cgroup, not unrelated
host services: 16,463 pre and 3,094 post user-cycle samples, zero lost samples.
The extension is symbolized; the official Godot binary is stripped. Inclusive
pre-profile costs overlap and must not be summed:

| Native sampled path | Inclusive sampled cycles |
| --- | --- |
| GLExecutionDomain::BeginRequire | 67.63% |
| Native module resolver | 66.04% |
| String::utf8 (source/path conversions combined) | 30.98% |
| gl_instance_fullname | 26.62% |
| ModuleScript type cast | 3.17% |
| Lua registry result access | 0.63% |

The old path enters through the Luau require wrapper, resolves the ObjectID,
checks Node/ModuleScript type and tree/resource liveness, retrieves/converts the
entire source, constructs/converts the hierarchy chunk name, then looks up the
numeric cache key and returns through registry/stack operations. Sampling
establishes that pre-cache native work is a bottleneck. It does not separately
time every Godot internal lock, individual allocation or source/path conversion;
some of those functions are stripped/inlined.

An optional executable links the **production core and pinned Luau**, recording
monotonic elapsed time, process CPU (`std::clock`) and C++ new-call/requested-byte
counts. Creation takes two C++ allocations per task (record/control block plus
map node), with additional table growth when needed; cancellation takes none.
Snapshot growth takes eleven allocations
at 1,000 tasks. Luau/Godot malloc and peak/live bytes are not counted. The core
benchmark is single-threaded; native Godot's allocator/shared_ptr atomic behavior
can differ. It supports attribution, not an isolated native scheduler CPU claim.

### Accepted changes and preserved behavior

- `luau_script.h`: LuauScript stores a source revision, incremented on actual
  source changes **before** changed-signal callbacks. Resource replacement is
  distinguished by its Godot ObjectID even when revisions are equal.
- `gl_domain_host.cpp`: the resolver performs live/type/tree/resource checks and
  returns module/resource IDs plus revision. A separate miss loader retrieves
  source and chunk path. No native pointer/resource is retained in a new cache.
- `gl_execution_domain.h/.cpp`: compare metadata before source loading; ready
  hits return the same registry value immediately. Resolvers without metadata
  retain the original content comparison. Loading entries still join once;
  cycle detection, sticky failure, invalidation, cancellation and shutdown
  admission behavior remain. Old returned values survive source invalidation.
- `gl_execution_domain.cpp`: reserve current snapshot/close-owner vector sizes;
  avoid a temporary shared_ptr copy when merely inspecting a live task. Strong
  snapshot roots and cancelled-task locals remain across resume/reset/unref.
  The registered-native-wait cleanup bit remains unchanged.

No public ModuleScript/task API, `_G`/shared behavior, environment, VM ownership,
authority/capability, network/persistence path, updater or dependency changed.
Native resource revision is internal metadata, not a new gameplay property.

### Final before/after measurements

Seven counterbalanced trials per count on the same idle worker/binaries. Values
are medians, **pre-GL-019 → post-GL-019**. All times below are elapsed milliseconds;
RSS is whole-process Startup-minus-Before growth. Generic runner labels in this
file map `Baseline` to pre-GL-019 and `Shared` to post-GL-019.

| Scripts | Cached require sum (100/script), ms | Startup ms | 32 create/cancel pairs/script, ms | RSS growth MiB |
| --- | --- | --- | --- | --- |
| 10 | 2.030 → 0.847 | 6.829 → 6.830 | 0.106 → 0.110 | 3.063 → 3.086 |
| 100 | 20.152 → 8.362 | 31.713 → 19.897 | 1.641 → 1.639 | 7.063 → 7.016 |
| 1,000 | 198.230 → 82.433 | 290.204 → 171.446 | 20.321 → 20.107 | 57.203 → 56.230 |

At 1,000, cached sums span 195.386–209.731 → 80.347–85.378 ms; startup spans
286.049–306.892 → 169.099–177.816 ms; task pairs span
19.658–22.990 → 19.854–20.608 ms. RSS growth spans
57.191–57.250 → 56.105–56.262 MiB. The small-count RSS/time ranges overlap;
no material startup/memory regression is established. Original per-script VM
costs remain a separately recorded comparison, not the primary optimization base.

The final captured-module loop (one million calls, seven counterbalanced trials)
measures **1,054.330 → 163.508 ms**, ranges 1,018.822–1,065.148 →
159.992–173.674 ms. True first module initialization is **13.040 → 13.080 us**,
ranges 11.800–14.910 → 12.190–14.050 us: no meaningful cold-path change is
claimed. The earlier require-only trial and final binary give consistent gains.
Population initial-require sums include one miss plus other scripts' cache hits;
they are not separate VM-allocation timing.

Domain/game shutdown medians at 10/100/1,000 scripts are
13.743/13.767/13.683 → 13.716/13.765/13.598 ms. Script destruction with pending
waits is 13.473/13.693/138.787 → 13.724/13.682/135.747 ms. Both include two
frame boundaries. Frames remain near 6.9 ms; TIME_PROCESS remains excluded.
No graphical frame-rate or scheduler CPU conclusion follows from those intervals.

Core microbenchmarks use eleven counterbalanced trials at each count. CPU
medians below are **process CPU ms per 1,000 operations**, not wall time; full
wall/CPU trial values remain in the raw evidence for min/median/max calculation.

| Core phase | CPU ms, pre → post | C++ allocation calls, pre → post |
| --- | --- | --- |
| Spawn + completion | 0.653 → 0.668 | 2,006 → 2,006 |
| Defer creation | 0.406 → 0.415 | 2,000 → 2,000 |
| Cancellation | 0.037 → 0.037 | 0 → 0 |
| Cancelled reaping | 0.037 → 0.031 | 11 → 1 |
| Defer/wait creation | 0.351 → 0.353 | 2,000 → 2,000 |
| Resume + yield | 0.085 → 0.073 | 11 → 1 |
| Resume + completion/reaping | 0.105 → 0.086 | 11 → 1 |
| Delay creation | 0.553 → 0.571 | 2,000 → 2,000 |
| Idle pending-task tick | 0.026 → 0.020 | 11 → 1 |
| Owner cancellation/reaping | 0.051 → 0.048 | 11 → 1 |
| Manual coroutine resume/completion | 0.557 → 0.590 | 0 → 0 |
| Concurrent require start (includes compile/owner creation) | 3.818 → 3.908 | 36,054 → 36,054 |
| Concurrent require finish | 0.155 → 0.151 | 22 → 2 |
| Domain shutdown | 0.028 → 0.034 | 11 → 1 |

These small timings contain noise; unchanged creation/manual-resume paths are
not claimed faster. A 21-trial sensitivity run at 10,000 operations gives idle
tick CPU median 0.271 → 0.159 ms (ranges 0.157–0.315 → 0.135–0.226), owner
cancellation 0.647 → 0.550 ms, and shutdown 0.381 → 0.383 ms. Creation/complete
results have broad overlapping spreads. Retention is justified by deterministic
allocation reduction and measured tick improvement without a structural rewrite.
At 1,000 tasks a snapshot requests 16,000–16,016 bytes once instead of 32,752
bytes across eleven calls. Two-step concurrent completion requests 32,000 rather
than 65,504 bytes. These are requested C++ bytes, not RSS or peak live allocation.

Separate native perf stat captures execute the same fifteen million cached
calls/five processes: accumulated task-container CPU **16,570.54 → 3,150.85 ms**,
cycles **92.553 → 16.905 billion**, instructions **325.971 → 56.991 billion**.
Capture windows are 25/15 seconds; idle capture time consumes no task CPU.
Totals include runner/startup/shutdown and sampling overhead; they are not
isolated function CPU times. Latency trials above ran without perf attached.

### Rejected candidates and remaining costs

- Removing shared_ptr roots or live ObjectID/type checks was rejected: those
  protect reentrant callbacks, destruction and native lifetime. A ~3% sampled
  type-cast contribution does not justify weakening validation.
- A bounded record pool/map replacement was considered but not implemented.
  Cancelled burst records remain rooted until a safe scheduler boundary, so
  they cannot be recycled during the initial create/cancel burst. A pool also
  needs correct snapshot/reference eligibility and extra retained storage.
  No prototype speedup is claimed. Complexity is not justified by the measured
  residual cost while simpler allocation reductions are available.
- Replacing the Luau require wrapper/continuation protocol was rejected as
  unnecessary after the measured native improvement; yielding/concurrent/error
  behavior remains intact. No new custom allocator or VM model was introduced.

Create/cancel bursts still cost ~20 ms at 1,000 scripts versus ~8 ms in the
original per-script architecture. Task records, registry roots, owner checks,
map/shared_ptr allocations and safe reaping are retained. This is an explicit
measured tradeoff, not a claim that every original regression disappeared.
Future task-creation work requires new profiling and lifetime evidence.

### Correctness and qualification

The original 36 core cases remain; three focused cases add lazy-source load
counts, resource identity/revision replacement, pending revision invalidation,
metadata-path cycles/sticky errors and cached require during shutdown. Native
Integration adds an earlier changed-signal subscriber that requires new source
before ModuleScript's later invalidation handler. This protects against an
identity-only shortcut returning stale data. Existing native fixtures still
exercise role/cache separation, source reload/destroy/replace, environments,
callbacks, task cancellation, Instance liveness, remotes, service replacement
and scene shutdown.

| Final gate | Result |
| --- | --- |
| Windows MSVC Debug/Release/ASan core + adapter builds | Pass; 39-case core suite passes five repetitions in each configuration |
| Linux GCC Debug/Release/ASan core + adapter builds | Pass; 39-case core suite passes five repetitions in each configuration |
| Windows Debug/Release native fixtures | Eight process results/configuration, all exit zero/PASS |
| Linux Debug/Release native fixtures | Eight process results/configuration, all exit zero/PASS |
| Full Linux Godot + bindings + adapter + Luau ASan/LSan | Three ordered-close repetitions, 24 process results pass with detect_leaks=1 |

Windows Debug Dedicated/Editor and Release Editor servers emitted the known
GL-017 zero-channel diagnostic; logs remain intact. Ordered-close sanitizer
stress still isolates the separately proven engine leak. GL-017 and GL-018
remain open; Windows full-native sanitizer coverage is not claimed. SCons/release
packaging was not rerun or republished for GL-019; CMake exercises actual native
code in both build configurations. The inherited distribution issues retain
their own scope. No historical stress matrix was repeated without need.

Reproduction commands and metric limits are in
[tests/runtime/README.md](../tests/runtime/README.md#gl-019-profiling-and-optimization-comparison).
Raw records and metadata are indexed in [evidence](evidence/README.md). Worker logs:
`linuxbox:/opt/codex/godotluau/logs/gl019-*.log`, raw perf/core/native artifacts
under `/opt/codex/godotluau/artifacts/gl019`; Windows build log
`dockerbox:C:\Sandbox\Codex\Logs\GodotLuau\gl019-builds.log`, native logs in
local `.runtime-tests/qualification/gl019-windows-{debug,release}`.

GL-019 is resolved for the requested profiling/optimization/qualification scope
on this branch. No universal performance target or production readiness is
implied. Main, upstream, dependency pins, updater and release automation remain
unchanged. Networking authority, persistence, capability/quota and distribution
limitations remain independently tracked. The next optional performance task is
profiling steady-state task creation under a real gameplay workload, preserving
the same ownership rules; it is not part of this completed change.

## GL-019 main integration (2026-10-26)

**INTEGRATED WITH QUALIFICATION LIMITATIONS.** The optimized shared-domain runtime
is the canonical main development baseline. This source integration preserves
the GL-019 architecture, public behavior and evidence; it is not a new full
production qualification. The preceding optimization section describes the
historical branch qualification before this merge.

### Revisions, merge and implementation identity

- Starting local/remote main: `aa5400321b8f838a75de8d2b4005b0c5165dab34`.
- Qualified local/remote source: `ad200aa468be56edf4812bb3a03daeb31d5bbdd8`
  on `perf/gl-019-hot-paths`. Neither branch advanced before integration.
- Integrated runtime main revision: `6badbae4b467a5544ffd027a1c7d7bd505cd0d46`.
  Normal `git merge --no-ff`, no conflicts, preserving harness `0427a35`, runtime
  `1756cc2` and evidence `ad200aa` in history. No squash/rebase/force push.
- Its entire tree equals the qualified source tree:
  `1d05c9a1bb39c20667ccfc1a555b7201321d7df9`. All subsequent integration edits
  are documentation/compact evidence only. The publication tip is the
  documentation commit immediately following this merge, identifiable in Git
  history; the runtime revision above is immutable and independently testable.
- Production/build/test code equals `1756cc2600e5a59ea948e69a684f5abd93e32229`
  (test README excluded). All 65 normalized native inputs retain fingerprint
  `40e2cbadfae3cef7fdc39e17d6b9feec94f635aa5e8926614bdcdb27c324045d`.
  Worker comparison covers 88 source/build/test files, excluding only the test
  README. Missing support files and benchmark Windows guards were synchronized;
  final CMake/core checks were repeated. Production inputs already matched.
- Pins, SConstruct, workflow/updater, generated assets and inherited binaries
  remain unchanged. The only build addition from GL-019 is the optional,
  default-off core benchmark target. ADR-001 is unchanged.

Static comparison retains live module/resource identity plus source revision
validation, revision increments before changed callbacks, lazy source/chunk-path
loading on misses, cache invalidation/cycles/sticky errors and old returned
values. Scheduler vectors reserve sizes while shared_ptr snapshots/cleanup
locals retain strong coroutine roots. Native-wait cleanup, owner cancellation
and shared Server/Client VM ownership are unchanged. No behavioral conflict
resolution or extra runtime change was needed.

### Fresh focused checks

Reused the same Windows worker toolchain and Linux task container/caches, with
four build jobs per worker. No installation, host setting or workflow change.
Windows CMake/core and SCons compilation ran on dockerbox. Windows native groups
used the existing official Godot 4.7.1 executable on the controlling PC, hidden
and headless with two engine workers, crash UI suppression and 45-second bounds.
Linux builds and all Linux execution ran inside the four-CPU/10-GiB task
container on linuxbox. This retains the established test topology.

| Gate | Fresh result |
| --- | --- |
| Windows CMake Debug/Release/ASan core + actual adapter | Incremental targets pass; all 39 cases pass once per final configuration |
| Linux CMake Debug/Release/ASan core + actual adapter | Incremental targets pass; all 39 cases pass once per final configuration |
| Windows/Linux SCons template_debug and template_release | Four incremental native builds pass with existing pinned dependencies |
| CMake Windows/Linux normal Debug/Release native fixtures | Eight process results per platform/configuration, all exit zero/PASS: 32 results |
| SCons Windows/Linux normal Debug/Release native fixtures | Same eight process results per platform/configuration, all exit zero/PASS: 32 results |
| Linux full-native ASan/LSan | One ordered-close repetition, eight process results pass; detect_leaks=1, matching instrumented Godot/bindings/adapter/Luau |

Each native group includes Singleplayer Integration, Listen, Dedicated with two
clients and Editor-style flags with two clients. Existing assertions cover
module sharing/revision invalidation, changed-subscriber ordering, domain
separation, source/lifecycle replacement, callback/task/native-wait cancellation,
retained methods, RemoteFunction service teardown and owner cleanup. No new
test infrastructure or historical stress repetitions were added.

Known GL-017 zero-channel diagnostics remain visible: CMake Windows Debug and
Release Editor servers; CMake Linux Debug Editor and Release Dedicated/Editor
servers; SCons Windows Debug Dedicated/Editor and Release Dedicated servers.
SCons Linux normal groups and ordered-close Linux ASan emitted none. These
functional passes do not resolve the separately reproduced engine diagnostic
or leak. GL-018 still excludes Windows full-native sanitizer qualification.

Commands use existing runners and build configurations:

```text
cmake --build <existing-runtime-config> --target ExecutionDomainTests GodotLuauAdapter --parallel 4
ctest --test-dir <existing-runtime-config> --output-on-failure --timeout 30
scons platform=linux target=template_debug -j4
scons platform=linux target=template_release -j4
```

Windows SCons uses the approved controlled Python and `RunSConsPortable.py`
with the existing portable SCons directory, `platform=windows` and those same
targets/job bound. Native `RunQualification.py` commands use each explicit
CMake/SCons library, `--teardown --timeout 45`; Linux full-native sanitizer uses
the existing instrumented engine, `--coordinated-close --timeout 90`, and
`ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=<distinct-output>/asan-report`.
All outputs are distinct from historical qualification directories.

### Performance evidence disposition

The historical seven-trial comparisons, profiler captures, allocation records
and rejected alternatives remain unchanged and apply within their original
scope by implementation/build-input identity. The CMake Release library remains
SHA256 `d9398aed311dab4e4493b022fc0df8e4ed81e569e778d562aeb3695248544883`;
Windows CMake Debug/Release hashes likewise match the qualified artifacts.
Fresh smoke measurements ran after builds completed, on the same Linux worker,
without profiling or concurrent task builds:

| Smoke metric | Pre-GL-019 | Integrated |
| --- | ---: | ---: |
| 1,000-script cached require sum, elapsed ms | 196.077 | 82.700 |
| Startup, elapsed ms | 287.051 | 171.334 |
| Whole-process RSS growth, MiB | 57.188 | 56.277 |
| Task create/cancel pairs, elapsed ms | 19.895 | 20.156 |
| Captured million-call require, median elapsed ms | 1,049.181 | 160.287 |
| Core idle tick, median process CPU ms / 1,000 tasks | 0.026 | 0.019 |
| Core idle tick, C++ new calls / requested bytes | 11 / 32,752 | 1 / 16,016 |

Population is one paired trial, not a new distribution or acceptance threshold.
Captured require and core use three counterbalanced trials per mode. RSS is
Startup-minus-Before for the whole process. C++ counters exclude Luau/Godot
malloc; core process CPU is distinct from native wall time. No new perf CPU
profile or exact numeric reproduction is claimed. The smoke is consistent
with preserved optimizations and retained task-creation cost; no material
regression requiring a new optimization phase appeared.

Reproduction: existing `RunRequireBenchmark.py --repeat 3`,
`RunQualification.py --counts 1000 --repeat 1 --timeout 120` with the pre-GL-019
library supplied through `--baseline`, and `RunHotPathBenchmarks.py --counts 1000
--repeat 3` using pre/current executables. Inputs, raw-result hashes, exact
binary identities, diagnostics and worker locations are in the
[integration manifest](evidence/gl019-main-integration-2026-10-26.json).
Raw smoke datasets/logs stay under `/opt/codex/godotluau/artifacts/gl019-integration`
and `logs/gl019-integration-*.log`; local Windows artifacts are ignored under
`.runtime-tests/qualification/gl019-integration`. No binaries/logs/archives
enter Git. Cached native artifacts do not establish release provenance.

### Disposition and next task

GL-019 is integrated and resolved for its measured optimization scope. Current
architecture, documentation entry points and test instructions identify optimized
main as canonical. Historical branches/evidence are retained. Main publication
uses an ordinary non-force push to `gmoddev/GodotLuau` with `[skip ci]`, preserving
the explicit prohibition on running the inherited release workflow. No branch
protection or ruleset is bypassed; both were absent during preflight. No upstream
write, PR, release, updater enablement or production binary publication occurs.

GL-017/GL-018 remain independent limitations, as do GL-003/004/005 capabilities,
sandbox/quotas/HTTP; GL-006/007/008 authority/input/identity; GL-009 persistence;
GL-010/011/012/016 distribution/gates/retention/updater; and GL-015 assets.
No graphical/editor/coordinator/production-content readiness is inferred.

Rechecked `roblox_network.h` on the integrated source: GL-006's ANY_PEER state/
removal receivers still lack transport-sender/receiver-role gates; GL-008's chat
relay still displays the supplied name and its receiver lacks a server-sender
guard. The smallest coherent next task is an authority-boundary patch to those
receivers plus server-derived chat identity, with wrong-peer rejection/no-side-
effect tests and valid server traffic in the existing multi-peer fixture.
These fixes were not implemented during integration; numeric movement/input
policy remains GL-007's separate scope.

## GL-006 / GL-008 security follow-up (2026-10-27)

The dedicated `security/gl-006-008-rpc-authority` branch first implemented and
qualified the endpoint-specific authority and trusted chat identity correction.
At that source-qualification checkpoint it had not merged into main. The
[authority record](network-authority-validation.md)
and [evidence manifest](evidence/gl006-008-qualification-2026-10-27.json) record
the real ENet baseline reproduction, final implementation identity, 39-case core
suites across six configurations and 90 passing native process results (50 new
security-fixture processes plus 40 existing regressions). Windows Debug/Release
and Linux Debug/Release/full-native ASan/LSan are exercised. GL-017/018 remain
bounded limitations; GL-020 records the independent animation authority gap.
Shared-domain and GL-019 implementation files remain unchanged.

Main subsequently integrated that exact qualified source through normal merge
`2e69d8ac703d3f968e42054871511111ab8471be` without conflicts. See the
[main authority integration record](network-authority-validation.md#main-integration-2026-10-27)
and [separate integration manifest](evidence/gl006-008-main-integration-2026-10-27.json)
for the six fresh core checks and 90 fresh native process results. The corrected
networking endpoints are the current main baseline; GL-007 and GL-020 remain open.


## Second extraction main integration (2026-10-28)

Starting local/remote main `174efcc2bdb59c5072ba21d27645c5380c61e8e9`
merges qualified branch tip `d97fa5da9c5fb587061db9e35be00e764a47e3de`
normally as `21d10d91769ee81c85ae2e1d2029e683feeb51ba`. Both source commits
(`5f72f4c` and `d97fa5d`) remain ancestors; the entire merge tree equals that tip.
The final branch commit changes four evidence/documentation files only. Source,
fixtures, dependencies, build configuration and workflows equal qualified
implementation `5f72f4cda1c5e3bb76edd33bb11e276cff07ac10`.

Fresh integration checks compare both converter bodies exactly to pre-extraction
source, confirm one definition each, inspect unchanged reflection/registration,
forward-only headers and both source-discovery globs, parse evidence and check the
diff. Prior Windows/Linux Debug/Release core39/native28 qualification is reused
within its recorded scope; no expensive local matrix is repeated. Release jobs
remain false with read-only permissions and updater admission remains false.
The normal push is read back at the exact merge SHA.

Fresh [core run 40642408324](https://github.com/gmoddev/GodotLuau/actions/runs/40642408324)
and [native run 40642408346](https://github.com/gmoddev/GodotLuau/actions/runs/40642408346)
target this merge. Observation is bounded at 25 minutes, with results recorded
during the authorized third extraction. Initial status is pending; pending work
is not a pass. The next documentation commit changes no tested input. GL-013
remains open, and the third extraction is authorized for branch publication only.
