import XCTest
import SwiftData
@testable import OpenPilot

/// Bifurcado de conversaciones: la ruta activa hasta un mensaje se copia en un
/// chat nuevo e independiente. Contenedor SwiftData en memoria.
@MainActor
final class ConversationForkTests: XCTestCase {
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

    private func makeConversation(title: String = "Test") -> Conversation {
        let c = Conversation(title: title, providerID: "casa", model: "m")
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

    /// Chat lineal u→a→u2→a2 con la hoja activa en a2.
    private func linear() -> (Conversation, Message, Message, Message, Message) {
        let c = makeConversation()
        let u = add(c, role: "user", text: "hola", parent: nil)
        let a = add(c, role: "assistant", text: "respuesta", parent: u)
        let u2 = add(c, role: "user", text: "otra", parent: a)
        let a2 = add(c, role: "assistant", text: "final", parent: u2)
        c.activeLeafID = a2.id
        return (c, u, a, u2, a2)
    }

    // MARK: - path(upTo:in:)

    func testPathUpToFirst() {
        let (c, u, _, _, _) = linear()
        XCTAssertEqual(ConversationFork.path(upTo: u.id, in: c.activeMessages).map(\.id), [u.id])
    }

    func testPathUpToMiddleInclusive() {
        let (c, u, a, _, _) = linear()
        XCTAssertEqual(ConversationFork.path(upTo: a.id, in: c.activeMessages).map(\.id), [u.id, a.id])
    }

    func testPathUpToLastWhole() {
        let (c, u, a, u2, a2) = linear()
        XCTAssertEqual(ConversationFork.path(upTo: a2.id, in: c.activeMessages).map(\.id), [u.id, a.id, u2.id, a2.id])
    }

    func testPathTargetOffPathFallsBackToWhole() {
        let (c, _, _, _, _) = linear()
        let off = Message(role: "user", text: "fuera")
        XCTAssertEqual(ConversationFork.path(upTo: off.id, in: c.activeMessages).count, c.activeMessages.count)
    }

    func testPathEmptyActive() {
        XCTAssertTrue(ConversationFork.path(upTo: UUID(), in: []).isEmpty)
    }

    // MARK: - title(from:)

    func testTitleAppendsFork() {
        XCTAssertEqual(ConversationFork.title(from: "Viaje"), "Viaje (fork)")
    }

    func testTitleEmptyFallback() {
        XCTAssertEqual(ConversationFork.title(from: ""), "Chat (fork)")
    }

    func testTitleTrimsWhitespace() {
        XCTAssertEqual(ConversationFork.title(from: "  Hola  "), "Hola (fork)")
    }

    // MARK: - fork(_:upTo:into:)

    func testForkCopiesPrefixAndLeavesOriginal() {
        let (c, u, a, _, _) = linear()
        let new = ConversationFork.fork(c, upTo: a, into: context)
        XCTAssertEqual(new.messages.count, 2)
        XCTAssertEqual(new.activeMessages.map(\.text), ["hola", "respuesta"])
        XCTAssertEqual(c.messages.count, 4, "el original no se toca")
        XCTAssertEqual(new.activeLeafID, new.activeMessages.last?.id)
        XCTAssertFalse(new.messages.contains { $0.id == u.id || $0.id == a.id }, "ids nuevos")
        XCTAssertNotEqual(new.id, c.id)
    }

    func testForkPreservesTelemetryAndReasoning() {
        let (c, _, a, _, _) = linear()
        a.reasoning = "pensando"
        a.promptTokens = 12
        a.completionTokens = 34
        a.tokensPerSecond = 56
        a.ttft = 0.7
        a.elapsed = 1.9
        a.feedback = 1
        let new = ConversationFork.fork(c, upTo: a, into: context)
        let copy = new.activeMessages.last!
        XCTAssertEqual(copy.reasoning, "pensando")
        XCTAssertEqual(copy.promptTokens, 12)
        XCTAssertEqual(copy.completionTokens, 34)
        XCTAssertEqual(copy.tokensPerSecond, 56)
        XCTAssertEqual(copy.ttft, 0.7)
        XCTAssertEqual(copy.elapsed, 1.9)
        XCTAssertEqual(copy.feedback, 1)
    }

    func testForkIsLinearVersionOne() {
        let c = makeConversation()
        let u1 = add(c, role: "user", text: "v1", parent: nil, version: 1)
        add(c, role: "assistant", text: "r1", parent: u1)
        let u2 = add(c, role: "user", text: "v2", parent: nil, version: 2)
        let a2 = add(c, role: "assistant", text: "r2", parent: u2)
        c.activeLeafID = a2.id
        let new = ConversationFork.fork(c, upTo: a2, into: context)
        XCTAssertEqual(new.activeMessages.map(\.text), ["v2", "r2"])
        XCTAssertTrue(new.messages.allSatisfy { $0.version == 1 })
        XCTAssertNil(new.activeMessages.first?.parentID)
        XCTAssertEqual(new.activeMessages.last?.parentID, new.activeMessages.first?.id)
    }

    func testForkInheritsProviderModelProjectTags() {
        let (c, _, _, _, a2) = linear()
        c.providerID = "cloud"
        c.model = "gpt-x"
        c.projectID = UUID()
        c.tags = ["trabajo"]
        let new = ConversationFork.fork(c, upTo: a2, into: context)
        XCTAssertEqual(new.providerID, "cloud")
        XCTAssertEqual(new.model, "gpt-x")
        XCTAssertEqual(new.projectID, c.projectID)
        XCTAssertEqual(new.tags, ["trabajo"])
        XCTAssertEqual(new.title, "Test (fork)")
    }

    func testForkFromUserMessageStopsBeforeAssistant() {
        let (c, _, _, u2, _) = linear()
        let new = ConversationFork.fork(c, upTo: u2, into: context)
        XCTAssertEqual(new.activeMessages.map(\.role), ["user", "assistant", "user"])
        XCTAssertEqual(new.activeMessages.last?.text, "otra")
    }
}
