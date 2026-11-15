import Foundation

/// Resumen local de una conversación. El modo extractivo funciona SIN red
/// (selección de frases por frecuencia de términos); el prompt de IA se envía
/// al provider configurado por el usuario (cliente directo, sin backend).
enum ConversationSummarizer {
    static let stopwords: Set<String> = [
        "el","la","los","las","un","una","de","del","y","o","en","con","por","para",
        "que","es","son","a","al","lo","se","su","sus","como","más","pero","muy",
        "the","an","of","and","or","to","in","on","for","with","is","are","was",
        "be","it","this","that","as","at","by","from","you","your","we","they"
    ]

    static func sentences(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    /// Resumen extractivo: puntúa frases por frecuencia de términos (con bonus
    /// para las primeras), elige las mejores y las devuelve en orden original.
    static func extractive(_ messages: [Message], maxBullets: Int = 5) -> [String] {
        let texts = messages.filter { $0.role == "user" || $0.role == "assistant" }.map { $0.text }
        var all: [(idx: Int, sentence: String)] = []
        for t in texts { for s in sentences(t) { all.append((all.count, s)) } }
        guard !all.isEmpty else { return [] }

        var freq: [String: Int] = [:]
        for item in all { for w in words(item.sentence) { freq[w, default: 0] += 1 } }

        var scored: [(idx: Int, sentence: String, score: Double)] = []
        for item in all {
            let ws = words(item.sentence)
            guard !ws.isEmpty else { continue }
            let sum = ws.reduce(0.0) { $0 + Double(freq[$1] ?? 0) }
            let posBonus = item.idx < 3 ? 1.5 : 1.0
            scored.append((item.idx, item.sentence, (sum / Double(ws.count)) * posBonus))
        }
        let chosen = scored.sorted { $0.score > $1.score }.prefix(maxBullets).sorted { $0.idx < $1.idx }
        var seen = Set<String>(); var out: [String] = []
        for c in chosen {
            let key = c.sentence.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            var s = c.sentence
            if s.count > 160 { s = String(s.prefix(160)) + "…" }
            out.append(s)
        }
        return out
    }

    /// Transcripción plana (conserva lo más reciente si excede el tope).
    static func transcript(_ messages: [Message], maxChars: Int = 6000) -> String {
        let lines = messages.filter { $0.role == "user" || $0.role == "assistant" }
            .map { ($0.role == "user" ? "Usuario" : "Asistente") + ": " + $0.text }
        var s = lines.joined(separator: "\n")
        if s.count > maxChars { s = String(s.suffix(maxChars)) }
        return s
    }

    static func aiPrompt(_ messages: [Message]) -> String {
        "Resume esta conversación en 3 a 5 viñetas concisas en el idioma predominante. "
        + "Captura decisiones, datos y conclusiones clave, sin relleno. Usa viñetas '- '.\n\n"
        + transcript(messages)
    }
}