import XCTest
@testable import OpenPilot

/// Catálogo de presets por proveedor y badges de capacidad.
final class ModelCatalogTests: XCTestCase {
    func testOpenAIPresets() {
        let presets = ModelCatalog.presets(for: "https://api.openai.com/v1", kind: "openai")
        XCTAssertFalse(presets.isEmpty)
        XCTAssertTrue(presets.contains { $0.id == "gpt-4o" })
    }

    func testQwenPresetsByHost() {
        let presets = ModelCatalog.presets(for: "https://dashscope.aliyuncs.com/compatible-mode/v1", kind: "openai")
        XCTAssertTrue(presets.contains { $0.id == "qwen-vl-max" })
        XCTAssertTrue(presets.contains { $0.id == "qwq-plus" })
    }

    func testAnthropicPresetsByKind() {
        let presets = ModelCatalog.presets(for: "https://api.anthropic.com", kind: "anthropic")
        XCTAssertTrue(presets.contains { $0.id.hasPrefix("claude") })
    }

    func testUnknownHostReturnsEmpty() {
        XCTAssertTrue(ModelCatalog.presets(for: "http://192.168.1.190:8080/v1", kind: "openai").isEmpty)
    }

    func testVisionBadge() {
        XCTAssertEqual(ModelCatalog.preset(for: "gpt-4o")?.badges.contains("vision"), true)
    }

    func testReasoningBadge() {
        XCTAssertEqual(ModelCatalog.preset(for: "qwq-plus")?.badges.contains("reasoning"), true)
    }

    func testImageGenBadge() {
        XCTAssertEqual(ModelCatalog.preset(for: "wan2.7-image")?.badges.contains("image"), true)
    }

    func testUnknownModelHasNoPreset() {
        XCTAssertNil(ModelCatalog.preset(for: "modelo-inexistente-xyz"))
    }
}
