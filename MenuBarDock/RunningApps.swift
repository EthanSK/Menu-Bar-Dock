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
	var maxNumRunningApps: Int { get }
}

protocol RunningAppsDelegate: AnyObject {
	func runningAppWasActivated(_ runningApp: NSRunningApplication)
	func runningAppWasQuit(_ runningApp: NSRunningApplication)
}

class RunningApps {
	public var apps: [RunningApp] = [] // state not getter for efficiency, will be ordered correctly

	private var ordering: [String] = [] // array of ids least to most recently activated

	weak var userPrefsDataSource: RunningAppsUserPrefsDataSource!
	weak var delegate: RunningAppsDelegate?

	init(
		userPrefsDataSource: RunningAppsUserPrefsDataSource
	) {
		self.userPrefsDataSource = userPrefsDataSource
		populateApps()
		ordering = apps
			.filter { $0.app.bundleURL != nil }
			.map { $0.app.bundleURL!.absoluteString } // populate the ordering array so the openable apps can start displaying correct order from the start
		trackAppsBeingActivated()
		trackAppsBeingQuit()
	}

	func update() {
		// update for user preference change for example
		populateApps()
	}

	private func populateApps() {
		apps = NSWorkspace.shared.runningApplications
			.map { RunningApp(app: $0) }
			.filter {canShowRunningApp(app: $0)}
			.reorder(by: ordering)
	}

	private func canShowRunningApp(app: RunningApp) -> Bool {
		if app.app.activationPolicy != .regular {return false}
		if app.app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDataSource.hideFinderFromRunningApps {return false}
		if userPrefsDataSource.hideActiveAppFromRunningApps == false {return true} else {return app.app != NSWorkspace.shared.frontmostApplication}
	}

	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if
				let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
				NSWorkspace.shared.frontmostApplication == app // make sure it wasn't triggered by some background process
			{
				let runningApp = RunningApp(app: app)
				self.ordering.removeAll(where: { $0 == runningApp.id })
				self.ordering.append(runningApp.id) // needs this order for it to populate from the most helpful side correctly
				self.populateApps()
 				self.delegate?.runningAppWasActivated(app)
			}
		}
	}

	private func trackAppsBeingQuit() {
		let a = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				let runningApp = RunningApp(app: app)

				self.ordering.removeAll(where: { $0 == runningApp.id })
				self.populateApps()
 				self.delegate?.runningAppWasQuit(app)
			}
		}
		NSWorkspace.shared.notificationCenter.removeObserver(a)
	}

}

enum RunningAppsSortingMethod: Int {
	case mostRecentOnRight = 0
	case mostRecentOnLeft = 1
	case consistent = 2
}
