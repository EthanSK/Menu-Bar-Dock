//
//  Constants.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

enum Constants {
	enum App{
		static let name = "Menu Bar Dock"
	}
	
	enum NSUserDefaultsKeys{
		static let bundleId = "bundleId"
	}
	
	enum UserPrefs{
		static let numberOfStatusItems = "numberOfStatusItems"
		static let widthOfStatusItem = "widthOfStatusItem"
		static let sortingMethod = "sortingMethod"
		static let iconSize = "iconSize"
		static let launchAtLogin = "launchAtLogin"
	}
}

enum SortingMethod: Int{
	case mostRecentOnRight = 0//newest active app on right
	case mostRecentOnLeft = 1
	case none = 2
}
