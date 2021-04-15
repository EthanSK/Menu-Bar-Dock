//
//  AppTracker.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 15/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol AppTrackerDelegate: AnyObject {
	func appWasActivated(runningApp: NSRunningApplication)
	func appWasQuit(runningApp: NSRunningApplication)
}

// tracks app activations and quits
class AppTracker {

	public weak var delegate: AppTrackerDelegate?

	init() {
		trackAppsBeingActivated()
		trackAppsBeingQuit()
	}
	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if
				let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
				NSWorkspace.shared.frontmostApplication == app // make sure it wasn't triggered by some background process
			{
				self.delegate?.appWasActivated(runningApp: app)
			}
		}
	}

	private func trackAppsBeingQuit() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				self.delegate?.appWasQuit(runningApp: app)
			}
		}
	}
}
