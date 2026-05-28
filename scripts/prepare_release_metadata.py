#!/usr/bin/env python3
"""Prepare version/build metadata for signed GitHub releases of Menu Bar Dock.

The Xcode project (Menu Bar Dock.xcodeproj) is the single source of truth
for both MARKETING_VERSION (e.g. "4.7.0") and CURRENT_PROJECT_VERSION (the
Sparkle build number — a monotonic integer). This script reads those values
via Apple's `agvtool` and computes the release tag, ZIP filename, and other
metadata the workflow needs.

Behavior:
  - tag push  (refs/tags/vX.Y.Z)        → release tag = vX.Y.Z
  - tag push  (vX.Y.Z-build.N)          → release tag = vX.Y.Z-build.N
  - branch push (push to main/master)   → release tag = vX.Y.Z if the
    canonical tag doesn't exist yet, otherwise vX.Y.Z-build.<run_number>
    (matches Producer Player's branch-release scheme).

Mirrors macos-widgets-stats-from-website/scripts/prepare_release_metadata.py
(voice 7174, 2026-05-28). Differences from that script:
  - Reads MARKETING_VERSION + CURRENT_PROJECT_VERSION from .xcodeproj via
    agvtool instead of project.yml (no XcodeGen on this project).
  - --apply-plists is a no-op (the .pbxproj already injects both via
    $(MARKETING_VERSION) / $(CURRENT_PROJECT_VERSION) placeholders, and we
    update via agvtool in bump-version.sh, not here).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# subprocess is used for git_tag_exists below.

ROOT = Path(__file__).resolve().parents[1]
# Hyphenated prefix — see update_appcast.py for the URL-safe-vs-spaces
# rationale. Same prefix is enforced by validate_release_metadata.py.
ASSET_PREFIX = "Menu-Bar-Dock"
REPO = "EthanSK/Menu-Bar-Dock"
DISPLAY_NAME = "Menu Bar Dock"
# Path to the .xcodeproj used by agvtool. agvtool requires a `cd` to the
# directory CONTAINING the .xcodeproj.
XCODEPROJ_NAME = "Menu Bar Dock.xcodeproj"
TAG_RE = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)(?:-build\.(?P<build>\d+))?$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"prepare_release_metadata.py: {message}", file=sys.stderr)
    sys.exit(1)


def read_marketing_and_build() -> tuple[str, str]:
    """Return (marketing_version, build_number) from the Xcode project.

    We deliberately do NOT use `agvtool` for the marketing version because
    this project's Info.plist uses the literal `$(MARKETING_VERSION)`
    placeholder (the build setting is the source of truth). agvtool would
    report the placeholder string back, not the substituted value. Parse the
    pbxproj directly instead.

    Xcode keeps MARKETING_VERSION + CURRENT_PROJECT_VERSION in lockstep
    across the Debug + Release build configs in this project, so the FIRST
    match is canonical. scripts/bump-version.sh updates ALL matches in one
    pass via sed.
    """
    pbxproj = ROOT / XCODEPROJ_NAME / "project.pbxproj"
    text = pbxproj.read_text(encoding="utf-8")
    mv = re.search(r"MARKETING_VERSION\s*=\s*([^;]+);", text)
    bv = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", text)
    if not mv:
        fail("project.pbxproj is missing MARKETING_VERSION")
    if not bv:
        fail("project.pbxproj is missing CURRENT_PROJECT_VERSION")
    return mv.group(1).strip(), bv.group(1).strip()


def git_tag_exists(tag: str) -> bool:
    """Return True iff the given tag already exists locally.

    Used to decide between canonical (v<version>) vs build-suffix
    (v<version>-build.<run>) tags on branch-push runs.
    """
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def release_values_for_ref(version: str, base_build: int) -> dict[str, str]:
    """Compute every RELEASE_* env var the workflow needs."""
    ref_type = os.environ.get("GITHUB_REF_TYPE", "branch")
    ref_name = os.environ.get("GITHUB_REF_NAME", "local")
    run_number_raw = os.environ.get("GITHUB_RUN_NUMBER", "0")
    sha = os.environ.get("GITHUB_SHA", "local")

    if not run_number_raw.isdigit():
        fail(f"GITHUB_RUN_NUMBER must be numeric, got {run_number_raw!r}")
    run_number = int(run_number_raw)

    canonical_tag = f"v{version}"
    release_tag = canonical_tag
    build_number = base_build
    release_title = f"{DISPLAY_NAME} v{version}"
    # `release_channel` is consumed by the workflow's `if:` gates so we can
    # publish a GitHub Release for every build (useful as testing artifacts)
    # while only updating the appcast on canonical tag-driven releases.
    release_channel = "branch"

    if ref_type == "tag":
        match = TAG_RE.match(ref_name)
        if not match:
            fail(
                f"tag {ref_name!r} is not supported; use v{version} or "
                f"v{version}-build.<number>"
            )
        if match.group("version") != version:
            fail(f"tag {ref_name!r} does not match MARKETING_VERSION {version!r}")
        release_tag = ref_name
        # Canonical vs build-suffix distinction. Canonical tag = users get
        # the appcast update; build-suffix = artifact-only.
        release_channel = "tag-build" if match.group("build") else "tag"
        if match.group("build"):
            release_title = f"{DISPLAY_NAME} v{version} (build {match.group('build')})"
    else:
        # Branch-push run. If the canonical tag already exists at some
        # earlier commit, this branch run is a "rolling build" and should
        # get a -build.<run> suffix so the GitHub Release tag stays unique.
        # If the canonical tag does NOT exist, this run can claim it.
        if git_tag_exists(canonical_tag):
            release_tag = f"{canonical_tag}-build.{run_number}"
            release_title = f"{DISPLAY_NAME} v{version} (build {run_number})"

    zip_filename = f"{ASSET_PREFIX}-{release_tag}.zip"
    latest_zip_filename = f"{ASSET_PREFIX}-latest.zip"
    release_notes_url = f"https://github.com/{REPO}/releases/tag/{release_tag}"

    return {
        "RELEASE_VERSION": version,
        "RELEASE_DISPLAY_VERSION": version,
        "RELEASE_BASE_BUILD_NUMBER": str(base_build),
        "RELEASE_BUILD_NUMBER": str(build_number),
        "RELEASE_TAG": release_tag,
        "RELEASE_TITLE": release_title,
        "RELEASE_CHANNEL": release_channel,
        "RELEASE_COMMIT_SHA": sha,
        "RELEASE_REPO": REPO,
        "RELEASE_NOTES_URL": release_notes_url,
        "ASSET_ZIP_FILENAME": zip_filename,
        "LATEST_ZIP_FILENAME": latest_zip_filename,
        "LATEST_ZIP_URL": f"https://github.com/{REPO}/releases/latest/download/{latest_zip_filename}",
        "VERSIONED_ZIP_URL": f"https://github.com/{REPO}/releases/download/{release_tag}/{zip_filename}",
    }


def write_key_values(path: str | None, values: dict[str, str]) -> None:
    """Append key=value pairs to a GitHub Actions env/output file.

    GITHUB_ENV / GITHUB_OUTPUT use the same key=value-on-newline format;
    multiline values would need heredoc syntax, so we hard-fail if any value
    contains a newline (the metadata we generate never legitimately does).
    """
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        for key, value in values.items():
            if "\n" in value:
                fail(f"refusing to write multiline value for {key}")
            handle.write(f"{key}={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # Kept for parity with the Stats Widget script; this project's pbxproj
    # already uses $(MARKETING_VERSION) / $(CURRENT_PROJECT_VERSION)
    # placeholders, so plist patching at release time is a no-op.
    parser.add_argument("--apply-plists", action="store_true", help="no-op on this project")
    parser.add_argument("--github-env", default=os.environ.get("GITHUB_ENV"), help="append release env vars to this file")
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"), help="append release outputs to this file")
    args = parser.parse_args()

    version, base_build_raw = read_marketing_and_build()

    if not SEMVER_RE.match(version):
        fail(
            f"MARKETING_VERSION must be x.y.z (semver), got {version!r}. "
            "Run scripts/bump-version.sh to bump cleanly."
        )
    if not base_build_raw.isdigit():
        fail(f"CURRENT_PROJECT_VERSION must be numeric, got {base_build_raw!r}")

    base_build = int(base_build_raw)
    values = release_values_for_ref(version, base_build)

    write_key_values(args.github_env, values)
    write_key_values(args.github_output, values)

    for key in sorted(values):
        print(f"{key}={values[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
