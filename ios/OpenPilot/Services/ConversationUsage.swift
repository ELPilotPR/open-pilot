import Foundation

/// Métricas de uso por conversación para el badge de la lista (sidebar):
/// tokens totales de la ruta activa y coste estimado. Helpers puros y
/// testeables; el coste reutiliza `UsagePricing` y `TurnInspector.formatCost`.
/// Todo client-side, sin red.
enum ConversationUsage {
    /// Suma de tokens prompt y completion de los mensajes dados.
    nonisolated static func totals(_ messages: [Message]) -> (prompt: Int, completion: Int) {
        var p = 0, c = 0
        for m in messages { p += m.promptTokens; c += m.completionTokens }
        return (p, c)
    }

    /// Formato compacto: 980 → "980", 1234 → "1.2k", 3_400_000 → "3.4M".
    nonisolated static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    /// Coste estimado en USD para un modelo cloud; nil si no hay coste positivo
    /// (p. ej. cero tokens). Los proveedores locales se tratan aparte en la UI.
    nonisolated static func estimatedCost(model: String, prompt: Int, completion: Int) -> Double? {
        let usd = UsagePricing.costUSD(model: model, promptTokens: prompt, completionTokens: completion, local: false)
        return usd > 0 ? usd : nil
    }
}
