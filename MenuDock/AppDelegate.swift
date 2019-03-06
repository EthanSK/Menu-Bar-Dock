//
//  AppDelegate.swift
//  MenuDock
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa
import ServiceManagement 



@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate {
	
	

	let popover = NSPopover()
	var preferencesWindow = NSWindow()
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		let launcherAppId = "com.etggames.Launcher"
		let runningApps = NSWorkspace.shared.runningApplications
		let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
		
		SMLoginItemSetEnabled(launcherAppId as CFString, MenuDock.shared.userPrefs.launchAtLogin)  //well this didn't fucking work
		if isRunning {
			DistributedNotificationCenter.default().post(name: .killLauncher,
														 object: Bundle.main.bundleIdentifier!)
		}

		MenuDock.shared.appManager.trackAppsBeingActivated { (notification) in
			self.updateStatusItems() 
		}
		MenuDock.shared.appManager.trackAppsBeingQuit { (notification) in
			self.updateStatusItems()  //because the app actually quits aftre the activated app is switched meaninng otherwise we would keep the old app in the list showing
		}
		addStatusItems()
		NotificationCenter.default.addObserver(self, selector: #selector(numberOfAppsSliderDidChange), name: .numberOfAppsSliderEndedSliding, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .widthOfitemSliderChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .sizeOfIconSliderChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .resetToDefaults, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateStatusItems), name: .sortingMethodChanged, object: nil)
				
	}
	
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
		MenuDock.shared.userPrefs.save()
	}
	
	
	func addStatusItems(){
		MenuDock.shared.statusItemManager.statusItems = []
		for _ in 1...MenuDock.shared.userPrefs.numberOfStatusItems{
			MenuDock.shared.statusItemManager.addStatusItem()
		}
		//		for _ in 1...69{//for now just do the maximum number to guarantee that the order is saved //fuck it its laggy and illegit
		//			MenuDock.shared.statusItemManager.addStatusItem()
		//		}
		updateStatusItems()
	}
	
	
	@objc func numberOfAppsSliderDidChange(){
		updateStatusItems()
	}
	
	@objc func updateStatusItems(){
		//display running apps in order
		//will be by default ordered newest on the right because that's the most likely place the status item will be if there are too many status items.
		MenuDock.shared.statusItemManager.correctVisibleNumberOfStatusItems() //in case there are fewer running apps that status items in place.
		for item in MenuDock.shared.statusItemManager.statusItems{
			item.button?.wantsLayer = true
			item.button?.action = #selector(statusBarPressed) //doing this coz if the item was re-added, it needs this assosiated with it.
			item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		var i = 0
		for item in MenuDock.shared.statusItemManager.statusItemsBeingDisplayedInOrder{
			if i >= MenuDock.shared.appManager.runningAppsInOrder.count{//then we need to hide it
				return //all other i's will be higher and will fail too
			}
			let image = MenuDock.shared.appManager.runningAppsInOrder[i].icon
			let imageSize = MenuDock.shared.userPrefs.iconSize
			image?.size = NSSize(width: imageSize, height: imageSize)	
			item.button?.appearance = NSAppearance(named: .aqua) //so the full colour of the icon is shown
			item.button?.image = image
			item.length = MenuDock.shared.userPrefs.widthOfStatusItem
			let bundleId = MenuDock.shared.appManager.runningAppsInOrder[i].bundleIdentifier ?? MenuDock.shared.appManager.runningAppsInOrder[i].localizedName //?? just in case
			item.button?.layer?.setValue(bundleId, forKey: Constants.NSUserDefaultsKeys.bundleId) //layer doesn't exist on view did load. it takes some time to load for some reason so i guess we gotta add a timer
			i += 1
		}
	} 
	
	
	var bundleIdOfMenuJustOpened: String?
	@objc func statusBarPressed(button: NSButton){
		let event = NSApp.currentEvent
		let bundleId =  button.layer?.value(forKey: Constants.NSUserDefaultsKeys.bundleId) as! String
		let item = MenuDock.shared.statusItemManager.statusItems.filter{$0.button == button}.first
		if event?.type == NSEvent.EventType.rightMouseUp {
			print("Right click")
			item?.button?.appearance = NSAppearance(named: NSAppearance.current.name)
			bundleIdOfMenuJustOpened = bundleId
			item?.popUpMenu(menu(onItemWithBundleId: bundleId)) //works but depr
			//			NSMenu.popUpContextMenu(menu(onItemWithBundleId: bundleId), with: event!, for: button)
			//			button.menu =  MenuDock.shared.statusItemManager.menu
			//			button.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height + 5), in: button)
		} else {
			print("Left click")
			MenuDock.shared.appManager.openApp(withBundleId: bundleId)
		}
	}
	
	func menu(onItemWithBundleId bundleId: String) -> NSMenu{
		let menu = NSMenu()
		//first options to do with the app. we cannot quit the app - there is nothing more i think we can do
		//let app = MenuDock.shared.appManager.runningAppsInOrder.filter{$0.bundleIdentifier == bundleId}.first
		//menu.addItem(NSMenuItem(title: "Quit \(app?.localizedName ?? "")", action: #selector(AppDelegate.quitApp), keyEquivalent: "q"))
		//menu.addItem(NSMenuItem.separator())
		//then options to do with menu bar dock
		menu.addItem(NSMenuItem(title: "\(Constants.App.name) Preferences...", action: #selector(AppDelegate.openPreferences), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: "Quit \(Constants.App.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
		
		return menu
	}
	
	@objc func openPreferences(){
		print("open preferences")
		openPreferencesWindow()
	}
	
	
	func openPreferencesWindow(){
		if let vc =  NSStoryboard(name: "Main",bundle: nil).instantiateController(withIdentifier: "PreferencesViewController") as? PreferencesViewController{
			if !preferencesWindow.isVisible{
				preferencesWindow = NSWindow(contentViewController: vc)
				preferencesWindow.makeKeyAndOrderFront(self)
			}
			let controller = NSWindowController(window: preferencesWindow)
			controller.showWindow(self)
			NSApp.activate(ignoringOtherApps: true)//stops bugz n shiz i think
		}
	}
	
}

