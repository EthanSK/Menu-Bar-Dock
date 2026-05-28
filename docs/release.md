# Release and Sparkle setup

Menu Bar Dock ships signed, notarized GitHub Releases with a Sparkle appcast
served from the `gh-pages` branch. The pipeline mirrors the
[macos-widgets-stats-from-website](https://github.com/EthanSK/stats-widget-from-website)
and [producer-player](https://github.com/EthanSK/producer-player) release flows.

## What the workflow publishes

The `Release` workflow (`.github/workflows/release.yml`) runs on:

- pushes to `main` or `master` — produces a "rolling build" release tagged
  `v<X.Y.Z>-build.<run_number>`. **Does not update appcast.xml**, so existing
  installs aren't offered the rolling build. Useful as a testing artifact.
- pushes of a `v*` tag — produces a canonical release tagged `vX.Y.Z`.
  **Updates appcast.xml on `gh-pages`** so existing installs auto-update.
- manual `workflow_dispatch` from the Actions tab — same as a branch push.

Each release attaches:

- a versioned ZIP: `Menu-Bar-Dock-vX.Y.Z.zip`
- a stable latest alias: `Menu-Bar-Dock-latest.zip`

The on-disk ZIP basename uses URL-safe hyphens; the .app wrapper inside is
named `Menu Bar Dock.app` (with spaces).

The stable user-facing URL is:

```text
https://github.com/EthanSK/Menu-Bar-Dock/releases/latest/download/Menu-Bar-Dock-latest.zip
```

Sparkle appcast URL:

```text
https://www.menubardock.com/appcast.xml
```

(Falls back to `https://ethansk.github.io/Menu-Bar-Dock/appcast.xml` if the
custom domain ever lapses — both point at the same `gh-pages` branch.)

## Required GitHub Actions secrets

Add these in GitHub → repo → Settings → Secrets and variables → Actions:

| Secret | Required | Purpose |
| --- | --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | yes | Base64-encoded Developer ID Application `.p12` certificate export. |
| `APPLE_CERTIFICATE_PASSWORD` | yes | Password for the exported `.p12`. |
| `APPLE_ID` | yes | Apple ID email used by `xcrun notarytool`. |
| `APPLE_APP_SPECIFIC_PASSWORD` | yes | App-specific password for notarization. |
| `SPARKLE_ED25519_PRIVATE_KEY` | yes | Sparkle Ed25519 private key used by `sign_update`. |
| `APPLE_TEAM_ID` | recommended | 10-character Apple Developer Team ID for signing/notarization. |
| `DEVELOPMENT_TEAM` | optional fallback | Alternate team-id secret name supported by the workflow. |

The checked-in fallback team ID is `T34G959ZG8`, but `APPLE_TEAM_ID` is safer
because it keeps account-specific release configuration in GitHub settings.

If you already configured these secrets for `stats-widget-from-website` or
`producer-player`, the same `APPLE_*` values will work here — they're tied to
the Apple Developer account, not the repo.

## Sparkle keys

Public key already in `MenuBarDock/Info.plist`:

```text
SUPublicEDKey = k3B1U0o3RBCyNKdtLsniY1f2HajvaVWSr/NLcZ499ZM=
```

The corresponding private key is stored in the maintainer's macOS Keychain
under account `menu-bar-dock` (created by
`Pods/Sparkle/bin/generate_keys --account menu-bar-dock` on 2026-05-28).

**Get the base64 private key for the GitHub Secret:**

```bash
~/Projects/menu-bar-dock/Pods/Sparkle/bin/generate_keys --account menu-bar-dock -x /tmp/sparkle-priv.txt
cat /tmp/sparkle-priv.txt | pbcopy
# paste into GitHub repo Settings → Secrets → SPARKLE_ED25519_PRIVATE_KEY
shred -u /tmp/sparkle-priv.txt   # nuke the on-disk copy
```

The keychain copy is the long-term canonical store. Losing it means future
local releases need to be CI-only, and rotating the public key in Info.plist
would break every existing install's update path.

**Export the Developer ID certificate as base64 for the GitHub Secret:**

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Validation gates

The workflow runs `scripts/validate_release_metadata.py` before building and
after appcast generation. It fails if:

- release config points at the wrong repo slug
- the GitHub Release is not marked `make_latest: true`
- the stable latest ZIP alias is missing
- Sparkle signatures are placeholders
- appcast enclosure lengths are zero/missing
- appcast/site URLs point at the wrong GitHub Pages or GitHub repo paths
- pbxproj versions drift from semver

Run the static gate locally:

```bash
python3 scripts/validate_release_metadata.py --check-repo --check-version
```

## Safe release procedure

1. Ensure the working tree is clean: `git status`.
2. Bump the version with `scripts/bump-version.sh`:

   ```bash
   scripts/bump-version.sh 4.7.1          # auto-increment build number
   # or: scripts/bump-version.sh 4.7.1 28  # explicit build number
   ```

   The script updates `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` across
   every Debug + Release build config in `Menu Bar Dock.xcodeproj/project.pbxproj`
   in one pass.

3. Update `CHANGELOG.md` with notes for the new version.

4. Validate locally:

   ```bash
   python3 scripts/validate_release_metadata.py --check-repo --check-version
   git diff --check
   ```

5. Commit + push + tag:

   ```bash
   git add -A
   git commit -m "Bump version to 4.7.1"
   git tag v4.7.1
   git push origin master --tags
   ```

   This triggers the workflow. The tag-race guard makes the branch-push run
   no-op so the tag-push run is the sole publisher.

6. Confirm:
   - The new GitHub Release contains both ZIP assets.
   - `gh-pages` branch's `appcast.xml` was updated by the workflow.
   - An existing install of Menu Bar Dock offers the update (open the app
     and let it run for a moment — the Sparkle check fires at launch).

## Do NOT

- Hand-edit `appcast.xml` with placeholder signatures. The workflow generates
  it from the signed ZIP so the signature and byte length match the shipped
  asset.
- Hand-edit Info.plist version fields. Use `scripts/bump-version.sh` which
  updates the pbxproj build settings (Info.plist inherits via
  `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` placeholders).
- Rotate `SUPublicEDKey` in Info.plist. Doing so invalidates every existing
  install's update path. If the private key is ever compromised, plan a
  coordinated rollout with a fresh keypair + a fallback "please re-download
  from the website" message on the landing page.

## Troubleshooting

**"resource fork, Finder information, or similar detritus not allowed" during codesign**
Run `xattr -cr build/Export/Menu\ Bar\ Dock.app` then retry. The xattrs are
usually a result of running on a development machine; CI runners are clean.

**Sparkle "update appears to be improperly signed" on the client**
The most common cause: the appcast's `sparkle:edSignature` was generated from
a key that doesn't match the `SUPublicEDKey` in the installed app's Info.plist.
Verify by checking the public key in both places matches exactly.

**"App is damaged and can't be opened" Gatekeeper error after manual download**
The notarization stapling step failed silently. Re-run the workflow; the
stapler retry loop handles most transient propagation lags.
