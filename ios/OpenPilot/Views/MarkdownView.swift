import SwiftUI

/// Render de markdown: parrafos con formato inline (negrita/cursiva/
/// codigo/enlaces), encabezados, listas, citas [n] en accent, y bloques de codigo
/// con etiqueta de lenguaje + boton copiar. Robusto durante streaming (fences abiertos).
struct MarkdownView: View {
    let text: String
    var sources: [WebSource] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let lang, let code):
                    CodeBlockView(lang: lang, code: code)
                case .prose(let s):
                    ProseView(text: s, sources: sources)
                }
            }
        }
    }

    enum Block { case code(String, String); case prose(String) }

    private var blocks: [Block] {
        var out: [Block] = []
        let ns = text as NSString
        let re = try? NSRegularExpression(pattern: "```([^\\n`]*)\\n?([\\s\\S]*?)(?:```|$)")
        var cursor = 0
        for m in re?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
            let r = m.range
            if r.location > cursor {
                let p = ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
                if !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(.prose(p)) }
            }
            let lang = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces) : ""
            let code = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : ""
            out.append(.code(lang, code))
            cursor = r.location + r.length
        }
        if cursor < ns.length {
            let p = ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            if !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(.prose(p)) }
        }
        if out.isEmpty { out.append(.prose(text)) }
        return out
    }
}

/// Texto en prosa: encabezados, listas y parrafos con markdown inline + citas.
private struct ProseView: View {
    let text: String
    var sources: [WebSource] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                paragraphView(p)
            }
        }
    }

    private var paragraphs: [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func paragraphView(_ p: String) -> some View {
        let lines = p.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let rows = parseTable(lines) {
            MarkdownTableView(rows: rows)
        } else if let first = lines.first, first.hasPrefix("#") {
            let level = first.prefix(while: { $0 == "#" }).count
            let txt = first.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            Text(inline(txt, sources: sources))
                .font(level <= 1 ? .title3.bold() : (level == 2 ? .headline : .subheadline.bold()))
                .foregroundStyle(OP.textPrimary)
        } else if lines.allSatisfy({ isListItem($0) }) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(bulletMarker(line))
                            .font(.body)
                            .foregroundStyle(OP.textSecondary)
                        Text(inline(stripMarker(line), sources: sources))
                            .font(.body)
                            .foregroundStyle(OP.textPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            Text(inline(p, sources: sources))
                .font(.body)
                .foregroundStyle(OP.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(OP.accent)
        }
    }

    private func isListItem(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") { return true }
        if let r = t.range(of: #"^\d+[.)]\s"#, options: .regularExpression) { return r.lowerBound == t.startIndex }
        return false
    }
    private func bulletMarker(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let r = t.range(of: #"^\d+[.)]"#, options: .regularExpression) { return String(t[r]) }
        return "•"
    }
    private func stripMarker(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if let r = t.range(of: #"^(\d+[.)]\s|[-*•]\s)"#, options: .regularExpression) { t.removeSubrange(r) }
        return t
    }

    private func parseTable(_ lines: [String]) -> [[String]]? {
        guard lines.count >= 2, lines[0].contains("|") else { return nil }
        let sep = lines[1].trimmingCharacters(in: .whitespaces)
        guard sep.contains("-"),
              sep.range(of: #"^\|?[\s:\-|]+\|?$"#, options: .regularExpression) != nil else { return nil }
        func cells(_ line: String) -> [String] {
            var t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("|") { t.removeFirst() }
            if t.hasSuffix("|") { t.removeLast() }
            return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var rows = [cells(lines[0])]
        for l in lines.dropFirst(2) where l.contains("|") { rows.append(cells(l)) }
        return rows.count >= 2 ? rows : nil
    }
}

/// Tabla markdown como grid alineado (legible, no pipes crudos).
private struct MarkdownTableView: View {
    let rows: [[String]]
    private var cols: Int { rows.map(\.count).max() ?? 0 }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    GridRow {
                        ForEach(Array(0..<cols), id: \.self) { c in
                            Text(inline(c < row.count ? row[c] : ""))
                                .font(r == 0 ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(r == 0 ? OP.textPrimary : OP.textSecondary)
                                .lineSpacing(2)
                        }
                    }
                    if r == 0 { Divider().gridCellColumns(cols) }
                }
            }
            .padding(12)
        }
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(OP.border, lineWidth: 1))
    }
}

/// Markdown inline + citas [n] como superindice accent TAPABLE (abre la fuente).
func inline(_ s: String, sources: [WebSource] = []) -> AttributedString {
    var attr = (try? AttributedString(
        markdown: s,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
    )) ?? AttributedString(s)
    let str = String(attr.characters)
    var searchStart = str.startIndex
    while let r = str.range(of: #"\[(\d+)\]"#, options: .regularExpression, range: searchStart..<str.endIndex) {
        let off = str.distance(from: str.startIndex, to: r.lowerBound)
        let len = str.distance(from: r.lowerBound, to: r.upperBound)
        let sIdx = attr.index(attr.startIndex, offsetByCharacters: off)
        let eIdx = attr.index(sIdx, offsetByCharacters: len)
        let marker = String(str[r])
        let n = Int(marker.dropFirst().dropLast()) ?? 0
        attr[sIdx..<eIdx].font = .caption2.weight(.bold)
        attr[sIdx..<eIdx].baselineOffset = 5
        if n >= 1, n <= sources.count, let u = URL(string: sources[n - 1].url) {
            attr[sIdx..<eIdx].link = u
            attr[sIdx..<eIdx].foregroundColor = OP.accent
        } else {
            attr[sIdx..<eIdx].foregroundColor = OP.textTertiary
        }
        searchStart = r.upperBound
    }
    return attr
}

/// Bloque de codigo con cabecera (lenguaje + copiar) y panel monoespaciado.
struct CodeBlockView: View {
    let lang: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.isEmpty ? "código" : lang)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(OP.textTertiary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    Haptic.success()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copiado" : "Copiar")
                    }
                    .font(.caption2)
                    .foregroundStyle(OP.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(OP.elevated)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(OP.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(OP.codeBlock)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(OP.border, lineWidth: 1))
    }
}
