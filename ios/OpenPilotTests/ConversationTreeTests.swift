import XCTest
import SwiftData
@testable import OpenPilot

/// Árbol de versiones de mensajes: ramas al editar/regenerar, navegación y
/// migración de conversaciones legacy. Usa un contenedor SwiftData en memoria.
@MainActor
final class ConversationTreeTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Conversation.self, Message.self, ProviderConfig.self, configurations: config)
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
    private func add(_ c: Conversation, role: String, text: String, parent: Message?, version: Int = 1) -> Message {
        let m = Message(role: role, text: text)
        m.parentID = parent?.id
        m.version = version
        parent?.preferredChildID = m.id
        m.conversation = c
        c.messages.append(m)
        context.insert(m)
        return m
    }

    func testLinearActiveMessages() {
        let c = makeConversation()
        let u = add(c, role: "user", text: "hola", parent: nil)
        let a = add(c, role: "assistant", text: "respuesta", parent: u)
        c.activeLeafID = a.id
        XCTAssertEqual(c.activeMessages.map(\.id), [u.id, a.id])
    }

    func testEditCreatesSiblings() {
        let c = makeConversation()
        let u1 = add(c, role: "user", text: "v1", parent: nil, version: 1)
        add(c, role: "assistant", text: "r1", parent: u1)
        let u2 = add(c, role: "user", text: "v2", parent: nil, version: 2)
        let a2 = add(c, role: "assistant", text: "r2", parent: u2)
        c.activeLeafID = a2.id
        XCTAssertEqual(c.siblings(of: u2).map(\.id), [u1.id, u2.id])
        XCTAssertEqual(c.activeMessages.map(\.id), [u2.id, a2.id])
    }

    func testSwitchVersionChangesActiveBranch() {
        let c = makeConversation()
        let u1 = add(c, role: "user", text: "v1", parent: nil, version: 1)
        let a1 = add(c, role: "assistant", text: "r1", parent: u1)
        let u2 = add(c, role: "user", text: "v2", parent: nil, version: 2)
        let a2 = add(c, role: "assistant", text: "r2", parent: u2)
        c.activeLeafID = a2.id

        c.switchToVersion(u1)
        XCTAssertEqual(c.activeLeafID, a1.id)
        XCTAssertEqual(c.activeMessages.map(\.id), [u1.id, a1.id])

        c.switchToVersion(u2)
        XCTAssertEqual(c.activeLeafID, a2.id)
        XCTAssertEqual(c.activeMessages.map(\.id), [u2.id, a2.id])
    }

    func testEnsureTreeMigratesLegacy() {
        let c = makeConversation()
        let u = Message(role: "user", text: "hola")
        let a = Message(role: "assistant", text: "r")
        for m in [u, a] { m.conversation = c; c.messages.append(m); context.insert(m) }
        XCTAssertNil(c.activeLeafID)
        c.ensureTree()
        XCTAssertNotNil(c.activeLeafID)
        XCTAssertEqual(c.activeMessages.count, 2)
        // Idempotente: una segunda llamada no cambia la hoja.
        let leaf = c.activeLeafID
        c.ensureTree()
        XCTAssertEqual(c.activeLeafID, leaf)
    }

    func testPinAndArchiveFlags() {
        let c = makeConversation()
        XCTAssertFalse(c.isPinned)
        XCTAssertFalse(c.isArchived)
        c.isPinned = true
        c.isArchived = true
        XCTAssertTrue(c.isPinned)
        XCTAssertTrue(c.isArchived)
    }
}
