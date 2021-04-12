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

	let autosaveNamePrefix = "3autoSave-"

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

		sortItems() // sort after adding them all for efficiency. not all of them will be sorted due to layout not updating instantly, but that's fine since we have an extra item at all times.
		print("number of apps: ", openableApps.apps.count)
		print("number of menu bar items: ", items.count)

		// try and populate the rightmost items since new ones are added to the left of the menu bar
		for (index, app) in openableApps.apps.enumerated() {
			let offset = items.count - openableApps.apps.count
			let item = items[index + offset]

			if #available(OSX 10.12, *) {
				item.statusItem.title = String(index) + "a" + String(item.statusItem.autosaveName.split(separator: "-")[1])
			}// TODO: - remove

 			showItem(item: item)

// 			item.update(for: app, appIconSize: userPrefsDelegate.appIconSize, slotWidth: userPrefsDelegate.statusItemWidth)
		}

		// hide the leftmost items not being used
		for index in 0...items.count - openableApps.apps.count - 1 {
 			let item = items[index]
			if #available(OSX 10.12, *) {
				item.statusItem.title = String(index) + "h" + String(item.statusItem.autosaveName.split(separator: "-")[1])
			}
 			hideItem(item: item)

		}

	}

	private func createEnoughStatusItems(openableApps: OpenableApps) {
		let origItemCount = items.count
		for index in 0...openableApps.apps.count where index >= origItemCount { // we loop to count not count - 1 so the sort order is always correct in advance https://trello.com/c/Jz312bga
			let statusItem = NSStatusBar.system.statusItem(withLength: userPrefsDelegate.statusItemWidth)
			let item = MenuBarItem(
				statusItem: statusItem,
				   userPrefsDelegate: self,
				   preferencesDelegate: self
			   )
			items.append(item)// it's important we never remove items, or the position in the menu bar will be reset. only add if needed, and reuse.
			print("creating status item idx: ", index)
			// self.setAutosaveName(item: item, name: autosaveNamePrefix + String(index))
			if #available(OSX 10.12, *) {
				print("autosave name: ", item.statusItem.autosaveName)
			} else {
				// Fallback on earlier versions
			}
			statusItem.title = "E" + String(index) // TODO: - remove
		}
	}

	private func setAutosaveName(item: MenuBarItem, name: String) {
		if #available(OSX 10.12, *) {
			item.statusItem.autosaveName = name // i think there might be a delay when doing this, so only do it when spawning them
 		}
	}

	private func hideItem(item: MenuBarItem) {
		item.statusItem.length = 0
 		if #available(OSX 10.12, *) {
//			item.statusItem.isVisible = false // this gets stored by the OS, and will restore its value when loaded up

		}
	}

	private func showItem(item: MenuBarItem) {
		item.statusItem.length = userPrefsDelegate.statusItemWidth
		if #available(OSX 10.12, *) {
			item.statusItem.isVisible = true // NEVER uncomment
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
