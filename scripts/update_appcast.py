#!/usr/bin/env python3
"""Update the Sparkle appcast used by GitHub Pages for Menu Bar Dock.

Reads release metadata from environment variables (set by the GitHub Actions
workflow + prepare_release_metadata.py), validates them defensively, and
upserts a single <item> for this release at the top of the <channel> in
appcast.xml.

The Sparkle client reads this feed daily (per Info.plist
SUScheduledCheckInterval=86400) and offers the newest item whose
sparkle:version is numerically greater than the installed CFBundleVersion.
"""

from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET

# Sparkle's RSS namespace — every <item> needs sparkle:version,
# sparkle:shortVersionString, etc. wrapped in this namespace.
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ATOM_NS = "http://www.w3.org/2005/Atom"
SPARKLE = f"{{{SPARKLE_NS}}}"
# Canonical repo slug — used to assemble release-asset and release-notes URLs.
# Must match what's checked in via prepare_release_metadata.py + the
# index.html download button. Keep these in lockstep when renaming the repo.
REPO_DEFAULT = "EthanSK/Menu-Bar-Dock"
# Primary site URL is the custom CNAME (www.menubardock.com). The
# *.github.io fallback works too — both point at the same gh-pages branch.
SITE_URL = "https://www.menubardock.com/"
APP_NAME = "Menu Bar Dock"
# Tokens that mean "the maintainer forgot to swap in the real signature".
# We hard-fail the appcast build if any of these slip through — better to
# abort the release than to ship a feed that bricks every existing install.
PLACEHOLDER_SIGNATURE_TOKENS = ("PLACEHOLDER", "CHANGEME", "TODO", "TBD", "DUMMY")
# Marketing version regex. Menu Bar Dock historically used 2-part versions
# like "4.6" but Sparkle compares numerically and needs a consistent format,
# so going forward we require 3-part semver (x.y.z). Releases pre-2026-05-28
# still exist as bare-number tags; the appcast only carries new releases.
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
BASE64_RE = re.compile(r"^[A-Za-z0-9+/=]+$")

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("atom", ATOM_NS)


def die(message: str) -> None:
    print(f"update_appcast.py: {message}", file=sys.stderr)
    sys.exit(1)


def require(name: str) -> str:
    """Pull a required env var or hard-fail with a clear message."""
    value = os.environ.get(name, "").strip()
    if not value:
        die(f"missing {name}")
    return value


def validate_release_inputs(
    *,
    version: str,
    display_version: str,
    build_number: str,
    release_tag: str,
    zip_filename: str,
    zip_size: str,
    ed_signature: str,
    repo: str,
    release_notes_url: str,
) -> None:
    """Defensive validation of every input the appcast will reference.

    Catches the common rename / typo / placeholder failure modes before they
    can be committed to gh-pages where they'd brick every installed update
    client.
    """
    if repo != REPO_DEFAULT:
        die(f"REPO must be {REPO_DEFAULT}, got {repo!r}")
    if not SEMVER_RE.match(version):
        die(f"VERSION must be x.y.z, got {version!r}")
    if display_version != version:
        die(f"DISPLAY_VERSION must match VERSION for Sparkle releases, got {display_version!r}")
    if not build_number.isdigit() or int(build_number) <= 0:
        die(f"BUILD_NUMBER must be a positive integer, got {build_number!r}")
    # Accept `v<version>` (canonical) and `v<version>-build.<N>` (CI branch
    # release). Tags WITHOUT the `v` prefix (the old bare-number scheme)
    # are rejected — we're standardizing on `v`-prefixed tags going forward.
    if not release_tag.startswith(f"v{version}"):
        die(f"RELEASE_TAG {release_tag!r} must start with v{version}")
    if "/" in zip_filename or not zip_filename.endswith(".zip"):
        die(f"ZIP_FILENAME must be a release ZIP basename, got {zip_filename!r}")
    # We standardize on "Menu-Bar-Dock-<tag>.zip" (URL-safe hyphens). The
    # legacy asset name was "Menu.Bar.Dock.app.zip"; new releases use the
    # hyphenated prefix to dodge URL-encoding issues in the Sparkle
    # enclosure URL. validate_release_metadata.py also enforces this.
    if "Menu-Bar-Dock" not in zip_filename:
        die(f"ZIP_FILENAME must use the Menu-Bar-Dock prefix, got {zip_filename!r}")
    if not zip_size.isdigit() or int(zip_size) <= 0:
        die(f"ZIP_SIZE must be a positive byte count, got {zip_size!r}")
    upper_signature = ed_signature.upper()
    if any(token in upper_signature for token in PLACEHOLDER_SIGNATURE_TOKENS):
        die("ED_SIGNATURE must be a real Sparkle Ed25519 signature, not a placeholder")
    if len(ed_signature) < 40 or not BASE64_RE.match(ed_signature):
        die("ED_SIGNATURE does not look like Sparkle sign_update base64 output")
    expected_notes_prefix = f"https://github.com/{repo}/releases/tag/"
    if not release_notes_url.startswith(expected_notes_prefix):
        die(f"RELEASE_NOTES_URL must start with {expected_notes_prefix}")


def load_or_create(path: Path) -> tuple[ET.ElementTree, ET.Element]:
    """Parse the existing appcast or create a fresh <rss> + <channel> shell."""
    if path.exists():
        tree = ET.parse(path)
        channel = tree.getroot().find("channel")
        if channel is None:
            die(f"{path} is missing <channel>")
        normalize_channel(channel)
        return tree, channel

    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    normalize_channel(channel)
    return ET.ElementTree(rss), channel


def set_or_create_text(channel: ET.Element, tag: str, value: str) -> None:
    node = channel.find(tag)
    if node is None:
        node = ET.SubElement(channel, tag)
    node.text = value


def normalize_channel(channel: ET.Element) -> None:
    """Ensure the channel header is correct + matches expected URLs.

    Run on EVERY appcast write so any drift from a hand-edit gets corrected
    automatically.
    """
    set_or_create_text(channel, "title", f"{APP_NAME} Updates")
    set_or_create_text(channel, "link", SITE_URL)
    set_or_create_text(channel, "description", f"Automatic update feed for {APP_NAME}.")
    set_or_create_text(channel, "language", "en")

    # The atom:link rel=self lets RSS clients discover the feed's canonical
    # URL. Sparkle doesn't strictly require it but it makes the feed valid
    # against the RSS 2.0 best-practices spec.
    atom_link = channel.find(f"{{{ATOM_NS}}}link")
    if atom_link is None:
        atom_link = ET.SubElement(channel, f"{{{ATOM_NS}}}link")
    atom_link.set("href", f"{SITE_URL}appcast.xml")
    atom_link.set("rel", "self")
    atom_link.set("type", "application/rss+xml")


def build_item() -> ET.Element:
    """Build the <item> for THIS release from environment variables."""
    version = require("VERSION")
    display_version = require("DISPLAY_VERSION")
    build_number = require("BUILD_NUMBER")
    release_tag = require("RELEASE_TAG")
    zip_filename = require("ZIP_FILENAME")
    zip_size = require("ZIP_SIZE")
    ed_signature = require("ED_SIGNATURE")
    repo = os.environ.get("REPO", REPO_DEFAULT).strip() or REPO_DEFAULT
    # Match the deployment target in the .xcodeproj — Sparkle won't offer
    # the update to clients on older macOS than this.
    min_macos = os.environ.get("MIN_MACOS", "10.15")
    release_notes_url = os.environ.get(
        "RELEASE_NOTES_URL",
        f"https://github.com/{repo}/releases/tag/{release_tag}",
    )
    pub_date = os.environ.get("PUB_DATE") or datetime.now(timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S +0000"
    )

    validate_release_inputs(
        version=version,
        display_version=display_version,
        build_number=build_number,
        release_tag=release_tag,
        zip_filename=zip_filename,
        zip_size=zip_size,
        ed_signature=ed_signature,
        repo=repo,
        release_notes_url=release_notes_url,
    )

    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"{APP_NAME} v{display_version}"
    ET.SubElement(item, "pubDate").text = pub_date
    # sparkle:version is the BUILD number (monotonically increasing integer).
    # Sparkle uses this for the "is X newer than Y" comparison — the
    # marketing version is only for display.
    ET.SubElement(item, f"{SPARKLE}version").text = build_number
    ET.SubElement(item, f"{SPARKLE}shortVersionString").text = version
    ET.SubElement(item, f"{SPARKLE}minimumSystemVersion").text = min_macos
    ET.SubElement(item, f"{SPARKLE}releaseNotesLink").text = release_notes_url

    # The enclosure is the actual download. The length attribute MUST equal
    # the real ZIP byte count or Sparkle aborts with a hash-mismatch-style
    # error post-download.
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set(
        "url",
        f"https://github.com/{repo}/releases/download/{release_tag}/{zip_filename}",
    )
    enclosure.set("length", zip_size)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{SPARKLE}version", build_number)
    enclosure.set(f"{SPARKLE}shortVersionString", version)
    enclosure.set(f"{SPARKLE}edSignature", ed_signature)
    return item


def upsert_item(channel: ET.Element, item: ET.Element, version: str) -> None:
    """Replace any existing item for this same marketing version, else prepend.

    Keeping older items in the feed is fine — Sparkle just picks the newest.
    But we never want two items for the same marketing version.
    """
    for existing in channel.findall("item"):
        short = existing.find(f"{SPARKLE}shortVersionString")
        if short is not None and (short.text or "").strip() == version:
            index = list(channel).index(existing)
            channel.remove(existing)
            channel.insert(index, item)
            return

    # Insert before the first existing <item> so newest is on top.
    for index, child in enumerate(list(channel)):
        if child.tag == "item":
            channel.insert(index, item)
            return
    channel.append(item)


def main() -> int:
    appcast_path = Path(os.environ.get("APPCAST_PATH", "appcast.xml"))
    appcast_path.parent.mkdir(parents=True, exist_ok=True)
    tree, channel = load_or_create(appcast_path)
    item = build_item()
    upsert_item(channel, item, require("VERSION"))
    ET.indent(tree, space="  ")
    tree.write(appcast_path, xml_declaration=True, encoding="utf-8")
    print(f"wrote {appcast_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
