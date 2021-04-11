//
//  Model.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class AppManager: NSObject {

	override init() {
		appActivationsTracked = []
		super.init()
	}

	private var appActivationsTracked: [NSRunningApplication] {
		didSet {
			appActivationsTracked = appActivationsTracked.unique
		}
	}

	private var runningApps: [NSRunningApplication] {
		func canShowRunningApp(app: NSRunningApplication) -> Bool {
			if app.activationPolicy != .regular {return false}
			if app.bundleIdentifier == Constants.App.finderBundleId {return !MenuBarDock.shared.userPrefs.hideFinderFromRunningApps}
			if MenuBarDock.shared.userPrefs.hideActiveAppFromRunningApps == false {return true} else {return app != NSWorkspace.shared.frontmostApplication}
		}
		return NSWorkspace.shared.runningApplications.filter {canShowRunningApp(app: $0)}
	}

	func effectiveAppName(_ app: NSRunningApplication) -> String {
		return app.localizedName ?? app.bundleIdentifier!
	}

	var runningAppsInOrder: [NSRunningApplication] {// will use appActivationsTracked to try and form the best order it can
		var result: [NSRunningApplication] = []

 		let runningApps = self.runningApps // so we don't recalc every time func is invoked. it's a set for efficiency

		if MenuBarDock.shared.userPrefs.runningAppsSortingMethod == .consistent {
			return runningApps.sorted {effectiveAppName($0) > effectiveAppName($1)}
		}
		for appActivated in appActivationsTracked { // first add the apps we have ordering info of AND that we know are running
			if runningApps.contains(appActivated) {
				result.append(appActivated)
 			}
		}
		for runningApp in runningApps { // then add the remaining apps we had no ordering info for (because we just started up menu bar dock and it hasn't tracked the activations)
			if !result.contains(runningApp) {
				result.append(runningApp)
			}
		}

		return result
	}

	func trackAppsBeingActivated(updated: @escaping (_ notification: Notification) -> Void) {// to allow us to form some sort of order in the menu bar
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
			if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, NSWorkspace.shared.frontmostApplication == app { // make sure it wasn't triggered by some background process
				self.appActivationsTracked.insert(app, at: 0)
				updated(notification)
			}
		}
	}

	func trackAppsBeingQuit(terminated: @escaping (_ notification: Notification) -> Void) {
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
 			terminated(notification) // handle the updating in the calling closure
		}
	}

 
}
