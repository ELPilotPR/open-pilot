import Foundation
import SwiftData

/// Bifurcado de conversaciones: copia la ruta activa hasta un mensaje en un
/// chat nuevo e independiente, sin tocar el original. Todo queda en el iPhone.
enum ConversationFork {
    /// Ruta a copiar: raíz→`targetID` (incluido) sobre la ruta activa. Si el
    /// objetivo no está en la ruta activa, se copia la ruta completa.
    nonisolated static func path(upTo targetID: UUID, in active: [Message]) -> [Message] {
        if let idx = active.firstIndex(where: { $0.id == targetID }) {
            return Array(active[...idx])
        }
        return active
    }

    /// Título del chat bifurcado.
    nonisolated static func title(from original: String) -> String {
        let base = original.trimmingCharacters(in: .whitespacesAndNewlines)
        return (base.isEmpty ? "Chat" : base) + " (fork)"
    }

    /// Crea un chat nuevo con la ruta activa de `source` hasta `target` (incluido).
    /// Devuelve la conversación nueva, ya insertada y guardada. No modifica `source`.
    /// La copia es lineal (version = 1, nueva cadena de parentID) aunque el origen
    /// tenga hermanos de versión: se bifurca la rama que se está viendo.
    @MainActor
    @discardableResult
    static func fork(_ source: Conversation, upTo target: Message, into context: ModelContext) -> Conversation {
        let route = path(upTo: target.id, in: source.activeMessages)
        let c = Conversation(title: title(from: source.title),
                             providerID: source.providerID, model: source.model)
        c.projectID = source.projectID
        c.tags = source.tags
        var copies: [Message] = []
        var prev: UUID?
        for src in route {
            let m = Message(role: src.role, text: src.text, reasoning: src.reasoning)
            m.createdAt = src.createdAt
            m.feedback = src.feedback
            m.sourcesData = src.sourcesData
            m.imageData = src.imageData
            m.attachmentName = src.attachmentName
            m.attachmentText = src.attachmentText
            m.weatherData = src.weatherData
            m.currencyData = src.currencyData
            m.citationsData = src.citationsData
            m.promptTokens = src.promptTokens
            m.completionTokens = src.completionTokens
            m.tokensPerSecond = src.tokensPerSecond
            m.ttft = src.ttft
            m.elapsed = src.elapsed
            m.parentID = prev
            m.version = 1
            m.conversation = c
            context.insert(m)
            copies.append(m)
            prev = m.id
        }
        c.messages = copies
        c.activeLeafID = copies.last?.id
        context.insert(c)
        try? context.save()
        return c
    }
}
