import Foundation

/// Borradores por conversación: el texto a medio escribir en el composer se guarda
/// en UserDefaults (una clave por id de chat) y se restaura al volver al chat.
/// Sin backend; vacío = sin borrador (se borra la clave para no acumular basura).
enum DraftStore {
    static func key(_ conversationID: String) -> String { "draft." + conversationID }

    static func text(for conversationID: String, in defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key(conversationID)) ?? ""
    }

    static func save(_ text: String, for conversationID: String, in defaults: UserDefaults = .standard) {
        if text.isEmpty {
            defaults.removeObject(forKey: key(conversationID))
        } else {
            defaults.set(text, forKey: key(conversationID))
        }
    }

    static func clear(for conversationID: String, in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(conversationID))
    }
}