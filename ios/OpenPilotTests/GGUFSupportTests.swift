import XCTest
@testable import OpenPilot

final class GGUFSupportTests: XCTestCase {
    func testCatalogNonEmpty() {
        XCTAssertFalse(GGUFSupport.catalog.isEmpty)
        XCTAssertTrue(GGUFSupport.catalog.allSatisfy { $0.filename.hasSuffix(".gguf") })
    }

    func testModelLookup() {
        let first = GGUFSupport.catalog[0]
        XCTAssertEqual(GGUFSupport.model(for: first.filename), first)
        XCTAssertNil(GGUFSupport.model(for: "nope.gguf"))
    }

    func testFlattenSystemAndPrompt() {
        let turns = [ChatTurn(role: "system", content: "Be brief."),
                     ChatTurn(role: "user", content: "Hi"),
                     ChatTurn(role: "assistant", content: "Hello")]
        let flat = GGUFSupport.flatten(turns)
        XCTAssertEqual(flat.instructions, "Be brief.")
        XCTAssertEqual(flat.prompt, "User: Hi\nAssistant: Hello")
    }

    func testFlattenNoSystem() {
        let flat = GGUFSupport.flatten([ChatTurn(role: "user", content: "Hi")])
        XCTAssertNil(flat.instructions)
        XCTAssertEqual(flat.prompt, "User: Hi")
    }

    func testDelta() {
        XCTAssertEqual(GGUFSupport.delta(previous: "Hel", current: "Hello"), "lo")
        XCTAssertEqual(GGUFSupport.delta(previous: "", current: "Hi"), "Hi")
        XCTAssertEqual(GGUFSupport.delta(previous: "abc", current: "xyz"), "xyz")
    }

    func testStoreURL() {
        XCTAssertEqual(LocalModelStore.directory.lastPathComponent, "LocalModels")
        XCTAssertEqual(LocalModelStore.url(for: "m.gguf").lastPathComponent, "m.gguf")
    }

    func testKind() {
        XCTAssertEqual(GGUFSupport.kind, "gguf")
    }
}