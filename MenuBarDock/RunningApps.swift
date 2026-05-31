//
//  RunningApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 12/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol RunningAppsUserPrefsDataSource: AnyObject {
 	var hideFinderFromRunningApps: Bool { get }
	var hideActiveAppFromRunningApps: Bool { get }
	var maxRunningApps: Int { get }
    var regularAppsUrls: [URL] { get }
	var runningAppsSortingMethod: RunningAppsSortingMethod { get }
}

class RunningApps {
	public var apps: [RunningApp] = [] // state not getter for efficiency, will be ordered correctly

	private var ordering: [String] = [] // array of ids least to most recently activated

	// The app that most recently activated, captured from the activation notification
	// payload (via handleAppActivation, which AppTracker feeds with the authoritative
	// NSRunningApplication from the notification). We use THIS for the "hide active app"
	// filter instead of reading NSWorkspace.shared.frontmostApplication live during
	// populateApps(). On macOS 14+ (cooperative activation) frontmostApplication isn't
	// updated synchronously with the activation notification, so a live read during
	// populateApps() — which runs FROM that very notification — could return the stale
	// previous frontmost app and hide the wrong app (or fail to hide the active one).
	// Tracking the payload here removes that race.
	// Limitation: this is only set once an activation has been observed since launch.
	// Before the first activation it is nil and we fall back to frontmostApplication
	// (best effort for the very first populateApps() at init time).
	private var lastActivatedApp: NSRunningApplication?

	weak var userPrefsDataSource: RunningAppsUserPrefsDataSource!

	public var limit: Int {
 		if userPrefsDataSource.maxRunningApps == 0 && userPrefsDataSource.regularAppsUrls.count == 0 {
			// we need to show at least one app in the menu bar, or user won't be able to access preferences!
			return 1
		}
		return userPrefsDataSource.maxRunningApps
	}

	init(
		userPrefsDataSource: RunningAppsUserPrefsDataSource
	) {
		self.userPrefsDataSource = userPrefsDataSource
		populateApps()
		ordering = apps.map { $0.id } // populate the ordering array so the openable apps can start displaying correct order from the start.
		// the reason it's not ordered straight away: https://trello.com/c/ZFs3C32g
  	}

	func update() {
		populateApps()
	}

	func handleAppActivation(runningApp: NSRunningApplication) {
		// DEBUG: snapshot ordering BEFORE mutation so the log shows the before->after
		// transition for each activation (the core thing we need to diagnose a
		// "wrong order" report). `shortIds` keeps the line readable (app names only).
		let before = shortIds(ordering)
		self.lastActivatedApp = runningApp // authoritative "currently active app" from the activation notification — used by the hide-active-app filter to avoid a racy frontmostApplication read
		let runningApp = RunningApp(app: runningApp) // to get id
		self.ordering.removeAll(where: { $0 == runningApp.id })
		self.ordering.append(runningApp.id) // needs this order for it to populate from the most helpful side correctly
		DebugLog.shared.log("[ordering] handleAppActivation lastActivated=\(lastActivatedApp?.localizedName ?? "?")  before=\(before)  after=\(shortIds(ordering))")
		update()
	}

	func handleAppQuit(runningApp: NSRunningApplication) {
		// DEBUG: snapshot ordering before/after the removal.
		let before = shortIds(ordering)
		let runningApp = RunningApp(app: runningApp) // to get id
		self.ordering.removeAll(where: { $0 == runningApp.id })
		DebugLog.shared.log("[ordering] handleAppQuit removed id-tail=\(shortId(runningApp.id))  before=\(before)  after=\(shortIds(ordering))")
		update()
	}

	private func populateApps() {
		if limit == 0 {
			apps = [] // for efficiency
			return
		}

		// Apps with no known ordering info must land on the OLDEST / least-recent
		// side so they (a) never steal the newest-app slot and (b) are the first
		// to be dropped by the limit (bug fix, voice 4442). Which physical array
		// end that is depends on the truncation direction used in limitNumApps():
		//   - .mostRecentOnRight uses suffix(limit) (keeps the END), and the
		//     array is least->most recent, so oldest == array START.
		//   - .mostRecentOnLeft uses prefix(limit) (keeps the FRONT), and
		//     correctedOrdering() is reversed to most->least recent, so oldest
		//     == array END.
		let newApps = NSWorkspace.shared.runningApplications
			.map { RunningApp(app: $0) }
			.filter {canShowRunningApp(app: $0)}
			.reorder(by: correctedOrdering(), unorderedGoTo: unorderedPlacement())
		apps = Array(limitNumApps(apps: newApps))

		// DEBUG: log the FINAL shown apps (in left->right display order), the
		// limit, and the sorting method, so "why is the order / set wrong" is
		// answerable straight from the log. Note `apps` here is least->most
		// recent internally; OpenableApps lays it out left->right per side pref.
		let methodStr: String
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight: methodStr = "mostRecentOnRight"
		case .mostRecentOnLeft: methodStr = "mostRecentOnLeft"
		case .consistent: methodStr = "consistent"
		}
		DebugLog.shared.log("[populate] shown(\(apps.count)/limit \(limit)) method=\(methodStr): \(apps.map { shortId($0.id) })")
	}

	private func canShowRunningApp(app: RunningApp) -> Bool {
		// Each early-return logs WHY an app was excluded so a "missing app X"
		// report is answerable from the log. Cheap: only the excluded path logs.
		if app.app.activationPolicy != .regular {
			// Don't log Menu Bar Dock excluding itself / the dozens of system
			// accessory processes on every populate — too noisy. The activation
			// log already captures accessory ACTIVATIONS, which is what matters.
			return false
		}
		if app.app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDataSource.hideFinderFromRunningApps {
			DebugLog.shared.log("[exclude] Finder (rule: hide-finder)")
			return false
		}
		if userPrefsDataSource.hideActiveAppFromRunningApps == false {return true}
		// Hide-active-app path (DEFAULT on). Compare against lastActivatedApp (captured
		// from the activation-notification payload) rather than reading
		// NSWorkspace.shared.frontmostApplication live here. populateApps() typically
		// runs synchronously off the activation notification, and on macOS 14+
		// cooperative activation frontmostApplication may not yet reflect the app that
		// just activated — a live read could hide the wrong app. Fall back to
		// frontmostApplication only before the first activation has been observed
		// (lastActivatedApp == nil), e.g. the initial populateApps() at launch.
		let activeApp = lastActivatedApp ?? NSWorkspace.shared.frontmostApplication
		let shown = (app.app != activeApp)
		if !shown {
			// This app is the one we consider "active" so it's hidden. Logging the
			// SOURCE of the active-app truth (notification payload vs the
			// frontmostApplication fallback) is key for diagnosing the residual
			// accessory-staleness edge: if activeApp came from a stale
			// lastActivatedApp, the WRONG app gets hidden here.
			let src = lastActivatedApp != nil ? "lastActivatedApp" : "frontmostApplication(fallback)"
			DebugLog.shared.log("[exclude] \(app.app.localizedName ?? "?") (rule: hide-active-app; active=\(activeApp?.localizedName ?? "?") via \(src))")
		}
		return shown
	}

	// MARK: - Debug helpers (readable ids in the log)

	// The "id" is bundleURL.absoluteString (a long file:// URL). For logs we only
	// want a short, human-recognisable tail — the .app bundle name — so lines
	// stay scannable. Falls back to the raw id if we can't extract a tail.
	private func shortId(_ id: String) -> String {
		guard let url = URL(string: id) else { return id }
		return url.deletingPathExtension().lastPathComponent // e.g. "Safari"
	}

	private func shortIds(_ ids: [String]) -> String {
		"[" + ids.map { shortId($0) }.joined(separator: ", ") + "]"
	}

	private func correctedOrdering() -> [String] {
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			return ordering
		case .mostRecentOnLeft:
			return ordering.reversed()
		case .consistent:
			return ordering.sorted {$0 < $1} // fixed alphabetical ordering
		}
	}

	// Mirrors the truncation direction in limitNumApps() so un-ordered apps are
	// pushed to whichever array end is BOTH the least-recent side and the side
	// that gets truncated first. See the comment block in populateApps().
	private func unorderedPlacement() -> UnorderedPlacement {
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			return .start // suffix(limit) keeps the end; oldest is the start
		case .mostRecentOnLeft:
			return .end   // prefix(limit) keeps the front; oldest is the end
		case .consistent:
			return .start // alphabetical; truncates with suffix, so match .mostRecentOnRight
		}
	}

	private func limitNumApps(apps: [RunningApp]) -> ArraySlice<RunningApp> {
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			return apps.suffix(limit)
		case .mostRecentOnLeft:
			return apps.prefix(limit)
		default:
			return apps.suffix(limit) // doesn't matter for this, because it doesn't really make sense anyway
		}
	}
}

enum RunningAppsSortingMethod: Int {
	case mostRecentOnRight = 0
	case mostRecentOnLeft = 1
	case consistent = 2
}

enum SideToShowRunningApps: String {
	case left = "left"
	case right = "right"
}
