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
	var runningAppsSortingMethod: RunningAppsSortingMethod { get }
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
		ordering = apps.map { $0.id } // populate the ordering array so the openable apps can start displaying correct order from the start.
		// the reason it's not ordered straight away: https://trello.com/c/ZFs3C32g
		trackAppsBeingActivated()
		trackAppsBeingQuit()
	}

	func update() {
		// update for user preference change for example
		populateApps()
	}

	private func populateApps() {
		let newApps = NSWorkspace.shared.runningApplications
			.map { RunningApp(app: $0) }
			.filter {canShowRunningApp(app: $0)}
			.reorder(by: correctedOrdering())
		apps = Array(limitNumApps(apps: newApps))
	}

	private func canShowRunningApp(app: RunningApp) -> Bool {
		if app.app.activationPolicy != .regular {return false}
		if app.app.bundleIdentifier == Constants.App.finderBundleId && userPrefsDataSource.hideFinderFromRunningApps {return false}
		if userPrefsDataSource.hideActiveAppFromRunningApps == false {return true} else {return app.app != NSWorkspace.shared.frontmostApplication}
	}

	private func correctedOrdering() -> [String] {
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			return ordering
		case .mostRecentOnLeft:
			return ordering.reversed()
		case .consistent:
			return ordering.sorted {$0 < $1} // fixed alphabetical ordering
		}
	}

	private func limitNumApps(apps: [RunningApp]) -> ArraySlice<RunningApp> {
		switch userPrefsDataSource.runningAppsSortingMethod {
		case .mostRecentOnRight:
			return apps.suffix(userPrefsDataSource.maxNumRunningApps)
		case .mostRecentOnLeft:
			return apps.prefix(userPrefsDataSource.maxNumRunningApps)
		default:
			return apps.suffix(userPrefsDataSource.maxNumRunningApps) // doesn't matter for this, because it doesn't really make sense anyway
		}
	}

	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if
				let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
				NSWorkspace.shared.frontmostApplication == app // make sure it wasn't triggered by some background process
			{
				let runningApp = RunningApp(app: app) // to get id
				self.ordering.removeAll(where: { $0 == runningApp.id })
				self.ordering.append(runningApp.id) // needs this order for it to populate from the most helpful side correctly
				self.populateApps()
 				self.delegate?.runningAppWasActivated(app)
			}
		}
	}

	private func trackAppsBeingQuit() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				let runningApp = RunningApp(app: app) // to get id
				self.ordering.removeAll(where: { $0 == runningApp.id })
				self.populateApps()
 				self.delegate?.runningAppWasQuit(app)
			}
		}
	}

}

enum RunningAppsSortingMethod: Int {
	case mostRecentOnRight = 0
	case mostRecentOnLeft = 1
	case consistent = 2
}

enum SideToShowRunningApps: String {
	case left = "left"
	case right = "right"
}
