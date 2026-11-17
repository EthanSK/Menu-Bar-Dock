//
//  MenuBarDockTests.swift
//  MenuBarDockTests
//
//  Created by Ethan Sarif-Kattan on 02/03/2019.
//  Copyright © 2019 Ethan Sarif-Kattan. All rights reserved.
//

import XCTest
@testable import Menu_Bar_Dock

class MenuBarDockTests: XCTestCase {

    func testSizing_usesTheSharedSizeForDifferentAppsWithoutResizingTheirSourceImages() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: 30)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let dataSource = MenuBarItemDataSourceStub()
        let item = MenuBarItem(statusItem: statusItem, userPrefsDataSource: dataSource)
        let firstApp = numberedApp(2, process: RecordingRunningApplication(), method: nil)
        let secondApp = numberedApp(3, process: RecordingRunningApplication(), method: nil)
        firstApp.bundleUrl = URL(fileURLWithPath: "/Applications/First.app")
        secondApp.bundleUrl = URL(fileURLWithPath: "/Applications/Second.app")
        firstApp.icon = NSImage(size: NSSize(width: 16, height: 16))
        secondApp.icon = NSImage(size: NSSize(width: 128, height: 128))

        for app in [firstApp, secondApp] {
            let sourceSize = app.icon.size
            item.update(for: app, appIconSize: 40, slotWidth: 30)
            let imageView = try XCTUnwrap(statusItem.button!.subviews.first as? NSImageView)
            XCTAssertEqual(imageView.frame.size, NSSize(width: 40, height: 40))
            XCTAssertEqual(imageView.frame.minY, -9)
            XCTAssertEqual(app.icon.size, sourceSize)
        }
    }

    func testSizing_appliesSmallerGlobalSizesWithoutFittingToTheSlot() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 18)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let dataSource = MenuBarItemDataSourceStub()
        let item = MenuBarItem(statusItem: statusItem, userPrefsDataSource: dataSource)
        let app = numberedApp(2, process: RecordingRunningApplication(), method: nil)
        item.update(for: app, appIconSize: 40, slotWidth: 18)
        XCTAssertEqual(statusItem.button!.subviews.first!.frame.size, NSSize(width: 40, height: 40))
        item.update(for: app, appIconSize: 16, slotWidth: 30)
        XCTAssertEqual(statusItem.button!.subviews.first!.frame.size, NSSize(width: 16, height: 16))
    }

    func testSizing_normalizesRecordedCrashWidthAndSliderValues() {
        let preferences = UserPrefs()
        // This exact width was captured immediately before the November 7 crash.
        preferences.itemSlotWidth = 30.3840206185567
        preferences.appIconSize = 40.37
        XCTAssertEqual(preferences.itemSlotWidth, 30)
        XCTAssertEqual(preferences.appIconSize, 40)

        preferences.itemSlotWidth = 30.8
        preferences.appIconSize = 39.8
        XCTAssertEqual(preferences.itemSlotWidth, 31)
        XCTAssertEqual(preferences.appIconSize, 40)
        preferences.itemSlotWidth = 30
        preferences.appIconSize = 40
        XCTAssertEqual(preferences.itemSlotWidth, 30)
        XCTAssertEqual(preferences.appIconSize, 40)
    }

    func testSizing_alignsOddSizedArtworkAndBadgeWithoutGrowingImage() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 31)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let dataSource = MenuBarItemDataSourceStub()
        let menuBarItem = MenuBarItem(statusItem: statusItem, userPrefsDataSource: dataSource)
        let app = numberedApp(12, process: RecordingRunningApplication(), method: nil)
        menuBarItem.update(for: app, appIconSize: 39, slotWidth: 31)

        let imageView = statusItem.button?.subviews.first as? NSImageView
        XCTAssertEqual(statusItem.length, 31)
        XCTAssertEqual(imageView?.frame.size, NSSize(width: 39, height: 39))
        XCTAssertEqual(imageView?.frame.origin.y, -9)
        let badgeView = imageView?.subviews.first
        XCTAssertNotNil(badgeView)
        for frame in [imageView?.frame, badgeView?.frame].compactMap({ $0 }) {
            for value in [frame.origin.x, frame.origin.y, frame.width, frame.height] {
                XCTAssertEqual(value, value.rounded())
            }
        }
        XCTAssertEqual(menuBarItem.app?.instanceNumber, 12)
    }

    // Recreate the real quit-notification snapshot: the exited process remains
    // in the array with isTerminated=true beside a surviving live process.
    private final class SnapshotRunningApplication: NSRunningApplication, @unchecked Sendable {
        var testPID: pid_t = 101
        var testTerminated = false
        var policy: NSApplication.ActivationPolicy = .regular
        var launched = Date(timeIntervalSince1970: 100)
        var testBundleURL = Bundle.main.bundleURL

        override var processIdentifier: pid_t { testPID }
        override var isTerminated: Bool { testTerminated }
        override var activationPolicy: NSApplication.ActivationPolicy { policy }
        override var launchDate: Date? { launched }
        override var bundleURL: URL? { testBundleURL }
        override var bundleIdentifier: String? { Bundle.main.bundleIdentifier ?? "com.ethansk.InstanceSnapshotTest" }
        override var localizedName: String? { "Instance Snapshot Test" }
        override var icon: NSImage? { NSImage(size: NSSize(width: 16, height: 16)) }
        override var hash: Int { Int(testPID) }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? NSRunningApplication else { return false }
            return testPID == other.processIdentifier // Test instances have no native process identity; preserve the real app's process-based equality for Hide active app.
        }
    }

    private final class SnapshotPreferences: RunningAppsUserPrefsDataSource, RegularAppsUserPrefsDataSource, OpenableAppsUserPrefsDataSource {
        var hideFinderFromRunningApps = false
        var hideActiveAppFromRunningApps = false
        var maxRunningApps = 10
        var regularAppsUrls: [URL] = []
        var runningAppsSortingMethod: RunningAppsSortingMethod = .mostRecentOnRight
        var appOpeningMethods: [String: AppOpeningMethod] = [:]
        var defaultAppOpeningMethod: AppOpeningMethod = .launch
        var sideToShowRunningApps: SideToShowRunningApps = .right
        var hideDuplicateApps = true
        var duplicateAppsPriority: DuplicateAppsPriority = .regularApps

        func iconOverride(forAppAt url: URL) -> NSImage? { nil }
    }

    func testInstanceBadge_ignoresTerminatedProcessInQuitSnapshot() {
        let preferences = SnapshotPreferences()
        preferences.regularAppsUrls = [Bundle.main.bundleURL]
        let running = RunningApps(userPrefsDataSource: preferences)
        let pinned = RegularApps(userPrefsDataSource: preferences)
        let combined = OpenableApps(userPrefsDataSource: preferences, runningApps: running, regularApps: pinned)
        let live = SnapshotRunningApplication()
        let exited = SnapshotRunningApplication()
        exited.testPID = 102
        exited.testTerminated = true

        // The exited entry comes first to cover pinned rebinding as well as
        // the badge count. All consumers receive the same captured state.
        let snapshot = [exited, live]
        running.update(runningApplications: snapshot)
        pinned.update(runningApplications: snapshot)
        combined.update(runningApps: running, regularApps: pinned, runningApplications: snapshot)

        XCTAssertEqual(pinned.apps.first?.runningApp?.processIdentifier, live.testPID)
        XCTAssertEqual(combined.apps.count, 1)
        XCTAssertNil(combined.apps.first?.instanceNumber)
        XCTAssertFalse(running.apps.contains { $0.app.isTerminated })
    }

    func testInstanceBadge_preservesLiveLaunchOrderForBothDuplicatePriorities() {
        let preferences = SnapshotPreferences()
        preferences.regularAppsUrls = [Bundle.main.bundleURL]
        let running = RunningApps(userPrefsDataSource: preferences)
        let pinned = RegularApps(userPrefsDataSource: preferences)
        let combined = OpenableApps(userPrefsDataSource: preferences, runningApps: running, regularApps: pinned)
        let oldest = SnapshotRunningApplication()
        oldest.testPID = 500 // A lower PID can belong to the newer instance after PID wraparound.
        let newest = SnapshotRunningApplication()
        newest.testPID = 100
        newest.launched = Date(timeIntervalSince1970: 200)
        let exited = SnapshotRunningApplication()
        exited.testPID = 50
        exited.testTerminated = true
        exited.launched = Date(timeIntervalSince1970: 50)
        let snapshot = [exited, newest, oldest]

        for priority in [DuplicateAppsPriority.regularApps, .runningApps] {
            preferences.duplicateAppsPriority = priority
            running.update(runningApplications: snapshot)
            pinned.update(runningApplications: snapshot)
            combined.update(runningApps: running, regularApps: pinned, runningApplications: snapshot)

            XCTAssertEqual(combined.apps.count, 2)
            XCTAssertEqual(combined.apps.first { $0.runningApplication?.processIdentifier == oldest.testPID }?.instanceNumber, 1)
            XCTAssertEqual(combined.apps.first { $0.runningApplication?.processIdentifier == newest.testPID }?.instanceNumber, 2)
        }
    }

    func testRunningApps_terminatedProcessCannotConsumeLimitedSlot() {
        let preferences = SnapshotPreferences()
        preferences.maxRunningApps = 1
        let running = RunningApps(userPrefsDataSource: preferences)
        let live = SnapshotRunningApplication()
        let exited = SnapshotRunningApplication()
        exited.testPID = 102
        exited.testTerminated = true

        running.update(runningApplications: [live, exited])

        XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, [live.testPID])
    }

    func testRunningApps_quittingAnotherProcessPreservesTheSurvivingAppsRecency() {
        for direction in [RunningAppsSortingMethod.mostRecentOnRight, .mostRecentOnLeft] {
            for hideActive in [false, true] {
                let preferences = SnapshotPreferences()
                preferences.runningAppsSortingMethod = direction
                preferences.hideActiveAppFromRunningApps = hideActive
                preferences.maxRunningApps = 2
                let running = RunningApps(userPrefsDataSource: preferences)
                let applications = (0..<4).map { index in
                    let application = SnapshotRunningApplication()
                    application.testPID = pid_t(200 + index)
                    application.testBundleURL = Bundle.main.bundleURL.appendingPathComponent("App\(index).app")
                    return application
                }
                for application in applications { running.handleAppActivation(runningApp: application) }
                running.update(runningApplications: applications)
                let expectedRight = hideActive ? [applications[1].testPID, applications[2].testPID] : [applications[2].testPID, applications[3].testPID]
                let expected = direction == .mostRecentOnRight ? expectedRight : Array(expectedRight.reversed())
                XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, expected)

                let exited = SnapshotRunningApplication()
                exited.testPID = 300
                exited.testTerminated = true
                exited.testBundleURL = applications[2].testBundleURL
                running.handleAppQuit(runningApp: exited, runningApplications: [exited] + applications)

                XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, expected, "direction=\(direction), hideActive=\(hideActive)")
            }
        }
    }

    func testRunningApps_quittingTheFinalProcessClearsItsRecency() {
        let preferences = SnapshotPreferences()
        let running = RunningApps(userPrefsDataSource: preferences)
        let first = SnapshotRunningApplication()
        let second = SnapshotRunningApplication()
        second.testPID = 102
        second.testBundleURL = Bundle.main.bundleURL.appendingPathComponent("Second.app")
        running.handleAppActivation(runningApp: second)
        running.handleAppActivation(runningApp: first)

        let alreadyExited = SnapshotRunningApplication()
        alreadyExited.testPID = 104
        alreadyExited.testTerminated = true
        running.handleAppQuit(runningApp: first, runningApplications: [first, alreadyExited, second]) // The exiting process may still be in the snapshot without isTerminated being set; a previously exited sibling must not retain recency either.
        let restarted = SnapshotRunningApplication()
        restarted.testPID = 103
        running.update(runningApplications: [second, restarted])

        XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, [restarted.testPID, second.testPID])
    }

    func testPinnedApps_keepLiveAccessoryAppsButRejectTerminatedMatches() {
        let preferences = SnapshotPreferences()
        preferences.regularAppsUrls = [Bundle.main.bundleURL]
        let pinned = RegularApps(userPrefsDataSource: preferences)
        let live = SnapshotRunningApplication()
        live.policy = .accessory // Pinned menu-bar apps remain supported.
        let exited = SnapshotRunningApplication()
        exited.testPID = 102
        exited.testTerminated = true

        pinned.update(runningApplications: [exited, live])

        XCTAssertEqual(pinned.apps.first?.runningApp?.processIdentifier, live.testPID)
    }

    private func diagnosticDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MenuBarDockDiagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func diagnosticState(_ filename: String, in directory: URL) throws -> DebugLog.DiagnosticSession {
        try JSONDecoder().decode(DebugLog.DiagnosticSession.self, from: Data(contentsOf: directory.appendingPathComponent(filename)))
    }

    func testDiagnostics_preserveUnfinishedSessionAcrossRelaunch() throws {
        let directory = try diagnosticDirectory()
        let previous = DebugLog(logDirectory: directory, enabled: true)
        previous.diagnostic("update=7 begin reason=application-activated", checkpoint: true)
        previous.flush()
        let before = try diagnosticState("layout-state.json", in: directory)

        // Do not call finishSession: model abrupt termination without crashing
        // the test host or adding a signal handler to the live app.
        let next = DebugLog(logDirectory: directory, enabled: true)
        next.flush()
        let recovered = try diagnosticState("previous-session.json", in: directory)
        let current = try diagnosticState("layout-state.json", in: directory)
        XCTAssertEqual(recovered.sessionID, before.sessionID)
        XCTAssertFalse(recovered.cleanShutdown)
        XCTAssertTrue(recovered.breadcrumbs.last?.contains("update=7 begin") == true)
        XCTAssertNotEqual(current.sessionID, recovered.sessionID)
        XCTAssertTrue(try String(contentsOf: directory.appendingPathComponent("debug.log")).contains("previous-exit=unclean"))
    }

    func testDiagnostics_cleanQuitDoesNotReportAnAbnormalExit() throws {
        let directory = try diagnosticDirectory()
        let previous = DebugLog(logDirectory: directory, enabled: true)
        previous.diagnostic("update completed", checkpoint: true)
        previous.finishSession()
        XCTAssertTrue(try diagnosticState("layout-state.json", in: directory).cleanShutdown)

        let next = DebugLog(logDirectory: directory, enabled: true)
        next.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("previous-session.json").path))
        XCTAssertFalse(try String(contentsOf: directory.appendingPathComponent("debug.log")).contains("previous-exit=unclean"))
    }

    func testDiagnostics_boundRecoveryContextAndRespectDisabledLogging() throws {
        let directory = try diagnosticDirectory()
        let logger = DebugLog(logDirectory: directory, enabled: true)
        for index in 0..<80 {
            logger.diagnostic("event=\(index) " + String(repeating: "x", count: 800) + "\nsecond line", checkpoint: true)
        }
        logger.flush()
        let state = try diagnosticState("layout-state.json", in: directory)
        XCTAssertEqual(state.breadcrumbs.count, 32)
        XCTAssertTrue(state.breadcrumbs.allSatisfy { !$0.contains("\n") && $0.count < 600 })
        XCTAssertLessThan(try Data(contentsOf: directory.appendingPathComponent("layout-state.json")).count, 32 * 1024)

        let disabledDirectory = directory.appendingPathComponent("disabled")
        let disabled = DebugLog(logDirectory: disabledDirectory, enabled: false)
        disabled.diagnostic("must not persist", checkpoint: true)
        disabled.log("must not persist")
        disabled.finishSession()
        disabled.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: disabledDirectory.path))
    }

    func testDiagnostics_concurrentLoggingKeepsCompleteTimestampedLines() throws {
        let directory = try diagnosticDirectory()
        let logger = DebugLog(logDirectory: directory, enabled: true)
        DispatchQueue.concurrentPerform(iterations: 100) { index in logger.log("producer=\(index)") }
        logger.flush()
        let lines = try String(contentsOf: directory.appendingPathComponent("debug.log")).split(separator: "\n").filter { $0.contains("producer=") }
        XCTAssertEqual(lines.count, 100)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertTrue(lines.allSatisfy { line in
            guard let timestamp = line.split(separator: " ").first else { return false }
            return formatter.date(from: String(timestamp)) != nil
        })
    }

    private class RecordingRunningApplication: NSRunningApplication, @unchecked Sendable {
        var activationCount = 0
        var quitCount = 0
        var hideCount = 0
        var testHidden = false
        override var isHidden: Bool { testHidden }

        override func hide() -> Bool {
            hideCount += 1
            testHidden = true
            return true
        }

        override func unhide() -> Bool {
            testHidden = false
            return true
        }

        override func terminate() -> Bool {
            quitCount += 1
            return true
        }

        override var isTerminated: Bool { false }

        override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
            activationCount += 1
            return true
        }
    }

    private func numberedApp(_ number: Int, process: NSRunningApplication, method: AppOpeningMethod?) -> OpenableApp {
        let url = URL(fileURLWithPath: "/nonexistent/MenuBarDockInstanceTest.app")
        let app = OpenableApp(bundleId: "com.ethansk.MenuBarDockInstanceTest", icon: NSImage(), bundleUrl: url,
                              name: "Instance Test", id: url.absoluteString, appOpeningMethod: method,
                              runningApplication: process)
        app.instanceNumber = number
        return app
    }

    func testOpen_numberedInstancesActivateTheirOwnProcessWithLaunchDefault() {
        let firstProcess = RecordingRunningApplication()
        let secondProcess = RecordingRunningApplication()
        let first = numberedApp(1, process: firstProcess, method: .launch)
        let second = numberedApp(2, process: secondProcess, method: .launch)

        first.open()
        XCTAssertEqual(firstProcess.activationCount, 1)
        XCTAssertEqual(secondProcess.activationCount, 0)

        second.open()
        XCTAssertEqual(firstProcess.activationCount, 1)
        XCTAssertEqual(secondProcess.activationCount, 1)
    }

    func testOpen_numberedInstanceWithoutOpeningOverrideActivatesItsProcess() {
        let process = RecordingRunningApplication()
        numberedApp(2, process: process, method: nil).open()
        XCTAssertEqual(process.activationCount, 1)
    }

    private final class MenuBarItemDataSourceStub: MenuBarItemDataSource {
        let rightClickByDefault = false

        func appOpeningMethod(for app: OpenableApp) -> AppOpeningMethod? {
            nil
        }
    }

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testRunningAppDropdown_putsQuitActionFirst() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let dataSource = MenuBarItemDataSourceStub()
        let menuBarItem = MenuBarItem(statusItem: statusItem, userPrefsDataSource: dataSource)
        let app = OpenableApp(
            bundleId: "com.example.TestApp",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            bundleUrl: URL(fileURLWithPath: "/Applications/Test App.app"),
            name: "Test App",
            id: "test-app",
            appOpeningMethod: nil,
            runningApplication: NSRunningApplication.current
        )
        menuBarItem.update(for: app, appIconSize: 16, slotWidth: 20)

        let menu = menuBarItem.makeDropdownMenu()

        XCTAssertEqual(menu?.items.first?.title, "Quit Test App")
        XCTAssertEqual(menu?.items.first?.keyEquivalent, "q")
        XCTAssertEqual(menu?.items.dropFirst().first?.title, "Hide Test App")
    }

    // MARK: - reorder(by:unorderedGoTo:) — un-ordered placement (bug fix, voice 4442)

    // Minimal Reorderable conformer so we can exercise the generic Array.reorder
    // extension without constructing real NSRunningApplication-backed apps.
    private struct Item: Reorderable, Equatable {
        let id: String
        var orderElement: String { id }
    }

    // Helper: turn a reordered [Item] back into its id list for easy asserting.
    private func ids(_ items: [Item]) -> [String] {
        items.map { $0.id }
    }

    // Ordered items keep their preferredOrder sequence; this is the baseline
    // behaviour that the bug fix must NOT regress.
    func testReorder_allOrdered_followsPreferredOrder() {
        let items = [Item(id: "c"), Item(id: "a"), Item(id: "b")]
        let result = ids(items.reorder(by: ["a", "b", "c"]))
        XCTAssertEqual(result, ["a", "b", "c"])
    }

    // THE BUG FIX (default .start): an item with NO ordering info must sort to
    // the BEGINNING of the array (the least-recent / "end of the dock" side),
    // NOT take the most-recent slot at the end. Here "x" is un-ordered.
    func testReorder_unorderedGoesToStart_byDefault() {
        let items = [Item(id: "a"), Item(id: "x"), Item(id: "b")]
        // preferredOrder = least->most recent (a then b). "x" is unknown.
        let result = ids(items.reorder(by: ["a", "b"]))
        // x first (oldest side), then a, then b (b == most recent, stays at end).
        XCTAssertEqual(result, ["x", "a", "b"])
        // Critical assertion: the un-ordered app is NOT last (the newest slot).
        XCTAssertNotEqual(result.last, "x")
    }

    // .end placement: un-ordered item sorts to the END of the array. Used by
    // .mostRecentOnLeft where preferredOrder is reversed (most->least recent)
    // and the limit keeps the FRONT via prefix(limit), so "oldest" == array end.
    func testReorder_unorderedGoesToEnd_whenRequested() {
        let items = [Item(id: "a"), Item(id: "x"), Item(id: "b")]
        // preferredOrder reversed = most->least recent (b then a). "x" unknown.
        let result = ids(items.reorder(by: ["b", "a"], unorderedGoTo: .end))
        // b (most recent) first, then a, then x (oldest side) last.
        XCTAssertEqual(result, ["b", "a", "x"])
        // Critical assertion: the un-ordered app is NOT first (the newest slot
        // for mostRecentOnLeft).
        XCTAssertNotEqual(result.first, "x")
    }

    // Multiple un-ordered items all land on the chosen side together; their
    // relative order among themselves is stable (no reordering between them).
    func testReorder_multipleUnordered_clusterOnStart() {
        let items = [Item(id: "y"), Item(id: "a"), Item(id: "x"), Item(id: "b")]
        let result = ids(items.reorder(by: ["a", "b"]))
        // y and x (unknown) at the start, preserving their input relative order,
        // then a, then b.
        XCTAssertEqual(result, ["y", "x", "a", "b"])
    }

    // All items un-ordered → input order preserved (stable, no crash / no
    // strict-weak-ordering violation).
    func testReorder_allUnordered_preservesInputOrder() {
        let items = [Item(id: "z"), Item(id: "y"), Item(id: "x")]
        let result = ids(items.reorder(by: []))
        XCTAssertEqual(result, ["z", "y", "x"])
    }
}

extension MenuBarDockTests {
    func testMenuBarItems_initialLayoutAndGrowingTheListKeepNativeLeftToRightOrder() {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let preferences = UserPrefs()
        let running = RunningApps(userPrefsDataSource: preferences)
        let pinned = RegularApps(userPrefsDataSource: preferences)
        let combined = OpenableApps(userPrefsDataSource: preferences, runningApps: running, regularApps: pinned)
        let bar = MenuBarItems(userPrefsDataSource: preferences)
        defer { for item in bar.items { NSStatusBar.system.removeStatusItem(item.statusItem) } }
        let applications = (0..<4).map { index in
            OpenableApp(bundleId: "com.ethansk.NativeOrderTest\(index)", icon: NSImage(size: NSSize(width: 16, height: 16)), bundleUrl: Bundle.main.bundleURL.appendingPathComponent("NativeOrder\(index).app"), name: "NativeOrder\(index)", id: "NativeOrder\(index)", appOpeningMethod: nil, runningApplication: nil)
        }
        for count in [3, 4, 2] {
            combined.apps = Array(applications.prefix(count))
            bar.update(openableApps: combined)
            let deadline = Date(timeIntervalSinceNow: 3)
            while Date() < deadline { // Wait for actual AppKit window placement, without adding a production timer or forcing layout.
                NSApp.updateWindows() // The isolated XCTest host supplies the window-update cycle normally driven by NSApplication.run.
                let shown = bar.items.filter { $0.app != nil }.sorted { $0.position < $1.position }
                if Set(shown.map { $0.position }).count == count && shown.compactMap({ $0.app?.id }) == combined.apps.map({ $0.id }) { break }
                RunLoop.main.run(mode: .default, before: deadline) // Service queued native work; a nonblocking nextEvent call does not run queued RunLoop.perform blocks.
            }
            let shown = bar.items.filter { $0.app != nil }.sorted { $0.position < $1.position }
            XCTAssertEqual(Set(shown.map { $0.position }).count, count)
            XCTAssertEqual(shown.compactMap { $0.app?.id }, combined.apps.map { $0.id })
        }
    }

    private final class ActivationDelegate: AppTrackerDelegate {
        let runningApps: RunningApps
        let snapshot: [NSRunningApplication]
        var activatedProcessIDs: [pid_t] = []

        init(runningApps: RunningApps, snapshot: [NSRunningApplication]) {
            self.runningApps = runningApps
            self.snapshot = snapshot
        }

        func appWasActivated(runningApp: NSRunningApplication) {
            activatedProcessIDs.append(runningApp.processIdentifier)
            runningApps.handleAppActivation(runningApp: runningApp)
            runningApps.update(runningApplications: snapshot)
        }

        func appWasLaunched(runningApp: NSRunningApplication) {}
        func appWasQuit(runningApp: NSRunningApplication) {}
    }

    func testActivation_menuBarOnlyAppsReleaseThePreviouslyHiddenAppWithoutChangingRecency() {
        let tracker = AppTracker()
        let center = NSWorkspace.shared.notificationCenter
        for direction in [RunningAppsSortingMethod.mostRecentOnRight, .mostRecentOnLeft] {
            for hideActive in [false, true] {
                let preferences = SnapshotPreferences()
                preferences.runningAppsSortingMethod = direction
                preferences.hideActiveAppFromRunningApps = hideActive
                preferences.maxRunningApps = 2
                let applications = (0..<3).map { index in
                    let application = SnapshotRunningApplication()
                    application.testPID = pid_t(301 + index)
                    application.testBundleURL = Bundle.main.bundleURL.appendingPathComponent("Activation\(index).app")
                    return application
                }
                let running = RunningApps(userPrefsDataSource: preferences)
                let delegate = ActivationDelegate(runningApps: running, snapshot: applications)
                tracker.delegate = delegate
                for application in applications {
                    center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: application])
                }
                let expectedBefore = (hideActive ? applications.prefix(2) : applications.suffix(2)).map { $0.testPID }
                XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, direction == .mostRecentOnRight ? expectedBefore : Array(expectedBefore.reversed()))

                for (index, policy) in [NSApplication.ActivationPolicy.accessory, .prohibited].enumerated() {
                    let menuBarApplication = SnapshotRunningApplication()
                    menuBarApplication.testPID = pid_t(401 + index)
                    menuBarApplication.testBundleURL = Bundle.main.bundleURL.appendingPathComponent("MenuBarOnly\(index).app")
                    menuBarApplication.policy = policy
                    center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: menuBarApplication])
                    let expected = applications.suffix(2).map { $0.testPID }
                    XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, direction == .mostRecentOnRight ? expected : Array(expected.reversed()))
                }

                center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: applications[0]])
                let expectedAfter = (hideActive ? [applications[1], applications[2]] : [applications[2], applications[0]]).map { $0.testPID }
                XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, direction == .mostRecentOnRight ? expectedAfter : Array(expectedAfter.reversed()))
                XCTAssertEqual(delegate.activatedProcessIDs, [301, 302, 303, 401, 402, 301])
            }
        }
    }

    private final class ClickedRowTable: NSTableView {
        var testClickedRow = -1
        override var clickedRow: Int { testClickedRow }
    }

    private final class RowDrag: NSObject, NSDraggingInfo {
        var draggingSource: Any?
        let draggingPasteboard = NSPasteboard.withUniqueName()
        let draggingDestinationWindow: NSWindow? = nil
        let draggingSourceOperationMask: NSDragOperation = .move
        let draggingLocation = NSPoint.zero
        let draggedImageLocation = NSPoint.zero
        let draggedImage: NSImage? = nil
        let draggingSequenceNumber = 1
        var draggingFormation = NSDraggingFormation.none
        var animatesToDestination = false
        var numberOfValidItemsForDrop = 1
        let springLoadingHighlight = NSSpringLoadingHighlight.none

        func slideDraggedImage(to screenPoint: NSPoint) {}
        func resetSpringLoading() {}
        func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    }

    func testPreferences_onlyAcceptsRowMovesFromItsOwnTable() {
        let prefs = UserPrefs()
        prefs.regularAppsUrls = [Bundle.main.bundleURL]
        let controller = PreferencesViewController(nibName: nil, bundle: nil)
        controller.userPrefsDataSource = prefs
        let table = NSTableView()
        table.dataSource = controller
        table.reloadData()
        let drag = RowDrag()
        defer { drag.draggingPasteboard.releaseGlobally() }
        let writer = controller.tableView(table, pasteboardWriterForRow: 0)!
        drag.draggingPasteboard.writeObjects([writer])
        XCTAssertEqual(controller.tableView(table, validateDrop: drag, proposedRow: 0, proposedDropOperation: .above), [])
        XCTAssertFalse(controller.tableView(table, acceptDrop: drag, row: 0, dropOperation: .above))

        drag.draggingSource = table
        XCTAssertEqual(controller.tableView(table, validateDrop: drag, proposedRow: 1, proposedDropOperation: .above), .move)
        XCTAssertTrue(controller.tableView(table, acceptDrop: drag, row: 1, dropOperation: .above))
        XCTAssertFalse(controller.tableView(table, acceptDrop: drag, row: 2, dropOperation: .above))
        prefs.regularAppsUrls = []
        XCTAssertFalse(controller.tableView(table, acceptDrop: drag, row: 0, dropOperation: .above))
    }

    func testPreferences_sliderActionsUpdateTheirLabelsWithoutAMouseEvent() {
        let controller = PreferencesViewController(nibName: nil, bundle: nil)
        let slider = NSSlider(value: 7, minValue: 0, maxValue: 10, target: nil, action: nil)
        let label = NSTextField()
        controller.itemSlotWidthCounterLabel = label
        controller.appIconSizeCounterLabel = label
        controller.maxRunningAppsCounterLabel = label
        for action in [controller.statusItemWidthSliderChanged, controller.appIconSizeSliderChange, controller.numberOfAppsSliderChanged] {
            label.stringValue = ""
            action(slider)
            XCTAssertEqual(label.stringValue, "7")
        }
    }

    func testPreferences_doubleClickOutsideAnAppRowReturnsWithoutCrashing() {
        let controller = PreferencesViewController(nibName: nil, bundle: nil)
        let table = ClickedRowTable()
        let preferences = UserPrefs()
        controller.regularAppsTable = table
        controller.userPrefsDataSource = preferences

        for appURLs in [[], [Bundle.main.bundleURL]] {
            preferences.regularAppsUrls = appURLs
            for row in [-1, appURLs.count, appURLs.count + 1] {
                table.testClickedRow = row
                controller.perform(NSSelectorFromString("tableRowDoubleClicked")) // Exercise the actual private Objective-C action without opening Finder for a valid row.
                XCTAssertEqual(preferences.regularAppsUrls, appURLs)
            }
        }
    }
}

// Refresh behavior across running-app snapshots and open menus.
extension MenuBarDockTests {
    func testPinnedApp_keepsItsActivatedInstanceAcrossRefreshesUntilItExits() {
        let preferences = SnapshotPreferences()
        preferences.regularAppsUrls = [Bundle.main.bundleURL]
        let pinned = RegularApps(userPrefsDataSource: preferences)
        let first = SnapshotRunningApplication()
        let second = SnapshotRunningApplication()
        second.testPID = 102
        pinned.update(runningApplications: [first, second])
        pinned.handleAppActivation(runningApp: second)
        pinned.update(runningApplications: [first, second])
        XCTAssertEqual(pinned.apps.first?.runningApp?.processIdentifier, second.testPID)

        second.testTerminated = true
        pinned.update(runningApplications: [second, first])
        XCTAssertEqual(pinned.apps.first?.runningApp?.processIdentifier, first.testPID)
        pinned.update(runningApplications: [])
        XCTAssertNil(pinned.apps.first?.runningApp)
    }

    func testFirstRefresh_keepsStartupOrderOnBothSidesWithALimit() {
        let snapshot = (1...4).map { index in
            let app = SnapshotRunningApplication()
            app.testPID = pid_t(500 + index)
            app.testBundleURL = URL(fileURLWithPath: "/Applications/App\(index).app")
            return app
        }
        let preferences = SnapshotPreferences()
        preferences.maxRunningApps = 3
        for direction in [RunningAppsSortingMethod.mostRecentOnLeft, .mostRecentOnRight] {
            preferences.runningAppsSortingMethod = direction
            let running = RunningApps(userPrefsDataSource: preferences, runningApplications: snapshot)
            let initial = running.apps.map { $0.app.processIdentifier }
            XCTAssertEqual(initial.count, 3)
            running.update(runningApplications: snapshot)
            XCTAssertEqual(running.apps.map { $0.app.processIdentifier }, initial)
        }
    }

    func testConsistentOrder_usesAllEligibleAppsRegardlessOfActivationHistoryOrLimit() {
        let preferences = SnapshotPreferences()
        preferences.runningAppsSortingMethod = .consistent
        let running = RunningApps(userPrefsDataSource: preferences)
        let apps = ["Charlie", "Alpha", "Bravo"].enumerated().map { index, name in
            let app = SnapshotRunningApplication()
            app.testPID = pid_t(201 + index)
            app.testBundleURL = URL(fileURLWithPath: "/Applications/\(name).app")
            return app
        }
        for limit in [3, 2] {
            preferences.maxRunningApps = limit
            for active in apps {
                running.handleAppActivation(runningApp: active)
                running.update(runningApplications: apps)
                XCTAssertEqual(running.apps.map { $0.app.processIdentifier },
                               Array([apps[1], apps[2], apps[0]].suffix(limit)).map { $0.testPID })
            }
        }
    }

    func testOpenMenu_keepsItsProcessWhenTheStatusItemIsReusedOrCleared() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: 20)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let dataSource = MenuBarItemDataSourceStub()
        let item = MenuBarItem(statusItem: statusItem, userPrefsDataSource: dataSource)
        let originalProcess = RecordingRunningApplication()
        let replacementProcess = RecordingRunningApplication()
        item.update(for: numberedApp(1, process: originalProcess, method: nil), appIconSize: 16, slotWidth: 20)
        let menu = try XCTUnwrap(item.makeDropdownMenu())
        item.update(for: numberedApp(2, process: replacementProcess, method: nil), appIconSize: 16, slotWidth: 20)
        menu.performActionForItem(at: 0) // The first command is Quit for the process that was clicked.
        XCTAssertEqual(originalProcess.quitCount, 1)
        XCTAssertEqual(replacementProcess.quitCount, 0)

        originalProcess.testHidden = true // Another action hid the original app while the open menu still says Hide.
        let hide = try XCTUnwrap(menu.items.firstIndex { $0.keyEquivalent == "h" })
        menu.performActionForItem(at: hide)
        XCTAssertTrue(originalProcess.testHidden)
        XCTAssertEqual(originalProcess.hideCount, 1)
        XCTAssertEqual(replacementProcess.hideCount, 0)

        item.reset()
        let activate = try XCTUnwrap(menu.items.firstIndex { $0.keyEquivalent == "a" })
        menu.performActionForItem(at: activate)
        XCTAssertEqual(originalProcess.activationCount, 1)
        XCTAssertEqual(replacementProcess.activationCount, 0)
    }
}
