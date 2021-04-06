//
//  Constants.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum Constants {
	enum App{
		static let name = "Menu Bar Dock"
		static let launcherBundleId = "com.ethansk.MenuBarDockLauncher"
	}
	
	enum NSUserDefaultsKeys{
		static let bundleId = "bundleId"
	}
	
	enum UserPrefs{
		static let numberOfStatusItems = "numberOfStatusItems"
		static let widthOfStatusItem = "widthOfStatusItem"
		static let sortingMethod = "sortingMethod"
		static let iconSize = "iconSize"
		static let launchAtLogin = "launchAtLogin"
		static let launchInsteadOfActivate = "launchInsteadOfActivate"
		static let launchInsteadOfActivateIndivApps = "launchInsteadOfActivateIndivApps"
		static let hideActiveApp = "hideActiveApp"
		static let hideFinder = "hideFinder"
	}
}

enum SortingMethod: Int{
	case mostRecentOnRight = 0//newest active app on right
	case mostRecentOnLeft = 1
	case consistent = 2
}
