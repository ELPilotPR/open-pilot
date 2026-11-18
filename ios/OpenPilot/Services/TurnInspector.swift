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

    /// Coste estimado en USD: nil/≤0 → "—"; <0.01 → 4 decimales; resto 2.
    nonisolated static func formatCost(_ usd: Double?) -> String {
        guard let usd, usd > 0 else { return "—" }
        return usd < 0.01 ? String(format: "$%.4f", usd) : String(format: "$%.2f", usd)
    }
}
