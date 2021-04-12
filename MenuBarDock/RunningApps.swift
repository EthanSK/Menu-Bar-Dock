//
//  RunningApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 12/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol RunningAppsUserPrefsDataSource: AnyObject {
 	var hideFinderFromRunningApps: Bool { get }
	var hideActiveAppFromRunningApps: Bool { get }

}

protocol RunningAppsDelegate: AnyObject {
	func runningAppWasActivated(_ runningApp: NSRunningApplication)
	func runningAppWasQuit(_ runningApp: NSRunningApplication)
}

class RunningApps {
	var apps: [NSRunningApplication] = [] // state not getter for efficiency

	private(set) var ordering: [String] = [] // array of bundleIds in order of least to most recently activated

	weak var userPrefsDataSource: RunningAppsUserPrefsDataSource!
	weak var delegate: RunningAppsDelegate?

	init(
		userPrefsDataSource: RunningAppsUserPrefsDataSource
	) {
		self.userPrefsDataSource = userPrefsDataSource
		populateApps()
		ordering = apps.filter { $0.bundleIdentifier != nil }.map { $0.bundleIdentifier! } // populate the ordering array so the openable apps can start displaying correct order from the start
		trackAppsBeingActivated()
		trackAppsBeingQuit()
	}

	private func populateApps() {
		apps = NSWorkspace.shared.runningApplications.filter {canShowRunningApp(app: $0)}
	}

	private func canShowRunningApp(app: NSRunningApplication) -> Bool {
		if app.activationPolicy != .regular {return false}
		if app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDataSource.hideFinderFromRunningApps {return false}
		if userPrefsDataSource.hideActiveAppFromRunningApps == false {return true} else {return app != NSWorkspace.shared.frontmostApplication}
	}

	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if
				let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
				NSWorkspace.shared.frontmostApplication == app, // make sure it wasn't triggered by some background process
				let bundleId = app.bundleIdentifier
			{
				self.populateApps()
				self.ordering.removeAll(where: { $0 == app.bundleIdentifier })
				self.ordering.append(bundleId) // needs this order for it to populate from the most helpful side correctly
 				self.delegate?.runningAppWasActivated(app)
			}
		}
	}

	private func trackAppsBeingQuit() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				self.populateApps()
				self.ordering.removeAll(where: { $0 == app.bundleIdentifier })
 				self.delegate?.runningAppWasQuit(app)
			}
		}
	}

}
