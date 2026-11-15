import Foundation

/// Tarifa orientativa en USD por millón de tokens (entrada / salida).
struct ModelRate: Equatable {
    let inputPerMillion: Double
    let outputPerMillion: Double
    static let zero = ModelRate(inputPerMillion: 0, outputPerMillion: 0)
}

/// Estimación de coste 100% local. Los modelos que corren en tu propio hardware
/// (on-device / Ollama / LM Studio en LAN) cuentan $0.
enum UsagePricing {
    static func rate(for model: String) -> ModelRate {
        let m = model.lowercased()
        if m == "apple-intelligence" || m.contains("local") { return .zero }
        if m.hasPrefix("gpt-4o-mini") { return ModelRate(inputPerMillion: 0.15, outputPerMillion: 0.6) }
        if m.hasPrefix("gpt-4o") { return ModelRate(inputPerMillion: 2.5, outputPerMillion: 10) }
        if m.hasPrefix("gpt-4.1-mini") { return ModelRate(inputPerMillion: 0.4, outputPerMillion: 1.6) }
        if m.hasPrefix("gpt-4.1") { return ModelRate(inputPerMillion: 2, outputPerMillion: 8) }
        if m.hasPrefix("o3") || m.hasPrefix("o4-mini") { return ModelRate(inputPerMillion: 2, outputPerMillion: 8) }
        if m.contains("gemini-2.5-pro") { return ModelRate(inputPerMillion: 1.25, outputPerMillion: 10) }
        if m.contains("gemini-2.5-flash") { return ModelRate(inputPerMillion: 0.30, outputPerMillion: 2.5) }
        if m.contains("llama-3.3-70b") { return ModelRate(inputPerMillion: 0.59, outputPerMillion: 0.79) }
        if m.contains("mistral-large") { return ModelRate(inputPerMillion: 2, outputPerMillion: 6) }
        if m.contains("qwen") { return ModelRate(inputPerMillion: 1.6, outputPerMillion: 6.4) }
        return ModelRate(inputPerMillion: 1, outputPerMillion: 3)   // genérico conservador
    }

    static func costUSD(model: String, promptTokens: Int, completionTokens: Int, local: Bool = false) -> Double {
        if local { return 0 }
        let r = rate(for: model)
        return Double(promptTokens) / 1_000_000 * r.inputPerMillion
             + Double(completionTokens) / 1_000_000 * r.outputPerMillion
    }

    /// Un proveedor es local si corre en tu hardware (on-device o servidor LAN).
    static func isLocal(kind: String, baseURL: String) -> Bool {
        if kind == "ondevice" { return true }
        let h = baseURL.lowercased()
        return h.contains("localhost") || h.contains("127.0.0.1") || h.contains("192.168.")
            || h.contains("://10.") || h.contains(":11434") || h.contains(":1234") || h.contains(".local")
    }
}

/// Una respuesta de asistente con tokens contabilizados.
struct UsageSample {
    let providerID: String
    let providerName: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let date: Date
    let local: Bool
}

struct ProviderUsage: Identifiable, Equatable {
    var id: String { providerID }
    let providerID: String
    let providerName: String
    let promptTokens: Int
    let completionTokens: Int
    let costUSD: Double
    let messages: Int
    var totalTokens: Int { promptTokens + completionTokens }
}

struct DayUsage: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    let costUSD: Double
    let tokens: Int
}

struct UsageSummary: Equatable {
    let totalPrompt: Int
    let totalCompletion: Int
    let totalCost: Double
    let messageCount: Int
    let byProvider: [ProviderUsage]
    let byDay: [DayUsage]
    var totalTokens: Int { totalPrompt + totalCompletion }
}

/// Agregación pura y determinista del uso a partir de muestras.
enum UsageStats {
    static func summarize(_ samples: [UsageSample], calendar: Calendar = .current, days: Int = 14) -> UsageSummary {
        var provMap: [String: (name: String, p: Int, c: Int, cost: Double, n: Int)] = [:]
        var dayMap: [Date: (cost: Double, tok: Int)] = [:]
        var tp = 0, tc = 0, n = 0
        var cost = 0.0
        for s in samples {
            let cst = UsagePricing.costUSD(model: s.model, promptTokens: s.promptTokens,
                                           completionTokens: s.completionTokens, local: s.local)
            tp += s.promptTokens; tc += s.completionTokens; cost += cst; n += 1
            var e = provMap[s.providerID] ?? (s.providerName, 0, 0, 0, 0)
            e.name = s.providerName; e.p += s.promptTokens; e.c += s.completionTokens; e.cost += cst; e.n += 1
            provMap[s.providerID] = e
            let day = calendar.startOfDay(for: s.date)
            var de = dayMap[day] ?? (0, 0)
            de.cost += cst; de.tok += s.promptTokens + s.completionTokens
            dayMap[day] = de
        }
        let byProvider = provMap.map {
            ProviderUsage(providerID: $0.key, providerName: $0.value.name, promptTokens: $0.value.p,
                          completionTokens: $0.value.c, costUSD: $0.value.cost, messages: $0.value.n)
        }.sorted { $0.costUSD > $1.costUSD }

        let today = calendar.startOfDay(for: Date())
        var byDay: [DayUsage] = []
        for offset in (0..<days).reversed() {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                let e = dayMap[day] ?? (0, 0)
                byDay.append(DayUsage(day: day, costUSD: e.cost, tokens: e.tok))
            }
        }
        return UsageSummary(totalPrompt: tp, totalCompletion: tc, totalCost: cost,
                            messageCount: n, byProvider: byProvider, byDay: byDay)
    }
}