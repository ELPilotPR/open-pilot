import XCTest
@testable import OpenPilot

final class ChatOutlineTests: XCTestCase {
    func testBuildOnlyUserTurnsIndexed() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let turns: [(id: UUID, role: String, text: String)] = [
            (a, "user", "primera pregunta"),
            (b, "assistant", "respuesta"),
            (c, "user", "segunda pregunta"),
            (d, "assistant", "otra respuesta"),
        ]
        let entries = ChatOutline.build(turns)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id, a)
        XCTAssertEqual(entries[0].index, 1)
        XCTAssertEqual(entries[1].id, c)
        XCTAssertEqual(entries[1].index, 2)
        XCTAssertEqual(entries[0].preview, "primera pregunta")
    }

    func testBuildEmpty() {
        XCTAssertTrue(ChatOutline.build([]).isEmpty)
        XCTAssertTrue(ChatOutline.build([(UUID(), "assistant", "hola")]).isEmpty)
    }

    func testPreviewFlattensAndTrims() {
        XCTAssertEqual(ChatOutline.preview("  hola\nmundo  "), "hola mundo")
    }

    func testPreviewTruncates() {
        let long = String(repeating: "x", count: 200)
        let p = ChatOutline.preview(long, max: 80)
        XCTAssertEqual(p.count, 81) // 80 + ellipsis
        XCTAssertTrue(p.hasSuffix("…"))
    }

    func testPreviewEmpty() {
        XCTAssertEqual(ChatOutline.preview("   "), "…")
        XCTAssertEqual(ChatOutline.preview(""), "…")
    }
}