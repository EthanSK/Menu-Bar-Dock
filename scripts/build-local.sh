#!/bin/bash
# Build a separate, ad-hoc signed Apple Silicon app using an installed 4.8.0's
# compiled storyboard/assets. Xcode is unnecessary; Swift Command Line Tools suffice.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
default_resources="/Applications/Menu Bar Dock.app"
[[ -d "$default_resources" ]] || default_resources="$repo_dir/../../outputs/Menu Bar Dock Grouped.app"
resource_app="${1:-$default_resources}"
output_app="${2:-$repo_dir/build/Menu Bar Dock Grouped.app}"
if [[ -e "$output_app" ]]; then
    echo "Output already exists: $output_app" >&2
    exit 1
fi
resource_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$resource_app/Contents/Info.plist")"
if [[ "$resource_version" != "4.8.0" && "$resource_version" != 4.8.0-grouped.* ]]; then
    echo "This build needs Menu Bar Dock 4.8.0 or an earlier grouped build's resources." >&2
    exit 1
fi
mkdir -p "$(dirname "$output_app")"
build_dir="$(mktemp -d "$(dirname "$output_app")/.grouped-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
app="$build_dir/Menu Bar Dock Grouped.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build_dir/module-cache"
for resource in "$resource_app/Contents/Resources/"*; do
    [[ "$(basename "$resource")" == "Launcher.app" ]] && continue
    ditto --noextattr --norsrc "$resource" "$app/Contents/Resources/$(basename "$resource")"
done
cp "$resource_app/Contents/Info.plist" "$app/Contents/Info.plist"
"$repo_dir/scripts/build-icon.sh" "$app/Contents/Resources/GroupedAppIcon.icns"
# The inherited compiled catalog still contains the old icon. Use the new
# standalone ICNS so Finder does not resolve that stale asset by name.
if /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$app/Contents/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$app/Contents/Info.plist"
fi
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile GroupedAppIcon' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.menubardock.grouped' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Menu Bar Dock Grouped' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 4.8.0-grouped.13' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 41' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 11.0' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :SUEnableAutomaticChecks false' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :SUAllowsAutomaticUpdates false' "$app/Contents/Info.plist"
xcrun swiftc -O -D LOCAL_BUILD -swift-version 5 -module-name Menu_Bar_Dock \
    -target arm64-apple-macosx11.0 -module-cache-path "${MBD_MODULE_CACHE:-$build_dir/module-cache}" \
    "$repo_dir"/MenuBarDock/*.swift -o "$app/Contents/MacOS/Menu Bar Dock"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
mv "$app" "$output_app"
echo "Built: $output_app"
