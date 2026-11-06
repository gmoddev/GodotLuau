#!/usr/bin/env bash
set -euo pipefail
Root="${1:-/work}"
Jobs="${2:-4}"
Revision=a13da4feb8d8aefc283c3763d33a2f170a18d541
if [ ! -f "$Root/godot-asan/SConstruct" ]; then
    curl --fail --location --max-time 120 "https://codeload.github.com/godotengine/godot/tar.gz/$Revision" -o "$Root/tools/godot-source.tar.gz"
    mkdir -p "$Root/godot-asan"
    tar -xf "$Root/tools/godot-source.tar.gz" --strip-components=1 -C "$Root/godot-asan"
fi
cd "$Root/godot-asan"
scons platform=linuxbsd target=template_debug use_asan=yes use_lsan=yes \
    use_static_cpp=no linker=lld dev_build=yes debug_symbols=no optimize=none \
    disable_path_overrides=no x11=no wayland=no vulkan=no opengl3=no accesskit=no \
    alsa=no pulseaudio=no dbus=no speechd=no fontconfig=no udev=no \
    modules_enabled_by_default=no module_gdscript_enabled=yes \
    module_multiplayer_enabled=yes module_enet_enabled=yes \
    module_mbedtls_enabled=yes \
    module_godot_physics_2d_enabled=yes module_godot_physics_3d_enabled=yes \
    module_freetype_enabled=yes \
    module_text_server_fb_enabled=yes -j"$Jobs"
