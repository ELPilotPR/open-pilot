import Foundation
import Observation

/// A reusable prompt template. Stored only on this device, no network.
struct Prompt: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, body: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

/// Local library of reusable prompts + the pure logic behind "/" slash commands
/// in the composer. Persisted as JSON in UserDefaults; observable so views update.
@Observable
@MainActor
final class PromptLibrary {
    static let shared = PromptLibrary()

    private(set) var prompts: [Prompt] = []
    private let defaults: UserDefaults
    private let key = "promptLibrary.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        // Seed a few helpful defaults only for the real shared store, not test suites.
        if prompts.isEmpty && defaults === UserDefaults.standard {
            seedDefaults()
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Prompt].self, from: data) else { return }
        prompts = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(prompts) {
            defaults.set(data, forKey: key)
        }
    }

    private func seedDefaults() {
        prompts = [
            Prompt(title: "Traducir", body: "Traduce el siguiente texto al inglés, manteniendo el tono:\n\n"),
            Prompt(title: "Resumir", body: "Resume el siguiente texto en 5 viñetas claras:\n\n"),
            Prompt(title: "Explicar sencillo", body: "Explica esto como si tuviera 10 años, con una analogía cotidiana:\n\n"),
            Prompt(title: "Revisar código", body: "Revisa este código: busca bugs, mejoras de rendimiento y de estilo. Sé concreto:\n\n"),
        ]
        persist()
    }

    // MARK: - CRUD

    @discardableResult
    func add(title: String, body: String) -> Prompt {
        let p = Prompt(title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: body)
        prompts.append(p)
        persist()
        return p
    }

    func update(_ id: UUID, title: String, body: String) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        prompts[i].body = body
        persist()
    }

    func delete(_ id: UUID) {
        prompts.removeAll { $0.id == id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        prompts.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Slash commands (pure, unit-testable)

    /// The token after a leading "/" while the user is still typing a single word.
    /// Returns nil once a whitespace appears (that's a normal message) or no slash.
    static func slashQuery(_ input: String) -> String? {
        guard input.hasPrefix("/") else { return nil }
        let rest = input.dropFirst()
        if rest.contains(where: { $0.isWhitespace }) { return nil }
        return String(rest)
    }

    /// Prompts whose title starts with the current slash query (case- and
    /// diacritic-insensitive). An empty query ("/") lists every prompt.
    static func suggestions(for input: String, in prompts: [Prompt]) -> [Prompt] {
        guard let q = slashQuery(input) else { return [] }
        if q.isEmpty { return prompts }
        let needle = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return prompts.filter {
            $0.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).hasPrefix(needle)
        }
    }
}