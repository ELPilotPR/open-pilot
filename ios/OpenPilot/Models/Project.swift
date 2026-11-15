import Foundation
import SwiftData

/// Un proyecto agrupa conversaciones bajo un nombre e instrucciones propias.
/// Todo local (SwiftData); nada sale del iPhone salvo la petición directa al
/// modelo que el usuario elija. Sin backend.
@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var instructions: String
    var symbol: String
    var createdAt: Date

    init(name: String = "", instructions: String = "", symbol: String = "folder") {
        self.id = UUID()
        self.name = name
        self.instructions = instructions
        self.symbol = symbol
        self.createdAt = Date()
    }

    /// Fragmento de system prompt con las instrucciones del proyecto; vacío si
    /// no hay instrucciones. Se antepone al de cada chat del proyecto.
    var systemPrompt: String {
        let t = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = n.isEmpty ? "Instrucciones del proyecto:" : "Instrucciones del proyecto \"\(n)\":"
        return header + "\n" + t
    }
}
