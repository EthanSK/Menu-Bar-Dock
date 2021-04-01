//
//  StatusItemManager.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 03/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class StatusItemManager: NSObject {
	
	var statusItems: [NSStatusItem] //this will contain even the ones that are 0 width coz they shouldn't be there
	
	var statusItemsBeingDisplayedInOrder: [NSStatusItem]{ //mutating order of most to least active. gets the order based on the existing sorted position.
		
		get{
			let filtered = statusItems.filter{$0.length != 0}
			switch MenuDock.shared.userPrefs.sortingMethod {
			case .mostRecentOnRight:
				return filtered.sorted{$0.button!.superview!.window!.frame.minX > $1.button!.superview!.window!.frame.minX} //item at index 0 is rightmost
			case .mostRecentOnLeft:
				return filtered.sorted{$0.button!.superview!.window!.frame.minX < $1.button!.superview!.window!.frame.minX} //item at index 0 is rightmost
			case .consistent:
				return filtered //don't be fooled, the actual ordering takes place in runningAppsInOrder in appmanager.swift
			}
		}	
	}
	
	override init(){
		statusItems = []
		super.init() 
	} 
	
	func addStatusItem(){
		let statusItem = NSStatusBar.system.statusItem(withLength: MenuDock.shared.userPrefs.widthOfStatusItem)
		//statusItem.menu = menu
		statusItems.append(statusItem)
	}
	

	func correctVisibleNumberOfStatusItems(){ //this will add or remove status items according to the number of running apps open
		let numberThereShouldBe = min(MenuDock.shared.userPrefs.numberOfStatusItems, MenuDock.shared.appManager.runningAppsInOrder.count)
		
		while statusItemsBeingDisplayedInOrder.count > numberThereShouldBe{ //not too hot
//			print("too many: ", statusItemsBeingDisplayedInOrder.count, numberThereShouldBe)
			//statusItems.filter{$0.length != 0}.last?.length = 0 //wait status items aren't in order here and we need them to be no? //only ever make smaller, never delete so we preserve the position

			if statusItems.count > MenuDock.shared.userPrefs.numberOfStatusItems{ //fuck it idc if it doesnt' work perfectly if we keep changing the numebr of items
				statusItems.removeLast() 
			}else{
				//else just make the width 0 because we know it will reappear at some point, and if we remove it it will reset the position on the menu bar
				statusItems.filter{$0.length != 0}.last?.length = 0
			}
		}
		while statusItemsBeingDisplayedInOrder.count < numberThereShouldBe { //not too cold
//			print("too few: ", statusItemsBeingDisplayedInOrder.count, numberThereShouldBe)
			
			if statusItems.count < MenuDock.shared.userPrefs.numberOfStatusItems{
				addStatusItem()
			}else{
				statusItems.filter{$0.length == 0}.first?.length = MenuDock.shared.userPrefs.widthOfStatusItem //re-add the first one that isn't zero. it's like a stack
			}
		}
		//juuuuuuuust right i want to die pls help.
	}  
}

