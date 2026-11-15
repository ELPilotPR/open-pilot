import Foundation
import SwiftData
import WidgetKit

/// Escribe el snapshot de chats recientes al App Group y recarga los widgets.
enum WidgetBridge {
    @MainActor
    static func refresh(context: ModelContext) {
        let convs = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        let chats: [WidgetChat] = convs
            .filter { !$0.isTemporary }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { c in
                let last = c.sortedMessages.last
                return WidgetChat(
                    id: c.id.uuidString,
                    title: c.title.isEmpty ? "New chat" : c.title,
                    snippet: String((last?.text ?? "").prefix(80)),
                    date: c.createdAt)
            }
        WidgetSnapshot.save(chats)
        WidgetCenter.shared.reloadAllTimelines()
    }
}