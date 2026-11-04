//
//  OpenableApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol OpenableAppsUserPrefsDataSource: AnyObject {
	func iconOverride(forAppAt url: URL) -> NSImage?
	var appOpeningMethods: [String: AppOpeningMethod] { get }
	var hideFinderFromRunningApps: Bool { get }
	var hideActiveAppFromRunningApps: Bool { get }
	var defaultAppOpeningMethod: AppOpeningMethod { get }
	var sideToShowRunningApps: SideToShowRunningApps { get }
	var hideDuplicateApps: Bool { get }
	var duplicateAppsPriority: DuplicateAppsPriority { get }
}

class OpenableApps {
	public var apps: [OpenableApp] = [] // ground truth for all apps to show, both running and non running, ordered left to right

	public weak var userPrefsDataSource: OpenableAppsUserPrefsDataSource!

 	private var runningApps: RunningApps
	private var regularApps: RegularApps

	init(
		userPrefsDataSource: OpenableAppsUserPrefsDataSource,
		runningApps: RunningApps,
		regularApps: RegularApps
 	) {
 		self.userPrefsDataSource = userPrefsDataSource
		self.runningApps = runningApps
		self.regularApps = regularApps

		populateApps()
	}

	func update(runningApps: RunningApps, regularApps: RegularApps, runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications) {
		self.runningApps = runningApps
		self.regularApps = regularApps
		populateApps(runningApplications: runningApplications)
	}

	private func populateApps(runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications) {
		apps = []

		// running and regular apps are already ordered internally
		switch userPrefsDataSource.sideToShowRunningApps {
		case .left:
			populateAppsWithRunningApps()
			populateAppsWithRegularApps()
		case .right:
			populateAppsWithRegularApps()
			populateAppsWithRunningApps()
		}
		// During a quit notification macOS can still list the exited process.
		// Counting it leaves an "instance 1" badge until another app event refreshes us.
		let runningApplications = runningApplications.filter { !$0.isTerminated && $0.activationPolicy == .regular }
		for app in apps { // Apply overrides after combining both sections so duplicate priority cannot bring back the original icon.
			if let icon = userPrefsDataSource.iconOverride(forAppAt: app.bundleUrl) {
				app.icon = icon
			}
			if let bundleId = app.bundleId, let runningApplication = app.runningApplication {
				let instances = runningApplications.filter { $0.bundleIdentifier == bundleId }.sorted { lhs, rhs in // Number the full running set by launch time, so activation and hidden entries cannot swap badges; PIDs can wrap around.
					let lhsLaunchDate = lhs.launchDate ?? .distantPast // macOS can omit a launch date; place unknown dates first and use PID to give them a deterministic order.
					let rhsLaunchDate = rhs.launchDate ?? .distantPast
					return lhsLaunchDate == rhsLaunchDate ? lhs.processIdentifier < rhs.processIdentifier : lhsLaunchDate < rhsLaunchDate
				}
				if instances.count > 1, let index = instances.firstIndex(where: { $0.processIdentifier == runningApplication.processIdentifier }) {
					app.instanceNumber = index + 1
				}
			}
		}
 	}

	private func populateAppsWithRunningApps() {
		for runningApp in runningApps.apps {
			if (
				userPrefsDataSource.hideDuplicateApps &&
				userPrefsDataSource.duplicateAppsPriority == .regularApps &&
				regularApps.apps.contains(where: {$0.id == runningApp.id && $0.runningApp?.processIdentifier == runningApp.app.processIdentifier}) // Hide the process represented by the pinned entry, while retaining other numbered instances.
			) { continue }

			guard let openableApp = try? OpenableApp(
				runningApp: runningApp,
				appOpeningMethod: userPrefsDataSource.appOpeningMethods[runningApp.id] ?? userPrefsDataSource.defaultAppOpeningMethod
			) else { continue }

			apps.append(openableApp)
		}
	}

	private func populateAppsWithRegularApps() {
		for regularApp in regularApps.apps {
			if (
				userPrefsDataSource.hideDuplicateApps &&
				userPrefsDataSource.duplicateAppsPriority == .runningApps &&
				runningApps.apps.contains(where: {$0.id == regularApp.id})
			) { continue }

			let openableApp = OpenableApp(
				regularApp: regularApp,
				appOpeningMethod: userPrefsDataSource.appOpeningMethods[regularApp.id] ?? userPrefsDataSource.defaultAppOpeningMethod
			)
			apps.append(openableApp)
		}
	}
}

enum UpdateRegularAppWithRunningAppType {
	case add
	case remove
}

enum DuplicateAppsPriority: String {
	case runningApps = "runningApps"
	case regularApps = "regularApps"
}
