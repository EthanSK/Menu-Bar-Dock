//
//  UserPrefs.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum UserPrefsDefaultValues {
    static let appIconSize: CGFloat = 40
    static let appOpeningMethods: [String: AppOpeningMethod] = [:] // openableApp id is the key
    static let defaultAppOpeningMethod = AppOpeningMethod.launch
    static let duplicateAppsPriority: DuplicateAppsPriority = .runningApps
    static let hideActiveAppFromRunningApps = true
    static let hideDuplicateApps = true
    static let hideFinderFromRunningApps = false
    static let launchAtLogin = true
    static let maxNumRunningApps = 10 // We need to show some apps when the user first open Menu Bar Dock, or it will be an instant turn off.
    static let preserveAppOrder = true
	static let regularAppsUrls: [URL] = []
    static let rightClickByDefault = false
    static let sideToShowRunningApps: SideToShowRunningApps = .right
    static let statusItemWidth = CGFloat(30)
    static let runningAppsSortingMethod: RunningAppsSortingMethod = .mostRecentOnRight
}

class UserPrefs {
    var appIconSize: CGFloat = UserPrefsDefaultValues.appIconSize
    var appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
    var defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
    var duplicateAppsPriority = UserPrefsDefaultValues.duplicateAppsPriority
    var hideActiveAppFromRunningApps = UserPrefsDefaultValues.hideActiveAppFromRunningApps
    var hideDuplicateApps = UserPrefsDefaultValues.hideDuplicateApps
    var hideFinderFromRunningApps = UserPrefsDefaultValues.hideFinderFromRunningApps
    var launchAtLogin = UserPrefsDefaultValues.launchAtLogin
    var maxRunningApps = UserPrefsDefaultValues.maxNumRunningApps // make it go up really high so user has freedom if the have a very large long screen
    var preserveAppOrder = UserPrefsDefaultValues.preserveAppOrder
    var regularAppsUrls = UserPrefsDefaultValues.regularAppsUrls
    var rightClickByDefault = UserPrefsDefaultValues.rightClickByDefault
    var runningAppsSortingMethod: RunningAppsSortingMethod = UserPrefsDefaultValues.runningAppsSortingMethod
    var sideToShowRunningApps = UserPrefsDefaultValues.sideToShowRunningApps
    var itemSlotWidth = UserPrefsDefaultValues.statusItemWidth

	func resetToDefaults() { // cba about this shitty code tbh not worth my time
        appIconSize = UserPrefsDefaultValues.appIconSize
        defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
        duplicateAppsPriority = UserPrefsDefaultValues.duplicateAppsPriority
        hideActiveAppFromRunningApps = UserPrefsDefaultValues.hideActiveAppFromRunningApps
        hideDuplicateApps = UserPrefsDefaultValues.hideDuplicateApps
        hideFinderFromRunningApps = UserPrefsDefaultValues.hideFinderFromRunningApps
        maxRunningApps =  UserPrefsDefaultValues.maxNumRunningApps // make it go up really high so user has freedom if the have a very large long screen
        preserveAppOrder = UserPrefsDefaultValues.preserveAppOrder
        // don't reset regularAppsUrls, it's not right
        rightClickByDefault = UserPrefsDefaultValues.rightClickByDefault
        runningAppsSortingMethod = UserPrefsDefaultValues.runningAppsSortingMethod
        sideToShowRunningApps = UserPrefsDefaultValues.sideToShowRunningApps
        itemSlotWidth = UserPrefsDefaultValues.statusItemWidth
		save()
	}

	func resetAppOpeningMethodsToDefaults() {
		appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
	}

	func save() {
        UserDefaults.standard.set(appIconSize, forKey: Constants.UserPrefs.appIconSize)
        UserDefaults.standard.set(
            Dictionary(uniqueKeysWithValues:
                    appOpeningMethods.map({ key, value in (key, value.rawValue)
        })), forKey: Constants.UserPrefs.appOpeningMethods)
        UserDefaults.standard.set(defaultAppOpeningMethod.rawValue, forKey: Constants.UserPrefs.defaultAppOpeningMethod)
        UserDefaults.standard.set(duplicateAppsPriority.rawValue, forKey: Constants.UserPrefs.duplicateAppsPriority)
        UserDefaults.standard.set(hideActiveAppFromRunningApps, forKey: Constants.UserPrefs.hideActiveAppFromRunningApps)
        UserDefaults.standard.set(hideDuplicateApps, forKey: Constants.UserPrefs.hideDuplicateApps)
        UserDefaults.standard.set(hideFinderFromRunningApps, forKey: Constants.UserPrefs.hideFinderFromRunningApps)
        UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserPrefs.launchAtLogin)
		UserDefaults.standard.set(maxRunningApps, forKey: Constants.UserPrefs.maxNumRunningApps)
        UserDefaults.standard.set(preserveAppOrder, forKey: Constants.UserPrefs.preserveAppOrder)
        UserDefaults.standard.set(regularAppsUrls.map { $0.absoluteString }, forKey: Constants.UserPrefs.regularAppsUrls)
        UserDefaults.standard.set(rightClickByDefault, forKey: Constants.UserPrefs.rightClickByDefault)
        UserDefaults.standard.set(runningAppsSortingMethod.rawValue, forKey: Constants.UserPrefs.runningAppsSortingMethod)
        UserDefaults.standard.set(sideToShowRunningApps.rawValue, forKey: Constants.UserPrefs.sideToShowRunningApps)
		UserDefaults.standard.set(itemSlotWidth, forKey: Constants.UserPrefs.statusItemWidth)
	}

	func load() {
        if let appIconSize = UserDefaults.standard.object(forKey: Constants.UserPrefs.appIconSize) as? CGFloat {
            self.appIconSize = appIconSize
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

        if let duplicateAppsPriority = UserDefaults.standard.object(forKey: Constants.UserPrefs.duplicateAppsPriority) as? String {
            self.duplicateAppsPriority = DuplicateAppsPriority(rawValue: duplicateAppsPriority) ?? UserPrefsDefaultValues.duplicateAppsPriority
        }

        if let hideActiveAppFromRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideActiveAppFromRunningApps) as? Bool {
            self.hideActiveAppFromRunningApps = hideActiveAppFromRunningApps
        }

        if let hideDuplicateApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideDuplicateApps) as? Bool {
            self.hideDuplicateApps = hideDuplicateApps
        }

        if let hideFinderFromRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideFinderFromRunningApps) as? Bool {
            self.hideFinderFromRunningApps = hideFinderFromRunningApps
        }

        if let launchAtLogin = UserDefaults.standard.object(forKey: Constants.UserPrefs.launchAtLogin) as? Bool {
            self.launchAtLogin = launchAtLogin
        }

		if let maxNumRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.maxNumRunningApps) as? Int {
			self.maxRunningApps = maxNumRunningApps
		}

        if let preserveAppOrder = UserDefaults.standard.object(forKey: Constants.UserPrefs.preserveAppOrder) as? Bool {
            self.preserveAppOrder = preserveAppOrder
        }

        if let regularAppsUrlsStrs = UserDefaults.standard.object(forKey: Constants.UserPrefs.regularAppsUrls) as? [String] {
            var res: [URL] = []
            for urlStr in regularAppsUrlsStrs {
                if let url = URL(string: urlStr) {
                    res.append(url)
                }
            }
            self.regularAppsUrls = res
         }

        if let rightClickByDefault = UserDefaults.standard.object(forKey: Constants.UserPrefs.rightClickByDefault) as? Bool {
            self.rightClickByDefault = rightClickByDefault
        }

        if let runningAppsSortingMethodInt = UserDefaults.standard.object(forKey: Constants.UserPrefs.runningAppsSortingMethod) as? Int, let runningAppsSortingMethod = RunningAppsSortingMethod(rawValue: runningAppsSortingMethodInt) {
            self.runningAppsSortingMethod = runningAppsSortingMethod
        }

        if let sideToShowRunningApps = UserDefaults.standard.object(forKey: Constants.UserPrefs.sideToShowRunningApps) as? String {
            self.sideToShowRunningApps = SideToShowRunningApps(rawValue: sideToShowRunningApps) ?? UserPrefsDefaultValues.sideToShowRunningApps
        }

		if let statusItemWidth = UserDefaults.standard.object(forKey: Constants.UserPrefs.statusItemWidth) as? CGFloat {
			self.itemSlotWidth = statusItemWidth
		}
	}
}

extension UserPrefs: MenuBarItemsUserPrefsDataSource {}

extension UserPrefs: OpenableAppsUserPrefsDataSource {}

extension UserPrefs: RunningAppsUserPrefsDataSource {}

extension UserPrefs: PreferencesViewControllerUserPrefsDataSource {}

extension UserPrefs: RegularAppsUserPrefsDataSource {}
