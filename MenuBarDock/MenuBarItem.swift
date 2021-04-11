//
//  MenuBarItem.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

class MenuBarItem {
	var statusItem: NSStatusItem
	var app: OpenableApp
	
	var position {
		return statusItem.button?.superview.window?.frame.minX
	}
	
	private(set) var bundleId: String
	
	init(statusItem: NSStatusItem) {
		self.statusItem = statusItem
		initButton()
	}
	
	func update(for app: OpenableApp, iconSize: CGFloat, slotWidth: CGFloat) {
		self.app = app
		
		let imageSize = iconSize
		let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 22
		let newView = NSImageView(
			frame: NSRect(
				x: (slotWidth - imageSize) / 2,
				y: -(imageSize - menuBarHeight) / 2,
				width: imageSize, height: imageSize)
		)
		
		image.size =  NSSize(width: imageSize, height: imageSize)
		
		newView.image = app.image
		newView.wantsLayer = true
		
		if let existingSubview = item.button?.subviews.first as? NSImageView {
			item.button?.replaceSubview(existingSubview, with: view) // we have to replace it to get the correct sizing
		} else {
			item.button?.addSubview(view)
		}
		
		statusItem.length = slotWidth
		
	}
	
	
	private func initButton(){
		statusItem.button?.wantsLayer = true
		item.button?.action = #selector(handleClick)
		statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		item.button?.appearance = NSAppearance(named: .aqua)
	}
	
	@objc private func handleClick(){
		let event = NSApp.currentEvent
		switch event?.type {
		case .rightMouseUp:
			showDropdownMenu()
		case .leftMouseUp:
			app.open()
		}
	}
	
	func showDropdownMenu() {
		let menu = NSMenu()
		let appName = app.name
		
		addMenuItem(
			title: "Quit \(appName)",
			action: #selector(quitApp),
			keyEquivalent: "q"
		)
		
		addMenuItem(
			title: "Reveal \(appName) in Finder",
			action: #selector(revealAppInFinder),
			keyEquivalent: "r"
		)
		
		if let runningApplication? = app.runningApplication?{
			//only makes sense to hide and show a running app, not just any app
			addMenuItem(
				title: "\(runningApplication?.isHidden ? "Unhide" : "Hide") \(appName)",
				action: #selector(toggleAppHidden),
				keyEquivalent: "h"
			)
			
			
			addMenuItem(
				title: "Activate \(appName)",
				action: #selector(activateApp),
				keyEquivalent: "a"
			)
		}
	
		addMenuItem(
			title: "Launch \(appName) instead of activating on click",
			action: #selector(activateApp),
			keyEquivalent: "l"
		)
		
		let launchInsteadActivateItem = NSMenuItem(title: "Launch \(appName) instead of activating on click", action: #selector(AppDelegate.launchInsteadOfActivateSpecificApp), keyEquivalent: "l")
		if let shouldLaunchInsteadOfActivate = MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[app?.bundleIdentifier ?? ""] {
			launchInsteadActivateItem.state = shouldLaunchInsteadOfActivate ? .on : .off
		} else {
			launchInsteadActivateItem.state = MenuBarDock.shared.userPrefs.launchInsteadOfActivate ? .on : .off // fallback to the global setting
		}
		self.launchInsteadActivateItem = launchInsteadActivateItem
		menu.addItem(launchInsteadActivateItem)
		
		menu.addItem(NSMenuItem.separator())
		// then options to do with menu bar dock
		menu.addItem(NSMenuItem(title: "\(Constants.App.name) Preferences...", action: #selector(AppDelegate.openPreferences), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: "Quit \(Constants.App.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")) // make it hard for user to quit menu bar dock lolll
		//		menu.addItem(NSMenuItem(title: "Creator's website", action: #selector(AppDelegate.openCreatorsWebsite), keyEquivalent: "w")) //bit needy, its good enough to just show it in preferences
		
		statusItem.popUpMenu(menu)
	}
	
	private func addMenuItem(title: String, action: Selector, keyEquivalent: String){
		menu.addItem(
			NSMenuItem(
				title: title,
				action: action,
				keyEquivalent: keyEquivalent
			)
		)
	}
	
	@objc private func quitApp(){
		app.quit()
	}
	
	@objc private func revealAppInFinder(){
		app.revealInFinder()
	}
	
	@objc private func toggleAppHidden(){
		if let runningApplication = app.runningApplication? {
			app.setIsHidden(!runningApplication.isHidden)
		}
	}
	
	@objc private func activateApp(){
		app.activate()
	}
	
}
