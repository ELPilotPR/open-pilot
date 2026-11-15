import Foundation

/// Un resultado de búsqueda global: un mensaje (o título) que coincide, con un
/// fragmento de contexto y la conversación a la que pertenece.
struct SearchHit: Identifiable, Equatable {
    let id: String
    let conversationID: UUID
    let conversationTitle: String
    let role: String
    let snippet: String
    let date: Date
}

/// Búsqueda global sobre todas las conversaciones (títulos + mensajes),
/// insensible a mayúsculas y diacríticos. Puro y testeable, sin red.
enum ConversationSearch {
    static func search(_ query: String, in conversations: [Conversation], limit: Int = 60) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var hits: [SearchHit] = []
        for c in conversations where !c.isTemporary {
            if let r = c.title.range(of: q, options: opts) {
                hits.append(SearchHit(id: "t-\(c.id.uuidString)", conversationID: c.id,
                                      conversationTitle: c.title, role: "title",
                                      snippet: snippet(c.title, around: r), date: c.createdAt))
            }
            for m in c.messages {
                if let r = m.text.range(of: q, options: opts) {
                    hits.append(SearchHit(id: m.id.uuidString, conversationID: c.id,
                                          conversationTitle: c.title, role: m.role,
                                          snippet: snippet(m.text, around: r), date: m.createdAt))
                }
            }
        }
        hits.sort { $0.date > $1.date }
        return Array(hits.prefix(limit))
    }

    /// Fragmento de ~`context` caracteres a cada lado de la coincidencia, con
    /// elipsis cuando se recorta y saltos de línea aplanados.
    static func snippet(_ text: String, around range: Range<String.Index>, context: Int = 40) -> String {
        let start = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        var s = String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
        if start > text.startIndex { s = "…" + s }
        if end < text.endIndex { s += "…" }
        return s
    }
}