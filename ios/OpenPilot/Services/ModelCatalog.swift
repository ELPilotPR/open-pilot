import Foundation

/// Un modelo sugerido con sus capacidades. Es una lista de conveniencia: el
/// usuario siempre puede escribir cualquier id a mano o descubrirlos con GET /models.
struct ModelPreset: Identifiable, Hashable {
    let id: String          // id exacto que se envía a la API
    let name: String        // nombre legible
    let vision: Bool        // acepta imágenes de entrada
    let reasoning: Bool     // modelo de razonamiento (piensa antes de responder)
    let imageGen: Bool      // genera imágenes

    /// Etiquetas cortas de capacidad para mostrar junto al modelo.
    var badges: [String] {
        var b: [String] = []
        if vision { b.append("vision") }
        if reasoning { b.append("reasoning") }
        if imageGen { b.append("image") }
        return b
    }
}

/// Catálogo de presets por familia de proveedor. Los ids son los públicos más
/// comunes; sirve como punto de partida, no como lista exhaustiva.
enum ModelCatalog {
    static let openai: [ModelPreset] = [
        ModelPreset(id: "gpt-4o", name: "GPT-4o", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "gpt-4o-mini", name: "GPT-4o mini", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "gpt-4.1", name: "GPT-4.1", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "gpt-4.1-mini", name: "GPT-4.1 mini", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "o3", name: "o3", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "o4-mini", name: "o4-mini", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "gpt-image-1", name: "GPT Image 1", vision: false, reasoning: false, imageGen: true),
    ]

    static let qwen: [ModelPreset] = [
        ModelPreset(id: "qwen-max", name: "Qwen Max", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen-plus", name: "Qwen Plus", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen-turbo", name: "Qwen Turbo", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen-vl-max", name: "Qwen VL Max", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen-vl-plus", name: "Qwen VL Plus", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "qwq-plus", name: "QwQ Plus", vision: false, reasoning: true, imageGen: false),
        ModelPreset(id: "wan2.7-image", name: "Wan 2.7 Image", vision: false, reasoning: false, imageGen: true),
    ]

    static let anthropic: [ModelPreset] = [
        ModelPreset(id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "claude-opus-4-1", name: "Claude Opus 4.1", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "claude-3-5-haiku-latest", name: "Claude 3.5 Haiku", vision: true, reasoning: false, imageGen: false),
    ]

    /// Sugerencias según el proveedor (host de la base URL o tipo).
    static func presets(for baseURL: String, kind: String) -> [ModelPreset] {
        let host = baseURL.lowercased()
        if kind == "anthropic" || host.contains("anthropic") { return anthropic }
        if host.contains("aliyuncs") || host.contains("dashscope") { return qwen }
        if host.contains("openai.com") { return openai }
        // OpenRouter y otros compatibles: mezcla de los más usados.
        if host.contains("openrouter") { return openai + anthropic }
        return []
    }

    /// Busca las capacidades de un id concreto en todo el catálogo.
    static func preset(for id: String) -> ModelPreset? {
        (openai + qwen + anthropic).first { $0.id == id }
    }
}
