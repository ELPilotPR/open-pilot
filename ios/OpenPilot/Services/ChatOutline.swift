import Foundation

/// Una entrada del índice de la conversación: un turno de usuario como ancla.
struct OutlineEntry: Identifiable, Equatable {
    let id: UUID          // id del mensaje al que saltar
    let index: Int        // nº de turno (1-based)
    let role: String
    let preview: String
}

/// Construye el índice de un chat para navegar rápido a cualquier turno.
enum ChatOutline {
    /// Versión pura (testeable sin SwiftData): una entrada por mensaje de usuario.
    static func build(_ turns: [(id: UUID, role: String, text: String)]) -> [OutlineEntry] {
        var out: [OutlineEntry] = []
        var n = 0
        for t in turns where t.role == "user" {
            n += 1
            out.append(OutlineEntry(id: t.id, index: n, role: t.role, preview: preview(t.text)))
        }
        return out
    }

    /// Atajo sobre los mensajes del hilo activo.
    static func entries(_ messages: [Message]) -> [OutlineEntry] {
        build(messages.map { (id: $0.id, role: $0.role, text: $0.text) })
    }

    /// Vista previa de una línea, recortada.
    static func preview(_ text: String, max: Int = 80) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if flat.isEmpty { return "…" }
        return flat.count > max ? String(flat.prefix(max)) + "…" : flat
    }
}