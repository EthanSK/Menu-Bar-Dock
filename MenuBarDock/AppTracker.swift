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
			// The notification payload (NSWorkspace.applicationUserInfoKey) IS the app
			// that just activated — it's authoritative and carries no race. We must
			// TRUST it directly.
			//
			// HISTORY / why we no longer read frontmostApplication here:
			// The old gate compared `NSWorkspace.shared.frontmostApplication == app`.
			// On macOS 14+ (Sonoma) the "cooperative activation" model means
			// `frontmostApplication` is NOT updated synchronously when THIS
			// notification fires — so the equality check intermittently returned
			// false for genuine foreground activations, the activation got dropped,
			// and the menu-bar "most recent" sort appeared frozen. That racy read is
			// removed on ALL macOS versions now (pre-14 was relying on the same racy
			// global read; trusting the payload is strictly more correct there too).
			//
			// `activationPolicy == .regular` is NOT a foreground test. activationPolicy
			// is a STATIC per-app capability (.regular / .accessory / .prohibited) —
			// many apps are .regular simultaneously, so it cannot tell us which app is
			// in front. We keep it ONLY as a cheap skip: apps that aren't .regular will
			// never be displayed in the dock anyway (RunningApps.canShowRunningApp
			// filters .regular again), so there's no point churning the recency
			// ordering for them. Applied uniformly — no macOS-version split.
			if app.activationPolicy == .regular {
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
