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

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		initApp()
		setupLaunchAtLogin()
		attachListeners()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		MenuBarDock.shared.userPrefs.save()
	}
	
	func initApp(){
		let userPrefs = UserPrefs()
		let menuBarItems = MenuBarItems(userPrefsDelegate: userPrefs, preferencesDelegate: self)
		let openableApp = OpenableApps()
		
		
	} 

	func setupLaunchAtLogin() {
		let launcherAppId = Constants.App.launcherBundleId
		let runningApps = NSWorkspace.shared.runningApplications

		SMLoginItemSetEnabled(launcherAppId as CFString, false) // needs to be set to false to actually create the loginitems.501.plist file, then we can set it to the legit value...weird
		SMLoginItemSetEnabled(launcherAppId as CFString, MenuBarDock.shared.userPrefs.launchAtLogin)

		let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
		if isLauncherRunning {
			DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
		}
	}

	func attachListeners() {
		MenuBarDock.shared.appManager.trackAppsBeingActivated { (_) in
			self.updateStatusItems()
		}
		MenuBarDock.shared.appManager.trackAppsBeingQuit { (_) in
			self.updateStatusItems()  // because the app actually quits aftre the activated app is switched meaninng otherwise we would keep the old app in the list showing
		}
		updateStatusItems()
		NotificationCenter.default.addObserver(self, selector: #selector(numberOfAppsSliderDidChange), name: .numberOfAppsSliderEndedSliding, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .widthOfitemSliderChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .sizeOfIconSliderChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .resetToDefaults, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .runningAppsSortingMethodChanged, object: nil)
	}

	@objc func numberOfAppsSliderDidChange() {
		updateStatusItems()
	}

	@objc func updateStatusItems() {
		// display running apps in order
		// will be by default ordered newest on the right because that's the most likely place the status item will be if there are too many status items.
		MenuBarDock.shared.statusItemManager.updateStatusItems()
	}


}


extension AppDelegate: MenuBarItemsPreferencesDelegate {
	func didOpenPreferencesWindow() {
		openPreferencesWindow()
	}
	
	func openPreferencesWindow() {
		if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: Constants.ViewControllerIdentifiers.preferences) as? PreferencesViewController {
			if !preferencesWindow.isVisible {
				preferencesWindow = NSWindow(contentViewController: viewController)
				preferencesWindow.makeKeyAndOrderFront(self)
			}
			let controller = NSWindowController(window: preferencesWindow)
			controller.showWindow(self)
			NSApp.activate(ignoringOtherApps: true)// stops bugz n shiz i think
		}
	}
}
