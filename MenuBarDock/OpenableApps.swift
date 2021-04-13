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

}

protocol OpenableAppsDelegate: AnyObject {
	func appsDidChange()
 }

class OpenableApps {
	public var apps: [OpenableApp] = [] // ground truth for all apps to show, both running and non running, ordered left to right

	public weak var userPrefsDataSource: OpenableAppsUserPrefsDataSource!
	public weak var delegate: OpenableAppsDelegate?

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
		runningApps.delegate = self

		populateApps()
	}

	private func populateApps() {
		apps = []

		for regularApp in regularApps.apps {
			guard let openableApp = try? OpenableApp(
				regularApp: regularApp
			) else { continue }
			apps.append(openableApp)
		}

		for runningApp in runningApps.apps {
			guard let bundleId = runningApp.bundleIdentifier else { continue }

			guard let openableApp = try? OpenableApp(
				runningApp: runningApp,
				appOpeningMethod: userPrefsDataSource.appOpeningMethods[bundleId] ?? UserPrefsDefaultValues.defaultAppOpeningMethod
			) else { continue }
			apps.append(openableApp)
		}

		apps = apps.reorder(by: appsOrder())
		delegate?.appsDidChange()
	}

	private func appsOrder() -> [String] {
		// here we combine the order arrays of running and non running apps in a way determined by user prefs to get the final app order array
		return runningApps.ordering // TODO: - change this to be correct
	}
}

extension OpenableApps: RunningAppsDelegate {
	func runningAppWasActivated(_ runningApp: NSRunningApplication) {
		populateApps()
	}

	func runningAppWasQuit(_ runningApp: NSRunningApplication) {
		populateApps()
	}
}
