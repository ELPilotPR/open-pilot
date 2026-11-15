import Foundation

/// Preferencia de respuesta háptica (Ajustes → Feedback). Helper puro y testeable:
/// no toca UIKit, solo UserDefaults, para poder verificar la lógica en tests.
enum HapticsPreference {
    static let key = "hapticsEnabled"

    /// Activado por defecto: si el usuario nunca lo tocó, las haptics funcionan.
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    static func setEnabled(_ on: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: key)
    }
}
