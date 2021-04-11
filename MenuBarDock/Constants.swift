//
//  Constants.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum Constants {
	enum App {
		static let name = "Menu Bar Dock"
		static let launcherBundleId = "com.ethansk.MenuBarDockLauncher"
		static let finderBundleId = "com.apple.finder"
	}

	enum UserDefaultsKeys {
		static let bundleId = "bundleId"
	}

	enum ViewControllerIdentifiers {
		static let preferences = "PreferencesViewController"
	}

	enum UserPrefs {
		static let maxNumRunningApps = "maxNumRunningApps"
		static let statusItemWidth = "statusItemWidth"
		static let runningAppsSortingMethod = "runningAppsSortingMethod"
		static let appIconSize = "appIconSize"
		static let launchAtLogin = "launchAtLogin"
		static let defaultAppOpeningMethod = "defaultAppOpeningMethod"
		static let appOpeningMethods = "appOpeningMethods"
		static let hideActiveAppFromRunningApps = "hideActiveAppFromRunningApps"
		static let hideFinderFromRunningApps = "hideFinderFromRunningApps"
	}
}

enum runningAppsSortingMethod: Int {
	case mostRecentOnRight = 0// newest active app on right
	case mostRecentOnLeft = 1
	case consistent = 2
}
