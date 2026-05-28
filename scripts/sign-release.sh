#!/usr/bin/env bash
# sign-release.sh — post-archive deep-sign for Menu Bar Dock.
#
# Why this script exists (mirrors the pattern from
# macos-widgets-stats-from-website's sign-release.sh):
#   Under Xcode 16+ a Release archive built with automatic signing + Developer
#   ID Application identity is fragile — xcodebuild flip-flops between
#   automatic and manual provisioning and the embedded Launcher login-item
#   helper + Sparkle framework can end up with mismatched signatures. The
#   working pattern is:
#     1. xcodebuild archive with CODE_SIGN_IDENTITY="-" (ad-hoc).
#     2. This script walks the archived .app inside-out and re-signs every
#        nested bundle with the real Developer ID Application identity using
#        each bundle's correct entitlements.
#     3. notarytool submit + xcrun stapler staple (handled by the workflow).
#
# Usage:
#   ./scripts/sign-release.sh <path/to/.app or path/to/.xcarchive> [IDENTITY]
# Defaults IDENTITY to "Developer ID Application: Ethan Sarif-Kattan (T34G959ZG8)"
# — match Ethan's other release pipelines.
#
# Exits non-zero on any failed signature.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path/to/.app or path/to/.xcarchive> [IDENTITY]" >&2
    exit 1
fi

INPUT="$1"
IDENTITY="${2:-Developer ID Application: Ethan Sarif-Kattan (T34G959ZG8)}"

# Resolve to the actual .app, whether the caller passed a .app or .xcarchive.
if [[ -d "$INPUT" && "$INPUT" == *.xcarchive ]]; then
    APP_CANDIDATES=("$INPUT"/Products/Applications/*.app)
    if [[ ${#APP_CANDIDATES[@]} -ne 1 || ! -d "${APP_CANDIDATES[0]}" ]]; then
        echo "sign-release.sh: ERROR — could not find exactly one .app inside $INPUT/Products/Applications" >&2
        exit 1
    fi
    APP="${APP_CANDIDATES[0]}"
elif [[ -d "$INPUT" && "$INPUT" == *.app ]]; then
    APP="$INPUT"
else
    echo "sign-release.sh: ERROR — input must be a .app or .xcarchive directory: $INPUT" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_ENTITLEMENTS="$REPO_ROOT/MenuBarDock/MenuBarDock.entitlements"
LAUNCHER_ENTITLEMENTS="$REPO_ROOT/Launcher/Launcher.entitlements"

# Sanity-check the entitlements files exist BEFORE we touch any signatures —
# otherwise codesign would happily strip entitlements and we'd ship a broken
# Hardened-Runtime build.
for entitlements_file in "$MAIN_ENTITLEMENTS" "$LAUNCHER_ENTITLEMENTS"; do
    if [[ ! -f "$entitlements_file" ]]; then
        echo "sign-release.sh: ERROR — entitlements file missing: $entitlements_file" >&2
        exit 1
    fi
done

echo "sign-release.sh: target  = $APP"
echo "sign-release.sh: identity= $IDENTITY"

# Helper — sign a single path with the given entitlements (or none).
# --options runtime enables Hardened Runtime (required for notarization).
# --timestamp sends each signature to Apple's timestamp server so the
# signature stays valid even after the signing cert expires.
sign() {
    local target="$1"
    local entitlements_file="${2:-}"
    if [[ -n "$entitlements_file" ]]; then
        /usr/bin/codesign --force --options runtime --timestamp \
            --entitlements "$entitlements_file" \
            --sign "$IDENTITY" \
            "$target"
    else
        /usr/bin/codesign --force --options runtime --timestamp \
            --sign "$IDENTITY" \
            "$target"
    fi
}

# 1. Sparkle framework — XPCs first (Installer + Downloader), then Autoupdate,
#    then the Updater.app, then the framework wrapper itself. Innermost-first
#    is mandatory: codesign walks the bundle tree top-down and any unsigned
#    nested bundle invalidates the outer signature.
SPARKLE_FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "sign-release.sh: signing Sparkle.framework tree..."
    SPARKLE_VERSIONS_CURRENT="$SPARKLE_FRAMEWORK/Versions/Current"
    if [[ -d "$SPARKLE_VERSIONS_CURRENT/XPCServices" ]]; then
        for xpc in "$SPARKLE_VERSIONS_CURRENT/XPCServices"/*.xpc; do
            [[ -d "$xpc" ]] && sign "$xpc"
        done
    fi
    [[ -f "$SPARKLE_VERSIONS_CURRENT/Autoupdate" ]] && sign "$SPARKLE_VERSIONS_CURRENT/Autoupdate"
    [[ -d "$SPARKLE_VERSIONS_CURRENT/Updater.app" ]] && sign "$SPARKLE_VERSIONS_CURRENT/Updater.app"
    sign "$SPARKLE_FRAMEWORK"
else
    echo "sign-release.sh: WARN — no Sparkle.framework found at $SPARKLE_FRAMEWORK"
    echo "sign-release.sh: this means pod install did NOT embed Sparkle into the archive."
    echo "sign-release.sh: investigate the Pods integration before continuing."
fi

# 2. Embedded Launcher login-item helper — Menu Bar Dock ships a helper app
#    inside Contents/Library/LoginItems/ so it can register itself with
#    SMAppService / SMLoginItemSetEnabled at runtime. Xcode currently emits it
#    as Launcher.app, while older project notes expected "Menu Bar
#    DockLauncher.app", so sign every login-item app we find. The helper has
#    its own entitlements file (Launcher/Launcher.entitlements). Pre-13 macOS
#    uses the SMLoginItemSetEnabled path which requires the launcher to be
#    signed with the same Team ID as the main app — re-signing here guarantees
#    the team ID matches in CI.
LOGIN_ITEMS_DIR="$APP/Contents/Library/LoginItems"
if [[ -d "$LOGIN_ITEMS_DIR" ]]; then
    shopt -s nullglob
    LOGIN_ITEM_APPS=("$LOGIN_ITEMS_DIR"/*.app)
    shopt -u nullglob

    if [[ ${#LOGIN_ITEM_APPS[@]} -eq 0 ]]; then
        echo "sign-release.sh: (LoginItems exists but contains no .app bundles — skipping)"
    fi

    for launcher_app in "${LOGIN_ITEM_APPS[@]}"; do
        echo "sign-release.sh: signing embedded Launcher login-item helper: $launcher_app"
        sign "$launcher_app" "$LAUNCHER_ENTITLEMENTS"
    done
else
    echo "sign-release.sh: (no LoginItems directory — skipping)"
fi

# 3. Outer .app last — applies the main-app entitlements. Outer-app signing
#    is what seals the bundle, so this MUST run after every nested bundle
#    has been signed. Otherwise codesign --deep --strict would reject the
#    bundle on verification.
echo "sign-release.sh: signing outer .app..."
sign "$APP" "$MAIN_ENTITLEMENTS"

# 4. Verify the whole tree. --deep --strict traverses every nested bundle;
#    any signature mismatch fails here loudly before notarization.
echo "sign-release.sh: verifying signatures..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

echo "sign-release.sh: done."
