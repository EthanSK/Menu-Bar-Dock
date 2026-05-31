//
//  AppDelegate.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa
import ServiceManagement
// Sparkle 2.x — drives in-app auto-update. The feed URL + EdDSA public key
// are configured via Info.plist (SUFeedURL / SUPublicEDKey). See Info.plist
// comments for the full release-pipeline rationale.
// Added 2026-05-28 (Ethan voice 7174).
import Sparkle

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate {
	let popover = NSPopover()
	var storyboard: NSStoryboard!
	var preferencesWindow = NSWindow()
	var aboutWindowController: NSWindowController?
	var infoWindowController: NSWindowController?

	var userPrefs =  UserPrefs()
	var menuBarItems: MenuBarItems! // need reference so it stays alive
	var openableApps: OpenableApps!
	var appTracker: AppTracker!
	var runningApps: RunningApps!
	var regularApps: RegularApps!

	// Sparkle's standard updater controller — must be a long-lived property so
	// Sparkle's background scheduler stays alive for the whole app session.
	// `startingUpdater: true` kicks off the first update check immediately on
	// launch (subject to SUScheduledCheckInterval). With `updaterDelegate: nil`
	// we accept Sparkle's defaults; future customization (e.g. ignoring
	// specific versions, gating beta channels) would add a delegate here.
	private lazy var sparkleUpdater: SPUStandardUpdaterController = {
		return SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)
	}()

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		initApp()
		setupLaunchAtLogin()
		// Touch the lazy var so Sparkle starts polling the appcast. Without
		// this access the property never instantiates and no updates are
		// checked. _ = is the canonical way to silence the unused-result
		// warning while forcing evaluation.
		_ = sparkleUpdater
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		userPrefs.save()
	}

	func initApp() {
		userPrefs.load()
		storyboard = NSStoryboard(name: "Main", bundle: nil)
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

        if #available(macOS 13.0, *) {
            do {
                let appService = SMAppService.loginItem(identifier: launcherAppId)
                if userPrefs.launchAtLogin {
                    try appService.register()
                } else {
                    try appService.unregister()
                }
            } catch {
                print("Failed to register/unregister login item: \(error)")
            }
        } else {
            SMLoginItemSetEnabled(launcherAppId as CFString, false) // needs to be set to false to actually create the loginitems.501.plist file, then we can set it to the legit value...weird
            SMLoginItemSetEnabled(launcherAppId as CFString, userPrefs.launchAtLogin)
        }

		let isLauncherRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
		if isLauncherRunning {
			DistributedNotificationCenter.default().post(name: Notification.Name("killLauncher"), object: Bundle.main.bundleIdentifier!)
		}
	}

	private func updateMenuBarItems() {
		menuBarItems.update(openableApps: openableApps)
	}

	// Exposed so a future "Check for Updates…" menu item / preferences button
	// can request an immediate user-driven update check (shows the Sparkle UI
	// even if no update is available, so the user gets visible feedback).
	// Sparkle's background scheduler still runs on its own cadence.
	// Marked @objc so it's wirable from Interface Builder.
	@objc func checkForUpdates(_ sender: Any?) {
		// LSUIElement TWO-CLICK FIX (Ethan voice, 2026-05-31):
		// Menu Bar Dock is an LSUIElement (menu-bar accessory) app — it has no
		// Dock tile and, crucially, macOS never auto-activates it to the
		// foreground. Sparkle's "check for updates" window inherits the
		// activation state of the app that requests it, so when this accessory
		// app (which is NOT frontmost) calls checkForUpdates, Sparkle's window
		// opens BEHIND the currently-active app. The user sees "nothing happen"
		// on the first click; a second click finally surfaces it because by then
		// some focus shuffle has occurred. The standard fix for this exact symptom
		// is to explicitly bring our app to the front RIGHT BEFORE asking Sparkle
		// to show its UI, so the update window appears front-and-centre on the
		// first click.
		//
		// WHY the #available split: NSApplication.activate(ignoringOtherApps:)
		// was deprecated in macOS 14 (Sonoma) when Apple changed to the
		// cooperative-activation model. On 14+ the parameter-less NSApp.activate()
		// is the supported call (it requests activation cooperatively); on older
		// systems we keep the legacy ignoringOtherApps: true to force the window
		// forward. Splitting on availability avoids both the deprecation warning
		// on 14+ and a missing-API problem on older targets.
		DebugLog.shared.log("check-for-updates invoked, activating app (LSUIElement front-bring before Sparkle UI)")
		if #available(macOS 14.0, *) {
			NSApp.activate()
		} else {
			NSApp.activate(ignoringOtherApps: true)
		}
		sparkleUpdater.checkForUpdates(sender)
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

	func didCheckForUpdates() {
		checkForUpdates(nil)
	}

	func openPreferencesWindow() {
		if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: Constants.Identifiers.ViewControllers.preferences) as? PreferencesViewController {
			viewController.userPrefsDataSource = userPrefs
			viewController.delegate = self

			if !preferencesWindow.isVisible == true {
				preferencesWindow = NSWindow(contentViewController: viewController)
				preferencesWindow.makeKeyAndOrderFront(self)
			}
			preferencesWindow.makeKeyAndOrderFront(self)

			preferencesWindow.minSize = preferencesWindow.frame.size
			preferencesWindow.windowController?.showWindow(self)
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

		updateMenuBarItems()
	}
}

extension AppDelegate: PreferencesViewControllerDelegate {
	func maxRunningAppsSliderDidChange(_ value: Int) {
		userPrefs.maxRunningApps = value
		userPrefsWasUpdated()
	}

	func itemSlotWidthSliderDidChange(_ value: Double) {
		userPrefs.itemSlotWidth = CGFloat(value)
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

    func checkForUpdatesWasPressed(_ sender: Any?) {
        checkForUpdates(sender)
    }

	func launchAtLoginDidChange(_ value: Bool) {
		userPrefs.launchAtLogin = value
		let launcherAppId = Constants.App.launcherBundleId
        if #available(macOS 13.0, *) {
            do {
                let appService = SMAppService.loginItem(identifier: launcherAppId)
                if value {
                    try appService.register()
                } else {
                    try appService.unregister()
                }
            } catch {
                print("Failed to register/unregister login item: \(error)")
            }
        } else {
            SMLoginItemSetEnabled(launcherAppId as CFString, value)

        }
		userPrefsWasUpdated()
	}

	func aboutWasPressed() {
		if let windowController = aboutWindowController ?? storyboard.instantiateController(withIdentifier: Constants.Identifiers.WindowControllers.about) as? NSWindowController {
			windowController.showWindow(self)
			aboutWindowController = windowController
		}
	}

	func hideFinderDidChange(_ value: Bool) {
		userPrefs.hideFinderFromRunningApps = value
		userPrefsWasUpdated()
	}

	func hideActiveAppDidChange(_ value: Bool) {
		userPrefs.hideActiveAppFromRunningApps = value
		userPrefsWasUpdated()
	}

    func preserveAppOrderDidChange(_ value: Bool) {
        userPrefs.preserveAppOrder = value
        userPrefsWasUpdated()
    }

    func rightClickByDefaultDidChange(_ value: Bool) {
        userPrefs.rightClickByDefault = value
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

	func hideDuplicateAppsDidChange(_ value: Bool) {
		userPrefs.hideDuplicateApps = value
		userPrefsWasUpdated()
	}

	func duplicateAppsPriorityDidChange(_ value: DuplicateAppsPriority) {
		userPrefs.duplicateAppsPriority = value
		userPrefsWasUpdated()
	}

	func infoWasPressed() {
		if let windowController = infoWindowController ?? storyboard.instantiateController(withIdentifier: Constants.Identifiers.WindowControllers.info) as? NSWindowController {
			windowController.showWindow(self)
			infoWindowController = windowController
		}
	}

	private func userPrefsWasUpdated() {
		userPrefs.save()
		runningApps.update()
		regularApps.update()
		openableApps.update(runningApps: runningApps, regularApps: regularApps)
		updateMenuBarItems()
	}
}
