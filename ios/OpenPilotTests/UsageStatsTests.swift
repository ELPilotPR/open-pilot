import XCTest
@testable import OpenPilot

final class UsageStatsTests: XCTestCase {
    func testRateGPT4o() {
        XCTAssertEqual(UsagePricing.rate(for: "gpt-4o"), ModelRate(inputPerMillion: 2.5, outputPerMillion: 10))
    }
    func testRateMiniCheaperThanFull() {
        XCTAssertLessThan(UsagePricing.rate(for: "gpt-4o-mini").inputPerMillion,
                          UsagePricing.rate(for: "gpt-4o").inputPerMillion)
    }
    func testRateOnDeviceZero() {
        XCTAssertEqual(UsagePricing.rate(for: "apple-intelligence"), .zero)
    }
    func testCostComputation() {
        // 1M prompt + 1M completion de gpt-4o = 2.5 + 10 = 12.5
        let c = UsagePricing.costUSD(model: "gpt-4o", promptTokens: 1_000_000, completionTokens: 1_000_000)
        XCTAssertEqual(c, 12.5, accuracy: 0.0001)
    }
    func testCostLocalZero() {
        XCTAssertEqual(UsagePricing.costUSD(model: "gpt-4o", promptTokens: 1_000_000, completionTokens: 1_000_000, local: true), 0)
    }
    func testIsLocalOnDevice() {
        XCTAssertTrue(UsagePricing.isLocal(kind: "ondevice", baseURL: ""))
    }
    func testIsLocalLAN() {
        XCTAssertTrue(UsagePricing.isLocal(kind: "openai", baseURL: "http://192.168.1.50:11434/v1"))
        XCTAssertTrue(UsagePricing.isLocal(kind: "openai", baseURL: "http://localhost:1234/v1"))
    }
    func testIsLocalCloudFalse() {
        XCTAssertFalse(UsagePricing.isLocal(kind: "openai", baseURL: "https://api.openai.com/v1"))
    }

    private func sample(_ prov: String, _ model: String, p: Int, c: Int, local: Bool = false, daysAgo: Int = 0) -> UsageSample {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return UsageSample(providerID: prov, providerName: prov, model: model,
                           promptTokens: p, completionTokens: c, date: date, local: local)
    }

    func testSummarizeTotals() {
        let s = UsageStats.summarize([sample("a", "gpt-4o", p: 100, c: 200),
                                      sample("a", "gpt-4o", p: 50, c: 50)])
        XCTAssertEqual(s.totalPrompt, 150)
        XCTAssertEqual(s.totalCompletion, 250)
        XCTAssertEqual(s.totalTokens, 400)
        XCTAssertEqual(s.messageCount, 2)
        XCTAssertEqual(s.byProvider.count, 1)
        XCTAssertEqual(s.byProvider[0].messages, 2)
    }
    func testSummarizeByProviderSortedByCost() {
        let s = UsageStats.summarize([sample("cheap", "gpt-4o-mini", p: 1_000_000, c: 0),
                                      sample("pricey", "gpt-4o", p: 1_000_000, c: 0)])
        XCTAssertEqual(s.byProvider.first?.providerID, "pricey")
    }
    func testSummarizeLocalCostZero() {
        let s = UsageStats.summarize([sample("local", "llama3", p: 1_000_000, c: 1_000_000, local: true)])
        XCTAssertEqual(s.totalCost, 0)
        XCTAssertEqual(s.totalTokens, 2_000_000)
    }
    func testSummarizeByDayCount() {
        let s = UsageStats.summarize([sample("a", "gpt-4o", p: 10, c: 10)], days: 14)
        XCTAssertEqual(s.byDay.count, 14)
        XCTAssertEqual(s.byDay.last?.tokens, 20)   // hoy
    }
    func testSummarizeEmpty() {
        let s = UsageStats.summarize([])
        XCTAssertEqual(s.totalTokens, 0)
        XCTAssertEqual(s.totalCost, 0)
        XCTAssertTrue(s.byProvider.isEmpty)
    }
}