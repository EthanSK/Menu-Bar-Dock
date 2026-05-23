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
				// macOS 14+ (Sonoma/Sequoia/26): `frontmostApplication` is no longer
				// updated synchronously with this notification under the cooperative-
				// activation model, so the old equality check silently dropped legit
				// activations. Filter via activationPolicy instead — the visible-dock
				// path already filters .regular at RunningApps.swift:74, so this
				// preserves the original "skip background processes" intent without
				// the timing race.
				app.activationPolicy == .regular
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
