//
//  UserPrefs.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum UserPrefsDefaultValues {
    static let hoverAnimationsEnabled = true
    static let groupBackgroundEnabled = true
    static let appIconSize: CGFloat = 40
    static let groupSpacing: CGFloat = 48
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
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        iconOverrideCache.countLimit = 64
        iconOverrideCache.totalCostLimit = 8 * 1024 * 1024
    }

    func prepareLocalPreferences(original: [String: Any]) {
        if !defaults.bool(forKey: "groupedLocalPreferencesImported") {
            for key in Constants.UserPrefs.migrationKeys {
                if let value = original[key] { defaults.set(value, forKey: key) }
            }
            defaults.set(false, forKey: Constants.UserPrefs.launchAtLogin)
            defaults.set(true, forKey: "groupedLocalPreferencesImported")
        }
        // Repair grouped.1/.2 without reimporting over the user's current list.
        // Preserve the new GroupedDock position and all app/folder preferences.
        for key in defaults.dictionaryRepresentation().keys
            where key.hasPrefix("NSStatusItem ") && key.contains(" Item-") {
            defaults.removeObject(forKey: key)
        }
        // grouped.1–.3 capped and saved the imported icon size at 20 pt.
        // Restore the upstream size once; later user adjustments remain local.
        if !defaults.bool(forKey: "groupedIconSizeRestored") {
            let current = defaults.object(forKey: Constants.UserPrefs.appIconSize) as? Double
            let originalSize = original[Constants.UserPrefs.appIconSize] as? Double
            if let current = current, current <= 20, let originalSize = originalSize, originalSize > 20 {
                defaults.set(min(100, originalSize), forKey: Constants.UserPrefs.appIconSize)
            }
            defaults.set(true, forKey: "groupedIconSizeRestored")
        }
    }
    var appIconOverrides: [String: Data] = [:] {
        didSet { iconOverrideCache.removeAllObjects(); invalidIconOverrides.removeAll() }
    }
    private let iconOverrideCache = NSCache<NSString, NSImage>()
    private var invalidIconOverrides: Set<String> = []
    private var lastSavedValues: [String: Any] = [:]

    /// Returns the saved icon for both the app list and menu-bar entries.
    func iconOverride(forAppAt url: URL) -> NSImage? {
        let key = url.absoluteString
        if let image = iconOverrideCache.object(forKey: key as NSString) { return image }
        guard !invalidIconOverrides.contains(key), let data = appIconOverrides[key] else { return nil }
        guard let image = NSImage(data: data), image.isValid,
              image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else {
            invalidIconOverrides.insert(key)
            return nil
        }
        // Image data is normally a bounded 256 px PNG. NSCache also responds
        // to memory pressure rather than retaining every decoded icon forever.
        let cost = Int(min(8_388_608, max(1, image.size.width * image.size.height * 4)))
        iconOverrideCache.setObject(image, forKey: key as NSString, cost: cost)
        return image
    }

    var hoverAnimationsEnabled = UserPrefsDefaultValues.hoverAnimationsEnabled
    var groupBackgroundEnabled = UserPrefsDefaultValues.groupBackgroundEnabled
    var groupSpacing: CGFloat = UserPrefsDefaultValues.groupSpacing
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
        hoverAnimationsEnabled = UserPrefsDefaultValues.hoverAnimationsEnabled
        groupBackgroundEnabled = UserPrefsDefaultValues.groupBackgroundEnabled
        groupSpacing = UserPrefsDefaultValues.groupSpacing
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
        let values: [String: Any] = [
            Constants.UserPrefs.hoverAnimationsEnabled: hoverAnimationsEnabled,
            Constants.UserPrefs.groupBackgroundEnabled: groupBackgroundEnabled,
            Constants.UserPrefs.groupSpacing: groupSpacing,
            Constants.UserPrefs.appIconOverrides: appIconOverrides,
            Constants.UserPrefs.appIconSize: appIconSize,
            Constants.UserPrefs.appOpeningMethods: appOpeningMethods.mapValues(\.rawValue),
            Constants.UserPrefs.defaultAppOpeningMethod: defaultAppOpeningMethod.rawValue,
            Constants.UserPrefs.duplicateAppsPriority: duplicateAppsPriority.rawValue,
            Constants.UserPrefs.hideActiveAppFromRunningApps: hideActiveAppFromRunningApps,
            Constants.UserPrefs.hideDuplicateApps: hideDuplicateApps,
            Constants.UserPrefs.hideFinderFromRunningApps: hideFinderFromRunningApps,
            Constants.UserPrefs.launchAtLogin: launchAtLogin,
            Constants.UserPrefs.maxNumRunningApps: maxRunningApps,
            Constants.UserPrefs.preserveAppOrder: preserveAppOrder,
            Constants.UserPrefs.regularAppsUrls: regularAppsUrls.map(\.absoluteString),
            Constants.UserPrefs.rightClickByDefault: rightClickByDefault,
            Constants.UserPrefs.runningAppsSortingMethod: runningAppsSortingMethod.rawValue,
            Constants.UserPrefs.sideToShowRunningApps: sideToShowRunningApps.rawValue,
            Constants.UserPrefs.statusItemWidth: itemSlotWidth
        ]
        for (key, value) in values {
            let previous = lastSavedValues[key] ?? defaults.object(forKey: key)
            if let previous = previous, (value as AnyObject).isEqual(previous) { continue }
            defaults.set(value, forKey: key)
        }
        lastSavedValues = values
    }

    private func finite(_ value: CGFloat, in range: ClosedRange<CGFloat>, fallback: CGFloat) -> CGFloat {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

	func load() {
        lastSavedValues.removeAll()
        if let enabled = defaults.object(forKey: Constants.UserPrefs.hoverAnimationsEnabled) as? Bool {
            hoverAnimationsEnabled = enabled
        }
        if let enabled = defaults.object(forKey: Constants.UserPrefs.groupBackgroundEnabled) as? Bool {
            groupBackgroundEnabled = enabled
        }
        if let spacing = defaults.object(forKey: Constants.UserPrefs.groupSpacing) as? Double {
            groupSpacing = finite(CGFloat(spacing), in: 0...160, fallback: UserPrefsDefaultValues.groupSpacing)
        }
        if let appIconOverrides = defaults.dictionary(forKey: Constants.UserPrefs.appIconOverrides) as? [String: Data] {
            self.appIconOverrides = appIconOverrides
        }
        if let appIconSize = defaults.object(forKey: Constants.UserPrefs.appIconSize) as? CGFloat {
            self.appIconSize = finite(appIconSize, in: 12...100, fallback: UserPrefsDefaultValues.appIconSize)
        }

        if let defaultAppOpeningMethod = defaults.object(forKey: Constants.UserPrefs.defaultAppOpeningMethod) as? String {
            self.defaultAppOpeningMethod = AppOpeningMethod(rawValue: defaultAppOpeningMethod) ?? UserPrefsDefaultValues.defaultAppOpeningMethod
        }
        if let appOpeningMethods = defaults.object(forKey: Constants.UserPrefs.appOpeningMethods) as? [String: String] {
            self.appOpeningMethods = Dictionary(uniqueKeysWithValues:
                appOpeningMethods.map({ key, value in
                (key, AppOpeningMethod(rawValue: value) ?? UserPrefsDefaultValues.defaultAppOpeningMethod)
            }))
        }

        if let duplicateAppsPriority = defaults.object(forKey: Constants.UserPrefs.duplicateAppsPriority) as? String {
            self.duplicateAppsPriority = DuplicateAppsPriority(rawValue: duplicateAppsPriority) ?? UserPrefsDefaultValues.duplicateAppsPriority
        }

        if let hideActiveAppFromRunningApps = defaults.object(forKey: Constants.UserPrefs.hideActiveAppFromRunningApps) as? Bool {
            self.hideActiveAppFromRunningApps = hideActiveAppFromRunningApps
        }

        if let hideDuplicateApps = defaults.object(forKey: Constants.UserPrefs.hideDuplicateApps) as? Bool {
            self.hideDuplicateApps = hideDuplicateApps
        }

        if let hideFinderFromRunningApps = defaults.object(forKey: Constants.UserPrefs.hideFinderFromRunningApps) as? Bool {
            self.hideFinderFromRunningApps = hideFinderFromRunningApps
        }

        if let launchAtLogin = defaults.object(forKey: Constants.UserPrefs.launchAtLogin) as? Bool {
            self.launchAtLogin = launchAtLogin
        }

		if let maxNumRunningApps = defaults.object(forKey: Constants.UserPrefs.maxNumRunningApps) as? Int {
			self.maxRunningApps = min(100, max(0, maxNumRunningApps))
		}

        if let preserveAppOrder = defaults.object(forKey: Constants.UserPrefs.preserveAppOrder) as? Bool {
            self.preserveAppOrder = preserveAppOrder
        }

        if let regularAppsUrlsStrs = defaults.object(forKey: Constants.UserPrefs.regularAppsUrls) as? [String] {
            var res: [URL] = []
            for urlStr in regularAppsUrlsStrs {
                if let url = URL(string: urlStr), url.isFileURL, !res.contains(url.standardizedFileURL) {
                    res.append(url.standardizedFileURL)
                }
            }
            self.regularAppsUrls = res
         }

        if let rightClickByDefault = defaults.object(forKey: Constants.UserPrefs.rightClickByDefault) as? Bool {
            self.rightClickByDefault = rightClickByDefault
        }

        if let runningAppsSortingMethodInt = defaults.object(forKey: Constants.UserPrefs.runningAppsSortingMethod) as? Int, let runningAppsSortingMethod = RunningAppsSortingMethod(rawValue: runningAppsSortingMethodInt) {
            self.runningAppsSortingMethod = runningAppsSortingMethod
        }

        if let sideToShowRunningApps = defaults.object(forKey: Constants.UserPrefs.sideToShowRunningApps) as? String {
            self.sideToShowRunningApps = SideToShowRunningApps(rawValue: sideToShowRunningApps) ?? UserPrefsDefaultValues.sideToShowRunningApps
        }

		if let statusItemWidth = defaults.object(forKey: Constants.UserPrefs.statusItemWidth) as? CGFloat {
			self.itemSlotWidth = finite(statusItemWidth, in: 30...64, fallback: UserPrefsDefaultValues.statusItemWidth)
		}
	}
}

extension UserPrefs: MenuBarItemsUserPrefsDataSource {}

extension UserPrefs: OpenableAppsUserPrefsDataSource {}

extension UserPrefs: RunningAppsUserPrefsDataSource {}

extension UserPrefs: PreferencesViewControllerUserPrefsDataSource {}

extension UserPrefs: RegularAppsUserPrefsDataSource {}
