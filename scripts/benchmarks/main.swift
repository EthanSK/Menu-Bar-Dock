import Cocoa

_ = NSApplication.shared
let suite = "local.menubardock.benchmark.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let prefs = UserPrefs(defaults: defaults)
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
for index in 0..<12 {
    let folder = root.appendingPathComponent("Folder-\(index)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    prefs.regularAppsUrls.append(folder)
}
let regular = RegularApps(userPrefsDataSource: prefs)
let openable = regular.apps.map { OpenableApp(regularApp: $0, appOpeningMethod: .launch) }
let dock = MenuBarItems(userPrefsDataSource: prefs)
dock.update(apps: openable)
let overrideBitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: overrideBitmap)
openable[0].icon.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256))
NSGraphicsContext.restoreGraphicsState()
prefs.appIconOverrides[openable[0].bundleUrl.absoluteString] = overrideBitmap.representation(using: .png, properties: [:])!

func measure(_ name: String, iterations: Int, action: () -> Void) {
    for _ in 0..<5 { action() }
    var times: [Double] = []
    for _ in 0..<3 {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { autoreleasepool { action() } }
        times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }
    print("\(name),\(iterations),\(String(format: "%.3f", times.sorted()[1]))")
}
print("scenario,iterations,median_total_ms")
measure("pinned_refresh_12_folders", iterations: 300) { regular.update() }
measure("dock_refresh_12_items", iterations: 1000) { dock.update(apps: openable) }
measure("override_lookup", iterations: 1000) { _ = prefs.iconOverride(forAppAt: openable[0].bundleUrl) }
