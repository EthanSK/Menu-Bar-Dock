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

# 2. Embedded Launcher helper apps. The target embeds Launcher.app twice:
#    - Contents/Library/LoginItems/Launcher.app is the login-item helper.
#    - Contents/Resources/Launcher.app is also copied as a resource by the
#      legacy project setup, and Apple's notarization service validates it too.
#    Sign both copies with the launcher entitlements before sealing the outer
#    app, otherwise notarization rejects the unsigned resource copy even though
#    codesign --deep verification can pass locally.
shopt -s nullglob
LAUNCHER_APPS=(
    "$APP"/Contents/Library/LoginItems/*.app
    "$APP"/Contents/Resources/Launcher.app
)
shopt -u nullglob

if [[ ${#LAUNCHER_APPS[@]} -eq 0 ]]; then
    echo "sign-release.sh: (no embedded Launcher apps found — skipping)"
fi

for launcher_app in "${LAUNCHER_APPS[@]}"; do
    echo "sign-release.sh: signing embedded Launcher helper: $launcher_app"
    sign "$launcher_app" "$LAUNCHER_ENTITLEMENTS"
done

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
