import Foundation

/// Cliente OpenAI-compatible mínimo para la extensión de teclado (sin streaming).
/// Helpers puros (request/parse) testeables sin red; `complete` hace la llamada.
enum KeyboardChat {
    static func trimBase(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("/") { t.removeLast() }
        return t
    }

    static func request(provider: KeyboardProvider, prompt: String) -> URLRequest? {
        let base = trimBase(provider.baseURL)
        guard !base.isEmpty, let url = URL(string: base + "/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !provider.apiKey.isEmpty {
            req.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": provider.model,
            "stream": false,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60
        return req
    }

    static func parseResponse(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else { return nil }
        return content
    }

    static func complete(provider: KeyboardProvider, prompt: String) async throws -> String {
        guard let req = request(provider: provider, prompt: prompt) else {
            throw NSError(domain: "KeyboardChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid provider URL"])
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "KeyboardChat", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(160))"])
        }
        guard let text = parseResponse(data) else {
            throw NSError(domain: "KeyboardChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response"])
        }
        return text
    }
}