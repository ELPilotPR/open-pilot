import XCTest
@testable import OpenPilot

final class WidgetSnapshotTests: XCTestCase {
    private func chat(_ id: String, _ title: String) -> WidgetChat {
        WidgetChat(id: id, title: title, snippet: "hi", date: Date(timeIntervalSince1970: 100))
    }

    func testRoundTrip() {
        let chats = [chat("a", "Alpha"), chat("b", "Beta")]
        let data = WidgetSnapshot.encode(chats)
        XCTAssertEqual(WidgetSnapshot.decode(data), chats)
    }

    func testDecodeInvalidIsEmpty() {
        XCTAssertEqual(WidgetSnapshot.decode(Data("not json".utf8)), [])
    }

    func testDecodeEmptyDataIsEmpty() {
        XCTAssertEqual(WidgetSnapshot.decode(Data()), [])
    }

    func testEncodeEmpty() {
        XCTAssertEqual(WidgetSnapshot.decode(WidgetSnapshot.encode([])), [])
    }

    func testChatEquality() {
        XCTAssertEqual(chat("a", "Alpha"), chat("a", "Alpha"))
        XCTAssertNotEqual(chat("a", "Alpha"), chat("b", "Alpha"))
    }

    func testAppGroupConstant() {
        XCTAssertEqual(WidgetSnapshot.appGroup, "group.com.openpilot.app")
        XCTAssertFalse(WidgetSnapshot.key.isEmpty)
    }
}