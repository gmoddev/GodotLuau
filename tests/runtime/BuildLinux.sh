#!/usr/bin/env bash
set -euo pipefail
Root="${1:-/work}"
Jobs="${2:-4}"
Source="$Root/source"
cmake -S "$Source/tests/runtime" -B "$Root/builds/linux-release" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DGL_BUILD_GODOT_ADAPTER=ON \
    -DGL_BASELINE_SOURCE_ROOT="$Root/baseline" >"$Root/logs/linux-release-configure.log" 2>&1
cmake --build "$Root/builds/linux-release" --target GodotLuauAdapter GodotLuauBaselineAdapter ExecutionDomainTests \
    --parallel "$Jobs" >"$Root/logs/linux-release-build.log" 2>&1
ctest --test-dir "$Root/builds/linux-release" --output-on-failure --timeout 30 \
    >"$Root/logs/linux-release-tests.log" 2>&1
cmake -S "$Source/tests/runtime" -B "$Root/builds/linux-asan" -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug -DGL_BUILD_GODOT_ADAPTER=ON \
    '-DCMAKE_CXX_FLAGS=-fsanitize=address -fno-omit-frame-pointer' \
    -DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address -DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address \
    >"$Root/logs/linux-asan-configure.log" 2>&1
cmake --build "$Root/builds/linux-asan" --target GodotLuauAdapter ExecutionDomainTests \
    --parallel "$Jobs" >"$Root/logs/linux-asan-build.log" 2>&1
ctest --test-dir "$Root/builds/linux-asan" --output-on-failure --timeout 30 --repeat until-fail:20 \
    >"$Root/logs/linux-asan-tests.log" 2>&1
cd "$Source"
scons platform=linux target=template_debug -j"$Jobs" >"$Root/logs/scons-linux-debug.log" 2>&1
scons platform=linux target=template_release -j"$Jobs" >"$Root/logs/scons-linux-release.log" 2>&1
echo '[Runtime:Build] Linux Release, full-adapter ASan and SCons Debug/Release passed'
