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
}