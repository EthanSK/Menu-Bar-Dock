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
		addRunningApps() // only need to do this in init, updates to activated and quitted apps will be done in openable apps delegate. a bit confusing, but much less code for a small feature.
	}

	func update() {
		// update for user preference change for example
		populateApps()
	}

	private func populateApps() {
		apps = []
		for url in userPrefsDataSource.regularAppsUrls {
			if let app = regularApp(for: url) {
				apps.append(app)
			}
		}
 	}

	private func regularApp(for url: URL) -> RegularApp? {
		guard let bundle = Bundle(url: url) else { return nil}

		let icon = NSWorkspace.shared.icon(forFile: url.path)

		let app = RegularApp(
			bundle: bundle,
			icon: icon,
			name: bundle.name
		)

		return app
	}

	private func addRunningApps() {
		let runningApps = NSWorkspace.shared.runningApplications
		for app in apps {
			app.runningApp = runningApps.first {RunningApp(app: $0).id == app.id} // we instantiate RunningApp just to get id. kinda hacky, but oh well.
		}
	}

}
