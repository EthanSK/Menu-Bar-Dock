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

}
