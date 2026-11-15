import Foundation

/// Helpers puros para el texto extraído de documentos escaneados.
enum DocumentScanSupport {
    static func joinPages(_ pages: [String]) -> String {
        pages.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    static func clean(_ s: String) -> String {
        var t = s
        while t.contains("\n\n\n") { t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}