import AppIntents
import SwiftData
import Foundation

/// Soporte puro para los App Intents (testeable sin red ni Siri).
enum IntentSupport {
    /// Claves UserDefaults que la app consume al volver al foreground.
    static let newChatFlag = "intent.newChat"
    static let voiceFlag = "intent.voice"

    /// Turnos para una pregunta directa de Siri (system + user).
    static func askTurns(question: String) -> [ChatTurn] {
        [ChatTurn(role: "system", content: "Eres Open Pilot, un asistente útil y conciso. Responde de forma breve y directa a la pregunta del usuario."),
         ChatTurn(role: "user", content: question)]
    }

    /// Drena una lista de eventos a texto plano (solo deltas).
    static func reduce(_ events: [ChatEvent]) -> String {
        events.reduce(into: "") { acc, e in if case .delta(let s) = e { acc += s } }
    }
}

/// Pregunta a Open Pilot y devuelve la respuesta como texto (Siri / Shortcuts).
/// Usa el primer proveedor configurado por el usuario; la key sale del Keychain.
struct AskOpenPilotIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Open Pilot"
    static var description = IntentDescription("Ask your configured model a question and get a text answer.")

    @Parameter(title: "Question")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Open Pilot \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return .result(value: "No question provided.") }
        let container = try ModelContainer(for: ProviderConfig.self, Conversation.self, Message.self, Project.self)
        let context = ModelContext(container)
        let providers = (try? context.fetch(FetchDescriptor<ProviderConfig>())) ?? []
        guard let p = providers.first else {
            return .result(value: "No model configured. Add a provider in Open Pilot settings.")
        }
        let kind = p.kind, base = p.baseURL, key = p.apiKey
        let model = p.models.first ?? "gpt-4o-mini"
        let client = ProviderFactory.make(kind: kind)
        var text = ""
        for try await event in client.stream(turns: IntentSupport.askTurns(question: q), model: model, baseURL: base, apiKey: key) {
            if case .delta(let s) = event { text += s }
        }
        return .result(value: text.isEmpty ? "No response." : text)
    }
}

/// Abre Open Pilot en un chat nuevo.
struct NewChatIntent: AppIntent {
    static var title: LocalizedStringResource = "New Open Pilot Chat"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: IntentSupport.newChatFlag)
        return .result()
    }
}

/// Abre Open Pilot en modo voz en vivo.
struct StartVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Pilot Voice"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: IntentSupport.voiceFlag)
        return .result()
    }
}

/// Registra los atajos en la app Shortcuts y en Siri.
struct PilotShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskOpenPilotIntent(), phrases: [
            "Ask \(.applicationName) a question",
            "Ask \(.applicationName)",
        ], shortTitle: "Ask Open Pilot", systemImageName: "bubble.left.and.text.bubble.right")
        AppShortcut(intent: NewChatIntent(), phrases: [
            "New chat in \(.applicationName)",
        ], shortTitle: "New Chat", systemImageName: "square.and.pencil")
        AppShortcut(intent: StartVoiceIntent(), phrases: [
            "Start voice in \(.applicationName)",
        ], shortTitle: "Voice Mode", systemImageName: "waveform")
    }
}
