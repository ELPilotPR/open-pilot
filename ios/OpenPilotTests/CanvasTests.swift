import XCTest
@testable import OpenPilot

/// Pruebas de las funciones puras de Canvas: limpieza de fences y extracción de
/// bloques de código desde un mensaje.
@MainActor
final class CanvasTests: XCTestCase {

    func testStripFences() {
        XCTAssertEqual(CanvasDocument.strip("```swift\nlet x = 1\n```"), "let x = 1")
    }

    func testStripPlain() {
        XCTAssertEqual(CanvasDocument.strip("  hola  "), "hola")
    }

    func testStripNoFence() {
        XCTAssertEqual(CanvasDocument.strip("let x = 1"), "let x = 1")
    }

    func testFirstCodeBlock() {
        let text = "Aquí tienes:\n```python\nprint('hola')\n```\nListo."
        let r = ChatView.firstCodeBlock(in: text)
        XCTAssertEqual(r?.0, "python")
        XCTAssertEqual(r?.1, "print('hola')")
    }

    func testNoCodeBlock() {
        XCTAssertNil(ChatView.firstCodeBlock(in: "solo texto sin código"))
    }
}
