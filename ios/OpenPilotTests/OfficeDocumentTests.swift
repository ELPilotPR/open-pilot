import XCTest
@testable import OpenPilot

final class OfficeDocumentTests: XCTestCase {
    // Fixtures OOXML reales generados con zipfile (deflate), embebidos en base64.
    private let docxB64 = "UEsDBBQAAAAIAA6ib13muHRrXAAAAGIAAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbBXMTQqAIBBA4auE+xxr0SJKL9EFRKYfylGcIer22fLxwZvcE6/mxsJHoll12ihnp+XNyE0V4lntInkE4LBj9KxTRqqyphK91CwbZB9OvyH0xgwQEgmStPI/FNgPUEsDBBQAAAAIAA6ib10TTntOjAAAANQAAAARAAAAd29yZC9kb2N1bWVudC54bWxtj8EKAjEMRH+l7MGjWTx4qGvP3v2CuK27hSYpbZfq39sKIoiXF4bMkMlUtZV5I8dFPShw1vU8rKVEDZDn1RHmvUTHbXeXRFiaTAtUSTYmmV3OnhcKcBjHIxB6HsxU9U3ss8/YkTqKuUhARRtbmaDrzvRm/LVe3dJ8qIJnh2qHFE+qFfmTg88t+P5hXlBLAQIUAxQAAAAIAA6ib13muHRrXAAAAGIAAAATAAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAgADqJvXRNOe06MAAAA1AAAABEAAAAAAAAAAAAAAIABjQAAAHdvcmQvZG9jdW1lbnQueG1sUEsFBgAAAAACAAIAgAAAAEgBAAAAAA=="
    private let xlsxB64 = "UEsDBBQAAAAIAA6ib11LEuEnagAAAIoAAAAUAAAAeGwvc2hhcmVkU3RyaW5ncy54bWxdzjEOgzAMheGrVBygRgwMlWupAyt3MI3bIOEkij1w/KZiQGJ831t+NPPbrluyZxfdywPA3lGU7Z6LpPZ8clX2NusXrFThYFHEdYOh70dQXlNHaCuh05x1qYLghPCXQ6fA4WqvxCdBi6AfUEsDBBQAAAAIAA6ib10Bb7w5jAAAAP0AAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sXY9dCkIhEEa3Ii6gUYMeQoWijYhZRtcfHLm35WcSIvdt5jszhxm5pfJG71wln7BEVNTXms8AaL0LBg8pu9jII5VgamvLEzAXZ+59KSwgGDtBMK9ItezZzVSjZUkbKYryltpfceGUVEWx9atmElYtwf7ZdWZ8MGiOIRJDJKZhsROJnh7ZzgHTYTA+1l9QSwECFAMUAAAACAAOom9dSxLhJ2oAAACKAAAAFAAAAAAAAAAAAAAAgAEAAAAAeGwvc2hhcmVkU3RyaW5ncy54bWxQSwECFAMUAAAACAAOom9dAW+8OYwAAAD9AAAAGAAAAAAAAAAAAAAAgAGcAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sUEsFBgAAAAACAAIAiAAAAF4BAAAAAA=="

    private func writeTemp(_ b64: String, ext: String) throws -> URL {
        let data = try XCTUnwrap(Data(base64Encoded: b64))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        try data.write(to: url)
        return url
    }

    func testDocxExtract() throws {
        let url = try writeTemp(docxB64, ext: "docx")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try XCTUnwrap(OfficeDocument.extractText(url: url))
        XCTAssertTrue(text.contains("Hola mundo"))
        XCTAssertTrue(text.contains("Segunda linea & mas"))
        XCTAssertTrue(text.contains("\n"))
    }

    func testXlsxExtract() throws {
        let url = try writeTemp(xlsxB64, ext: "xlsx")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try XCTUnwrap(OfficeDocument.extractText(url: url))
        XCTAssertEqual(text, "Nombre\tEdad\nAna\t30")
    }

    func testZipEntriesFindsDocument() throws {
        let data = try XCTUnwrap(Data(base64Encoded: docxB64))
        let entries = OfficeDocument.zipEntries(data)
        XCTAssertNotNil(entries["word/document.xml"])
        XCTAssertNotNil(entries["[Content_Types].xml"])
    }

    func testZipEntriesXlsx() throws {
        let data = try XCTUnwrap(Data(base64Encoded: xlsxB64))
        let entries = OfficeDocument.zipEntries(data)
        XCTAssertNotNil(entries["xl/sharedStrings.xml"])
        XCTAssertNotNil(entries["xl/worksheets/sheet1.xml"])
    }

    func testInvalidDataReturnsNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".docx")
        try Data("esto no es un zip".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(OfficeDocument.extractText(url: url))
    }

    // MARK: - Helpers puros

    func testCapture() {
        XCTAssertEqual(OfficeDocument.capture("<t>a</t><t>b</t>", tag: "t"), ["a", "b"])
        XCTAssertEqual(OfficeDocument.capture("<t xml:space=\"preserve\">hola</t>", tag: "t"), ["hola"])
        XCTAssertTrue(OfficeDocument.capture("<x>1</x>", tag: "t").isEmpty)
    }

    func testStripTags() {
        XCTAssertEqual(OfficeDocument.stripTags("<p>hola <b>mundo</b></p>"), "hola mundo")
    }

    func testDecodeEntities() {
        XCTAssertEqual(OfficeDocument.decodeEntities("&amp;&lt;&gt;&quot;&#39;"), "&<>\"'")
    }

    func testCleanCollapsesNewlines() {
        XCTAssertEqual(OfficeDocument.clean("a\n\n\n\nb"), "a\n\nb")
        XCTAssertEqual(OfficeDocument.clean("  hola  "), "hola")
    }
}