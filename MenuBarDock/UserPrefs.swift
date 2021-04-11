//
//  UserPrefs.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum UserPrefsDefaultValues {
	static let numberOfStatusItems = 15 // make it go up really high so user has freedom if the have a very large long screen
	static let widthOfStatusItem = CGFloat(30)
	static let sortingMethod: SortingMethod = .mostRecentOnRight
	static let iconSize: CGFloat = 21
	static let launchAtLogin = true // appaz mac app store doesn't allow default true
	static let defaultAppOpeningMethod = AppOpeningMethod.launch
	static let appOpeningMethods: [String: AppOpeningMethod] = [:] //bundleId is key
	static let hideActiveApp = true
	static let hideFinder = false
}

class UserPrefs: NSObject {
	var numberOfStatusItems = UserPrefsDefaultValues.numberOfStatusItems // make it go up really high so user has freedom if the have a very large long screen
	var widthOfStatusItem = UserPrefsDefaultValues.widthOfStatusItem
	var sortingMethod: SortingMethod = UserPrefsDefaultValues.sortingMethod
	var iconSize: CGFloat = UserPrefsDefaultValues.iconSize
	var launchAtLogin = UserPrefsDefaultValues.launchAtLogin
	var defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
	var appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
	var hideActiveApp = UserPrefsDefaultValues.hideActiveApp
	var hideFinder = UserPrefsDefaultValues.hideFinder

	override init() {
		super.init()
		load()
	}

	func resetToDefaults() { // cba about this shitty code tbh not worth my time
		numberOfStatusItems =  UserPrefsDefaultValues.numberOfStatusItems // make it go up really high so user has freedom if the have a very large long screen
		widthOfStatusItem = UserPrefsDefaultValues.widthOfStatusItem
		sortingMethod = UserPrefsDefaultValues.sortingMethod
		iconSize = UserPrefsDefaultValues.iconSize
		defaultAppOpeningMethod = UserPrefsDefaultValues.defaultAppOpeningMethod
		hideActiveApp = UserPrefsDefaultValues.hideActiveApp
		hideFinder = UserPrefsDefaultValues.hideFinder

		save()
	}
	func resetIndivAppSettingsToDefaults() {
		appOpeningMethods = UserPrefsDefaultValues.appOpeningMethods
	}

	func save() {
		UserDefaults.standard.set(numberOfStatusItems, forKey: Constants.UserPrefs.numberOfStatusItems)
		UserDefaults.standard.set(widthOfStatusItem, forKey: Constants.UserPrefs.widthOfStatusItem)
		UserDefaults.standard.set(sortingMethod.rawValue, forKey: Constants.UserPrefs.sortingMethod)
		UserDefaults.standard.set(iconSize, forKey: Constants.UserPrefs.iconSize)
		UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserPrefs.launchAtLogin)
		UserDefaults.standard.set(defaultAppOpeningMethod.rawValue, forKey: Constants.UserPrefs.defaultAppOpeningMethod)
		UserDefaults.standard.set(
			Dictionary(uniqueKeysWithValues:
					appOpeningMethods.map({ key, value in (key, value.rawValue)
		})), forKey: Constants.UserPrefs.appOpeningMethods)
		UserDefaults.standard.set(hideActiveApp, forKey: Constants.UserPrefs.hideActiveApp)
		UserDefaults.standard.set(hideFinder, forKey: Constants.UserPrefs.hideFinder)

	}

	func load() {
		if let numberOfStatusItems = UserDefaults.standard.object(forKey: Constants.UserPrefs.numberOfStatusItems) as? Int {
			self.numberOfStatusItems = numberOfStatusItems
		}

		if let widthOfStatusItem = UserDefaults.standard.object(forKey: Constants.UserPrefs.widthOfStatusItem) as? CGFloat {
			self.widthOfStatusItem = widthOfStatusItem
		}

		if let sortingMethodInt = UserDefaults.standard.object(forKey: Constants.UserPrefs.sortingMethod) as? Int, let sortingMethod = SortingMethod(rawValue: sortingMethodInt) {
			self.sortingMethod = sortingMethod
		}

		if let iconSize = UserDefaults.standard.object(forKey: Constants.UserPrefs.iconSize) as? CGFloat {
			self.iconSize = iconSize
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
		if let hideActiveApp = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideActiveApp) as? Bool {
			self.hideActiveApp = hideActiveApp
		}
		if let hideFinder = UserDefaults.standard.object(forKey: Constants.UserPrefs.hideFinder) as? Bool {
			self.hideFinder = hideFinder
		}
	}
}
