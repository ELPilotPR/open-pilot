import Foundation

/// Un chat reciente tal como lo ve el widget (sin depender del modelo SwiftData).
struct WidgetChat: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let snippet: String
    let date: Date
}

/// Puente de datos app ↔ widget vía el App Group compartido. Puro y testeable.
enum WidgetSnapshot {
    static let appGroup = "group.com.openpilot.app"
    static let key = "widget.recentChats"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func encode(_ chats: [WidgetChat]) -> Data {
        (try? JSONEncoder().encode(chats)) ?? Data()
    }

    static func decode(_ data: Data) -> [WidgetChat] {
        (try? JSONDecoder().decode([WidgetChat].self, from: data)) ?? []
    }

    static func save(_ chats: [WidgetChat]) {
        defaults?.set(encode(chats), forKey: key)
    }

    static func load() -> [WidgetChat] {
        guard let d = defaults?.data(forKey: key) else { return [] }
        return decode(d)
    }
}