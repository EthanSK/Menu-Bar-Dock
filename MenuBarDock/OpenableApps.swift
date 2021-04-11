//
//  OpenableApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol OpenableAppsUserPrefsDelegate: AnyObject {
	
}

class OpenableApps {
	var apps: [OpenableApp]
	
	init() {
		apps = []
	}
	
	func add(app: OpenableApp) {
		apps.append(app)
	}
	
	func remove(app: OpenableApp) {
//		apps.removeAll(app)
	}
	
	private func runningApps() -> [NSRunningApplication]{
		return NSWorkspace.shared.runningApplications.filter {canShowRunningApp(app: $0)}
	}
	
	func canShowRunningApp(app: NSRunningApplication) -> Bool {
		if app.activationPolicy != .regular {return false}
		if app.bundleIdentifier == Constants.App.finderBundleId {return !MenuBarDock.shared.userPrefs.hideFinderFromRunningApps}
		if MenuBarDock.shared.userPrefs.hideActiveAppFromRunningApps == false {return true} else {return app != NSWorkspace.shared.frontmostApplication}
	}
}

