import Foundation

/// Enruta turnos con imagen a un modelo multimodal cuando el elegido es solo-texto.
/// Conservador: nunca toca proveedores locales/LAN ni on-device (no adivina modelos cloud).
enum VisionRouting {
    /// Heurística por id de modelo: ¿acepta imágenes?
    static func isVisionCapable(_ model: String) -> Bool {
        let m = model.lowercased()
        if m.isEmpty { return false }
        let textOnly = ["gpt-3.5", "text-", "davinci", "babbage", "embedding", "whisper", "tts", "dall-e"]
        if textOnly.contains(where: { m.contains($0) }) { return false }
        let vision = ["gpt-4o", "gpt-4.1", "gpt-4-vision", "gpt-4-turbo", "gpt-5", "o3", "o4",
                      "claude-3", "claude-4", "claude-sonnet", "claude-opus", "claude-haiku",
                      "gemini", "qwen-vl", "qwen2-vl", "qwen2.5-vl", "llava", "vision",
                      "pixtral", "internvl", "minicpm-v", "moondream"]
        return vision.contains { m.contains($0) }
    }

    /// ¿Es un endpoint local/LAN? (no enrutar a un modelo cloud que no existe ahí)
    static func isLocal(_ baseURL: String) -> Bool {
        let b = baseURL.lowercased()
        return b.contains("localhost") || b.contains("127.0.0.1") || b.contains("192.168.")
            || b.contains("10.") || b.contains(".local")
    }

    /// Modelo vision por defecto para un kind de provider cloud (nil si no se conoce).
    static func defaultVisionModel(kind: String) -> String? {
        switch kind.lowercased() {
        case "anthropic": return "claude-3-5-sonnet-latest"
        case "ondevice": return nil
        default: return "gpt-4o-mini"
        }
    }

    /// Modelo efectivo para un turno: si hay imagen y el actual no ve, usa uno que sí.
    static func effectiveModel(current: String, hasImage: Bool, kind: String, baseURL: String) -> String {
        guard hasImage, !isLocal(baseURL), kind.lowercased() != "ondevice" else { return current }
        if isVisionCapable(current) { return current }
        return defaultVisionModel(kind: kind) ?? current
    }
}