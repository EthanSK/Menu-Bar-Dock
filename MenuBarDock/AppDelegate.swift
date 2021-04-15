//
//  AppDelegate.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate {

	let popover = NSPopover()
	var preferencesWindow = NSWindow()
	var userPrefs =  UserPrefs()
	var menuBarItems: MenuBarItems! // need reference so it stays alive
	var openableApps: OpenableApps!

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		initApp()
		setupLaunchAtLogin()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		userPrefs.save()
	}

	func initApp() {
		userPrefs.load()
		menuBarItems = MenuBarItems(
			userPrefsDataSource: userPrefs
		)
		menuBarItems.delegate = self

		let runningApps = RunningApps(userPrefsDataSource: userPrefs)
		let regularApps = RegularApps(userPrefsDataSource: userPrefs)

		openableApps = OpenableApps(userPrefsDataSource: userPrefs, runningApps: runningApps, regularApps: regularApps)
		openableApps.delegate = self

		updateMenuBarItems()
	}

	func setupLaunchAtLogin() {
		let launcherAppId = Constants.App.launcherBundleId
		let runningApps = NSWorkspace.shared.runningApplications

		SMLoginItemSetEnabled(launcherAppId as CFString, false) // needs to be set to false to actually create the loginitems.501.plist file, then we can set it to the legit value...weird
		SMLoginItemSetEnabled(launcherAppId as CFString, userPrefs.launchAtLogin)

		let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
		if isLauncherRunning {
			DistributedNotificationCenter.default().post(name: Notification.Name("killLauncher"), object: Bundle.main.bundleIdentifier!)
		}
	}

	private func updateMenuBarItems() {
		menuBarItems.update(openableApps: openableApps)
	}
}

extension AppDelegate: MenuBarItemsDelegate {
	func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp) {
		userPrefs.appOpeningMethods[app.id] = method
		userPrefsWasUpdated()
	}

	func didOpenPreferencesWindow() {
		openPreferencesWindow()
	}

	func openPreferencesWindow() {
		if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: Constants.ViewControllerIdentifiers.preferences) as? PreferencesViewController {
			viewController.userPrefsDataSource = userPrefs
			viewController.delegate = self
			if !preferencesWindow.isVisible {
				preferencesWindow = NSWindow(contentViewController: viewController)
				preferencesWindow.makeKeyAndOrderFront(self)
			}
			preferencesWindow.minSize = preferencesWindow.frame.size
			let controller = NSWindowController(window: preferencesWindow)
			controller.showWindow(self)
			NSApp.activate(ignoringOtherApps: true)// stops bugz n shiz i think
		}
	}
}

extension AppDelegate: OpenableAppsDelegate {
	func appsDidChange() {
		updateMenuBarItems()
	}
}

extension AppDelegate: PreferencesViewControllerDelegate {

	func maxNumRunningAppsSliderEndedChanging(_ value: Int) {
		userPrefs.maxNumRunningApps = value
		userPrefsWasUpdated()
	}

	func statusItemWidthSliderDidChange(_ value: Double) {
		userPrefs.statusItemWidth = CGFloat(value)
		userPrefsWasUpdated()
	}

	func appIconSizeSliderDidChange(_ value: Double) {
		userPrefs.appIconSize = CGFloat(value)
		userPrefsWasUpdated()
	}

	func runningAppsSortingMethodDidChange(_ value: RunningAppsSortingMethod) {
		userPrefs.runningAppsSortingMethod = value
		userPrefsWasUpdated()
	}

	func resetPreferencesToDefaultsWasPressed() {
		userPrefs.resetToDefaults()
		userPrefsWasUpdated()
	}

	func resetAppOpeningMethodsWasPressed() {
		userPrefs.resetAppOpeningMethodsToDefaults()
		userPrefsWasUpdated()
	}

	func launchAtLoginDidChange(_ value: Bool) {
		userPrefs.launchAtLogin = value
		let launcherAppId = Constants.App.launcherBundleId
		SMLoginItemSetEnabled(launcherAppId as CFString, value)
		userPrefsWasUpdated()
	}

	func aboutWasPressed() {
		// TODO: open about window
	}

	func hideFinderDidChange(_ value: Bool) {
		userPrefs.hideFinderFromRunningApps = value
		userPrefsWasUpdated()
	}

	func hideActiveAppDidChange(_ value: Bool) {
		userPrefs.hideActiveAppFromRunningApps = value
		userPrefsWasUpdated()
	}

	func appOpeningMethodDidChange(_ value: AppOpeningMethod) {
		userPrefs.defaultAppOpeningMethod = value
		userPrefsWasUpdated()
	}

	func regularAppsUrlsWereAdded(_ value: [URL]) {
		value.forEach { (url) in
			if !userPrefs.regularAppsUrls.contains(url) {
				userPrefs.regularAppsUrls.append(url)
			}
		}
		userPrefsWasUpdated()
	}

	func regularAppsUrlsWereRemoved(_ removedIndexes: IndexSet) {
		userPrefs.regularAppsUrls.remove(at: removedIndexes)
		userPrefsWasUpdated()
	}

	func regularAppUrlWasMoved(oldIndex: Int, newIndex: Int) {
		let url = userPrefs.regularAppsUrls.remove(at: oldIndex)
		userPrefs.regularAppsUrls.insert(url, at: newIndex)
		userPrefsWasUpdated()
	}

	func sideToShowRunningAppsDidChange(_ value: SideToShowRunningApps) {
		userPrefs.sideToShowRunningApps = value
		userPrefsWasUpdated()
	}

	func hideDuplicateAppsWasPressed(_ value: Bool) {
		userPrefs.hideDuplicateApps = value
		userPrefsWasUpdated()
	}

	func duplicateAppsPriorityDidChange(_ value: DuplicateAppsPriority) {
		userPrefs.duplicateAppsPriority = value
		userPrefsWasUpdated()
	}

	private func userPrefsWasUpdated() {
		userPrefs.save()
		openableApps.update()
		updateMenuBarItems()
	}
}
