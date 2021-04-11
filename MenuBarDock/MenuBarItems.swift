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

	func update(
		openableApps: OpenableApps
	) {
		createEnoughStatusItems(openableApps: openableApps)

		sortItems() // sort after adding them all for efficiency
		print("number of apps: ", openableApps.apps.count)
		for (index, app) in openableApps.apps.enumerated() {
			let item = items[index]
			item.statusItem.title = String(index) // TODO: - remove
			showItem(item: item)
 			item.update(for: app, appIconSize: userPrefsDelegate.appIconSize, slotWidth: userPrefsDelegate.statusItemWidth)
		}

		for index in openableApps.apps.count...items.count - 1 { // loop over the rest of the status items that didn't get assigned an app, and hide them
			let item = items[index]
			hideItem(item: item)
		}

	}

	private func createEnoughStatusItems(openableApps: OpenableApps) {
		let origItemCount = items.count
		for index in 0...openableApps.apps.count where index >= origItemCount { // we loop to count not count - 1 so the sort order is always correct in advance https://trello.com/c/Jz312bga
			let statusItem = NSStatusBar.system.statusItem(withLength: userPrefsDelegate.statusItemWidth)
			statusItem.button?.superview?.needsLayout = true
			statusItem.button?.superview?.layout()
			statusItem.button!.superview!.window!.layoutIfNeeded()
			statusItem.button!.superview!.layoutSubtreeIfNeeded()
			statusItem.button!.superview!.layout()
			statusItem.button!.window!.displayIfNeeded()
			statusItem.button?.superview?.window?.update()
			items.append(
				MenuBarItem(
					statusItem: statusItem,
					userPrefsDelegate: self,
					preferencesDelegate: self
				)
			)// it's important we never remove items, or the position in the menu bar will be reset. only add if needed, and reuse.
			items[index].statusItem.title = "E-" + String(index) // E for empty //TODO: - remove
		}
	}

	private func hideItem(item: MenuBarItem) {
		if #available(OSX 10.12, *) {
			item.statusItem.isVisible = false
		} else {
			item.statusItem.length = 0
		}
	}

	private func showItem(item: MenuBarItem) {
		if #available(OSX 10.12, *) {
			item.statusItem.isVisible = true
		} else {
			item.statusItem.length = userPrefsDelegate.statusItemWidth
		}
	}

	private func sortItems() {
		print("before: ", items.map {$0.position})
		items = items.sorted {$0.position < $1.position}
		print("after: ", items.map {$0.position})
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
