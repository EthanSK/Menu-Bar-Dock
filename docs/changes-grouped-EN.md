# Menu Bar Dock Grouped — change summary

Prepared on 17 October 2026. This document describes the final local customization, version **4.8.0-grouped.13**, build **41**, relative to upstream Menu Bar Dock **4.8.0**, commit [`027f62230f3a5758770f1beab72e1d3ea17c8302`](https://github.com/EthanSK/Menu-Bar-Dock/commit/027f62230f3a5758770f1beab72e1d3ea17c8302).

The upstream `master` branch was checked on this date and still pointed to that commit. The implementation is offered as one complete personal customization snapshot on `feature/grouped-dock-folders`. The maintainer is welcome to select, adapt or leave out any part; this draft proposal does not assume that the whole snapshot should be merged.

## 1. One dock group in the menu bar

- Replaced independent status items with one persistent `NSStatusItem` containing native buttons for the dock entries. Other applications' status icons cannot appear between those buttons.
- Added a shared rounded background, with an independent **Show group background** preference.
- Added a configurable gap to the right of the group: **Group right margin**, 0–160 pt, default 48 pt. A context-menu submenu also provides preset values.
- Command-drag moves the whole group. A stable autosave identity preserves its system-managed position across ordinary updates.
- Added a screen-width budget and an overflow menu for entries that do not fit. An empty group retains a Preferences/options button.
- Reused native buttons to preserve click targets and accessibility labels. Command-drag events pass through to the enclosing status button.
- Replaced the stretched pressed-state highlight with a circle centered on the artwork. The circle is independent of button width and the group's trailing gap.

The current customization always uses grouped mode. An option to retain the original independent-item mode has **not** been implemented.

## 2. Folder shortcuts

- Renamed the pinned section to **Apps & Folders** and allowed the add dialog to select applications and ordinary directories.
- Clicking a pinned folder opens that directory in Finder. Folder menus provide folder-appropriate actions and omit Quit, Hide and Activate controls.
- Folder pins share ordering, removal, URL persistence and custom-icon lookup with application pins. They never inherit Finder's running indicator or instance number.
- Validated directory URLs and distinguished ordinary folders from application bundles and other packages. Unavailable folders can recover after cache invalidation, including volume changes.
- Preserved folder display names, including names containing spaces, Unicode characters and dots. An unavailable folder produces a user-visible error when opened.

## 3. Running indicators and artwork layout

- Added a small running-state dot immediately to the left of each running application icon. Stopped apps and folder shortcuts have no dot.
- Scaled the dot diameter and gap with icon size. Reserved the same indicator space for stopped entries so starting an app does not shift the artwork.
- Automatically widened buttons when necessary to prevent the icon from overlapping the indicator. **Minimum Item Width** remains the user's requested minimum.
- Allowed configured artwork sizes from 12–100 pt while retaining the upstream 40 pt default. Corrected flipped-coordinate drawing in the custom button and kept instance badges inside the visible slot for oversized icons.
- Added a one-time repair for icon sizes reduced by an early grouped prototype, while preserving subsequent user changes.

**Existing upstream features:** per-app icon overrides and numbered instance badges were already introduced in upstream 4.8.0. This work preserves and adapts them; it does not introduce them as new features. Instance grouping now distinguishes separate application installations by URL, and recency ordering distinguishes processes by PID.

## 4. Hover animation and stable menus

- Added an optional, approximately **1.5 mm** downward hover movement over **0.18 seconds**, with a return movement on pointer exit.
- Used entered/exited tracking events and Core Animation. There is no continuous cursor timer, mouse-move callback or global input monitor.
- Kept native click geometry stationary while a reusable, transparent, nonactivating visual panel moves the icon, indicator and instance badge together.
- Rendered complete artwork at the backing scale rather than caching only the short button rectangle. This removes the top/bottom crop introduced by the earlier hover implementation.
- Added **Animate icons on hover**, saved independently of the background preference. Disabling it cancels an active hover immediately. System **Reduce Motion** takes priority.
- Anchored context menus below the stationary button in screen coordinates. Deferred group rendering until menu tracking ends, including nested tracking.
- Consumed the matching right-mouse-up event after opening a menu on right-mouse-down, preventing a second menu from the parent status button.
- Cancelled hover for clicks, menu tracking and button removal. Animation generation identities prevent stale completion callbacks from dismissing a newer hover.

The millimeter distance depends on display metadata and is approximate. Physical display edges still limit visible drawing.

## 5. Preferences, restart and startup

- Added the two appearance checkboxes and a separate **Restart App** button below the existing Preferences layout.
- Applied appearance changes immediately, saved them independently and restored their defaults without removing pinned folders.
- Saved settings before restart, then used a bounded helper to wait for the old PID to exit before launching the same application bundle. This avoids the single-instance guard forwarding the new launch back to the old process.
- Passed bundle paths as quoted positional arguments. Repeated restart requests are ignored after a successful helper start; a helper-start error leaves the app alive and permits retry.
- Reused the Preferences window, refreshed its content on reopening and synchronized the margin slider after context-menu changes.
- Reopening the accessory application exposes Preferences. A duplicate grouped process forwards to the oldest instance and exits without overwriting settings with unloaded defaults.
- Explicitly restored status-item visibility and filtered legacy per-item visibility keys to fix missing icons in early grouped builds.
- Updated in-app help for grouping, folder pins, overflow and the running indicator.

Startup visibility, custom-button orientation, hover cropping and context-menu jumping include fixes for regressions in the grouped prototype; they should not all be described as defects in the original application.

## 6. Reliability fixes

- Made notification observers weak and removed their tokens during deinitialization.
- Recorded accessory-app activations so hiding the active app does not leave the previous regular application incorrectly hidden.
- Tracked recency per process, preserved a selected live pinned-app instance and kept sibling instances independent when one exits.
- Made consistent sorting use display names and made a zero running-app limit remain zero. Bounded malformed or negative limits before array operations.
- Validated non-finite geometry, numeric preference ranges and pinned file URLs; filtered duplicate URLs.
- Accepted keyboard and accessibility slider actions, as well as mouse actions.
- Used a private table pasteboard type, validated drag sources/indexes and preserved selected-row order during bulk moves.
- Displayed application-launch errors after user actions, and fell back to launching when an old running-process handle had terminated.
- Made diagnostic timestamp formatting serial and prevented log-trimming arithmetic from underflowing.

## 7. Less repeated work

- Reused visible entry controllers and their native buttons. Removed obsolete cache entries; created overflow controllers only when needed for menu tracking.
- Cached pinned models, file metadata and standard artwork across ordinary application events. Invalidated them when pins change, Preferences opens or mounted volumes change.
- Cached decoded custom icons with `NSCache`, bounded to 64 entries and an 8 MiB cost budget, with invalidation and malformed-image fallback.
- Coalesced event bursts into one main-queue refresh and passed a single running-process snapshot to all models.
- Updated appearance without process queries or rebuilding application models.
- Skipped unchanged preference writes, including unchanged icon data.
- Made disabled diagnostic messages lazy. The local build defaults logging off; the upstream build retains its logging default.
- Precomputed ordering positions instead of searching the preferred-order array for each sorting comparison.

Raw historical measurements are included in [`benchmarks/performance-before.csv`](benchmarks/performance-before.csv) and [`benchmarks/performance-after.csv`](benchmarks/performance-after.csv).

Historical warm-cache microbenchmarks compared **grouped.4 with grouped.5**, not the stock upstream application. Values below are total milliseconds for the listed number of operations, using the median of three runs on the same Mac.

| Operation | Iterations | grouped.4 | grouped.5 |
| --- | ---: | ---: | ---: |
| Refresh 12 pinned folders | 300 | 230.955 ms | 7.841 ms |
| Refresh a 12-entry dock | 1,000 | 1,153.829 ms | 39.703 ms |
| Repeated custom PNG lookup | 1,000 | 57.398 ms | 0.168 ms |

These measurements describe individual operations. They do not establish whole-application CPU reductions, battery savings or the energy cost of the later hover animation.

## 8. Optional artwork

- Replaced the app icon with the user-confirmed attached design: a graphite anchor with pointed flukes and shallow relief on a pale gray tile. External canvas padding is cropped so the tile fills the asset.
- Supplied all ten macOS 1x/2x asset slots from 16 to 1024 px, including the previously missing 1024 px slot.
- Preserved the original reference, selected generated source and prompts. The alternative icon was generated with the built-in image generation tool and resized for the asset catalog.
- Added ICNS packaging and used an explicit icon file for local builds, avoiding the old icon name in reused compiled assets. Packaged an opaque RGB backing to prevent automatic macOS glass treatment from adding ring highlights and lowering anchor contrast; retained the approved transparent PNG separately. ICNS payloads now contain the source PNGs verbatim.

The artwork is a separate branding proposal and can be excluded from upstream contributions.

## 9. Local build and verification tools

- Added local build, icon preparation/packaging, native behavioral checks and benchmark tools. `scripts/check-app-icon.swift` additionally compares the actual system icon with the approved PNG and rejects the bright ring artifacts seen in the earlier packaging.
- Built a separate arm64 application targeting macOS 11 or later, with bundle ID `local.menubardock.grouped`, its own preference domain and an ad-hoc signature.
- Added a one-time selective preference import from the original app. The local profile does not import upstream updater state or per-item visibility and leaves Launch at Login off initially.
- Disabled upstream automatic updates in the local build so they cannot replace the customization. Kept Sparkle integration available in the normal upstream build configuration.
- Used the local app's own main-app login service on macOS 13+. Disabled its login checkbox on older supported local systems.
- Allowed local build/check scripts to use compiled UI resources from either upstream 4.8.0 or an earlier grouped build when Xcode is unavailable.

These local bundle, update, migration, version and resource-copying decisions are not proposed as defaults for the official application.

## Verification and remaining work

- **143 native behavioral checks passed for grouped.9.** The runtime Swift sources in grouped.13 are byte-identical; the icon-only revisions did not rerun those checks.
- Checks cover models, preferences, observer lifetime, caches, event coalescing, folder handling, table actions, offscreen rendering, menu/hover geometry, accessibility actions and restart-helper behavior.
- Final grouped.13 verification covered optimized arm64 compilation, strict ad-hoc signature validation, all icon dimensions, native ICNS decoding, system icon resolution and archive integrity.
- The restart helper was tested with a disposable old process and a fake opener. This is not a claim of complete real-application restart testing.
- Full Xcode/XCTest/UI targets, Intel/universal builds and runtime compatibility with the upstream macOS 10.15 target remain to be checked. The local test harness uses a logged-in macOS session and compiled storyboard resources.
- Real menu interaction, folder clicks, position restoration, multiple displays/notches and long-term animation energy use still require additional manual verification.
- The group is not guaranteed to remain left of new system status icons. A proposed automatic/manual reinsertion shortcut failed its positioning test and was removed. Restart does not override macOS ordering; Command-drag remains available.

This is a documented local prototype with useful test evidence, not an already merge-ready replacement for the official release.
