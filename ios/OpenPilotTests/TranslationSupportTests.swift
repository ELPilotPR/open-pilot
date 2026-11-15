import XCTest
@testable import OpenPilot

final class TranslationSupportTests: XCTestCase {
    func testLanguageCount() {
        XCTAssertEqual(TranslationSupport.languages.count, 12)
    }
    func testUniqueCodes() {
        XCTAssertEqual(Set(TranslationSupport.languages.map { $0.code }).count, 12)
    }
    func testDefaultTargetSpanishDevice() {
        XCTAssertEqual(TranslationSupport.defaultTarget(deviceLanguage: "es"), "en")
    }
    func testDefaultTargetEnglishDevice() {
        XCTAssertEqual(TranslationSupport.defaultTarget(deviceLanguage: "en"), "es")
    }
    func testDefaultTargetOtherDevice() {
        XCTAssertEqual(TranslationSupport.defaultTarget(deviceLanguage: "fr"), "es")
    }
    func testNameLookup() {
        XCTAssertEqual(TranslationSupport.name(for: "ja"), "Japanese")
        XCTAssertEqual(TranslationSupport.name(for: "xx"), "xx")
    }
    func testPromptContainsTextAndLanguage() {
        let p = TranslationSupport.prompt(text: "Hola mundo", targetCode: "en")
        XCTAssertTrue(p.contains("Hola mundo"))
        XCTAssertTrue(p.contains("English"))
        XCTAssertTrue(p.contains("ONLY the translation"))
    }
}