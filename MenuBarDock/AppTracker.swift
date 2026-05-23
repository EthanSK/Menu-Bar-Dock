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
			guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
				return
			}
			// Activation gate — filter out background-process activations that aren't
			// "this app just came to the front". Pre-Sonoma the cleanest signal was
			// `NSWorkspace.shared.frontmostApplication == app`, but on macOS 14+ the
			// cooperative activation model means `frontmostApplication` isn't always
			// updated synchronously with this notification — the equality check then
			// silently drops legit foreground activations and the "most recent"
			// sort appears frozen. On Sonoma+ we instead trust the notification's
			// payload directly and filter by `activationPolicy == .regular`, which
			// matches the same filter the visible-dock path uses
			// (RunningApps.canShowRunningApp:74). On older OSes we keep the
			// original guard since it was working there.
			let isForegroundActivation: Bool
			if #available(macOS 14.0, *) {
				isForegroundActivation = (app.activationPolicy == .regular)
			} else {
				isForegroundActivation = (NSWorkspace.shared.frontmostApplication == app)
			}
			if isForegroundActivation {
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
