import XCTest
@testable import OpenPilot

@MainActor
final class PromptLibraryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "test.prompts.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testAddPersistReload() {
        let lib = PromptLibrary(defaults: defaults)
        XCTAssertEqual(lib.prompts.count, 0, "a test suite must not seed defaults")
        lib.add(title: "Traducir", body: "Traduce: ")
        XCTAssertEqual(lib.prompts.count, 1)
        let reloaded = PromptLibrary(defaults: defaults)
        XCTAssertEqual(reloaded.prompts.count, 1)
        XCTAssertEqual(reloaded.prompts.first?.title, "Traducir")
        XCTAssertEqual(reloaded.prompts.first?.body, "Traduce: ")
    }

    func testUpdateDelete() {
        let lib = PromptLibrary(defaults: defaults)
        let p = lib.add(title: "A", body: "x")
        lib.update(p.id, title: "B", body: "y")
        XCTAssertEqual(lib.prompts.first?.title, "B")
        XCTAssertEqual(lib.prompts.first?.body, "y")
        lib.delete(p.id)
        XCTAssertTrue(lib.prompts.isEmpty)
    }

    func testSlashQuery() {
        XCTAssertNil(PromptLibrary.slashQuery("hola"))
        XCTAssertNil(PromptLibrary.slashQuery("/hola mundo"), "a space means a normal message")
        XCTAssertEqual(PromptLibrary.slashQuery("/"), "")
        XCTAssertEqual(PromptLibrary.slashQuery("/tra"), "tra")
    }

    func testSuggestionsPrefix() {
        let prompts = [
            Prompt(title: "Traducir", body: ""),
            Prompt(title: "Resumir", body: ""),
            Prompt(title: "Trabajo", body: ""),
        ]
        XCTAssertEqual(PromptLibrary.suggestions(for: "hola", in: prompts).count, 0)
        XCTAssertEqual(PromptLibrary.suggestions(for: "/", in: prompts).count, 3)
        XCTAssertEqual(PromptLibrary.suggestions(for: "/tra", in: prompts).map(\.title), ["Traducir", "Trabajo"])
        XCTAssertEqual(PromptLibrary.suggestions(for: "/res", in: prompts).map(\.title), ["Resumir"])
        XCTAssertEqual(PromptLibrary.suggestions(for: "/zzz", in: prompts).count, 0)
    }

    func testSuggestionsDiacriticCase() {
        let prompts = [Prompt(title: "Traducción", body: "")]
        XCTAssertEqual(PromptLibrary.suggestions(for: "/traduccion", in: prompts).count, 1)
        XCTAssertEqual(PromptLibrary.suggestions(for: "/TRAD", in: prompts).count, 1)
    }

    func testCodableRoundTrip() throws {
        let p = Prompt(title: "T", body: "B")
        let data = try JSONEncoder().encode([p])
        let back = try JSONDecoder().decode([Prompt].self, from: data)
        XCTAssertEqual(back, [p])
    }
}