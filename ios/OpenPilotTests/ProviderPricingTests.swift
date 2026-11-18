import XCTest
@testable import OpenPilot

/// Precio por proveedor: resolve manual/auto, cache OpenRouter, parseo y override
/// del coste. Todo puro (sin red ni SwiftData) para ser determinista.
final class ProviderPricingTests: XCTestCase {

    // MARK: resolve

    func testResolveDisabledReturnsNil() {
        XCTAssertNil(ProviderPricing.resolve(enabled: false, mode: "manual", manualIn: 5, manualOut: 9, autoJSON: "", model: "gpt-4o"))
    }

    func testResolveManualRates() {
        let r = ProviderPricing.resolve(enabled: true, mode: "manual", manualIn: 1.6, manualOut: 6.4, autoJSON: "", model: "qwen-max")
        XCTAssertEqual(r, ModelRate(inputPerMillion: 1.6, outputPerMillion: 6.4))
    }

    func testResolveManualZeroReturnsNil() {
        XCTAssertNil(ProviderPricing.resolve(enabled: true, mode: "manual", manualIn: 0, manualOut: 0, autoJSON: "", model: "x"))
    }

    func testResolveAutoExactMatch() {
        let json = ProviderPricing.encodeAuto(["openai/gpt-4o": ModelRate(inputPerMillion: 2.5, outputPerMillion: 10)])
        let r = ProviderPricing.resolve(enabled: true, mode: "auto", manualIn: 0, manualOut: 0, autoJSON: json, model: "openai/gpt-4o")
        XCTAssertEqual(r, ModelRate(inputPerMillion: 2.5, outputPerMillion: 10))
    }

    func testResolveAutoSubstringMatch() {
        let json = ProviderPricing.encodeAuto(["gpt-4o": ModelRate(inputPerMillion: 2.5, outputPerMillion: 10)])
        let r = ProviderPricing.resolve(enabled: true, mode: "auto", manualIn: 0, manualOut: 0, autoJSON: json, model: "openai/gpt-4o-2024")
        XCTAssertEqual(r?.inputPerMillion, 2.5)
    }

    func testResolveAutoMissingReturnsNil() {
        let json = ProviderPricing.encodeAuto(["claude": ModelRate(inputPerMillion: 3, outputPerMillion: 15)])
        XCTAssertNil(ProviderPricing.resolve(enabled: true, mode: "auto", manualIn: 0, manualOut: 0, autoJSON: json, model: "gpt-4o"))
    }

    // MARK: cache encode/decode

    func testEncodeDecodeRoundTrip() {
        let rates = ["a": ModelRate(inputPerMillion: 1, outputPerMillion: 2),
                     "b": ModelRate(inputPerMillion: 0.5, outputPerMillion: 1.5)]
        let json = ProviderPricing.encodeAuto(rates)
        XCTAssertEqual(ProviderPricing.decodeAuto(json, model: "a"), rates["a"])
        XCTAssertEqual(ProviderPricing.decodeAuto(json, model: "b"), rates["b"])
    }

    func testDecodeAutoEmptyReturnsNil() {
        XCTAssertNil(ProviderPricing.decodeAuto("", model: "a"))
        XCTAssertNil(ProviderPricing.decodeAuto("not json", model: "a"))
    }

    // MARK: parseOpenRouter

    func testParseOpenRouterStringPricing() {
        let json = #"{"data":[{"id":"openai/gpt-4o","pricing":{"prompt":"0.0000025","completion":"0.00001"}}]}"#
        let rates = ProviderPricing.parseOpenRouter(Data(json.utf8))
        XCTAssertEqual(rates["openai/gpt-4o"], ModelRate(inputPerMillion: 2.5, outputPerMillion: 10))
    }

    func testParseOpenRouterNumericPricing() {
        let json = #"{"data":[{"id":"m","pricing":{"prompt":0.000001,"completion":0.000003}}]}"#
        let rates = ProviderPricing.parseOpenRouter(Data(json.utf8))
        XCTAssertEqual(rates["m"], ModelRate(inputPerMillion: 1, outputPerMillion: 3))
    }

    func testParseOpenRouterSkipsFree() {
        let json = #"{"data":[{"id":"free","pricing":{"prompt":"0","completion":"0"}},{"id":"paid","pricing":{"prompt":"0.000001","completion":"0"}}]}"#
        let rates = ProviderPricing.parseOpenRouter(Data(json.utf8))
        XCTAssertNil(rates["free"])
        XCTAssertEqual(rates["paid"]?.inputPerMillion, 1)
    }

    func testParseOpenRouterBadJSONEmpty() {
        XCTAssertTrue(ProviderPricing.parseOpenRouter(Data("{}".utf8)).isEmpty)
        XCTAssertTrue(ProviderPricing.parseOpenRouter(Data("nope".utf8)).isEmpty)
    }

    func testPerMillionVariants() {
        XCTAssertEqual(ProviderPricing.perMillion("0.000002"), 2)
        XCTAssertEqual(ProviderPricing.perMillion(0.000002 as Double), 2)
        XCTAssertEqual(ProviderPricing.perMillion(nil), 0)
        XCTAssertEqual(ProviderPricing.perMillion("abc"), 0)
    }

    // MARK: override del coste

    func testCostUSDOverrideWinsOverTable() {
        // gpt-4o-mini tabla = 0.15/0.6; override 5/9 debe ganar.
        let usd = UsagePricing.costUSD(model: "gpt-4o-mini", promptTokens: 1_000_000, completionTokens: 1_000_000,
                                       override: ModelRate(inputPerMillion: 5, outputPerMillion: 9))
        XCTAssertEqual(usd, 14, accuracy: 1e-9)
    }

    func testCostUSDLocalStillZeroWithOverride() {
        let usd = UsagePricing.costUSD(model: "gpt-4o", promptTokens: 1_000_000, completionTokens: 1_000_000,
                                       local: true, override: ModelRate(inputPerMillion: 5, outputPerMillion: 9))
        XCTAssertEqual(usd, 0)
    }

    func testEstimatedCostOverride() {
        let usd = ConversationUsage.estimatedCost(model: "unknown-xyz", prompt: 1_000_000, completion: 1_000_000,
                                                  override: ModelRate(inputPerMillion: 2, outputPerMillion: 8))
        XCTAssertEqual(usd ?? 0, 10, accuracy: 1e-9)
    }

    func testSummarizeUsesOverride() {
        let s = UsageSample(providerID: "p", providerName: "P", model: "unknown-xyz",
                            promptTokens: 1_000_000, completionTokens: 1_000_000,
                            date: Date(), local: false, override: ModelRate(inputPerMillion: 2, outputPerMillion: 8))
        let summary = UsageStats.summarize([s])
        XCTAssertEqual(summary.totalCost, 10, accuracy: 1e-9)
    }
}
