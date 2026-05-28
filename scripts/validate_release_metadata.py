#!/usr/bin/env python3
"""Validate release, Sparkle appcast, and GitHub Pages metadata for Menu Bar Dock.

Focuses on distribution-facing files so placeholder Sparkle signatures, stale
download links, and rename leftovers fail loudly BEFORE they reach gh-pages.

Mirrors macos-widgets-stats-from-website/scripts/validate_release_metadata.py
(voice 7174, 2026-05-28). Differences:
  - Reads versions from .xcodeproj via agvtool (no project.yml).
  - Doesn't validate per-target Info.plist version placeholders (the .pbxproj
    handles version substitution at build time via MARKETING_VERSION /
    CURRENT_PROJECT_VERSION build settings — Info.plist for this project
    uses $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION) placeholders
    inherited from the target's build configuration).
"""

from __future__ import annotations

import argparse
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = "EthanSK/Menu-Bar-Dock"
SITE_URL = "https://www.menubardock.com/"
APP_NAME = "Menu Bar Dock"
# On-disk ZIP basename prefix uses URL-safe hyphens — spaces would
# percent-encode in the Sparkle enclosure URL and break some download clients.
# Same rationale as macos-widgets-stats-from-website.
APP_BUNDLE_NAME = "Menu-Bar-Dock"
LATEST_ZIP = "Menu-Bar-Dock-latest.zip"
LATEST_ZIP_URL = f"https://github.com/{REPO}/releases/latest/download/{LATEST_ZIP}"

# Legacy / stale tokens we don't want creeping back into release-facing files.
# Note: the OLD bare-number tag scheme (e.g. "4.6") is fine to leave as
# historical context in CHANGELOG.md and elsewhere — it's only banned in
# the appcast and release.yml.
OLD_TOKENS: list[str] = [
    # Add tokens here if we rename the repo or app in future. Empty list for
    # now since Menu Bar Dock has only ever had this name.
]
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ATOM_NS = "http://www.w3.org/2005/Atom"
SPARKLE = f"{{{SPARKLE_NS}}}"
ATOM = f"{{{ATOM_NS}}}"
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
BASE64_RE = re.compile(r"^[A-Za-z0-9+/=]+$")

# Files we sanity-check for stale rename tokens + required snippets.
RELEASE_CONFIG_FILES = [
    Path(".github/workflows/release.yml"),
    Path("README.md"),
    Path("docs/release.md"),
]


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def assert_no_old_tokens(path: Path, text: str) -> None:
    for token in OLD_TOKENS:
        if token in text:
            fail(f"{path} contains stale rename token {token!r}")


def check_repo(root: Path) -> None:
    """Validate the release.yml + update_appcast.py + docs are internally consistent."""
    for relative in RELEASE_CONFIG_FILES:
        path = root / relative
        if path.exists():
            text = read_text(path)
            assert_no_old_tokens(relative, text)

    workflow = read_text(root / ".github/workflows/release.yml")
    # Required snippets — if any of these are missing, the workflow is
    # subtly broken (e.g. no tag trigger, no validation step, etc.).
    required_snippets = [
        "tags:",
        "'v*'",
        "make_latest: true",
        LATEST_ZIP,
        "softprops/action-gh-release@v2",
        "scripts/validate_release_metadata.py",
        "scripts/prepare_release_metadata.py",
    ]
    for snippet in required_snippets:
        if snippet not in workflow:
            fail(f"release workflow is missing required snippet {snippet!r}")

    update_appcast = read_text(root / "scripts/update_appcast.py")
    for snippet in [REPO, SITE_URL, "PLACEHOLDER", "ZIP_SIZE", "ED_SIGNATURE"]:
        if snippet not in update_appcast:
            fail(f"update_appcast.py is missing expected validation/reference {snippet!r}")


def _read_xcodeproj_versions(root: Path) -> tuple[str, str]:
    """Read MARKETING_VERSION + CURRENT_PROJECT_VERSION from .xcodeproj/project.pbxproj.

    We parse the pbxproj directly rather than using agvtool because this
    project's Info.plist uses $(MARKETING_VERSION) placeholder substitution
    (the build setting is the source of truth) — agvtool would report the
    literal placeholder string for that target. Xcode keeps the value
    consistent across Debug + Release configs, so the FIRST regex match is
    canonical. scripts/bump-version.sh updates ALL matches in one pass.
    """
    xcodeproj = root / "Menu Bar Dock.xcodeproj"
    if not xcodeproj.exists():
        fail("Menu Bar Dock.xcodeproj does not exist at repo root")

    text = (xcodeproj / "project.pbxproj").read_text(encoding="utf-8")
    mv = re.search(r"MARKETING_VERSION\s*=\s*([^;]+);", text)
    bv = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", text)
    if not mv or not bv:
        fail("project.pbxproj is missing MARKETING_VERSION or CURRENT_PROJECT_VERSION")
    return mv.group(1).strip(), bv.group(1).strip()


def check_versions(root: Path) -> None:
    """Validate that the marketing version is x.y.z semver + build is a positive int."""
    version, build = _read_xcodeproj_versions(root)

    if not SEMVER_RE.match(version):
        fail(
            f"Xcode project MARKETING_VERSION must be x.y.z (semver), got {version!r}. "
            "Run scripts/bump-version.sh to bump cleanly."
        )
    if not build.isdigit() or int(build) <= 0:
        fail(f"Xcode project CURRENT_PROJECT_VERSION must be a positive integer, got {build!r}")

    # Validate Info.plist has the expected Sparkle keys + no placeholder values.
    info_plist_path = root / "MenuBarDock/Info.plist"
    if not info_plist_path.exists():
        fail(f"Info.plist not found at {info_plist_path}")

    with info_plist_path.open("rb") as handle:
        payload = plistlib.load(handle)

    feed_url = str(payload.get("SUFeedURL", ""))
    public_key = str(payload.get("SUPublicEDKey", ""))
    if feed_url != f"{SITE_URL}appcast.xml":
        fail(f"Main app SUFeedURL is {feed_url!r}, expected {SITE_URL}appcast.xml")
    if not public_key or "PLACEHOLDER" in public_key.upper():
        fail("Main app SUPublicEDKey is missing or placeholder")


def check_signature(signature: str) -> None:
    upper = signature.upper()
    if any(token in upper for token in ["PLACEHOLDER", "CHANGEME", "TODO", "TBD", "DUMMY"]):
        fail("appcast enclosure has a placeholder Sparkle Ed25519 signature")
    if len(signature) < 40 or not BASE64_RE.match(signature):
        fail("appcast enclosure Sparkle Ed25519 signature does not look like base64 output")


def check_appcast(path: Path, require_item: bool) -> None:
    """Walk appcast.xml and verify every <item> looks legit."""
    raw = read_text(path)
    assert_no_old_tokens(path, raw)

    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        fail(f"appcast is not well-formed XML: {exc}")

    channel = root.find("channel")
    if channel is None:
        fail("appcast is missing <channel>")

    title = (channel.findtext("title") or "").strip()
    link = (channel.findtext("link") or "").strip()
    description = (channel.findtext("description") or "").strip()
    atom_link = channel.find(f"{ATOM}link")

    if APP_NAME not in title:
        fail("appcast channel title does not use the expected app name")
    if link != SITE_URL:
        fail(f"appcast channel link is {link!r}, expected {SITE_URL!r}")
    if APP_NAME not in description:
        fail("appcast channel description does not use the expected app name")
    if atom_link is None or atom_link.get("href") != f"{SITE_URL}appcast.xml":
        fail("appcast atom self-link does not point at the expected appcast URL")

    items = channel.findall("item")
    if require_item and not items:
        fail("appcast has no release items")

    for item in items:
        title = (item.findtext("title") or "").strip()
        if APP_NAME not in title:
            fail(f"appcast item title does not use expected app name: {title!r}")

        sparkle_version = (item.findtext(f"{SPARKLE}version") or "").strip()
        short_version = (item.findtext(f"{SPARKLE}shortVersionString") or "").strip()
        notes = (item.findtext(f"{SPARKLE}releaseNotesLink") or "").strip()
        enclosure = item.find("enclosure")
        if not sparkle_version.isdigit() or int(sparkle_version) <= 0:
            fail(f"appcast item has invalid sparkle:version {sparkle_version!r}")
        if not SEMVER_RE.match(short_version):
            fail(f"appcast item has invalid sparkle:shortVersionString {short_version!r}")
        if not notes.startswith(f"https://github.com/{REPO}/releases/tag/"):
            fail(f"appcast release notes URL is stale or wrong: {notes!r}")
        if enclosure is None:
            fail("appcast item is missing enclosure")

        url = enclosure.get("url", "")
        length = enclosure.get("length", "")
        signature = enclosure.get(f"{SPARKLE}edSignature", "")
        if not url.startswith(f"https://github.com/{REPO}/releases/download/"):
            fail(f"appcast enclosure URL is stale or wrong: {url!r}")
        if not url.endswith(".zip") or APP_BUNDLE_NAME not in url:
            fail(f"appcast enclosure URL does not point at the expected ZIP artifact: {url!r}")
        if not length.isdigit() or int(length) <= 0:
            fail(f"appcast enclosure length must be a positive byte count, got {length!r}")
        check_signature(signature)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--site-dir", type=Path, default=None)
    parser.add_argument("--appcast", type=Path, default=None)
    parser.add_argument("--check-repo", action="store_true")
    parser.add_argument("--check-version", action="store_true")
    parser.add_argument("--check-appcast", action="store_true")
    parser.add_argument("--require-appcast-item", action="store_true")
    args = parser.parse_args()

    # Default: run repo + version checks (matches Stats Widget convention).
    if not any([args.check_repo, args.check_version, args.check_appcast]):
        args.check_repo = True
        args.check_version = True

    try:
        repo_root = args.repo_root.resolve()
        if args.check_repo:
            check_repo(repo_root)
        if args.check_version:
            check_versions(repo_root)
        if args.check_appcast:
            appcast = args.appcast
            if appcast is None:
                if args.site_dir is None:
                    fail("--appcast or --site-dir is required with --check-appcast")
                appcast = args.site_dir / "appcast.xml"
            check_appcast(appcast.resolve(), args.require_appcast_item)
    except ValidationError as exc:
        print(f"validate_release_metadata.py: {exc}", file=sys.stderr)
        return 1

    print("validate_release_metadata.py: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
