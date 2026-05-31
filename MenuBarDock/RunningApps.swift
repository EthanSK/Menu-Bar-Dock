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
		let runningApp = RunningApp(app: runningApp) // to get id
		self.ordering.removeAll(where: { $0 == runningApp.id })
		self.ordering.append(runningApp.id) // needs this order for it to populate from the most helpful side correctly
		update()
	}

	func handleAppQuit(runningApp: NSRunningApplication) {
		let runningApp = RunningApp(app: runningApp) // to get id
		self.ordering.removeAll(where: { $0 == runningApp.id })
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
	}

	private func canShowRunningApp(app: RunningApp) -> Bool {
		if app.app.activationPolicy != .regular {return false}
		if app.app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDataSource.hideFinderFromRunningApps {return false}
		if userPrefsDataSource.hideActiveAppFromRunningApps == false {return true} else {return app.app != NSWorkspace.shared.frontmostApplication}
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
