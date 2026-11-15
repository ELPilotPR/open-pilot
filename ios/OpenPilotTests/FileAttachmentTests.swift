import XCTest
@testable import OpenPilot

/// Extracción de texto de archivos adjuntos (texto/código) y truncado.
final class FileAttachmentTests: XCTestCase {
    private func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("op-test-\(UUID().uuidString).\(ext)")
    }

    func testParseTextFile() throws {
        let url = tempURL("txt")
        try "Hola mundo".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let parsed = FileAttachment.parse(url: url)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, url.lastPathComponent)
        XCTAssertEqual(parsed?.text, "Hola mundo")
    }

    func testParseCodeFile() throws {
        let url = tempURL("swift")
        let code = "let x = 42\nprint(x)"
        try code.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(FileAttachment.parse(url: url)?.text, code)
    }

    func testTruncationToMaxChars() throws {
        let url = tempURL("txt")
        let big = String(repeating: "a", count: FileAttachment.maxChars + 5000)
        try big.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(FileAttachment.parse(url: url)?.text.count, FileAttachment.maxChars)
    }

    func testMissingFileReturnsNil() {
        let url = tempURL("pdf")
        XCTAssertNil(FileAttachment.parse(url: url))
    }
}
