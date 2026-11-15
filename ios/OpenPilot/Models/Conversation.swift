import Foundation
import SwiftData

/// Una conversación persistente en el dispositivo. Nada sale del iPhone salvo
/// la petición directa al modelo que el usuario elija.
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var providerID: String
    var model: String
    /// Hoja activa del árbol de versiones: la ruta raíz→hoja que se muestra.
    var activeLeafID: UUID?
    /// Fijada arriba del sidebar (pin) y/o archivada (oculta de la lista principal).
    var isPinned: Bool = false
    var isArchived: Bool = false
    /// Proyecto al que pertenece (nil = sin proyecto). Migración ligera.
    var projectID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(title: String = "", providerID: String = "", model: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.providerID = providerID
        self.model = model
        self.messages = []
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Árbol de versiones

    func message(_ id: UUID?) -> Message? {
        guard let id else { return nil }
        return messages.first { $0.id == id }
    }

    /// Ruta raíz→hoja activa. Si aún no hay árbol (datos legacy), cae al orden
    /// cronológico completo.
    var activeMessages: [Message] {
        let byID = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard let leafID = activeLeafID, let leaf = byID[leafID] else { return sortedMessages }
        var path: [Message] = []
        var cur = leaf
        var hops = 0
        while hops < 100_000 {
            path.append(cur)
            guard let pid = cur.parentID, let next = byID[pid] else { break }
            cur = next
            hops += 1
        }
        return path.reversed()
    }

    /// Convierte una conversación legacy (lineal, sin árbol) en una cadena simple.
    /// Idempotente: no hace nada si ya hay hoja activa.
    func ensureTree() {
        guard activeLeafID == nil else { return }
        let sorted = sortedMessages
        guard !sorted.isEmpty else { return }
        var prev: UUID?
        for m in sorted {
            m.parentID = prev
            m.version = 1
            prev = m.id
        }
        activeLeafID = sorted.last?.id
    }

    /// Versiones hermanas de un mensaje (mismo predecesor y rol), ordenadas.
    func siblings(of m: Message) -> [Message] {
        messages.filter { $0.parentID == m.parentID && $0.role == m.role }
            .sorted { $0.version < $1.version }
    }

    /// Cambia la rama activa a la versión `target`, recordando la elección y
    /// bajando por los hijos preferidos hasta una hoja.
    func switchToVersion(_ target: Message) {
        if let pid = target.parentID, let parent = message(pid) {
            parent.preferredChildID = target.id
        }
        let byID = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var cur = target
        var hops = 0
        while hops < 100_000 {
            guard let cid = cur.preferredChildID, let child = byID[cid] else { break }
            cur = child
            hops += 1
        }
        activeLeafID = cur.id
    }
}