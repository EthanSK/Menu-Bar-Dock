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

