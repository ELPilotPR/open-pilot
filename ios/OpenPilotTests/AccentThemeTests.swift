import XCTest
import SwiftUI
@testable import OpenPilot

final class AccentThemeTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.accent.\(UUID().uuidString)")!
    }

    func testEightAccents() {
        XCTAssertEqual(AccentTheme.allCases.count, 8)
    }
    func testDefaultBlue() {
        XCTAssertEqual(AccentTheme.current(defaults: freshDefaults()), .blue)
    }
    func testCurrentReadsPreference() {
        let d = freshDefaults(); d.set("purple", forKey: "accentColor")
        XCTAssertEqual(AccentTheme.current(defaults: d), .purple)
    }
    func testInvalidFallsBackBlue() {
        let d = freshDefaults(); d.set("nope", forKey: "accentColor")
        XCTAssertEqual(AccentTheme.current(defaults: d), .blue)
    }
    func testRawValueRoundTrip() {
        for t in AccentTheme.allCases { XCTAssertEqual(AccentTheme(rawValue: t.rawValue), t) }
    }
    func testHexValid() {
        for t in AccentTheme.allCases {
            XCTAssertEqual(t.light.count, 7)
            XCTAssertEqual(t.dark.count, 7)
            XCTAssertTrue(t.light.hasPrefix("#"))
            XCTAssertTrue(t.dark.hasPrefix("#"))
        }
    }
    func testDistinctLightColors() {
        XCTAssertEqual(Set(AccentTheme.allCases.map { $0.light }).count, 8)
    }
}