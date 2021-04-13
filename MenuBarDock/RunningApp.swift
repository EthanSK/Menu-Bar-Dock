//
//  RunningApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 13/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class RunningApp {
	var app: NSRunningApplication
	var id: String {
		app.bundleURL?.absoluteString ?? "UNKNOWN" // should never be unknown, but if so, fail gracefully
	}

	init(app: NSRunningApplication) {
		self.app = app
	}
}

// needs to be orderable so we can cut off the first N apps correctly depending on the max num running apps
extension RunningApp: Reorderable {
	var orderElement: OrderElement { // so we can order using another array of bundleIds
		id
	}

	typealias OrderElement = String
}
