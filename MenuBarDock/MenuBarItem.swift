//
//  MenuBarItem.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol MenuBarItemUserPrefsDelegate: AnyObject {
	func getAppOpeningMethod(_ app: OpenableApp) -> AppOpeningMethod
	func didSetAppOpeningMethod(_ method: AppOpeningMethod, _ app: OpenableApp)
}

protocol MenuBarItemPreferencesDelegate: AnyObject {
	func didOpenPreferencesWindow()
}

class MenuBarItem {
	var statusItem: NSStatusItem
	var app: OpenableApp
	
	
	var position {
		return statusItem.button?.superview.window?.frame.minX
	}
	
	weak var userPrefsDelegate: MenuBarItemUserPrefsDelegate!
	weak var preferencesDelegate: MenuBarItemPreferencesDelegate!
	
	private(set) var bundleId: String
	
	init(
		statusItem: NSStatusItem,
		userPrefsDelegate: MenuBarItemUserPrefsDelegate
		preferencesDelegate: MenuBarItemPreferencesDelegate
	) {
		self.statusItem = statusItem
		self.userPrefsDelegate = userPrefsDelegate
		self.preferencesDelegate = preferencesDelegate
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
			menu: menu
			title: "Quit \(appName)",
			action: #selector(quitApp),
			keyEquivalent: "q"
		)
		
		addMenuItem(
			menu: menu
			title: "Reveal \(appName) in Finder",
			action: #selector(revealAppInFinder),
			keyEquivalent: "r"
		)
		
		if let runningApplication? = app.runningApplication?{
			//only makes sense to hide and show, and activate a running app, not just any app
			addMenuItem(
				menu: menu
				title: "\(runningApplication?.isHidden ? "Unhide" : "Hide") \(appName)",
				action: #selector(toggleAppHidden),
				keyEquivalent: "h"
			)
			addMenuItem(
				menu: menu
				title: "Activate \(appName)",
				action: #selector(activateApp),
				keyEquivalent: "a"
			)
		}
		
		menu.addItem(appOpeningMethodMenuItem(menu))
		
		menu.addItem(NSMenuItem.separator())
		
		// options to do with menu bar dock itself
		addMenuItem(
			menu: menu
			title: "\(Constants.App.name) Preferences...",
			action: #selector(openPreferencesWindow),
			keyEquivalent: ","
		)
		
		addMenuItem(
			menu: menu
			title: "Quit \(Constants.App.name)",
			action: #selector(NSApplication.terminate(_:)),
			keyEquivalent: ""
		)
		
		statusItem.popUpMenu(menu)
	}
	
	private func appOpeningMethodMenuItem(menu: NSMenu) -> NSMenuItem{
		let appOpeningMethodMenuItem = addMenuItem(
			menu: menu
			title: "Change opening method for \(appName)",
			action: nil,
			keyEquivalent: ""
		)
		appOpeningMethodMenuItem.submenu = NSMenu()
		let launchItem = addMenuItem(
			menu: appOpeningMethodMenuItem.submenu
			title: AppOpeningMethod.launch.rawValue,
			action: #selector(setAppOpeningMethodLaunch),
			keyEquivalent: ""
		)
		let activateItem = addMenuItem(
			menu: appOpeningMethodMenuItem.submenu
			title: AppOpeningMethod.activate.rawValue,
			action: #selector(setAppOpeningMethodActivate),
			keyEquivalent: ""
		)
		
		switch delegate.appOpeningMethod {
		case .launch:
			launchItem.state = .on
			activateItem.state = .off
		case .activate:
			launchItem.state = .off
			activateItem.state = .on
		}
		return appOpeningMethodMenuItem
	}
	
	private func addMenuItem(menu: NSMenu, title: String, action: Selector, keyEquivalent: String) -> NSMenuItem{
		let item = NSMenuItem(
			title: title,
			action: action,
			keyEquivalent: keyEquivalent
		)
		menu.addItem(item)
		return item
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
	
	@objc private func setAppOpeningMethodLaunch(){
		delegate.didSetAppOpeningMethod(.launch)
	}
	
	@objc private func setAppOpeningMethodActivate(){
		delegate.didSetAppOpeningMethod(.activate)
	}
	
	@objc private func openPreferencesWindow(){
		preferencesDelegate.didOpenPreferencesWindow()
	}
}
