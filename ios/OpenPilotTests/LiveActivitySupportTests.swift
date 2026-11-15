import XCTest
@testable import OpenPilot

final class LiveActivitySupportTests: XCTestCase {
    func testSnippetShort() {
        XCTAssertEqual(LiveActivitySupport.snippet("hola"), "hola")
    }

    func testSnippetFlattensNewlines() {
        XCTAssertEqual(LiveActivitySupport.snippet("a\nb\nc"), "a b c")
    }

    func testSnippetTrims() {
        XCTAssertEqual(LiveActivitySupport.snippet("  hi  "), "hi")
    }

    func testSnippetTruncates() {
        let long = String(repeating: "x", count: 200)
        let out = LiveActivitySupport.snippet(long, max: 90)
        XCTAssertEqual(out.count, 90)
        XCTAssertTrue(out.hasSuffix("…"))
    }

    func testSnippetEmpty() {
        XCTAssertEqual(LiveActivitySupport.snippet("   \n  "), "")
    }

    func testStatusLabel() {
        XCTAssertEqual(LiveActivitySupport.statusLabel("listening"), "Listening…")
        XCTAssertEqual(LiveActivitySupport.statusLabel("streaming"), "Responding…")
        XCTAssertEqual(LiveActivitySupport.statusLabel("whatever"), "Responding…")
    }
}