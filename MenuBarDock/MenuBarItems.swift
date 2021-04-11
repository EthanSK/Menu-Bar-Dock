//
//  MenuBarItems.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 10/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class MenuBarItems {
	
	private var items: [MenuBarItem] { //ordered left to right
		didSet {
			items = items.sorted {$0.position < $1.position}
		}
	}
	
	init() {
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
				items.append(MenuBarItem(statusItem: NSStatusBar.system.statusItem(withLength: itemWidth)))
			}
			
			items[i].update(bundleId: app.bundleId, image: app.icon, iconSize: iconSize, slotWidth: itemWidth)
		}
	}
}
