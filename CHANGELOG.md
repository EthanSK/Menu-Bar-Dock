# Changelog

All notable changes to Menu Bar Dock are documented here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Sparkle-driven auto-update kicks in from v4.7.0 onward; older versions need
to be manually re-downloaded.

## [Unreleased]

## [4.7.8] — 2026-06-24

### Fixed

- Fixed the About window version label so three-part semver versions such as
  `4.7.8` display fully instead of clipping down to `4.7`.

## [4.7.7] — 2026-05-31

### Fixed

- "Check for Updates…" now brings the app to the foreground on the FIRST
  click. Because Menu Bar Dock is a menu-bar accessory (LSUIElement) app it is
  never auto-activated by macOS, so Sparkle's update window used to open behind
  the frontmost app — the first click appeared to do nothing and a second click
  was needed to surface it. We now explicitly activate the app right before
  invoking Sparkle's update check (`NSApp.activate()` on macOS 14+, the legacy
  `activate(ignoringOtherApps:)` on older systems). Fixes the two-click bug
  from both the menu-bar dropdown and the Preferences button.

## [4.7.6] — 2026-05-31

### Added

- Lightweight on-device debug logging to diagnose hard-to-reproduce
  activation / recency-ordering issues. Writes a timestamped trace to
  `~/Library/Logs/Menu Bar Dock/debug.log` capturing every app activation
  (including accessory / LSUIElement apps that are intentionally skipped), the
  `ordering` array before/after each change, the final shown apps with the
  limit + sorting method, and the reason any app is excluded (not-regular /
  hide-finder / hide-active-app). Retention is ~24h with a 4 MB size cap
  (oldest lines trimmed first); all IO is off the main thread and crash-safe.
  On by default; disable with
  `defaults write com.ethansk.MenuBarDock MenuBarDockDebugLogging -bool NO`.

### Notes

- Re-verified the v4.7.5 activation/ordering fix: it is correct for the main
  recency-sort case and the un-ordered-app placement. One residual edge
  remains (accessory / LSUIElement app activations don't update the
  "last active app", so the hide-active-app filter can transiently hide the
  wrong app). The logging above is intentionally shipped first to capture a
  real reproduction before any change to core activation-ingestion logic.

## [4.7.5] — 2026-05-31

### Fixed

- Recency ordering ("most recent" app sort) no longer freezes on macOS 14+
  (Sonoma / Sequoia). The app-activation gate was reading
  `NSWorkspace.shared.frontmostApplication`, which under macOS 14's cooperative
  activation isn't updated synchronously with the activation notification — so
  legitimate foreground activations were silently dropped. We now trust the
  activation notification's payload directly (it's authoritative, no race), and
  use `activationPolicy == .regular` only as a cheap skip rather than as a
  (incorrect) foreground test.
- "Hide active app from running apps" (the default) now compares against the
  last-activated app tracked from the activation notification instead of a live
  `frontmostApplication` read, fixing the same staleness so the correct app is
  hidden on macOS 14+.

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
