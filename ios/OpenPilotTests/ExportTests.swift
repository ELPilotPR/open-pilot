import XCTest
import SwiftData
@testable import OpenPilot

/// Export/import de conversaciones: Markdown, JSON fiel (árbol de versiones) y
/// PDF. Usa un contenedor SwiftData en memoria para el import.
@MainActor
final class ExportTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Conversation.self, Message.self, ProviderConfig.self, Project.self, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    private func makeConversation() -> Conversation {
        let c = Conversation(title: "Test", providerID: "casa", model: "m")
        context.insert(c)
        return c
    }

    @discardableResult
    private func add(_ c: Conversation, role: String, text: String, parent: Message?, version: Int = 1, reasoning: String = "") -> Message {
        let m = Message(role: role, text: text, reasoning: reasoning)
        m.parentID = parent?.id
        m.version = version
        parent?.preferredChildID = m.id
        m.conversation = c
        c.messages.append(m)
        context.insert(m)
        return m
    }

    func testMarkdownRolesTitleText() {
        let c = makeConversation()
        let u = add(c, role: "user", text: "hola mundo", parent: nil)
        add(c, role: "assistant", text: "respuesta larga", parent: u)
        c.activeLeafID = c.messages.last?.id
        let md = ConversationExport.markdown(c)
        XCTAssertTrue(md.contains("# Test"))
        XCTAssertTrue(md.contains("## You"))
        XCTAssertTrue(md.contains("## Assistant"))
        XCTAssertTrue(md.contains("hola mundo"))
        XCTAssertTrue(md.contains("respuesta larga"))
        XCTAssertTrue(md.contains("Exported from Open Pilot"))
    }

    func testMarkdownReasoningBlockquote() {
        let c = makeConversation()
        let u = add(c, role: "user", text: "q", parent: nil)
        add(c, role: "assistant", text: "a", parent: u, reasoning: "paso uno\npaso dos")
        c.activeLeafID = c.messages.last?.id
        let md = ConversationExport.markdown(c)
        XCTAssertTrue(md.contains("> **Reasoning**"))
        XCTAssertTrue(md.contains("> paso uno"))
        XCTAssertTrue(md.contains("> paso dos"))
    }

    func testJSONRoundTripFields() throws {
        let c = makeConversation()
        let u = add(c, role: "user", text: "pregunta", parent: nil)
        let a = add(c, role: "assistant", text: "respuesta", parent: u, reasoning: "think")
        a.feedback = 1
        c.activeLeafID = a.id
        let data = try ConversationExport.jsonData(c)
        let doc = try ConversationExport.decode(data)
        XCTAssertEqual(doc.format, "openpilot.chat")
        XCTAssertEqual(doc.title, "Test")
        XCTAssertEqual(doc.model, "m")
        XCTAssertEqual(doc.messages.count, 2)
        XCTAssertEqual(doc.activeLeafID, a.id)
        XCTAssertEqual(doc.messages.last?.text, "respuesta")
        XCTAssertEqual(doc.messages.last?.reasoning, "think")
        XCTAssertEqual(doc.messages.last?.feedback, 1)
        XCTAssertEqual(doc.messages.last?.parentID, u.id)
    }

    func testImportPreservesTreeAndText() throws {
        let c = makeConversation()
        let u1 = add(c, role: "user", text: "v1", parent: nil, version: 1)
        add(c, role: "assistant", text: "r1", parent: u1)
        let u2 = add(c, role: "user", text: "v2", parent: nil, version: 2)
        let a2 = add(c, role: "assistant", text: "r2", parent: u2)
        c.activeLeafID = a2.id
        let data = try ConversationExport.jsonData(c)

        let imported = try ConversationExport.importJSON(data, into: context)
        XCTAssertEqual(imported.messages.count, 4)
        XCTAssertEqual(imported.activeMessages.map(\.text), ["v2", "r2"])
        XCTAssertEqual(imported.title, "Test")
        // el árbol sigue conectado: la hoja activa tiene predecesor
        XCTAssertNotNil(imported.activeMessages.last?.parentID)
    }

    func testImportRemapsIDs() throws {
        let c = makeConversation()
        let u = add(c, role: "user", text: "x", parent: nil)
        add(c, role: "assistant", text: "y", parent: u)
        c.activeLeafID = c.messages.last?.id
        let originalIDs = Set(c.messages.map(\.id))
        let data = try ConversationExport.jsonData(c)
        let imported = try ConversationExport.importJSON(data, into: context)
        XCTAssertNotEqual(imported.id, c.id)
        let newIDs = Set(imported.messages.map(\.id))
        XCTAssertTrue(originalIDs.isDisjoint(with: newIDs), "los ids importados no deben colisionar")
        XCTAssertEqual(newIDs.count, 2)
    }

    func testPDFHeaderAndBody() {
        let c = makeConversation()
        let u = add(c, role: "user", text: "hola", parent: nil)
        add(c, role: "assistant", text: String(repeating: "texto de prueba. ", count: 200), parent: u)
        c.activeLeafID = c.messages.last?.id
        let data = ConversationExport.pdf(c)
        XCTAssertGreaterThan(data.count, 1000)
        let header = String(data: data.prefix(5), encoding: .ascii)
        XCTAssertEqual(header, "%PDF-")
    }

    func testFileNameSanitizes() {
        XCTAssertEqual(ConversationExport.fileName("a/b\\c:d", ext: "json"), "a-b-c-d.json")
        XCTAssertEqual(ConversationExport.fileName("   ", ext: "md"), "chat.md")
        XCTAssertTrue(ConversationExport.fileName("normal", ext: "pdf").hasSuffix(".pdf"))
    }
}