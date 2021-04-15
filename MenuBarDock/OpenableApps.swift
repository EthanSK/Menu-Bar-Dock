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

	func update() {
		runningApps.update()
		regularApps.update()
		populateApps()
	}

	private func populateApps() {
		apps = []

		// running and regular apps are already ordered internally, we just need to append them correctly.
		// TODO: swap the order we populate depending on the user pref.
		populateAppsWithRegularApps()
		populateAppsWithRunningApps()

		delegate?.appsDidChange()
	}

	private func populateAppsWithRunningApps() {
		for runningApp in runningApps.apps {
			guard let openableApp = try? OpenableApp(
				runningApp: runningApp
			) else { continue }
			openableApp.appOpeningMethod = userPrefsDataSource.appOpeningMethods[openableApp.id] ?? userPrefsDataSource.defaultAppOpeningMethod
			apps.append(openableApp)
		}
	}

	private func populateAppsWithRegularApps() {
		for regularApp in regularApps.apps {
			let openableApp = OpenableApp(
				regularApp: regularApp,
				runningApp: regularApp.runningApp
			)
			apps.append(openableApp)
		}
	}

	private func updateRegularApp(with runningApp: NSRunningApplication, updateType: UpdateRegularAppWithRunningAppType) {
		let regularApp = regularApps.apps.first { $0.id == RunningApp(app: runningApp).id} // we just use RunningApp() to get the id...kinda hacky
		switch updateType {
		case .add:
			regularApp?.runningApp = runningApp
		case .remove:
			regularApp?.runningApp = nil
		}
	}
}

extension OpenableApps: RunningAppsDelegate {
	func runningAppWasActivated(_ runningApp: NSRunningApplication) {
		updateRegularApp(with: runningApp, updateType: .add) // doing this here is kinda a hack, the right way would be to track the activations in regularApps, but for such a small feature, it's not worth duplicating all that code when its just as easy as this
		populateApps()
	}

	func runningAppWasQuit(_ runningApp: NSRunningApplication) {
		updateRegularApp(with: runningApp, updateType: .remove)
		populateApps()
	}
}

enum UpdateRegularAppWithRunningAppType {
	case add
	case remove
}
