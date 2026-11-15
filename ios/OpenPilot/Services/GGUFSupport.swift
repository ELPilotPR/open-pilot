import Foundation

/// Un modelo GGUF descargable de Hugging Face (tamaños aproximados).
struct GGUFModel: Identifiable, Equatable {
    let id: String        // repo de Hugging Face
    let filename: String  // archivo .gguf
    let name: String
    let sizeGB: Double
    let note: String
}

/// Soporte puro del proveedor GGUF (testeable sin el runtime ni red).
enum GGUFSupport {
    static let kind = "gguf"
    static let displayName = "On-device (GGUF / llama.cpp)"

    /// Modelos pequeños pensados para iPhone; el usuario también puede añadir uno propio.
    static let catalog: [GGUFModel] = [
        GGUFModel(id: "Qwen/Qwen2.5-0.5B-Instruct-GGUF", filename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
                  name: "Qwen2.5 0.5B (Q4)", sizeGB: 0.4, note: "Tiny and fast; good for older iPhones."),
        GGUFModel(id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF", filename: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
                  name: "Qwen2.5 1.5B (Q4)", sizeGB: 1.0, note: "Balanced quality and size."),
        GGUFModel(id: "bartowski/Llama-3.2-1B-Instruct-GGUF", filename: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                  name: "Llama 3.2 1B (Q4)", sizeGB: 0.8, note: "Meta's small instruct model."),
        GGUFModel(id: "lmstudio-community/gemma-3-4B-it-qat-GGUF", filename: "gemma-3-4B-it-QAT-Q4_0.gguf",
                  name: "Gemma 3 4B (QAT Q4)", sizeGB: 2.5, note: "Higher quality; needs ~6 GB of RAM."),
    ]

    static func model(for filename: String) -> GGUFModel? { catalog.first { $0.filename == filename } }

    /// Convierte turnos normalizados en (instrucciones de sistema, prompt etiquetado).
    static func flatten(_ turns: [ChatTurn]) -> (instructions: String?, prompt: String) {
        let system = turns.filter { $0.role == "system" }.map { $0.content }.joined(separator: "\n")
        let prompt = turns.filter { $0.role != "system" }.map { t -> String in
            let label = t.role == "assistant" ? "Assistant" : "User"
            return "\(label): \(t.content)"
        }.joined(separator: "\n")
        return (system.isEmpty ? nil : system, prompt)
    }

    /// Delta incremental a partir de snapshots acumulados (por si el backend acumula).
    static func delta(previous: String, current: String) -> String {
        if current.hasPrefix(previous) { return String(current.dropFirst(previous.count)) }
        return current
    }
}