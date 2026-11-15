import XCTest
@testable import OpenPilot

final class HandoffSupportTests: XCTestCase {
    private func conv(_ texts: [(String, String)] = [("user", "hola"), ("assistant", "qué tal")]) -> Conversation {
        let c = Conversation(title: "Chat", providerID: "casa", model: "m")
        for (r, t) in texts { let m = Message(role: r, text: t); m.conversation = c; c.messages.append(m) }
        c.ensureTree(); return c
    }
    func testEncodeDecodeRoundTrip() {
        let msgs = [HandoffMessage(role: "user", text: "hola"), HandoffMessage(role: "assistant", text: "hi")]
        XCTAssertEqual(HandoffSupport.decode(HandoffSupport.encode(msgs)), msgs)
    }
    func testDecodeInvalid() {
        XCTAssertTrue(HandoffSupport.decode("not json").isEmpty)
    }
    func testTranscriptFiltersRoles() {
        let c = conv([("system", "sys"), ("user", "u"), ("assistant", "a")])
        let t = HandoffSupport.transcript(c)
        XCTAssertEqual(t.count, 2)
        XCTAssertEqual(t.map { $0.role }, ["user", "assistant"])
    }
    func testConfigureSetsUserInfo() {
        let a = NSUserActivity(activityType: HandoffSupport.activityType)
        HandoffSupport.configure(a, for: conv())
        XCTAssertNotNil(a.userInfo?["transcript"])
        XCTAssertTrue(a.isEligibleForHandoff)
    }
    func testConfigureNil() {
        let a = NSUserActivity(activityType: HandoffSupport.activityType)
        HandoffSupport.configure(a, for: nil)
        XCTAssertTrue(a.userInfo?.isEmpty ?? false)
    }
    func testPayloadValid() {
        let a = NSUserActivity(activityType: HandoffSupport.activityType)
        a.userInfo = ["title": "Chat", "transcript": HandoffSupport.encode([HandoffMessage(role: "user", text: "hola")])]
        let p = HandoffSupport.payload(from: a)
        XCTAssertEqual(p?.title, "Chat")
        XCTAssertEqual(p?.messages.first?.text, "hola")
    }
    func testPayloadWrongType() {
        let a = NSUserActivity(activityType: "com.other")
        a.userInfo = ["transcript": HandoffSupport.encode([HandoffMessage(role: "user", text: "x")])]
        XCTAssertNil(HandoffSupport.payload(from: a))
    }
    func testPayloadEmptyTranscript() {
        let a = NSUserActivity(activityType: HandoffSupport.activityType)
        a.userInfo = ["transcript": "[]"]
        XCTAssertNil(HandoffSupport.payload(from: a))
    }
    func testHandleSetsPending() {
        let a = NSUserActivity(activityType: HandoffSupport.activityType)
        a.userInfo = ["title": "T", "transcript": HandoffSupport.encode([HandoffMessage(role: "user", text: "x")])]
        HandoffSupport.handle(a)
        XCTAssertEqual(HandoffSupport.pending?.title, "T")
        HandoffSupport.pending = nil
    }
}