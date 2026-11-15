import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Extrae texto de archivos adjuntos para enviarlo como contexto al modelo.
/// PDF vía PDFKit; texto/código/markdown/json/csv/html se leen como UTF-8.
enum FileAttachment {
    struct Parsed { let name: String; let text: String }

    /// Tope de caracteres por archivo para no saturar la ventana de contexto.
    static let maxChars = 60_000

    static var allowedTypes: [UTType] {
        var t: [UTType] = [.pdf, .plainText, .utf8PlainText, .sourceCode,
                           .json, .xml, .html, .commaSeparatedText, .rtf]
        if let md = UTType("net.daringfireball.markdown") { t.append(md) }
        return t
    }

    /// Lee el archivo (con acceso security-scoped) y devuelve nombre + texto.
    static func parse(url: URL) -> Parsed? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        var text: String?
        if ext == "pdf" {
            text = PDFDocument(url: url)?.string
        } else {
            if let d = try? Data(contentsOf: url) {
                text = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1)
            }
        }
        guard var t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        let marker = "\n…[contenido truncado]"
        if t.count > maxChars { t = String(t.prefix(maxChars - marker.count)) + marker }
        return Parsed(name: name, text: t)
    }
}
