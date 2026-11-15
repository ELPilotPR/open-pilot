import XCTest
import SwiftData
@testable import OpenPilot

/// Proyectos: instrucciones propias, asignación de conversaciones y borrado sin
/// perder los chats. Contenedor SwiftData en memoria.
@MainActor
final class ProjectTests: XCTestCase {
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

    func testDefaults() {
        let p = Project()
        XCTAssertEqual(p.symbol, "folder")
        XCTAssertEqual(p.name, "")
        XCTAssertEqual(p.instructions, "")
    }

    func testSystemPromptEmptyWithoutInstructions() {
        XCTAssertEqual(Project(name: "Trabajo").systemPrompt, "")
        XCTAssertEqual(Project(name: "X", instructions: "   \n ").systemPrompt, "")
    }

    func testSystemPromptWithName() {
        let p = Project(name: "Trabajo", instructions: "Sé conciso y profesional")
        let s = p.systemPrompt
        XCTAssertTrue(s.contains("Trabajo"))
        XCTAssertTrue(s.contains("Sé conciso y profesional"))
    }

    func testSystemPromptWithoutName() {
        let p = Project(instructions: "Responde en español")
        XCTAssertTrue(p.systemPrompt.contains("Instrucciones del proyecto:"))
        XCTAssertTrue(p.systemPrompt.contains("Responde en español"))
    }

    func testAssignConversationToProject() throws {
        let p = Project(name: "Trabajo")
        context.insert(p)
        let c = Conversation(title: "Chat", providerID: "casa", model: "m")
        c.projectID = p.id
        context.insert(c)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.projectID, p.id)
    }

    func testUnassignConversation() throws {
        let p = Project(name: "Trabajo")
        context.insert(p)
        let c = Conversation(title: "Chat", providerID: "casa", model: "m")
        c.projectID = p.id
        context.insert(c)
        try context.save()
        c.projectID = nil
        try context.save()
        XCTAssertNil(try context.fetch(FetchDescriptor<Conversation>()).first?.projectID)
    }

    func testDeleteProjectKeepsChats() throws {
        let p = Project(name: "Trabajo")
        context.insert(p)
        let c = Conversation(title: "Chat", providerID: "casa", model: "m")
        c.projectID = p.id
        context.insert(c)
        try context.save()

        // El proyecto no tiene relación cascade con los chats: borrarlo no los toca.
        context.delete(p)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Project>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Conversation>()).count, 1)
    }
}
