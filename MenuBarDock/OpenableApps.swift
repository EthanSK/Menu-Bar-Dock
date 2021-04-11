//
//  OpenableApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol OpenableAppsUserPrefsDelegate: AnyObject {
	var appOpeningMethods: [String: AppOpeningMethod] { get }
	var hideFinderFromRunningApps: Bool { get }
	var hideActiveAppFromRunningApps: Bool { get }

}

class OpenableApps {
	var apps: [OpenableApp] = []

	weak var userPrefsDelegate: OpenableAppsUserPrefsDelegate!

	init(
		userPrefsDelegate: OpenableAppsUserPrefsDelegate
	) {
		self.userPrefsDelegate = userPrefsDelegate
		initApps()
	}

	private func initApps() {
		for runningApp in runningApps() {
			guard let bundleId = runningApp.bundleIdentifier else { continue }

			let openableApp = try? OpenableApp(
				runningApp: runningApp,
				appOpeningMethod: userPrefsDelegate.appOpeningMethods[bundleId] ?? UserPrefsDefaultValues.defaultAppOpeningMethod
			)
			if let openableApp = openableApp {
				apps.append(openableApp)
			}
		}
	}

	private func runningApps() -> [NSRunningApplication] {
		return NSWorkspace.shared.runningApplications.filter {canShowRunningApp(app: $0)}
	}

	private func canShowRunningApp(app: NSRunningApplication) -> Bool {
		if app.activationPolicy != .regular {return false}
		if app.bundleIdentifier == Constants.App.finderBundleId {return !userPrefsDelegate.hideFinderFromRunningApps}
		if userPrefsDelegate.hideActiveAppFromRunningApps == false {return true} else {return app != NSWorkspace.shared.frontmostApplication}
	}

//	private func trackAppsBeingActivated() {// to allow us to form some sort of order in the menu bar
//		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
//			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, NSWorkspace.shared.frontmostApplication == app { // make sure it wasn't triggered by some background process
//				self.appActivationsTracked.insert(app, at: 0)
//				updated(notification)
//			}
//		}
//	}
//
//	private func trackAppsBeingQuit() {
//		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
//			terminated(notification) // handle the updating in the calling closure
//		}
//	}

}
