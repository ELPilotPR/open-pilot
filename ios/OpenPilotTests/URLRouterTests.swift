import XCTest
@testable import OpenPilot

final class URLRouterTests: XCTestCase {
    private func url(_ s: String) -> URL { URL(string: s)! }

    func testAskText() {
        XCTAssertEqual(URLRouter.parse(url("openpilot://ask?text=Hola%20mundo"))?.action, .ask("Hola mundo"))
    }
    func testAskAliasQ() {
        XCTAssertEqual(URLRouter.parse(url("openpilot://ask?q=Hi"))?.action, .ask("Hi"))
    }
    func testAskAliasPrompt() {
        XCTAssertEqual(URLRouter.parse(url("openpilot://ask?prompt=Hey"))?.action, .ask("Hey"))
    }
    func testAskMissingTextNil() {
        XCTAssertNil(URLRouter.parse(url("openpilot://ask")))
    }
    func testNewChat() {
        XCTAssertEqual(URLRouter.parse(url("openpilot://newchat"))?.action, .newChat)
        XCTAssertEqual(URLRouter.parse(url("openpilot://new"))?.action, .newChat)
    }
    func testVoice() {
        XCTAssertEqual(URLRouter.parse(url("openpilot://voice"))?.action, .voice)
    }
    func testWrongSchemeNil() {
        XCTAssertNil(URLRouter.parse(url("https://ask?text=x")))
    }
    func testUnknownCommandNil() {
        XCTAssertNil(URLRouter.parse(url("openpilot://bogus")))
    }
    func testXCallbackURL() {
        let r = URLRouter.parse(url("openpilot://x-callback-url/ask?text=Hi&x-success=other://ok&x-error=other://fail"))
        XCTAssertEqual(r?.action, .ask("Hi"))
        XCTAssertEqual(r?.callbacks.success, "other://ok")
        XCTAssertEqual(r?.callbacks.error, "other://fail")
    }
    func testCallbackAppendsParam() {
        let u = URLRouter.callback("other://ok?foo=1", param: "text", value: "hello world")
        XCTAssertEqual(u?.scheme, "other")
        let comps = URLComponents(url: u!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(comps?.queryItems?.first(where: { $0.name == "foo" })?.value, "1")
        XCTAssertEqual(comps?.queryItems?.first(where: { $0.name == "text" })?.value, "hello world")
    }
    func testCallbackInvalidBaseNil() {
        XCTAssertNil(URLRouter.callback("not a url", param: "text", value: "x"))
    }
    func testRouteAskWritesFlags() {
        let d = UserDefaults(suiteName: "test.deeplink.\(UUID().uuidString)")!
        XCTAssertTrue(DeepLinkSupport.route(url("openpilot://ask?text=Q&x-success=other://ok"), defaults: d))
        XCTAssertEqual(d.string(forKey: DeepLinkSupport.askTextFlag), "Q")
        XCTAssertEqual(d.string(forKey: DeepLinkSupport.xSuccessKey), "other://ok")
    }
    func testRouteNewChatSetsIntentFlag() {
        let d = UserDefaults(suiteName: "test.deeplink.\(UUID().uuidString)")!
        XCTAssertTrue(DeepLinkSupport.route(url("openpilot://newchat"), defaults: d))
        XCTAssertTrue(d.bool(forKey: IntentSupport.newChatFlag))
    }
    func testRouteVoiceSetsIntentFlag() {
        let d = UserDefaults(suiteName: "test.deeplink.\(UUID().uuidString)")!
        XCTAssertTrue(DeepLinkSupport.route(url("openpilot://voice"), defaults: d))
        XCTAssertTrue(d.bool(forKey: IntentSupport.voiceFlag))
    }
    func testRouteInvalidReturnsFalse() {
        let d = UserDefaults(suiteName: "test.deeplink.\(UUID().uuidString)")!
        XCTAssertFalse(DeepLinkSupport.route(url("https://x"), defaults: d))
    }
}