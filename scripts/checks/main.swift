import Cocoa

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("FAIL: \(message)") }
    print("PASS: \(message)")
    fflush(stdout)
}

_ = NSApplication.shared
let suite = "local.menubardock.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let prefs = UserPrefs(defaults: defaults)
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
let folder = root.appendingPathComponent("Папка с пробелами.v1", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
let ordinaryFile = root.appendingPathComponent("file.txt")
try Data("test".utf8).write(to: ordinaryFile)
expect(RegularApp.isPinnableFolder(folder), "folders with Unicode, spaces and dots are supported")
expect(!RegularApp.isPinnableFolder(finderURL), "application packages are not folders")
expect(!RegularApp.isPinnableFolder(ordinaryFile), "ordinary files cannot be pinned as folders")
expect(!RegularApp.isPinnableFolder(root.appendingPathComponent("missing")), "missing folders are rejected")

prefs.regularAppsUrls = [folder, finderURL]
prefs.groupSpacing = 96
prefs.save()
let loaded = UserPrefs(defaults: defaults)
loaded.load()
expect(loaded.regularAppsUrls == [folder, finderURL], "folder/app order and URLs survive preference reload")
expect(loaded.groupSpacing == 96, "group spacing survives preference reload")
let regular = RegularApps(userPrefsDataSource: loaded)
expect(regular.apps.count == 2, "pinned folder and Finder both load")
expect(regular.apps[0].name == "Папка с пробелами.v1", "folder names retain their extension")
let folderApp = OpenableApp(regularApp: regular.apps[0], appOpeningMethod: .activate)
expect(folderApp.isFolder && !folderApp.isRunning && folderApp.runningApplication == nil, "folders do not inherit Finder's running state")
let finder = OpenableApp(regularApp: regular.apps[1], appOpeningMethod: .launch)
expect(!finder.isFolder && finder.isRunning, "pinned Finder has its own running indicator")

final class Source: MenuBarItemDataSource {
    let rightClickByDefault = false
    let groupSpacing: CGFloat = 48
    func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod? { nil }
}
let source = Source()
let folderItem = MenuBarItem(userPrefsDataSource: source)
folderItem.update(for: folderApp, appIconSize: 18, slotWidth: 30)
let folderTitles = folderItem.makeDropdownMenu()!.items.map(\.title)
expect(folderTitles.contains("Open \(folderApp.name) in Finder"), "folder menu opens the folder")
expect(!folderTitles.contains(where: { $0.hasPrefix("Quit \(folderApp.name)") || $0.hasPrefix("Change opening method") || $0.hasPrefix("Hide ") }), "folder menu omits process-only operations")
let runningItem = MenuBarItem(userPrefsDataSource: source)
runningItem.update(for: finder, appIconSize: 18, slotWidth: 30)
expect(runningItem.makeDropdownMenu()?.items.first?.title == "Quit \(finder.name)", "running app menu keeps Quit first")
let stopped = OpenableApp(bundleId: "test", icon: finder.icon, bundleUrl: finderURL, name: "Stopped", id: "stopped", appOpeningMethod: .launch, runningApplication: nil)
expect(!stopped.isRunning, "stopped app has no running indicator")
let emptyItem = MenuBarItem(userPrefsDataSource: source)
expect(emptyItem.makeDropdownMenu()!.items.contains(where: { $0.title.contains("Preferences") }), "empty dock retains a preferences action")

for count in [0, 1, 3, 10, 100] {
    for budget: CGFloat in [120, 300, 800] {
        for gap: CGFloat in [0, 48, 160] {
            let layout = DockGroupLayout(count: count, slotWidth: 30, spacing: gap, budget: budget)
            precondition(layout.totalWidth <= budget)
            precondition(layout.visibleCount <= count)
            precondition(layout.visibleCount == count || layout.needsMenu)
            precondition(count > 0 || layout.needsMenu)
        }
    }
}
expect(true, "45 narrow/wide, empty and overflow layouts remain within budget")
// Reproduce the production startup failure before creating the first status item.
let legacyVisibilityKey = "NSStatusItem VisibleCC Item-0"
let oldVisibility = UserDefaults.standard.object(forKey: legacyVisibilityKey)
UserDefaults.standard.set(false, forKey: legacyVisibilityKey)
defer {
    if let oldVisibility = oldVisibility { UserDefaults.standard.set(oldVisibility, forKey: legacyVisibilityKey) }
    else { UserDefaults.standard.removeObject(forKey: legacyVisibilityKey) }
}
let dock = MenuBarItems(userPrefsDataSource: loaded)
expect(dock.statusItem.isVisible, "startup unhides the dock despite a hidden legacy Item-0")
let identity = dock.statusItem
for apps in [[folderApp, finder], [folderApp], [], [finder, folderApp]] {
    dock.update(apps: apps)
    expect(dock.statusItem === identity, "group reuses one status item across content changes")
}
expect(dock.statusItem.autosaveName == "GroupedDock", "group position has a stable autosave identity")
let overflow = MenuBarItem(userPrefsDataSource: source)
overflow.overflowItems = [folderItem, runningItem]
expect(overflow.makeDropdownMenu()?.items[0].submenu?.items.contains(where: { $0.title.hasPrefix("Open ") }) == true, "overflow keeps folder actions accessible")
// Fresh migration excludes system/updater state but retains the user's pins.
let migrationSuite = "local.menubardock.migration-tests.\(UUID().uuidString)"
let migrationDefaults = UserDefaults(suiteName: migrationSuite)!
defer { migrationDefaults.removePersistentDomain(forName: migrationSuite) }
let migrated = UserPrefs(defaults: migrationDefaults)
migrated.prepareLocalPreferences(original: [
    Constants.UserPrefs.regularAppsUrls: [folder.absoluteString],
    Constants.UserPrefs.launchAtLogin: true,
    legacyVisibilityKey: false,
    "SUHasLaunchedBefore": true
])
expect(migrationDefaults.object(forKey: legacyVisibilityKey) == nil, "migration excludes upstream hidden-item flags")
expect(migrationDefaults.object(forKey: "SUHasLaunchedBefore") == nil, "migration excludes updater state")
migrated.load()
expect(migrated.regularAppsUrls == [folder] && !migrated.launchAtLogin, "migration retains pins and leaves local login disabled")
migrated.regularAppsUrls = [finderURL, folder]
migrated.save()
migrationDefaults.set(false, forKey: legacyVisibilityKey)
migrationDefaults.set(240, forKey: "NSStatusItem Preferred Position GroupedDock")
migrated.prepareLocalPreferences(original: [Constants.UserPrefs.regularAppsUrls: []])
migrated.load()
expect(migrated.regularAppsUrls == [finderURL, folder], "upgrade repairs visibility without overwriting edited pins")
expect(migrationDefaults.object(forKey: legacyVisibilityKey) == nil, "upgrade removes previously imported legacy visibility")
expect(migrationDefaults.integer(forKey: "NSStatusItem Preferred Position GroupedDock") == 240, "upgrade preserves the group position")

let sizeSuite = "local.menubardock.size-tests.\(UUID().uuidString)"
let sizeDefaults = UserDefaults(suiteName: sizeSuite)!
defer { sizeDefaults.removePersistentDomain(forName: sizeSuite) }
sizeDefaults.set(true, forKey: "groupedLocalPreferencesImported")
sizeDefaults.set(20.0, forKey: Constants.UserPrefs.appIconSize)
let sizePrefs = UserPrefs(defaults: sizeDefaults)
sizePrefs.prepareLocalPreferences(original: [Constants.UserPrefs.appIconSize: 25.423])
sizePrefs.load()
expect(abs(sizePrefs.appIconSize - 25.423) < 0.001, "upgrade restores the original icon size after the old 20 pt cap")
sizePrefs.appIconSize = 18
sizePrefs.save()
sizePrefs.prepareLocalPreferences(original: [Constants.UserPrefs.appIconSize: 40.0])
sizePrefs.load()
expect(sizePrefs.appIconSize == 18, "later local icon-size adjustments are retained")
sizePrefs.appIconSize = 40
sizePrefs.save()
sizePrefs.load()
expect(sizePrefs.appIconSize == 40, "larger icon sizes survive preference reload")

// Render our own offscreen views, not the user's desktop. Compare orientation
// against NSImageView, which was used by the original application.
func render(_ view: NSView) -> NSBitmapImageRep {
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return bitmap
}
let asymmetricIcon = NSImage(size: NSSize(width: 26, height: 26), flipped: false) { rect in
    NSColor.red.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 13, width: 26, height: 13)).fill()
    NSColor.blue.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 26, height: 13)).fill()
    return true
}
let artworkApp = OpenableApp(bundleId: "test.artwork", icon: asymmetricIcon,
                            bundleUrl: finderURL, name: "Artwork", id: "artwork",
                            appOpeningMethod: .launch, runningApplication: nil)
let artworkButton = DockItemButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
artworkButton.app = artworkApp
artworkButton.iconSize = 26
let reference = NSImageView(frame: artworkButton.frame)
reference.image = asymmetricIcon
reference.imageScaling = .scaleNone
let actualBitmap = render(artworkButton)
let referenceBitmap = render(reference)
let x = actualBitmap.pixelsWide / 2
let upper = actualBitmap.pixelsHigh / 4
let lower = actualBitmap.pixelsHigh * 3 / 4
let actualTop = actualBitmap.colorAt(x: x, y: upper)!.usingColorSpace(.deviceRGB)!
let referenceTop = referenceBitmap.colorAt(x: x, y: upper)!.usingColorSpace(.deviceRGB)!
let actualBottom = actualBitmap.colorAt(x: x, y: lower)!.usingColorSpace(.deviceRGB)!
let referenceBottom = referenceBitmap.colorAt(x: x, y: lower)!.usingColorSpace(.deviceRGB)!
expect(abs(actualTop.redComponent - referenceTop.redComponent) < 0.05 &&
       abs(actualBottom.redComponent - referenceBottom.redComponent) < 0.05,
       "icon orientation matches native NSImageView in the actual button coordinates")
let wideArtwork = MenuBarItem(userPrefsDataSource: source)
wideArtwork.update(for: artworkApp, appIconSize: 40, slotWidth: 30)
expect(wideArtwork.button.iconSize == 40, "menu-bar artwork is not reduced to the slot height")

let transparentIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in true }
let indicatorApp = OpenableApp(bundleId: "test.indicator", icon: transparentIcon,
                              bundleUrl: finderURL, name: "Indicator", id: "indicator",
                              appOpeningMethod: .launch, runningApplication: NSRunningApplication.current)
let indicatorButton = DockItemButton(frame: NSRect(x: 0, y: 0, width: 30, height: 22))
indicatorButton.app = indicatorApp
indicatorButton.iconSize = 18
let indicatorBitmap = render(indicatorButton)
let center = indicatorBitmap.pixelsWide / 2
let scale = indicatorBitmap.pixelsHigh / 22
let indicatorX = Int(indicatorButton.artworkLayout.indicatorRect.midX * CGFloat(scale))
expect(indicatorBitmap.colorAt(x: indicatorX, y: 11 * scale)!.alphaComponent > 0.5 &&
       indicatorButton.artworkLayout.indicatorRect.maxX < indicatorButton.artworkLayout.iconRect.minX,
       "running indicator is a small dot to the left of the icon")
expect(indicatorBitmap.colorAt(x: indicatorX, y: 5 * scale)!.alphaComponent < 0.05 &&
       indicatorBitmap.colorAt(x: center, y: 2 * scale)!.alphaComponent < 0.05,
       "running indicator draws neither a side bar nor a top dot")
indicatorApp.runningApplication = nil
let stoppedBitmap = render(indicatorButton)
expect(stoppedBitmap.colorAt(x: indicatorX, y: 11 * scale)!.alphaComponent < 0.05,
       "stopped applications do not draw the left dot")

let resources = Bundle(url: URL(fileURLWithPath: ProcessInfo.processInfo.environment["MBD_RESOURCE_APP"] ?? "/Applications/Menu Bar Dock.app"))!
let controller = NSStoryboard(name: "Main", bundle: resources)
    .instantiateController(withIdentifier: Constants.Identifiers.ViewControllers.preferences) as! PreferencesViewController
controller.userPrefsDataSource = loaded
_ = controller.view
controller.viewWillAppear()
controller.view.layoutSubtreeIfNeeded()
expect(controller.groupSpacingSlider.doubleValue == 96 &&
       controller.groupSpacingCounterLabel.stringValue == "96 pt",
       "Preferences exposes the saved group margin as a visible slider")
let marginControls = controller.groupSpacingSlider.superview!
let general = marginControls.superview!
let bottomBar = controller.launchAtLoginButton.superview!
let openingMethod = controller.appOpeningMethodPopUp.superview!
expect(general.bounds.contains(marginControls.frame) && marginControls.frame.width > 250 &&
       marginControls.frame.minY > bottomBar.frame.maxY &&
       marginControls.frame.maxY < openingMethod.frame.minY,
       "margin controls fit between existing settings without overlap")
controller.groupSpacingSlider.doubleValue = 47.8
controller.groupSpacingSliderChanged(controller.groupSpacingSlider)
expect(controller.groupSpacingCounterLabel.stringValue == "48 pt",
       "margin slider shows rounded point values")
expect(controller.appIconSizeSlider.maxValue == 100,
       "Preferences allows the original larger icon sizes")

// Review regressions: malformed preferences, keyboard actions, lifetime and caching.
defaults.set(-20, forKey: Constants.UserPrefs.maxNumRunningApps)
defaults.set(Double.nan, forKey: Constants.UserPrefs.groupSpacing)
defaults.set(Double.infinity, forKey: Constants.UserPrefs.appIconSize)
defaults.set(-100, forKey: Constants.UserPrefs.statusItemWidth)
defaults.set([folder.absoluteString, folder.absoluteString, "https://example.invalid/app"], forKey: Constants.UserPrefs.regularAppsUrls)
let repaired = UserPrefs(defaults: defaults)
repaired.load()
expect(repaired.maxRunningApps == 0, "negative running-app limit is repaired instead of crashing")
expect(repaired.groupSpacing == 48 && repaired.appIconSize == 40 && repaired.itemSlotWidth == 30,
       "non-finite and out-of-range dimensions load safely")
expect(repaired.regularAppsUrls == [folder], "malformed and duplicate pinned URLs are filtered")

let cachedFolder = regular.apps[0]
regular.update(runningApplications: [])
expect(regular.apps[0] === cachedFolder, "ordinary updates reuse pinned objects and their artwork")
loaded.regularAppsUrls = [finderURL, folder]
regular.update(runningApplications: [])
expect(regular.apps[1] === cachedFolder, "pin reordering preserves cached artwork")
expect(regular.apps[0].runningApp == nil, "a shared snapshot clears stopped pinned apps")
let folderImageData = folderApp.icon.tiffRepresentation!
loaded.appIconOverrides[folder.absoluteString] = folderImageData
let cachedImage = loaded.iconOverride(forAppAt: folder)!
expect(loaded.iconOverride(forAppAt: folder) === cachedImage, "custom icons are decoded once and reused")
loaded.appIconOverrides[folder.absoluteString] = finder.icon.tiffRepresentation!
expect(loaded.iconOverride(forAppAt: folder) !== cachedImage, "changing a custom icon invalidates its decoded cache")
loaded.appIconOverrides[folder.absoluteString] = nil
expect(loaded.iconOverride(forAppAt: folder) == nil, "resetting a custom icon removes its cache")
loaded.appIconOverrides[folder.absoluteString] = Data("invalid-image".utf8)
expect(loaded.iconOverride(forAppAt: folder) == nil, "damaged custom icons fall back safely")

dock.update(apps: [folderApp, finder])
let reusedButton = dock.items[0].button
dock.update(apps: [finder, folderApp])
expect(dock.items[1].button === reusedButton, "content refresh and reorder reuse the same native buttons")
loaded.groupSpacing = 24
dock.refreshLayout()
expect(dock.items[1].button === reusedButton, "appearance-only settings preserve native buttons")
dock.update(apps: [folderApp, folderApp])
expect(dock.items.count == 2 && dock.items[0] !== dock.items[1], "intentional duplicate entries retain separate click targets")
weak var retiredItem: MenuBarItem?
weak var retiredButton: NSButton?
autoreleasepool {
    let retiringApp = OpenableApp(bundleId: "retiring", icon: finder.icon, bundleUrl: finderURL,
                                 name: "Retiring", id: "retiring", appOpeningMethod: .launch, runningApplication: nil)
    dock.update(apps: [retiringApp])
    retiredItem = dock.items[0]
    retiredButton = dock.items[0].button
    dock.update(apps: [])
}
expect(retiredItem == nil && retiredButton == nil, "removed buttons do not accumulate in the cache")

expect(["a", "b", "c", "d", "e"].movingElements(at: IndexSet([1, 3]), to: 5) == ["a", "c", "e", "b", "d"],
       "multiple dragged rows preserve their order when moved down")
expect(["a", "b", "c", "d", "e"].movingElements(at: IndexSet([2, 4]), to: 0) == ["c", "e", "a", "b", "d"],
       "multiple dragged rows preserve their order when moved up")
expect(["a", "b"].movingElements(at: IndexSet(integer: 99), to: 0) == nil &&
       ["a", "b"].movingElements(at: IndexSet(integer: 0), to: -1) == nil,
       "invalid drag indexes and destinations are rejected safely")

final class SliderDelegate: PreferencesViewControllerDelegate {
    var iconSize: Double?
    var slotWidth: Double?
    var runningLimit: Int?
    var margin: Double?
    var animations: Bool?
    var background: Bool?
    var restarts = 0
    func hoverAnimationsDidChange(_ value: Bool) { animations = value }
    func groupBackgroundDidChange(_ value: Bool) { background = value }
    func restartAppWasPressed() { restarts += 1 }
    func appIconSizeSliderDidChange(_ value: Double) { iconSize = value }
    func itemSlotWidthSliderDidChange(_ value: Double) { slotWidth = value }
    func maxRunningAppsSliderDidChange(_ value: Int) { runningLimit = value }
    func groupSpacingSliderDidChange(_ value: Double) { margin = value }
    func runningAppsSortingMethodDidChange(_ value: RunningAppsSortingMethod) {}
    func hideFinderDidChange(_ value: Bool) {}
    func hideActiveAppDidChange(_ value: Bool) {}
    func hideDuplicateAppsDidChange(_ value: Bool) {}
    func preserveAppOrderDidChange(_ value: Bool) {}
    func rightClickByDefaultDidChange(_ value: Bool) {}
    func regularAppsUrlsWereAdded(_ value: [URL]) {}
    func regularAppsUrlsWereRemoved(_ removedIndexes: IndexSet) {}
    func regularAppsUrlsWereReordered(_ urls: [URL]) {}
    func appIconOverrideDidChange(_ imageData: Data?, forAppAt url: URL) {}
    func infoWasPressed() {}
    func sideToShowRunningAppsDidChange(_ value: SideToShowRunningApps) {}
    func duplicateAppsPriorityDidChange(_ value: DuplicateAppsPriority) {}
    func appOpeningMethodDidChange(_ value: AppOpeningMethod) {}
    func aboutWasPressed() {}
    func resetPreferencesToDefaultsWasPressed() {}
    func resetAppOpeningMethodsWasPressed() {}
    func checkForUpdatesWasPressed(_ sender: Any?) {}
    func launchAtLoginDidChange(_ value: Bool) {}
}
let sliderDelegate = SliderDelegate()
controller.delegate = sliderDelegate
controller.appIconSizeSlider.doubleValue = 35
controller.appIconSizeSliderChange(controller.appIconSizeSlider)
controller.itemSlotWidthSlider.doubleValue = 45
controller.statusItemWidthSliderChanged(controller.itemSlotWidthSlider)
controller.maxRunningAppsSlider.integerValue = 7
controller.numberOfAppsSliderChanged(controller.maxRunningAppsSlider)
controller.groupSpacingSlider.doubleValue = 56
controller.groupSpacingSliderChanged(controller.groupSpacingSlider)
expect(sliderDelegate.iconSize == 35 && sliderDelegate.slotWidth == 45 &&
       sliderDelegate.runningLimit == 7 && sliderDelegate.margin == 56,
       "slider keyboard and accessibility actions commit every setting without a mouse event")

final class TrackerDelegate: AppTrackerDelegate {
    var activations = 0
    func appWasActivated(runningApp: NSRunningApplication) { activations += 1 }
    func appWasLaunched(runningApp: NSRunningApplication) {}
    func appWasQuit(runningApp: NSRunningApplication) {}
}
let centerForTest = NotificationCenter()
let trackerDelegate = TrackerDelegate()
var tracker: AppTracker? = AppTracker(center: centerForTest)
tracker?.delegate = trackerDelegate
let oldPolicy = NSApp.activationPolicy()
_ = NSApp.setActivationPolicy(.accessory)
centerForTest.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                   userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
expect(trackerDelegate.activations == 1, "accessory activation reaches the active-app state tracker")
weak var releasedTracker = tracker
tracker = nil
expect(releasedTracker == nil, "notification observers do not retain the tracker")
centerForTest.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                   userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
expect(trackerDelegate.activations == 1, "tracker observers are removed on deinitialization")

let runningPrefs = UserPrefs(defaults: UserDefaults(suiteName: "local.menubardock.running-tests.\(UUID().uuidString)")!)
runningPrefs.hideActiveAppFromRunningApps = true
runningPrefs.maxRunningApps = 10
let finderProcess = finder.runningApplication!
let appList = RunningApps(userPrefsDataSource: runningPrefs, runningApplications: { [finderProcess] })
appList.handleAppActivation(runningApp: finderProcess)
appList.update(runningApplications: [finderProcess])
expect(appList.apps.isEmpty, "the active regular app is hidden")
appList.handleAppActivation(runningApp: NSRunningApplication.current)
appList.update(runningApplications: [finderProcess, NSRunningApplication.current])
expect(appList.apps.contains(where: { $0.app.processIdentifier == finderProcess.processIdentifier }),
       "activating an accessory app restores the previously hidden regular app")
runningPrefs.maxRunningApps = 0
appList.update(runningApplications: [finderProcess])
expect(appList.apps.isEmpty, "zero running-app limit stays zero even without pinned entries")
runningPrefs.maxRunningApps = -1
appList.update(runningApplications: [finderProcess])
expect(appList.apps.isEmpty, "a negative datasource limit cannot crash array truncation")
_ = NSApp.setActivationPolicy(oldPolicy)

final class CountingDefaults: UserDefaults {
    var writes = 0
    override func set(_ value: Any?, forKey defaultName: String) {
        writes += 1
        super.set(value, forKey: defaultName)
    }
}
let writesSuite = "local.menubardock.writes-tests.\(UUID().uuidString)"
let countingDefaults = CountingDefaults(suiteName: writesSuite)!
defer { countingDefaults.removePersistentDomain(forName: writesSuite) }
let writePrefs = UserPrefs(defaults: countingDefaults)
writePrefs.save()
countingDefaults.writes = 0
writePrefs.save()
expect(countingDefaults.writes == 0, "unchanged preferences perform no UserDefaults writes")
writePrefs.groupSpacing = 83
writePrefs.save()
expect(countingDefaults.writes == 1, "changing the margin writes only that preference")

var evaluatedDiagnostic = false
DebugLog.shared.log({ evaluatedDiagnostic = true; return "test diagnostic" }())
expect(!evaluatedDiagnostic, "disabled local diagnostics avoid message formatting and disk work")

let recoveredURL = root.appendingPathComponent("Recovered", isDirectory: true)
loaded.regularAppsUrls.append(recoveredURL)
regular.update(runningApplications: [])
expect(!regular.apps.contains(where: { $0.url == recoveredURL }), "unavailable pinned folders do not create invalid models")
try FileManager.default.createDirectory(at: recoveredURL, withIntermediateDirectories: true)
regular.invalidateCache()
regular.update(runningApplications: [])
expect(regular.apps.contains(where: { $0.url == recoveredURL }), "cache invalidation recovers folders after a volume becomes available")

indicatorApp.instanceNumber = 2
indicatorButton.iconSize = 40
let badgeBitmap = render(indicatorButton)
let badgePixel = badgeBitmap.colorAt(x: 23 * scale, y: 15 * scale)!.usingColorSpace(.deviceRGB)!
expect(badgePixel.redComponent > badgePixel.blueComponent && badgePixel.alphaComponent > 0.5,
       "instance badge remains visible at the bottom with oversized artwork")

// Exercise the real delegate without launching or showing any app window.
loaded.maxRunningApps = 10
let auditedDelegate = AppDelegate()
auditedDelegate.userPrefs = loaded
auditedDelegate.menuBarItems = dock
auditedDelegate.regularApps = regular
auditedDelegate.runningApps = RunningApps(userPrefsDataSource: loaded)
auditedDelegate.openableApps = OpenableApps(userPrefsDataSource: loaded,
                                           runningApps: auditedDelegate.runningApps, regularApps: regular)
let existingFolderModel = auditedDelegate.openableApps.apps.first(where: { $0.isFolder })!
var snapshotReads = 0
auditedDelegate.runningApplicationsProvider = { snapshotReads += 1; return [finderProcess] }
auditedDelegate.preferencesWindow.contentViewController = controller
auditedDelegate.groupSpacingSliderDidChange(36)
expect(controller.groupSpacingSlider.doubleValue == 36 && controller.groupSpacingCounterLabel.stringValue == "36 pt",
       "context-menu margin changes immediately synchronize the existing Preferences controls")
auditedDelegate.appIconSizeSliderDidChange(32)
auditedDelegate.itemSlotWidthSliderDidChange(38)
expect(snapshotReads == 0 && auditedDelegate.openableApps.apps.contains(where: { $0 === existingFolderModel }),
       "appearance sliders avoid process queries and app-model rebuilds")
auditedDelegate.appWasActivated(runningApp: finderProcess)
auditedDelegate.appWasLaunched(runningApp: finderProcess)
var eventsDrained = false
DispatchQueue.main.async { eventsDrained = true }
let eventDeadline = Date().addingTimeInterval(2)
while !eventsDrained && Date() < eventDeadline {
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
}
expect(eventsDrained && snapshotReads == 1, "a burst of app events shares one deferred process snapshot (reads: \(snapshotReads))")

auditedDelegate.userPrefs = writePrefs
countingDefaults.writes = 0
auditedDelegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
expect(countingDefaults.writes == 0, "an uninitialized duplicate delegate never overwrites preferences on exit")

struct OrderedItem: Reorderable {
    let orderElement: String
}
let orderedItems = ["y", "a", "x", "b"].map { OrderedItem(orderElement: $0) }
expect(orderedItems.reorder(by: ["a", "b"]).map(\.orderElement) == ["y", "x", "a", "b"],
       "optimized ordering preserves unknown-item order at the least-recent end")
expect(orderedItems.reorder(by: ["b", "a"], unorderedGoTo: .end).map(\.orderElement) == ["b", "a", "y", "x"],
       "optimized reverse ordering leaves newest apps at the front")
expect(orderedItems.reorder(by: ["a", "a", "b"]).map(\.orderElement) == ["y", "x", "a", "b"],
       "duplicate ordering keys cannot trap dictionary construction")

for size: CGFloat in [12, 18, 25.4, 40, 64, 100] {
    for requested: CGFloat in [30, 48, 64] {
        let width = DockItemLayout.slotWidth(requested: requested, iconSize: size)
        for height: CGFloat in [22, 30] {
            let bounds = NSRect(x: 0, y: 0, width: width, height: height)
            let geometry = DockItemLayout(bounds: bounds, iconSize: size)
            precondition(bounds.contains(geometry.indicatorRect))
            precondition(geometry.iconRect.minX > geometry.indicatorRect.maxX)
            precondition(geometry.iconRect.minX >= bounds.minX + 0.99)
            precondition(geometry.iconRect.maxX <= bounds.maxX - 0.99)
            precondition(abs(geometry.indicatorRect.midY - geometry.iconRect.midY) < 0.001)
        }
        for count in [0, 1, 3, 10, 100] {
            for budget: CGFloat in [120, 300, 800] {
                for spacing: CGFloat in [0, 48, 160] {
                    let layout = DockGroupLayout(count: count, slotWidth: width, spacing: spacing, budget: budget)
                    precondition(layout.totalWidth <= budget)
                    precondition(layout.visibleCount <= count)
                }
            }
        }
    }
}
expect(true, "36 icon/slot/height combinations keep the scaled left dot separate and within bounds")
expect(true, "810 group layouts with automatically widened slots remain within the menu budget")
expect(DockItemLayout.indicatorDiameter(iconSize: 40) > DockItemLayout.indicatorDiameter(iconSize: 18) &&
       DockItemLayout.indicatorGap(iconSize: 40) > DockItemLayout.indicatorGap(iconSize: 18),
       "indicator diameter and small gap scale with the icon size")
loaded.appIconSize = 40
loaded.itemSlotWidth = 30
dock.update(apps: [folderApp, finder])
expect(dock.items.allSatisfy { item in
    let geometry = item.button.artworkLayout
    return item.button.bounds.contains(geometry.indicatorRect) &&
        geometry.iconRect.minX > geometry.indicatorRect.maxX &&
        geometry.iconRect.maxX <= item.button.bounds.maxX
}, "real menu buttons automatically reserve space beside enlarged artwork")
let alignedRect = indicatorButton.artworkLayout.iconRect
indicatorApp.runningApplication = NSRunningApplication.current
expect(indicatorButton.artworkLayout.iconRect == alignedRect,
       "starting an application does not shift the icon to make room for its dot")

// Own invisible window: no popup, screen capture or foreground activation.
let hoverWindow = NSWindow(contentRect: NSRect(x: 100, y: 200, width: 160, height: 80),
                           styleMask: .borderless, backing: .buffered, defer: false)
let hoverButton = DockItemButton(frame: NSRect(x: 20, y: 10, width: 32, height: 30))
hoverButton.isBordered = false
hoverButton.app = artworkApp
hoverButton.iconSize = 26
hoverButton.reduceMotion = { false }
hoverButton.hoverDistance = { _ in 8.5 }
hoverWindow.contentView!.addSubview(hoverButton)
let originalFrame = hoverButton.frame
let fixedAnchor = DockMenuPresentation.anchor(from: hoverButton)!
let sourceRect = hoverWindow.convertToScreen(hoverButton.convert(hoverButton.bounds, to: nil))
expect(abs(fixedAnchor.y - (sourceRect.minY - 1)) < 0.001 && fixedAnchor.x == sourceRect.minX,
       "popup anchor is below the physical button in screen coordinates")

let sprite = NSImageView(frame: NSRect(origin: .zero, size: hoverButton.bounds.size))
sprite.imageScaling = .scaleNone
sprite.image = hoverButton.hoverSnapshot()
let sourceBitmap = render(hoverButton)
let spriteBitmap = render(sprite)
let pixelX = sourceBitmap.pixelsWide / 2
let pixelY = sourceBitmap.pixelsHigh / 4
expect(abs(sourceBitmap.colorAt(x: pixelX, y: pixelY)!.usingColorSpace(.deviceRGB)!.redComponent -
           spriteBitmap.colorAt(x: pixelX, y: pixelY)!.usingColorSpace(.deviceRGB)!.redComponent) < 0.05,
       "hover sprite preserves native icon orientation and Retina geometry")

hoverButton.updateTrackingAreas()
hoverButton.updateTrackingAreas()
let hoverAreas = hoverButton.trackingAreas.filter { $0.options.contains(.activeAlways) && $0.options.contains(.mouseEnteredAndExited) }
expect(hoverAreas.count == 1 && !hoverAreas[0].options.contains(.mouseMoved),
       "hover uses one enter/exit tracking area without continuous mouse-move events")
hoverButton.setHovered(true)
let overlay = DockHoverOverlay.shared
expect(overlay.owner === hoverButton && overlay.targetOffset == -8.5 && hoverButton.layer?.opacity == 0,
       "hover moves the visual sprite down while hiding its stationary copy")
expect(hoverButton.frame == originalFrame && DockMenuPresentation.anchor(from: hoverButton) == fixedAnchor,
       "animation changes neither click geometry nor the popup anchor")
expect(hoverButton.hitTest(NSPoint(x: originalFrame.midX, y: originalFrame.midY)) === hoverButton,
       "the original button remains clickable while its visual copy is animated")
expect(overlay.visualFrame!.contains(sourceRect) &&
       overlay.visualFrame!.contains(sourceRect.offsetBy(dx: 0, dy: -8.5)) && !overlay.isVisible,
       "overlay covers both animation endpoints without clipping or showing test windows (frame: \(overlay.visualFrame!), source: \(sourceRect), visible: \(overlay.isVisible))")
let oldAnimation = overlay.currentAnimation!
expect(oldAnimation.keyPath == "transform.translation.y" && oldAnimation.duration == 0.18,
       "hover runs a short Core Animation layer translation")
hoverButton.setMenuTracking(true)
expect(overlay.owner == nil && hoverButton.layer?.opacity == 1,
       "opening a context menu immediately restores stable original artwork")
hoverButton.setHovered(true)
expect(overlay.owner == nil, "menu tracking suppresses hover animation")
hoverButton.setMenuTracking(false)
hoverButton.reduceMotion = { true }
hoverButton.setHovered(true)
expect(overlay.owner == nil && hoverButton.layer?.opacity == 1,
       "Reduce Motion keeps the original icon stationary")
hoverButton.reduceMotion = { false }
hoverButton.setHovered(true)
overlay.animationDidStop(oldAnimation, finished: true)
expect(overlay.owner === hoverButton, "a cancelled old animation cannot dismiss a newer hover")
hoverButton.resetHover()
expect(overlay.owner == nil && hoverButton.layer?.opacity == 1,
       "hover cancellation restores the button and releases the sprite")

expect(abs(DockHoverMotion.distance(screenHeight: 1000, physicalHeight: 200) - 7.5) < 0.001 &&
       abs(DockHoverMotion.distance(screenHeight: 800, physicalHeight: 200) - 6) < 0.001,
       "1.5 mm movement accounts for display size and logical scaling")
expect(DockHoverMotion.distance(screenHeight: 1000, physicalHeight: 0).isFinite &&
       abs(DockHoverMotion.distance(screenHeight: 1000, physicalHeight: 0) - 1.5 * 72 / 25.4) < 0.001,
       "missing display metadata has a safe approximate 1.5 mm fallback")

let beforeMenuItems = dock.items
let beforeMenuWidth = dock.statusItem.length
dock.menuWillOpen()
dock.update(apps: [folderApp])
expect(dock.items.count == beforeMenuItems.count && dock.statusItem.length == beforeMenuWidth &&
       zip(dock.items, beforeMenuItems).allSatisfy { $0 === $1 },
       "app updates cannot move buttons or resize the group during menu tracking")
dock.menuWillOpen()
dock.update(apps: [])
dock.menuDidClose()
expect(dock.items.count == beforeMenuItems.count, "nested menu tracking preserves the frozen group")
dock.menuDidClose()
expect(dock.items.count == 1 && dock.items[0].app == nil,
       "closing the last menu applies the most recent deferred content")

weak var retiredHoverButton: DockItemButton?
autoreleasepool {
    let retiring = DockItemButton(frame: NSRect(x: 0, y: 0, width: 32, height: 30))
    retiring.app = artworkApp
    retiring.iconSize = 26
    retiring.reduceMotion = { false }
    retiring.hoverDistance = { _ in 8.5 }
    hoverWindow.contentView!.addSubview(retiring)
    retiredHoverButton = retiring
    retiring.setHovered(true, animated: false)
    retiring.removeFromSuperview()
}
expect(retiredHoverButton == nil && overlay.owner == nil,
       "removing a hovered button releases both its tracking state and overlay ownership")

final class MouseUpReceiver: NSResponder {
    var releases = 0
    override func rightMouseUp(with event: NSEvent) { releases += 1 }
}
let receiver = MouseUpReceiver()
hoverButton.nextResponder = receiver
var rightMenuRequests = 0
hoverButton.onRightClick = { rightMenuRequests += 1 }
let rightDown = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [],
                                   timestamp: 0, windowNumber: hoverWindow.windowNumber, context: nil,
                                   eventNumber: 0, clickCount: 1, pressure: 1)!
let rightUp = NSEvent.mouseEvent(with: .rightMouseUp, location: .zero, modifierFlags: [],
                                 timestamp: 0, windowNumber: hoverWindow.windowNumber, context: nil,
                                 eventNumber: 1, clickCount: 1, pressure: 0)!
hoverButton.setHovered(true, animated: false)
hoverButton.rightMouseDown(with: rightDown)
hoverButton.rightMouseUp(with: rightUp)
expect(rightMenuRequests == 1 && receiver.releases == 0 && overlay.owner == nil,
       "a right-click opens one menu, cancels hover and cannot bubble to a second group menu")

final class FixedTestWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
let screenFrame = NSScreen.main!.frame
let bandWindow = FixedTestWindow(contentRect: NSRect(x: screenFrame.midX, y: screenFrame.maxY - 30,
                                                     width: 60, height: 30),
                                  styleMask: .borderless, backing: .buffered, defer: false)
let bandButton = DockItemButton(frame: NSRect(x: 0, y: 0, width: 32, height: 30))
bandButton.app = artworkApp
bandButton.iconSize = 26
bandButton.reduceMotion = { false }
bandButton.hoverDistance = { _ in 8.5 }
bandWindow.contentView!.addSubview(bandButton)
bandButton.setHovered(true, animated: false)
let bandSource = bandWindow.convertToScreen(bandButton.convert(bandButton.bounds, to: nil))
expect(overlay.visualFrame!.contains(bandSource) &&
       overlay.visualFrame!.contains(bandSource.offsetBy(dx: 0, dy: -8.5)) && !overlay.isVisible,
       "overlay stays aligned even when the source occupies the actual menu-bar screen band")
bandButton.resetHover()
// Regression: artwork taller than its button must survive the first hover
// frame at full size. Inspect only bitmaps rendered from our own test icon.
for size: CGFloat in [12, 25.4, 40, 64, 100] {
    for height: CGFloat in [22, 30] {
        let width = DockItemLayout.slotWidth(requested: 30, iconSize: size)
        let button = DockItemButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
        button.app = artworkApp
        button.iconSize = size
        button.reduceMotion = { false }
        button.hoverDistance = { _ in 4.25 }
        hoverWindow.contentView!.addSubview(button)
        let rect = button.hoverArtworkBounds
        let icon = button.artworkLayout.iconRect
        let image = button.hoverSnapshot()!
        let bitmap = image.representations.first as! NSBitmapImageRep
        let sx = CGFloat(bitmap.pixelsWide) / rect.width
        let sy = CGFloat(bitmap.pixelsHigh) / rect.height
        let x = Int((icon.midX - rect.minX) * sx)
        let topInset = button.isFlipped ? icon.minY - rect.minY : rect.maxY - icon.maxY
        let bottomInset = button.isFlipped ? rect.maxY - icon.maxY : icon.minY - rect.minY
        let top = bitmap.colorAt(x: x, y: Int((topInset + 1) * sy))!.usingColorSpace(.deviceRGB)!
        let bottom = bitmap.colorAt(x: x, y: bitmap.pixelsHigh - 1 - Int((bottomInset + 1) * sy))!.usingColorSpace(.deviceRGB)!
        expect(rect.contains(icon) && image.size == rect.size &&
               top.redComponent > 0.9 && top.alphaComponent > 0.9 &&
               bottom.blueComponent > 0.9 && bottom.alphaComponent > 0.9,
               "full hover artwork keeps top/bottom pixels and scale at icon \(size), button height \(height)")
        let frame = button.frame
        let anchor = DockMenuPresentation.anchor(from: button)
        button.setHovered(true)
        let fullSource = hoverWindow.convertToScreen(button.convert(rect, to: nil))
        expect(overlay.visualFrame!.contains(fullSource) &&
               overlay.visualFrame!.contains(fullSource.offsetBy(dx: 0, dy: -4.25)) &&
               button.frame == frame && DockMenuPresentation.anchor(from: button) == anchor && !overlay.isVisible,
               "expanded overlay contains full artwork at both endpoints for icon \(size), height \(height)")
        button.resetHover()
        button.removeFromSuperview()
    }
}

// Appearance preferences persist independently and default to the existing look.
let appearanceSuite = "local.menubardock.appearance-tests.\(UUID().uuidString)"
let appearanceDefaults = UserDefaults(suiteName: appearanceSuite)!
defer { appearanceDefaults.removePersistentDomain(forName: appearanceSuite) }
let appearancePrefs = UserPrefs(defaults: appearanceDefaults)
appearancePrefs.load()
expect(appearancePrefs.hoverAnimationsEnabled && appearancePrefs.groupBackgroundEnabled,
       "existing installations keep hover and background enabled when new keys are absent")
appearancePrefs.regularAppsUrls = [folder]
appearancePrefs.hoverAnimationsEnabled = false
appearancePrefs.groupBackgroundEnabled = true
appearancePrefs.save()
let appearanceReload = UserPrefs(defaults: appearanceDefaults)
appearanceReload.load()
expect(!appearanceReload.hoverAnimationsEnabled && appearanceReload.groupBackgroundEnabled,
       "hover can be disabled independently and survives reload")
appearanceReload.groupBackgroundEnabled = false
appearanceReload.save()
appearancePrefs.load()
expect(!appearancePrefs.hoverAnimationsEnabled && !appearancePrefs.groupBackgroundEnabled,
       "both appearance toggles can be disabled and survive reload")
appearancePrefs.resetToDefaults()
expect(appearancePrefs.hoverAnimationsEnabled && appearancePrefs.groupBackgroundEnabled &&
       appearancePrefs.regularAppsUrls == [folder],
       "reset restores appearance defaults without removing pinned folders")

controller.delegate = sliderDelegate
controller.view.layoutSubtreeIfNeeded()
expect(controller.hoverAnimationsButton.state == .on && controller.groupBackgroundButton.state == .on,
       "Preferences reflects enabled hover and group background")
let addedControls: [NSView] = [controller.hoverAnimationsButton, controller.groupBackgroundButton,
                               controller.restartAppButton]
let controlGeometry = addedControls.map {
    "\($0.frame) fit=\($0.fittingSize) ambiguous=\($0.hasAmbiguousLayout) root=\($0.convert($0.bounds, to: controller.view))"
}
expect(addedControls.allSatisfy { control in
    controller.view.bounds.contains(control.convert(control.bounds, to: controller.view)) &&
        !control.hasAmbiguousLayout && control.frame.width >= control.fittingSize.width
}, "new settings and action buttons fit in the expanded Preferences window (root: \(controller.view.bounds), controls: \(controlGeometry))")
let toggleRect = controller.hoverAnimationsButton.convert(controller.hoverAnimationsButton.bounds, to: controller.view)
let actionRect = controller.restartAppButton.convert(controller.restartAppButton.bounds, to: controller.view)
expect(!toggleRect.intersects(actionRect), "appearance toggles and action buttons do not overlap")
controller.hoverAnimationsButton.performClick(nil)
controller.groupBackgroundButton.performClick(nil)
controller.restartAppButton.performClick(nil)
expect(sliderDelegate.animations == false && sliderDelegate.background == false &&
       sliderDelegate.restarts == 1,
       "native buttons forward both toggles and the restart action once")

// Exercise live appearance updates without reading processes or showing windows.
auditedDelegate.userPrefs = loaded
loaded.hoverAnimationsEnabled = true
loaded.groupBackgroundEnabled = true
dock.update(apps: [folderApp, finder])
let appearanceItems = dock.items
let appearanceStatusItem = dock.statusItem
let hovering = dock.items[0].button
hovering.reduceMotion = { false }
hovering.setHovered(true, animated: false)
expect(overlay.owner === hovering, "live icon starts hover before its animation is disabled")
let readsBeforeAppearance = snapshotReads
auditedDelegate.hoverAnimationsDidChange(false)
expect(overlay.owner == nil && hovering.layer?.opacity == 1 &&
       dock.items.allSatisfy { !$0.button.hoverAnimationsEnabled },
       "disabling hover immediately cancels the active sprite and restores stationary icons")
hovering.setHovered(true)
expect(overlay.owner == nil, "disabled hover cannot create a visual overlay")
auditedDelegate.groupBackgroundDidChange(false)
expect(!dock.isGroupBackgroundVisible && dock.statusItem === appearanceStatusItem &&
       zip(appearanceItems, dock.items).allSatisfy { $0 === $1 } && snapshotReads == readsBeforeAppearance,
       "hiding the background keeps the group, buttons and models without querying processes")
auditedDelegate.hoverAnimationsDidChange(true)
auditedDelegate.groupBackgroundDidChange(true)
hovering.setHovered(true, animated: false)
expect(dock.isGroupBackgroundVisible && overlay.owner === hovering,
       "both appearance options can be enabled again without restart")
hovering.resetHover()
controller.updateUi()
expect(controller.hoverAnimationsButton.state == .on && controller.groupBackgroundButton.state == .on,
       "reopening Preferences synchronizes both checkbox states")

// Relaunch control: fake execution/termination, then a real helper using only
// our disposable sleep process and fake opener; no application is restarted.
let restartDelegate = AppDelegate()
restartDelegate.userPrefs = appearancePrefs
let unusualAppURL = root.appendingPathComponent("App with spaces $(literal) ' \".app")
restartDelegate.applicationBundleURL = { unusualAppURL }
var helperRequests = 0
var terminations = 0
restartDelegate.runRelaunchHelper = { process in
    helperRequests += 1
    expect(appearanceDefaults.object(forKey: Constants.UserPrefs.groupBackgroundEnabled) as? Bool == false &&
           process.arguments?.suffix(2).first == unusualAppURL.path,
           "restart saves current settings and passes the exact application path as an argument")
}
restartDelegate.terminateApplication = { terminations += 1 }
appearancePrefs.groupBackgroundEnabled = false
restartDelegate.restartAppWasPressed()
restartDelegate.restartAppWasPressed()
expect(helperRequests == 1 && terminations == 1,
       "repeated restart clicks schedule only one helper and one termination")
let failingRestart = AppDelegate()
failingRestart.userPrefs = appearancePrefs
failingRestart.runRelaunchHelper = { _ in throw CocoaError(.executableNotLoadable) }
var restartErrors = 0
failingRestart.presentRestartError = { _ in restartErrors += 1 }
failingRestart.terminateApplication = { terminations += 1 }
failingRestart.restartAppWasPressed()
failingRestart.restartAppWasPressed()
expect(restartErrors == 2 && terminations == 1,
       "a helper launch failure leaves the app alive, reports the error and permits retry")

let fakeOpener = root.appendingPathComponent("fake opener")
try "#!/bin/sh\n/usr/bin/printf '%s\\n' \"$@\" > \"$0.result\"\n".write(to: fakeOpener, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeOpener.path)
let sleeper = Process()
sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
sleeper.arguments = ["0.3"]
try sleeper.run()
let helper = AppRelaunch.helper(appURL: unusualAppURL, processID: sleeper.processIdentifier, openerURL: fakeOpener)
try helper.run()
helper.waitUntilExit()
let waitedForOldProcess = !sleeper.isRunning
sleeper.waitUntilExit()
let openedArguments = try String(contentsOfFile: fakeOpener.path + ".result", encoding: .utf8)
expect(helper.terminationStatus == 0 && waitedForOldProcess &&
       openedArguments == "-n\n" + unusualAppURL.path + "\n",
       "real relaunch helper waits for the old PID and preserves spaces, quotes and shell metacharacters")
print("\(checks) checks passed")
