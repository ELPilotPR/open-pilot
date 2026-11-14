import SwiftUI

/// Render de markdown: parrafos con formato inline (negrita/cursiva/codigo/enlaces),
/// encabezados, listas ANIDADAS, blockquotes, tablas, reglas horizontales y citas [n]
/// en accent. Bloques de codigo con etiqueta de lenguaje + resaltado de sintaxis + copiar.
/// Robusto durante streaming (fences abiertos). Todo on-device, sin dependencias.
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

// MARK: - Prosa (encabezados / listas anidadas / citas / tablas / hr / parrafos)

private enum PBlock {
    case heading(Int, String)
    case list([LItem])
    case quote(String)
    case table([[String]])
    case hr
    case para(String)
}
private struct LItem { var level: Int; var marker: String; var text: String }

private struct ProseView: View {
    let text: String
    var sources: [WebSource] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parseProse(text).enumerated()), id: \.offset) { _, b in
                blockView(b)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ b: PBlock) -> some View {
        switch b {
        case .heading(let level, let txt):
            Text(inline(txt, sources: sources))
                .font(level <= 1 ? .title3.bold() : (level == 2 ? .headline : .subheadline.bold()))
                .foregroundStyle(OP.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .list(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                    HStack(alignment: .top, spacing: 8) {
                        Text(it.marker)
                            .font(.body)
                            .foregroundStyle(OP.textSecondary)
                            .frame(minWidth: 18, alignment: .trailing)
                        Text(inline(it.text, sources: sources))
                            .font(.body)
                            .foregroundStyle(OP.textPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, CGFloat(it.level) * 18)
                }
            }
        case .quote(let q):
            Text(inline(q, sources: sources))
                .font(.body).italic()
                .foregroundStyle(OP.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.vertical, 2)
                .overlay(alignment: .leading) {
                    Rectangle().fill(OP.accent.opacity(0.7)).frame(width: 3)
                }
        case .table(let rows):
            MarkdownTableView(rows: rows, sources: sources)
        case .hr:
            Divider().padding(.vertical, 2)
        case .para(let s):
            Text(inline(s, sources: sources))
                .font(.body)
                .foregroundStyle(OP.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(OP.accent)
        }
    }
}

/// Parte la prosa en bloques respetando orden y anidacion (listas, citas, tablas, hr).
private func parseProse(_ text: String) -> [PBlock] {
    let lines = text.components(separatedBy: "\n")
    var out: [PBlock] = []
    var para: [String] = []
    var list: [LItem] = []
    var quote: [String] = []
    func flushPara() { if !para.isEmpty { out.append(.para(para.joined(separator: "\n"))); para = [] } }
    func flushList() { if !list.isEmpty { out.append(.list(list)); list = [] } }
    func flushQuote() { if !quote.isEmpty { out.append(.quote(quote.joined(separator: "\n"))); quote = [] } }
    func flushAll() { flushPara(); flushList(); flushQuote() }

    var i = 0
    while i < lines.count {
        let raw = lines[i]
        let t = raw.trimmingCharacters(in: .whitespaces)

        // Tabla: linea con | seguida de separador ---
        if t.contains("|"), i + 1 < lines.count, isTableSep(lines[i + 1]) {
            flushAll()
            var rows = [tableCells(t)]
            i += 2
            while i < lines.count {
                let lt = lines[i].trimmingCharacters(in: .whitespaces)
                if lt.isEmpty || !lt.contains("|") { break }
                rows.append(tableCells(lt)); i += 1
            }
            out.append(.table(rows)); continue
        }
        // Regla horizontal
        if t.range(of: #"^(-{3,}|\*{3,}|_{3,})$"#, options: .regularExpression) != nil {
            flushAll(); out.append(.hr); i += 1; continue
        }
        // Encabezado
        if t.hasPrefix("#"), let r = t.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            flushAll()
            let level = t[r].filter { $0 == "#" }.count
            let txt = String(t[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            out.append(.heading(level, txt)); i += 1; continue
        }
        // Blockquote
        if t.hasPrefix(">") {
            flushPara(); flushList()
            quote.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
            i += 1; continue
        } else { flushQuote() }
        // Item de lista (con nivel por indentacion)
        if let item = listItem(raw) {
            flushPara()
            list.append(item); i += 1; continue
        }
        // Continuacion indentada de un item de lista
        if !list.isEmpty, !t.isEmpty, raw.hasPrefix("  ") {
            list[list.count - 1].text += "\n" + t; i += 1; continue
        }
        flushList()
        if t.isEmpty { flushPara(); i += 1; continue }
        para.append(t); i += 1
    }
    flushAll()
    return out
}

private func listItem(_ raw: String) -> LItem? {
    let indent = raw.prefix(while: { $0 == " " || $0 == "\t" }).reduce(0) { $0 + ($1 == "\t" ? 2 : 1) }
    let t = raw.trimmingCharacters(in: .whitespaces)
    let level = indent / 2
    if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") {
        return LItem(level: level, marker: "•", text: String(t.dropFirst(2)))
    }
    if let r = t.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
        let marker = String(t[r]).trimmingCharacters(in: .whitespaces)
        return LItem(level: level, marker: marker, text: String(t[r.upperBound...]))
    }
    return nil
}

private func isTableSep(_ line: String) -> Bool {
    let s = line.trimmingCharacters(in: .whitespaces)
    guard s.contains("-") else { return false }
    return s.range(of: #"^\|?[\s:\-|]+\|?$"#, options: .regularExpression) != nil
}

private func tableCells(_ line: String) -> [String] {
    var t = line.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("|") { t.removeFirst() }
    if t.hasSuffix("|") { t.removeLast() }
    return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
}

/// Tabla markdown como grid alineado (legible, no pipes crudos).
private struct MarkdownTableView: View {
    let rows: [[String]]
    var sources: [WebSource] = []
    private var cols: Int { rows.map(\.count).max() ?? 0 }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    GridRow {
                        ForEach(Array(0..<cols), id: \.self) { c in
                            Text(inline(c < row.count ? row[c] : "", sources: sources))
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

// MARK: - Bloque de codigo con resaltado de sintaxis

struct CodeBlockView: View {
    let lang: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.isEmpty ? T("code", "código") : lang)
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
                        Text(copied ? T("Copied", "Copiado") : T("Copy", "Copiar"))
                    }
                    .font(.caption2)
                    .foregroundStyle(OP.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(OP.elevated)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(SyntaxHighlighter.highlight(code.trimmingCharacters(in: .newlines), lang: lang))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(OP.codeBlock)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(OP.border, lineWidth: 1))
    }
}

/// Resaltado de sintaxis ligero y on-device (sin dependencias): comentarios, strings,
/// numeros, palabras clave y tipos. Colores adaptativos light/dark estilo Xcode.
enum SyntaxHighlighter {
    private static let cComment = OP.dyn("#6A737D", "#7F8C98")
    private static let cString  = OP.dyn("#C41A16", "#FC6A5D")
    private static let cKeyword = OP.dyn("#AD3DA4", "#FF7AB2")
    private static let cNumber  = OP.dyn("#1C00CF", "#D0BF69")
    private static let cType    = OP.dyn("#3900A0", "#5DD8FF")

    private static let hashLangs: Set<String> = ["python", "py", "bash", "sh", "shell", "ruby", "rb", "yaml", "yml", "toml", "perl", "r"]
    private static let dashLangs: Set<String> = ["sql", "lua", "haskell"]
    private static let slashLangs: Set<String> = ["swift", "js", "javascript", "ts", "typescript", "java", "c", "cpp", "c++", "cs", "csharp", "go", "rust", "rs", "kotlin", "json", "php", "css", "scss", "dart", "scala"]

    static func highlight(_ code: String, lang: String) -> AttributedString {
        let l = lang.lowercased()
        let words = keywords(for: l)
        let hash = hashLangs.contains(l)
        let dash = dashLangs.contains(l)
        let slash = slashLangs.contains(l) || (!hash && !dash)
        let js = (l == "js" || l == "javascript" || l == "ts" || l == "typescript")
        var parts: [String] = [
            ##""(?:\\.|[^"\\])*""##,
            ##"'(?:\\.|[^'\\])*'"##,
        ]
        if js { parts.append(##"`(?:\\.|[^`\\])*`"##) }
        parts.append(##"/\*[\s\S]*?\*/"##)
        if slash { parts.append(##"//[^\n]*"##) }
        if hash { parts.append(##"#[^\n]*"##) }
        if dash { parts.append(##"--[^\n]*"##) }
        parts.append(##"\b\d+(?:\.\d+)?\b"##)
        parts.append(##"[A-Za-z_][A-Za-z0-9_]*"##)
        let pattern = parts.joined(separator: "|")
        guard let re = try? NSRegularExpression(pattern: pattern) else { return seg(code, OP.textPrimary) }
        let ns = code as NSString
        var result = AttributedString()
        var cursor = 0
        for m in re.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
            let r = m.range
            if r.location > cursor {
                result += seg(ns.substring(with: NSRange(location: cursor, length: r.location - cursor)), OP.textPrimary)
            }
            let tok = ns.substring(with: r)
            result += seg(tok, color(tok, words: words, compiled: slash))
            cursor = r.location + r.length
        }
        if cursor < ns.length {
            result += seg(ns.substring(with: NSRange(location: cursor, length: ns.length - cursor)), OP.textPrimary)
        }
        return result
    }

    private static func seg(_ s: String, _ color: Color) -> AttributedString {
        var a = AttributedString(s)
        a.foregroundColor = color
        return a
    }

    private static func color(_ tok: String, words: Set<String>, compiled: Bool) -> Color {
        if tok.hasPrefix("\"") || tok.hasPrefix("'") || tok.hasPrefix("`") { return cString }
        if tok.hasPrefix("//") || tok.hasPrefix("/*") || tok.hasPrefix("#") || tok.hasPrefix("--") { return cComment }
        if let f = tok.first, f.isNumber { return cNumber }
        if words.contains(tok) { return cKeyword }
        if compiled, let f = tok.first, f.isUppercase { return cType }
        return OP.textPrimary
    }

    private static func keywords(for l: String) -> Set<String> {
        switch l {
        case "swift":
            return Set("func let var if else guard return for while in switch case break continue struct class enum protocol extension import init self nil true false static private public internal override throws try catch async await do defer where as is some any typealias final open repeat default lazy weak".split(separator: " ").map(String.init))
        case "python", "py":
            return Set("def return if elif else for while in import from as class try except finally with lambda pass break continue and or not is None True False global yield raise assert del async await".split(separator: " ").map(String.init))
        case "js", "javascript", "ts", "typescript":
            return Set("function return if else for while do switch case break continue var let const new typeof instanceof this class extends super import export from default try catch finally throw async await yield of in delete void null true undefined static get set".split(separator: " ").map(String.init))
        case "bash", "sh", "shell":
            return Set("if then else fi for while do done case esac function echo return exit local export set".split(separator: " ").map(String.init))
        case "json":
            return Set(["true", "false", "null"])
        default:
            return Set("if else for while return func function let var const class struct enum import export true false null nil none def switch case break continue new try catch async await public private static".split(separator: " ").map(String.init))
        }
    }
}
