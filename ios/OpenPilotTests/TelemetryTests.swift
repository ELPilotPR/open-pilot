import XCTest
@testable import OpenPilot

final class TelemetryTests: XCTestCase {
    func testWindowByModel() {
        XCTAssertEqual(ModelContextWindow.window(for: "gpt-4o", kind: "openai"), 128_000)
        XCTAssertEqual(ModelContextWindow.window(for: "gpt-4.1-mini", kind: "openai"), 128_000)
        XCTAssertEqual(ModelContextWindow.window(for: "o3-mini", kind: "openai"), 200_000)
        XCTAssertEqual(ModelContextWindow.window(for: "gpt-3.5-turbo", kind: "openai"), 16_385)
        XCTAssertEqual(ModelContextWindow.window(for: "qwen-max", kind: "openai"), 131_072)
        XCTAssertEqual(ModelContextWindow.window(for: "qwen-long", kind: "openai"), 1_000_000)
        XCTAssertEqual(ModelContextWindow.window(for: "gemini-2.5-pro", kind: "openai"), 1_000_000)
        XCTAssertEqual(ModelContextWindow.window(for: "claude-sonnet-4", kind: "anthropic"), 200_000)
        XCTAssertEqual(ModelContextWindow.window(for: "apple-intelligence", kind: "ondevice"), 4096)
        XCTAssertEqual(ModelContextWindow.window(for: "cualquiera", kind: "ondevice"), 4096)
        XCTAssertEqual(ModelContextWindow.window(for: "mi-modelo", kind: "gguf"), 8192)
        XCTAssertEqual(ModelContextWindow.window(for: "swift-iq3_s", kind: "openai"), 32_768)
    }
    func testGaugeFractionAndTier() {
        let g = ContextGauge.make(used: 8000, window: 32000)
        XCTAssertEqual(g.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(g.percent, 25)
        XCTAssertEqual(g.tier, 0)
    }
    func testGaugeMidTier() {
        let g = ContextGauge.make(used: 20000, window: 32000) // 62.5 → 63
        XCTAssertEqual(g.percent, 63)
        XCTAssertEqual(g.tier, 1)
    }
    func testGaugeFullTier() {
        let g = ContextGauge.make(used: 28000, window: 32000) // 87.5 → 88
        XCTAssertEqual(g.percent, 88)
        XCTAssertEqual(g.tier, 2)
    }
    func testGaugeClampsOverWindow() {
        let g = ContextGauge.make(used: 999999, window: 32000)
        XCTAssertEqual(g.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(g.percent, 100)
        XCTAssertEqual(g.tier, 2)
    }
    func testGaugeZeroWindowSafe() {
        let g = ContextGauge.make(used: 100, window: 0)
        XCTAssertEqual(g.window, 1)
        XCTAssertEqual(g.percent, 100)
    }
    func testTPS() {
        XCTAssertEqual(LiveSpeed.tps(tokens: 100, elapsed: 2), 50, accuracy: 0.0001)
        XCTAssertEqual(LiveSpeed.tps(tokens: 0, elapsed: 2), 0)
        XCTAssertEqual(LiveSpeed.tps(tokens: 100, elapsed: 0), 0)
        XCTAssertEqual(LiveSpeed.tps(tokens: 100, elapsed: 0.01), 0)
    }
    func testTPSLabel() {
        XCTAssertEqual(LiveSpeed.label(12.34), "12.3 tok/s")
        XCTAssertEqual(LiveSpeed.label(150), "150 tok/s")
        XCTAssertEqual(LiveSpeed.label(0), "0.0 tok/s")
    }
    func testEstimateTokens() {
        XCTAssertEqual(LiveSpeed.estimateTokens("abcdabcd"), 2)
        XCTAssertEqual(LiveSpeed.estimateTokens(""), 0)
    }
    func testTokenFormat() {
        XCTAssertEqual(TokenFormat.short(512), "512")
        XCTAssertEqual(TokenFormat.short(1000), "1k")
        XCTAssertEqual(TokenFormat.short(8200), "8.2k")
        XCTAssertEqual(TokenFormat.short(128000), "128k")
        XCTAssertEqual(TokenFormat.short(16385), "16.4k")
        XCTAssertEqual(TokenFormat.short(1_000_000), "1M")
        XCTAssertEqual(TokenFormat.short(1_500_000), "1.5M")
    }
}
