import Foundation

/// Un turno de chat normalizado (independiente del proveedor).
struct ChatTurn {
    let role: String
    let content: String
    var images: [Data] = []   // fotos adjuntas (vision); vacio = solo texto
}

/// Eventos que emite un proveedor durante el streaming.
enum ChatEvent {
    case delta(String)
    case reasoning(String)
    case usage(promptTokens: Int, completionTokens: Int)
    case done
}

enum ProviderError: LocalizedError {
    case badURL(String)
    case http(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badURL(let s): return "URL inválida: \(s)"
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(300))"
        case .transport(let s): return "Error de red: \(s)"
        }
    }
}

/// Contrato común. El proveedor on-device (MLX/llama.cpp) conformará este mismo
/// protocolo en la siguiente fase, sin tocar la UI ni la persistencia.
protocol ChatProvider {
    func stream(turns: [ChatTurn], model: String, baseURL: String, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error>
    func models(baseURL: String, apiKey: String) async throws -> [String]
}

enum ProviderFactory {
    static func make(kind: String) -> ChatProvider {
        switch kind {
        case "anthropic": return AnthropicProvider()
        case "ondevice": return OnDeviceProvider()
        case "gguf": return GGUFProvider()
        default: return OpenAICompatibleProvider()
        }
    }
}

/// Normaliza una baseURL quitando slashes finales.
func trimBase(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    while t.hasSuffix("/") { t.removeLast() }
    return t
}