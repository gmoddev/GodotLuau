# Shared-domain regression fixtures

These tests exercise the production `GLExecutionDomain` implementation and the
actual Godot adapters. They do not use a second scheduler/cache implementation.
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

`ExecutionDomainTests` runs 35 cases and exits nonzero on any failure. Its fake
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
