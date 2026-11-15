import Foundation

/// Detecta la ventana de contexto REAL de un modelo consultando al servidor
/// (petición directa al provider del usuario, sin backend nuestro). Soporta:
///  - OpenAI-compatible `/v1/models` con metadatos de contexto (vLLM, llama.cpp, LM Studio)
///  - llama.cpp `/props` (`default_generation_settings.n_ctx`)
///  - Ollama `/api/show` (`model_info.<arch>.context_length`)
/// Si el servidor no lo expone (p. ej. Strata), devuelve nil → se usa el override
/// manual o la heurística por familia. Cachea por provider+modelo en UserDefaults.
enum ContextWindowDetector {

    // MARK: - Parseo puro (unit-testeable sin red)

    /// `/v1/models`: busca el modelo por id (o el primero) y lee su contexto.
    static func fromModelsJSON(_ data: Data, model: String) -> Int? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]] else { return nil }
        let match = arr.first { ($0["id"] as? String) == model } ?? arr.first
        guard let m = match else { return nil }
        return contextValue(from: m)
    }

    /// Contexto de un objeto modelo: campos planos conocidos + `meta` anidada.
    static func contextValue(from m: [String: Any]) -> Int? {
        let keys = ["context_length", "max_model_len", "context_window", "max_context_length", "n_ctx", "n_ctx_train", "max_seq_len"]
        for k in keys { if let v = intValue(m[k]), v > 0 { return v } }
        if let meta = m["meta"] as? [String: Any] {
            for k in keys { if let v = intValue(meta[k]), v > 0 { return v } }
        }
        return nil
    }

    /// llama.cpp `/props`.
    static func fromPropsJSON(_ data: Data) -> Int? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let dgs = obj["default_generation_settings"] as? [String: Any], let v = intValue(dgs["n_ctx"]), v > 0 { return v }
        if let v = intValue(obj["n_ctx"]), v > 0 { return v }
        return nil
    }

    /// Ollama `/api/show`: cualquier clave `*.context_length` dentro de model_info.
    static func fromOllamaShowJSON(_ data: Data) -> Int? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let info = obj["model_info"] as? [String: Any] else { return nil }
        for (k, v) in info where k.hasSuffix("context_length") {
            if let n = intValue(v), n > 0 { return n }
        }
        return nil
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        return nil
    }

    // MARK: - Cache (UserDefaults, por provider+modelo)

    private static func cacheKey(_ pid: String, _ model: String) -> String { "ctxwin.\(pid).\(model)" }

    static func cached(providerID: String, model: String) -> Int? {
        let v = UserDefaults.standard.integer(forKey: cacheKey(providerID, model))
        return v > 0 ? v : nil
    }

    static func store(_ window: Int, providerID: String, model: String) {
        UserDefaults.standard.set(window, forKey: cacheKey(providerID, model))
    }

    // MARK: - Detección por red

    static func detect(baseURL: String, apiKey: String, model: String) async -> Int? {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        // 1) /v1/models (la base suele incluir ya /v1)
        if let url = URL(string: base.hasSuffix("/") ? base + "models" : base + "/models"),
           let data = await fetch(url, apiKey: apiKey),
           let w = fromModelsJSON(data, model: model) { return w }
        // 1b) detalle por modelo /v1/models/{id} (algunos servers lo exponen ahí)
        if !model.isEmpty,
           let url = URL(string: base.hasSuffix("/") ? base + "models/" + model : base + "/models/" + model),
           let data = await fetch(url, apiKey: apiKey) {
            if let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let w = contextValue(from: obj), w > 0 { return w }
            if let w = fromModelsJSON(data, model: model) { return w }
        }
        // root sin /v1 para los endpoints nativos
        let root = base.replacingOccurrences(of: "/v1", with: "")
        // 2) llama.cpp /props
        if let url = URL(string: root + "/props"),
           let data = await fetch(url, apiKey: apiKey),
           let w = fromPropsJSON(data) { return w }
        // 3) Ollama /api/show
        if !model.isEmpty, let url = URL(string: root + "/api/show"),
           let data = await post(url, apiKey: apiKey, body: ["name": model]),
           let w = fromOllamaShowJSON(data) { return w }
        return nil
    }

    private static func fetch(_ url: URL, apiKey: String) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    private static func post(_ url: URL, apiKey: String, body: [String: Any]) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}