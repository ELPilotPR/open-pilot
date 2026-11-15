import Foundation

/// User-facing context settings (shared keys with SettingsView's @AppStorage).
enum ContextSettings {
    static var autoCompact: Bool {
        get { UserDefaults.standard.object(forKey: "context.autoCompact") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "context.autoCompact") }
    }
    /// 0 = auto (escala con la ventana del modelo); >0 = presupuesto manual fijo.
    static var budgetTokens: Int {
        get { UserDefaults.standard.integer(forKey: "context.budget") }
        set { UserDefaults.standard.set(newValue, forKey: "context.budget") }
    }
}

/// On-device context management: estimate token usage and compact long histories so a
/// conversation never blows past the model's context window. Compaction is extractive
/// (a bounded digest of older turns) — no extra API call, works fully offline.
enum ContextManager {

    /// Rough token estimate (~4 chars/token), matching the app's usage fallback.
    static func estimateTokens(_ text: String) -> Int { text.count / 4 }

    static func estimateTokens(_ turns: [ChatTurn]) -> Int {
        turns.reduce(0) { $0 + max(1, $1.content.count / 4) }
    }

    /// Presupuesto de compactación: manual si >0; si no (auto), ~70% de la ventana
    /// del modelo, dejando margen para el system prompt y la respuesta.
    static let autoBudgetFraction = 0.7
    static func effectiveBudget(window: Int, manual: Int) -> Int {
        if manual > 0 { return manual }
        return max(2000, Int(Double(max(window, 2000)) * autoBudgetFraction))
    }

    struct Plan {
        var compacted: [ChatTurn]
        var didCompact: Bool
        var foldedCount: Int
        var beforeTokens: Int
        var afterTokens: Int
    }

    /// Max older turns folded into the digest, so the summary itself stays bounded.
    static let summaryCap = 40

    /// Keep system turns + the most recent `keepRecent` turns verbatim; when the estimate
    /// exceeds `budget`, fold older turns into one summary system turn. Recent turns keep
    /// their images (vision); only older text is condensed.
    static func compact(_ turns: [ChatTurn], budget: Int, keepRecent: Int = 6) -> Plan {
        let before = estimateTokens(turns)
        let system = turns.filter { $0.role == "system" }
        let nonSystem = turns.filter { $0.role != "system" }
        guard before > budget, nonSystem.count > keepRecent else {
            return Plan(compacted: turns, didCompact: false, foldedCount: 0,
                        beforeTokens: before, afterTokens: before)
        }
        let older = Array(nonSystem.dropLast(keepRecent))
        let recent = Array(nonSystem.suffix(keepRecent))
        let digest = Array(older.suffix(summaryCap))
        let summaryTurn = ChatTurn(role: "system", content: summarize(digest, totalFolded: older.count))
        let compacted = system + [summaryTurn] + recent
        return Plan(compacted: compacted, didCompact: true, foldedCount: older.count,
                    beforeTokens: before, afterTokens: estimateTokens(compacted))
    }

    /// Extractive digest: one bullet per older turn, each truncated to a snippet.
    static func summarize(_ turns: [ChatTurn], totalFolded: Int? = nil) -> String {
        let n = totalFolded ?? turns.count
        var lines = [T("[Summary of \(n) earlier messages in this conversation]",
                       "[Resumen de \(n) mensajes anteriores de esta conversación]")]
        for t in turns {
            let clean = t.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = String(clean.prefix(160))
            let who = t.role == "user" ? T("User", "Usuario") : T("Assistant", "Asistente")
            lines.append("• \(who): \(snippet)\(clean.count > 160 ? "…" : "")")
        }
        return lines.joined(separator: "\n")
    }
}