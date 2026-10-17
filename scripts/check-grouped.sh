#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/menubardock-checks.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
sources=()
for source in "$repo_dir"/MenuBarDock/*.swift; do
    sources+=("$source")
done
xcrun swiftc -D LOCAL_BUILD -D APP_TEST -swift-version 5 -module-name Menu_Bar_Dock \
    -module-cache-path "${MBD_MODULE_CACHE:-$build_dir/module-cache}" \
    "${sources[@]}" "$repo_dir/scripts/checks/main.swift" -o "$build_dir/checks"
resource_app="${MBD_RESOURCE_APP:-/Applications/Menu Bar Dock.app}"
[[ -d "$resource_app" ]] || resource_app="$repo_dir/../../outputs/Menu Bar Dock Grouped.app"
MBD_RESOURCE_APP="$resource_app" "$build_dir/checks"
