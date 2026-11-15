import ActivityKit
import Foundation

/// Atributos de la Live Activity de un turno de chat (compartido app ↔ widget).
struct ChatActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var snippet: String
        var status: String   // "streaming" | "listening"
    }
    var title: String
}