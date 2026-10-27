# Shared-domain regression fixtures

## Network authority and chat security

Main includes the qualified GL-006/008 `NetworkSecurity.gd` fixtures through the
existing runner. The [integration record](../../newdocs/network-authority-validation.md#main-integration-2026-10-27)
distinguishes fresh integration checks from the retained source-branch evidence:

```text
python tests/runtime/RunQualification.py --godot <existing-Godot-4.7.1> --extension <candidate-library> --output <new-isolated-directory> --security --timeout 60
```

This executes ten processes across Local, Listen, Dedicated and Handler modes.
Handler deliberately changes the four receive RPCs to ANY_PEER in the fixture,
testing native guards independently of transport authority filtering. Attacks
still traverse real ENet; file barriers coordinate actors only. Use a new output
directory per run, since markers and logs are retained there. For a focused
reproduction, `--security-modes Dedicated` selects one server/two-client group.

The same message signatures and existing runner prepare/start/check/deadline/
cleanup paths apply. Windows uses hidden processes and crash-UI suppression;
Linux full-native sanitizer runs use the established matching instrumented host,
`detect_leaks=1`, and a 90-second timeout. Final closes are ordered after the
transport poll, preserving GL-017 separately. Existing `--teardown
--coordinated-close` regression runs remain a separate gate. See the
[authority report](../../newdocs/network-authority-validation.md) for assertions,
source identity, executed platforms and limitations.

## Shared-domain coverage

These tests exercise the production `GLExecutionDomain` implementation and the
actual Godot adapters. They do not use a second scheduler/cache implementation.
`main` is the optimized shared-domain development baseline, including GL-019;
historical source branches and reused qualification scope are recorded in the
[integration record](../../newdocs/shared-domains-validation.md#gl-019-main-integration-2026-10-26).
Initialize the pinned `luau` and `godot-cpp` submodules first. Native builds use
the configured worker; keep compilation off the controlling gaming PC.

## Core and adapter build

Run in an existing MSVC developer command environment on the worker:

```powershell
$Source = 'C:\Sandbox\Codex\Workspaces\GodotLuau'
$Build = 'C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-debug'
cmake -S "$Source\tests\runtime" -B $Build -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug -DGL_BUILD_GODOT_ADAPTER=ON `
  -DPython3_EXECUTABLE=C:/Sandbox/Codex/Tools/python-3.12.6-controlled-v1/python.exe
cmake --build $Build --target ExecutionDomainTests GodotLuauAdapter --parallel 4
ctest --test-dir $Build --output-on-failure --timeout 30
```

`ExecutionDomainTests` runs 39 cases and exits nonzero on any failure. Its fake
numeric module resolver isolates the actual core from Godot; native identity,
role and wire behavior are covered by the separate integration fixtures.
The optional adapter target builds all production core `.cpp` files and their
native headers against pinned godot-cpp. `SConstruct` remains the distribution
build entry point; this CMake target does not qualify release packaging.

For the Windows AddressSanitizer core configuration:

```powershell
$Asan = 'C:\Sandbox\Codex\Builds\GodotLuau\runtime-msvc-asan'
cmake -S "$Source\tests\runtime" -B $Asan -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug -DGL_BUILD_GODOT_ADAPTER=OFF `
  -DCMAKE_CXX_FLAGS=/fsanitize=address `
  '-DCMAKE_CXX_FLAGS_DEBUG=/Zi /Od' `
  -DCMAKE_EXE_LINKER_FLAGS=/INCREMENTAL:NO
cmake --build $Asan --target ExecutionDomainTests --parallel 4
ctest --test-dir $Asan --output-on-failure --timeout 30
```

This instruments the core and pinned Luau targets, not Godot or native adapters.
The developer environment must expose the existing ASan runtime DLL directory.

## Native headless fixtures

Copy the worker-built DLL to an ignored artifact directory, then run locally:

```powershell
$Godot = 'C:\Users\aiden\Downloads\Godot\Godot_v4.7.1-stable_win64.exe'
$Project = '.runtime-tests\final-integration'
powershell -NoProfile -ExecutionPolicy Bypass -File tests/runtime/RunIntegration.ps1 `
  -GodotPath $Godot -ExtensionPath '.runtime-tests\artifacts\godot_luau.dll' `
  -OutputDirectory $Project -TimeoutSeconds 30
powershell -NoProfile -ExecutionPolicy Bypass -File tests/runtime/RunNetworkIntegration.ps1 `
  -GodotPath $Godot -ProjectDirectory $Project -Mode Listen -TimeoutSeconds 30
powershell -NoProfile -ExecutionPolicy Bypass -File tests/runtime/RunNetworkIntegration.ps1 `
  -GodotPath $Godot -ProjectDirectory $Project -Mode Dedicated -TimeoutSeconds 30
powershell -NoProfile -ExecutionPolicy Bypass -File tests/runtime/RunNetworkIntegration.ps1 `
  -GodotPath $Godot -ProjectDirectory $Project -Mode Editor -TimeoutSeconds 30
```

Use the engine executable directly, rather than its console proxy, so timeout
cleanup owns the actual process. Runners suppress Windows crash UI, start hidden
headless processes, capture logs, enforce a deadline, and require exit code zero
and fixture PASS markers. The isolated project has no updater plugin and caps
Godot's worker pool at two threads. It uses a qualification-only user directory.
No editor/release workflow is launched.

Dedicated uses an ephemeral UDP port and two clients. Editor uses the inherited
`--glindex 1/2/3 --glcount 2` convention on port 25575, checking port availability
first; it does not open the graphical editor. Listen verifies both domains in
one process. ServerStorage denials in client logs are expected negative checks.
ENet teardown diagnostics must remain visible in qualification reports even if
the functional assertions pass. Logs are overwritten when reusing an output
directory; use distinct directories when preserving multiple runs.

See [validation](../../newdocs/shared-domains-validation.md) for observed results,
coverage, artifact identity and outstanding gaps.

## Cross-platform continuation qualification

The commands above preserve the initial Windows core-only sanitizer procedure.
For the expanded qualification, use `RunQualification.py` (Python 3.12):

```powershell
C:/Python312/python.exe tests/runtime/RunQualification.py --godot $Godot `
  --extension .runtime-tests/qualification/windows-debug.dll `
  --output .runtime-tests/qualification/windows-qualified-debug `
  --repeat 3 --teardown --timeout 45
```

It runs Integration, Listen, Dedicated/server+two clients and Editor/server+two
clients: eight process results per repetition. `--teardown` additionally destroys
NetworkService during an outstanding invoke and requires the caller's error.
Listen covers retained getters/mutators across service replacement. Each run
requires exit zero and PASS, preserves stderr, and fails on sanitizer errors.

Linux uses the task-owned container described in the validation report. Populate
`/work/source` with the candidate checkout and initialized pinned submodules;
populate `/work/baseline` with `src` from
`8b163269cbe44cf7fcf7a9a0285620878a2345fd`. Build with four jobs:

```sh
docker build -f tests/runtime/Qualification.Dockerfile \
  -t codex-godotluau-qualification:ubuntu24 .
# Existing task container: /opt/codex/godotluau:/work, --cpus 4 --memory 10g.
bash /work/source/tests/runtime/BuildLinux.sh /work 4
cmake -S /work/source/tests/runtime -B /work/builds/linux-debug -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DGL_BUILD_GODOT_ADAPTER=ON
cmake --build /work/builds/linux-debug --parallel 4
ctest --test-dir /work/builds/linux-debug --output-on-failure \
  --timeout 30 --repeat until-fail:20
```

Use LF shell scripts on Linux (Git checkout or archive). All image packages stay
inside Docker; do not install host packages or alter unrelated containers.
`BuildLinux.sh` builds Release/baseline, full-adapter ASan and both SCons targets.
Both CMake and SCons glob production core sources, including the domain/host.

```sh
python3 /work/source/tests/runtime/RunQualification.py \
  --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
  --extension /work/builds/linux-debug/godot_luau.so \
  --output /work/artifacts/linux-qualified-debug --teardown
# Repeat with linux-release and both source/GodotLuau/bin SCons libraries.
bash /work/source/tests/runtime/BuildSanitizedGodot.sh /work 4
ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:log_path=/work/artifacts/linux-full-asan-stress/report \
python3 /work/source/tests/runtime/RunQualification.py \
  --godot /work/godot-asan/bin/godot.linuxbsd.template_debug.dev.x86_64.san \
  --extension /work/builds/linux-asan/godot_luau.so \
  --output /work/artifacts/linux-full-asan-stress \
  --repeat 10 --teardown --coordinated-close --timeout 90
```

The sanitizer engine is exact Godot commit
`a13da4feb8d8aefc283c3763d33a2f170a18d541`; its supported ASan build avoids the
stock Linux loader's incompatible RTLD_DEEPBIND flag. The minimal headless build
does not qualify graphical rendering or production physics. Do not treat a stock
Windows executable plus instrumented DLL shutdown timeout as passing coverage.
`--load-only` isolates registration without any game/domain; both baseline and
candidate timed out in that Windows combination, with ASan DLLs copied using
`--runtime-directory`. The smallest next step is an instrumented Windows host.

`--coordinated-close` orders client closes using the server's completed poll. It
isolates native lifecycle stress from the independently reproduced engine leak;
it does not qualify simultaneous close or suppress diagnostics. Preserve the
adversarial reproduction separately:

```sh
python3 /work/source/tests/runtime/RunQualification.py \
  --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
  --extension /work/builds/linux-release/godot_luau.so \
  --output /work/artifacts/linux-probe --probe --repeat 5
```

The probe's project never loads the supplied extension. Five combinations test
relay on/off and no/synchronous/deferred application sends. To retain the failing
LSan reproduction, run the instrumented engine directly in that engine-only
project with `--script res://ENetDisconnectProbe.gd -- 32579 true none` and the
same ASAN_OPTIONS. Expect functional PASS followed by a nonzero leak exit.

Windows SCons uses the owner's approved portable wheel, SHA256
`2f66a1c5c485068a496c12356583eefb2d79e17177278c7334b12b460f0503ce`,
unpacked at `C:\Sandbox\Codex\Tools\GodotLuauSCons`. In the existing MSVC
developer environment, run the controlled Python executable with:

```text
tests/runtime/RunSConsPortable.py C:\Sandbox\Codex\Tools\GodotLuauSCons platform=windows target=template_debug -j4
tests/runtime/RunSConsPortable.py C:\Sandbox\Codex\Tools\GodotLuauSCons platform=windows target=template_release -j4
```

## Controlled benchmark and local package

Run on an idle worker after Release/baseline compilation, with the same engine,
compiler flags, pinned dependencies and CPU/memory allocation:

```sh
python3 /work/source/tests/runtime/RunQualification.py \
  --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
  --extension /work/builds/linux-release/godot_luau.so \
  --baseline /work/builds/linux-release/godot_luau_baseline.so \
  --output /work/artifacts/benchmark-final --repeat 3 --timeout 120
python3 /work/source/tests/runtime/SummarizeBenchmark.py \
  /work/artifacts/benchmark-final/results.json
```

Default counts are 10/100/1,000. Trial order reverses every other trial. Each
script requires once, checks 100 cache hits, creates/cancels 32 deferred tasks,
then waits 20 frames. RSS is sampled externally at phase handshakes; times use
monotonic elapsed clocks. Startup includes VM/bootstrap/compile/work/wait costs,
not isolated VM allocation. Destroy/shutdown include two frame boundaries.
Frame intervals include headless pacing; TIME_PROCESS is a coarse, stale monitor
and is excluded from conclusions. No reload or graphical frame-rate claim is made.

`PackageQualification.py --revision <committed-source-SHA> --windows-debug ...
--windows-release ... --linux-debug ... --linux-release ... --output <ignored.zip>`
requires clean production source/pins and explicit four-library inputs. It copies
the descriptor, current GodotLuau runtime assets/licenses and supplied libraries,
excludes inherited binaries/updater, checks every descriptor resource is included,
records SHA256s and the normalized native source fingerprint, then checks CRC and hashes.
This is a local test archive, never an authorized release workflow invocation.

## GL-019 profiling and optimization comparison

The measurement-harness commit `0427a3560ac01b191aa7dcc8b2c144f8eccda2dd`
has the same production runtime as pre-GL-019 main
`aa5400321b8f838a75de8d2b4005b0c5165dab34`. Runtime optimization commit
`1756cc2600e5a59ea948e69a684f5abd93e32229` contains the candidate. Build the
harness revision first, preserve its binaries, then update to the candidate and
incrementally build in the same Release tree. Both use the same pinned vendors.

```sh
cmake -S /work/source/tests/runtime -B /work/builds/linux-release \
  -DGL_BUILD_HOT_PATH_BENCHMARKS=ON
cmake --build /work/builds/linux-release \
  --target GodotLuauAdapter HotPathBenchmarks --parallel 4
# Before updating production source:
cp /work/builds/linux-release/godot_luau.so /work/artifacts/gl019/pre-gl019.so
cp /work/builds/linux-release/HotPathBenchmarks /work/artifacts/gl019/pre-hotpaths
# Update to the candidate, rebuild the same targets, preserve post-gl019.so/post-hotpaths.
python3 /work/source/tests/runtime/RunRequireBenchmark.py \
  --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
  --baseline /work/artifacts/gl019/pre-gl019.so \
  --extension /work/artifacts/gl019/post-gl019.so \
  --output /work/artifacts/gl019/require-final --repeat 7
python3 /work/source/tests/runtime/RunHotPathBenchmarks.py \
  --baseline /work/artifacts/gl019/pre-hotpaths \
  --candidate /work/artifacts/gl019/post-hotpaths \
  --output /work/artifacts/gl019/micro-comparison.jsonl --repeat 11
# Sensitivity run: --counts 10000 --repeat 21, using a separate output file.
python3 /work/source/tests/runtime/RunQualification.py \
  --godot /work/tools/Godot_v4.7.1-stable_linux.x86_64 \
  --baseline /work/artifacts/gl019/pre-gl019.so \
  --extension /work/artifacts/gl019/post-gl019.so \
  --output /work/artifacts/gl019/population-comparison --repeat 7 --timeout 120
```

RequireBenchmark captures the native module before timing one million cached
calls, separating require from hierarchy lookup. Cold initialization is timed
separately. The population fixture is unchanged. Its generic labels `Baseline`
and `Shared` mean pre/post GL-019 in this comparison; in the separate fresh
original/shared baseline file they mean per-script/shared architectures.

HotPathBenchmarks links the production core and pinned Luau. It separately times
defer/delay creation, cancellation, reaping, resume/yield/completion, idle pending
ticks, owner cancellation, manual coroutines, concurrent require and shutdown.
Concurrent start includes owner creation/compilation. It reports monotonic elapsed
ms, process CPU ms (`std::clock`), C++ new-call counts and requested allocation
bytes. These counters exclude Luau/Godot malloc, do not measure peak/live bytes,
and exist only in the optional test executable. Native scheduler CPU can differ
from this single-threaded core benchmark; headless frame pacing is not CPU proof.
Both runners counterbalance trial order, preserve every row and bound children.

Native perf sampling ran on linuxbox, scoped to only this task's container cgroup.
No perf settings or packages changed. On the host, obtain the group's relative
path from `/proc/<docker-inspect-State.Pid>/cgroup`, then run in parallel:

```sh
perf record -a -e cycles:u -G "$Group" -F 997 --call-graph dwarf \
  -o "$Artifacts/pre-require.perf" -- sleep 25
perf stat -a -e task-clock,cycles,instructions -G "$Group" \
  -o "$Artifacts/pre-require-stat.txt" -- sleep 25
# During that interval, docker exec the require runner with --calls 3000000 --repeat 5.
# Repeat for the candidate with its own output paths and a 15-second capture.
perf report -i "$Artifacts/pre-require.perf" --symfs "$Artifacts/symbols" \
  --stdio --children --call-graph none --sort symbol,dso
```

The task-owned symbol root maps `symbols/work` to `/opt/codex/godotluau`, allowing
host perf to resolve container `/work/...` extension paths. The official Godot
binary is stripped; inclusive caller costs overlap. Profiled runs are separate
from the unprofiled latency trials. Raw data, commands, identities, accepted/
rejected candidates and qualification are in the
[GL-019 report](../../newdocs/shared-domains-validation.md#gl-019-optimization-2026-10-26).
