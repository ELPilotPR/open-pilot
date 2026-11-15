import XCTest
@testable import OpenPilot

/// Trust boundary + lectura de páginas (adaptado de dsh tool-web).
final class WebSearchTrustTests: XCTestCase {
    func testTrustNoticeIsPresentAndClear() {
        let n = WebSearchService.trustNotice
        XCTAssertFalse(n.isEmpty)
        XCTAssertTrue(n.localizedCaseInsensitiveContains("no confiable"))
        XCTAssertTrue(n.localizedCaseInsensitiveContains("instrucciones"))
    }

    func testContextBlockEmptyIncludesNotice() {
        let s = WebSearchService.contextBlock(query: "algo", sources: [])
        XCTAssertTrue(s.contains(WebSearchService.trustNotice))
        XCTAssertTrue(s.contains("Fuentes:"))
    }

    func testContextBlockWithSourceIncludesNoticeAndIndex() {
        let src = WebSource(title: "T", url: "https://t.com", snippet: "sn", content: "body")
        let s = WebSearchService.contextBlock(query: "q", sources: [src])
        XCTAssertTrue(s.contains(WebSearchService.trustNotice))
        XCTAssertTrue(s.contains("[1] T"))
        XCTAssertTrue(s.contains("body"))
    }

    func testExtractReadableStripsTagsAndScripts() {
        let html = "<html><body><p>Tom &amp; Jerry</p><script>alert(1)</script><style>x{}</style></body></html>"
        let out = WebSearchService.extractReadableText(html, maxChars: 2600)
        XCTAssertTrue(out.contains("Tom & Jerry"), out)
        XCTAssertFalse(out.contains("alert"), out)
        XCTAssertFalse(out.contains("<p>"), out)
    }

    func testExtractReadableDecodesEntitiesAndCollapses() {
        let out = WebSearchService.extractReadableText("<p>a&nbsp;b&#39;c</p>\n\n   <p>d</p>", maxChars: 2600)
        XCTAssertTrue(out.contains("a b'c"), out)
        XCTAssertFalse(out.contains("  "), out)
    }

    func testExtractReadableEmpty() {
        XCTAssertEqual(WebSearchService.extractReadableText("", maxChars: 2600), "")
    }
}
