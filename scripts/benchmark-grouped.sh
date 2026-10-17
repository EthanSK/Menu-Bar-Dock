#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/menubardock-benchmark.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
sources=()
for source in "$repo_dir"/MenuBarDock/*.swift; do
    [[ "$(basename "$source")" == "AppDelegate.swift" ]] && continue
    sources+=("$source")
done
xcrun swiftc -O -D LOCAL_BUILD -swift-version 5 -module-name Menu_Bar_Dock \
    -module-cache-path "${MBD_MODULE_CACHE:-$build_dir/module-cache}" \
    "${sources[@]}" "$repo_dir/scripts/benchmarks/main.swift" -o "$build_dir/benchmark"
"$build_dir/benchmark"
