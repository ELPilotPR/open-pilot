import XCTest
@testable import OpenPilot

final class ConversationSummarizerTests: XCTestCase {
    private func conv(_ texts: [(String, String)]) -> [Message] {
        let c = Conversation(title: "T", providerID: "casa", model: "m")
        for (role, text) in texts {
            let m = Message(role: role, text: text); m.conversation = c; c.messages.append(m)
        }
        c.ensureTree()
        return c.messages
    }

    func testSentencesSplit() {
        let s = ConversationSummarizer.sentences("Hola mundo. Otra frase! Y una más?")
        XCTAssertEqual(s.count, 3)
    }
    func testExtractiveEmpty() {
        XCTAssertTrue(ConversationSummarizer.extractive([]).isEmpty)
    }
    func testExtractiveMaxBullets() {
        let msgs = conv([("user", (0..<12).map { "Frase número \($0) sobre varios temas distintos" }.joined(separator: ". "))])
        XCTAssertLessThanOrEqual(ConversationSummarizer.extractive(msgs, maxBullets: 4).count, 4)
    }
    func testExtractivePicksFrequentTopic() {
        let msgs = conv([
            ("user", "Python es un lenguaje de programación. Python se usa para datos. Python es popular."),
            ("assistant", "El clima hoy es soleado y agradable en la ciudad.")
        ])
        let bullets = ConversationSummarizer.extractive(msgs, maxBullets: 2)
        XCTAssertTrue(bullets.contains { $0.lowercased().contains("python") })
    }
    func testExtractiveDedup() {
        let msgs = conv([("user", "Repetido exacto. Repetido exacto. Repetido exacto.")])
        let bullets = ConversationSummarizer.extractive(msgs)
        XCTAssertEqual(bullets.filter { $0 == "Repetido exacto" }.count, 1)
    }
    func testTranscriptRoles() {
        let msgs = conv([("user", "hola"), ("assistant", "qué tal")])
        let t = ConversationSummarizer.transcript(msgs)
        XCTAssertTrue(t.contains("Usuario: hola"))
        XCTAssertTrue(t.contains("Asistente: qué tal"))
    }
    func testTranscriptTruncation() {
        let msgs = conv([("user", String(repeating: "x", count: 9000))])
        XCTAssertLessThanOrEqual(ConversationSummarizer.transcript(msgs, maxChars: 1000).count, 1000)
    }
    func testAiPromptContainsTranscript() {
        let msgs = conv([("user", "dato clave")])
        XCTAssertTrue(ConversationSummarizer.aiPrompt(msgs).contains("dato clave"))
    }
    func testStopwordsFiltered() {
        let ws = ConversationSummarizer.words("the quick brown fox")
        XCTAssertFalse(ws.contains("the"))
        XCTAssertTrue(ws.contains("quick"))
    }
}