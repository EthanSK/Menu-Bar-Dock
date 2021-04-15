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
	var appTracker: AppTracker!
	var runningApps: RunningApps!
	var regularApps: RegularApps!

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

		appTracker = AppTracker()
		appTracker.delegate = self

		runningApps = RunningApps(userPrefsDataSource: userPrefs)
		regularApps = RegularApps(userPrefsDataSource: userPrefs)

		openableApps = OpenableApps(userPrefsDataSource: userPrefs, runningApps: runningApps, regularApps: regularApps)

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

	private func updateMenuBarItems(canSkipItemUpdateIfSameApp: Bool = false) {
		menuBarItems.update(openableApps: openableApps, canSkipItemUpdateIfSameApp: canSkipItemUpdateIfSameApp)
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

extension AppDelegate: AppTrackerDelegate {
	func appWasActivated(runningApp: NSRunningApplication) {
		runningApps.handleAppActivation(runningApp: runningApp)
		regularApps.handleAppActivation(runningApp: runningApp)

		appActivationChange()
	}

	func appWasQuit(runningApp: NSRunningApplication) {
		runningApps.handleAppQuit(runningApp: runningApp)
		regularApps.handleAppQuit(runningApp: runningApp)

		appActivationChange()
	}

	private func appActivationChange() {
		runningApps.update()
//		regularApps.update() //doesn't make sense to update regular apps based on app activations. we could if we wanted to due to the hot reactive code structure, but best not to.
		openableApps.update(runningApps: runningApps, regularApps: regularApps)

		// only update the menu bar items if we are showing running apps, otherwise we can be efficient and not bother (since regular apps are static with respect to app activations)
		if runningApps.limit > 0 {
			updateMenuBarItems(canSkipItemUpdateIfSameApp: true)
		}
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
		runningApps.update()
		regularApps.update()
		openableApps.update(runningApps: runningApps, regularApps: regularApps)
		updateMenuBarItems()
	}
}
