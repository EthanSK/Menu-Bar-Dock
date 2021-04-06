//
//  Shared.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class MenuBarDock: NSObject {
	
	static let shared = MenuBarDock()
	
	var appManager: AppManager
	var statusItemManager: StatusItemManager
	var userPrefs: UserPrefs
	
	private override init() {
		userPrefs = UserPrefs() //do this first so it loads in the values 
		appManager = AppManager()
		statusItemManager = StatusItemManager()
		super.init()

	}
}
