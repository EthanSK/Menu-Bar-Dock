# Proposed contribution plan

Prepared on 17 October 2026 for the local grouped.13 customization. The plan below was prepared before publication. The owner subsequently requested that the complete current version be offered in one draft pull request. That publication decision takes precedence over the earlier suggestion to split contributions; the maintainer can choose whichever parts are useful.

## How the GitHub workflow works

The normal sequence is **fork → feature branch → commits → push to the fork → pull request to the original repository**. A commit records a change in Git; the pull request is the proposal the maintainer reviews and may merge. The original repository is often called *upstream*.

GitHub documents this process in [Contributing to a project](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project) and [Creating a pull request from a fork](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request-from-a-fork).

The default branch is `master`, not `main`. On the date above, the GitHub API confirmed upstream `master` at `027f62230f3a5758770f1beab72e1d3ea17c8302`, the same base as this checkout. Recheck it before publishing.

There is no need to upload a ZIP and rebuild Git history by copying files manually. The current directory is already a clone of the original repository, with the changes on `feature/grouped-dock-folders`. Existing work is still uncommitted, including untracked scripts, documentation and icon assets; those files need deliberate inclusion.

## Recommended approach

1. Preserve the complete personal version as a clearly named branch in a fork, including its source and documentation. Keep generated apps, build caches and local logs out of source commits. This provides a reference implementation, not the first PR to merge wholesale.
2. Use the prepared maintainer message to discuss scope through the project's issue tracker. The upstream README explicitly points feedback there. Add a fork/comparison link once one exists. A small maintainer-approved change can also be submitted directly as a focused PR.
3. Prepare focused branches from the latest upstream `master`, porting only the relevant changes and tests. The current implementation mixes several concerns in the same files; splitting it requires reviewing dependencies, not just dividing the file list.
4. Open small draft PRs for work that still needs compatibility validation. Keep ready, fully tested fixes separate. The maintainer decides whether and how to merge them; a fork does not grant push access to the original project.

## Suggested pull-request boundaries

| Contribution | Scope | Preparation needed |
| --- | --- | --- |
| Reliability fixes | Observer cleanup, accessory activation, validated limits/preferences, keyboard actions, safe table moves, launch errors | Extract focused fixes and corresponding tests; distinguish upstream defects from grouped-prototype regressions |
| Refresh performance | Shared process snapshot, event coalescing, model/button reuse, bounded decoded-icon cache, unchanged-write suppression, lazy diagnostics | Preserve invalidation behavior; report reproducible operation measurements rather than battery claims |
| Folder shortcuts | Directory-aware models, add dialog, folder actions, persistence and folder-specific running state | Check whether a folder-only PR can be independent of the grouping change |
| Grouped dock | One status item, shared layout, margin, overflow, circular highlight and left running indicator | Discuss making grouped mode opt-in; preserve original-user behavior and update the native Preferences UI |
| Hover and restart | Reduce Motion, animation toggle, complete artwork rendering, stable menus and restart helper | Separate animation from the core grouping review; test actual restart, displays and native menu tracking |
| Alternative app icon | Selected monochrome anchor, complete icon asset set and provenance | Treat as a separate branding choice; do not make functional PRs depend on it |

These are proposed review boundaries, not a promise that six independent PRs already exist. Combine or reorder them if the maintainer prefers, and keep inseparable fixes with their feature.

## Keep local packaging separate

The personal fork may retain the separate bundle ID, local preference import/repair, grouped version strings, ad-hoc build scripts and disabled upstream updates. An upstream PR should preserve the official app identity, release process, signing/notarization, Sparkle behavior and deployment target unless the maintainer explicitly agrees to change them.

The normal source asset catalog is suitable for review. The local workaround that copies compiled resources from an installed application should not become the official build path. The programmatically appended Preferences controls also need review against the project's native storyboard/layout conventions.

Do not commit the packaged `.app`, distribution ZIPs, Swift module caches, machine-specific logs or full copied preferences. Include reproducible source, necessary tests, relevant documentation and selected design assets. Rejected visual experiments can remain outside the functional PRs.

## Before asking for code review

- Build through the normal CocoaPods/Xcode workspace, including the upstream macOS 10.15 deployment target and Intel/Apple Silicon configurations. The existing local build only targets arm64 on macOS 11+.
- Run the relevant Xcode tests and make the new test cases work without requiring an unrelated installed app for resources. Keep the native check harness as supplemental evidence where appropriate.
- Verify folder opening, right-click menus, Command-drag, saved positions, empty/overflow states, display/notch changes, light/dark appearances and actual restart in a normal macOS session.
- Retain the distinction between 143 historical behavioral checks and the later icon-only checks. Avoid claiming universal compatibility or energy savings that have not been measured.
- Review the public change set for accidental personal data, temporary files and unrelated formatting changes. Maintain original attribution.
- Check the maintainer's contribution/AI policy. No repository-local CONTRIBUTING document or root LICENSE file was found at the checked base; clarify the project's contribution and distribution terms rather than inventing a license for it.

## Git setup when publication is authorized

Create the fork on GitHub first. The current `origin` already points to EthanSK's repository, so it can remain unchanged; add a second remote for the fork. The following is a template, not a command that has been run:

```sh
git remote add fork https://github.com/YOUR-LOGIN/Menu-Bar-Dock.git
```

After reviewing and staging the complete personal source snapshot, commit it on the existing feature branch and push that branch to `fork`. Use separate branches based on upstream `master` for the focused contributions. Review the comparison before opening a PR, with **base repository** `EthanSK/Menu-Bar-Dock`, **base branch** `master`, and the relevant branch of the fork as **head**.

Do not push directly to upstream, force-push someone else's branch, or rewrite the current working tree just to create the fork. Fork creation, publication and sending the maintainer message are separate next actions from this documentation task.

## Prepared material

- `changes-grouped-EN.md`: complete final-state change summary, verification and limitations.
- `upstream-proposal-EN.md`: a short first message for the maintainer.
- `grouped-dock.md`: existing implementation notes and iteration history.
- `scripts/check-grouped.sh` and `scripts/benchmark-grouped.sh`: reproducible local validation tools, subject to upstream integration work.

The most useful first contact is a short explanation of the grouped-dock use case and a proposal for small reviewable changes, with the full inventory available as supporting material.
