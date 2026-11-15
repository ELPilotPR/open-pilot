import XCTest
@testable import OpenPilot

final class AutoTaggerTests: XCTestCase {
    private func msgs(_ texts: [String]) -> [Message] {
        let c = Conversation(title: "T", providerID: "casa", model: "m")
        for t in texts { let m = Message(role: "user", text: t); m.conversation = c; c.messages.append(m) }
        c.ensureTree(); return c.messages
    }
    func testTopicCode() {
        XCTAssertTrue(AutoTagger.topicTags("Escribe una función en Swift con un bug").contains("code"))
    }
    func testTopicFood() {
        XCTAssertTrue(AutoTagger.topicTags("Dame una receta de comida para cocinar").contains("food"))
    }
    func testTopicNone() {
        XCTAssertTrue(AutoTagger.topicTags("xyz qwerty").isEmpty)
    }
    func testKeywordsFrequency() {
        let k = AutoTagger.keywords("kubernetes kubernetes kubernetes deployment", max: 1)
        XCTAssertEqual(k, ["kubernetes"])
    }
    func testTagsCombined() {
        let tags = AutoTagger.tags(for: msgs(["Cómo hago un deploy de mi api en python con git"]))
        XCTAssertTrue(tags.contains("code"))
        XCTAssertLessThanOrEqual(tags.count, 6)
    }
    func testParseAITags() {
        XCTAssertEqual(AutoTagger.parseAITags("Code, Swift, #iOS, code"), ["code", "swift", "ios"])
    }
    func testParseAITagsCap() {
        let raw = (0..<20).map { "tag\($0)" }.joined(separator: ",")
        XCTAssertLessThanOrEqual(AutoTagger.parseAITags(raw, max: 5).count, 5)
    }
    func testParseAITagsEmpty() {
        XCTAssertTrue(AutoTagger.parseAITags("  , ,\n").isEmpty)
    }
    func testAiPromptContainsText() {
        XCTAssertTrue(AutoTagger.aiPrompt(msgs(["contenido único"])).contains("contenido único"))
    }
}