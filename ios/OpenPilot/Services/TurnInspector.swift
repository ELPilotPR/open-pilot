import Foundation

/// Formateo puro para el inspector de turno (testeable sin UI ni SwiftData).
enum TurnInspector {
    /// Duración: nil o negativa → "—"; <1 s en ms, si no en segundos (2 decimales).
    nonisolated static func formatDuration(_ s: Double?) -> String {
        guard let s, s >= 0 else { return "—" }
        if s < 1 { return String(format: "%.0f ms", s * 1000) }
        return String(format: "%.2f s", s)
    }

    /// tok/s: 0 o negativo → "—".
    nonisolated static func formatTPS(_ v: Double) -> String {
        v > 0 ? String(format: "%.1f", v) : "—"
    }

    /// Conteo de tokens: 0 → "—".
    nonisolated static func formatCount(_ n: Int) -> String {
        n > 0 ? "\(n)" : "—"
    }
}
