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
	func appWasLaunched(runningApp: NSRunningApplication)
	func appWasQuit(runningApp: NSRunningApplication)
}

// tracks app activations, launches and quits
class AppTracker {
	public weak var delegate: AppTrackerDelegate?

	init() {
		trackAppsBeingActivated()
		trackAppsBeingLaunched()
		trackAppsBeingQuit()
	}

    /// Refreshes instance badges when an app starts without taking focus.
    private func trackAppsBeingLaunched() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.activationPolicy == .regular {
                self.delegate?.appWasLaunched(runningApp: app) // Background launches do not send activation notifications, but must update the numbered instance set.
            }
        }
    }

	private func trackAppsBeingActivated() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
				DebugLog.shared.log("[activate] notification with NO app payload (ignored)")
				return
			}
			// Log EVERY activation, including accessory/LSUIElement apps. The
			// v4.7.5 post-mortem identified that dropping their notifications left
			// lastActivatedApp stale, so the hide-active-app filter hid the wrong
			// app. Forward every activation below; RunningApps keeps display and
			// recency eligibility separate from the current active-app truth.
			let policyStr: String
			switch app.activationPolicy {
			case .regular: policyStr = "regular"
			case .accessory: policyStr = "accessory"
			case .prohibited: policyStr = "prohibited"
			@unknown default: policyStr = "unknown"
			}
			DebugLog.shared.log("[activate] \(app.localizedName ?? "?") bundle=\(app.bundleIdentifier ?? "?") policy=\(policyStr) -> INGESTED")
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
			// in front. RunningApps.canShowRunningApp still filters the visible list
			// to .regular apps, and its activation handler only reorders those apps.
			// Every activation must reach lastActivatedApp so a menu-bar app taking
			// focus makes the previously active app visible again. Applied uniformly
			// — no macOS-version split.
			self.delegate?.appWasActivated(runningApp: app)
		}
	}

	private func trackAppsBeingQuit() {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				DebugLog.shared.log("[quit] \(app.localizedName ?? "?") bundle=\(app.bundleIdentifier ?? "?")")
				self.delegate?.appWasQuit(runningApp: app)
			}
		}
	}
}
