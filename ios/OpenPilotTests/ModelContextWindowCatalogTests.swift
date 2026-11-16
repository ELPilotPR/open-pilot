import XCTest
@testable import OpenPilot

/// Catálogo de ventana de contexto por modelo (1.0.1): los Qwen modernos de
/// 1M se detectan solos por nombre; no se rompen los valores clásicos.
final class ModelContextWindowCatalogTests: XCTestCase {

    private let M = ModelContextWindow.self

    // MARK: - Qwen modernos = 1M (los del token plan del usuario)

    func testQwen4MaxIs1M() {
        XCTAssertEqual(M.window(for: "qwen4-max", kind: "openai"), 1_000_000)
    }

    func testQwen4MaxPreviewIs1M() {
        XCTAssertEqual(M.window(for: "qwen4-max-preview", kind: "openai"), 1_000_000)
    }

    func testQwen37MaxIs1M() {
        XCTAssertEqual(M.window(for: "qwen3.7-max", kind: "openai"), 1_000_000)
    }

    func testQwen37PlusIs1M() {
        XCTAssertEqual(M.window(for: "qwen3.7-plus", kind: "openai"), 1_000_000)
    }

    func testQwen36FlashIs1M() {
        XCTAssertEqual(M.window(for: "qwen3.6-flash", kind: "openai"), 1_000_000)
    }

    func testQwen38MaxAndFlashAre1M() {
        XCTAssertEqual(M.window(for: "qwen3.8-max", kind: "openai"), 1_000_000)
        XCTAssertEqual(M.window(for: "qwen3.8-flash", kind: "openai"), 1_000_000)
    }

    func testQwen3CoderPlusFlashAre1M() {
        XCTAssertEqual(M.window(for: "qwen3-coder-plus", kind: "openai"), 1_000_000)
        XCTAssertEqual(M.window(for: "qwen3-coder-flash", kind: "openai"), 1_000_000)
    }

    func testModernPlusFlashTurboAre1M() {
        XCTAssertEqual(M.window(for: "qwen-plus", kind: "openai"), 1_000_000)
        XCTAssertEqual(M.window(for: "qwen-flash", kind: "openai"), 1_000_000)
        XCTAssertEqual(M.window(for: "qwen-turbo", kind: "openai"), 1_000_000)
    }

    // MARK: - No regresión de los valores clásicos

    func testQwen3MaxStays256k() {
        XCTAssertEqual(M.window(for: "qwen3-max", kind: "openai"), 262_144)
    }

    func testQwen3DenseStays256k() {
        XCTAssertEqual(M.window(for: "qwen3-235b", kind: "openai"), 262_144)
    }

    func testQwen25NotCaughtByDottedRule() {
        // qwen2.5 NO debe disparar la regla de versiones con punto (esa es ≥3).
        XCTAssertEqual(M.window(for: "qwen2.5-72b-instruct", kind: "openai"), 131_072)
    }

    func testLegacyQwenMaxStays128k() {
        XCTAssertEqual(M.window(for: "qwen-max", kind: "openai"), 131_072)
    }

    func testQwenLongStays1M() {
        XCTAssertEqual(M.window(for: "qwen-long", kind: "openai"), 1_000_000)
    }

    // MARK: - Otras familias del provider del usuario

    func testDeepseekV4Is128k() {
        XCTAssertEqual(M.window(for: "deepseek-v4-pro", kind: "openai"), 128_000)
        XCTAssertEqual(M.window(for: "deepseek-v4.1-flash", kind: "openai"), 128_000)
    }

    func testDeepseekChatStays64k() {
        XCTAssertEqual(M.window(for: "deepseek-chat", kind: "openai"), 65_536)
    }

    func testGlmIs200k() {
        XCTAssertEqual(M.window(for: "glm-5.2", kind: "openai"), 200_000)
        XCTAssertEqual(M.window(for: "glm-5.3", kind: "openai"), 200_000)
    }

    // MARK: - Prioridad de resolución y presupuesto

    func testResolvePriorityOverrideThenDetectedThenCatalog() {
        XCTAssertEqual(M.resolve(model: "qwen4-max", kind: "openai", override: 512_000, detected: 8_192), 512_000)
        XCTAssertEqual(M.resolve(model: "qwen4-max", kind: "openai", override: 0, detected: 262_144), 262_144)
        XCTAssertEqual(M.resolve(model: "qwen4-max", kind: "openai", override: 0, detected: 0), 1_000_000)
    }

    func testBudgetScalesWith1MWindow() {
        // Auto-compaction budget ~70% de la ventana: con 1M debe ser ~700k, no 91k.
        XCTAssertEqual(ContextManager.effectiveBudget(window: 1_000_000, manual: 0), 700_000)
    }
}