import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Soporte puro del proveedor on-device (testeable sin el framework ni red).
enum OnDeviceSupport {
    static let kind = "ondevice"
    static let modelID = "apple-intelligence"
    static let displayName = "On-device (Apple Intelligence)"

    /// Convierte los turnos normalizados en (instrucciones de sistema, prompt).
    /// El modelo del sistema recibe un único prompt; el historial se renderiza
    /// etiquetado por rol para conservar el contexto de la conversación.
    static func flatten(_ turns: [ChatTurn]) -> (instructions: String?, prompt: String) {
        let system = turns.filter { $0.role == "system" }.map { $0.content }.joined(separator: "\n")
        let prompt = turns.filter { $0.role != "system" }.map { t -> String in
            let label = t.role == "assistant" ? "Assistant" : "User"
            return "\(label): \(t.content)"
        }.joined(separator: "\n")
        return (system.isEmpty ? nil : system, prompt)
    }

    /// Delta incremental a partir de snapshots acumulados del stream.
    static func delta(previous: String, current: String) -> String {
        if current.hasPrefix(previous) { return String(current.dropFirst(previous.count)) }
        return current
    }

    /// Mensaje de estado legible para la UI.
    static func availabilityMessage(available: Bool, reason: String?) -> String {
        if available { return "On-device model ready (Apple Intelligence)." }
        if let r = reason, !r.isEmpty { return "On-device model unavailable: \(r)." }
        return "On-device model unavailable on this device."
    }
}

/// Proveedor on-device real: usa el modelo de lenguaje del sistema de Apple
/// (FoundationModels / Apple Intelligence). 100% en el dispositivo, sin backend,
/// sin descarga de modelos y sin API key. Conformar ChatProvider permite usarlo
/// desde la misma UI/persistencia que cualquier proveedor cloud.
struct OnDeviceProvider: ChatProvider {
    func stream(turns: [ChatTurn], model: String, baseURL: String, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    let system = SystemLanguageModel.default
                    guard system.isAvailable else {
                        continuation.finish(throwing: ProviderError.transport(OnDeviceProvider.currentStatus()))
                        return
                    }
                    let flat = OnDeviceSupport.flatten(turns)
                    let session = LanguageModelSession(model: system, instructions: flat.instructions)
                    var previous = ""
                    do {
                        for try await snapshot in session.streamResponse(to: flat.prompt) {
                            let current = snapshot.content
                            let d = OnDeviceSupport.delta(previous: previous, current: current)
                            if !d.isEmpty { continuation.yield(.delta(d)) }
                            previous = current
                        }
                        continuation.yield(.done)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }
                #endif
                continuation.finish(throwing: ProviderError.transport("On-device requires iOS 26 or later."))
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func models(baseURL: String, apiKey: String) async throws -> [String] {
        [OnDeviceSupport.modelID]
    }

    /// Estado actual del modelo del sistema, para mostrar en el editor.
    static func currentStatus() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return OnDeviceSupport.availabilityMessage(available: true, reason: nil)
            case .unavailable(let reason):
                return OnDeviceSupport.availabilityMessage(available: false, reason: String(describing: reason))
            }
        }
        #endif
        return "On-device requires iOS 26 or later."
    }
}
