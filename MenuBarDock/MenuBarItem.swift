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
			statusItem.popUpMenu(menu(onItemWithBundleId: bundleId))
		case .leftMouseUp:
			openApp()
	}
		
	
	private func openApp() {
		let bundleId = app.bundleId
		print("Opening app with id: ", bundleId)
		if (bundleId) == Constants.App.finderBundleId { // finder is weird and doesn't open normally
			NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil) // do this as well if it's hidden
			appToOpen?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) // this is the only way i can get working to show the finder app
		} else {
			// i don't think there is a way to differentiate two different app versions that have the same bundle id eg matlab
			// its better to activate instead of launch because if there are multiple versions of the same app it will fucc u
			let shouldLaunchInsteadOfActivate = MenuBarDock.shared.userPrefs.launchInsteadOfActivateIndivApps[appToOpen?.bundleIdentifier ?? ""] ?? MenuBarDock.shared.userPrefs.launchInsteadOfActivate

			if shouldLaunchInsteadOfActivate {
				NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)

			} else {
				appToOpen?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) // this is the only way i can get working to show the finder app

			}

		}
	}
		
		
	func menu(onItemWithBundleId bundleId: String) -> NSMenu {
		let menu = NSMenu()
		// first options to do with the app.
		let app = MenuBarDock.shared.appManager.runningAppsInOrder.filter {$0.bundleIdentifier == bundleId}.first
		appBeingRightClicked = app
		let appNameToUse = app?.localizedName ?? "app"
		menu.addItem(NSMenuItem(title: "Quit \(appNameToUse)", action: #selector(AppDelegate.quitAppBeingRightClicked), keyEquivalent: "q"))
		menu.addItem(NSMenuItem(title: "Reveal \(appNameToUse) in Finder", action: #selector(AppDelegate.showInFinderAppBeingRightClicked), keyEquivalent: "r"))

		if let app = app {
			if app.isHidden {
				menu.addItem(NSMenuItem(title: "Unhide \(appNameToUse)", action: #selector(AppDelegate.unhideAppBeingRightClicked), keyEquivalent: "h"))
			} else {
				menu.addItem(NSMenuItem(title: "Hide \(appNameToUse)", action: #selector(AppDelegate.hideAppBeingRightClicked), keyEquivalent: "h"))
			}
		}
		menu.addItem(NSMenuItem(title: "Activate \(appNameToUse)", action: #selector(AppDelegate.activateAppBeingRightClicked), keyEquivalent: "a"))

		let launchInsteadActivateItem = NSMenuItem(title: "Launch \(appNameToUse) instead of activating on click", action: #selector(AppDelegate.launchInsteadOfActivateSpecificApp), keyEquivalent: "l")
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

		return menu
	}
}
