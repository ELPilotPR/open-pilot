import Foundation
import CoreSpotlight

/// Indexación de conversaciones en Spotlight (búsqueda del sistema). Todo en el
/// dispositivo: CoreSpotlight no envía nada a ningún servidor propio.
enum SpotlightSupport {
    static let domain = "com.openpilot.app.conversations"
    static var pendingID: UUID?

    static func identifier(_ id: UUID) -> String { id.uuidString }

    /// Extrae el ID de conversación de una actividad de Spotlight.
    static func conversationID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    static func handle(_ activity: NSUserActivity) {
        if let id = conversationID(from: activity) { pendingID = id }
    }

    static func snippet(_ c: Conversation, max: Int = 200) -> String {
        let text = c.sortedMessages.first { $0.role == "user" || $0.role == "assistant" }?.text ?? ""
        return text.count > max ? String(text.prefix(max)) + "…" : text
    }

    static func attributeSet(for c: Conversation) -> CSSearchableItemAttributeSet {
        let a = CSSearchableItemAttributeSet()
        a.title = c.title.isEmpty ? "New chat" : c.title
        a.displayName = a.title
        a.contentDescription = snippet(c)
        a.keywords = c.tags
        return a
    }

    static func item(for c: Conversation) -> CSSearchableItem {
        CSSearchableItem(uniqueIdentifier: identifier(c.id), domainIdentifier: domain,
                         attributeSet: attributeSet(for: c))
    }

    static func index(_ conversations: [Conversation]) {
        let items = conversations.map { item(for: $0) }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    static func remove(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier(id)]) { _ in }
    }

    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
    }
}