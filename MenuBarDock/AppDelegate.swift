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
#if !LOCAL_BUILD
import Sparkle
#endif

enum AppRelaunch {
    static func helper(appURL: URL, processID: pid_t,
                       openerURL: URL = URL(fileURLWithPath: "/usr/bin/open")) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Pass the path as an argument, never interpolate it into shell code.
        // Wait for the old process so single-instance forwarding cannot steal
        // the new launch. Bound the wait if termination is unexpectedly denied.
        let script = """
        attempts=200
        while /bin/kill -0 "$1" 2>/dev/null; do
            [ "$attempts" -gt 0 ] || exit 1
            /bin/sleep 0.05
            attempts=$((attempts - 1))
        done
        exec "$3" -n "$2"
        """
        process.arguments = ["-c", script, "menubardock-relaunch", String(processID), appURL.path, openerURL.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }
}

#if !APP_TEST
@NSApplicationMain
#endif

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
    private var hasInitialized = false
    private var refreshScheduled = false
    var runningApplicationsProvider: () -> [NSRunningApplication] = { NSWorkspace.shared.runningApplications }
    var applicationBundleURL: () -> URL = { Bundle.main.bundleURL }
    var runRelaunchHelper: (Process) throws -> Void = { try $0.run() }
    var terminateApplication: () -> Void = { NSApp.terminate(nil) }
    var presentRestartError: (Error) -> Void = { NSApp.presentError($0) }
    private var isRestarting = false

	// Sparkle's standard updater controller — must be a long-lived property so
	// Sparkle's background scheduler stays alive for the whole app session.
	// `startingUpdater: true` kicks off the first update check immediately on
	// launch (subject to SUScheduledCheckInterval). With `updaterDelegate: nil`
	// we accept Sparkle's defaults; future customization (e.g. ignoring
	// specific versions, gating beta channels) would add a delegate here.
#if !LOCAL_BUILD
	private lazy var sparkleUpdater: SPUStandardUpdaterController = {
		return SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)
	}()
#endif

	func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard !forwardToExistingInstance() else { return }
		initApp()
        hasInitialized = true
		setupLaunchAtLogin()
		// Touch the lazy var so Sparkle starts polling the appcast. Without
		// this access the property never instantiates and no updates are
		// checked. _ = is the canonical way to silence the unused-result
		// warning while forcing evaluation.
        #if !LOCAL_BUILD
		_ = sparkleUpdater
        #endif
	}

	func applicationWillTerminate(_ aNotification: Notification) {
        // A duplicate exits before loading preferences and must not overwrite
        // the active instance's pinned list with defaults.
        if hasInitialized { userPrefs.save() }
	}

    private func forwardToExistingInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !$0.isTerminated }
            .sorted {
                let lhs = $0.launchDate ?? .distantPast
                let rhs = $1.launchDate ?? .distantPast
                return lhs == rhs ? $0.processIdentifier < $1.processIdentifier : lhs < rhs
            }
        guard let existing = instances.first,
              existing.processIdentifier != current.processIdentifier,
              let url = existing.bundleURL else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    /// Opens the app's configuration when it is reopened from Finder or a launcher.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard hasInitialized else { return false }
        openPreferencesWindow() // A menu-bar app has no main window; reopening it should expose its per-app configuration.
        return false
    }

	func initApp() {
        #if LOCAL_BUILD
        userPrefs.prepareLocalPreferences(original: UserDefaults.standard.persistentDomain(forName: "com.ethansk.MenuBarDock") ?? [:])
        #endif
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
        #if LOCAL_BUILD
        // Local builds use their own main-app login item, never the upstream helper.
        if #available(macOS 13.0, *) {
            do {
                if userPrefs.launchAtLogin { try SMAppService.mainApp.register() }
                else if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            } catch { print("Login item: \(error)") }
        }
        return
        #else
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
        #endif
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
        #if LOCAL_BUILD
        let alert = NSAlert()
        alert.messageText = "Local grouped build"
        alert.informativeText = "Automatic updates are disabled for this customized build, so an upstream release cannot replace your changes."
        alert.runModal()
        #else
		sparkleUpdater.checkForUpdates(sender)
        #endif
	}
}

extension AppDelegate: MenuBarItemsDelegate {
    func didChangeGroupSpacing(_ spacing: CGFloat) {
        userPrefs.groupSpacing = spacing
        appearanceWasUpdated()
        (preferencesWindow.contentViewController as? PreferencesViewController)?.updateGroupSpacingUi()
    }
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
        regularApps.invalidateCache()
        refreshApps() // Refresh folder availability and externally changed icons on demand.
        if let viewController = preferencesWindow.contentViewController as? PreferencesViewController {
            viewController.updateTable()
            viewController.updateUi()
        } else if let viewController = storyboard.instantiateController(withIdentifier: Constants.Identifiers.ViewControllers.preferences) as? PreferencesViewController {
            viewController.userPrefsDataSource = userPrefs
            viewController.delegate = self
            preferencesWindow = NSWindow(contentViewController: viewController)
            preferencesWindow.isReleasedWhenClosed = false
            preferencesWindow.minSize = preferencesWindow.frame.size
        }
        preferencesWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

}

extension AppDelegate: AppTrackerDelegate {
    func volumesDidChange() {
        regularApps.invalidateCache()
        scheduleAppRefresh()
    }
	/// Refreshes running entries and their instance badges without changing recency order.
    func appWasLaunched(runningApp: NSRunningApplication) {
        runningApps.handleAppLaunch(runningApp: runningApp)
        scheduleAppRefresh()
    }

    func appWasActivated(runningApp: NSRunningApplication) {
        runningApps.handleAppActivation(runningApp: runningApp)
        regularApps.handleAppActivation(runningApp: runningApp)
        scheduleAppRefresh()
    }

    func appWasQuit(runningApp: NSRunningApplication) {
        runningApps.handleAppQuit(runningApp: runningApp)
        regularApps.handleAppQuit(runningApp: runningApp)
        scheduleAppRefresh()
    }

    private func scheduleAppRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshScheduled = false
            self.refreshApps()
        }
    }

    private func refreshApps() {
        let snapshot = runningApplicationsProvider()
        runningApps.update(runningApplications: snapshot)
        regularApps.update(runningApplications: snapshot)
        openableApps.update(runningApps: runningApps, regularApps: regularApps, runningApplications: snapshot)
        updateMenuBarItems()
    }

}

extension AppDelegate: PreferencesViewControllerDelegate {
    func hoverAnimationsDidChange(_ value: Bool) {
        userPrefs.hoverAnimationsEnabled = value
        appearanceWasUpdated()
    }

    func groupBackgroundDidChange(_ value: Bool) {
        userPrefs.groupBackgroundEnabled = value
        appearanceWasUpdated()
    }

    func restartAppWasPressed() {
        guard !isRestarting else { return }
        isRestarting = true
        userPrefs.save()
        do {
            try runRelaunchHelper(AppRelaunch.helper(appURL: applicationBundleURL(), processID: getpid()))
            terminateApplication()
        } catch {
            isRestarting = false
            presentRestartError(error)
        }
    }

    func groupSpacingSliderDidChange(_ value: Double) {
        didChangeGroupSpacing(CGFloat(value))
    }
	func maxRunningAppsSliderDidChange(_ value: Int) {
		userPrefs.maxRunningApps = value
		userPrefsWasUpdated()
	}

	func itemSlotWidthSliderDidChange(_ value: Double) {
		userPrefs.itemSlotWidth = CGFloat(value)
        appearanceWasUpdated()
	}

	func appIconSizeSliderDidChange(_ value: Double) {
		userPrefs.appIconSize = CGFloat(value)
        appearanceWasUpdated()
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
        setupLaunchAtLogin()
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
			if (RegularApp.isPinnableFolder(url) || (url.pathExtension.lowercased() == "app" && Bundle(url: url) != nil)) && !userPrefs.regularAppsUrls.contains(url) {
				userPrefs.regularAppsUrls.append(url)
			}
		}
		userPrefsWasUpdated()
	}

	func regularAppsUrlsWereRemoved(_ removedIndexes: IndexSet) {
		userPrefs.regularAppsUrls.remove(at: removedIndexes)
		userPrefsWasUpdated()
	}

    func regularAppsUrlsWereReordered(_ urls: [URL]) {
        guard urls.count == userPrefs.regularAppsUrls.count,
              Set(urls) == Set(userPrefs.regularAppsUrls) else { return }
        userPrefs.regularAppsUrls = urls
        userPrefsWasUpdated()
    }

    /// Saves or removes a per-app icon and immediately refreshes the menu bar.
    func appIconOverrideDidChange(_ imageData: Data?, forAppAt url: URL) {
        userPrefs.appIconOverrides[url.absoluteString] = imageData
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
        refreshApps()
    }

    private func appearanceWasUpdated() {
        userPrefs.save()
        menuBarItems.refreshLayout()
    }
}
