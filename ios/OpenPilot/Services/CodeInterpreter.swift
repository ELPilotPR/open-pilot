import Foundation
import JavaScriptCore

/// On-device code interpreter. JavaScript runs in a bare `JSContext`, which has no
/// network, filesystem, or OS bridge — code can only compute and print through the
/// console we inject. Nothing leaves the device. Also parses CSV for charting.
enum CodeInterpreter {

    struct RunResult: Equatable {
        var logs: [String]
        var value: String
        var error: String?
        var durationMs: Double
        var ok: Bool { error == nil }

        /// Human-readable transcript: console lines, the final value, then any error.
        var output: String {
            var parts = logs
            if !value.isEmpty && value != "undefined" && error == nil {
                parts.append("→ " + value)
            }
            if let e = error { parts.append("⚠ " + e) }
            return parts.joined(separator: "\n")
        }
    }

    /// Run JavaScript off the main thread so a runaway loop can't freeze the UI.
    /// We wait up to `timeout`; if it overruns we report a timeout (JSContext cannot
    /// be interrupted mid-evaluation, so an infinite loop is abandoned, not killed).
    static func run(_ source: String, timeout: TimeInterval = 5) -> RunResult {
        final class Box {
            var result = RunResult(logs: [], value: "", error: nil, durationMs: 0)
            let sem = DispatchSemaphore(value: 0)
        }
        let box = Box()
        DispatchQueue.global(qos: .userInitiated).async {
            box.result = evaluate(source)
            box.sem.signal()
        }
        if box.sem.wait(timeout: .now() + timeout) == .timedOut {
            return RunResult(logs: [], value: "",
                             error: "Execution timed out after \(Int(timeout))s",
                             durationMs: timeout * 1000)
        }
        return box.result
    }

    private static func evaluate(_ source: String) -> RunResult {
        let start = Date()
        guard let ctx = JSContext() else {
            return RunResult(logs: [], value: "", error: "JavaScript unavailable", durationMs: 0)
        }
        var logs: [String] = []
        var caught: String?
        ctx.exceptionHandler = { _, exc in
            caught = exc?.toString() ?? "Unknown error"
        }

        // Native sink + a JS console that joins all arguments (objects → JSON).
        let sink: @convention(block) (String) -> Void = { s in logs.append(s) }
        ctx.setObject(sink, forKeyedSubscript: "__nativeLog" as NSString)
        ctx.evaluateScript("""
        function __fmt(a){ try { return (typeof a === 'object' && a !== null) ? JSON.stringify(a) : String(a); } catch(e){ return String(a); } }
        var console = { log: function(){ __nativeLog(Array.prototype.map.call(arguments, __fmt).join(' ')); } };
        console.warn = console.log; console.error = console.log; console.info = console.log; console.debug = console.log;
        """)

        let result = ctx.evaluateScript(source)
        let ms = Date().timeIntervalSince(start) * 1000
        return RunResult(logs: logs, value: result?.toString() ?? "", error: caught, durationMs: ms)
    }

    // MARK: - CSV

    struct CSVTable: Equatable {
        var columns: [String]
        var rows: [[String]]

        /// Numeric values for a column index, or nil if any cell isn't a number.
        func numericValues(_ index: Int) -> [Double]? {
            guard index >= 0 && index < columns.count else { return nil }
            var out: [Double] = []
            for r in rows {
                guard index < r.count, let v = Double(r[index].trimmingCharacters(in: .whitespaces)) else { return nil }
                out.append(v)
            }
            return out
        }

        /// Index of the first fully-numeric column, if any.
        var firstNumericColumn: Int? {
            for i in columns.indices where numericValues(i) != nil { return i }
            return nil
        }
    }

    /// RFC4180-ish parser: quoted fields, escaped quotes (""), commas and newlines
    /// inside quotes, CRLF tolerance. First record is the header.
    static func parseCSV(_ text: String) -> CSVTable {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n":
                    record.append(field); field = ""
                    records.append(record); record = []
                case "\r": break
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field); records.append(record)
        }
        records = records.filter { !($0.count == 1 && $0[0].isEmpty) }
        guard let header = records.first else { return CSVTable(columns: [], rows: []) }
        let cols = header
        let rows = Array(records.dropFirst()).map { r -> [String] in
            var rr = r
            while rr.count < cols.count { rr.append("") }
            return Array(rr.prefix(cols.count))
        }
        return CSVTable(columns: cols, rows: rows)
    }
}