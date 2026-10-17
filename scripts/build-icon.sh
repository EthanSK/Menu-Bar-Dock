#!/bin/bash
# Preserve opaque PNG artwork verbatim; do not add inferred material metadata.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_icon="${1:?Usage: build-icon.sh /path/to/output.icns}"
python3 "$repo_dir/scripts/package-app-icon.py" \
    "$repo_dir/MenuBarDock/Assets.xcassets/AppIcon.appiconset" "$output_icon"
