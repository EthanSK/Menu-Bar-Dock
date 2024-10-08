//
//  OpenableApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

// represents an app actually being shown in the menu bar
class OpenableApp {
	public var id: String
	public var appOpeningMethod: AppOpeningMethod? // should only have a value if the user explicitly set it
	public var bundleId: String? // do NOT use to uniquely identify app. there can be multiple instances of the same app running
	public var icon: NSImage
	public var name: String
	public var bundleUrl: URL
	public var runningApplication: NSRunningApplication?

	init(
		bundleId: String?,
		icon: NSImage,
		bundleUrl: URL,
		name: String,
		id: String,
		appOpeningMethod: AppOpeningMethod?,
		runningApplication: NSRunningApplication?
	) {
		self.bundleId = bundleId
		self.icon = icon
		self.bundleUrl = bundleUrl
		self.name = name
		self.id = id
		self.appOpeningMethod = appOpeningMethod
		self.runningApplication = runningApplication
 	}

	convenience init(
		regularApp: RegularApp,
		appOpeningMethod: AppOpeningMethod
	) {
		self.init(
			bundleId: regularApp.bundle.bundleIdentifier,
			icon: regularApp.icon,
			bundleUrl: regularApp.bundle.bundleURL,
			name: regularApp.name,
			id: regularApp.id,
			appOpeningMethod: appOpeningMethod,
			runningApplication: regularApp.runningApp
		)
	}

	convenience init(
		runningApp: RunningApp,
		appOpeningMethod: AppOpeningMethod
 	) throws {

		guard let icon = runningApp.app.icon else {
			throw OpenableAppError.noIcon
		}
		guard let name = runningApp.app.localizedName ?? runningApp.app.bundleIdentifier else {
			throw OpenableAppError.noName
		}
		guard let bundleUrl = runningApp.app.bundleURL else {
			throw OpenableAppError.noBundleUrl
		}

		self.init(
			bundleId: runningApp.app.bundleIdentifier,
			icon: icon,
			bundleUrl: bundleUrl,
			name: name,
			id: runningApp.id,
			appOpeningMethod: appOpeningMethod,
			runningApplication: runningApp.app
 		)

 	}

	func open() {
		showOpeningAppWarningIfNeeded()
		if bundleId == Constants.App.finderBundleId {
			openFinder()
			return
		}
		openApp()
	}

	func quit() {
		let wasTerminated = runningApplication?.terminate() // needs app sandbox off or explicit com.apple.security.temporary-exception.apple-events entitlement for the specific app
		print("App \(bundleId ?? "none") termination success status: ", wasTerminated ?? "null")
	}

	func revealInFinder() {
		NSWorkspace.shared.activateFileViewerSelecting([bundleUrl])
	}

	func setIsHidden(isHidden: Bool) {
		guard let runningApplication = runningApplication else { return }
		if isHidden {
			runningApplication.hide()
		} else {
			runningApplication.unhide()
		}
	}

	func activate() {
		activateApp()
	}

	func launch() {
		launchApp()
	}

	func openNewAppInstance() {
		if #available(OSX 10.15, *) {
			let config = NSWorkspace.OpenConfiguration()
			config.createsNewApplicationInstance = true
			NSWorkspace.shared.openApplication(at: bundleUrl, configuration: config) { (runningApp, error) in
				print("openNewAppInstance running app: ", runningApp?.bundleIdentifier ?? "none", "error: ", error ?? "none")
			}
		}
	}

	private func openFinder() {
		launchApp()
		if let runningApp = runningApplication {
			runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) // this is the only way I can get working to show the finder app
		}
	}

	private func openApp() {
		if appOpeningMethod == .activate, runningApplication != nil {
			activateApp()
		} else {
			launchApp()
		}
	}

	private func launchApp() {
		print("Launching app: ", name)

        // workaround needed to open Steam, otherwise it opens the app path in Finder
        if bundleId == "com.valvesoftware.steam" {
            NSWorkspace.shared.launchApplication(withBundleIdentifier: "com.valvesoftware.steam", options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
            return
        }

		if #available(OSX 10.15, *) {
			let config = NSWorkspace.OpenConfiguration()
			config.activates = true
			NSWorkspace.shared.openApplication(at: bundleUrl, configuration: config) { (_, _) in
			}
		} else if let bundleId = bundleId {
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) // old way
		}
	}

	private func activateApp() {
		print("Activating app: ", name)
		guard let runningApp = runningApplication else { return }
		runningApp.activate(options: [.activateIgnoringOtherApps]) // I removed .activateAllWindows, but if that proves to be a problem, add it back to the options array
	}

	private func showOpeningAppWarningIfNeeded() {
		// allows us to fail gracefully and alert the developer
		if appOpeningMethod == .activate && runningApplication == nil {
			let warningMsg = "The app opening method is 'activate' for app \(bundleId ?? "none") but there is no running app, so launched it instead! This shouldn't happen"
			print(warningMsg)
		}
	}
}

enum AppOpeningMethod: String {
	case launch = "launch"
	case activate = "activate"
}

enum OpenableAppError: Error {
 	case noIcon // we need an icon to show something in the menu bar, so throwing an error is fine if there isn't one.
	case noName // we need some kind of name
	case noBundleUrl // we need this for the exact path of the app, so we open the correct version
}

extension OpenableApp: Reorderable {
	var orderElement: OrderElement { // so we can order using another array of bundleIds
		id
	}

	typealias OrderElement = String
}
