import XCTest
@testable import OpenPilot

/// Memoria automática: parseo de la extracción del modelo, dedup, tope y
/// composición del system prompt. UserDefaults; se limpia en cada test.
final class MemoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MemoryStore.clear()
        MemoryStore.enabled = true
    }

    override func tearDown() {
        MemoryStore.clear()
        MemoryStore.enabled = true
        super.tearDown()
    }

    func testParseBullets() {
        let out = MemoryStore.parseExtraction("- Vive en Wisconsin\n* Le gusta el café\n• Tiene un iPhone")
        XCTAssertEqual(out, ["Vive en Wisconsin", "Le gusta el café", "Tiene un iPhone"])
    }

    func testParseNumbered() {
        let out = MemoryStore.parseExtraction("1. Tiene un iPhone\n2) Trabaja en iOS")
        XCTAssertEqual(out, ["Tiene un iPhone", "Trabaja en iOS"])
    }

    func testParseNinguno() {
        XCTAssertEqual(MemoryStore.parseExtraction("NINGUNO"), [])
        XCTAssertEqual(MemoryStore.parseExtraction("none"), [])
        XCTAssertEqual(MemoryStore.parseExtraction("NINGUNA\n\n"), [])
    }

    func testParseEmptyAndBlank() {
        XCTAssertEqual(MemoryStore.parseExtraction(""), [])
        XCTAssertEqual(MemoryStore.parseExtraction("  \n   \n"), [])
    }

    func testAddDedupCaseInsensitive() {
        let added = MemoryStore.add(["Hola", "hola", "  Hola  "])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(MemoryStore.entries.count, 1)
    }

    func testAddSkipsEmpty() {
        let added = MemoryStore.add(["", "   ", "Dato real"])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(MemoryStore.entries, ["Dato real"])
    }

    func testAddCap() {
        MemoryStore.add((1...60).map { "hecho \($0)" })
        XCTAssertEqual(MemoryStore.entries.count, MemoryStore.maxEntries)
        XCTAssertEqual(MemoryStore.entries.last, "hecho 60")
    }

    func testRemove() {
        MemoryStore.add(["a", "b", "c"])
        MemoryStore.remove(at: 1)
        XCTAssertEqual(MemoryStore.entries, ["a", "c"])
    }

    func testSystemPromptDisabled() {
        MemoryStore.add(["Vive en Wisconsin"])
        MemoryStore.enabled = false
        XCTAssertEqual(MemoryStore.systemPrompt, "")
    }

    func testSystemPromptEmpty() {
        XCTAssertEqual(MemoryStore.systemPrompt, "")
    }

    func testSystemPromptContent() {
        MemoryStore.add(["Vive en Wisconsin", "Prefiere español"])
        let s = MemoryStore.systemPrompt
        XCTAssertTrue(s.contains("- Vive en Wisconsin"))
        XCTAssertTrue(s.contains("- Prefiere español"))
        XCTAssertTrue(s.contains("memoria"))
    }
}
