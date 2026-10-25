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
