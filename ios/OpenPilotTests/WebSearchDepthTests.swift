import XCTest
@testable import OpenPilot

/// 1.0.9 — deeper web browse: depth presets, POST form encoding, Lite
/// pagination (next_form) and the POST result markup. All pure/offline.
final class WebSearchDepthTests: XCTestCase {

    // MARK: depthParams

    func testDepthQuick() {
        let d = WebSearchService.depthParams("quick")
        XCTAssertEqual(d.limit, 5); XCTAssertEqual(d.enrichTop, 3)
        XCTAssertEqual(d.maxChars, 2600); XCTAssertEqual(d.pages, 1)
    }

    func testDepthStandard() {
        let d = WebSearchService.depthParams("standard")
        XCTAssertEqual(d.limit, 8); XCTAssertEqual(d.enrichTop, 5)
        XCTAssertEqual(d.maxChars, 3500); XCTAssertEqual(d.pages, 1)
    }

    func testDepthDeep() {
        let d = WebSearchService.depthParams("deep")
        XCTAssertEqual(d.limit, 12); XCTAssertEqual(d.enrichTop, 8)
        XCTAssertEqual(d.maxChars, 4500); XCTAssertEqual(d.pages, 2)
    }

    func testDepthUnknownFallsBackToStandard() {
        let d = WebSearchService.depthParams("nonsense")
        XCTAssertEqual(d.limit, 8); XCTAssertEqual(d.pages, 1)
    }

    func testDeepReadsMoreThanQuick() {
        let q = WebSearchService.depthParams("quick")
        let deep = WebSearchService.depthParams("deep")
        XCTAssertGreaterThan(deep.limit, q.limit)
        XCTAssertGreaterThan(deep.enrichTop, q.enrichTop)
        XCTAssertGreaterThan(deep.maxChars, q.maxChars)
        XCTAssertGreaterThan(deep.pages, q.pages)
    }

    // MARK: formEncode

    func testFormEncodeSpacesBecomePlus() {
        XCTAssertEqual(WebSearchService.formEncode(["q": "swiftui tutorial"]), "q=swiftui+tutorial")
    }

    func testFormEncodeSpecialChars() {
        XCTAssertEqual(WebSearchService.formEncode(["q": "a&b=c"]), "q=a%26b%3Dc")
    }

    func testFormEncodeMultipleFields() {
        let body = WebSearchService.formEncode(["q": "hi", "s": "10"])
        XCTAssertTrue(body.contains("q=hi"))
        XCTAssertTrue(body.contains("s=10"))
        XCTAssertTrue(body.contains("&"))
    }

    // MARK: nextFormFields (pagination)

    private let nextForm = """
    <form class="next_form" action="/lite/" method="post">
    <input type="submit" class='navbutton' value="Next Page &gt;">
    <input type="hidden" name="q" value="swiftui tutorial">
    <input type="hidden" name="s" value="10">
    <input type="hidden" name="vqd" value="4-201579273942500420766274432262423336250">
    <input name="kl" value="wt-wt" type="hidden">
    </form>
    """

    func testNextFormExtractsHiddenFields() {
        let f = WebSearchService.nextFormFields(nextForm)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?["q"], "swiftui tutorial")
        XCTAssertEqual(f?["s"], "10")
        XCTAssertEqual(f?["vqd"], "4-201579273942500420766274432262423336250")
        XCTAssertEqual(f?["kl"], "wt-wt")
    }

    func testNextFormSkipsUnnamedSubmit() {
        let f = WebSearchService.nextFormFields(nextForm)
        XCTAssertEqual(f?.count, 4)   // q, s, vqd, kl — the submit button has no name
    }

    func testNextFormNilWhenAbsent() {
        XCTAssertNil(WebSearchService.nextFormFields("<html><body>no results</body></html>"))
        XCTAssertNil(WebSearchService.nextFormFields(""))
    }

    func testNextFormRoundTripsThroughFormEncode() {
        let f = WebSearchService.nextFormFields(nextForm)!
        let body = WebSearchService.formEncode(f)
        XCTAssertTrue(body.contains("vqd=4-201579273942500420766274432262423336250"))
        XCTAssertTrue(body.contains("q=swiftui+tutorial"))
    }

    // MARK: parseLite on POST markup (direct URLs, no uddg redirect)

    private let litePOST = """
    <table>
    <tr><td><a rel="nofollow" href="https://developer.apple.com/tutorials/swiftui/" class="result-link">SwiftUI Tutorials | Apple</a></td></tr>
    <tr><td class="result-snippet">Learn how to use SwiftUI to create user interfaces.</td></tr>
    <tr><td><a rel="nofollow" href="https://www.w3schools.com/swift/swift_ui_intro.asp" class="result-link">SwiftUI Introduction</a></td></tr>
    <tr><td class="result-snippet">Well organized and easy to understand.</td></tr>
    </table>
    """

    func testParseLitePOSTDirectURLs() {
        let r = WebSearchService.parseLite(litePOST, limit: 10)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0].url, "https://developer.apple.com/tutorials/swiftui/")
        XCTAssertEqual(r[0].title, "SwiftUI Tutorials | Apple")
        XCTAssertTrue(r[0].snippet.contains("Learn how to use SwiftUI"))
        XCTAssertEqual(r[1].url, "https://www.w3schools.com/swift/swift_ui_intro.asp")
    }

    func testParseLiteChallengeReturnsEmpty() {
        let challenge = "<html><head><title>DuckDuckGo</title></head><body><iframe src=\"//duckduckgo.com/anomaly.js\"></iframe></body></html>"
        XCTAssertTrue(WebSearchService.parseLite(challenge, limit: 10).isEmpty)
    }
}