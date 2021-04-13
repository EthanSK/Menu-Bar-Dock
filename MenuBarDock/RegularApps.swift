//
//  RegularApps.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 12/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Foundation

class RegularApps { // regular apps are just apps that use user added manually
	public var apps: [String]  = []

	init() {
		populateApps()
	}

	private func populateApps() {
		let url = Bundle(url: URL(fileURLWithPath: "/System/Applications/Mail.app"))?.bundleURL
		print(url)
	}
}
