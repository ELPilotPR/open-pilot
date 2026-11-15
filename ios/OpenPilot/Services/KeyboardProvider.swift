import Foundation

/// Proveedor activo espejado al App Group para que la extensión de teclado pueda
/// llamar al modelo del usuario sin backend. (La clave viaja al App Group solo
/// cuando el usuario activa el teclado en Ajustes; es un opt-in explícito.)
struct KeyboardProvider: Codable, Equatable {
    var kind: String
    var baseURL: String
    var apiKey: String
    var model: String
    var name: String
}

enum KeyboardShared {
    static let appGroup = "group.com.openpilot.app"
    static let key = "keyboard.provider"
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func encode(_ p: KeyboardProvider) -> Data { (try? JSONEncoder().encode(p)) ?? Data() }
    static func decode(_ d: Data) -> KeyboardProvider? { try? JSONDecoder().decode(KeyboardProvider.self, from: d) }
    static func save(_ p: KeyboardProvider) { defaults?.set(encode(p), forKey: key) }
    static func load() -> KeyboardProvider? {
        guard let d = defaults?.data(forKey: key) else { return nil }
        return decode(d)
    }
    static func clear() { defaults?.removeObject(forKey: key) }
}