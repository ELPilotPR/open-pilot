import XCTest
@testable import OpenPilot

/// Regresión del parser de límite de contexto desde errores de desborde.
/// Cubre los formatos REALES de DashScope/Qwen, OpenAI, vLLM, LiteLLM, llama.cpp
/// y los casos negativos (cap de max_tokens, errores sin número).
final class ContextProbeParseTests: XCTestCase {
    private let P = ContextWindowDetector.self

    // MARK: - DashScope / Qwen (el server del usuario)

    func testQwenRange1M() {
        XCTAssertEqual(P.parseContextLimit(from: "Range of input length should be [1, 1048576]"), 1_048_576)
    }

    func testQwenRangeGlm() {
        XCTAssertEqual(P.parseContextLimit(from: "Range of input length should be [1, 202745]"), 202_745)
    }

    func testQwenRangeWithSpaces() {
        XCTAssertEqual(P.parseContextLimit(from: "Range of input length should be [1, 991808]"), 991_808)
    }

    func testQwenWrappedInJSONErrorBody() {
        let body = #"{"error":{"message":"<400> InternalError.Algo.InvalidParameter: Range of input length should be [1, 1048576]","type":"invalid_request_error","code":"invalid_parameter_error"}}"#
        XCTAssertEqual(P.parseContextLimit(from: body), 1_048_576)
    }

    // MARK: - OpenAI / vLLM / LiteLLM / OpenAI-compatible

    func testOpenAIMaximumContextLengthIs() {
        let s = "This model's maximum context length is 8192 tokens. However, your messages resulted in 9001 tokens. Please reduce the length of the messages."
        XCTAssertEqual(P.parseContextLimit(from: s), 8192)
    }

    func testVLLMRequestedTokens() {
        let s = "This model's maximum context length is 32768 tokens. However, you requested 33000 tokens (100 in the messages, 32900 in the completion). Please reduce the length."
        XCTAssertEqual(P.parseContextLimit(from: s), 32768)
    }

    func testLiteLLMMaximumContextLengthOf() {
        let s = "Requested token count exceeds the model's maximum context length of 131072 tokens"
        XCTAssertEqual(P.parseContextLimit(from: s), 131072)
    }

    func testOpenAICompatibleParenthesized() {
        let s = "Input length (265330) exceeds model's maximum context length (262144)."
        XCTAssertEqual(P.parseContextLimit(from: s), 262144)
    }

    func testLlamaCppContextSize() {
        let s = "the request exceeds the available context size (8192 tokens)"
        XCTAssertEqual(P.parseContextLimit(from: s), 8192)
    }

    // MARK: - Negativos (no debe inventar un número)

    func testNoNumberReturnsNil() {
        XCTAssertNil(P.parseContextLimit(from: "Your input exceeds the context window of this model"))
    }

    func testMaxTokensOutputCapIsNotContext() {
        // El cap de SALIDA (max_tokens) NO es la ventana de contexto: no debe parsearse.
        XCTAssertNil(P.parseContextLimit(from: "Range of max_tokens should be [1, 8192]"))
    }

    func testAuthErrorReturnsNil() {
        XCTAssertNil(P.parseContextLimit(from: #"{"error":{"message":"Invalid API key","code":"invalid_api_key"}}"#))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(P.parseContextLimit(from: ""))
    }
}