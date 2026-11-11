#!/usr/bin/env bash
set -euo pipefail
# Configured Ubuntu mirrors failed DNS in retained GL-051 attempts. Choose a
# reachable archive on this disposable runner; signed APT verification and the
# selected compiler/engine profiles remain unchanged.
if [[ -f /etc/apt/apt-mirrors.txt ]]; then
    Selected=""
    for Mirror in https://archive.ubuntu.com/ubuntu https://azure.archive.ubuntu.com/ubuntu https://mirrors.edge.kernel.org/ubuntu; do
        if curl --fail --silent --show-error --connect-timeout 4 --max-time 8 "$Mirror/dists/noble/InRelease" -o /dev/null; then
            Selected="$Mirror"
            break
        fi
    done
    if [[ -z "$Selected" ]]; then
        echo '[Build:Provision] No Ubuntu archive is reachable.' >&2
        exit 1
    fi
    printf '%s\n' "$Selected" | sudo tee /etc/apt/apt-mirrors.txt >/dev/null
    echo "[Build:Provision] Ubuntu archive: $Selected"
fi
Packages=(clang-19 lld-19 pkg-config ninja-build)
if [[ "${1:-}" == "--sanitizers" ]]; then Packages+=(libclang-rt-19-dev); fi
Options=(-o Acquire::ForceIPv4=true -o Acquire::Retries=1 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15)
sudo apt-get "${Options[@]}" -o APT::Update::Error-Mode=any update
sudo apt-get "${Options[@]}" install --no-install-recommends -y "${Packages[@]}"
