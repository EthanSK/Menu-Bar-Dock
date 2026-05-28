# Release setup — manual steps Ethan needs to do

The Sparkle auto-update + GitHub Pages release-tracking rails are in place,
but the first release can't run until these one-time manual steps are done.

After completing them, push a `v*` tag (e.g. `git tag v4.7.0 && git push
origin master --tags`) and the workflow takes care of everything else.

---

## 1. Upload the Sparkle Ed25519 private key as a GitHub Secret

The keypair was generated locally on the Mac Mini on 2026-05-28. The
**public** key is already committed in `MenuBarDock/Info.plist`:

```text
SUPublicEDKey = nnWPxTwKYaUTPjycwsl0jIBtiPNjokGcuZRA/El7W/Y=
```

The **private** key sits in the maintainer's macOS Keychain under account
`menu-bar-dock`. The CI needs a base64-encoded copy as a repo secret.

```bash
cd ~/Projects/menu-bar-dock
./Pods/Sparkle/bin/generate_keys --account menu-bar-dock -x /tmp/sparkle-priv.txt
cat /tmp/sparkle-priv.txt | pbcopy
shred -u /tmp/sparkle-priv.txt   # nuke the on-disk copy
```

Then:

1. Go to https://github.com/EthanSK/Menu-Bar-Dock/settings/secrets/actions
2. Click **New repository secret**
3. Name: `SPARKLE_ED25519_PRIVATE_KEY`
4. Value: paste from clipboard
5. Add secret

The keychain copy is the long-term canonical store. If you ever lose it,
the GitHub Secret + the public key in Info.plist are still load-bearing —
do NOT rotate the public key without a coordinated rollout.

---

## 2. Add the Apple Developer ID + notarization secrets

Same set of secrets as `stats-widget-from-website` + `producer-player`. If
you've already configured them on either of those repos, the SAME values
work here (they're tied to the Apple Developer account, not the repo).

In https://github.com/EthanSK/Menu-Bar-Dock/settings/secrets/actions, add:

| Secret | What goes in it |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | `base64 -i DeveloperIDApplication.p12 \| pbcopy` and paste |
| `APPLE_CERTIFICATE_PASSWORD` | The password you set when exporting the .p12 |
| `APPLE_ID` | Your Apple Developer email |
| `APPLE_APP_SPECIFIC_PASSWORD` | An app-specific password generated at https://appleid.apple.com/account/manage |
| `APPLE_TEAM_ID` | `T34G959ZG8` (or generate a fresh one if you've rotated) |

To export the Developer ID certificate from Keychain Access:

1. Open **Keychain Access** → **login** keychain → **Certificates**
2. Right-click "Developer ID Application: Ethan Sarif-Kattan (T34G959ZG8)"
3. Choose **Export "..."** → save as `.p12` (you'll be prompted for a password)
4. `base64 -i DeveloperIDApplication.p12 | pbcopy`

---

## 3. Enable GitHub Pages for the `gh-pages` branch

The release workflow auto-creates the `gh-pages` branch on the first
canonical-tag release (it falls back to an orphan commit if the branch
doesn't exist yet). But you still need to flip GitHub Pages to serve from
that branch:

1. Go to https://github.com/EthanSK/Menu-Bar-Dock/settings/pages
2. Source: **Deploy from a branch**
3. Branch: `gh-pages` / `/ (root)`
4. Custom domain: `www.menubardock.com` (should already be set per the
   existing CNAME file)
5. Enforce HTTPS: yes

Note that the existing site is currently served from the `master` branch
(via the README.md + Jekyll cayman theme). After the first Sparkle release,
the site switches to `gh-pages` which will contain `appcast.xml` PLUS the
README-driven landing page (the release workflow's gh-pages step doesn't
delete other files; it just writes `appcast.xml`).

**If you'd rather keep serving the landing page from `master`** and ONLY
publish `appcast.xml` to a separate location, change `SUFeedURL` in
`MenuBarDock/Info.plist` from `https://www.menubardock.com/appcast.xml` to
`https://ethansk.github.io/Menu-Bar-Dock/appcast.xml`, then set the
gh-pages source to `gh-pages` / `/ (root)` WITHOUT the custom domain. That
way `www.menubardock.com` stays as the README-driven master-branch site and
`ethansk.github.io/Menu-Bar-Dock/appcast.xml` serves the appcast.

---

## 4. (Optional) Wire a "Check for Updates…" menu item in Interface Builder

`AppDelegate.swift` now has an `@objc func checkForUpdates(_:)` action that
shows the Sparkle update UI on demand. To make it user-accessible, open
`MenuBarDock/Base.lproj/Main.storyboard` in Interface Builder and:

1. Add an `NSMenuItem` "Check for Updates…" to the preferences popover or
   menu-bar-item context menu
2. Wire its action to `checkForUpdates:` on the App Delegate's First Responder

This is a nice-to-have — Sparkle's background scheduler still fires daily
without this menu item, so users will be offered updates either way.

---

## 5. Push a canonical tag to test the first release

After steps 1–3 are done:

```bash
cd ~/Projects/menu-bar-dock
# version is already bumped to 4.7.0 / build 27 (see CHANGELOG.md)
git push origin master            # if there are unpushed commits
git tag v4.7.0
git push origin v4.7.0
```

Then watch https://github.com/EthanSK/Menu-Bar-Dock/actions for the
"Release" workflow run. The first run takes ~5-10 min on macos-latest.

If it fails, check the run logs — `validate_release_secrets` step gives
the clearest error message for missing secrets.
