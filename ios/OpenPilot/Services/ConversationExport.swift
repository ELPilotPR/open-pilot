import Foundation
import SwiftData
import UIKit
import CoreText

/// Export/import de conversaciones 100% local (sin backend).
/// - JSON: fiel, incluye el árbol de versiones, razonamiento y adjuntos.
/// - Markdown: legible, sobre la rama activa.
/// - PDF: paginado (CoreText), sobre la rama activa.
/// El import reconstruye una conversación nueva con ids remapeados (sin colisiones).
enum ConversationExport {

    // MARK: - Documento portable

    struct Document: Codable {
        var format: String = "openpilot.chat"
        var version: Int = 1
        var title: String
        var createdAt: Date
        var providerID: String
        var model: String
        var activeLeafID: UUID?
        var messages: [Item]
    }

    struct Item: Codable {
        var id: UUID
        var role: String
        var text: String
        var reasoning: String
        var createdAt: Date
        var parentID: UUID?
        var version: Int
        var preferredChildID: UUID?
        var feedback: Int
        var sourcesData: Data
        var imageData: Data
        var attachmentName: String?
        var attachmentText: String?
        var weatherData: Data
        var currencyData: Data
        var citationsData: Data
        var promptTokens: Int
        var completionTokens: Int
        var tokensPerSecond: Double
    }

    static func document(_ c: Conversation) -> Document {
        Document(
            title: c.title,
            createdAt: c.createdAt,
            providerID: c.providerID,
            model: c.model,
            activeLeafID: c.activeLeafID,
            messages: c.sortedMessages.map { m in
                Item(
                    id: m.id, role: m.role, text: m.text, reasoning: m.reasoning,
                    createdAt: m.createdAt, parentID: m.parentID, version: m.version,
                    preferredChildID: m.preferredChildID, feedback: m.feedback,
                    sourcesData: m.sourcesData, imageData: m.imageData,
                    attachmentName: m.attachmentName, attachmentText: m.attachmentText,
                    weatherData: m.weatherData, currencyData: m.currencyData,
                    citationsData: m.citationsData, promptTokens: m.promptTokens,
                    completionTokens: m.completionTokens, tokensPerSecond: m.tokensPerSecond
                )
            }
        )
    }

    // MARK: - JSON

    static func jsonData(_ c: Conversation) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(document(c))
    }

    static func decode(_ data: Data) throws -> Document {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Document.self, from: data)
    }

    /// Reconstruye el documento como conversación nueva. Remapea los ids antiguos
    /// a nuevos para preservar el árbol de versiones sin colisionar con lo existente.
    @discardableResult
    static func materialize(_ doc: Document, into context: ModelContext) -> Conversation {
        let c = Conversation(title: doc.title, providerID: doc.providerID, model: doc.model)
        c.createdAt = doc.createdAt
        var idMap: [UUID: UUID] = [:]
        var news: [Message] = []
        for item in doc.messages {
            let m = Message(role: item.role, text: item.text, reasoning: item.reasoning)
            m.createdAt = item.createdAt
            m.version = item.version
            m.feedback = item.feedback
            m.sourcesData = item.sourcesData
            m.imageData = item.imageData
            m.attachmentName = item.attachmentName
            m.attachmentText = item.attachmentText
            m.weatherData = item.weatherData
            m.currencyData = item.currencyData
            m.citationsData = item.citationsData
            m.promptTokens = item.promptTokens
            m.completionTokens = item.completionTokens
            m.tokensPerSecond = item.tokensPerSecond
            idMap[item.id] = m.id
            news.append(m)
            context.insert(m)
        }
        for (item, m) in zip(doc.messages, news) {
            m.parentID = item.parentID.flatMap { idMap[$0] }
            m.preferredChildID = item.preferredChildID.flatMap { idMap[$0] }
            m.conversation = c
        }
        c.messages = news
        c.activeLeafID = doc.activeLeafID.flatMap { idMap[$0] }
        context.insert(c)
        c.ensureTree()
        try? context.save()
        return c
    }

    @discardableResult
    static func importJSON(_ data: Data, into context: ModelContext) throws -> Conversation {
        materialize(try decode(data), into: context)
    }

    // MARK: - Markdown (rama activa)

    static func markdown(_ c: Conversation) -> String {
        let title = c.title.isEmpty ? "New chat" : c.title
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var lines = ["# \(title)", "", "_\(c.model) · \(df.string(from: c.createdAt))_", ""]
        for m in c.activeMessages {
            let who = m.role == "user" ? "You" : (m.role == "assistant" ? "Assistant" : m.role.capitalized)
            lines.append("## \(who)")
            lines.append("")
            if !m.reasoning.isEmpty {
                lines.append("> **Reasoning**")
                for r in m.reasoning.split(separator: "\n") { lines.append("> \(r)") }
                lines.append("")
            }
            lines.append(m.text.isEmpty ? "_(empty)_" : m.text)
            lines.append("")
        }
        lines.append("---")
        lines.append("_Exported from Open Pilot_")
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF (rama activa, paginado con CoreText)

    static func pdf(_ c: Conversation) -> Data {
        let title = c.title.isEmpty ? "New chat" : c.title
        let pageW: CGFloat = 612, pageH: CGFloat = 792, margin: CGFloat = 54
        let contentW = pageW - margin * 2
        let textRect = CGRect(x: margin, y: margin, width: contentW, height: pageH - margin * 2)

        let body = NSMutableParagraphStyle(); body.lineSpacing = 3; body.paragraphSpacing = 10
        let header = NSMutableParagraphStyle(); header.paragraphSpacingBefore = 8; header.paragraphSpacing = 4
        let accent = UIColor(red: 0.27, green: 0.47, blue: 0.98, alpha: 1)

        let full = NSMutableAttributedString()
        func add(_ s: String, _ font: UIFont, _ color: UIColor, _ style: NSParagraphStyle) {
            full.append(NSAttributedString(string: s + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: style
            ]))
        }
        add(title, .systemFont(ofSize: 22, weight: .bold), .black, header)
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        add("\(c.model) · \(df.string(from: c.createdAt))", .systemFont(ofSize: 11), .darkGray, body)
        for m in c.activeMessages {
            let who = m.role == "user" ? "You" : "Assistant"
            add(who, .systemFont(ofSize: 13, weight: .semibold), accent, header)
            if !m.text.isEmpty { add(m.text, .systemFont(ofSize: 12), .black, body) }
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return renderer.pdfData { ctx in
            let framesetter = CTFramesetterCreateWithAttributedString(full)
            let total = full.length
            var loc = 0
            var pages = 0
            while loc < total && pages < 1000 {
                ctx.beginPage()
                // El contexto de UIGraphicsPDFRenderer viene con el eje Y invertido
                // (origen arriba-izquierda). CoreText dibuja y-hacia-arriba, así que
                // se voltea una vez para que el texto quede derecho y empiece arriba.
                let cg = ctx.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: pageH)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: textRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: loc, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                let visible = CTFrameGetVisibleStringRange(frame)
                cg.restoreGState()
                if visible.length == 0 { break }
                loc += visible.length
                pages += 1
            }
        }
    }

    // MARK: - Utilidades de archivo

    /// Nombre de archivo seguro a partir del título (sin separadores de ruta).
    static func fileName(_ title: String, ext: String) -> String {
        let base = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = base.unicodeScalars.map { s -> Character in
            let c = Character(s)
            return "/\\:?%*|\"<>".contains(c) ? "-" : c
        }
        let name = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = name.isEmpty ? "chat" : String(name.prefix(60))
        return "\(stem).\(ext)"
    }
}