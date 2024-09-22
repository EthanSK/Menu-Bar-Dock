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
        static let releasesURL = "https://github.com/EthanSK/Menu-Bar-Dock/releases"
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
        static let appIconSize = "appIconSize"
        static let appOpeningMethods = "appOpeningMethods"
        static let defaultAppOpeningMethod = "defaultAppOpeningMethod"
        static let duplicateAppsPriority = "duplicateAppsPriority"
        static let hideActiveAppFromRunningApps = "hideActiveAppFromRunningApps"
        static let hideDuplicateApps = "hideDuplicateApps"
        static let hideFinderFromRunningApps = "hideFinderFromRunningApps"
        static let launchAtLogin = "launchAtLogin"
		static let maxNumRunningApps = "maxNumRunningApps"
        static let preserveAppOrder = "preserveAppOrder"
        static let regularAppsUrls = "regularAppsUrls"
        static let rightClickByDefault = "rightClickByDefault"
        static let runningAppsSortingMethod = "runningAppsSortingMethod"
        static let sideToShowRunningApps = "sideToShowRunningApps"
		static let statusItemWidth = "statusItemWidth"
	}
}
