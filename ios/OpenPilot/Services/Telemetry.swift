import Foundation

/// Telemetría de generación 100% local: velocidad en vivo (tok/s) y gauge de
/// contexto por chat. Sin backend; todo se estima en el dispositivo.
///
/// La ventana de contexto es aproximada (por familia de modelo) y solo alimenta
/// el gauge visual. El presupuesto de auto-compacción sigue siendo
/// `ContextSettings.budgetTokens`, independiente de esta ventana.

/// Ventana de contexto aproximada por modelo (tokens).
enum ModelContextWindow {
    static func window(for model: String, kind: String) -> Int {
        let m = model.lowercased()
        if kind == "ondevice" || m == "apple-intelligence" { return 4096 }
        if m.contains("gpt-4o") || m.contains("gpt-4.1") { return 128_000 }
        if m.hasPrefix("o3") || m.hasPrefix("o4") || m.contains("gpt-5") { return 200_000 }
        if m.contains("gpt-3.5") { return 16_385 }
        if m.contains("gemini") { return 1_000_000 }
        if m.contains("claude") { return 200_000 }
        if m.contains("qwen-long") { return 1_000_000 }
        if m.contains("qwen3") || m.contains("qwen-3") { return 262_144 }
        if m.contains("qwen2.5") || m.contains("qwen-2.5") { return 131_072 }
        if m.contains("qwen") { return 131_072 }
        if m.contains("deepseek") { return 65_536 }
        if m.contains("llama-3") || m.contains("llama3") { return 131_072 }
        if m.contains("mistral") || m.contains("mixtral") { return 32_768 }
        if kind == "gguf" { return 8192 }
        return 32_768   // genérico OpenAI-compatible / LAN
    }

    /// Ventana efectiva: override manual > detectada del servidor > heurística.
    static func resolve(model: String, kind: String, override: Int, detected: Int) -> Int {
        if override > 0 { return override }
        if detected > 0 { return detected }
        return window(for: model, kind: kind)
    }
}

/// Gauge de contexto: fracción usada, porcentaje y nivel de color.
struct ContextGauge: Equatable {
    let used: Int
    let window: Int
    var fraction: Double { window > 0 ? min(1, Double(used) / Double(window)) : 0 }
    var percent: Int { Int((fraction * 100).rounded()) }
    /// 0 = holgado (<60%), 1 = medio (60–84%), 2 = lleno (≥85%).
    var tier: Int { percent >= 85 ? 2 : (percent >= 60 ? 1 : 0) }
    static func make(used: Int, window: Int) -> ContextGauge {
        ContextGauge(used: max(0, used), window: max(1, window))
    }
}

/// Velocidad de generación en vivo (tokens/s).
enum LiveSpeed {
    /// tok/s; 0 si aún no hay tokens o el elapsed es despreciable.
    static func tps(tokens: Int, elapsed: TimeInterval) -> Double {
        guard elapsed > 0.05, tokens > 0 else { return 0 }
        return Double(tokens) / elapsed
    }
    /// "12.3 tok/s" (≥100 sin decimales para que el número no baile).
    static func label(_ tps: Double) -> String {
        tps >= 100 ? String(format: "%.0f tok/s", tps) : String(format: "%.1f tok/s", tps)
    }
    /// Tokens estimados de un texto (~4 chars/token), igual que el fallback de usage.
    static func estimateTokens(_ text: String) -> Int { max(0, text.count / 4) }
}

/// Formato compacto de conteos de tokens para el gauge.
enum TokenFormat {
    /// 512 → "512", 8200 → "8.2k", 128000 → "128k", 1000000 → "1M".
    static func short(_ n: Int) -> String {
        if n >= 1_000_000 {
            let v = Double(n) / 1_000_000
            return v == v.rounded() ? "\(Int(v))M" : String(format: "%.1fM", v)
        }
        if n >= 1000 {
            let v = Double(n) / 1000
            return v == v.rounded() ? "\(Int(v))k" : String(format: "%.1fk", v)
        }
        return "\(n)"
    }
}
