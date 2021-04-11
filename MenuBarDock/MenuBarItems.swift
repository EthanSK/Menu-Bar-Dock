//
//  MenuBarItems.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 10/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol MenuBarItemsUserPrefsDelegate: AnyObject {
	var appOpeningMethods: [String: AppOpeningMethod] { get }
	var maxNumItems: Int { get }
	var itemWith: CGFloat { get }
	var iconSize: CGFloat { get }
	func didSetAppOpeningMethod(_ method: AppOpeningMethod, _ app: OpenableApp)

}

protocol MenuBarItemsPreferencesDelegate: AnyObject {
	func didOpenPreferencesWindow()
}


class MenuBarItems {
	weak var userPrefsDelegate: MenuBarItemsUserPrefsDelegate!
	weak var preferencesDelegate: MenuBarItemsPreferencesDelegate!

	private var items: [MenuBarItem] { //ordered left to right
		didSet {
			items = items.sorted {$0.position < $1.position}
		}
	}	
	
	init(
		userPrefsDelegate: MenuBarItemsUserPrefsDelegate,
		preferencesDelegate: MenuBarItemsPreferencesDelegate
	) {
		self.userPrefsDelegate = userPrefsDelegate
		self.preferencesDelegate = preferencesDelegate
		items = []
	}
	
	func update(
		apps: [OpenableApp],
		maxNumItems: Int,
		itemWidth: CGFloat,
		iconSize: CGFloat
	){
		let itemCount = items.count
		for i in 0...apps.count {
			if i > maxNumItems { return }
			let app = apps[i]
			
			if i >= itemCount{
				items.append(
					MenuBarItem(
						statusItem: NSStatusBar.system.statusItem(withLength: itemWidth),
						userPrefsDelegate: self,
						preferencesDelegate: self
					)
				)
			}
			items[i].update(for: app, iconSize: iconSize, slotWidth: itemWidth)
		}
	}
}

extension MenuBarItems: MenuBarItemUserPrefsDelegate {
	func getAppOpeningMethod(_ app: OpenableApp) -> AppOpeningMethod {
		return userPrefsDelegate.appOpeningMethods[app.bundleId] ?? UserPrefsDefaultValues.defaultAppOpeningMethod
	}
	
	func didSetAppOpeningMethod(_ method: AppOpeningMethod, _ app: OpenableApp) {
		userPrefsDelegate.didSetAppOpeningMethod(method, app)
	}
	
	
}

extension MenuBarItems: MenuBarItemPreferencesDelegate {
	func didOpenPreferencesWindow() {
		preferencesDelegate.didOpenPreferencesWindow()
	}
}
