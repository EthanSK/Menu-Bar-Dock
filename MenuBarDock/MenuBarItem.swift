//
//  MenuBarItem.swift
//  Menu Bar Dock
//
//  Created by Ethan Sarif-Kattan on 11/04/2021.
//  Copyright © 2021 Ethan Sarif-Kattan. All rights reserved.
//

import Cocoa

protocol MenuBarItemDataSource: AnyObject {
	func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod?
    var rightClickByDefault: Bool { get }
}

protocol MenuBarItemDelegate: AnyObject {
	func didOpenPreferencesWindow()
	func didCheckForUpdates()
	func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp)

}

class MenuBarItem {
	private(set) var statusItem: NSStatusItem
	private(set) var app: OpenableApp?

	public var position: CGFloat {
		return statusItem.button!.superview!.window!.frame.minX
	}

	public weak var userPrefsDataSource: MenuBarItemDataSource!
	public weak var delegate: MenuBarItemDelegate?

	init(
		statusItem: NSStatusItem,
        userPrefsDataSource: MenuBarItemDataSource
 	) {
		self.statusItem = statusItem
		self.userPrefsDataSource = userPrefsDataSource
		initButton()

	}

	func update(for app: OpenableApp, appIconSize: CGFloat, slotWidth: CGFloat) {
        DebugLog.shared.diagnostic("item begin app=\(app.bundleId ?? "unknown") length=\(statusItem.length) subviews=\(statusItem.button?.subviews.count ?? 0) scale=\(statusItem.button?.window?.backingScaleFactor ?? 0)")
		self.app = app
        let menuBarHeight: CGFloat = 22 // do not use NSApplication.shared.mainMenu?.menuBarHeight, it doesn't work on MBP 16 inch with notch, because the menu bar reports as bigger than the actual height it uses. 22 is a good fixed height.
        let imageSize = appIconSize // All apps use the shared size. Ethan rejected per-app fitting because it made one icon smaller; do not reintroduce app-specific sizing (task 01a1df78-3f6d-7231-854c-4a4206992d2e).
		let newView = NSImageView(
			frame: NSRect(
                // Odd whole-number sizes can still produce half-point origins.
                // Whole points align on both 1x and 2x displays without growing the image.
				x: ((slotWidth - imageSize) / 2).rounded(),
				y: (-(imageSize - menuBarHeight) / 2).rounded(),
				width: imageSize, height: imageSize)
		)

        // Different entries can share an NSImage from macOS. Wrap its drawing
        // so drawing one entry cannot resize a neighbor's source image. Like
        // the badge below, AppKit draws this at the actual backing scale.
        let sourceIcon = app.icon
        let displayedIcon = NSImage(size: NSSize(width: imageSize, height: imageSize), flipped: false) { rect in
            sourceIcon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        displayedIcon.isTemplate = sourceIcon.isTemplate
		newView.image = displayedIcon
		newView.wantsLayer = true

        if let instanceNumber = app.instanceNumber {
            let text = String(instanceNumber)
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.white]
            let textSize = text.size(withAttributes: attributes)
            let badgeSize = NSSize(width: max(14, textSize.width + 6).rounded(.up), height: 14)
            let badgeImage = NSImage(size: badgeSize, flipped: false) { rect in
                NSColor.systemRed.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
                text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2), withAttributes: attributes)
                return true
            }
            let badgeView = NSImageView(frame: NSRect(x: ((slotWidth + imageSize) / 2 - badgeSize.width - 1).rounded(), y: ((imageSize - menuBarHeight) / 2 + 1).rounded(), width: badgeSize.width, height: badgeSize.height)) // Anchor to the visible menu-bar slot, since oversized app artwork extends above and below it.
            badgeView.image = badgeImage
            newView.addSubview(badgeView)
            statusItem.button?.setAccessibilityLabel("\(app.name), instance \(instanceNumber)")
            statusItem.button?.toolTip = "\(app.name), instance \(instanceNumber)"
        } else {
            statusItem.button?.setAccessibilityLabel(app.name)
            statusItem.button?.toolTip = app.name
        }

		if let existingSubview = statusItem.button?.subviews.first as? NSImageView {
			statusItem.button?.replaceSubview(existingSubview, with: newView) // we have to replace it to get the correct sizing
		} else {
			statusItem.button?.addSubview(newView)
		}

		statusItem.length = slotWidth
        DebugLog.shared.diagnostic("item completed app=\(app.bundleId ?? "unknown") length=\(statusItem.length) subviews=\(statusItem.button?.subviews.count ?? 0)")
	}

	func reset() {
		self.app = nil
        if let button = statusItem.button {
            for subview in button.subviews {
                subview.removeFromSuperview()
            }
        }
	}

	private func initButton() {
		statusItem.button?.wantsLayer = true
		statusItem.button?.target = self
		statusItem.button?.action = #selector(handleClick)
		statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		statusItem.button?.appearance = NSAppearance(named: .aqua)
 	}

	@objc private func handleClick() {
        DebugLog.shared.diagnostic("click app=\(app?.bundleId ?? "none") event=\(NSApp.currentEvent?.type.rawValue ?? 0) menuDefault=\(userPrefsDataSource.rightClickByDefault)", checkpoint: true)
        if userPrefsDataSource.rightClickByDefault == true {
            showDropdownMenu()
            return
        }

		let event = NSApp.currentEvent
		switch event?.type {
		case .rightMouseUp:
			showDropdownMenu()
		case .leftMouseUp:
			app?.open()
		default: break

		}
	}

	func showDropdownMenu() {
        DebugLog.shared.diagnostic("menu begin app=\(app?.bundleId ?? "none")", checkpoint: true)
        defer { DebugLog.shared.diagnostic("menu completed", checkpoint: true) }
		statusItem.button?.appearance = NSAppearance(named: NSAppearance.current.name)

		guard let menu = makeDropdownMenu() else { return }
		statusItem.popUpMenu(menu)
	}

	func makeDropdownMenu() -> NSMenu? {
		let menu = NSMenu()
		guard let appName = app?.name else { return nil }

        if let runningApplication = app?.runningApplication {
            _ = addMenuItem(
                menu: menu,
                title: "Quit \(appName)",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )

            // only makes sense to hide and show, and activate a running app, not just any app
            let isHidden = runningApplication.isHidden
            _ = addMenuItem(
                menu: menu,
                title: "\(isHidden ? "Unhide" : "Hide") \(appName)",
                action: isHidden ? #selector(unhideApp) : #selector(hideApp),
                keyEquivalent: "h"
            )

            _ = addMenuItem(
                menu: menu,
                title: "Activate \(appName)",
                action: #selector(activateApp),
                keyEquivalent: "a"
            )
        }

		_ = addMenuItem(
			menu: menu,
			title: "Reveal \(appName) in Finder",
			action: #selector(revealAppInFinder),
			keyEquivalent: "r"
		)

		_ = addMenuItem(
			menu: menu,
			title: "Launch \(appName)",
			action: #selector(launchApp),
			keyEquivalent: "l"
		)
		// removed open new instance item because it's kinda pointless and will probably cause bugs
		addAppOpeningMethodMenuItem(menu: menu)

		menu.addItem(NSMenuItem.separator())

		// options to do with menu bar dock itself
		_ = addMenuItem(
			menu: menu,
			title: "\(Constants.App.name) Preferences...", // ... is a standard...
			action: #selector(openPreferencesWindow),
			keyEquivalent: ","
		)

		_ = addMenuItem(
			menu: menu,
			title: "Check for Updates...",
			action: #selector(checkForUpdates),
			keyEquivalent: ""
		)

		_ = addMenuItem(
			menu: menu,
			title: "Quit \(Constants.App.name)",
			action: #selector(quitMenuBarDock),
			keyEquivalent: ""
		)

		return menu
	}

	private func addAppOpeningMethodMenuItem(menu: NSMenu) {
		guard let app = app else { return }
		let appOpeningMethodMenuItem = addMenuItem(
			menu: menu,
			title: "Change opening method for \(app.name)",
			action: nil,
			keyEquivalent: ""
		)
		appOpeningMethodMenuItem.submenu = NSMenu()

		let launchItem = addMenuItem(
			menu: appOpeningMethodMenuItem.submenu!,
			title: "Launch",
			action: #selector(setAppOpeningMethodLaunch),
			keyEquivalent: ""
		)

		let activateItem = addMenuItem(
			menu: appOpeningMethodMenuItem.submenu!,
			title: "Activate",
			action: #selector(setAppOpeningMethodActivate),
			keyEquivalent: ""
		)

		switch userPrefsDataSource.appOpeningMethod(for: app) {
		case .launch:
			launchItem.state = .on
			activateItem.state = .off
		case .activate:
			launchItem.state = .off
			activateItem.state = .on
		default:
			launchItem.state = .off
			activateItem.state = .off
		}
 	}

	private func addMenuItem(menu: NSMenu, title: String, action: Selector?, keyEquivalent: String) -> NSMenuItem {
		let item = NSMenuItem(
			title: title,
			action: action,
			keyEquivalent: keyEquivalent
		)
		item.representedObject = app // A workspace refresh can reuse this status item while its menu is open. Keep the app and process named in the menu.
		item.target = self
		menu.addItem(item)
		return item
	}

	@objc private func quitApp(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.quit()
	}

	@objc private func revealAppInFinder(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.revealInFinder()
	}

	@objc private func hideApp(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.setIsHidden(isHidden: true)
	}

	@objc private func unhideApp(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.setIsHidden(isHidden: false)
	}

	@objc private func activateApp(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.activate()
	}

	@objc private func launchApp(_ sender: NSMenuItem) {
		(sender.representedObject as? OpenableApp)?.launch()
	}

	@objc private func setAppOpeningMethodLaunch(_ sender: NSMenuItem) {
		guard let app = sender.representedObject as? OpenableApp else { return }
		delegate?.didSetAppOpeningMethod(userPrefsDataSource.appOpeningMethod(for: app) == .launch ? nil : .launch, app) // toggle the current state
	}

	@objc private func setAppOpeningMethodActivate(_ sender: NSMenuItem) {
		guard let app = sender.representedObject as? OpenableApp else { return }
		delegate?.didSetAppOpeningMethod(userPrefsDataSource.appOpeningMethod(for: app) == .activate ? nil : .activate, app)
	}

	@objc private func openPreferencesWindow() {
		delegate?.didOpenPreferencesWindow()
	}

	@objc private func checkForUpdates() {
		delegate?.didCheckForUpdates()
	}

	@objc private func quitMenuBarDock(_ sender: Any?) {
		NSApp.terminate(nil)
	}
}
