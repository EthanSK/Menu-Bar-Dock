# Changelog

All notable changes to Menu Bar Dock are documented here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Sparkle-driven auto-update kicks in from v4.7.0 onward; older versions need
to be manually re-downloaded.

## [Unreleased]

## [4.7.4] — 2026-05-31

### Fixed

- Apps with no known ordering info are now placed on the least-recent ("end of
  the dock") side instead of stealing the newest-app slot. Previously an
  un-ordered app could land in the spot reserved for the app you just launched,
  and could even evict a genuinely-ordered app when the running-apps limit
  kicked in. (voice 4442)

## [4.7.3] — 2026-05-28

### Changed

- No-op release to verify the Sparkle auto-update flow from v4.7.2.

## [4.7.0] — 2026-05-28

### Added

- Sparkle 2.x auto-update: Menu Bar Dock now checks daily for updates from
  `https://www.menubardock.com/appcast.xml` and offers them in-app. Existing
  installs from pre-4.7 still require a manual re-download to opt in.
- GitHub Actions release pipeline: pushing a `v*` tag (or any commit to
  `master`) triggers a notarized + Sparkle-signed build, a GitHub Release,
  and an appcast update.
- Landing-page download button now reads from the GitHub Releases API so it
  always points at the latest release without manual updates.

### Changed

- Marketing version bumped from `4.6` (2-part) to `4.7.0` (3-part semver) so
  Sparkle's appcast validator accepts it. CFBundleVersion bumped to `27`.

## Previous releases

Tags `4.6` and earlier (`4.5`, `4.4`, `4.3`, `4.2`, `4.1`, `4.0`, `3.3`,
`3.1`, `3.0`) were published manually before the Sparkle pipeline existed.
See [GitHub Releases](https://github.com/EthanSK/Menu-Bar-Dock/releases) for
their notes.
