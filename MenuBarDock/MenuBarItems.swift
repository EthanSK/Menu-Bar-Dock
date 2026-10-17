import Cocoa

protocol MenuBarItemsUserPrefsDataSource: AnyObject {
    var appOpeningMethods: [String: AppOpeningMethod] { get }
    var itemSlotWidth: CGFloat { get }
    var appIconSize: CGFloat { get }
    var rightClickByDefault: Bool { get }
    var groupSpacing: CGFloat { get }
    var hoverAnimationsEnabled: Bool { get }
    var groupBackgroundEnabled: Bool { get }
}

protocol MenuBarItemsDelegate: AnyObject {
    func didOpenPreferencesWindow()
    func didCheckForUpdates()
    func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp)
    func didChangeGroupSpacing(_ spacing: CGFloat)
}

/// One status item owns the entire group. System icons cannot be inserted between its children.
class MenuBarItems {
    weak var userPrefsDataSource: MenuBarItemsUserPrefsDataSource!
    weak var delegate: MenuBarItemsDelegate?
    private(set) var items: [MenuBarItem] = []
    let statusItem: NSStatusItem
    var isGroupBackgroundVisible: Bool { !background.isHidden }
    private let background = DockGroupBackground(frame: .zero)
    private var apps: [OpenableApp] = []
    private var itemCache: [String: MenuBarItem] = [:]
    private var screenObserver: NSObjectProtocol?
    private var menuTrackingDepth = 0
    private var pendingRender = false

    init(userPrefsDataSource: MenuBarItemsUserPrefsDataSource) {
        self.userPrefsDataSource = userPrefsDataSource
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        statusItem.autosaveName = "GroupedDock"
        // AppKit reads the legacy Item-0 visibility before autosaveName is set.
        // Changing the name does not unhide an item created in that state.
        statusItem.isVisible = true
        // The system button spans both the icons and the trailing spacer. Its
        // native highlight would paint a long capsule across that entire width.
        // Each child draws its own circular pressed state instead.
        (statusItem.button?.cell as? NSButtonCell)?.highlightsBy = []
        statusItem.button?.addSubview(background)
        // The parent remains a native status-bar button for command-drag and position persistence.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showGroupMenu)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("Menu Bar Dock group")
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.render()
        }
    }

    deinit {
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func update(openableApps: OpenableApps) {
        update(apps: openableApps.apps)
    }

    func update(apps: [OpenableApp]) {
        self.apps = apps
        render()
    }

    func refreshLayout() { render() }

    /// Conservative budget leaves room for system icons; overflow stays reachable in a menu.
    private var widthBudget: CGFloat {
        guard let screen = statusItem.button?.window?.screen ?? NSScreen.screens.first else { return 480 }
        var width = screen.frame.width * 0.45
        if #available(macOS 12.0, *), let right = screen.auxiliaryTopRightArea {
            width = min(width, right.width - 120)
        }
        return max(120, width)
    }

    private func render() {
        guard menuTrackingDepth == 0 else { pendingRender = true; return }
        guard let button = statusItem.button else { return }
        background.isHidden = !userPrefsDataSource.groupBackgroundEnabled
        let oldItems = items
        var newItems: [MenuBarItem] = []
        var newCache: [String: MenuBarItem] = [:]
        var occurrences: [String: Int] = [:]
        let slotWidth = DockItemLayout.slotWidth(requested: min(64, max(30, userPrefsDataSource.itemSlotWidth)),
                                                iconSize: userPrefsDataSource.appIconSize)
        let gap = min(160, max(0, userPrefsDataSource.groupSpacing))
        let layout = DockGroupLayout(count: apps.count, slotWidth: slotWidth, spacing: gap, budget: widthBudget)
        if statusItem.length != layout.totalWidth { statusItem.length = layout.totalWidth }
        let height = max(22, button.bounds.height)
        let backgroundFrame = NSRect(x: 0, y: 0, width: layout.groupWidth, height: height)
        if background.frame != backgroundFrame {
            background.frame = backgroundFrame
            background.needsDisplay = true
        }
        background.autoresizingMask = [.height]

        for (index, app) in apps.prefix(layout.visibleCount).enumerated() {
            let identity = "\(app.id)|\(app.runningApplication?.processIdentifier ?? 0)"
            let occurrence = occurrences[identity, default: 0]
            occurrences[identity] = occurrence + 1
            let key = "\(identity)|\(occurrence)"
            let item = itemCache[key] ?? makeItem(app: nil)
            item.button.hoverAnimationsEnabled = userPrefsDataSource.hoverAnimationsEnabled
            item.update(for: app, appIconSize: userPrefsDataSource.appIconSize, slotWidth: slotWidth)
            newCache[key] = item
            let frame = NSRect(x: 4 + CGFloat(index) * slotWidth, y: 0, width: slotWidth, height: height)
            if item.button.frame != frame { item.button.resetHover(); item.button.frame = frame }
            item.button.autoresizingMask = [.height]
            if item.button.superview !== button { button.addSubview(item.button) }
            newItems.append(item)
        }
        if layout.needsMenu {
            let menuItem = itemCache["overflow"] ?? makeItem(app: nil)
            newCache["overflow"] = menuItem
            menuItem.overflowItems = []
            menuItem.overflowApps = Array(apps.dropFirst(layout.visibleCount))
            menuItem.button.toolTip = apps.isEmpty ? "Menu Bar Dock Preferences" : "More apps and folders"
            menuItem.button.setAccessibilityLabel(menuItem.button.toolTip)
            let frame = NSRect(x: 4 + CGFloat(layout.visibleCount) * slotWidth, y: 0, width: slotWidth, height: height)
            if menuItem.button.frame != frame { menuItem.button.frame = frame }
            menuItem.button.autoresizingMask = [.height]
            if menuItem.button.superview !== button { button.addSubview(menuItem.button) }
            newItems.append(menuItem)
        }
        oldItems.filter { old in !newItems.contains(where: { $0 === old }) }.forEach { $0.button.removeFromSuperview() }
        items = newItems
        itemCache = newCache // No accumulation of closed apps or old overflow entries.
    }

    private func makeItem(app: OpenableApp?) -> MenuBarItem {
        let item = MenuBarItem(userPrefsDataSource: self)
        item.delegate = self
        if let app = app {
            item.update(for: app, appIconSize: userPrefsDataSource.appIconSize, slotWidth: userPrefsDataSource.itemSlotWidth)
        }
        return item
    }

    @objc private func showGroupMenu() {
        menuWillOpen()
        defer { menuDidClose() }
        let item = makeItem(app: nil)
        guard let menu = item.makeDropdownMenu(), let button = statusItem.button else { return }
        withExtendedLifetime(item) {
            DockMenuPresentation.popUp(menu, from: button)
        }
    }
}

/// Pure geometry shared with regression checks: always keep an empty-dock/overflow control.
struct DockGroupLayout {
    let visibleCount: Int
    let needsMenu: Bool
    let groupWidth: CGFloat
    let totalWidth: CGFloat

    init(count: Int, slotWidth: CGFloat, spacing: CGFloat, budget: CGFloat) {
        let gap = min(spacing, max(0, budget - slotWidth - 8))
        let capacity = max(1, Int((budget - gap - 8) / slotWidth))
        needsMenu = count == 0 || count > capacity
        visibleCount = count > capacity ? capacity - 1 : count
        groupWidth = 8 + CGFloat(visibleCount + (needsMenu ? 1 : 0)) * slotWidth
        totalWidth = groupWidth + gap
    }
}

private final class DockGroupBackground: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 2.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        path.fill()
        NSColor.labelColor.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

extension MenuBarItems: MenuBarItemDataSource {
    var rightClickByDefault: Bool { userPrefsDataSource.rightClickByDefault }
    var groupSpacing: CGFloat { userPrefsDataSource.groupSpacing }
    func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod? { userPrefsDataSource.appOpeningMethods[app.id] }
}

extension MenuBarItems: MenuBarItemDelegate {
    func menuWillOpen() { menuTrackingDepth += 1 }
    func menuDidClose() {
        menuTrackingDepth = max(0, menuTrackingDepth - 1)
        if menuTrackingDepth == 0 && pendingRender {
            pendingRender = false
            render()
        }
    }
    func didOpenPreferencesWindow() { delegate?.didOpenPreferencesWindow() }
    func didCheckForUpdates() { delegate?.didCheckForUpdates() }
    func didSetAppOpeningMethod(_ method: AppOpeningMethod?, _ app: OpenableApp) { delegate?.didSetAppOpeningMethod(method, app) }
    func didChangeGroupSpacing(_ spacing: CGFloat) { delegate?.didChangeGroupSpacing(spacing) }
}
