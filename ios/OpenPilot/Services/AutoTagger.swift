import Foundation

/// Auto-etiquetado local de conversaciones (sin red): detecta temas por
/// palabras clave y extrae términos frecuentes. La variante IA usa el provider
/// del usuario (cliente directo, sin backend).
enum AutoTagger {
    /// Vocabulario de temas con disparadores bilingües (es/en).
    static let topics: [(tag: String, triggers: [String])] = [
        ("code", ["swift","python","javascript","typescript","code","código","función","function","api","bug","program","git","react","sql","css","html","rust","compile","debug","swiftui"]),
        ("design", ["design","diseño","ui","ux","figma","color","layout","logo","interface","tipografía"]),
        ("writing", ["write","escribir","essay","ensayo","blog","story","historia","poem","poema","email","correo","redactar","guión"]),
        ("research", ["research","investigar","study","estudio","paper","analysis","análisis","compare","comparar","fuente"]),
        ("travel", ["travel","viaje","flight","vuelo","hotel","trip","vacation","vacaciones","turismo"]),
        ("food", ["food","comida","recipe","receta","cook","cocinar","restaurant","meal","ingrediente"]),
        ("health", ["health","salud","medical","médico","exercise","ejercicio","diet","dieta","sleep","sueño"]),
        ("finance", ["finance","finanzas","money","dinero","budget","presupuesto","invest","invertir","stock","tax","impuesto","crypto"]),
        ("learning", ["learn","aprender","tutorial","course","curso","explain","explica","teach","enseñar","lesson"]),
        ("work", ["work","trabajo","meeting","reunión","project","proyecto","deadline","client","cliente","business","negocio"]),
    ]

    static func topicTags(_ text: String, max: Int = 4) -> [String] {
        let lower = text.lowercased()
        var hits: [(String, Int)] = []
        for t in topics {
            let n = t.triggers.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            if n > 0 { hits.append((t.tag, n)) }
        }
        return hits.sorted { $0.1 > $1.1 }.prefix(max).map { $0.0 }
    }

    static func keywords(_ text: String, max: Int = 3) -> [String] {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !ConversationSummarizer.stopwords.contains($0) }
        var freq: [String: Int] = [:]
        for w in words { freq[w, default: 0] += 1 }
        return freq.sorted { $0.value > $1.value }.prefix(max).map { $0.key }
    }

    /// Etiquetas combinadas: temas detectados + algún término frecuente.
    static func tags(for messages: [Message], max: Int = 6) -> [String] {
        let text = messages.filter { $0.role == "user" || $0.role == "assistant" }.map { $0.text }.joined(separator: " ")
        var out = topicTags(text)
        for k in keywords(text) where !out.contains(k) { out.append(k) }
        return Array(out.prefix(max))
    }

    static func aiPrompt(_ messages: [Message]) -> String {
        let text = messages.filter { $0.role == "user" || $0.role == "assistant" }
            .map { $0.text }.joined(separator: "\n")
        let trimmed = text.count > 4000 ? String(text.suffix(4000)) : text
        return "Generate 3 to 6 short lowercase tags for this conversation. "
        + "Return ONLY a comma-separated list of tags, no explanation, no hashtags.\n\n" + trimmed
    }

    /// Normaliza la salida del modelo a una lista de etiquetas limpias.
    static func parseAITags(_ raw: String, max: Int = 8) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for part in raw.components(separatedBy: CharacterSet(charactersIn: ",\n")) {
            var t = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            while t.hasPrefix("#") { t.removeFirst() }
            t = t.trimmingCharacters(in: .whitespaces)
            guard t.count >= 2, t.count <= 24, !seen.contains(t) else { continue }
            seen.insert(t); out.append(t)
            if out.count >= max { break }
        }
        return out
    }
}