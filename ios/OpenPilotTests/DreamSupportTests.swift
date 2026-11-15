import XCTest
@testable import OpenPilot

final class DreamSupportTests: XCTestCase {
    // MARK: - parseProfile
    func testParseSectionsAndItems() {
        let text = """
        ## Quién es
        - Se llama Javier
        - Vive en Wisconsin
        ## Gustos y preferencias
        - Le gusta el café sin azúcar
        """
        let s = DreamSupport.parseProfile(text)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[0].title, "Quién es")
        XCTAssertEqual(s[0].items, ["Se llama Javier", "Vive en Wisconsin"])
        XCTAssertEqual(s[1].items, ["Le gusta el café sin azúcar"])
    }

    func testParseStripsBulletsAndSkipsEmptySections() {
        let text = """
        ## Proyectos
        * Open Pilot
        • Korsh
        ## Vacía
        ## Estilo
        - Respuestas cortas
        """
        let s = DreamSupport.parseProfile(text)
        XCTAssertEqual(s.count, 2) // "Vacía" se omite
        XCTAssertEqual(s[0].items, ["Open Pilot", "Korsh"])
        XCTAssertEqual(s[1].title, "Estilo")
    }

    func testParseCapsItemsPerSection() {
        let items = (1...20).map { "- item \($0)" }.joined(separator: "\n")
        let s = DreamSupport.parseProfile("## Gustos\n" + items)
        XCTAssertEqual(s[0].items.count, DreamSupport.maxItemsPerSection)
    }

    func testParseIgnoresTextBeforeFirstHeader() {
        let s = DreamSupport.parseProfile("intro sin sección\n- huérfano\n## Quién es\n- Javier")
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].items, ["Javier"])
    }

    func testParseEmpty() {
        XCTAssertTrue(DreamSupport.parseProfile("").isEmpty)
        XCTAssertTrue(DreamSupport.parseProfile("NINGUNO").isEmpty)
    }

    // MARK: - consolidationPrompt
    func testConsolidationPromptIncludesExistingTranscriptAndFormat() {
        let existing = UserProfile(sections: [.init(title: "Quién es", items: ["Javier"])], updatedAt: Date())
        let p = DreamSupport.consolidationPrompt(existing: existing, transcript: "Usuario: hola")
        XCTAssertTrue(p.contains("Javier"))
        XCTAssertTrue(p.contains("Usuario: hola"))
        XCTAssertTrue(p.contains("## Quién es"))
        XCTAssertTrue(p.contains("máximo \(DreamSupport.maxItemsPerSection)"))
    }

    func testConsolidationPromptEmptyProfile() {
        let p = DreamSupport.consolidationPrompt(existing: .empty, transcript: "x")
        XCTAssertTrue(p.contains("(perfil vacío)"))
    }

    // MARK: - systemPromptFragment
    func testFragmentEmptyForEmptyProfile() {
        XCTAssertEqual(DreamSupport.systemPromptFragment(.empty), "")
    }

    func testFragmentRendersProfile() {
        let p = UserProfile(sections: [.init(title: "Gustos", items: ["café"])], updatedAt: Date())
        let f = DreamSupport.systemPromptFragment(p)
        XCTAssertTrue(f.contains("Perfil aprendido"))
        XCTAssertTrue(f.contains("## Gustos"))
        XCTAssertTrue(f.contains("- café"))
    }

    // MARK: - shouldDream
    func testShouldDreamThreshold() {
        XCTAssertTrue(DreamSupport.shouldDream(enabled: true, newMessages: 20, threshold: 20))
        XCTAssertFalse(DreamSupport.shouldDream(enabled: true, newMessages: 19, threshold: 20))
        XCTAssertFalse(DreamSupport.shouldDream(enabled: false, newMessages: 100, threshold: 20))
    }

    // MARK: - transcript
    func testTranscriptLabelsAndBudget() {
        let msgs = [(role: "user", text: "hola"), (role: "assistant", text: "qué tal"), (role: "user", text: "  ")]
        let t = DreamSupport.transcript(msgs)
        XCTAssertTrue(t.contains("Usuario: hola"))
        XCTAssertTrue(t.contains("Asistente: qué tal"))
        XCTAssertFalse(t.contains("  ")) // vacío omitido
    }

    func testTranscriptRespectsBudget() {
        let msgs = (1...100).map { _ in (role: "user", text: String(repeating: "x", count: 400)) }
        let t = DreamSupport.transcript(msgs, maxChars: 1000)
        XCTAssertLessThanOrEqual(t.count, 1400) // 1000 + última línea parcial
    }

    // MARK: - UserProfile
    func testProfileEmptyAndCounts() {
        XCTAssertTrue(UserProfile.empty.isEmpty)
        let p = UserProfile(sections: [.init(title: "A", items: ["x", "y"]), .init(title: "B", items: [])], updatedAt: Date())
        XCTAssertFalse(p.isEmpty)
        XCTAssertEqual(p.totalItems, 2)
    }
}