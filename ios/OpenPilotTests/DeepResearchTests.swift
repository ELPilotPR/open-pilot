import XCTest
@testable import OpenPilot

final class DeepResearchTests: XCTestCase {
    func testParseNumberedList() {
        let text = "1. primera consulta\n2. segunda consulta\n3. tercera"
        XCTAssertEqual(DeepResearchPlanner.parseQueries(text, max: 4),
                       ["primera consulta", "segunda consulta", "tercera"])
    }

    func testParseBulletsAndHeader() {
        let text = "Sub-consultas:\n- alpha\n* beta\n• gamma"
        XCTAssertEqual(DeepResearchPlanner.parseQueries(text, max: 4), ["alpha", "beta", "gamma"])
    }

    func testParseCapsAtMax() {
        let text = "1. a\n2. b\n3. c\n4. d\n5. e"
        XCTAssertEqual(DeepResearchPlanner.parseQueries(text, max: 3).count, 3)
    }

    func testParseEmpty() {
        XCTAssertEqual(DeepResearchPlanner.parseQueries("  \n\n", max: 4), [])
    }

    func testDedupSourcesCaseInsensitive() {
        let a = WebSource(title: "A", url: "https://x.com", snippet: "s")
        let b = WebSource(title: "B", url: "https://X.com", snippet: "s")
        let c = WebSource(title: "C", url: "https://y.com", snippet: "s")
        let out = DeepResearchPlanner.dedupSources([a, b, c], limit: 12)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].title, "A")
        XCTAssertEqual(out[1].title, "C")
    }

    func testDedupLimit() {
        let srcs = (0..<10).map { WebSource(title: "t\($0)", url: "https://\($0).com", snippet: "") }
        XCTAssertEqual(DeepResearchPlanner.dedupSources(srcs, limit: 3).count, 3)
    }

    func testReduceDeltas() {
        let events: [ChatEvent] = [.delta("Hola"), .reasoning("think"), .delta(" mundo"),
                                   .usage(promptTokens: 1, completionTokens: 2), .done]
        XCTAssertEqual(DeepResearchPlanner.reduce(events), "Hola mundo")
    }

    func testPlanPromptContainsQuestionAndMax() {
        let p = DeepResearchPlanner.planPrompt(question: "¿ clima ?", max: 3)
        XCTAssertTrue(p.contains("¿ clima ?"))
        XCTAssertTrue(p.contains("3"))
    }

    func testSynthesisTurns() {
        let src = WebSource(title: "T", url: "https://t.com", snippet: "body", content: "full")
        let turns = DeepResearchPlanner.synthesisTurns(question: "Q?", sources: [src])
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].role, "system")
        XCTAssertEqual(turns[1].role, "user")
        XCTAssertEqual(turns[1].content, "Q?")
        XCTAssertTrue(turns[0].content.contains("https://t.com"))
        XCTAssertTrue(turns[0].content.contains("[1]"))
        XCTAssertTrue(turns[0].content.contains("full"))
    }

    func testRoundRobinInterleavesByRank() {
        let a = [WebSource(title: "a1", url: "https://a1.com", snippet: ""),
                 WebSource(title: "a2", url: "https://a2.com", snippet: "")]
        let b = [WebSource(title: "b1", url: "https://b1.com", snippet: ""),
                 WebSource(title: "b2", url: "https://b2.com", snippet: "")]
        let out = DeepResearchPlanner.roundRobinMerge([a, b], limit: 10)
        XCTAssertEqual(out.map { $0.title }, ["a1", "b1", "a2", "b2"])
    }

    func testRoundRobinDedupsAcrossLists() {
        let a = [WebSource(title: "a", url: "https://x.com", snippet: "")]
        let b = [WebSource(title: "b", url: "https://X.com", snippet: ""),
                 WebSource(title: "c", url: "https://y.com", snippet: "")]
        let out = DeepResearchPlanner.roundRobinMerge([a, b], limit: 10)
        XCTAssertEqual(out.map { $0.title }, ["a", "c"])
    }

    func testRoundRobinCapsLimit() {
        let a = (0..<5).map { WebSource(title: "a\($0)", url: "https://a\($0).com", snippet: "") }
        let b = (0..<5).map { WebSource(title: "b\($0)", url: "https://b\($0).com", snippet: "") }
        XCTAssertEqual(DeepResearchPlanner.roundRobinMerge([a, b], limit: 3).count, 3)
    }

    func testRoundRobinEmpty() {
        XCTAssertEqual(DeepResearchPlanner.roundRobinMerge([], limit: 5).count, 0)
        XCTAssertEqual(DeepResearchPlanner.roundRobinMerge([[]], limit: 5).count, 0)
    }

    func testSynthesisIncludesTrustNotice() {
        let src = WebSource(title: "T", url: "https://t.com", snippet: "s")
        let turns = DeepResearchPlanner.synthesisTurns(question: "Q?", sources: [src])
        XCTAssertTrue(turns[0].content.contains(WebSearchService.trustNotice))
    }
}
