#!/usr/bin/env bash
set -euo pipefail
Root="${1:-/work}"
Jobs="${2:-4}"
python3 "$(dirname "$0")/BuildSanitizedGodot.py" --output "$Root/godot-asan" --jobs "$Jobs"
