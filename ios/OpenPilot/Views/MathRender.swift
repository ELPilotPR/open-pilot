import SwiftUI
import SwiftMath
import UIKit

/// Render de matemáticas LaTeX 100% nativo (SwiftMath / iosMath, CoreText).
/// Sin webview ni backend: cada fórmula se typeset a UIImage y se cachea.
/// Soporta display ($$…$$, \[…\]) e inline ($…$, \(…\)). Los precios en $
/// (p.ej. "$5") NO se interpretan como fórmula.

// MARK: - Segmentos

enum MathSegment: Equatable {
    case text(String)
    case inlineMath(String)
    case displayMath(String)
}

/// Divide un texto en tramos de texto plano y fórmulas (display/inline).
func parseMathSegments(_ s: String) -> [MathSegment] {
    let chars = Array(s)
    var out: [MathSegment] = []
    var text = ""
    var i = 0
    func flushText() { if !text.isEmpty { out.append(.text(text)); text = "" } }

    while i < chars.count {
        // Display $$…$$
        if chars[i] == "$", i + 1 < chars.count, chars[i + 1] == "$" {
            if let end = mathClose(chars, from: i + 2, delim: ["$", "$"]) {
                let inner = String(chars[(i + 2)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                flushText(); out.append(.displayMath(inner)); i = end + 2; continue
            }
        }
        // Display \[…\]
        if chars[i] == "\\", i + 1 < chars.count, chars[i + 1] == "[" {
            if let end = mathClose(chars, from: i + 2, delim: ["\\", "]"]) {
                let inner = String(chars[(i + 2)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                flushText(); out.append(.displayMath(inner)); i = end + 2; continue
            }
        }
        // Inline \(…\)
        if chars[i] == "\\", i + 1 < chars.count, chars[i + 1] == "(" {
            if let end = mathClose(chars, from: i + 2, delim: ["\\", ")"]) {
                let inner = String(chars[(i + 2)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                flushText(); out.append(.inlineMath(inner)); i = end + 2; continue
            }
        }
        // Inline $…$ (con guarda anti-precios)
        if chars[i] == "$", let end = inlineDollarEnd(chars, from: i + 1) {
            let inner = String(chars[(i + 1)..<end])
            flushText(); out.append(.inlineMath(inner)); i = end + 1; continue
        }
        text.append(chars[i]); i += 1
    }
    flushText()
    return out
}

/// ¿El texto contiene alguna fórmula (inline o display)?
func containsMath(_ s: String) -> Bool {
    parseMathSegments(s).contains { if case .text = $0 { return false }; return true }
}

private func mathClose(_ chars: [Character], from: Int, delim: [Character]) -> Int? {
    var i = from
    while i + delim.count <= chars.count {
        if Array(chars[i..<(i + delim.count)]) == delim { return i }
        i += 1
    }
    return nil
}

/// Busca el $ de cierre de una fórmula inline; nil si no es fórmula válida.
private func inlineDollarEnd(_ chars: [Character], from: Int) -> Int? {
    var j = from
    while j < chars.count {
        if chars[j] == "$" {
            // no cerrar en un $$ (display)
            if j + 1 < chars.count, chars[j + 1] == "$" { return nil }
            let inner = Array(chars[from..<j])
            return isMathInner(inner) ? j : nil
        }
        if chars[j] == "\n" { return nil }
        j += 1
    }
    return nil
}

/// Evita falsos positivos de precios: exige contenido sin espacios en los
/// bordes, sin saltos de línea, y con algún indicador matemático o letra.
private func isMathInner(_ inner: [Character]) -> Bool {
    guard let first = inner.first, let last = inner.last, !inner.isEmpty else { return false }
    if first == " " || last == " " || first == "\n" || last == "\n" { return false }
    if inner.contains("\n") { return false }
    let indicators: Set<Character> = ["\\", "^", "_", "{", "}", "="]
    if inner.contains(where: { indicators.contains($0) }) { return true }
    return inner.contains(where: { $0.isLetter })
}

// MARK: - Imagen de fórmula (cacheada)

struct MathImageView: View {
    let latex: String
    var display: Bool = false
    var fontSize: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let img = Self.render(latex, fontSize: fontSize, display: display, dark: scheme == .dark) {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .fixedSize()
                .frame(maxWidth: display ? .infinity : nil, alignment: .center)
                .accessibilityLabel(Text(latex))
        } else {
            Text(latex)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(OP.textSecondary)
        }
    }

    private static let cache = NSCache<NSString, UIImage>()

    static func render(_ latex: String, fontSize: CGFloat, display: Bool, dark: Bool) -> UIImage? {
        let key = "\(latex)|\(fontSize)|\(display)|\(dark)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let color = MTColor(dark ? Color(white: 0.93) : Color(white: 0.10))
        let renderer = MTMathImage(
            latex: trimmed,
            fontSize: fontSize,
            textColor: color,
            labelMode: display ? .display : .text,
            textAlignment: .center
        )
        let (error, image) = renderer.asImage()
        guard error == nil, let image else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Texto con fórmulas inline

/// Renderiza un texto que puede mezclar prosa y fórmulas. Usa un único `Text`
/// concatenado (prosa con markdown + imágenes inline) para conservar negritas,
/// wrap natural y espaciado de puntuación correcto. Una única fórmula display
/// se centra en bloque.
struct MathText: View {
    let text: String
    var sources: [WebSource] = []
    var font: Font = .body
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let segs = parseMathSegments(text)
        if segs.count == 1, case .displayMath(let f) = segs[0] {
            MathImageView(latex: f, display: true, fontSize: 22)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else {
            concat(segs)
                .font(font)
                .foregroundStyle(OP.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(OP.accent)
        }
    }

    private func concat(_ segs: [MathSegment]) -> Text {
        var result = Text("")
        for seg in segs {
            switch seg {
            case .text(let t):
                result = result + Text(inline(t, sources: sources))
            case .inlineMath(let f):
                result = result + mathText(f, display: false, size: 17)
            case .displayMath(let f):
                result = result + Text("\n") + mathText(f, display: true, size: 20) + Text("\n")
            }
        }
        return result
    }

    private func mathText(_ latex: String, display: Bool, size: CGFloat) -> Text {
        if let img = MathImageView.render(latex, fontSize: size, display: display, dark: scheme == .dark) {
            return Text(Image(uiImage: img))
        }
        return Text(latex).font(.system(.body, design: .monospaced))
    }
}
