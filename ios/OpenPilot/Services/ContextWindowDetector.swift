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

    // MARK: - Detección activa por desborde (servers que no reportan contexto)

    /// Extrae la ventana de contexto REAL del error que devuelven los servers
    /// OpenAI-compatible cuando la entrada desborda el contexto. Puro → testeable.
    /// Formatos reales cubiertos:
    ///  - DashScope/Qwen: `Range of input length should be [1, 1048576]`
    ///  - OpenAI/vLLM:    `This model's maximum context length is 8192 tokens…`
    ///  - LiteLLM:        `…maximum context length of 131072 tokens`
    ///  - OpenAI-compat:  `Input length (265330) exceeds model's maximum context length (262144).`
    ///  - llama.cpp:      `…exceeds the available context size (8192 tokens)`
    static func parseContextLimit(from text: String) -> Int? {
        let patterns = [
            #"input length should be \[\s*\d+\s*,\s*(\d+)"#,        // DashScope/Qwen
            #"maximum context length is (\d+)"#,                    // OpenAI / vLLM
            #"maximum context length of (\d+)"#,                    // LiteLLM
            #"maximum context length \(\s*(\d+)\s*\)"#,             // OpenAI-compatible
            #"maximum context length[:\s]+(\d+)"#,                  // genérico
            #"available context size \(\s*(\d+)"#,                  // llama.cpp
            #"context (?:window|length|size) (?:is |of )?\(?\s*(\d+)"#,
            #"exceeds[^(]*\(\s*(\d+)\s*\)"#,                        // …exceeds … (N)
        ]
        let ns = text as NSString
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { continue }
            if let m = re.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
               m.numberOfRanges >= 2 {
                let r = m.range(at: 1)
                if r.location != NSNotFound, let n = Int(ns.substring(with: r)), n > 0 { return n }
            }
        }
        return nil
    }

    /// Probe activo: provoca un error de desborde y lee el límite real del cuerpo.
    /// Solo se invoca desde el botón manual "Detect from server" (NUNCA en el
    /// refresco automático del chat). Dos intentos, de barato a costoso:
    ///  1. `max_tokens` enorme + entrada mínima → vLLM/OpenAI/LiteLLM revelan
    ///     "maximum context length is N" sin payload grande.
    ///  2. Entrada gigante (>1M tokens) + `max_tokens=1` → Qwen/DashScope revelan
    ///     "Range of input length should be [1, N]". (~5 MB, una sola vez.)
    /// Ninguno llega a generar tokens: el server rechaza en validación.
    static func probeContextLimit(baseURL: String, apiKey: String, model: String) async -> Int? {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !model.isEmpty else { return nil }
        let urlStr = (base.hasSuffix("/") ? base : base + "/") + "chat/completions"
        guard let url = URL(string: urlStr) else { return nil }
        // 1) Barato: desborde por max_tokens (payload mínimo).
        let cheap: [String: Any] = [
            "model": model, "max_tokens": 100_000_000, "stream": false,
            "messages": [["role": "user", "content": "hi"]],
        ]
        if let body = await postRaw(url, apiKey: apiKey, body: cheap, timeout: 20),
           let w = parseContextLimit(from: body) { return w }
        // 2) Qwen/DashScope: desborde por entrada (>1M tokens).
        let filler = String(repeating: " the", count: 1_300_000)
        let big: [String: Any] = [
            "model": model, "max_tokens": 1, "stream": false,
            "messages": [["role": "user", "content": filler]],
        ]
        if let body = await postRaw(url, apiKey: apiKey, body: big, timeout: 45),
           let w = parseContextLimit(from: body) { return w }
        return nil
    }

    /// POST que devuelve el cuerpo crudo AUNQUE el status no sea 200, para poder
    /// leer el mensaje de error de desborde (que trae el límite real).
    private static func postRaw(_ url: URL, apiKey: String, body: [String: Any], timeout: TimeInterval) async -> String? {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
