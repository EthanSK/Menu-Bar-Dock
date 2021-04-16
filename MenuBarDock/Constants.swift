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
		static let regularAppsSectionTitle = "Regular Apps"
		static let runningAppsSectionTitle = "Running Apps"
	}

	enum UserDefaultsKeys {
		static let bundleId = "bundleId"
	}

	enum Identifiers {
		enum ViewControllers {
			static let preferences = "PreferencesViewController"
			static let about = "AboutViewController"
			static let info = "InfoViewController"

		}

		enum WindowControllers {
			static let info = "InfoWindowController"
			static let about = "AboutWindowController"
		}

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
		static let regularAppsUrls = "regularAppsUrls"
		static let sideToShowRunningApps = "sideToShowRunningApps"
		static let hideDuplicateApps = "hideDuplicateApps"
		static let duplicateAppsPriority = "duplicateAppsPriority"
	}
}
