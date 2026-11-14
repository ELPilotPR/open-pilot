import Foundation

/// Cita estructurada con el contrato `content_references[]`:
/// `{type, name, start_idx, end_idx, category}`. Se sintetiza EN CLIENTE a partir
/// de los marcadores [n] que el modelo escribe y las fuentes web que la app
/// inyectó (se derivan del texto + [WebSource]). `startIdx`/`endIdx` son offsets
/// de CARACTERES sobre el texto del mensaje.
struct CitationReference: Codable, Identifiable {
    var type: String = "entity"
    var name: String                 // nombre visible (dominio de la fuente)
    var startIdx: Int
    var endIdx: Int
    var category: String? = "web"
    var url: String
    var title: String
    var snippet: String? = nil

    var id: String { "\(startIdx)-\(endIdx)-\(url)" }

    enum CodingKeys: String, CodingKey {
        case type, name, category, url, title, snippet
        case startIdx = "start_idx"
        case endIdx = "end_idx"
    }

    /// Dominio legible (sin "www.") para mostrar en la píldora.
    static func domain(of urlString: String) -> String {
        guard let h = URL(string: urlString)?.host else { return urlString }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    /// Recorre el texto buscando [n] y lo mapea a sources[n-1], produciendo una
    /// referencia con el span exacto (start_idx/end_idx) del marcador.
    static func parse(text: String, sources: [WebSource]) -> [CitationReference] {
        guard !sources.isEmpty,
              let re = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else { return [] }
        let ns = text as NSString
        var out: [CitationReference] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges >= 2 else { continue }
            let numStr = ns.substring(with: m.range(at: 1))
            guard let n = Int(numStr), n >= 1, n <= sources.count else { continue }
            let src = sources[n - 1]
            let lower = String.Index(utf16Offset: m.range.location, in: text)
            let upper = String.Index(utf16Offset: m.range.location + m.range.length, in: text)
            let start = text.distance(from: text.startIndex, to: lower)
            let end = text.distance(from: text.startIndex, to: upper)
            out.append(CitationReference(
                name: domain(of: src.url),
                startIdx: start, endIdx: end,
                url: src.url, title: src.title,
                snippet: src.snippet.isEmpty ? nil : src.snippet
            ))
        }
        return out.sorted { $0.startIdx < $1.startIdx }
    }
}