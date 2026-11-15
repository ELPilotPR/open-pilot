import XCTest
@testable import OpenPilot

final class ProviderDiscoveryTests: XCTestCase {
    // MARK: - ModelCatalog: detección de presets por host

    func testPresetDetectionGemini() {
        let p = ModelCatalog.presets(for: "https://generativelanguage.googleapis.com/v1beta/openai", kind: "openai")
        XCTAssertTrue(p.contains { $0.id == "gemini-2.5-pro" })
    }

    func testPresetDetectionGroq() {
        let p = ModelCatalog.presets(for: "https://api.groq.com/openai/v1", kind: "openai")
        XCTAssertTrue(p.contains { $0.id == "llama-3.3-70b-versatile" })
    }

    func testPresetDetectionMistral() {
        let p = ModelCatalog.presets(for: "https://api.mistral.ai/v1", kind: "openai")
        XCTAssertTrue(p.contains { $0.id == "pixtral-large-latest" })
    }

    func testPresetDetectionOpenRouter() {
        let p = ModelCatalog.presets(for: "https://openrouter.ai/api/v1", kind: "openai")
        XCTAssertTrue(p.contains { $0.id == "openai/gpt-4o" })
    }

    func testPresetDetectionOllama() {
        let p = ModelCatalog.presets(for: "http://192.168.1.50:11434/v1", kind: "openai")
        XCTAssertTrue(p.contains { $0.id == "llama3.2" })
    }

    func testPresetLookupNewIDs() {
        XCTAssertEqual(ModelCatalog.preset(for: "gemini-2.5-flash")?.vision, true)
        XCTAssertEqual(ModelCatalog.preset(for: "pixtral-large-latest")?.vision, true)
        XCTAssertEqual(ModelCatalog.preset(for: "deepseek-r1-distill-llama-70b")?.reasoning, true)
    }

    // MARK: - LocalServerDiscovery: helpers puros

    func testSubnetPrefixValid() {
        XCTAssertEqual(LocalServerDiscovery.subnetPrefix(ofIPv4: "192.168.1.42"), "192.168.1")
        XCTAssertEqual(LocalServerDiscovery.subnetPrefix(ofIPv4: "10.0.0.7"), "10.0.0")
    }

    func testSubnetPrefixInvalid() {
        XCTAssertNil(LocalServerDiscovery.subnetPrefix(ofIPv4: "abc"))
        XCTAssertNil(LocalServerDiscovery.subnetPrefix(ofIPv4: "1.2.3"))
        XCTAssertNil(LocalServerDiscovery.subnetPrefix(ofIPv4: "::1"))
        XCTAssertNil(LocalServerDiscovery.subnetPrefix(ofIPv4: "1.2.3.4.5"))
    }

    func testCandidates() {
        let c = LocalServerDiscovery.candidates(subnet: "10.0.0", hosts: 1...2)
        XCTAssertEqual(c.count, 4)
        XCTAssertTrue(c.contains("http://10.0.0.1:11434/v1"))
        XCTAssertTrue(c.contains("http://10.0.0.1:1234/v1"))
        XCTAssertTrue(c.contains("http://10.0.0.2:11434/v1"))
        XCTAssertTrue(c.contains("http://10.0.0.2:1234/v1"))
    }

    func testServerNameAndInfo() {
        XCTAssertEqual(LocalServerDiscovery.serverName(port: 11434), "Ollama")
        XCTAssertEqual(LocalServerDiscovery.serverName(port: 1234), "LM Studio")
        XCTAssertEqual(LocalServerDiscovery.serverName(port: 9999), "Server")
        XCTAssertEqual(LocalServerDiscovery.info(forBaseURL: "http://1.2.3.4:11434/v1")?.name, "Ollama")
        XCTAssertEqual(LocalServerDiscovery.info(forBaseURL: "http://1.2.3.4:1234/v1")?.port, 1234)
        XCTAssertNil(LocalServerDiscovery.info(forBaseURL: "not a url"))
    }
}