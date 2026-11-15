import Foundation
import SwiftData
import Security

/// Un proveedor de modelo configurado por el usuario y guardado en el iPhone.
/// kind "openai" cubre CUALQUIER endpoint OpenAI-compatible (server local de casa,
/// Ollama, llama.cpp, LM Studio, OpenAI, OpenRouter…). kind "anthropic" para Claude.
/// La apiKey se guarda en el KEYCHAIN del dispositivo (nunca en texto plano) y
/// jamás se envía a ningún backend nuestro: la app conecta directo al modelo.
@Model
final class ProviderConfig {
    @Attribute(.unique) var id: String
    var name: String
    var kind: String          // "openai" | "anthropic"
    var baseURL: String
    /// Respaldo legacy en texto plano (versiones anteriores). Se migra al Keychain
    /// en el primer arranque y queda vacío. No usar directamente: usar `apiKey`.
    @Attribute(originalName: "apiKey") var apiKeyLegacy: String = ""
    var models: [String]
    var createdAt: Date
    /// Soporte de generacion de imagenes: "auto" (detecta por host) | "yes" | "no".
    var imageCapability: String = "auto"
    /// Ventana de contexto manual (tokens). 0 = automático (detectar del servidor
    /// o estimar por familia). Útil cuando el server no la reporta (p. ej. Strata).
    var contextWindow: Int = 0

    /// API key protegida por el Keychain. Lee del Keychain y, si aún no se ha
    /// migrado, cae al valor legacy para no perder la clave existente.
    var apiKey: String {
        get { KeychainStore.get(id) ?? apiKeyLegacy }
        set {
            KeychainStore.set(newValue, for: id)
            apiKeyLegacy = ""
        }
    }

    init(id: String, name: String, kind: String = "openai", baseURL: String, apiKey: String = "", models: [String] = [], imageCapability: String = "auto") {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL
        self.models = models
        self.createdAt = Date()
        self.imageCapability = imageCapability
        self.apiKeyLegacy = ""
        if !apiKey.isEmpty { KeychainStore.set(apiKey, for: id) }
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

    /// Mueve las claves legacy (texto plano) al Keychain una sola vez. Solo borra
    /// el respaldo legacy si la escritura en Keychain fue exitosa: nunca se pierde
    /// una clave. Idempotente.
    static func migrateKeysToKeychain(in context: ModelContext) {
        guard let providers = try? context.fetch(FetchDescriptor<ProviderConfig>()) else { return }
        var changed = false
        for p in providers where !p.apiKeyLegacy.isEmpty {
            if KeychainStore.set(p.apiKeyLegacy, for: p.id) {
                p.apiKeyLegacy = ""
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}

/// Almacén de API keys en el Keychain del dispositivo. Generic-password, accesible
/// tras el primer desbloqueo y solo en este dispositivo (no se sincroniza ni respalda).
enum KeychainStore {
    private static let service = "com.openpilot.app.providerkeys"

    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return true }   // vacío = borrar, nada que guardar
        var attrs = base
        attrs[kSecValueData as String] = Data(value.utf8)
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
