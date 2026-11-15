import Foundation

/// Compleción puntual (no streaming) contra el provider configurado por el
/// usuario. Cliente directo: el iPhone habla con el modelo, sin backend propio.
/// Reutilizable para resúmenes, traducción y auto-etiquetado.
enum OneShot {
    static func complete(prompt: String, kind: String, model: String,
                         baseURL: String, apiKey: String) async -> String? {
        var out = ""
        do {
            for try await ev in ProviderFactory.make(kind: kind).stream(
                turns: [ChatTurn(role: "user", content: prompt)],
                model: model, baseURL: baseURL, apiKey: apiKey) {
                if case .delta(let t) = ev { out += t }
            }
        } catch { return nil }
        let t = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}