import XCTest
@testable import OpenPilot

final class ShareInboxTests: XCTestCase {
    private func item(_ kind: SharedItem.Kind, text: String = "", url: String = "",
                      note: String = "", image: Data = Data()) -> SharedItem {
        SharedItem(kind: kind, text: text, url: url, imageData: image, note: note,
                   date: Date(timeIntervalSince1970: 1000))
    }

    func testCodableRoundTrip() throws {
        let it = item(.url, text: "t", url: "https://x.com", note: "n", image: Data([1, 2, 3]))
        let data = try JSONEncoder().encode(it)
        let back = try JSONDecoder().decode(SharedItem.self, from: data)
        XCTAssertEqual(it, back)
    }

    func testMessageTextURLWithNote() {
        let it = item(.url, url: "https://x.com", note: "lee esto")
        XCTAssertEqual(ShareInbox.messageText(for: it), "lee esto\n\nhttps://x.com")
    }

    func testMessageTextPlain() {
        let it = item(.text, text: "hola mundo")
        XCTAssertEqual(ShareInbox.messageText(for: it), "hola mundo")
    }

    func testMessageTextImageUsesNoteOnly() {
        let it = item(.image, note: "describe la foto", image: Data([9]))
        XCTAssertEqual(ShareInbox.messageText(for: it), "describe la foto")
    }

    func testTitleTruncatesTo40() {
        let long = String(repeating: "a", count: 80)
        let it = item(.text, text: long)
        XCTAssertEqual(ShareInbox.title(for: it).count, 40)
    }

    func testTitleEmptyFallback() {
        XCTAssertEqual(ShareInbox.title(for: item(.image)), "Imagen compartida")
        XCTAssertEqual(ShareInbox.title(for: item(.text)), "Compartido")
    }

    func testPutTakeRoundTrip() {
        let it = item(.text, text: "round-trip-\(UUID().uuidString)")
        ShareInbox.put(it)
        XCTAssertTrue(ShareInbox.hasPending)
        let back = ShareInbox.take()
        XCTAssertEqual(back?.text, it.text)
        XCTAssertFalse(ShareInbox.hasPending)
        XCTAssertNil(ShareInbox.take())
    }
}
