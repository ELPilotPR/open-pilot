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
    static let accent        = dyn("#0B6BCB", "#48AAFF")   // icon-accent (más oscuro en claro: mejor contraste WCAG)
    static let composerBg    = dyn("#FFFFFF", "#303030")
    static let border        = dyn("#E8E8E8", "#424242")   // border-default
    static let sendBg        = dyn("#0D0D0D", "#FFFFFF")
    static let sendFg        = dyn("#FFFFFF", "#0D0D0D")
    static let codeBlock     = dyn("#F8F8F8", "#171717")   // bg-code-block
    static let success       = dyn("#10A37F", "#10A37F")   // verde OpenAI
    static let danger        = dyn("#EF4444", "#F87171")
}