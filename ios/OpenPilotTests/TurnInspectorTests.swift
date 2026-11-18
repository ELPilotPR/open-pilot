import XCTest
@testable import OpenPilot

/// Tests del formateo puro del inspector de turno.
final class TurnInspectorTests: XCTestCase {
    func testDurationNilIsDash() {
        XCTAssertEqual(TurnInspector.formatDuration(nil), "—")
    }

    func testDurationNegativeIsDash() {
        XCTAssertEqual(TurnInspector.formatDuration(-0.5), "—")
    }

    func testDurationSubSecondInMilliseconds() {
        XCTAssertEqual(TurnInspector.formatDuration(0.5), "500 ms")
        XCTAssertEqual(TurnInspector.formatDuration(0.001), "1 ms")
    }

    func testDurationSecondsTwoDecimals() {
        XCTAssertEqual(TurnInspector.formatDuration(1.5), "1.50 s")
        XCTAssertEqual(TurnInspector.formatDuration(12.345), "12.35 s")
    }

    func testDurationZeroIsMilliseconds() {
        XCTAssertEqual(TurnInspector.formatDuration(0), "0 ms")
    }

    func testTPSZeroIsDash() {
        XCTAssertEqual(TurnInspector.formatTPS(0), "—")
        XCTAssertEqual(TurnInspector.formatTPS(-3), "—")
    }

    func testTPSOneDecimal() {
        XCTAssertEqual(TurnInspector.formatTPS(42.34), "42.3")
        XCTAssertEqual(TurnInspector.formatTPS(7), "7.0")
    }

    func testCountZeroIsDash() {
        XCTAssertEqual(TurnInspector.formatCount(0), "—")
    }

    func testCountPositive() {
        XCTAssertEqual(TurnInspector.formatCount(5), "5")
        XCTAssertEqual(TurnInspector.formatCount(1234), "1234")
    }

    func testCostNilIsDash() {
        XCTAssertEqual(TurnInspector.formatCost(nil), "—")
    }

    func testCostZeroOrNegativeIsDash() {
        XCTAssertEqual(TurnInspector.formatCost(0), "—")
        XCTAssertEqual(TurnInspector.formatCost(-1.5), "—")
    }

    func testCostSmallFourDecimals() {
        XCTAssertEqual(TurnInspector.formatCost(0.0023), "$0.0023")
        XCTAssertEqual(TurnInspector.formatCost(0.0002), "$0.0002")
    }

    func testCostLargeTwoDecimals() {
        XCTAssertEqual(TurnInspector.formatCost(0.5), "$0.50")
        XCTAssertEqual(TurnInspector.formatCost(1.234), "$1.23")
    }

    func testCostBoundary() {
        XCTAssertEqual(TurnInspector.formatCost(0.01), "$0.01")
    }
}
