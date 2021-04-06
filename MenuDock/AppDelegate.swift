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
		
		let launcherAppId = Constants.App.launcherBundleId
		let runningApps = NSWorkspace.shared.runningApplications
		let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
		print("Launch at login on app did finish launching: ", MenuBarDock.shared.userPrefs.launchAtLogin)
		SMLoginItemSetEnabled(launcherAppId as CFString, MenuBarDock.shared.userPrefs.launchAtLogin)
		
		if isRunning {
			DistributedNotificationCenter.default().post(name: .killLauncher,
														 object: Bundle.main.bundleIdentifier!)
		}
		
		MenuBarDock.shared.appManager.trackAppsBeingActivated { (notification) in
			self.updateStatusItems() 
		}
		MenuBarDock.shared.appManager.trackAppsBeingQuit { (notification) in
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
		MenuBarDock.shared.userPrefs.save()
	}
	
	
	func addStatusItems(){
		MenuBarDock.shared.statusItemManager.statusItems = []
		for _ in 1...MenuBarDock.shared.userPrefs.numberOfStatusItems{
			MenuBarDock.shared.statusItemManager.addStatusItem()
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
		MenuBarDock.shared.statusItemManager.correctVisibleNumberOfStatusItems() //in case there are fewer running apps that status items in place.
		for item in MenuBarDock.shared.statusItemManager.statusItems{
			item.button?.wantsLayer = true
			item.button?.action = #selector(statusBarPressed) //doing this coz if the item was re-added, it needs this assosiated with it.
			item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}
		var i = 0
		for item in MenuBarDock.shared.statusItemManager.statusItemsBeingDisplayedInOrder{
			if i >= MenuBarDock.shared.appManager.runningAppsInOrder.count{//then we need to hide it
				return //all other i's will be higher and will fail too
			}
			let image = MenuBarDock.shared.appManager.runningAppsInOrder[i].icon
			let imageSize = MenuBarDock.shared.userPrefs.iconSize
			image?.size = NSSize(width: imageSize, height: imageSize)
			item.button?.appearance = NSAppearance(named: .aqua) //so the full colour of the icon is shown
//			item.button?.image = image //this casuse it to show as completely blank on secondary monitors. have to set view manually
			let itemSlotWidth = MenuBarDock.shared.userPrefs.widthOfStatusItem
 			let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 22
			
			let view = NSImageView(frame: NSRect(
				x: (itemSlotWidth - imageSize) / 2,
				y: -(imageSize - menuBarHeight) / 2,
				width: imageSize, height: imageSize)) //constructing image view from image is only available on macos >= 10.12
			view.image = image
			view.wantsLayer = true
//			view.layer?.backgroundColor = NSColor.yellow.cgColor
			if let existingSubview = item.button?.subviews.first as? NSImageView
			{
//				existingSubview.image = image
				item.button?.replaceSubview(existingSubview, with: view) //we have to replace it to get the correct sizing
			}else{
				item.button?.addSubview(view)
			}
			
			
			item.length = itemSlotWidth
			let bundleId = MenuBarDock.shared.appManager.runningAppsInOrder[i].bundleIdentifier ?? MenuBarDock.shared.appManager.runningAppsInOrder[i].localizedName //?? just in case
			item.button?.layer?.setValue(bundleId, forKey: Constants.NSUserDefaultsKeys.bundleId) //layer doesn't exist on view did load. it takes some time to load for some reason so i guess we gotta add a timer
 			i += 1
		}
	} 
	
	
	var bundleIdOfMenuJustOpened: String?
	@objc func statusBarPressed(button: NSButton){
		let event = NSApp.currentEvent
		let bundleId =  button.layer?.value(forKey: Constants.NSUserDefaultsKeys.bundleId) as! String
		let item = MenuBarDock.shared.statusItemManager.statusItems.filter{$0.button == button}.first
		if event?.type == NSEvent.EventType.rightMouseUp {
			print("Right click")
			item?.button?.appearance = NSAppearance(named: NSAppearance.current.name)
			bundleIdOfMenuJustOpened = bundleId
			item?.popUpMenu(menu(onItemWithBundleId: bundleId))
 
		} else {
			print("Left click")
			MenuBarDock.shared.appManager.openApp(withBundleId: bundleId)
		}
	}
	
	var appBeingRightClicked: NSRunningApplication? //this is horrible but idk how else to pass the app through the nsmenuitem selector.
	var launchInsteadActivateItem: NSMenuItem!
	
	func menu(onItemWithBundleId bundleId: String) -> NSMenu{
		let menu = NSMenu()
		//first options to do with the app.
		let app = MenuBarDock.shared.appManager.runningAppsInOrder.filter{$0.bundleIdentifier == bundleId}.first
		appBeingRightClicked = app;
		let appNameToUse = app?.localizedName ?? "app"
		menu.addItem(NSMenuItem(title: "Quit \(appNameToUse)", action: #selector(AppDelegate.quitAppBeingRightClicked), keyEquivalent: "q"))
		menu.addItem(NSMenuItem(title: "Reveal \(appNameToUse) in Finder", action: #selector(AppDelegate.showInFinderAppBeingRightClicked), keyEquivalent: "r"))
		
		if let app = app{
			if (app.isHidden){
				menu.addItem(NSMenuItem(title: "Unhide \(appNameToUse)", action: #selector(AppDelegate.unhideAppBeingRightClicked), keyEquivalent: "h"))
			}
			else{
				menu.addItem(NSMenuItem(title: "Hide \(appNameToUse)", action: #selector(AppDelegate.hideAppBeingRightClicked), keyEquivalent: "h"))
			}
		}
		menu.addItem(NSMenuItem(title: "Activate \(appNameToUse)", action: #selector(AppDelegate.activateAppBeingRightClicked), keyEquivalent: "a"))
		
		let launchInsteadActivateItem = NSMenuItem(title: "Launch \(appNameToUse) instead of activating on click", action: #selector(AppDelegate.launchInsteadOfActivateSpecificApp), keyEquivalent: "l")
		if let shouldLaunchInsteadOfActivate = MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[app?.bundleIdentifier ?? ""]{
			launchInsteadActivateItem.state = shouldLaunchInsteadOfActivate ? .on : .off
		}else {
			launchInsteadActivateItem.state = MenuBarDock.shared.userPrefs.launchInsteadOfActivate ? .on : .off //fallback to the global setting
		}
		self.launchInsteadActivateItem = launchInsteadActivateItem
		menu.addItem(launchInsteadActivateItem)


		menu.addItem(NSMenuItem.separator())
		//then options to do with menu bar dock
		menu.addItem(NSMenuItem(title: "\(Constants.App.name) Preferences...", action: #selector(AppDelegate.openPreferences), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: "Quit \(Constants.App.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")) //make it hard for user to quit menu bar dock lolll
//		menu.addItem(NSMenuItem(title: "Creator's website", action: #selector(AppDelegate.openCreatorsWebsite), keyEquivalent: "w")) //bit needy, its good enough to just show it in preferences

		
		
		return menu
	}
	
	
	
	@objc func openCreatorsWebsite(){
		NSWorkspace.shared.open(URL(string: "https://www.etggames.com/menu-bar-dock")!)
	}
	
	@objc func launchInsteadOfActivateSpecificApp(){
		// the individual app settings should not be overriden by the global option. they should be the priority.
		guard let key = appBeingRightClicked?.bundleIdentifier else {return}
		let newValue: Bool
		if launchInsteadActivateItem.state == .on {
			newValue = false
			launchInsteadActivateItem.state = .off
		}else{
			newValue = true
			launchInsteadActivateItem.state = .on
		}
		MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[key] = newValue
		MenuBarDock.shared.userPrefs.save()
  	}
	
		
	@objc func activateAppBeingRightClicked(){
		appBeingRightClicked?.activate(options: .activateIgnoringOtherApps)
	}
	
	@objc func hideAppBeingRightClicked()
	{
		if let appBeingRightClicked = appBeingRightClicked
		{
			appBeingRightClicked.hide()

		}
	}
	@objc func unhideAppBeingRightClicked()
	{
		if let appBeingRightClicked = appBeingRightClicked
		{
			appBeingRightClicked.unhide()

		}
	}
	
	@objc func showInFinderAppBeingRightClicked()
	{
		if let bundleURL = appBeingRightClicked?.bundleURL
		{
			NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
		}
	}
	
	
	@objc func quitAppBeingRightClicked() {
		let wasTerminated = appBeingRightClicked?.terminate() //needs app sandbox off or explicit com.apple.security.temporary-exception.apple-events entitlement for the specific app
		print("was terminated: " , wasTerminated ?? "null")
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

