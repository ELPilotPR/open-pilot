import XCTest
import SwiftData
@testable import OpenPilot

/// Búsqueda dentro de la conversación (filtro de mensajes).
final class SearchTests: XCTestCase {
    private func msgs() -> [Message] {
        [Message(role: "user", text: "Háblame de París"),
         Message(role: "assistant", text: "París es la capital de Francia."),
         Message(role: "user", text: "¿Y Madrid?"),
         Message(role: "assistant", text: "Madrid tiene clima seco.")]
    }

    func testEmptyQueryReturnsAll() {
        XCTAssertEqual(ChatView.filterMessages(msgs(), query: "").count, 4)
        XCTAssertEqual(ChatView.filterMessages(msgs(), query: "   ").count, 4)
    }

    func testCaseInsensitiveMatch() {
        let r = ChatView.filterMessages(msgs(), query: "parís")
        XCTAssertEqual(r.count, 2)
        XCTAssertTrue(r.allSatisfy { $0.text.localizedCaseInsensitiveContains("parís") })
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertEqual(ChatView.filterMessages(msgs(), query: "Tokio").count, 0)
    }
}
