import XCTest
@testable import OpenPilot

final class PersonaTests: XCTestCase {
    private var suite: UserDefaults!
    private let suiteName = "PersonaTests.suite"

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: suiteName)
        suite.removePersistentDomain(forName: suiteName)
        PersonaStore.defaults = suite
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        PersonaStore.defaults = .standard
        super.tearDown()
    }

    func testBuiltinsHaveDefaultNone() {
        XCTAssertFalse(PersonaStore.builtins.isEmpty)
        let none = PersonaStore.builtins.first { $0.id == "none" }
        XCTAssertNotNil(none)
        XCTAssertEqual(none?.prompt, "")
        XCTAssertTrue(PersonaStore.builtins.allSatisfy { $0.isBuiltin })
    }

    func testDefaultSelectionIsEmptyPrompt() {
        XCTAssertEqual(PersonaStore.selectedID, "none")
        XCTAssertEqual(PersonaStore.selectedPrompt, "")
    }

    func testSelectBuiltinChangesPrompt() {
        PersonaStore.selectedID = "coder"
        XCTAssertFalse(PersonaStore.selectedPrompt.isEmpty)
        XCTAssertEqual(PersonaStore.selected?.id, "coder")
    }

    func testCustomAddPersists() {
        let p = Persona(id: "c1", name: "Poeta", symbol: "quote.opening", prompt: "Escribe en verso.", isBuiltin: false)
        PersonaStore.add(p)
        XCTAssertEqual(PersonaStore.custom.count, 1)
        XCTAssertEqual(PersonaStore.custom.first?.name, "Poeta")
        XCTAssertTrue(PersonaStore.all.contains { $0.id == "c1" })
        // Persistió de verdad (re-leer del store).
        XCTAssertEqual(PersonaStore.custom.first?.prompt, "Escribe en verso.")
    }

    func testCustomUpdate() {
        PersonaStore.add(Persona(id: "c1", name: "A", symbol: "star", prompt: "x", isBuiltin: false))
        PersonaStore.update(Persona(id: "c1", name: "B", symbol: "star", prompt: "y", isBuiltin: false))
        XCTAssertEqual(PersonaStore.custom.first?.name, "B")
        XCTAssertEqual(PersonaStore.custom.first?.prompt, "y")
        XCTAssertEqual(PersonaStore.custom.count, 1)
    }

    func testDeleteCustomResetsSelection() {
        PersonaStore.add(Persona(id: "c1", name: "A", symbol: "star", prompt: "x", isBuiltin: false))
        PersonaStore.selectedID = "c1"
        XCTAssertEqual(PersonaStore.selectedPrompt, "x")
        PersonaStore.delete(id: "c1")
        XCTAssertTrue(PersonaStore.custom.isEmpty)
        XCTAssertEqual(PersonaStore.selectedID, "none")
        XCTAssertEqual(PersonaStore.selectedPrompt, "")
    }

    func testSelectedCustomPrompt() {
        PersonaStore.add(Persona(id: "c1", name: "A", symbol: "star", prompt: "habla como pirata", isBuiltin: false))
        PersonaStore.selectedID = "c1"
        XCTAssertEqual(PersonaStore.selectedPrompt, "habla como pirata")
    }

    func testCodableRoundTrip() throws {
        let p = Persona(id: "z", name: "Ñandú", symbol: "bird", prompt: "hola \"mundo\"\nsegunda", isBuiltin: false)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Persona.self, from: data)
        XCTAssertEqual(back, p)
    }
}