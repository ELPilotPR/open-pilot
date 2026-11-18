import XCTest
import SwiftData
@testable import OpenPilot

/// Tests del badge de uso por conversación: helpers puros de tokens y coste.
@MainActor
final class ConversationUsageTests: XCTestCase {
    private func msg(_ p: Int, _ c: Int) -> Message {
        let m = Message(role: "assistant", text: "x")
        m.promptTokens = p
        m.completionTokens = c
        return m
    }

    // MARK: - totals

    func testTotalsEmpty() {
        let t = ConversationUsage.totals([])
        XCTAssertEqual(t.prompt, 0)
        XCTAssertEqual(t.completion, 0)
    }

    func testTotalsSumsPromptAndCompletion() {
        let t = ConversationUsage.totals([msg(100, 40), msg(250, 60), msg(0, 5)])
        XCTAssertEqual(t.prompt, 350)
        XCTAssertEqual(t.completion, 105)
    }

    // MARK: - formatTokens

    func testFormatTokensZero() {
        XCTAssertEqual(ConversationUsage.formatTokens(0), "0")
    }

    func testFormatTokensBelowThousand() {
        XCTAssertEqual(ConversationUsage.formatTokens(980), "980")
        XCTAssertEqual(ConversationUsage.formatTokens(999), "999")
    }

    func testFormatTokensThousands() {
        XCTAssertEqual(ConversationUsage.formatTokens(1000), "1.0k")
        XCTAssertEqual(ConversationUsage.formatTokens(1500), "1.5k")
        XCTAssertEqual(ConversationUsage.formatTokens(1234), "1.2k")
    }

    func testFormatTokensMillions() {
        XCTAssertEqual(ConversationUsage.formatTokens(1_000_000), "1.0M")
        XCTAssertEqual(ConversationUsage.formatTokens(2_500_000), "2.5M")
    }

    // MARK: - estimatedCost

    func testEstimatedCostZeroTokensNil() {
        XCTAssertNil(ConversationUsage.estimatedCost(model: "gpt-4o", prompt: 0, completion: 0))
    }

    func testEstimatedCostKnownModelPositive() {
        let usd = ConversationUsage.estimatedCost(model: "gpt-4o", prompt: 1_000_000, completion: 0)
        XCTAssertNotNil(usd)
        XCTAssertEqual(usd ?? 0, 2.5, accuracy: 0.0001)
    }

    func testEstimatedCostGenericModelPositive() {
        let usd = ConversationUsage.estimatedCost(model: "modelo-desconocido", prompt: 1_000_000, completion: 1_000_000)
        XCTAssertNotNil(usd)
        XCTAssertEqual(usd ?? 0, 4.0, accuracy: 0.0001)   // genérico 1 + 3
    }

    func testEstimatedCostMatchesUsagePricing() {
        let usd = ConversationUsage.estimatedCost(model: "gpt-4o-mini", prompt: 500_000, completion: 250_000)
        let direct = UsagePricing.costUSD(model: "gpt-4o-mini", promptTokens: 500_000, completionTokens: 250_000, local: false)
        XCTAssertEqual(usd ?? -1, direct, accuracy: 0.000001)
    }
}
