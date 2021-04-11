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
	var runningApp: NSRunningApplication?
	var appOpeningMethod: AppOpeningMethod
	
	init(bundleId: String, icon: NSImage) {
		self.bundleId = bundleId
		self.icon = icon
	}
	
	init(runningApp: NSRunningApplication) throws {
		guard let bundleId = runningApp.bundleIdentifier else {
			throw OpenableAppError.noBundleId
		}
		guard let icon = runningApp.icon else {
			throw OpenableAppError.noIcon
		}
		self.bundleId = bundleId
		self.icon = icon
		self.runningApp = runningApp
	}
	
	func open(){
		showWarningIfNeeded()
		if bundleId == Constants.App.finderBundleId {
			openFinder()
			return
 		}
	}
	
	private func openFinder(){
		NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) // do this as well if it's hidden
		guard let runningApp = runningApp else { return }
		runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) // this is the only way I can get working to show the finder app
	}
	
	private func openRegularApp(){
		if appOpeningMethod == .activate, let runningApp = runningApp{
			runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
		} else {
			//we still want to try and get it to work as much as possible, we can show a warning if there is an issue after
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
		}
	}
	
	private func showWarningIfNeeded(){
		//allows us to fail gracefully and alert the developer
		if appOpeningMethod == .activate && runningApp == nil {
			let warningMsg = "The app opening method is 'activate' for app \(bundleId) but there is no running app, so launched it instead! This shouldn't happen"
			print(warningMsg)
		}
	}
}

enum AppOpeningMethod {
	case launch
	case activate
}


enum OpenableAppError: Error {
	case noBundleId //we need a bundleId to launch the app, so throwing an error if there isn't one is fine
	case noIcon //we need an icon to show something in the menu bar, so throwing an error is fine if there isn't one.
}
