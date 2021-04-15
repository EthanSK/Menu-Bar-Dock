//
//  OpenableApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol OpenableAppsUserPrefsDataSource: AnyObject {
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

	func update(runningApps: RunningApps, regularApps: RegularApps) {
		self.runningApps = runningApps
		self.regularApps = regularApps
		populateApps()
	}

	private func populateApps() {
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
 	}

	private func populateAppsWithRunningApps() {
		for runningApp in runningApps.apps {
			if (
				userPrefsDataSource.hideDuplicateApps &&
				userPrefsDataSource.duplicateAppsPriority == .regularApps &&
				regularApps.apps.contains(where: {$0.id == runningApp.id})
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
