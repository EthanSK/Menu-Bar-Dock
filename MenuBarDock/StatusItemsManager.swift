//
//  StatusItemsManager.swift
//  MenuBarDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class StatusItemsManager: NSObject {

	var statusItems: [NSStatusItem] // this will contain even the ones that are 0 width coz they shouldn't be there

	var statusItemsBeingDisplayedInOrder: [NSStatusItem] { // mutating order of most to least active. gets the order based on the existing sorted position.
		let filtered = statusItems.filter {$0.length != 0}
		switch MenuBarDock.shared.userPrefs.sortingMethod {
		case .mostRecentOnRight:
			return filtered.sorted {$0.button!.superview!.window!.frame.minX > $1.button!.superview!.window!.frame.minX} // item at index 0 is rightmost
		case .mostRecentOnLeft:
			return filtered.sorted {$0.button!.superview!.window!.frame.minX < $1.button!.superview!.window!.frame.minX} // item at index 0 is rightmost
		case .consistent:
			return filtered // don't be fooled, the actual ordering takes place in runningAppsInOrder in appmanager.swift
		}
	}

	override init() {
		statusItems = []
		super.init()
	}

	private func addStatusItem() {
		let statusItem = NSStatusBar.system.statusItem(withLength: MenuBarDock.shared.userPrefs.widthOfStatusItem)
		statusItems.append(statusItem)
	}

	@objc public func updateStatusItems() {
		correctVisibleNumberOfStatusItems() // in case there are fewer running apps that status items in place.
		for item in MenuBarDock.shared.statusItemManager.statusItems {
			item.button?.wantsLayer = true
			item.button?.action = statusButtonPressed // doing this coz if the item was re-added, it needs this assosiated with it.
			item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		var count = 0
		for item in MenuBarDock.shared.statusItemManager.statusItemsBeingDisplayedInOrder {
			if count >= MenuBarDock.shared.appManager.runningAppsInOrder.count {// then we need to hide it
				return // all other i's will be higher and will fail too
			}
			let image = MenuBarDock.shared.appManager.runningAppsInOrder[count].icon
			let imageSize = MenuBarDock.shared.userPrefs.iconSize
			image?.size = NSSize(width: imageSize, height: imageSize)
			item.button?.appearance = NSAppearance(named: .aqua) // so the full colour of the icon is shown
			//			item.button?.image = image //this casuse it to show as completely blank on secondary monitors. have to set view manually
			let itemSlotWidth = MenuBarDock.shared.userPrefs.widthOfStatusItem
			let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 22

			let view = NSImageView(frame: NSRect(
									x: (itemSlotWidth - imageSize) / 2,
									y: -(imageSize - menuBarHeight) / 2,
									width: imageSize, height: imageSize)) // constructing image view from image is only available on macos >= 10.12
			view.image = image
			view.wantsLayer = true
			//			view.layer?.backgroundColor = NSColor.yellow.cgColor
			if let existingSubview = item.button?.subviews.first as? NSImageView {
				//				existingSubview.image = image
				item.button?.replaceSubview(existingSubview, with: view) // we have to replace it to get the correct sizing
			} else {
				item.button?.addSubview(view)
			}

			item.length = itemSlotWidth
			let bundleId = MenuBarDock.shared.appManager.runningAppsInOrder[count].bundleIdentifier ?? MenuBarDock.shared.appManager.runningAppsInOrder[count].localizedName // ?? just in case
			item.button?.layer?.setValue(bundleId, forKey: Constants.UserDefaultsKeys.bundleId) // layer doesn't exist on view did load. it takes some time to load for some reason so i guess we gotta add a timer
			count += 1
		}
	}

	private func correctVisibleNumberOfStatusItems() { // this will add or remove status items according to the number of running apps open
		let numberThereShouldBe = min(MenuBarDock.shared.userPrefs.numberOfStatusItems, MenuBarDock.shared.appManager.runningAppsInOrder.count)

		while statusItemsBeingDisplayedInOrder.count > numberThereShouldBe { // not too many

			if statusItems.count > MenuBarDock.shared.userPrefs.numberOfStatusItems {
				statusItems.removeLast()
			} else {
				// else just make the width 0 because we know it will reappear at some point, and if we remove it it will reset the position on the menu bar
				statusItems.filter {$0.length != 0}.last?.length = 0
			}
		}
		while statusItemsBeingDisplayedInOrder.count < numberThereShouldBe { // not too cold (not too few)

			if statusItems.count < MenuBarDock.shared.userPrefs.numberOfStatusItems {
				addStatusItem()
			} else {
				statusItems.filter {$0.length == 0}.first?.length = MenuBarDock.shared.userPrefs.widthOfStatusItem // re-add the first one that isn't zero. it's like a stack
			}
		}
	}

}
