import Cocoa

protocol RunningAppsUserPrefsDataSource: AnyObject {
    var hideFinderFromRunningApps: Bool { get }
    var hideActiveAppFromRunningApps: Bool { get }
    var maxRunningApps: Int { get }
    var regularAppsUrls: [URL] { get }
    var runningAppsSortingMethod: RunningAppsSortingMethod { get }
}

final class RunningApps {
    private(set) var apps: [RunningApp] = []
    private var ordering: [String] = [] // Process identities, least to most recent.
    private var lastActivatedApp: NSRunningApplication?
    weak var userPrefsDataSource: RunningAppsUserPrefsDataSource!
    private let runningApplications: () -> [NSRunningApplication]

    var limit: Int { min(100, max(0, userPrefsDataSource.maxRunningApps)) }

    init(userPrefsDataSource: RunningAppsUserPrefsDataSource,
         runningApplications: @escaping () -> [NSRunningApplication] = { NSWorkspace.shared.runningApplications }) {
        self.userPrefsDataSource = userPrefsDataSource
        self.runningApplications = runningApplications
        update()
        ordering = apps.map(\.orderElement)
    }

    func handleAppActivation(runningApp: NSRunningApplication) {
        lastActivatedApp = runningApp // Trust the notification payload, including accessory apps.
        guard runningApp.activationPolicy == .regular else { return }
        let key = RunningApp(app: runningApp).orderElement
        ordering.removeAll { $0 == key }
        ordering.append(key)
    }

    func handleAppLaunch(runningApp: NSRunningApplication) {
        guard runningApp.activationPolicy == .regular else { return }
        let key = RunningApp(app: runningApp).orderElement
        if !ordering.contains(key) { ordering.append(key) }
    }

    func handleAppQuit(runningApp: NSRunningApplication) {
        let key = RunningApp(app: runningApp).orderElement
        ordering.removeAll { $0 == key } // A sibling instance keeps its own recency.
        if lastActivatedApp?.processIdentifier == runningApp.processIdentifier { lastActivatedApp = nil }
    }

    func update(runningApplications snapshot: [NSRunningApplication]? = nil) {
        guard limit > 0 else { apps = []; return } // Empty dock has its own preferences button.
        let running = (snapshot ?? runningApplications()).filter { !$0.isTerminated }
        let liveKeys = Set(running.map { RunningApp(app: $0).orderElement })
        ordering.removeAll { !liveKeys.contains($0) }
        let active = lastActivatedApp ?? NSWorkspace.shared.frontmostApplication
        let candidates = running.filter {
            $0.activationPolicy == .regular &&
            !(userPrefsDataSource.hideFinderFromRunningApps && $0.bundleIdentifier == Constants.App.finderBundleId) &&
            !(userPrefsDataSource.hideActiveAppFromRunningApps && $0.processIdentifier == active?.processIdentifier)
        }.map { RunningApp(app: $0) }
        switch userPrefsDataSource.runningAppsSortingMethod {
        case .mostRecentOnRight:
            apps = Array(candidates.reorder(by: ordering, unorderedGoTo: .start).suffix(limit))
        case .mostRecentOnLeft:
            apps = Array(candidates.reorder(by: ordering.reversed(), unorderedGoTo: .end).prefix(limit))
        case .consistent:
            let alphabetical = candidates.sorted {
                let comparison = ($0.app.localizedName ?? $0.id).localizedStandardCompare($1.app.localizedName ?? $1.id)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return $0.orderElement < $1.orderElement
            }
            apps = Array(alphabetical.prefix(limit))
        }
    }
}

enum RunningAppsSortingMethod: Int {
    case mostRecentOnRight = 0
    case mostRecentOnLeft = 1
    case consistent = 2
}

enum SideToShowRunningApps: String {
    case left = "left"
    case right = "right"
}
