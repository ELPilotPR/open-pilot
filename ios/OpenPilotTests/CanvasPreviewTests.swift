import XCTest
@testable import OpenPilot

final class CanvasPreviewTests: XCTestCase {

    func testIsPreviewable() {
        XCTAssertTrue(CanvasPreview.isPreviewable("html"))
        XCTAssertTrue(CanvasPreview.isPreviewable("HTML"))
        XCTAssertTrue(CanvasPreview.isPreviewable("javascript"))
        XCTAssertTrue(CanvasPreview.isPreviewable("js"))
        XCTAssertTrue(CanvasPreview.isPreviewable("mermaid"))
        XCTAssertFalse(CanvasPreview.isPreviewable("swift"))
        XCTAssertFalse(CanvasPreview.isPreviewable("python"))
        XCTAssertFalse(CanvasPreview.isPreviewable(""))
    }

    func testHTMLPassThrough() {
        let src = "<h1>Hola</h1>"
        XCTAssertEqual(CanvasPreview.htmlDocument(language: "html", source: src), src)
    }

    func testJSWrapsAndCapturesConsole() {
        let html = CanvasPreview.htmlDocument(language: "js", source: "console.log('x')")
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("console.log('x')"))
        XCTAssertTrue(html.contains("window.onerror"))
        XCTAssertTrue(html.contains("id=\"out\""))
    }

    func testScriptEscape() {
        XCTAssertEqual(CanvasPreview.escapeScript("a</script>b"), "a<\\/script>b")
        let html = CanvasPreview.jsHTML("var s = '</script>';")
        XCTAssertFalse(html.contains("'</script>';"))   // neutralised inside the wrapper
    }

    func testMermaidContainsDiagramAndInit() {
        let html = CanvasPreview.htmlDocument(language: "mermaid", source: "graph TD; A-->B;")
        XCTAssertTrue(html.contains("class=\"mermaid\""))
        XCTAssertTrue(html.contains("graph TD; A-->B;"))
        XCTAssertTrue(html.contains("mermaid.initialize") || html.contains("not bundled"))
    }

    func testUnknownLanguageFallsBackToJSWrapper() {
        let html = CanvasPreview.htmlDocument(language: "whatever", source: "1+1")
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("1+1"))
    }
}