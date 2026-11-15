import XCTest
@testable import OpenPilot

final class SmartFolderTests: XCTestCase {
    private func conv(tags: [String] = [], pinned: Bool = false, temp: Bool = false,
                      texts: [String] = [], images: Int = 0) -> Conversation {
        let c = Conversation(title: "T", providerID: "casa", model: "m")
        c.tags = tags; c.isPinned = pinned; c.isTemporary = temp
        for t in texts { let m = Message(role: "user", text: t); m.conversation = c; c.messages.append(m) }
        for _ in 0..<images { let m = Message(role: "assistant", text: ""); m.imageData = Data([0x1]); m.conversation = c; c.messages.append(m) }
        c.ensureTree(); return c
    }
    func testCodeByTag() {
        XCTAssertTrue(SmartFolder.code.matches(conv(tags: ["code"])))
    }
    func testCodeByFence() {
        XCTAssertTrue(SmartFolder.code.matches(conv(texts: ["mira ```swift\nlet x = 1\n```"])))
    }
    func testImages() {
        XCTAssertTrue(SmartFolder.images.matches(conv(images: 1)))
        XCTAssertFalse(SmartFolder.images.matches(conv(texts: ["hola"])))
    }
    func testLong() {
        let many = (0..<20).map { "m\($0)" }
        XCTAssertTrue(SmartFolder.long.matches(conv(texts: many)))
        XCTAssertFalse(SmartFolder.long.matches(conv(texts: ["uno"])))
    }
    func testPinned() {
        XCTAssertTrue(SmartFolder.pinned.matches(conv(pinned: true)))
    }
    func testUntagged() {
        XCTAssertTrue(SmartFolder.untagged.matches(conv(texts: ["hola"])))
        XCTAssertFalse(SmartFolder.untagged.matches(conv(tags: ["x"], texts: ["hola"])))
    }
    func testTemporaryExcluded() {
        XCTAssertFalse(SmartFolder.pinned.matches(conv(pinned: true, temp: true)))
    }
    func testFilterSorts() {
        let a = conv(tags: ["code"]); let b = conv(tags: ["code"])
        let r = SmartFolder.conversations(in: .code, from: [a, b])
        XCTAssertEqual(r.count, 2)
    }
}