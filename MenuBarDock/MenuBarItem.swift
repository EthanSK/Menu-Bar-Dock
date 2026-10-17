// Each app/folder is a button inside one persistent system status item.
import Cocoa
import QuartzCore

protocol MenuBarItemDataSource: AnyObject {
    func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod?
    var rightClickByDefault: Bool { get }
    var groupSpacing: CGFloat { get }
}

protocol MenuBarItemDelegate: AnyObject {
    func didOpenPreferencesWindow()
    func didCheckForUpdates()
    func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp)
    func didChangeGroupSpacing(_ spacing: CGFloat)
    func menuWillOpen()
    func menuDidClose()
}

extension MenuBarItemDelegate {
    func menuWillOpen() {}
    func menuDidClose() {}
}

class MenuBarItem {
    let button = DockItemButton(frame: .zero)
    private(set) var app: OpenableApp?
    weak var userPrefsDataSource: MenuBarItemDataSource!
    weak var delegate: MenuBarItemDelegate?
    // Retain controllers for overflow-menu actions throughout menu tracking.
    var overflowItems: [MenuBarItem] = []
    var overflowApps: [OpenableApp] = []
    private var displayedRunning = false

    init(userPrefsDataSource: MenuBarItemDataSource) {
        self.userPrefsDataSource = userPrefsDataSource
        button.isBordered = false
        button.title = "⋯"
        button.target = self
        button.action = #selector(handleClick)
        button.onRightClick = { [weak self] in self?.showDropdownMenu() }
        button.setAccessibilityLabel("Menu Bar Dock Preferences")
        button.toolTip = "Menu Bar Dock — right-click for options; ⌘-drag to move the group"
    }

    func update(for app: OpenableApp, appIconSize: CGFloat, slotWidth: CGFloat) {
        let size = min(100, max(12, appIconSize))
        let redraw = button.app?.icon !== app.icon || displayedRunning != app.isRunning ||
            button.app?.instanceNumber != app.instanceNumber || button.iconSize != size
        self.app = app
        button.app = app
        button.iconSize = size
        displayedRunning = app.isRunning
        let width = DockItemLayout.slotWidth(requested: max(30, slotWidth), iconSize: size)
        if button.frame.width != width {
            button.resetHover()
            button.frame.size.width = width
        }
        let instance = app.instanceNumber.map { ", instance \($0)" } ?? ""
        let state = app.isFolder ? ", folder" : (app.isRunning ? ", running" : ", not running")
        button.setAccessibilityLabel(app.name + instance + state)
        button.toolTip = app.name + instance + state + (app.isFolder ? "\n\(app.bundleUrl.path)" : "")
        if redraw { button.resetHover(); button.needsDisplay = true }
    }

    @objc private func handleClick() {
        if app == nil || userPrefsDataSource.rightClickByDefault || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            showDropdownMenu()
        } else {
            app?.open()
        }
    }

    func showDropdownMenu() {
        guard let menu = makeDropdownMenu() else { return }
        delegate?.menuWillOpen()
        button.setMenuTracking(true)
        button.highlight(true)
        defer {
            button.highlight(false)
            delegate?.menuDidClose()
            button.setMenuTracking(false)
        }
        withExtendedLifetime(overflowItems) {
            DockMenuPresentation.popUp(menu, from: button)
        }
    }

	func makeDropdownMenu() -> NSMenu? {
		let menu = NSMenu()
        // Hidden entries need menu controllers only while a menu is being opened.
        if !overflowApps.isEmpty {
            overflowItems = overflowApps.map { app in
                let item = MenuBarItem(userPrefsDataSource: userPrefsDataSource)
                item.delegate = delegate
                item.update(for: app, appIconSize: 18, slotWidth: 30)
                return item
            }
        }
        for item in overflowItems {
            guard let app = item.app else { continue }
            let entry = NSMenuItem(title: app.name + (app.isRunning ? "  •" : ""), action: nil, keyEquivalent: "")
            let icon = app.icon.copy() as? NSImage
            icon?.size = NSSize(width: 18, height: 18)
            entry.image = icon
            entry.submenu = item.makeDropdownMenu()
            menu.addItem(entry)
        }
        if !overflowItems.isEmpty { menu.addItem(.separator()) }
        if let app = app {
        let appName = app.name

        if app.isRunning, let runningApplication = app.runningApplication {
            _ = addMenuItem(
                menu: menu,
                title: "Quit \(appName)",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )

            // only makes sense to hide and show, and activate a running app, not just any app
            _ = addMenuItem(
                menu: menu,
                title: "\(runningApplication.isHidden ? "Unhide" : "Hide") \(appName)",
                action: #selector(toggleAppHidden),
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
			title: app.isFolder ? "Open \(appName) in Finder" : "Launch \(appName)",
			action: #selector(launchApp),
			keyEquivalent: "l"
		)
		// removed open new instance item because it's kinda pointless and will probably cause bugs
        if !app.isFolder { addAppOpeningMethodMenuItem(menu: menu) }
        }

        if !menu.items.isEmpty { menu.addItem(.separator()) }

        let spacingItem = addMenuItem(menu: menu, title: "Space to the right of the group", action: nil, keyEquivalent: "")
        let spacingMenu = NSMenu()
        for value in [0, 24, 48, 96, 160] {
            let item = addMenuItem(menu: spacingMenu, title: "\(value) pt", action: #selector(changeGroupSpacing), keyEquivalent: "")
            item.tag = value
            item.state = Int(userPrefsDataSource.groupSpacing) == value ? .on : .off
        }
        spacingItem.submenu = spacingMenu
        let hint = NSMenuItem(title: "⌘-drag the group to move it toward the center", action: nil, keyEquivalent: "")
        menu.addItem(hint)
        menu.addItem(.separator())

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
		item.target = self
		menu.addItem(item)
		return item
	}

    @objc private func changeGroupSpacing(_ sender: NSMenuItem) {
        delegate?.didChangeGroupSpacing(CGFloat(sender.tag))
    }

	@objc private func quitApp() {
		app?.quit()
	}

	@objc private func revealAppInFinder() {
		app?.revealInFinder()
	}

	@objc private func toggleAppHidden() {
		if let runningApplication = app?.runningApplication {
			app?.setIsHidden(isHidden: !runningApplication.isHidden)
		}
	}

	@objc private func activateApp() {
		app?.activate()
	}

	@objc private func launchApp() {
		app?.launch()
	}

	@objc private func openNewAppInstance() {
		app?.openNewAppInstance()
	}

	@objc private func setAppOpeningMethodLaunch() {
		guard let app = app else { return }
		delegate?.didSetAppOpeningMethod(userPrefsDataSource.appOpeningMethod(for: app) == .launch ? nil : .launch, app) // toggle the current state
 	}

	@objc private func setAppOpeningMethodActivate() {
		guard let app = app else { return }
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

/// A native button keeps keyboard/VoiceOver activation and per-item hit targets.
/// Command-drag passes through to NSStatusBarButton so macOS moves the whole dock.
final class DockItemButton: NSButton {
    var app: OpenableApp?
    var iconSize: CGFloat = UserPrefsDefaultValues.appIconSize
    var onRightClick: (() -> Void)?
    var hoverAnimationsEnabled = true {
        didSet { if !hoverAnimationsEnabled { resetHover() } }
    }
    private var hoverTrackingArea: NSTrackingArea?
    private(set) var isHovered = false
    private var isMenuTracking = false
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var hoverDistance: (NSScreen?) -> CGFloat = { DockHoverMotion.distance(on: $0) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(!event.modifierFlags.contains(.command))
    }

    override func mouseExited(with event: NSEvent) { setHovered(false) }

    override func mouseDown(with event: NSEvent) {
        resetHover()
        super.mouseDown(with: event)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { resetHover() }
        super.viewWillMove(toWindow: newWindow)
    }

    func setHovered(_ hovered: Bool, animated: Bool = true) {
        isHovered = hovered
        if hovered, hoverAnimationsEnabled, app != nil, !isMenuTracking, !reduceMotion() {
            DockHoverOverlay.shared.show(for: self, distance: hoverDistance(window?.screen), animated: animated)
        } else {
            DockHoverOverlay.shared.hide(for: self, animated: animated && !isMenuTracking && !reduceMotion())
        }
    }

    func resetHover() { isHovered = false; DockHoverOverlay.shared.hide(for: self, animated: false) }

    func setMenuTracking(_ tracking: Bool) {
        isMenuTracking = tracking
        resetHover()
        if !tracking, let window = window, window.isVisible {
            let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            setHovered(bounds.contains(point))
        }
    }

    /// Include artwork outside the short menu-bar button. Caching the view's
    /// bounds clips oversized icons before their first animation frame.
    var hoverArtworkBounds: NSRect {
        bounds.union(artworkLayout.iconRect).union(artworkLayout.indicatorRect).integral
    }

    func hoverSnapshot() -> NSImage? {
        let rect = hoverArtworkBounds
        guard rect.width > 0, rect.height > 0 else { return nil }
        let scale = window?.backingScaleFactor ?? 2
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(rect.width * scale)), pixelsHigh: Int(ceil(rect.height * scale)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = rect.size
        let cg = context.cgContext
        cg.scaleBy(x: CGFloat(bitmap.pixelsWide) / rect.width,
                   y: CGFloat(bitmap.pixelsHigh) / rect.height)
        if isFlipped {
            cg.translateBy(x: 0, y: rect.height)
            cg.scaleBy(x: 1, y: -1)
        }
        cg.translateBy(x: -rect.minX, y: -rect.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: isFlipped)
        effectiveAppearance.performAsCurrentDrawingAppearance { draw(rect) }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: rect.size)
        image.addRepresentation(bitmap)
        return image
    }

    var artworkLayout: DockItemLayout { DockItemLayout(bounds: bounds, iconSize: iconSize) }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if NSApp.currentEvent?.modifierFlags.contains(.command) == true { resetHover(); return nil }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        resetHover()
        onRightClick?()
    }

    // The down event already opened the menu. Do not forward its matching up
    // event to the enclosing status button and open a second group menu.
    override func rightMouseUp(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        let geometry = artworkLayout
        if isHighlighted {
            NSColor.labelColor.withAlphaComponent(0.16).setFill()
            // Keep the highlight circular even when the user widens the click
            // target. Item spacing and the group's trailing gap have no fill.
            let diameter = max(0, min(bounds.width, bounds.height) - 2)
            let centerX = app == nil ? bounds.midX : geometry.iconRect.midX
            let circle = NSRect(x: centerX - diameter / 2,
                                y: bounds.midY - diameter / 2,
                                width: diameter, height: diameter)
            NSBezierPath(ovalIn: circle).fill()
        }
        guard let app = app else {
            let text = "⋯"
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 16), .foregroundColor: NSColor.labelColor]
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
            return
        }
        // Preserve the original artwork scale, including transparent padding.
        // Large icons are clipped to the menu-bar slot, as in the original app.
        let iconRect = geometry.iconRect
        app.icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1,
                      respectFlipped: true, hints: nil)
        if app.isRunning {
            NSColor.labelColor.withAlphaComponent(0.9).setFill()
            NSBezierPath(ovalIn: geometry.indicatorRect).fill()
        }
        if let number = app.instanceNumber {
            let text = String(number)
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 8), .foregroundColor: NSColor.white]
            let textSize = text.size(withAttributes: attributes)
            let width = max(11, textSize.width + 4)
            // Oversized artwork extends beyond the slot; the badge must remain
            // visible and sit at its physical bottom in flipped coordinates.
            let x = min(bounds.maxX - width - 1, iconRect.maxX - width)
            let y = isFlipped ? bounds.maxY - 12 : bounds.minY + 1
            let badge = NSRect(x: max(bounds.minX, x), y: y, width: width, height: 11)
            NSColor.systemRed.setFill()
            NSBezierPath(roundedRect: badge, xRadius: 5.5, yRadius: 5.5).fill()
            text.draw(at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2), withAttributes: attributes)
        }
    }
}

/// Reserve indicator space for every entry so starting/quitting an app does
/// not shift its artwork. The group widens slots before drawing large icons.
struct DockItemLayout {
    let iconRect: NSRect
    let indicatorRect: NSRect

    static func indicatorDiameter(iconSize: CGFloat) -> CGFloat { min(5, max(1.5, iconSize * 0.10)) }
    static func indicatorGap(iconSize: CGFloat) -> CGFloat { min(2, max(0.75, iconSize * 0.04)) }

    static func slotWidth(requested: CGFloat, iconSize: CGFloat) -> CGFloat {
        max(requested, ceil(iconSize + indicatorDiameter(iconSize: iconSize) + indicatorGap(iconSize: iconSize) + 2))
    }

    init(bounds: NSRect, iconSize: CGFloat) {
        let diameter = Self.indicatorDiameter(iconSize: iconSize)
        let gap = Self.indicatorGap(iconSize: iconSize)
        let width = iconSize + diameter + gap
        let left = bounds.midX - width / 2
        indicatorRect = NSRect(x: left, y: bounds.midY - diameter / 2, width: diameter, height: diameter)
        iconRect = NSRect(x: indicatorRect.maxX + gap, y: bounds.midY - iconSize / 2,
                          width: iconSize, height: iconSize)
    }
}

enum DockMenuPresentation {
    static func anchor(from view: NSView) -> NSPoint? {
        guard let window = view.window else { return nil }
        let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
        return NSPoint(x: rect.minX, y: rect.minY - 1)
    }

    static func popUp(_ menu: NSMenu, from view: NSView) {
        menu.update()
        guard let point = anchor(from: view) else { return }
        // Screen coordinates keep the menu independent of view transforms and
        // AppKit's correction of an anchor overlapping the menu bar.
        _ = menu.popUp(positioning: nil, at: point, in: nil)
    }
}

enum DockHoverMotion {
    static let millimeters: CGFloat = 1.5
    static let duration: CFTimeInterval = 0.18

    static func distance(screenHeight: CGFloat, physicalHeight: CGFloat) -> CGFloat {
        guard screenHeight.isFinite, physicalHeight.isFinite,
              screenHeight > 0, physicalHeight > 40,
              screenHeight / physicalHeight < 20 else { return millimeters * 72 / 25.4 }
        return millimeters * screenHeight / physicalHeight
    }

    static func distance(on screen: NSScreen?) -> CGFloat {
        guard let screen = screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return distance(screenHeight: 0, physicalHeight: 0)
        }
        let display = CGDirectDisplayID(number.uint32Value)
        let physical = CGDisplayScreenSize(display)
        let rotation = CGDisplayRotation(display).truncatingRemainder(dividingBy: 360)
        let portrait = (45...135).contains(rotation) || (225...315).contains(rotation)
        return distance(screenHeight: screen.frame.height, physicalHeight: portrait ? physical.width : physical.height)
    }
}

private final class DockHoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// One reusable, noninteractive visual window lets the sprite move below the
/// menu bar. Click targets and tracking rectangles stay in the original bar.
final class DockHoverOverlay: NSObject, CAAnimationDelegate {
    static let shared = DockHoverOverlay()
    private(set) weak var owner: DockItemButton?
    private(set) var targetOffset: CGFloat = 0
    private(set) var distance: CGFloat = 0
    private var generation = 0
    private var panel: DockHoverPanel?
    private let imageView = NSImageView(frame: .zero)
    private let animationKey = "dockHover"

    var visualFrame: NSRect? { panel?.frame }
    var isVisible: Bool { panel?.isVisible == true }
    var currentAnimation: CABasicAnimation? { imageView.layer?.animation(forKey: animationKey) as? CABasicAnimation }

    private override init() {
        super.init()
        imageView.wantsLayer = true
        imageView.imageScaling = .scaleNone
    }

    func show(for button: DockItemButton, distance: CGFloat, animated: Bool) {
        guard distance.isFinite, distance > 0, let sourceWindow = button.window else { return }
        if owner !== button {
            dismiss()
            guard let image = button.hoverSnapshot() else { return }
            owner = button
            imageView.image = image
        }
        if panel == nil {
            let window = DockHoverPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.contentView = NSView(frame: .zero)
            window.contentView?.addSubview(imageView)
            panel = window
        }
        guard let panel = panel else { return }
        self.distance = distance
        let sourceRect = sourceWindow.convertToScreen(button.convert(button.hoverArtworkBounds, to: nil))
        // This window contains both endpoints of the animation, so the lower
        // part of the icon is never clipped by the status-item window.
        let envelope = NSRect(x: sourceRect.minX, y: sourceRect.minY - distance,
                              width: sourceRect.width, height: sourceRect.height + distance).integral
        panel.setFrame(envelope, display: false)
        imageView.frame = NSRect(x: sourceRect.minX - panel.frame.minX, y: sourceRect.minY - panel.frame.minY,
                                 width: sourceRect.width, height: sourceRect.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        button.layer?.opacity = 0
        CATransaction.commit()
        if sourceWindow.isVisible {
            if panel.parent !== sourceWindow {
                panel.parent?.removeChildWindow(panel)
                sourceWindow.addChildWindow(panel, ordered: .above)
            }
            panel.orderFront(nil)
        }
        animate(to: -distance, animated: animated)
    }

    func hide(for button: DockItemButton, animated: Bool) {
        guard owner === button else { return }
        if animated, panel?.isVisible == true { animate(to: 0, animated: true) }
        else { dismiss() }
    }

    private func animate(to offset: CGFloat, animated: Bool) {
        guard let layer = imageView.layer else { return }
        let from = layer.presentation()?.transform.m42 ?? layer.transform.m42
        generation += 1
        targetOffset = offset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeTranslation(0, offset, 0)
        CATransaction.commit()
        layer.removeAnimation(forKey: animationKey)
        if animated {
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = from
            animation.toValue = offset
            animation.duration = DockHoverMotion.duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.delegate = self
            animation.setValue(generation, forKey: "generation")
            layer.add(animation, forKey: animationKey)
        }
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag, (anim.value(forKey: "generation") as? NSNumber)?.intValue == generation,
              targetOffset == 0, owner?.isHovered != true else { return }
        dismiss()
    }

    private func dismiss() {
        generation += 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        owner?.layer?.opacity = 1
        imageView.layer?.removeAnimation(forKey: animationKey)
        imageView.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
        if let panel = panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        imageView.image = nil
        owner = nil
        targetOffset = 0
    }
}
