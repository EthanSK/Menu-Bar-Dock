//
//  OpenableApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class OpenableApp {
	var bundleId: String
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

	private func openFinder() {
		NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) // do this as well if it's hidden
		guard let runningApp = runningApplication else { return }
		runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) // this is the only way I can get working to show the finder app
	}

	private func openRegularApp() {
		if appOpeningMethod == .activate, let runningApp = runningApplication {
			runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
		} else {
			// we still want to try and get it to work as much as possible, we can show a warning if there is an issue after
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
		}
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
	case noBundleUrl // do we NEED this? don't think so but for now we can throw
}
