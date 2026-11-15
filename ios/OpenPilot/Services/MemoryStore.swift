import Foundation

/// Memoria automática local: hechos duraderos sobre el usuario que el modelo
/// extrae de las conversaciones y que se inyectan en cada system prompt para
/// personalizar respuestas. Todo en el dispositivo (UserDefaults); sin backend.
/// Se puede activar/desactivar y editar/borrar a mano desde Ajustes.
enum MemoryStore {
    static let maxEntries = 50
    private static let entriesKey = "memoryEntries"
    private static let enabledKey = "memoryEnabled"

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var entries: [String] {
        get { (UserDefaults.standard.array(forKey: entriesKey) as? [String]) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: entriesKey) }
    }

    /// Añade hechos nuevos deduplicando (case-insensitive + trim) y aplica el
    /// tope. Devuelve cuántos añadió. No escribe si no hay nada nuevo.
    @discardableResult
    static func add(_ facts: [String]) -> Int {
        var current = entries
        var added = 0
        for f in facts {
            let t = f.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if !current.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                current.append(t); added += 1
            }
        }
        if current.count > maxEntries { current = Array(current.suffix(maxEntries)) }
        if added > 0 { entries = current }
        return added
    }

    static func remove(at index: Int) {
        var e = entries
        guard e.indices.contains(index) else { return }
        e.remove(at: index); entries = e
    }

    static func clear() { entries = [] }

    /// Parsea la salida del modelo (un hecho por línea) a hechos limpios.
    /// Quita viñetas ("- ", "* ", "• ") y numeración ("1. ", "2) ").
    /// "NINGUNO"/"NONE"/"NINGUNA" → []. Líneas vacías se ignoran.
    static func parseExtraction(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.split(whereSeparator: { $0.isNewline }) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let upper = line.uppercased()
            if upper == "NINGUNO" || upper == "NONE" || upper == "NINGUNA" { continue }
            for prefix in ["- ", "* ", "• "] {
                if line.hasPrefix(prefix) { line = String(line.dropFirst(prefix.count)); break }
            }
            if let r = line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                line.removeSubrange(r)
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { out.append(line) }
        }
        return out
    }

    /// Fragmento de system prompt; vacío si está desactivado o sin hechos.
    static var systemPrompt: String {
        guard enabled else { return "" }
        let e = entries
        guard !e.isEmpty else { return "" }
        return "Hechos recordados sobre el usuario (memoria):\n" + e.map { "- \($0)" }.joined(separator: "\n")
    }
}
