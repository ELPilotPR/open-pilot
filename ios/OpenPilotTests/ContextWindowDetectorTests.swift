import XCTest
@testable import OpenPilot

final class ContextWindowDetectorTests: XCTestCase {

    // MARK: - /v1/models

    func testModelsMetaNCtx() {
        let json = #"{"object":"list","data":[{"id":"m","meta":{"n_ctx":512000}}]}"#
        XCTAssertEqual(ContextWindowDetector.fromModelsJSON(Data(json.utf8), model: "m"), 512000)
    }

    func testModelsFlatContextLength() {
        let json = #"{"data":[{"id":"qwen","context_length":262144}]}"#
        XCTAssertEqual(ContextWindowDetector.fromModelsJSON(Data(json.utf8), model: "qwen"), 262144)
    }

    func testModelsMatchesSpecificID() {
        let json = #"{"data":[{"id":"a","context_length":8192},{"id":"b","max_model_len":131072}]}"#
        XCTAssertEqual(ContextWindowDetector.fromModelsJSON(Data(json.utf8), model: "b"), 131072)
    }

    func testModelsStrataNoContextReturnsNil() {
        // Forma real del servidor Strata de casa: meta sin contexto.
        let json = #"{"object":"list","data":[{"id":"swift-iq3_s","owned_by":"strata","meta":{"label":"Swift 1.5 IQ3_S","gpus":[1,2,0]}}]}"#
        XCTAssertNil(ContextWindowDetector.fromModelsJSON(Data(json.utf8), model: "swift-iq3_s"))
    }

    func testModelsNumericString() {
        let json = #"{"data":[{"id":"m","context_length":"32768"}]}"#
        XCTAssertEqual(ContextWindowDetector.fromModelsJSON(Data(json.utf8), model: "m"), 32768)
    }

    func testDetailModelObjectContextValue() {
        // Forma de /v1/models/{id}: objeto plano (sin envolver en "data").
        let obj: [String: Any] = ["id": "swift-iq3_s", "context_length": 512000]
        XCTAssertEqual(ContextWindowDetector.contextValue(from: obj), 512000)
        let meta: [String: Any] = ["id": "m", "meta": ["max_model_len": 262144]]
        XCTAssertEqual(ContextWindowDetector.contextValue(from: meta), 262144)
        XCTAssertNil(ContextWindowDetector.contextValue(from: ["id": "m", "label": "x"]))
    }

    // MARK: - llama.cpp /props

    func testPropsDefaultGenerationSettings() {
        let json = #"{"default_generation_settings":{"n_ctx":8192,"seed":1}}"#
        XCTAssertEqual(ContextWindowDetector.fromPropsJSON(Data(json.utf8)), 8192)
    }

    func testPropsTopLevelNCtx() {
        XCTAssertEqual(ContextWindowDetector.fromPropsJSON(Data(#"{"n_ctx":4096}"#.utf8)), 4096)
    }

    // MARK: - Ollama /api/show

    func testOllamaShowContextLength() {
        let json = #"{"model_info":{"general.architecture":"llama","llama.context_length":131072}}"#
        XCTAssertEqual(ContextWindowDetector.fromOllamaShowJSON(Data(json.utf8)), 131072)
    }

    func testOllamaShowNoContextReturnsNil() {
        XCTAssertNil(ContextWindowDetector.fromOllamaShowJSON(Data(#"{"model_info":{"general.architecture":"llama"}}"#.utf8)))
    }

    // MARK: - Resolución (override > detectada > heurística)

    func testResolveOverrideWins() {
        XCTAssertEqual(ModelContextWindow.resolve(model: "swift-iq3_s", kind: "openai", override: 512000, detected: 8192), 512000)
    }

    func testResolveDetectedWhenNoOverride() {
        XCTAssertEqual(ModelContextWindow.resolve(model: "swift-iq3_s", kind: "openai", override: 0, detected: 262144), 262144)
    }

    func testResolveFallsBackToHeuristic() {
        XCTAssertEqual(ModelContextWindow.resolve(model: "swift-iq3_s", kind: "openai", override: 0, detected: 0), 32768)
        XCTAssertEqual(ModelContextWindow.resolve(model: "qwen3-max", kind: "openai", override: 0, detected: 0), 262144)
    }

    func testHeuristicQwen3() {
        XCTAssertEqual(ModelContextWindow.window(for: "qwen3-235b", kind: "openai"), 262144)
        XCTAssertEqual(ModelContextWindow.window(for: "deepseek-chat", kind: "openai"), 65536)
    }
}