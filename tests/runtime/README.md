# Shared-domain regression fixtures

These tests exercise the production `GLExecutionDomain` implementation and the
actual Godot adapters. They do not use a second scheduler/cache implementation.
`main` is the current shared-domain development baseline; the historical source
branch and reused qualification scope are recorded in the
[integration record](../../newdocs/shared-domains-validation.md#main-integration-2026-10-26).
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

`ExecutionDomainTests` runs 36 cases and exits nonzero on any failure. Its fake
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
