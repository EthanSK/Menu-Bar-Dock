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

protocol OpenableAppsDelegate: AnyObject {
	func runningAppWasActivated(_ runningApp: NSRunningApplication)
	func runningAppWasQuit(_ runningApp: NSRunningApplication)
}

class OpenableApps {
	var apps: [OpenableApp] = [] // ground truth for all apps to show, both running and non running, ordered left to right

	weak var userPrefsDelegate: OpenableAppsUserPrefsDelegate!
	weak var delegate: OpenableAppsDelegate!

	private var runningAppsOrder: [String] = [] // array of bundleIds in order of least to most recently activated

	init(
		delegate: OpenableAppsDelegate,
		userPrefsDelegate: OpenableAppsUserPrefsDelegate
	) {
		self.delegate = delegate
		self.userPrefsDelegate = userPrefsDelegate
		populateApps()
		trackAppsBeingActivated()
		trackAppsBeingQuit()
	}

	private func populateApps() {
		apps = []
		for runningApp in runningApps() {
			guard let bundleId = runningApp.bundleIdentifier else { continue }

			guard let openableApp = try? OpenableApp(
				runningApp: runningApp,
				appOpeningMethod: userPrefsDelegate.appOpeningMethods[bundleId] ?? UserPrefsDefaultValues.defaultAppOpeningMethod
			) else { continue }
			apps.append(openableApp)
		}
		apps = apps.reorder(by: appsOrder())
		print(apps.map {$0.bundleId})
	}

	private func runningApps() -> [NSRunningApplication] {
		return NSWorkspace.shared.runningApplications.filter {canShowRunningApp(app: $0)}
	}

	private func canShowRunningApp(app: NSRunningApplication) -> Bool {
		if app.activationPolicy != .regular {return false}
		if app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDelegate.hideFinderFromRunningApps {return false}
		if userPrefsDelegate.hideActiveAppFromRunningApps == false {return true} else {return app != NSWorkspace.shared.frontmostApplication}
	}

	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if
				let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
				NSWorkspace.shared.frontmostApplication == app, // make sure it wasn't triggered by some background process
				let bundleId = app.bundleIdentifier
			{
				self.runningAppsOrder.removeAll(where: { $0 == app.bundleIdentifier })
				self.runningAppsOrder.append(bundleId)
				self.populateApps()
				self.delegate.runningAppWasActivated(app)
			}
		}
	}

	private func trackAppsBeingQuit() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				self.runningAppsOrder.removeAll(where: { $0 == app.bundleIdentifier })
				self.populateApps()
				self.delegate.runningAppWasQuit(app)
			}
		}
	}

	private func appsOrder() -> [String] {
		// here we combine the order arrays of running and non running apps in a way determined by user prefs to get the final app order array
		return runningAppsOrder.reversed() // TODO: - change this to be correct
	}

}
