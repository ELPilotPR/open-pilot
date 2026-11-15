import Foundation

/// Contenido recibido por la Share Extension, guardado en el App Group compartido.
struct SharedItem: Codable, Equatable {
    enum Kind: String, Codable { case text, url, image }
    var kind: Kind
    var text: String
    var url: String
    var imageData: Data
    var note: String
    var date: Date
}

/// Bandeja de entrada compartida entre la Share Extension y la app. Usa el App
/// Group (UserDefaults con suiteName): la extensión escribe, la app consume al
/// volver al foreground. Sin backend, todo en el dispositivo.
enum ShareInbox {
    static let appGroup = "group.com.openpilot.app"
    static let pendingKey = "share.pending"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Guarda un item pendiente (lo escribe la extensión).
    static func put(_ item: SharedItem) {
        guard let d = defaults, let data = try? JSONEncoder().encode(item) else { return }
        d.set(data, forKey: pendingKey)
    }

    /// Lee y borra el item pendiente (lo consume la app). nil si no hay nada.
    static func take() -> SharedItem? {
        guard let d = defaults, let data = d.data(forKey: pendingKey) else { return nil }
        d.removeObject(forKey: pendingKey)
        return try? JSONDecoder().decode(SharedItem.self, from: data)
    }

    /// ¿Hay algo pendiente? (sin consumir)
    static var hasPending: Bool { defaults?.data(forKey: pendingKey) != nil }

    // MARK: - Helpers puros (testeables sin App Group)

    /// Compone el texto del mensaje de usuario a partir del item compartido.
    static func messageText(for item: SharedItem) -> String {
        var parts: [String] = []
        let note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { parts.append(note) }
        switch item.kind {
        case .url:
            if !item.url.isEmpty { parts.append(item.url) }
            if !item.text.isEmpty && item.text != item.url { parts.append(item.text) }
        case .text:
            if !item.text.isEmpty { parts.append(item.text) }
        case .image:
            if !item.text.isEmpty { parts.append(item.text) }
        }
        return parts.joined(separator: "\n\n")
    }

    /// Título corto para la conversación creada a partir del share.
    static func title(for item: SharedItem) -> String {
        let base = messageText(for: item)
        let firstLine = base.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let t = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return item.kind == .image ? "Imagen compartida" : "Compartido" }
        return String(t.prefix(40))
    }
}
