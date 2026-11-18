import XCTest
import SwiftData
@testable import OpenPilot

/// Respaldo completo: export de chats + metadatos de proveedor (sin keys),
/// round-trip JSON y restauración replace/merge. Contenedor SwiftData en memoria.
@MainActor
final class BackupTests: XCTestCase {
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

    private func makeConv(_ title: String, temporary: Bool = false, pinned: Bool = false, archived: Bool = false, tags: [String] = []) -> Conversation {
        let c = Conversation(title: title, providerID: "casa", model: "m")
        c.isTemporary = temporary; c.isPinned = pinned; c.isArchived = archived; c.tags = tags
        context.insert(c)
        return c
    }

    @discardableResult
    private func add(_ c: Conversation, role: String, text: String, parent: Message?, p: Int = 0, comp: Int = 0) -> Message {
        let m = Message(role: role, text: text)
        m.parentID = parent?.id
        parent?.preferredChildID = m.id
        m.promptTokens = p; m.completionTokens = comp
        m.conversation = c
        c.messages.append(m)
        context.insert(m)
        return m
    }

    private func linear(_ title: String = "Chat") -> Conversation {
        let c = makeConv(title)
        let u = add(c, role: "user", text: "hola", parent: nil, p: 100)
        let a = add(c, role: "assistant", text: "respuesta", parent: u, comp: 40)
        c.activeLeafID = a.id
        c.ensureTree()
        return c
    }

    private func convCount() -> Int { (try? context.fetch(FetchDescriptor<Conversation>()))?.count ?? -1 }
    private func provCount() -> Int { (try? context.fetch(FetchDescriptor<ProviderConfig>()))?.count ?? -1 }

    func testBundleExcludesTemporary() {
        let keep = makeConv("Keep")
        _ = makeConv("Temp", temporary: true)
        let b = Backup.bundle(conversations: [keep], providers: [])
        // bundle recibe la lista ya filtrada por el caller; aquí verificamos el filtro interno
        let all = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        let b2 = Backup.bundle(conversations: all, providers: [])
        XCTAssertEqual(b.conversations.count, 1)
        XCTAssertEqual(b2.conversations.count, 1)
        XCTAssertEqual(b2.conversations.first?.document.title, "Keep")
    }

    func testProviderItemOmitsKeys() throws {
        let p = ProviderConfig(id: "api-test", name: "Test", kind: "openai", baseURL: "https://x", apiKey: "secret-test-key", models: ["m"])
        context.insert(p)
        let b = Backup.bundle(conversations: [], providers: [p])
        let json = String(data: try Backup.jsonData(b), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("apiKey"))
        XCTAssertFalse(json.contains("secret-test-key"))
        XCTAssertEqual(b.providers.first?.id, "api-test")
        KeychainStore.delete("api-test")
    }

    func testRoundTripEncodeDecode() throws {
        let c1 = linear("Uno"); let c2 = linear("Dos")
        let p = ProviderConfig(id: "casa", name: "Casa", baseURL: "http://local", models: ["m"])
        context.insert(p)
        let b = Backup.bundle(conversations: [c1, c2], providers: [p])
        let back = try Backup.decode(Backup.jsonData(b))
        XCTAssertEqual(back.format, "openpilot.backup")
        XCTAssertEqual(back.conversations.count, 2)
        XCTAssertEqual(back.providers.count, 1)
        XCTAssertEqual(Set(back.conversations.map { $0.document.title }), ["Uno", "Dos"])
    }

    func testDecodeRejectsForeignFormat() throws {
        let c = linear("Chat")
        let singleChatJSON = try ConversationExport.jsonData(c)   // format "openpilot.chat"
        XCTAssertThrowsError(try Backup.decode(singleChatJSON))
    }

    func testRestoreReplaceWipesExisting() {
        _ = makeConv("Old")
        let s1 = linear("S1"); let s2 = linear("S2")
        let b = Backup.bundle(conversations: [s1, s2], providers: [])
        let r = Backup.restore(b, into: context, replace: true)
        XCTAssertEqual(r.conversations, 2)
        XCTAssertEqual(convCount(), 2)
        let titles = ((try? context.fetch(FetchDescriptor<Conversation>())) ?? []).map { $0.title }
        XCTAssertFalse(titles.contains("Old"))
    }

    func testRestoreMergeAddsCopies() {
        _ = makeConv("Old")
        let s1 = linear("S1"); let s2 = linear("S2")
        let b = Backup.bundle(conversations: [s1, s2], providers: [])
        let r = Backup.restore(b, into: context, replace: false)
        XCTAssertEqual(r.conversations, 2)
        XCTAssertEqual(convCount(), 5)   // Old + S1 + S2 (3 ya en el contenedor) + 2 copias
    }

    func testRestorePreservesFlags() {
        let c = linear("Flags")
        c.isPinned = true; c.isArchived = true; c.tags = ["x", "y"]
        let b = Backup.bundle(conversations: [c], providers: [])
        Backup.restore(b, into: context, replace: true)
        let restored = ((try? context.fetch(FetchDescriptor<Conversation>())) ?? []).first
        XCTAssertEqual(restored?.isPinned, true)
        XCTAssertEqual(restored?.isArchived, true)
        XCTAssertEqual(restored?.tags, ["x", "y"])
    }

    func testRestoreProvidersSkipExisting() {
        let existing = ProviderConfig(id: "casa", name: "Original", baseURL: "http://a", models: ["m"])
        context.insert(existing)
        let b = Backup.Bundle(exportedAt: Date(), conversations: [], providers: [
            Backup.ProviderItem(id: "casa", name: "Changed", kind: "openai", baseURL: "http://b", models: [], imageCapability: "auto", contextWindow: 0),
            Backup.ProviderItem(id: "api-new", name: "New", kind: "openai", baseURL: "http://c", models: ["n"], imageCapability: "auto", contextWindow: 4096),
        ])
        let r = Backup.restore(b, into: context, replace: false)
        XCTAssertEqual(r.providers, 1)
        XCTAssertEqual(provCount(), 2)
        let casa = ((try? context.fetch(FetchDescriptor<ProviderConfig>())) ?? []).first { $0.id == "casa" }
        XCTAssertEqual(casa?.name, "Original")   // el existente no se toca
    }

    func testRestorePreservesTreeAndTokens() {
        let c = linear("Tree")
        let b = Backup.bundle(conversations: [c], providers: [])
        Backup.restore(b, into: context, replace: true)
        let restored = ((try? context.fetch(FetchDescriptor<Conversation>())) ?? []).first
        XCTAssertEqual(restored?.activeMessages.count, 2)
        let t = ConversationUsage.totals(restored?.activeMessages ?? [])
        XCTAssertEqual(t.prompt, 100)
        XCTAssertEqual(t.completion, 40)
    }

    func testEmptyBundle() throws {
        let b = Backup.bundle(conversations: [], providers: [])
        let back = try Backup.decode(Backup.jsonData(b))
        let r = Backup.restore(back, into: context, replace: true)
        XCTAssertEqual(r.conversations, 0)
        XCTAssertEqual(r.providers, 0)
        XCTAssertEqual(convCount(), 0)
    }
}
