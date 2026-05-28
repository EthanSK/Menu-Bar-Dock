#!/usr/bin/env bash
# bump-version.sh — bump MARKETING_VERSION + CURRENT_PROJECT_VERSION across
# every Debug + Release build config in Menu Bar Dock.xcodeproj/project.pbxproj.
#
# Usage:
#   scripts/bump-version.sh <new-marketing-version> [<new-build-number>]
#
# Examples:
#   scripts/bump-version.sh 4.7.0          # auto-increment build number
#   scripts/bump-version.sh 4.7.0 27       # explicit build number
#
# The marketing version MUST be x.y.z semver (Sparkle's appcast validator
# rejects 2-part versions like "4.6"). If no build number is provided we
# increment the existing CURRENT_PROJECT_VERSION by 1.
#
# This script is the canonical entry point for version bumps — DO NOT edit
# .pbxproj by hand for versioning. Doing so would risk only updating one of
# the Debug/Release configs and leaving the other stale, which manifests as
# silent CI failures (the release workflow reads the FIRST match).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT/Menu Bar Dock.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    echo "bump-version.sh: ERROR — pbxproj not found at $PBXPROJ" >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: scripts/bump-version.sh <new-marketing-version> [<new-build-number>]" >&2
    exit 64
fi

NEW_VERSION="$1"
NEW_BUILD="${2:-}"

# Strict semver check — Sparkle's appcast validator rejects anything else.
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "bump-version.sh: ERROR — marketing version must be x.y.z, got $NEW_VERSION" >&2
    exit 1
fi

# Read the current build number out of the pbxproj. We expect every
# CURRENT_PROJECT_VERSION line to carry the same value — they should be in
# lockstep across Debug + Release configs.
CURRENT_BUILD="$(grep -oE "CURRENT_PROJECT_VERSION = [0-9]+;" "$PBXPROJ" | head -1 | grep -oE "[0-9]+")"
if [[ -z "$CURRENT_BUILD" ]]; then
    echo "bump-version.sh: ERROR — could not find CURRENT_PROJECT_VERSION in pbxproj" >&2
    exit 1
fi

if [[ -z "$NEW_BUILD" ]]; then
    NEW_BUILD=$((CURRENT_BUILD + 1))
fi

if ! [[ "$NEW_BUILD" =~ ^[0-9]+$ ]] || [[ "$NEW_BUILD" -le 0 ]]; then
    echo "bump-version.sh: ERROR — build number must be a positive integer, got $NEW_BUILD" >&2
    exit 1
fi

# Sparkle compares build numbers numerically — going backwards or sideways
# would let an installed copy refuse the offered update. Hard-fail on it.
if [[ "$NEW_BUILD" -le "$CURRENT_BUILD" ]]; then
    echo "bump-version.sh: ERROR — new build number ($NEW_BUILD) must be > current ($CURRENT_BUILD)" >&2
    exit 1
fi

# In-place sed across both build configs. sed -i requires '' on macOS BSD
# vs no-arg on GNU; the empty-arg form works for BSD only — we're macOS-only
# here so that's fine.
sed -i '' \
    -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${NEW_VERSION};/g" \
    "$PBXPROJ"
sed -i '' \
    -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" \
    "$PBXPROJ"

# Sanity check — make sure every match line ended up at the new value.
FINAL_MV="$(grep -oE "MARKETING_VERSION = [^;]+;" "$PBXPROJ" | sort -u)"
FINAL_BV="$(grep -oE "CURRENT_PROJECT_VERSION = [0-9]+;" "$PBXPROJ" | sort -u)"
if [[ "$(echo "$FINAL_MV" | wc -l | tr -d ' ')" != "1" ]]; then
    echo "bump-version.sh: ERROR — MARKETING_VERSION rewrite ended up non-uniform: $FINAL_MV" >&2
    exit 1
fi
if [[ "$(echo "$FINAL_BV" | wc -l | tr -d ' ')" != "1" ]]; then
    echo "bump-version.sh: ERROR — CURRENT_PROJECT_VERSION rewrite ended up non-uniform: $FINAL_BV" >&2
    exit 1
fi

echo "bump-version.sh: bumped to $NEW_VERSION (build $NEW_BUILD)"
echo "  $FINAL_MV"
echo "  $FINAL_BV"
echo ""
echo "Next steps:"
echo "  1. Update CHANGELOG.md with notes for v$NEW_VERSION"
echo "  2. git commit -am 'Bump version to $NEW_VERSION'"
echo "  3. git tag v$NEW_VERSION && git push origin master --tags"
