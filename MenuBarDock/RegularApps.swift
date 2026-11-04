//
//  RegularApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 12/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol RegularAppsUserPrefsDataSource: AnyObject {
	var regularAppsUrls: [URL] { get }
}

class RegularApps { // regular apps are just apps that use user added manually
	public var apps: [RegularApp]  = [] // order is correct

	weak var userPrefsDataSource: RegularAppsUserPrefsDataSource!

	init(
		userPrefsDataSource: RegularAppsUserPrefsDataSource
	) {
		self.userPrefsDataSource = userPrefsDataSource
		populateApps()
	}

	func update(runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications) {
		populateApps(runningApplications: runningApplications)
	}

	func handleAppActivation(runningApp: NSRunningApplication) {
		correspondingRegularApp(for: runningApp)?.runningApp = runningApp
		// we DON'T want to update here, because it doesn't make sense to update regular apps based on app activations, otherwise they would be RunningApp()s!
	}

	/// Keeps the pinned entry bound to a remaining instance when its current process exits.
	func handleAppQuit(runningApp: NSRunningApplication) {
		guard let regularApp = correspondingRegularApp(for: runningApp), regularApp.runningApp?.processIdentifier == runningApp.processIdentifier else { return }
		regularApp.runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier != runningApp.processIdentifier && !$0.isTerminated && RunningApp(app: $0).id == regularApp.id } // Quitting one instance must not mark the whole app as stopped when another instance remains.
	}

	private func correspondingRegularApp(for runningApp: NSRunningApplication) -> RegularApp? {
		return apps.first { $0.id == RunningApp(app: runningApp).id} // we just use RunningApp() just to get the id...kinda hacky
	}

	private func populateApps(runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications) {
		apps = []
		for url in userPrefsDataSource.regularAppsUrls {
			if let app = regularApp(for: url) {
				apps.append(app)
			}
		}
		addRunningApps(runningApplications: runningApplications)
	}

	private func regularApp(for url: URL) -> RegularApp? {
		guard let bundle = Bundle(url: url) else { return nil }

		let icon = NSWorkspace.shared.icon(forFile: url.path)

		let app = RegularApp(
			bundle: bundle,
			icon: icon,
			name: bundle.name
		)

		return app
	}

	private func addRunningApps(runningApplications: [NSRunningApplication]) {
		let runningApps = runningApplications.filter { !$0.isTerminated } // Match the quit-rebinding guard: pinned entries must target a live process.
		for app in apps {
			app.runningApp = runningApps.first {RunningApp(app: $0).id == app.id} // we instantiate RunningApp just to get id. kinda hacky, but oh well.
		}
	}
}
