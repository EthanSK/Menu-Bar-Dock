//
//  MenuBarItems.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 10/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol MenuBarItemsUserPrefsDataSource: AnyObject {
	var appOpeningMethods: [String: AppOpeningMethod] { get }
	var itemSlotWidth: CGFloat { get }
	var appIconSize: CGFloat { get }
    var preserveAppOrder: Bool { get }
    var rightClickByDefault: Bool { get }
}

protocol MenuBarItemsDelegate: AnyObject {
	func didOpenPreferencesWindow()
	func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp)
}

class MenuBarItems {
	public weak var userPrefsDataSource: MenuBarItemsUserPrefsDataSource!
	public weak var delegate: MenuBarItemsDelegate?

	private(set) var items: [MenuBarItem] // ordered left to right

	init(
		userPrefsDataSource: MenuBarItemsUserPrefsDataSource
 	) {
		self.userPrefsDataSource = userPrefsDataSource
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
			item.update(for: app, appIconSize: userPrefsDataSource.appIconSize, slotWidth: userPrefsDataSource.itemSlotWidth)
		}

		// hide the leftmost items not being used (so the weird gap glitch is as left as possible)
		for index in 0...items.count - openableApps.apps.count - 1 {
			let item = items[index]
			item.reset()
			hideItem(item: item)
		}
	}

	private func createEnoughStatusItems(openableApps: OpenableApps) {
		let origItemCount = items.count
		for index in 0...openableApps.apps.count where index >= origItemCount { // we loop to count not count - 1 so the sort order is always correct as it has sorted one item in advance. https://trello.com/c/Jz312bga
			let statusItem = NSStatusBar.system.statusItem(withLength: userPrefsDataSource.itemSlotWidth)
			let item = MenuBarItem(
				statusItem: statusItem,
                userPrefsDataSource: self
 			)
			item.delegate = self
			items.append(item)// it's important we never remove items, or the position in the menu bar will be reset. only add if needed, and reuse.
		}
	}

	private func hideItem(item: MenuBarItem) {
		item.statusItem.length = 0

		if #available(OSX 10.12, *) {
            if userPrefsDataSource.preserveAppOrder == false {
                item.statusItem.isVisible = false // this prevents the item from remembering its position. Thanks Apple.
            }
		}
	}

	private func showItem(item: MenuBarItem) {
		item.statusItem.length = userPrefsDataSource.itemSlotWidth

		if #available(OSX 10.12, *) {
			item.statusItem.isVisible = true // Don't remove this, no harm, only has benefits
		}
	}

	private func sortItems() { // sorts items array such that order matches that of actual status items being displayed
		items = items.sorted {$0.position < $1.position}
	}
}

extension MenuBarItems: MenuBarItemDataSource {
    var rightClickByDefault: Bool {
        return userPrefsDataSource.rightClickByDefault
    }

	func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod? {
		return userPrefsDataSource.appOpeningMethods[app.id]
	}
}

extension MenuBarItems: MenuBarItemDelegate {
	func didOpenPreferencesWindow() {
		delegate?.didOpenPreferencesWindow()
	}

	func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp) {
		delegate?.didSetAppOpeningMethod(method, app)
	}
}
