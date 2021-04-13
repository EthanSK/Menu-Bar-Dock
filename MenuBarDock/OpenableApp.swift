//
//  OpenableApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class OpenableApp {
	var bundleId: String // do NOT use to uniquely identify app. there can be multiple instances of the same app running
	var icon: NSImage
	var name: String
	var bundleUrl: URL
	var runningApplication: NSRunningApplication?
	var appOpeningMethod: AppOpeningMethod

	init(
		 bundleId: String,
		 icon: NSImage,
		 appOpeningMethod: AppOpeningMethod,
		 bundleUrl: URL,
		 name: String
	) {
		self.bundleId = bundleId
		self.icon = icon
		self.appOpeningMethod = appOpeningMethod
		self.bundleUrl = bundleUrl
		self.name = name
 	}

	init(
		runningApp: NSRunningApplication,
		appOpeningMethod: AppOpeningMethod
	) throws {
		guard let bundleId = runningApp.bundleIdentifier else {
			throw OpenableAppError.noBundleId
		}
		guard let icon = runningApp.icon else {
			throw OpenableAppError.noIcon
		}
		guard let name = runningApp.localizedName ?? runningApp.bundleIdentifier else {
			throw OpenableAppError.noName
		}
		guard let bundleUrl = runningApp.bundleURL else {
			throw OpenableAppError.noBundleUrl
		}
		self.bundleId = bundleId
		self.icon = icon
		self.runningApplication = runningApp
		self.appOpeningMethod = appOpeningMethod
		self.bundleUrl = bundleUrl
		self.name = name
 	}

	func open() {
		showOpeningAppWarningIfNeeded()
		if bundleId == Constants.App.finderBundleId {
			openFinder()
			return
		}
		openRegularApp()
	}

	func quit() {
		let wasTerminated = runningApplication?.terminate() // needs app sandbox off or explicit com.apple.security.temporary-exception.apple-events entitlement for the specific app
		print("App \(bundleId) termination success status: ", wasTerminated ?? "null")
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
		guard let runningApplication = runningApplication else { return }
		runningApplication.activate(options: .activateIgnoringOtherApps)
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

	private func openRegularApp() {
		if appOpeningMethod == .activate, runningApplication != nil {
			activateApp()
		} else {
			launchApp()
		}
	}

	private func launchApp() {
		if #available(OSX 10.15, *) {
			let config = NSWorkspace.OpenConfiguration()
			config.activates = true
			NSWorkspace.shared.openApplication(at: bundleUrl, configuration: config) { (runningApp, error) in
				print("launchApp running app: ", runningApp?.bundleIdentifier ?? "none", "error: ", error ?? "none")
			}
		} else {
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) // old way
		}
	}

	private func activateApp() {
		guard let runningApp = runningApplication else { return }
		runningApp.activate(options: [.activateIgnoringOtherApps]) // I removed .activateAllWindows, but if that proves to be a problem, add it back to the options array
	}

	private func showOpeningAppWarningIfNeeded() {
		// allows us to fail gracefully and alert the developer
		if appOpeningMethod == .activate && runningApplication == nil {
			let warningMsg = "The app opening method is 'activate' for app \(bundleId) but there is no running app, so launched it instead! This shouldn't happen"
			print(warningMsg)
		}
	}
}

enum AppOpeningMethod: String {
	case launch = "launch"
	case activate = "activate"
}

enum OpenableAppError: Error {
	case noBundleId // we need a bundleId to launch the app, so throwing an error if there isn't one is fine
	case noIcon // we need an icon to show something in the menu bar, so throwing an error is fine if there isn't one.
	case noName // we need some kind of name
	case noBundleUrl // we need this for the exact path of the app, so we open the correct version
}

extension OpenableApp: Reorderable {
	var orderElement: OrderElement { // so we can order using another array of bundleIds
		bundleId
	}

	typealias OrderElement = String
}
