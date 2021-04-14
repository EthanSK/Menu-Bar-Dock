//
//  RegularApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 12/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class RegularApps { // regular apps are just apps that use user added manually
	public var apps: [RegularApp]  = [] // order is correct

	init() {
		populateApps()
	}

	func update() {
		// update for user preference change for example
		populateApps()
	}

	private func populateApps() {
//		let path = "/System/Applications/Mail.app"
//
//		if let regularApp = regularApp(for: path) {
//			apps.append(regularApp)
//		}
 	}

	private func regularApp(for path: String) -> RegularApp? {
		guard let bundle = Bundle(url: URL(fileURLWithPath: path)) else { return nil}

		guard let name =
				bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ??
				bundle.infoDictionary?[kCFBundleNameKey as String] as? String
		else { return nil }

		let icon = NSWorkspace.shared.icon(forFile: path)

		let app = RegularApp(
			path: path,
			bundle: bundle,
			icon: icon,
			name: name
		)

		return app
	}

}
