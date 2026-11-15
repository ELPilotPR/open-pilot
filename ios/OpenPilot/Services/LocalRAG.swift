import Foundation
import NaturalLanguage

/// Fragmento de un adjunto indexable.
struct RAGChunk: Identifiable, Equatable {
    let id: Int
    let text: String
    let source: String
}

/// RAG local sobre los adjuntos de la conversación: trocea, embebe con
/// NaturalLanguage (en el dispositivo, SIN red) y recupera por similitud coseno.
enum LocalRAG {
    /// Trocea por párrafos y empaqueta en fragmentos de hasta maxChars.
    static func chunk(_ text: String, source: String, maxChars: Int = 600) -> [RAGChunk] {
        let paras = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var chunks: [RAGChunk] = []
        var buf = ""
        func flush() {
            let t = buf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { chunks.append(RAGChunk(id: chunks.count, text: t, source: source)) }
            buf = ""
        }
        for p in paras {
            if p.count > maxChars {
                flush()
                var start = p.startIndex
                while start < p.endIndex {
                    let end = p.index(start, offsetBy: maxChars, limitedBy: p.endIndex) ?? p.endIndex
                    chunks.append(RAGChunk(id: chunks.count, text: String(p[start..<end]), source: source))
                    start = end
                }
            } else if buf.count + p.count + 1 > maxChars {
                flush(); buf = p
            } else {
                buf += (buf.isEmpty ? "" : " ") + p
            }
        }
        flush()
        return chunks
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i] }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    /// Ordena items (chunk, vector) por similitud coseno contra la query.
    static func rank(query: [Double], items: [(RAGChunk, [Double])], k: Int) -> [(RAGChunk, Double)] {
        items.map { ($0.0, cosine(query, $0.1)) }
            .sorted { $0.1 > $1.1 }
            .prefix(k).map { $0 }
    }

    static func embed(_ text: String, language: NLLanguage = .english) -> [Double]? {
        guard let emb = NLEmbedding.sentenceEmbedding(for: language) else { return nil }
        return emb.vector(for: text)
    }

    static func retrieve(query: String, chunks: [RAGChunk], k: Int = 4,
                         language: NLLanguage = .english) -> [(RAGChunk, Double)] {
        guard let qv = embed(query, language: language) else { return [] }
        let scored = chunks.compactMap { c -> (RAGChunk, Double)? in
            guard let v = embed(c.text, language: language) else { return nil }
            return (c, cosine(qv, v))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(k).map { $0 }
    }

    /// Contexto recuperado para una pregunta sobre los adjuntos (vacío si no hay
    /// embeddings disponibles o nada relevante).
    static func context(query: String, attachments: [(name: String, text: String)],
                        k: Int = 4, language: NLLanguage = .english) -> String {
        let chunks = attachments.flatMap { chunk($0.text, source: $0.name) }
        let top = retrieve(query: query, chunks: chunks, k: k, language: language)
        guard !top.isEmpty else { return "" }
        return top.map { "[\($0.0.source)] \($0.0.text)" }.joined(separator: "\n\n")
    }

    static func qaPrompt(question: String, context: String) -> String {
        "Answer the question using ONLY the context below. If the answer is not in the context, say so. "
        + "Cite the source name in brackets when relevant.\n\nCONTEXT:\n\(context)\n\nQUESTION: \(question)"
    }
}