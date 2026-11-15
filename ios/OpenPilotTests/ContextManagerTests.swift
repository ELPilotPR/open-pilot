import XCTest
@testable import OpenPilot

final class ContextManagerTests: XCTestCase {
    private func turn(_ role: String, _ content: String) -> ChatTurn {
        ChatTurn(role: role, content: content)
    }

    func testEstimateTokens() {
        XCTAssertEqual(ContextManager.estimateTokens("abcd"), 1)
        XCTAssertEqual(ContextManager.estimateTokens(String(repeating: "x", count: 400)), 100)
        XCTAssertEqual(ContextManager.estimateTokens([turn("user", String(repeating: "x", count: 400))]), 100)
    }

    func testNoCompactionUnderBudget() {
        let turns = [turn("user", "hola"), turn("assistant", "hi")]
        let p = ContextManager.compact(turns, budget: 1000)
        XCTAssertFalse(p.didCompact)
        XCTAssertEqual(p.compacted.count, 2)
        XCTAssertEqual(p.beforeTokens, p.afterTokens)
    }

    func testCompactionOverBudget() {
        var turns = [turn("system", "sys")]
        for i in 0..<20 {
            turns.append(turn(i % 2 == 0 ? "user" : "assistant", String(repeating: "palabra ", count: 100)))
        }
        let p = ContextManager.compact(turns, budget: 500, keepRecent: 4)
        XCTAssertTrue(p.didCompact)
        XCTAssertEqual(p.foldedCount, 16)
        XCTAssertLessThan(p.afterTokens, p.beforeTokens)
        XCTAssertEqual(p.compacted.count, 6) // 1 system + 1 summary + 4 recent
        XCTAssertEqual(p.compacted.filter { $0.role == "system" }.count, 2)
        XCTAssertEqual(p.compacted.suffix(4).map { $0.content }, turns.suffix(4).map { $0.content })
    }

    func testKeepsRecentWhenFewMessages() {
        var turns = [turn("system", "sys")]
        for _ in 0..<3 { turns.append(turn("user", String(repeating: "x", count: 2000))) }
        let p = ContextManager.compact(turns, budget: 100, keepRecent: 6)
        XCTAssertFalse(p.didCompact) // only 3 non-system turns, <= keepRecent
    }

    func testSummaryCapBoundsDigest() {
        var turns: [ChatTurn] = []
        for _ in 0..<100 { turns.append(turn("user", String(repeating: "texto ", count: 200))) }
        let p = ContextManager.compact(turns, budget: 100, keepRecent: 2)
        XCTAssertTrue(p.didCompact)
        XCTAssertEqual(p.foldedCount, 98)
        // digest is capped, so the summary turn stays bounded regardless of history length
        let summary = p.compacted.first { $0.role == "system" }!
        let bullets = summary.content.components(separatedBy: "•").count - 1
        XCTAssertLessThanOrEqual(bullets, ContextManager.summaryCap)
    }

    func testSummaryContainsBullets() {
        let s = ContextManager.summarize([turn("user", "pregunta uno"), turn("assistant", "respuesta uno")])
        XCTAssertTrue(s.contains("•"))
        XCTAssertTrue(s.contains("pregunta uno"))
        XCTAssertTrue(s.contains("respuesta uno"))
    }

    func testSummaryTruncatesLong() {
        let long = String(repeating: "a", count: 500)
        let s = ContextManager.summarize([turn("user", long)])
        XCTAssertTrue(s.contains("…"))
        XCTAssertFalse(s.contains(long))
    }

    func testRecentImagesPreserved() {
        var turns: [ChatTurn] = []
        for _ in 0..<10 { turns.append(turn("user", String(repeating: "texto ", count: 200))) }
        var last = turn("user", "mira esta foto")
        last.images = [Data([1, 2, 3])]
        turns.append(last)
        let p = ContextManager.compact(turns, budget: 100, keepRecent: 2)
        XCTAssertEqual(p.compacted.last?.images.count, 1)
    }
}