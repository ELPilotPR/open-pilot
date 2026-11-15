import XCTest
@testable import OpenPilot

final class KeyboardTests: XCTestCase {
    private func provider(key: String = "sk-test") -> KeyboardProvider {
        KeyboardProvider(kind: "openai", baseURL: "http://localhost:8080/v1/", apiKey: key, model: "m", name: "n")
    }

    func testProviderRoundTrip() {
        let p = provider()
        XCTAssertEqual(KeyboardShared.decode(KeyboardShared.encode(p)), p)
    }

    func testDecodeInvalidNil() {
        XCTAssertNil(KeyboardShared.decode(Data("nope".utf8)))
    }

    func testTrimBase() {
        XCTAssertEqual(KeyboardChat.trimBase("  http://x/v1/// "), "http://x/v1")
    }

    func testRequestURL() {
        let req = KeyboardChat.request(provider: provider(), prompt: "hi")
        XCTAssertEqual(req?.url?.absoluteString, "http://localhost:8080/v1/chat/completions")
        XCTAssertEqual(req?.httpMethod, "POST")
    }

    func testRequestAuthHeader() {
        let withKey = KeyboardChat.request(provider: provider(key: "sk-abc"), prompt: "hi")
        XCTAssertEqual(withKey?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-abc")
        let noKey = KeyboardChat.request(provider: provider(key: ""), prompt: "hi")
        XCTAssertNil(noKey?.value(forHTTPHeaderField: "Authorization"))
    }

    func testRequestBody() throws {
        let req = KeyboardChat.request(provider: provider(), prompt: "hello")
        let body = try XCTUnwrap(req?.httpBody)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(obj["model"] as? String, "m")
        XCTAssertEqual(obj["stream"] as? Bool, false)
        let msgs = try XCTUnwrap(obj["messages"] as? [[String: Any]])
        XCTAssertEqual(msgs.first?["content"] as? String, "hello")
    }

    func testParseResponse() {
        let json = #"{"choices":[{"message":{"role":"assistant","content":"Paris."}}]}"#
        XCTAssertEqual(KeyboardChat.parseResponse(Data(json.utf8)), "Paris.")
    }

    func testParseResponseInvalid() {
        XCTAssertNil(KeyboardChat.parseResponse(Data("{}".utf8)))
        XCTAssertNil(KeyboardChat.parseResponse(Data(#"{"choices":[]}"#.utf8)))
    }

    func testRequestEmptyBaseNil() {
        let p = KeyboardProvider(kind: "openai", baseURL: "  ", apiKey: "", model: "m", name: "n")
        XCTAssertNil(KeyboardChat.request(provider: p, prompt: "hi"))
    }
}