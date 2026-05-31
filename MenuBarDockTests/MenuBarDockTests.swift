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
