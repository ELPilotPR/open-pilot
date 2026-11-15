import XCTest
import SwiftData
@testable import OpenPilot

/// Chat temporal: flag del modelo y exclusión del historial.
final class TemporaryTests: XCTestCase {
    func testDefaultsToFalse() {
        let c = Conversation(title: "x")
        XCTAssertFalse(c.isTemporary)
    }

    func testTemporaryFlagSettable() {
        let c = Conversation(title: "x")
        c.isTemporary = true
        XCTAssertTrue(c.isTemporary)
    }

    func testTempExcludedFromHistoryFilter() {
        // Replica la lógica del sidebar: los temporales no entran al historial.
        let normal = Conversation(title: "normal")
        let temp = Conversation(title: "temp"); temp.isTemporary = true
        let history = [normal, temp].filter { !$0.isTemporary }
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.title, "normal")
    }
}
