import SwiftUI

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b, a: Double
        if h.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Paleta de Open Pilot, light + dark. Tokens semánticos (fondo, texto, acento,
/// borde, código) que se adaptan automáticamente al modo claro/oscuro.
enum OP {
    static func dyn(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
    static let canvas        = dyn("#FFFFFF", "#212121")   // bg-primary
    static let sidebar       = dyn("#F9F9F9", "#171717")
    static let elevated      = dyn("#FFFFFF", "#303030")   // bg-elevated-primary
    static let userBubble    = dyn("#F4F4F4", "#3A3A3A")   // bg-user-message
    static let textPrimary   = dyn("#0D0D0D", "#ECECEC")   // text-primary
    static let textSecondary = dyn("#5D5D5D", "#CDCDCD")   // text-secondary
    static let textTertiary  = dyn("#8F8F8F", "#AFAFAF")   // text-tertiary
    static var accent: Color { AccentTheme.current().color }   // acento seleccionable por el usuario
    static let composerBg    = dyn("#FFFFFF", "#303030")
    static let border        = dyn("#E8E8E8", "#424242")   // border-default
    static let sendBg        = dyn("#0D0D0D", "#FFFFFF")
    static let sendFg        = dyn("#FFFFFF", "#0D0D0D")
    static let codeBlock     = dyn("#F8F8F8", "#171717")   // bg-code-block
    static let success       = dyn("#10A37F", "#10A37F")   // verde OpenAI
    static let danger        = dyn("#EF4444", "#F87171")
}

/// Acento seleccionable por el usuario (Settings → Apariencia). Cada color tiene
/// variante clara y oscura para mantener contraste en ambos modos.
enum AccentTheme: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var light: String {
        switch self {
        case .blue: return "#0B6BCB"
        case .indigo: return "#4F46E5"
        case .purple: return "#7C3AED"
        case .pink: return "#DB2777"
        case .red: return "#DC2626"
        case .orange: return "#EA580C"
        case .green: return "#059669"
        case .teal: return "#0D9488"
        }
    }
    var dark: String {
        switch self {
        case .blue: return "#48AAFF"
        case .indigo: return "#818CF8"
        case .purple: return "#A78BFA"
        case .pink: return "#F472B6"
        case .red: return "#F87171"
        case .orange: return "#FB923C"
        case .green: return "#34D399"
        case .teal: return "#2DD4BF"
        }
    }
    var color: Color { OP.dyn(light, dark) }

    static func current(defaults: UserDefaults = .standard) -> AccentTheme {
        AccentTheme(rawValue: defaults.string(forKey: "accentColor") ?? "blue") ?? .blue
    }
}