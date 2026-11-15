import XCTest
@testable import OpenPilot

final class DocumentScanSupportTests: XCTestCase {
    func testJoinPages() { XCTAssertEqual(DocumentScanSupport.joinPages(["a", "b"]), "a\n\nb") }
    func testJoinSkipsEmpty() { XCTAssertEqual(DocumentScanSupport.joinPages(["a", "  ", "b"]), "a\n\nb") }
    func testJoinEmpty() { XCTAssertEqual(DocumentScanSupport.joinPages([]), "") }
    func testCleanCollapses() { XCTAssertEqual(DocumentScanSupport.clean("a\n\n\n\nb"), "a\n\nb") }
    func testCleanTrims() { XCTAssertEqual(DocumentScanSupport.clean("  hola  "), "hola") }
}