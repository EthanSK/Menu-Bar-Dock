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
		let previousApps = apps
		let liveProcesses = runningApplications.filter { !$0.isTerminated }
		apps = userPrefsDataSource.regularAppsUrls.compactMap { url in
			guard let app = regularApp(for: url) else { return nil }
			let matches = liveProcesses.filter { RunningApp(app: $0).id == app.id }
			let previousPID = previousApps.first { $0.id == app.id }?.runningApp?.processIdentifier
			app.runningApp = matches.first { $0.processIdentifier == previousPID } ?? matches.first // A background launch or preferences refresh must preserve the pinned app's selected instance while it is still running.
			return app
		}
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
}
