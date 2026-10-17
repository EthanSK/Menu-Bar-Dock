# Complete customization proposal

Hi Ethan,

I have customized Menu Bar Dock 4.8.0 and would like to offer the complete current version back to you. This is one draft proposal with the entire implementation, so you can decide which parts, if any, fit the project. There is no expectation that you merge the whole snapshot.

### What changes

- **Grouped dock:** one persistent menu-bar status item keeps the app icons together, with a configurable right margin, optional rounded background, circular pressed highlights and overflow handling. Command-drag moves the group.
- **Folder shortcuts:** pin individual folders alongside applications, with folder-specific actions and saved ordering.
- **Running indicators:** a small dot to the left of each running application's icon scales with the artwork and stays separate from it.
- **Optional hover movement:** approximately 1.5 mm down over 0.18 seconds, controlled by a preference and respecting Reduce Motion. Enter/exit tracking and Core Animation avoid continuous cursor polling. Right-click menus remain anchored to the stationary button.
- **Preferences and restart:** independent animation/background switches, a visible group-margin control and a restart button.
- **Reliability and refresh performance:** observer cleanup, process-specific state/recency, validated limits and geometry, keyboard slider actions, safer table reordering and visible launch errors. Reused buttons/artwork, a bounded custom-icon cache, coalesced refreshes and one process snapshot reduce repeated work.
- **Optional branding:** the selected gray anchor icon, its source/provenance and complete asset family. Opaque RGB packaging prevents the unwanted glass highlights and contrast loss reproduced in macOS system icon rendering.

Existing per-app icon overrides and instance badges from upstream 4.8.0 are preserved and adapted. The full inventory and qualifications are in [the English change summary](https://github.com/Atom7z/Menu-Bar-Dock/blob/feature/grouped-dock-folders/docs/changes-grouped-EN.md); [implementation notes](https://github.com/Atom7z/Menu-Bar-Dock/blob/feature/grouped-dock-folders/docs/grouped-dock.md), [native check tools](https://github.com/Atom7z/Menu-Bar-Dock/blob/feature/grouped-dock-folders/scripts/check-grouped.sh) and [raw benchmark data](https://github.com/Atom7z/Menu-Bar-Dock/tree/feature/grouped-dock-folders/docs/benchmarks) are included.

### Validation and limits

- 143 native behavioral checks passed for grouped.9; grouped.13 retains byte-identical runtime Swift sources. The later icon-only revisions were checked separately.
- The current grouped.13/build 41 application passed optimized arm64 compilation, strict ad-hoc signature validation, native icon-resolution/contrast checks and archive-integrity checks. The [verification record](https://github.com/Atom7z/Menu-Bar-Dock/blob/feature/grouped-dock-folders/docs/verification-grouped13.txt) distinguishes historical checks from the final packaging checks.
- Full Xcode/XCTest, Intel/universal builds and compatibility with the upstream macOS 10.15 target have **not** been validated. Broader manual display/menu/restart testing and animation energy measurements remain open.
- Grouped mode is currently always enabled. New external status icons can still appear to its left; this does not override macOS ordering.

The separate local arm64 build targets macOS 11+, uses `local.menubardock.grouped`, imports preferences selectively and disables upstream automatic updates. These local packaging choices are included for reproducibility, not proposed as official release defaults.

[Download the current app, complete source archive and English contribution pack](https://github.com/Atom7z/Menu-Bar-Dock/releases/tag/grouped.13-preview). This is an unofficial preview with an ad-hoc signature, not a notarized official release.

The work was developed with AI assistance, and the optional icon artwork was AI-generated. Its source and prompts are included. Please feel free to take only the useful parts, request changes, or close this proposal if it does not fit your plans.

Thank you for creating Menu Bar Dock.
