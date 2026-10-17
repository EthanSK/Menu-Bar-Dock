import Cocoa

protocol RegularAppsUserPrefsDataSource: AnyObject {
    var regularAppsUrls: [URL] { get }
}

final class RegularApps {
    private(set) var apps: [RegularApp] = []
    weak var userPrefsDataSource: RegularAppsUserPrefsDataSource!
    private var loadedURLs: [URL]?

    init(userPrefsDataSource: RegularAppsUserPrefsDataSource) {
        self.userPrefsDataSource = userPrefsDataSource
        update()
    }

    func invalidateCache() {
        loadedURLs = nil
        apps = []
    }

    func update(runningApplications: [NSRunningApplication]? = nil) {
        let urls = userPrefsDataSource.regularAppsUrls
        if loadedURLs != urls {
            // Cache only the current pinned list. Ordinary app switches must
            // not reread folder metadata or reload their artwork from disk.
            var existing: [URL: RegularApp] = [:]
            for app in apps { existing[app.url] = app }
            apps = urls.compactMap { existing[$0] ?? regularApp(for: $0) }
            loadedURLs = urls
        }
        let running = (runningApplications ?? NSWorkspace.shared.runningApplications).filter { !$0.isTerminated }
        let byURL = Dictionary(grouping: running, by: { $0.bundleURL?.absoluteString ?? "" })
        for app in apps where !app.isFolder {
            let candidates = byURL[app.id] ?? []
            // Keep the activated instance while it is alive. Rebinding every
            // refresh to the first instance would undo per-instance activation.
            if !candidates.contains(where: { $0.processIdentifier == app.runningApp?.processIdentifier }) {
                app.runningApp = candidates.first
            }
        }
    }

    func handleAppActivation(runningApp: NSRunningApplication) {
        correspondingRegularApp(for: runningApp)?.runningApp = runningApp
    }

    func handleAppQuit(runningApp: NSRunningApplication) {
        guard let app = correspondingRegularApp(for: runningApp),
              app.runningApp?.processIdentifier == runningApp.processIdentifier else { return }
        app.runningApp = nil // The next shared snapshot binds a remaining instance.
    }

    private func correspondingRegularApp(for runningApp: NSRunningApplication) -> RegularApp? {
        apps.first { !$0.isFolder && $0.id == runningApp.bundleURL?.absoluteString }
    }

    private func regularApp(for url: URL) -> RegularApp? {
        if RegularApp.isPinnableFolder(url) { return RegularApp(folderURL: url) }
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url) else { return nil }
        return RegularApp(bundle: bundle, icon: NSWorkspace.shared.icon(forFile: url.path), name: bundle.name)
    }
}
