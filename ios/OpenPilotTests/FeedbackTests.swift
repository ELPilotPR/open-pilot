import XCTest
import SwiftData
@testable import OpenPilot

/// Voto 👍/👎 sobre las respuestas.
final class FeedbackTests: XCTestCase {
    func testStartsNeutral() {
        let m = Message(role: "assistant", text: "hola")
        XCTAssertEqual(m.feedback, 0)
    }

    func testThumbsUpTogglesOff() {
        let m = Message(role: "assistant", text: "hola")
        m.toggleFeedback(1)
        XCTAssertEqual(m.feedback, 1)
        m.toggleFeedback(1)
        XCTAssertEqual(m.feedback, 0, "tocar el mismo voto debe quitarlo")
    }

    func testThumbsDownReplacesUp() {
        let m = Message(role: "assistant", text: "hola")
        m.toggleFeedback(1)
        m.toggleFeedback(-1)
        XCTAssertEqual(m.feedback, -1, "el voto contrario reemplaza al anterior")
        m.toggleFeedback(-1)
        XCTAssertEqual(m.feedback, 0)
    }
}
