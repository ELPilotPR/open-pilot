import Foundation
import Compression

/// Lee .docx y .xlsx (contenedores ZIP OOXML) y extrae texto legible para el modelo.
/// 100% en el dispositivo: lector ZIP mínimo + `Compression` (deflate crudo), sin dependencias.
enum OfficeDocument {

    /// Texto legible del documento, o nil si no es un Office válido / no se pudo leer.
    static func extractText(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let entries = zipEntries(data)
        guard !entries.isEmpty else { return nil }
        switch url.pathExtension.lowercased() {
        case "docx":
            guard let xml = entries["word/document.xml"] else { return nil }
            return docxText(xml)
        case "xlsx":
            return xlsxText(entries)
        default:
            return nil
        }
    }

    // MARK: - Texto OOXML

    static func docxText(_ xml: Data) -> String? {
        guard var s = String(data: xml, encoding: .utf8) else { return nil }
        s = s.replacingOccurrences(of: "</w:p>", with: "\n")
        s = s.replacingOccurrences(of: "<w:tab/>", with: "\t")
        s = s.replacingOccurrences(of: "<w:br/>", with: "\n")
        s = stripTags(s)
        let out = clean(s)
        return out.isEmpty ? nil : out
    }

    static func xlsxText(_ entries: [String: Data]) -> String? {
        var shared: [String] = []
        if let ss = entries["xl/sharedStrings.xml"], let s = String(data: ss, encoding: .utf8) {
            shared = capture(s, tag: "t")
        }
        var lines: [String] = []
        let sheetKeys = entries.keys.filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }.sorted()
        for key in sheetKeys {
            guard let data = entries[key], let xml = String(data: data, encoding: .utf8) else { continue }
            for row in capture(xml, tag: "row") {
                var vals: [String] = []
                for cell in captureFull(row, tag: "c") {
                    let isShared = cell.contains("t=\"s\"")
                    if let v = capture(cell, tag: "v").first {
                        if isShared, let idx = Int(v), idx >= 0, idx < shared.count {
                            vals.append(shared[idx])
                        } else {
                            vals.append(v)
                        }
                    } else if let t = capture(cell, tag: "t").first {
                        vals.append(t)
                    }
                }
                if !vals.isEmpty { lines.append(vals.joined(separator: "\t")) }
            }
        }
        let out = clean(lines.joined(separator: "\n"))
        return out.isEmpty ? nil : out
    }

    // MARK: - HTML/XML helpers

    /// Contenido interno de cada `<tag …>…</tag>` (no anidado del mismo tag), decodificado.
    static func capture(_ s: String, tag: String) -> [String] {
        let pattern = "<\(tag)(?:\\s[^>]*)?>(.*?)</\(tag)>"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = s as NSString
        let matches = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m -> String? in
            guard m.numberOfRanges > 1 else { return nil }
            return decodeEntities(ns.substring(with: m.range(at: 1)))
        }
    }

    /// Elemento completo `<tag …>…</tag>` (incluye los atributos de apertura).
    static func captureFull(_ s: String, tag: String) -> [String] {
        let pattern = "<\(tag)(?:\\s[^>]*)?>.*?</\(tag)>"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    static func stripTags(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "<[^>]+>", options: [.dotMatchesLineSeparators]) else { return s }
        let ns = s as NSString
        return re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "")
    }

    static func decodeEntities(_ s: String) -> String {
        var out = s
        for (a, b) in [("&#39;", "'"), ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            out = out.replacingOccurrences(of: a, with: b)
        }
        return out
    }

    static func clean(_ s: String) -> String {
        var out = decodeEntities(s)
        out = out.replacingOccurrences(of: "\r\n", with: "\n")
        while out.contains("\n\n\n") { out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Lector ZIP mínimo

    /// nombre → contenido descomprimido de cada entrada.
    static func zipEntries(_ data: Data) -> [String: Data] {
        var result: [String: Data] = [:]
        guard let eocd = findEOCD(data) else { return result }
        let count = Int(readU16(data, eocd + 10))
        var off = Int(readU32(data, eocd + 16))
        for _ in 0..<count {
            guard off + 46 <= data.count, readU32(data, off) == 0x02014b50 else { break }
            let method = Int(readU16(data, off + 10))
            let compSize = Int(readU32(data, off + 20))
            let uncompSize = Int(readU32(data, off + 24))
            let fnLen = Int(readU16(data, off + 28))
            let extraLen = Int(readU16(data, off + 30))
            let commentLen = Int(readU16(data, off + 32))
            let localOff = Int(readU32(data, off + 42))
            guard off + 46 + fnLen <= data.count else { break }
            let name = String(data: data.subdata(in: (off + 46)..<(off + 46 + fnLen)), encoding: .utf8) ?? ""
            if localOff + 30 <= data.count, readU32(data, localOff) == 0x04034b50 {
                let lfn = Int(readU16(data, localOff + 26))
                let lex = Int(readU16(data, localOff + 28))
                let start = localOff + 30 + lfn + lex
                if start + compSize <= data.count, compSize >= 0 {
                    let comp = data.subdata(in: start..<(start + compSize))
                    if let content = inflate(comp, method: method, expected: uncompSize) {
                        result[name] = content
                    }
                }
            }
            off += 46 + fnLen + extraLen + commentLen
        }
        return result
    }

    /// Busca la firma End Of Central Directory (0x06054b50) desde el final.
    static func findEOCD(_ data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let base = data.startIndex
        var i = data.count - 22
        let lower = max(0, data.count - 22 - 65536)
        while i >= lower {
            if data[base + i] == 0x50 && data[base + i + 1] == 0x4b
                && data[base + i + 2] == 0x05 && data[base + i + 3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }

    /// method 0 = almacenado; method 8 = deflate crudo (COMPRESSION_ZLIB de Apple).
    static func inflate(_ comp: Data, method: Int, expected: Int) -> Data? {
        if method == 0 { return comp }
        guard method == 8, expected > 0 else { return nil }
        var dst = Data(count: expected)
        let n = dst.withUnsafeMutableBytes { dstPtr -> Int in
            comp.withUnsafeBytes { srcPtr -> Int in
                guard let d = dstPtr.bindMemory(to: UInt8.self).baseAddress,
                      let s = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, expected, s, comp.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n > 0 else { return nil }
        return dst.prefix(n)
    }

    static func readU16(_ d: Data, _ o: Int) -> UInt16 {
        let b = d.startIndex + o
        guard b + 2 <= d.endIndex else { return 0 }
        return UInt16(d[b]) | (UInt16(d[b + 1]) << 8)
    }

    static func readU32(_ d: Data, _ o: Int) -> UInt32 {
        let b = d.startIndex + o
        guard b + 4 <= d.endIndex else { return 0 }
        return UInt32(d[b]) | (UInt32(d[b + 1]) << 8) | (UInt32(d[b + 2]) << 16) | (UInt32(d[b + 3]) << 24)
    }
}