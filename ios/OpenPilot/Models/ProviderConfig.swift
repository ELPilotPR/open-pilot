import Foundation
import SwiftData

/// Un proveedor de modelo configurado por el usuario y guardado en el iPhone.
/// kind "openai" cubre CUALQUIER endpoint OpenAI-compatible (server local de casa,
/// Ollama, llama.cpp, LM Studio, OpenAI, OpenRouter…). kind "anthropic" para Claude.
/// La apiKey se guarda localmente; nunca se envía a ningún backend nuestro.
@Model
final class ProviderConfig {
    @Attribute(.unique) var id: String
    var name: String
    var kind: String          // "openai" | "anthropic"
    var baseURL: String
    var apiKey: String
    var models: [String]
    var createdAt: Date
    /// Soporte de generacion de imagenes: "auto" (detecta por host) | "yes" | "no".
    var imageCapability: String = "auto"

    init(id: String, name: String, kind: String = "openai", baseURL: String, apiKey: String = "", models: [String] = [], imageCapability: String = "auto") {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.models = models
        self.createdAt = Date()
        self.imageCapability = imageCapability
    }

    /// true si este proveedor puede generar imagenes (flag explicito o host conocido).
    var resolvesImageSupport: Bool {
        switch imageCapability {
        case "yes": return true
        case "no": return false
        default:
            let h = (URL(string: baseURL)?.host ?? "").lowercased()
            return h.contains("aliyuncs") || h.contains("dashscope") || h.contains("openai.com")
        }
    }
}