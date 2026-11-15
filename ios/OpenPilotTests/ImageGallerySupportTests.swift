import XCTest
@testable import OpenPilot

final class ImageGallerySupportTests: XCTestCase {
    private func conv(_ title: String, temp: Bool = false, imgs: [(Date, Data)] = []) -> Conversation {
        let c = Conversation(title: title, providerID: "casa", model: "m")
        c.isTemporary = temp
        for (d, data) in imgs {
            let m = Message(role: "assistant", text: "")
            m.imageData = data; m.createdAt = d; m.conversation = c; c.messages.append(m)
        }
        c.ensureTree(); return c
    }
    func testCollectsImages() {
        let c = conv("A", imgs: [(Date(), Data([1]))])
        XCTAssertEqual(ImageGallerySupport.collect(from: [c]).count, 1)
    }
    func testSkipsEmptyImageData() {
        let c = conv("A", imgs: [(Date(), Data())])
        XCTAssertTrue(ImageGallerySupport.collect(from: [c]).isEmpty)
    }
    func testSkipsTemporary() {
        let c = conv("A", temp: true, imgs: [(Date(), Data([1]))])
        XCTAssertTrue(ImageGallerySupport.collect(from: [c]).isEmpty)
    }
    func testSortsNewestFirst() {
        let c = conv("A", imgs: [(Date(timeIntervalSince1970: 1000), Data([1])),
                                 (Date(timeIntervalSince1970: 2000), Data([2]))])
        XCTAssertEqual(ImageGallerySupport.collect(from: [c]).first?.data, Data([2]))
    }
    func testTitleCarried() {
        let c = conv("Mi chat", imgs: [(Date(), Data([1]))])
        XCTAssertEqual(ImageGallerySupport.collect(from: [c]).first?.title, "Mi chat")
    }
    func testEmpty() { XCTAssertTrue(ImageGallerySupport.collect(from: []).isEmpty) }
}