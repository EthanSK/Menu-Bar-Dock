//
//  RegularApp.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 13/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class RegularApp {
	public var bundle: Bundle
	public var icon: NSImage
	public var name: String
	public var runningApp: NSRunningApplication? // once we open a regular app, it will be running, and so we want to show options for running apps in the dropdown menu such as 'quit'

	var id: String {
		bundle.bundleURL.absoluteString
	}

	init(
		bundle: Bundle,
		icon: NSImage,
		name: String
	) {
		self.bundle = bundle
		self.icon = icon
		self.name = name
	}

}
