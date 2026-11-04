# Learnings

Per-repo institutional memory for fixes. Every entry below is a real bug we hit + how we solved it. Check this file BEFORE attempting a same-looking fix.

Maintained by the `learnings` skill — see `~/.claude/skills/learnings/skill.md`.

## Format

Each entry looks like:

```
---
**Date:** YYYY-MM-DDTHH:MM:SSZ
**Trigger:** <voice N / message snippet / null>
**Symptom:** <what was visible>
**Root cause:** <what we actually found>
**Fix:** <file:line + short prose + commit SHA>
**Guard:** <test / lint / watchdog / comment that prevents regression — or 'none'>
---
```

## Entries

(newest first)


## Exclude terminated processes from instance snapshots (2026-11-04)

A real VS Code `code --status` invocation briefly creates another regular Code
process without another editor window. At its quit notification, macOS can still
return that exited process in `NSWorkspace.runningApplications`, with
`isTerminated == true`. Counting only `.regular` entries leaves badge 1 on the
survivor until another app event refreshes the models. The source-model probe
reproduced this in two of six runs; observing the later array change alone did
not refresh the existing model.

Exclude terminated entries from the badge count, the running-app list before
its limit, and pinned-app binding. Keep live accessory apps eligible for pins,
launch-date numbering, real separate processes and process-specific activation.
The update methods accept a supplied snapshot for deterministic tests and still
default to the live workspace in production. Four new snapshot regression tests
fail with the former filters; all 18 tests pass with the repair. No sleep or
new polling loop was introduced.

Xcode 27's SDK no longer builds the existing macOS 10.15 deployment target.
Release builds pin macos-15/Xcode 16.4 so older-system support is preserved;
the locally tested Xcode 27 candidate uses a command-line macOS 12 minimum only.
The public artifact must be checked independently before claiming its minimum OS.

Before replacing this app, save and compare its app-setting fields: the old
running instance saves its cached preferences on quit and can overwrite a newer
external edit. During this install that changed the voice-app pin from the
existing HelloChat.app to a missing Hey Chat.app. After the process exited, only
that list value was restored from the pre-install snapshot; all 16 app-setting
fields then matched. Do not overwrite unrelated or newer preferences wholesale.


## Preserve original crash evidence before bounded logs rotate (2026-10-26)

macOS moved both October 25 Menu Bar Dock `.ips` files into the user's
`DiagnosticReports/Retired/` folder. Search that folder before treating a missing
top-level report as lost. Preserve incident-specific originals in ignored local
verification storage: the app's bounded debug log can rotate out pre-crash lines
before its 24-hour age threshold. The reports remained readable and identified
layout recursion/abort; neither was an out-of-memory termination. A current
memory snapshot or stable icon/view counts cannot rule out all leaks or prove the
historical trigger. Avoid interpreting virtual-address totals as physical use.

---
**Date:** 2026-10-25T19:28:00Z
**Trigger:** Ethan: add instrumentation so the next recurring Menu Bar Dock crash can be diagnosed.
**Symptom:** The 4.8.1 crash reports contained AppKit layout/backing-scale frames, including a main-thread recursion overflow, but the activation log did not identify the corresponding status-item mutation.
**Root cause:** The exact layout trigger remains unknown. Existing diagnostics described app ordering, not layout phases, display changes, or the last unfinished session.
**Fix:** Extend the existing serial DebugLog writer with bounded layout breadcrumbs and atomic layout-state.json checkpoints. Keep one previous-session.json when the last run did not record a clean application termination; label it an unclean exit rather than proof of a crash. Record update reasons and begin/end stages, per-item mutations, click/menu entry and exit, and rate-limited display/backing notifications. Never force layout, capture user text, install a Swift fatal-signal handler, or claim that instrumentation fixes the original crash. Move ISO-8601 formatting onto the same queue as parsing and file IO.
**Guard:** Mac Mini's canonical xcodebuild test action executed all four new diagnostic tests plus the existing dropdown guard: five named tests, zero failures. Recovery uses real files but models abrupt termination by omitting finishSession; it does not deliberately crash the live app. Recovery context holds at most 32 messages of 512 characters, with at most 256 pending diagnostic writes; debug.log retains its existing 4-MiB cap. Generated build.noindex sources must be excluded from SwiftLint, and test deployment targets must match the app's macOS 10.15 minimum to execute the tests with current Xcode.
**Release verification:** The final canonical unit run executed all 14 named tests with zero failures for native source commit abf3192. Universal 4.8.2/build 39 was built on the Mini, signed using the matching Developer ID on the MacBook after unattended Mini signing returned errSecInternalComponent, and installed as a complete bundle. Deep/strict signature verification, a new live process writing completed checkpoints, all 16 saved preference values, byte-identical app artwork, and visible menu-bar icons passed. Retain the signed archive and matching arm64/x86_64 dSYMs under the normal indexed Xcode Archives directory; logging and a few minutes of idle operation do not prove the original AppKit crash is fixed.
---

---
**Date:** 2026-10-17T12:04:00Z
**Trigger:** Publish the physically accepted numbered-instance fix as 4.8.1.
**Symptom:** Apple notarization returned HTTP 403, "A required agreement is missing or has expired," including the first retry after the account holder confirmed acceptance.
**Root cause:** Apple's account agreement gate blocked submission before binary analysis. The existing developer account page still showed the old June agreement; a fresh navigation later showed the October 13 agreement accepted on October 17. The precise propagation interval was not measured.
**Fix:** Reran the same canonical tag workflow without changing the release tag or bypassing notarization. Attempt 3 of run 39030171922 accepted the app and published 4.8.1/build 38. The public feed gate passed. Downloaded both release ZIPs and confirmed identical bytes, valid Developer ID signing, a stapled notarization ticket, Gatekeeper acceptance, and the Sparkle Ed25519 signature. A Sparkle probe using the preserved 4.8.0 host found 4.8.1/build 38. Installed the published bundle, verified its running path, and confirmed no preference keys changed.
**Guard:** Reload the account page after a legal-agreement handoff before inferring which agreement is pending. Treat acceptance as account-holder work and retry the existing release run; completion still requires notarization and the actual public appcast. A separate Paid Apps agreement update remained available and was not needed for this release.
---

---
**Date:** 2026-10-17T11:34:00Z
**Trigger:** Ethan: clicking numbered app instances 1 and 2 always opens the same instance.
**Symptom:** The badges distinguish running processes, but normal clicks still reopen the shared application bundle when the opening method is Launch.
**Root cause:** OpenableApp.openApp only selected the stored NSRunningApplication for the Activate preference. Launch reopened the bundle URL through NSWorkspace, allowing macOS to select a different process.
**Fix:** A numbered entry with a live running application uses the existing process-specific activation path regardless of its Launch preference. Unnumbered entries retain their opening preference, and the explicit Launch menu action remains available.
**Guard:** Two regression tests check that numbered entries with Launch and nil preferences activate their own process; all 10 unit tests passed. Full Swift typechecking for macOS 10.15 and release metadata checks passed. A universal signed 4.8.1 (38) build was installed and verified at /Applications/Menu Bar Dock.app with the original app icon and user preferences preserved. Ethan physically confirmed that the fix works and authorized release on 2026-10-17. Agent-side menu-bar automation could not verify those clicks: Computer Use cannot bind this windowless app's status items, and the disposable GUI test controller's background actions did not transfer foreground focus. All test processes/windows were removed; do not call that GUI attempt a passing focus test.
**Installation note:** Replace a complete app bundle rather than merging with ditto. Xcode 27's compiled nib files conflicted with the installed build's nib directories during a merge. Staging and signature-verifying a fresh bundle before renaming it into place resolved the installation; the signed 4.8.0 rollback copy was preserved.
---

---
**Date:** 2026-09-30T01:30:20Z
**Trigger:** Ethan: distinguish multiple app instances with numbered red badges and show manual screenshots.
**Symptom:** Separate app processes shared indistinguishable icons. PID-based numbering also put a newly launched process before the oldest one during the test.
**Root cause:** macOS PIDs wrapped during the test. Background launches did not emit activation notifications. Regular-app duplicate suppression previously hid all matching processes, and quitting one process cleared the pinned app binding.
**Fix:** Number the full regular running-process set by bundle identifier and launch date, using PID only to break ties. Refresh on launch without changing recency. Suppress only the process represented by the pinned entry and rebind that entry when its process exits. Draw the badge inside the visible menu-bar height so oversized icons do not clip it.
**Guard:** Native screenshots from actual test processes verified three badges on overridden icons, two badges after closing an instance, and no badge for a single process. PIDs wrapped again during the follow-up test without changing launch-order numbering. Numbers describe the current running set and can renumber when an instance exits; separate windows in one process do not receive individual badges.
---

---
**Date:** 2026-09-30T00:53:53Z
**Trigger:** Ethan: configurable per-app icon overrides; manually test them.
**Symptom:** Menu Bar Dock showed ChatGPT artwork while the running Codex app showed different artwork in Command-Tab. Adding the per-app action column also exposed a cold-launch layout problem: the column could sit outside the visible app list.
**Root cause:** NSRunningApplication.icon and NSWorkspace.icon(forFile:) both returned ChatGPT artwork for the running app. A table view's document bounds can expand when a column is added, so those bounds are not the available viewport width.
**Fix:** Store bounded PNG copies under the existing app URL identity in UserPrefs, and apply them after combining running and regular entries in OpenableApps. The app list shares the same lookup. Size the app column from the enclosing scroll view's content width and let the first column resize, preserving a fixed-width action column. Reopening the accessory app exposes Preferences for configuration.
**Guard:** Release build and macOS 10.15 Swift typecheck passed. Native UI tests confirmed image and app-bundle previews, Cancel, Save, per-app isolation, actual menu-bar artwork, and persistence after restarting with the source image moved. Cold-launch screenshots reproduced the missing action column and confirmed the layout correction. Reset restored the native icon; a malformed image was rejected without enabling Save. Real separate test processes showed 1/2/3 badges with one shared override, then 1/2 and no badge as instances exited. Both duplicate-priority settings retained distinct processes. Test entries and overrides were removed and original user-controlled preferences restored.
---

---
**Date:** 2026-07-30T12:05:00Z
**Trigger:** Menu Bar Dock 4.7.9 was published, but the installed updater still reported 4.7.8
**Symptom:** The canonical release workflow was green and `origin/gh-pages:appcast.xml` contained 4.7.9, while `https://www.menubardock.com/appcast.xml` still served 4.7.8. The Pages deployment run remained `waiting` overnight with no runner assigned.
**Root cause:** The release workflow treated committing `appcast.xml` to `gh-pages` as completion. GitHub's separate legacy Pages deployment can stall after that commit, leaving Sparkle clients on the previous public feed even though the GitHub Release exists.
**Fix:** Cancelled only the stale Pages run and requested a fresh build through the Pages API. The replacement run completed successfully and the public feed began serving 4.7.9/build 36. Added a separate `Verify public Sparkle feed` release job that checks the exact public version, build, ZIP filename, and byte length for up to 15 minutes.
**Commit:** post-v4.7.9 release-completion guard
**Guard:** A canonical release workflow cannot finish successfully until the public Sparkle URL serves the exact release metadata; `docs/release.md` records the bounded stale-run recovery procedure.
---

---
**Date:** 2026-07-29T22:52:00Z
**Trigger:** GitHub Actions release run 30497459199 failed at `pod install --deployment`
**Symptom:** The v4.7.9 tag workflow stopped before build/sign/notarization because CocoaPods reported `New Lockfile: 1.17.0` and `Old Lockfile: 1.16.2`.
**Root cause:** GitHub's current macOS runner upgraded its preinstalled CocoaPods generator to 1.17.0. Deployment mode treats the generator version recorded at the end of `Podfile.lock` as lockfile state, even when every pod version and checksum is unchanged.
**Fix:** Regenerated the lock metadata with a task-local CocoaPods 1.17.0 install; the only tracked change was `COCOAPODS: 1.16.2` to `1.17.0`.
**Commit:** v4.7.9 release repair commit
**Guard:** CocoaPods 1.17.0 `pod install --deployment` completes with `Verifying no changes`, and `Podfile.lock` exactly matches `Pods/Manifest.lock`.
---

---
**Date:** 2026-07-29T22:47:00Z
**Trigger:** Ethan: `Quit <app>` is the most common menu action and belongs at the top
**Symptom:** A running app's menu opened with Hide/Unhide first while Quit was several rows lower, making the primary action slower to reach.
**Root cause:** Commit 9b4b871 reordered the menu in response to issue #15's generic macOS convention, overriding the product owner's actual high-frequency workflow. No test protected the original quit-first priority.
**Fix:** `MenuBarItem.makeDropdownMenu()` now inserts `Quit <app>` before Hide/Unhide and Activate for running apps. Menu construction was separated from display so its order is directly testable.
**Commit:** v4.7.9 release commit
**Guard:** `testRunningAppDropdown_putsQuitActionFirst` asserts the first title and `q` shortcut, plus Hide as the following action.
---

---
**Date:** 2026-05-31T20:00:00Z
**Trigger:** Ethan voice: post-mortem on how the WRONG activation-policy fix got made (forensic, no code changes)
**Symptom:** Two commits (b64a85f 2026-05-23 16:02, 63fbce0 2026-05-23 17:04) "fixed" the frozen recency-sort by gating activation on `activationPolicy == .regular`, using a static capability enum as a foreground test. Misdiagnosis; corrected in a8674de (v4.7.5, 2026-05-31).
**Root cause (of the BAD fix, not the original bug):** The agent conflated `NSRunningApplication.activationPolicy` (an app-mode/capability — .regular/.accessory/.prohibited, KVO-observable but normally fixed; NOT current foreground state) with "which app is in front." The original 2021 gate `NSWorkspace.shared.frontmostApplication == app` (commit b364bc2) was the REAL bug — polling global frontmost state inside a payload-carrying notification callback is a fragile contract Apple never promised to keep synchronous; empirically OK pre-14, observably broke on macOS 14+. b64a85f "worked" only because it incidentally DELETED that racy check. The `.regular` gate it added is a near-tautology FOR THE VISIBLE DOCK (RunningApps.canShowRunningApp re-filters .regular) — so behaviour looked unchanged and the symptom vanished, masking the wrong premise.
**Why it slipped through:** (a) symptom disappeared (broken check deleted) so it "looked" fixed; (b) `.regular` gate redundant for the visible list → nothing visibly broke; (c) NO regression test for activation handling; (d) a confident-but-wrong code comment ("filter via activationPolicy instead… preserves the intent") cemented the wrong mental model for the next reader; (e) the Codex review at 63fbce0 caught a REAL risk (behaviour change on pre-Sonoma) but reinforced the wrong model — it version-gated the policy filter instead of questioning whether activationPolicy is a foreground signal at all. Reviewing the diff-as-written can validate a wrong premise.
**Actual impact (honest):** NOT a live user-facing regression in the common case — at runtime the recency sort un-froze and worked. The real damage was (i) a wrong mental model persisting in a confident comment, and (ii) a residual latent edge that even v4.7.5 still carries: because the gate drops non-.regular activations BEFORE state ingestion, when an `.accessory`/LSUIElement app activates, `lastActivatedApp` (now the active-app truth used by the hide-active-app filter) is never updated and goes stale. Menu Bar Dock itself is LSUIElement, and accessory apps can be activated by windows/programmatically. Display-eligibility filtering sits in front of event ingestion rather than at the consumer boundary.
**Fix (the post-mortem itself):** documentation only — this entry. Code fix already landed in a8674de.
**Lessons / prevention:**
  - When a fix makes a symptom VANISH, verify WHY it works, not just THAT it works. b64a85f passed because it removed the broken line, not because the new line was right.
  - Never use a capability/policy/mode enum (activationPolicy, etc.) as a current-state signal. It answers "what kind of app is this," not "is it in front."
  - Prefer the authoritative EVENT PAYLOAD (notification.userInfo applicationUserInfoKey) over polling global mutable state (frontmostApplication) inside that event's own callback.
  - Don't put display-eligibility filters in front of event/state INGESTION — ingest every activation as state truth, then decide separately whether it participates in the visible list. (Residual .accessory staleness above is the live consequence of violating this.)
  - Add a regression test covering activation handling (none existed; the next ordering bug ee2965e DID add tests — follow that precedent here too).
  - Misleading/over-confident comments propagate misdiagnoses. Phrase OS-timing causal claims as OBSERVED behaviour ("we saw X drop on 14+") not platform fact ("macOS 14 cooperative activation guarantees Y"), unless backed by repro logs.
  - A code review that validates the diff as written can still miss a wrong premise — ask "is the underlying assumption true?" not just "is this change safe?"
**Commit:** a8674de (code fix); this entry is the post-mortem (no code change)
**Guard:** this learning + the corrected AppTracker.swift/RunningApps.swift comments; regression test for activation still OUTSTANDING (recommended)
---

---
**Date:** 2026-05-31T18:48:33Z
**Trigger:** Ethan voice: is the activation-policy fix actually right? research+verify
**Symptom:** MBD recency sort frozen / activation gate uses activationPolicy as a foreground test
**Root cause:** activationPolicy is a static per-app capability, NOT a foreground signal; old frontmostApplication==app check is racy on macOS 14+ cooperative activation
**Fix:** trust didActivateApplication notification payload; drop frontmostApplication check on all OS versions; keep .regular only as a cheap skip; also track lastActivatedApp for the hide-active-app filter
**Commit:** a8674de
**Guard:** comment + this learning
---

---
**Date:** 2026-05-31T17:04:16Z
**Trigger:** voice 4442
**Symptom:** Apps with no known ordering info appeared at the START of the dock, stealing the newest-app slot
**Root cause:** Array.reorder(by:) in Utils.swift returned un-ordered elements (orderElement not in preferredOrder) as the LARGEST, sorting them to the array END = the most-recent/newest-app slot for the default .mostRecentOnRight + suffix(limit) path; suffix even preferentially kept un-ordered apps over real ordered ones
**Fix:** Added unorderedGoTo:UnorderedPlacement param to reorder(by:). Un-ordered elements now sort to the OLDEST/least-recent side (.start for suffix-truncated modes, .end for prefix-truncated .mostRecentOnLeft), wired from runningAppsSortingMethod via unorderedPlacement() in RunningApps.swift
**Commit:** ee2965e
**Guard:** Unit tests in MenuBarDockTests.swift cover ordered baseline, .start placement, .end placement, multi-unordered clustering, all-unordered stable order; thorough comments at reorder(by:) + populateApps()
---
