import Foundation

/// Helpers puros para la Live Activity (testeables sin ActivityKit).
enum LiveActivitySupport {
    /// Aplana saltos de línea y recorta el snippet para la pantalla de bloqueo / isla.
    static func snippet(_ text: String, max: Int = 90) -> String {
        let flat = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return flat.count <= max ? flat : String(flat.prefix(max - 1)) + "…"
    }

    static func statusLabel(_ status: String) -> String {
        status == "listening" ? "Listening…" : "Responding…"
    }
}