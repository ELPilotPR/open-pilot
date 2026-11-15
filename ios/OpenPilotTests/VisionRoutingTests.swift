import XCTest
@testable import OpenPilot

final class VisionRoutingTests: XCTestCase {
    func testVisionModels() {
        XCTAssertTrue(VisionRouting.isVisionCapable("gpt-4o"))
        XCTAssertTrue(VisionRouting.isVisionCapable("gpt-4o-mini"))
        XCTAssertTrue(VisionRouting.isVisionCapable("claude-3-5-sonnet-latest"))
        XCTAssertTrue(VisionRouting.isVisionCapable("qwen-vl-max"))
        XCTAssertTrue(VisionRouting.isVisionCapable("gemini-1.5-pro"))
        XCTAssertTrue(VisionRouting.isVisionCapable("llava:13b"))
    }
    func testTextOnlyModels() {
        XCTAssertFalse(VisionRouting.isVisionCapable("gpt-3.5-turbo"))
        XCTAssertFalse(VisionRouting.isVisionCapable("text-embedding-3-small"))
        XCTAssertFalse(VisionRouting.isVisionCapable("dall-e-3"))
        XCTAssertFalse(VisionRouting.isVisionCapable(""))
    }
    func testLocalDetection() {
        XCTAssertTrue(VisionRouting.isLocal("http://192.168.1.190:8080/v1"))
        XCTAssertTrue(VisionRouting.isLocal("http://localhost:11434/v1"))
        XCTAssertFalse(VisionRouting.isLocal("https://api.openai.com/v1"))
    }
    func testNoImageKeepsModel() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "gpt-3.5-turbo", hasImage: false,
                                                    kind: "openai", baseURL: "https://api.openai.com/v1"),
                       "gpt-3.5-turbo")
    }
    func testRoutesTextOnlyToVision() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "gpt-3.5-turbo", hasImage: true,
                                                    kind: "openai", baseURL: "https://api.openai.com/v1"),
                       "gpt-4o-mini")
    }
    func testKeepsVisionModel() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "gpt-4o", hasImage: true,
                                                    kind: "openai", baseURL: "https://api.openai.com/v1"),
                       "gpt-4o")
    }
    func testAnthropicDefault() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "claude-instant", hasImage: true,
                                                    kind: "anthropic", baseURL: "https://api.anthropic.com"),
                       "claude-3-5-sonnet-latest")
    }
    func testLocalNotRouted() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "swift-iq3_s", hasImage: true,
                                                    kind: "openai", baseURL: "http://192.168.1.190:8080/v1"),
                       "swift-iq3_s")
    }
    func testOnDeviceNotRouted() {
        XCTAssertEqual(VisionRouting.effectiveModel(current: "apple-intelligence", hasImage: true,
                                                    kind: "ondevice", baseURL: ""),
                       "apple-intelligence")
    }
}