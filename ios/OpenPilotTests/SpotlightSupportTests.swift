import XCTest
import CoreSpotlight
@testable import OpenPilot

final class SpotlightSupportTests: XCTestCase {
    private func conv(title: String = "Hola", tags: [String] = [], text: String = "contenido") -> Conversation {
        let c = Conversation(title: title, providerID: "casa", model: "m")
        c.tags = tags
        let m = Message(role: "user", text: text); m.conversation = c; c.messages.append(m)
        c.ensureTree(); return c
    }
    func testIdentifier() {
        let id = UUID()
        XCTAssertEqual(SpotlightSupport.identifier(id), id.uuidString)
    }
    func testConversationIDValid() {
        let id = UUID()
        let a = NSUserActivity(activityType: CSSearchableItemActionType)
        a.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]
        XCTAssertEqual(SpotlightSupport.conversationID(from: a), id)
    }
    func testConversationIDWrongType() {
        let a = NSUserActivity(activityType: "com.other")
        a.userInfo = [CSSearchableItemActivityIdentifier: UUID().uuidString]
        XCTAssertNil(SpotlightSupport.conversationID(from: a))
    }
    func testConversationIDInvalid() {
        let a = NSUserActivity(activityType: CSSearchableItemActionType)
        a.userInfo = [CSSearchableItemActivityIdentifier: "not-a-uuid"]
        XCTAssertNil(SpotlightSupport.conversationID(from: a))
    }
    func testHandleSetsPending() {
        let id = UUID()
        let a = NSUserActivity(activityType: CSSearchableItemActionType)
        a.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]
        SpotlightSupport.handle(a)
        XCTAssertEqual(SpotlightSupport.pendingID, id)
        SpotlightSupport.pendingID = nil
    }
    func testAttributeSetTitle() {
        XCTAssertEqual(SpotlightSupport.attributeSet(for: conv(title: "Mi chat")).title, "Mi chat")
    }
    func testAttributeSetTitleEmpty() {
        XCTAssertEqual(SpotlightSupport.attributeSet(for: conv(title: "")).title, "New chat")
    }
    func testAttributeSetKeywords() {
        let a = SpotlightSupport.attributeSet(for: conv(tags: ["code", "swift"]))
        XCTAssertEqual(a.keywords, ["code", "swift"])
    }
    func testSnippetTruncation() {
        let s = SpotlightSupport.snippet(conv(text: String(repeating: "x", count: 500)), max: 200)
        XCTAssertLessThanOrEqual(s.count, 201)
    }
    func testItemIdentifier() {
        let c = conv()
        XCTAssertEqual(SpotlightSupport.item(for: c).uniqueIdentifier, c.id.uuidString)
    }
}