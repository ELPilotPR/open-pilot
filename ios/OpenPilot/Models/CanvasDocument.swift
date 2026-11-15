import Foundation
import SwiftUI

extension Notification.Name {
    /// Un bloque de código pide abrir su contenido en Canvas. userInfo: ["lang": String, "code": String].
    static let openCanvas = Notification.Name("op.openCanvas")
}

/// Documento editable de Canvas: texto o código que el usuario puede modificar a
/// mano o pedir al modelo que revise. Cada revisión del modelo se guarda como una
/// versión navegable (< n/m >), igual que los mensajes del chat. Sin backend.
@MainActor
final class CanvasDocument: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String
    @Published var content: String
    @Published var language: String
    @Published var versions: [String]
    @Published var versionIndex: Int = 0
    @Published var isStreaming = false
    @Published var statusText = ""

    init(title: String = "Canvas", content: String = "", language: String = "") {
        self.title = title
        self.content = content
        self.language = language
        self.versions = [content]
    }

    var versionTotal: Int { versions.count }

    func switchVersion(_ i: Int) {
        guard i >= 0, i < versions.count else { return }
        versionIndex = i
        content = versions[i]
    }

    /// Pide al modelo una revisión y la aplica como nueva versión. Conserva la
    /// edición manual actual como base antes de añadir el resultado.
    func applyEdit(instruction: String, provider: ProviderConfig, model: String) {
        let instr = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instr.isEmpty, !isStreaming else { return }
        isStreaming = true
        statusText = T("Editing…", "Editando…")
        let snapshot = content
        versions[versionIndex] = snapshot   // captura la edición manual en el historial
        let lang = language
        let system = "Eres un editor de documentos y código. Recibes el documento completo y un cambio pedido. Devuelve ÚNICAMENTE el documento completo actualizado, sin explicaciones, sin comentarios y sin fences de código."
        let user = "Documento actual" + (lang.isEmpty ? "" : " (\(lang))") + ":\n\n\(snapshot)\n\nCambio pedido: \(instr)"
        let turns = [ChatTurn(role: "system", content: system), ChatTurn(role: "user", content: user)]
        let client = ProviderFactory.make(kind: provider.kind)
        let base = provider.baseURL, key = provider.apiKey
        Task { @MainActor in
            var buffer = ""
            do {
                for try await ev in client.stream(turns: turns, model: model, baseURL: base, apiKey: key) {
                    if case .delta(let d) = ev {
                        buffer += d
                        self.content = Self.strip(buffer)
                    }
                }
                let final = Self.strip(buffer)
                if !final.isEmpty {
                    self.versions.append(final)
                    self.versionIndex = self.versions.count - 1
                    self.content = final
                    self.statusText = ""
                } else {
                    self.content = snapshot
                    self.statusText = T("No changes", "Sin cambios")
                }
            } catch {
                self.content = snapshot
                self.statusText = T("Error", "Error") + ": \(error.localizedDescription)"
            }
            self.isStreaming = false
        }
    }

    /// Quita fences ```lang … ``` si el modelo los añade pese a la instrucción.
    static func strip(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let nl = t.firstIndex(of: "\n") { t = String(t[t.index(after: nl)...]) }
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}
