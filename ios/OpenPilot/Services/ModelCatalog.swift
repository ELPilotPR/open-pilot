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

    /// Gemini vía el endpoint OpenAI-compatible de Google.
    static let gemini: [ModelPreset] = [
        ModelPreset(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash Lite", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", vision: true, reasoning: false, imageGen: false),
    ]

    static let groq: [ModelPreset] = [
        ModelPreset(id: "llama-3.3-70b-versatile", name: "Llama 3.3 70B", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "llama-3.2-11b-vision-preview", name: "Llama 3.2 11B Vision", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "deepseek-r1-distill-llama-70b", name: "DeepSeek R1 Distill 70B", vision: false, reasoning: true, imageGen: false),
        ModelPreset(id: "gemma2-9b-it", name: "Gemma 2 9B", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", vision: false, reasoning: false, imageGen: false),
    ]

    static let mistral: [ModelPreset] = [
        ModelPreset(id: "mistral-large-latest", name: "Mistral Large", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "mistral-small-latest", name: "Mistral Small", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "open-mistral-nemo", name: "Mistral Nemo", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "pixtral-large-latest", name: "Pixtral Large", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "codestral-latest", name: "Codestral", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "magistral-medium-latest", name: "Magistral Medium", vision: false, reasoning: true, imageGen: false),
    ]

    /// OpenRouter usa ids con prefijo de familia.
    static let openrouter: [ModelPreset] = [
        ModelPreset(id: "openai/gpt-4o", name: "GPT-4o (OpenRouter)", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "anthropic/claude-sonnet-4.5", name: "Claude Sonnet 4.5 (OpenRouter)", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "google/gemini-2.5-pro", name: "Gemini 2.5 Pro (OpenRouter)", vision: true, reasoning: true, imageGen: false),
        ModelPreset(id: "meta-llama/llama-3.3-70b-instruct", name: "Llama 3.3 70B (OpenRouter)", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "deepseek/deepseek-chat", name: "DeepSeek Chat (OpenRouter)", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen/qwen-2.5-72b-instruct", name: "Qwen 2.5 72B (OpenRouter)", vision: false, reasoning: false, imageGen: false),
    ]

    /// Modelos comunes en Ollama (servidor local). Los ids exactos dependen de
    /// los tags que el usuario haya hecho `ollama pull`; Test & discover los lista.
    static let ollama: [ModelPreset] = [
        ModelPreset(id: "llama3.2", name: "Llama 3.2", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "llama3.2-vision", name: "Llama 3.2 Vision", vision: true, reasoning: false, imageGen: false),
        ModelPreset(id: "llama3.1", name: "Llama 3.1", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "qwen2.5", name: "Qwen 2.5", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "mistral", name: "Mistral", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "gemma2", name: "Gemma 2", vision: false, reasoning: false, imageGen: false),
        ModelPreset(id: "deepseek-r1", name: "DeepSeek R1", vision: false, reasoning: true, imageGen: false),
        ModelPreset(id: "llava", name: "LLaVA", vision: true, reasoning: false, imageGen: false),
    ]

    /// Sugerencias según el proveedor (host de la base URL o tipo).
    static func presets(for baseURL: String, kind: String) -> [ModelPreset] {
        let host = baseURL.lowercased()
        if kind == "anthropic" || host.contains("anthropic") { return anthropic }
        if host.contains("aliyuncs") || host.contains("dashscope") { return qwen }
        if host.contains("generativelanguage") || host.contains("gemini") { return gemini }
        if host.contains("groq") { return groq }
        if host.contains("mistral") { return mistral }
        if host.contains("openrouter") { return openrouter }
        if host.contains("11434") || host.contains("ollama") { return ollama }
        if host.contains("openai.com") { return openai }
        // LM Studio y otros compatibles: sin presets fijos (el id es el modelo
        // cargado); se descubren con GET /models.
        return []
    }

    /// Busca las capacidades de un id concreto en todo el catálogo.
    static func preset(for id: String) -> ModelPreset? {
        (openai + qwen + anthropic + gemini + groq + mistral + openrouter + ollama)
            .first { $0.id == id }
    }
}