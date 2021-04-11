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
		setupLaunchAtLogin()
		attachListeners()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		MenuBarDock.shared.userPrefs.save()
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
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .sortingMethodChanged, object: nil)
	}

	@objc func numberOfAppsSliderDidChange() {
		updateStatusItems()
	}

	@objc func updateStatusItems() {
		// display running apps in order
		// will be by default ordered newest on the right because that's the most likely place the status item will be if there are too many status items.
		MenuBarDock.shared.statusItemManager.updateStatusItems()
	}

	var appBeingRightClicked: NSRunningApplication? // this is horrible but idk how else to pass the app through the nsmenuitem selector.
	var launchInsteadActivateItem: NSMenuItem!

	func menu(onItemWithBundleId bundleId: String) -> NSMenu {
		let menu = NSMenu()
		// first options to do with the app.
		let app = MenuBarDock.shared.appManager.runningAppsInOrder.filter {$0.bundleIdentifier == bundleId}.first
		appBeingRightClicked = app
		let appNameToUse = app?.localizedName ?? "app"
		menu.addItem(NSMenuItem(title: "Quit \(appNameToUse)", action: #selector(AppDelegate.quitAppBeingRightClicked), keyEquivalent: "q"))
		menu.addItem(NSMenuItem(title: "Reveal \(appNameToUse) in Finder", action: #selector(AppDelegate.showInFinderAppBeingRightClicked), keyEquivalent: "r"))

		if let app = app {
			if app.isHidden {
				menu.addItem(NSMenuItem(title: "Unhide \(appNameToUse)", action: #selector(AppDelegate.unhideAppBeingRightClicked), keyEquivalent: "h"))
			} else {
				menu.addItem(NSMenuItem(title: "Hide \(appNameToUse)", action: #selector(AppDelegate.hideAppBeingRightClicked), keyEquivalent: "h"))
			}
		}
		menu.addItem(NSMenuItem(title: "Activate \(appNameToUse)", action: #selector(AppDelegate.activateAppBeingRightClicked), keyEquivalent: "a"))

		let launchInsteadActivateItem = NSMenuItem(title: "Launch \(appNameToUse) instead of activating on click", action: #selector(AppDelegate.launchInsteadOfActivateSpecificApp), keyEquivalent: "l")
		if let shouldLaunchInsteadOfActivate = MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[app?.bundleIdentifier ?? ""] {
			launchInsteadActivateItem.state = shouldLaunchInsteadOfActivate ? .on : .off
		} else {
			launchInsteadActivateItem.state = MenuBarDock.shared.userPrefs.launchInsteadOfActivate ? .on : .off // fallback to the global setting
		}
		self.launchInsteadActivateItem = launchInsteadActivateItem
		menu.addItem(launchInsteadActivateItem)

		menu.addItem(NSMenuItem.separator())
		// then options to do with menu bar dock
		menu.addItem(NSMenuItem(title: "\(Constants.App.name) Preferences...", action: #selector(AppDelegate.openPreferences), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: "Quit \(Constants.App.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")) // make it hard for user to quit menu bar dock lolll
//		menu.addItem(NSMenuItem(title: "Creator's website", action: #selector(AppDelegate.openCreatorsWebsite), keyEquivalent: "w")) //bit needy, its good enough to just show it in preferences

		return menu
	}

	@objc func openCreatorsWebsite() {
		NSWorkspace.shared.open(URL(string: "https://www.etggames.com/menu-bar-dock")!)
	}

	@objc func launchInsteadOfActivateSpecificApp() {
		// the individual app settings should not be overriden by the global option. they should be the priority.
		guard let key = appBeingRightClicked?.bundleIdentifier else {return}
		let newValue: Bool
		if launchInsteadActivateItem.state == .on {
			newValue = false
			launchInsteadActivateItem.state = .off
		} else {
			newValue = true
			launchInsteadActivateItem.state = .on
		}
		MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[key] = newValue
		MenuBarDock.shared.userPrefs.save()
  	}

	@objc func activateAppBeingRightClicked() {
		appBeingRightClicked?.activate(options: .activateIgnoringOtherApps)
	}

	@objc func hideAppBeingRightClicked() {
		if let appBeingRightClicked = appBeingRightClicked {
			appBeingRightClicked.hide()

		}
	}
	@objc func unhideAppBeingRightClicked() {
		if let appBeingRightClicked = appBeingRightClicked {
			appBeingRightClicked.unhide()

		}
	}

	@objc func showInFinderAppBeingRightClicked() {
		if let bundleURL = appBeingRightClicked?.bundleURL {
			NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
		}
	}

	@objc func quitAppBeingRightClicked() {
		let wasTerminated = appBeingRightClicked?.terminate() // needs app sandbox off or explicit com.apple.security.temporary-exception.apple-events entitlement for the specific app
		print("was terminated: ", wasTerminated ?? "null")
	}

	@objc func openPreferences() {
		print("open preferences")
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

	var bundleIdOfMenuJustOpened: String?

	@objc func statusBarPressed(button: NSButton) {
		let event = NSApp.currentEvent
		guard let bundleId =  button.layer?.value(forKey: Constants.UserDefaultsKeys.bundleId) as? String else {return}
		let item = MenuBarDock.shared.statusItemManager.statusItems.filter {$0.button == button}.first
		if event?.type == NSEvent.EventType.rightMouseUp {
			print("Right click")
			item?.button?.appearance = NSAppearance(named: NSAppearance.current.name)
			bundleIdOfMenuJustOpened = bundleId
			item?.popUpMenu(menu(onItemWithBundleId: bundleId))

		} else {
			print("Left click")
			MenuBarDock.shared.appManager.openApp(withBundleId: bundleId)
		}
	}

}
