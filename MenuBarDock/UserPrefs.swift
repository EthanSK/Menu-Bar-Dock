//
//  UserPrefs.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum UserPrefsDefaultValues {
	static let maxNumRunningApps = 15
	static let statusItemWidth = CGFloat(30)
	static let runningAppsSortingMethod: RunningAppsSortingMethod = .mostRecentOnRight
	static let appIconSize: CGFloat = 21
	static let launchAtLogin = true
	static let defaultAppOpeningMethod = AppOpeningMethod.launch
	static let appOpeningMethods: [String: AppOpeningMethod] = [:] // bundleId is key
	static let hideActiveAppFromRunningApps = true
	static let hideFinderFromRunningApps = false
}

class UserPrefs {
	var maxNumRunningApps = UserPrefsDefaultValues.maxNumRunningApps // make it go up really high so user has freedom if the have a very large long screen
	var statusItemWidth = UserPrefsDefaultValues.statusItemWidth
	var runningAppsSortingMethod: RunningAppsSortingMethod = UserPrefsDefaultValues.runningAppsSortingMethod
	var appIconSize: CGFloat = UserPrefsDefaultValues.appIconSize
	var launchAtLogin = UserPrefsDefaultValues.launchAtLogin
	var defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
	var appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
	var hideActiveAppFromRunningApps = UserPrefsDefaultValues.hideActiveAppFromRunningApps
	var hideFinderFromRunningApps = UserPrefsDefaultValues.hideFinderFromRunningApps

	func resetToDefaults() { // cba about this shitty code tbh not worth my time
		maxNumRunningApps =  UserPrefsDefaultValues.maxNumRunningApps // make it go up really high so user has freedom if the have a very large long screen
		statusItemWidth = UserPrefsDefaultValues.statusItemWidth
		runningAppsSortingMethod = UserPrefsDefaultValues.runningAppsSortingMethod
		appIconSize = UserPrefsDefaultValues.appIconSize
		defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
		hideActiveAppFromRunningApps = UserPrefsDefaultValues.hideActiveAppFromRunningApps
		hideFinderFromRunningApps = UserPrefsDefaultValues.hideFinderFromRunningApps

		save()
	}
	func resetIndivAppSettingsToDefaults() {
		appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
	}

	func save() {
		UserDefaults.standard.set(maxNumRunningApps, forKey: Constants.UserPrefs.maxNumRunningApps)
		UserDefaults.standard.set(statusItemWidth, forKey: Constants.UserPrefs.statusItemWidth)
		UserDefaults.standard.set(runningAppsSortingMethod.rawValue, forKey: Constants.UserPrefs.runningAppsSortingMethod)
		UserDefaults.standard.set(appIconSize, forKey: Constants.UserPrefs.appIconSize)
		UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserPrefs.launchAtLogin)
		UserDefaults.standard.set(defaultAppOpeningMethod.rawValue, forKey: Constants.UserPrefs.defaultAppOpeningMethod)
		UserDefaults.standard.set(
			Dictionary(uniqueKeysWithValues:
					appOpeningMethods.map({ key, value in (key, value.rawValue)
		})), forKey: Constants.UserPrefs.appOpeningMethods)
		UserDefaults.standard.set(hideActiveAppFromRunningApps, forKey: Constants.UserPrefs.hideActiveAppFromRunningApps)
		UserDefaults.standard.set(hideFinderFromRunningApps, forKey: Constants.UserPrefs.hideFinderFromRunningApps)

	}

	func load() {
		if let maxNumRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.maxNumRunningApps) as? Int {
			self.maxNumRunningApps = maxNumRunningApps
		}

		if let statusItemWidth = UserDefaults.standard.object(forKey: Constants.UserPrefs.statusItemWidth) as? CGFloat {
			self.statusItemWidth = statusItemWidth
		}

		if let runningAppsSortingMethodInt = UserDefaults.standard.object(forKey: Constants.UserPrefs.runningAppsSortingMethod) as? Int, let runningAppsSortingMethod = RunningAppsSortingMethod(rawValue: runningAppsSortingMethodInt) {
			self.runningAppsSortingMethod = runningAppsSortingMethod
		}

		if let appIconSize = UserDefaults.standard.object(forKey: Constants.UserPrefs.appIconSize) as? CGFloat {
			self.appIconSize = appIconSize
		}

		if let launchAtLogin = UserDefaults.standard.object(forKey: Constants.UserPrefs.launchAtLogin) as? Bool {
			self.launchAtLogin = launchAtLogin
		}
		if let defaultAppOpeningMethod = UserDefaults.standard.object(forKey: Constants.UserPrefs.defaultAppOpeningMethod) as? String {
			self.defaultAppOpeningMethod = AppOpeningMethod(rawValue: defaultAppOpeningMethod) ?? UserPrefsDefaultValues.defaultAppOpeningMethod
		}
		if let appOpeningMethods = UserDefaults.standard.object(forKey: Constants.UserPrefs.appOpeningMethods) as? [String: String] {
			self.appOpeningMethods = Dictionary(uniqueKeysWithValues:
				appOpeningMethods.map({ key, value in
				(key, AppOpeningMethod(rawValue: value) ?? UserPrefsDefaultValues.defaultAppOpeningMethod)
			}))
		}
		if let hideActiveAppFromRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideActiveAppFromRunningApps) as? Bool {
			self.hideActiveAppFromRunningApps = hideActiveAppFromRunningApps
		}
		if let hideFinderFromRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideFinderFromRunningApps) as? Bool {
			self.hideFinderFromRunningApps = hideFinderFromRunningApps
		}
	}
}

extension UserPrefs: MenuBarItemsUserPrefsDelegate {
	func didSetAppOpeningMethod(_ method: AppOpeningMethod, _ app: OpenableApp) {
		appOpeningMethods[app.bundleId] = method
		save()
	}
}

extension UserPrefs: OpenableAppsUserPrefsDelegate {

}
