#!/usr/bin/env bash
set -euo pipefail
# Hosted Ubuntu's Azure HTTP mirror stalled in two retained GL-051 attempts.
# Use the official HTTPS archive on this disposable runner, keeping signed APT
# verification, selected compiler packages and the workflow deadline unchanged.
if [[ -f /etc/apt/apt-mirrors.txt ]]; then
    sudo sed -i 's|http://azure.archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' /etc/apt/apt-mirrors.txt
fi
Packages=(clang-19 lld-19 pkg-config ninja-build)
if [[ "${1:-}" == "--sanitizers" ]]; then Packages+=(libclang-rt-19-dev); fi
sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 update
sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 install --no-install-recommends -y "${Packages[@]}"
