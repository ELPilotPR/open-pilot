import Foundation
import SwiftData

/// Espeja el proveedor activo al App Group para el teclado (opt-in). Si el usuario
/// no activó el teclado, limpia el snapshot (no deja la clave compartida).
@MainActor
enum KeyboardBridge {
    static func refresh(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "keyboardEnabled") else {
            KeyboardShared.clear()
            return
        }
        let providers = (try? context.fetch(FetchDescriptor<ProviderConfig>())) ?? []
        // El cliente del teclado habla OpenAI-compatible; prioriza ese kind.
        let pick = providers.first(where: { $0.kind == "openai" })
            ?? providers.first(where: { $0.kind != "anthropic" && $0.kind != "ondevice" })
        guard let p = pick else {
            KeyboardShared.clear()
            return
        }
        let key = p.apiKey
        let model = p.models.first ?? "gpt-4o-mini"
        KeyboardShared.save(KeyboardProvider(kind: p.kind, baseURL: p.baseURL, apiKey: key, model: model, name: p.name))
    }
}