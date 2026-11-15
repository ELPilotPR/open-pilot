import XCTest
@testable import OpenPilot

final class ConversationSearchTests: XCTestCase {
    private func makeConv(_ title: String, messages: [(String, String)], temporary: Bool = false) -> Conversation {
        let c = Conversation(title: title, providerID: "casa", model: "swift-iq3_s")
        c.isTemporary = temporary
        for (role, text) in messages {
            let m = Message(role: role, text: text)
            m.conversation = c; c.messages.append(m)
        }
        c.ensureTree()
        return c
    }

    func testEmptyQueryReturnsEmpty() {
        let c = makeConv("Hola", messages: [("user", "texto")])
        XCTAssertTrue(ConversationSearch.search("  ", in: [c]).isEmpty)
    }
    func testTitleMatch() {
        let c = makeConv("Recetas de cocina", messages: [("user", "nada")])
        let hits = ConversationSearch.search("recetas", in: [c])
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.role, "title")
    }
    func testMessageMatch() {
        let c = makeConv("Chat", messages: [("assistant", "La capital de Francia es París")])
        let hits = ConversationSearch.search("parís", in: [c])
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.role, "assistant")
        XCTAssertEqual(hits.first?.conversationID, c.id)
    }
    func testCaseInsensitive() {
        let c = makeConv("Chat", messages: [("user", "OPENPILOT rocks")])
        XCTAssertEqual(ConversationSearch.search("openpilot", in: [c]).count, 1)
    }
    func testDiacriticInsensitive() {
        let c = makeConv("Chat", messages: [("user", "me gusta la canción")])
        XCTAssertEqual(ConversationSearch.search("cancion", in: [c]).count, 1)
    }
    func testTemporaryExcluded() {
        let c = makeConv("Secreto", messages: [("user", "clave")], temporary: true)
        XCTAssertTrue(ConversationSearch.search("clave", in: [c]).isEmpty)
    }
    func testNoMatchEmpty() {
        let c = makeConv("Chat", messages: [("user", "hola mundo")])
        XCTAssertTrue(ConversationSearch.search("zzzznoexiste", in: [c]).isEmpty)
    }
    func testLimit() {
        let c = makeConv("Chat", messages: (0..<10).map { ("user", "palabra \($0)") })
        XCTAssertEqual(ConversationSearch.search("palabra", in: [c], limit: 3).count, 3)
    }
    func testSnippetEllipsis() {
        let long = String(repeating: "a", count: 100) + " objetivo " + String(repeating: "b", count: 100)
        let c = makeConv("Chat", messages: [("user", long)])
        let snip = ConversationSearch.search("objetivo", in: [c]).first?.snippet ?? ""
        XCTAssertTrue(snip.hasPrefix("…"))
        XCTAssertTrue(snip.hasSuffix("…"))
        XCTAssertTrue(snip.contains("objetivo"))
    }
    func testSortByDateDesc() {
        let older = makeConv("Viejo", messages: [("user", "clave")])
        let newer = makeConv("Nuevo", messages: [("user", "clave")])
        older.messages[0].createdAt = Date().addingTimeInterval(-10000)
        newer.messages[0].createdAt = Date()
        let hits = ConversationSearch.search("clave", in: [older, newer])
        XCTAssertEqual(hits.first?.conversationTitle, "Nuevo")
    }
}