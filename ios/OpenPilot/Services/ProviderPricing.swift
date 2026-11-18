import Foundation

/// Precio por proveedor: manual (tarifas fijas del usuario) o auto (cache de un
/// endpoint /models tipo OpenRouter). Todo client-side: el fetch va directo al
/// endpoint del proveedor, sin backend nuestro. `resolve` devuelve nil cuando no
/// hay override → se usa la tabla integrada de `UsagePricing`.
enum ProviderPricing {

    /// Tarifa efectiva de un modelo según los ajustes del proveedor.
    /// - manual: una tarifa fija para todos los modelos del proveedor (0/0 = sin override).
    /// - auto: busca el modelo en la cache OpenRouter; si no está, nil (tabla integrada).
    nonisolated static func resolve(enabled: Bool, mode: String,
                                    manualIn: Double, manualOut: Double,
                                    autoJSON: String, model: String) -> ModelRate? {
        guard enabled else { return nil }
        if mode == "manual" {
            guard manualIn > 0 || manualOut > 0 else { return nil }
            return ModelRate(inputPerMillion: manualIn, outputPerMillion: manualOut)
        }
        return decodeAuto(autoJSON, model: model)
    }

    /// Cache auto → JSON {modelID: [inputPerMillion, outputPerMillion]}.
    nonisolated static func encodeAuto(_ rates: [String: ModelRate]) -> String {
        var dict: [String: [Double]] = [:]
        for (k, r) in rates { dict[k] = [r.inputPerMillion, r.outputPerMillion] }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Lee la cache auto para un modelo: match exacto y luego por subcadena (como la tabla).
    nonisolated static func decodeAuto(_ json: String, model: String) -> ModelRate? {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] else { return nil }
        if let pair = obj[model], pair.count == 2 {
            return ModelRate(inputPerMillion: pair[0], outputPerMillion: pair[1])
        }
        let lower = model.lowercased()
        guard !lower.isEmpty else { return nil }
        for (k, pair) in obj where pair.count == 2 {
            let kl = k.lowercased()
            if lower.contains(kl) || kl.contains(lower) {
                return ModelRate(inputPerMillion: pair[0], outputPerMillion: pair[1])
            }
        }
        return nil
    }

    /// Parsea /models de OpenRouter: data[].id + pricing.prompt/completion.
    /// Esos valores son USD por TOKEN (string o número) → ×1e6 para USD/millón.
    /// Modelos con ambos precios 0 (gratis) se omiten.
    nonisolated static func parseOpenRouter(_ data: Data) -> [String: ModelRate] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]] else { return [:] }
        var out: [String: ModelRate] = [:]
        for item in arr {
            guard let id = item["id"] as? String,
                  let pricing = item["pricing"] as? [String: Any] else { continue }
            let pin = perMillion(pricing["prompt"])
            let pout = perMillion(pricing["completion"])
            if pin > 0 || pout > 0 {
                out[id] = ModelRate(inputPerMillion: pin, outputPerMillion: pout)
            }
        }
        return out
    }

    /// pricing puede venir como String ("0.0000025"), Double o Int. USD/token → USD/millón.
    nonisolated static func perMillion(_ v: Any?) -> Double {
        let d: Double
        if let s = v as? String { d = Double(s) ?? 0 }
        else if let n = v as? Double { d = n }
        else if let n = v as? Int { d = Double(n) }
        else { d = 0 }
        return d * 1_000_000
    }

    enum FetchError: LocalizedError {
        case badURL, badResponse
        var errorDescription: String? {
            switch self {
            case .badURL: return "Invalid base URL"
            case .badResponse: return "No pricing in /models (is this an OpenRouter-style endpoint?)"
            }
        }
    }

    /// GET {baseURL}/models y extrae tarifas. Directo al proveedor, sin backend nuestro.
    static func fetch(baseURL: String, apiKey: String) async throws -> [String: ModelRate] {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: trimmed) else { throw FetchError.badURL }
        var path = comps.path
        if path.hasSuffix("/") { path.removeLast() }
        comps.path = path + "/models"
        guard let url = comps.url else { throw FetchError.badURL }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.badResponse
        }
        let rates = parseOpenRouter(data)
        guard !rates.isEmpty else { throw FetchError.badResponse }
        return rates
    }
}
