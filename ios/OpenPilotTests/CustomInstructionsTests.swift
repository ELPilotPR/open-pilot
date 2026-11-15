import XCTest
@testable import OpenPilot

/// Composición del system prompt de instrucciones personalizadas (UserDefaults).
final class CustomInstructionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CustomInstructions.enabled = true
        CustomInstructions.aboutYou = ""
        CustomInstructions.responsePrefs = ""
    }

    override func tearDown() {
        CustomInstructions.aboutYou = ""
        CustomInstructions.responsePrefs = ""
        CustomInstructions.enabled = true
        super.tearDown()
    }

    func testEmptyWhenDisabled() {
        CustomInstructions.enabled = false
        CustomInstructions.aboutYou = "Soy Javier"
        XCTAssertEqual(CustomInstructions.systemPrompt, "")
    }

    func testEmptyWhenNoContent() {
        XCTAssertEqual(CustomInstructions.systemPrompt, "")
    }

    func testAboutOnly() {
        CustomInstructions.aboutYou = "Soy Javier"
        let s = CustomInstructions.systemPrompt
        XCTAssertTrue(s.contains("Soy Javier"))
        XCTAssertTrue(s.contains("Contexto sobre el usuario"))
    }

    func testBothSections() {
        CustomInstructions.aboutYou = "Vivo en Wisconsin"
        CustomInstructions.responsePrefs = "Responde en español"
        let s = CustomInstructions.systemPrompt
        XCTAssertTrue(s.contains("Vivo en Wisconsin"))
        XCTAssertTrue(s.contains("Responde en español"))
        XCTAssertTrue(s.contains("Cómo debe responder el modelo"))
    }

    func testWhitespaceOnlyIsEmpty() {
        CustomInstructions.aboutYou = "   \n  "
        XCTAssertEqual(CustomInstructions.systemPrompt, "")
    }
}
