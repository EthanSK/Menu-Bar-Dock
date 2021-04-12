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
	var statusItemWidth: CGFloat { get }
	var appIconSize: CGFloat { get }
	func didSetAppOpeningMethod(_ method: AppOpeningMethod, _ app: OpenableApp)

}

protocol MenuBarItemsPreferencesDelegate: AnyObject {
	func didOpenPreferencesWindow()
}

class MenuBarItems {
	weak var userPrefsDelegate: MenuBarItemsUserPrefsDelegate!
	weak var preferencesDelegate: MenuBarItemsPreferencesDelegate!

	private(set) var items: [MenuBarItem] // ordered left to right

	init(
		userPrefsDelegate: MenuBarItemsUserPrefsDelegate,
		preferencesDelegate: MenuBarItemsPreferencesDelegate
	) {
		self.userPrefsDelegate = userPrefsDelegate
		self.preferencesDelegate = preferencesDelegate
		items = []
	}

	/*
	KNOWN ISSUE: After opening some apps, then closing some, there will be a gap of
	empty space where the items of length 0 are (because they are trying to be hidden).
	There is nothing currently we can do to stop this, the alternative is using statusItem.isVisible = false,
	but then that causes the items to not restore to their correct, user-defined positions on the menu
	bar...It is therefore recommended to only drag N apps to the right, where N is a
	relatively small number that is ideally less than the number of apps you would tend
	to have running at any given time
	*/
	func update(
		openableApps: OpenableApps
	) {
		createEnoughStatusItems(openableApps: openableApps)
		sortItems() // sort after adding them all for efficiency. not all of them will be sorted due to layout not updating instantly, but that's fine since we have an extra item at all times.

		// try and populate the rightmost items since new ones are added to the left of the menu bar
		for (index, app) in openableApps.apps.enumerated() {
			let offset = items.count - openableApps.apps.count
			let item = items[index + offset]
			showItem(item: item)
			item.update(for: app, appIconSize: userPrefsDelegate.appIconSize, slotWidth: userPrefsDelegate.statusItemWidth)
		}

		// hide the leftmost items not being used (so the weird gap glitch is as left as possible)
		for index in 0...items.count - openableApps.apps.count - 1 {
			let item = items[index]
			hideItem(item: item)
		}
	}

	private func createEnoughStatusItems(openableApps: OpenableApps) {
		let origItemCount = items.count
		for index in 0...openableApps.apps.count where index >= origItemCount { // we loop to count not count - 1 so the sort order is always correct as it has sorted one item in advance. https://trello.com/c/Jz312bga
			let statusItem = NSStatusBar.system.statusItem(withLength: userPrefsDelegate.statusItemWidth)
			let item = MenuBarItem(
				statusItem: statusItem,
				userPrefsDelegate: self,
				preferencesDelegate: self
			)
			items.append(item)// it's important we never remove items, or the position in the menu bar will be reset. only add if needed, and reuse.
		}
	}

	private func hideItem(item: MenuBarItem) {

		item.statusItem.length = 0
		if #available(OSX 10.12, *) {
			// item.statusItem.isVisible = false // this prevents the item from remembering its position. Thanks Apple.
		}
	}

	private func showItem(item: MenuBarItem) {
		item.statusItem.length = userPrefsDelegate.statusItemWidth

		if #available(OSX 10.12, *) {
			item.statusItem.isVisible = true // Don't remove this, no harm, only has benefits
		}
	}

	private func sortItems() { // sorts items array such that order matches that of actual status items being displayed
		items = items.sorted {$0.position < $1.position}
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
