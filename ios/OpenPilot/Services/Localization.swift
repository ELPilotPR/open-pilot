import SwiftUI
import Observation

/// Idioma de la interfaz. Por defecto sigue al dispositivo (autodetección);
/// el usuario puede fijar EN o ES con el botón de idioma.
enum AppLang: String, CaseIterable, Identifiable {
    case en, es
    var id: String { rawValue }
    var nativeName: String { self == .en ? "English" : "Español" }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()
    private let key = "appLanguageOverride"

    /// nil = autodetectar del dispositivo. EN/ES = elección manual persistida.
    var override: AppLang? {
        didSet {
            if let o = override { UserDefaults.standard.set(o.rawValue, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: key) { override = AppLang(rawValue: raw) }
    }

    static var device: AppLang {
        let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return pref.hasPrefix("es") ? .es : .en
    }

    var current: AppLang { override ?? Self.device }
    var isAuto: Bool { override == nil }
    func toggle() { override = (current == .es) ? .en : .es }
}

/// Selector bilingüe según el idioma activo. Se evalúa en cada render, así que
/// toda la UI que lo use se actualiza al cambiar el idioma (Observation).
@inline(__always)
func T(_ en: String, _ es: String) -> String {
    LanguageManager.shared.current == .es ? es : en
}

/// Botón segmentado EN / ES para fijar el idioma (por defecto: autodetectado).
struct LanguageToggle: View {
    var compact: Bool = false
    var body: some View {
        let lang = LanguageManager.shared.current
        HStack(spacing: 2) {
            option(.en, active: lang == .en)
            option(.es, active: lang == .es)
        }
        .padding(2)
        .background(OP.elevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(OP.border, lineWidth: 1))
    }

    private func option(_ l: AppLang, active: Bool) -> some View {
        Button {
            LanguageManager.shared.override = l
            Haptic.selection()
        } label: {
            Text(l.nativeName)
                .font((compact ? Font.caption : Font.subheadline).weight(active ? .semibold : .regular))
                .foregroundStyle(active ? OP.sendFg : OP.textSecondary)
                .padding(.horizontal, compact ? 12 : 18)
                .padding(.vertical, compact ? 6 : 9)
                .background(active ? OP.accent : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}