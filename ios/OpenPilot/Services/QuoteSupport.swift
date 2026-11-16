import Foundation

/// Citar un mensaje en el composer: lo convierte en un blockquote Markdown acotado
/// para que el modelo vea a qué texto se refiere el usuario sin inundar el composer.
enum QuoteSupport {
    /// Máximo de caracteres citados.
    static let maxChars = 600

    static func blockquote(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }
        let clipped = String(clean.prefix(maxChars))
        var out = clipped
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> " + $0 }
            .joined(separator: "\n")
        if clean.count > maxChars { out += "\n> …" }
        return out
    }
}