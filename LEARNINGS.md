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
**Date:** 2026-05-31T17:04:16Z
**Trigger:** voice 4442
**Symptom:** Apps with no known ordering info appeared at the START of the dock, stealing the newest-app slot
**Root cause:** Array.reorder(by:) in Utils.swift returned un-ordered elements (orderElement not in preferredOrder) as the LARGEST, sorting them to the array END = the most-recent/newest-app slot for the default .mostRecentOnRight + suffix(limit) path; suffix even preferentially kept un-ordered apps over real ordered ones
**Fix:** Added unorderedGoTo:UnorderedPlacement param to reorder(by:). Un-ordered elements now sort to the OLDEST/least-recent side (.start for suffix-truncated modes, .end for prefix-truncated .mostRecentOnLeft), wired from runningAppsSortingMethod via unorderedPlacement() in RunningApps.swift
**Commit:** ee2965e
**Guard:** Unit tests in MenuBarDockTests.swift cover ordered baseline, .start placement, .end placement, multi-unordered clustering, all-unordered stable order; thorough comments at reorder(by:) + populateApps()
---

