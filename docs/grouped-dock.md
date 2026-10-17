# Grouped dock and folders

Based on EthanSK/Menu-Bar-Dock commit `027f622` (4.8.0).

## Behavior

- All dock entries live inside one persistent `NSStatusItem`, with a shared rounded background. System status icons cannot be inserted between the app buttons.
- The group has a right-hand gap, initially 48 pt. **Preferences → General → Group right margin** provides a 0–160 pt slider. Right-click any entry → **Space to the right of the group** also offers 0 / 24 / 48 / 96 / 160 pt. Hold Command and drag the group to move it farther toward the center. The `GroupedDock` autosave name preserves the system-managed position. This is not absolute screen centering: macOS controls status-item placement, available space and the notch.
- The pressed/menu-open state is a circle centered on the icon, independent of slot width. The system-wide status-button highlight is disabled, so the right-hand spacer cannot become a stretched oval.
- A small dot to the left of the icon identifies a running application. Its diameter scales from 1.5 to 5 pt and its gap from 0.75 to 2 pt with artwork size. Each slot reserves this space even when the dot is absent, and automatically widens for large artwork to prevent overlap. Folder shortcuts and stopped apps have no dot. Instance-number badges are retained. Artwork uses the original configured scale (12–100 pt, default 40 pt), with menu-bar clipping for oversized images. Image drawing respects the native button's flipped coordinates. On upgrade, an icon size reduced by grouped.1–.3's 20 pt cap is restored once from the upstream preference; subsequent local edits are preserved.
- **Apps & Folders → +** accepts app bundles and ordinary folders. Clicking a folder opens it in Finder. Its context menu offers opening and revealing, without app-specific Quit/Hide/Activate controls. Folders share ordering, removal, icon overrides and URL persistence with pinned apps.
- The group keeps an options button when empty. A conservative screen-width budget moves excess entries into the `…` menu. Large gaps may reduce the number of visible icons. The app cannot measure the width of every other app's status items; an unusually crowded menu may still require reducing the gap or pinned/running item count.

## Build with Xcode

Use the existing CocoaPods/Xcode workspace workflow (`pod install`, then open `Menu Bar Dock.xcworkspace`). The new code uses existing source-file entries; no project-file additions are needed. The upstream deployment target and Sparkle integration remain available in this build mode. A normal upstream build can still receive upstream updates; use the separate local build below for personal customization.

## Separate local build, without Xcode

Requires Apple Silicon, Swift Command Line Tools, and the original installed **Menu Bar Dock 4.8.0** for its compiled storyboard and assets:

```sh
./scripts/build-local.sh "/Applications/Menu Bar Dock.app" "$PWD/build/Menu Bar Dock Grouped.app"
```

The output path must not already exist. The script compiles all current Swift sources with `LOCAL_BUILD`, copies only the original compiled UI resources, and applies an ad-hoc signature. It does not reuse the upstream executable or Sparkle framework. This is a local, non-notarized build, targeting macOS 11 or later on arm64.

The bundle ID is `local.menubardock.grouped`. On first launch it copies only the original app preferences into its own domain and leaves Launch at Login off. AppKit status-item visibility and updater state are excluded. Subsequent settings are independent of the original. Upstream auto-updates are disabled to avoid replacing the customization. On macOS 13 or later, Launch at Login uses the local app's own `SMAppService.mainApp`; move the app to a stable location before enabling it.

grouped.3 repairs legacy status-item keys previously imported by grouped.1/.2, preserving current pins and the named group position. AppKit can initialize the first status item as hidden before its autosave name is assigned; the group explicitly sets `isVisible = true` after assigning its name. A duplicate process forwards to the oldest running instance and exits without saving unloaded preferences.

Quit the original Menu Bar Dock before using the grouped build to avoid two docks appearing simultaneously. Closing this local app and reopening the original returns to the previous version and its settings.

## Validation

```sh
./scripts/check-grouped.sh
```

Run from a normal logged-in macOS desktop session. The checks use AppKit and inspect the running Finder process; a process-isolated sandbox is not representative and fails that integration assertion.

Verified in this workspace:

- Native Swift compilation and application startup.
- grouped.2: rebuilt after replacing the click highlight with a circle and disabling the parent highlight. The actual DockItemButton drawing was rendered with 30 pt and 64 pt slots in Aqua and Dark Aqua; both pressed states remained circular.
- grouped.3: a separate native probe reproduced startup with `NSStatusItem VisibleCC Item-0 = false`; assigning the autosave name did not restore visibility, while explicitly setting `isVisible` did. The user confirmed that icons appeared after launching the fixed build.
- 143 runtime assertions, including folder/application discrimination, Unicode and dotted folder names, preference round-trip, running versus stopped state, menu actions, empty dock, overflow actions, a stable single status-item identity, hidden legacy startup, migration filtering and preservation of edited pins and the group position. grouped.4 also covers icon-size restoration, orientation against native NSImageView, top-dot pixels, absence of side bars, and the margin slider's value and layout in the compiled Preferences storyboard. These renders use our own offscreen views, without capturing the user's desktop.
- 45 layout combinations across item counts, spacing and screen budgets.
- Native Preferences window loaded from the original 4.8.0 resources; existing pinned apps and icon controls appeared. The native + dialog showed applications and directories. Adding the Utilities folder created a pinned row; removing that row restored the list. The final build passed strict ad-hoc signature verification.

Not yet manually verified end-to-end: clicking a pinned folder from the actual menu bar, Command-dragging the group, light/dark appearance on every display, position restoration after a user drag, and launching duplicate copies. Full Xcode/XCTest targets were not run because Xcode is not installed.

## grouped.5 review and performance

- Block observers are weak and removed on deinitialization. Accessory activations also update active-app state. Mount/unmount/volume rename invalidates the pinned cache.
- Recency ordering uses process identity, keeping sibling instances independent. Consistent ordering sorts display names. A zero running limit remains zero; malformed limits and non-finite geometry are repaired at load.
- Pins and their artwork are reused across ordinary app events. Decoded overrides use NSCache with a count/cost budget and are invalidated when changed. Button caches retain only visible entries and distinguish deliberate duplicates. Overflow menu controllers are built on demand and held alive during tracking.
- The delegate coalesces event bursts and supplies one process snapshot to all models. Appearance sliders update geometry without process queries or rebuilding models. Preferences writes skip unchanged keys, including PNG data.
- Local diagnostic logging defaults off, with lazy message construction. Explicit opt-in remains available. Formatting and parsing use the serial logging queue.
- Native keyboard/accessibility slider actions work. Private pasteboard data plus validated indexes prevent external text from triggering a bad move. Bulk moves preserve selected-row order.
- Preferences windows are reused and refreshed, and context-menu margin changes synchronize the existing slider. Large-icon instance badges remain inside the slot. App launch failures are shown instead of discarded; terminated handles fall back to launch.
- Added scripts/benchmark-grouped.sh. Warm-cache benchmarks use 12 pinned folders, 12 displayed items, and a 256 px PNG override, taking the median of three runs. These measure individual operations, not whole-app CPU, energy or battery savings. See audit-RU.md in the deliverables for measured results and limitations.

## grouped.6 indicator layout

The icon and left dot use shared DockItemLayout geometry. Slot width is at least the icon width plus the dot, the small gap, and edge padding; Minimum Item Width remains the user's requested minimum. Large icons may move more entries into overflow. The circular highlight remains centered on the artwork. Running/stopped transitions do not alter artwork alignment. New checks cover 36 icon/slot/height combinations, 810 screen-budget combinations, native left-dot pixels and real menu button widths.

## grouped.7 menus and hover animation

Context menus capture a screen-coordinate anchor 1 pt below the stationary status button. The dock defers rendering while menu tracking is active, including nested tracking, and applies only the latest pending content after closing. Right mouse-up is consumed by the child button after right mouse-down opens its menu, preventing a second parent menu. Hover is cancelled for clicks and suspended while a menu is open.

A single reusable nonactivating, transparent NSPanel displays a Retina snapshot of the button artwork. It ignores mouse events and cannot become key/main, so the native button keeps its original click and drag geometry. The panel covers both animation endpoints and permits positioning across the menu-bar band; whole-pixel envelope padding avoids fractional-coordinate clipping. The source artwork is hidden only while its visual copy is displayed, then restored. Image and weak ownership are cleared on cancellation/removal.

NSTrackingArea requests only entered/exited events, active even for an inactive menu-bar app. A 0.18 s Core Animation translation moves the sprite down and back. No polling timer, mouse-moved callback, or global event monitor is installed. Reduce Motion suppresses movement. Cancelled animation callbacks carry generation identities so they cannot dismiss a newer hover.

The displacement aims at 1.5 mm (reduced in grouped.8) using screen point height divided by display millimeter height, with rotation adjustment and a safe approximately 4.25 pt fallback when metadata is unusable. Display physical dimensions can be estimated by macOS, so millimeter accuracy depends on its data.

Primary API references: [NSMenu popup coordinates](https://developer.apple.com/documentation/appkit/nsmenu/popup(positioning:at:in:)), [display size in millimeters](https://developer.apple.com/documentation/coregraphics/cgdisplayscreensize(_:)), [tracking areas](https://developer.apple.com/documentation/appkit/nstrackingarea).

New checks cover snapshot orientation, enter/exit-only tracking, native hit testing, menu anchor stability, both motion endpoints, geometry at the real menu-bar band, cancellation, Reduce Motion, weak-owner release, physical-unit conversion, deferred group updates and right-click event routing. Test windows remain invisible. Actual desktop motion smoothness, panel ordering with other menu utilities and context-menu interaction require manual user QA; energy consumption of the added hover effect has not been measured.

## grouped.8 full artwork during hover

The old snapshot cached only the button bounds. With an icon taller than the menu-bar button, switching to that snapshot cut off its top and bottom before translation began. The hover bitmap now renders the same artwork directly into the union of the button, icon and indicator bounds at the window backing scale. Its placement uses that expanded rectangle in screen coordinates, and the overlay covers the complete artwork at both endpoints. Native hit targets and menu anchors stay fixed. Appearance, flipped coordinates, running dot and instance badge use the existing drawing routine.

Twenty additional assertions cover full-size top and bottom pixels, orientation and both overlay endpoints for 12, 25.4, 40, 64 and 100 pt artwork in 22 and 30 pt buttons. All own test windows remained invisible. Physical screen edges still limit what can be displayed; there is no additional crop from the hover bitmap or panel. Displacement is now approximately 1.5 mm, retaining the 0.18 s event-driven animation and Reduce Motion behavior.

## grouped.9 appearance preferences and restart

Preferences adds two independent persisted booleans, hoverAnimationsEnabled and groupBackgroundEnabled, both defaulting to true for existing installations. Turning hover off cancels any active overlay immediately and restores the source button. The group background is hidden without changing status-item identity, spacing, click targets or the circular pressed highlight. Both changes save preferences and refresh appearance without querying running processes. Reduce Motion remains an overriding system preference.

A 64 pt extension below the original compiled Preferences layout contains native checkboxes and a Restart App button. Offscreen geometry checks cover containment, intrinsic widths, ambiguity, non-overlap and action routing. The original controls and visible margin slider remain intact. Reset restores the two booleans while preserving pinned folders.

Restart saves settings before starting a shell helper. The application path, PID and opener path are positional arguments, never interpolated into shell source. The helper waits for the old PID to disappear (bounded at about ten seconds) before executing /usr/bin/open -n with the exact app bundle path. This avoids forwarding the new launch back to the terminating instance. Repeated clicks are ignored after a successful helper start; a helper-start failure reports an error and leaves the application running with retry available. A real disposable sleep process plus a fake opener exercise the waiting and quoting behavior, including spaces, quotes and shell metacharacters, without restarting the user's application.

Separate system status icons are ordered by macOS. A temporary implementation tried fresh autosave identities to reinsert the group at the left edge. A native test comparing only our own temporary item coordinates showed the group could retain its previous position, so the unverified Move Group Left action was removed. The shipped Restart App button does not claim to force ordering. Users can ⌘-drag the group; automatic reordering and private positioning APIs are not used.

Local scripts accept storyboard/assets from the original 4.8.0 or an earlier grouped build, allowing rebuilding after the original /Applications copy is removed. Runtime checks use MBD_RESOURCE_APP when supplied, otherwise the installed original or the neighboring outputs build. No screen viewing was performed. Actual full-app restart and desktop interaction remain for user QA.

## grouped.10 application icon

The violet/turquoise anchor identity is retained with a lighter mint anchor, rounded geometry and an indigo tile. The built-in image_gen tool used the old anchor as a reference. The original reference, generated RGBA source and exact prompt are preserved under assets/app-icon. AppIcon.appiconset now contains all ten macOS 1x/2x slots, including the previously absent 1024 px file. Only deterministic resizing was done with sips after generation.

scripts/build-icon.sh packages those source-controlled PNGs as ICNS with iconutil. The local build installs it as GroupedAppIcon.icns, sets CFBundleIconFile to GroupedAppIcon and removes the inherited CFBundleIconName, so the old icon in the reused compiled Assets.car is not selected by name. The release is 4.8.0-grouped.10, build 38. Xcode builds consume the updated source asset catalog normally.

All ten source PNGs passed expected-dimension and RGBA8 checks. The ICNS container includes its 1024 px representation, and native ImageIO decoded 16, 32, 64, 128, 256, 512 and 1024 px sizes. NSWorkspace.icon(forFile:) on the new app resolved the new icon; its own rendered 128 px preview was inspected, with transparent corners and violet tile confirmed. No desktop capture or app launch was used. Optimized compilation, strict signature validation and archive integrity also passed. Runtime Swift sources are byte-identical to grouped.9; the previous 143 behavioral checks were not repeated for this asset-only update.

## grouped.11 selected restrained icon

After viewing four quieter directions, the user selected variant 1 (Outline): a flat graphite anchor with rounded open flukes on a warm off-white macOS tile. The exact chosen generated image replaces the colorful grouped.10 artwork without further creative changes. Only deterministic resizing and ICNS packaging are applied. The reference, selected generated source and its prompt remain under assets/app-icon, together with concept-prompts.json; all four previews and their prompt set are saved in outputs/icon-concepts in the delivered workspace.

The bundle is 4.8.0-grouped.11, build 39. All ten RGBA8 PNG slots have the expected dimensions. The same native ImageIO/NSWorkspace verification checks ICNS sizes, transparent corners, the light tile and dark anchor. Runtime Swift sources remain unchanged; compilation, signature and archive checks apply to this build.

## grouped.12 corrected selection and icon padding

The user clarified the intended artwork with an attachment: concept 4 (Light), a graphite anchor with pointed flukes and shallow relief on a pale gray tile. The previous interpretation of “first” as concept 1 was incorrect. The attachment is copied byte-for-byte to assets/app-icon/anchor-source.png. No new generation, redraw, recoloring or anchor geometry changes are applied.

scripts/prepare-app-icon.swift detects the continuous tile through the canvas center and crops only external padding, ignoring isolated pixels outside the tile. The 1254 px source is cropped to (78, 79, 1098, 1098), preserving aspect ratio, then resized into the ten asset slots. The central tile spans 1098×1074 px before resizing: full asset width and approximately 98 percent height. The 128 px packaged asset measures 128×124 px at its opaque center runs. IconServices adds its normal application-icon inset separately; the system preview measures 104×104 px inside a 128 px request.

The bundle is 4.8.0-grouped.12, build 40. Native ICNS decoding, system resolution, asset dimensions/fill, strict signing and archive integrity are checked. Runtime Swift sources remain unchanged. English contribution documents and selected-icon metadata are updated to match the confirmed artwork.

## grouped.13 system icon appearance and alpha handling

A user screenshot exposed bright spots around the anchor eye and reduced contrast in the application icon, even though the standalone PNG was correct. Previous checks confirmed dimensions and basic colors but did not reject this visual mismatch; that validation was insufficient.

Native A/B probes showed that the effect also occurred with PNG payloads stored directly in ICNS and with old build metadata removed. An opaque backing, with unchanged anchor artwork, prevented the inferred foreground material treatment. A Finder custom-icon experiment also preserved the image but failed strict signature validation and was discarded. No Finder custom icon or resource-fork workaround is shipped.

The original attached source and transparent cropped preview remain unchanged. prepare-app-icon.swift additionally composites only the transparent exterior over a light backing and writes an opaque RGB packaging master. All ten app-icon asset slots use opaque RGB8 PNGs. package-app-icon.py stores those PNGs byte-for-byte in standard ICNS chunks, without extra inferred-material metadata or image re-encoding; build-icon.sh invokes it instead of iconutil. The system still supplies its normal outer icon mask.

check-app-icon.swift renders the actual NSWorkspace application icon and compares an eroded ring-interior mask against the approved preview. For the old grouped.12 icon, 295 of 1,254 ring-interior samples were anomalously bright, with mean luminance error 0.16784. For grouped.13, zero were anomalously bright and mean error was 0.00546. This is a targeted visual regression check on the current macOS session, not a claim of complete cross-version appearance validation. Native ICNS decoding covers all sizes 16–1024 px, each payload is checked against its source PNG and strict ad-hoc signature validation passes. The version is 4.8.0-grouped.13, build 41; runtime application Swift sources are unchanged.

Apple describes automatic material treatment for existing Mac icons in [WWDC25: Say hello to the new look of app icons](https://developer.apple.com/videos/play/wwdc2025/220/). The specific alpha-dependent artifact and workaround above were established with our own native probes.
