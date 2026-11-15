import Foundation
import SwiftData

/// Motor del "modo sueño": lee conversaciones recientes del dispositivo, se las
/// pasa al modelo elegido para consolidar un perfil aprendido y lo guarda.
/// Corre en segundo plano (fire-and-forget o botón manual), sin backend: la única
/// salida de red es la petición directa al provider que el usuario configuró.
@MainActor
enum DreamEngine {
    struct Outcome {
        let ok: Bool
        let message: String
        let items: Int
    }

    /// Consolida el perfil a partir del historial reciente. Devuelve un resultado
    /// para que la UI muestre estado (éxito con nº de hechos, o motivo del fallo).
    static func dream(provider: ProviderConfig, model: String, context: ModelContext, maxConversations: Int = 8) async -> Outcome {
        let desc = FetchDescriptor<Conversation>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let all = try? context.fetch(desc) else {
            return Outcome(ok: false, message: T("Couldn't read history.", "No se pudo leer el historial."), items: 0)
        }
        let convs = all.filter { !$0.isTemporary && !$0.isArchived }
        let recent = convs.sorted { latestActivity($0) > latestActivity($1) }.prefix(maxConversations)

        var msgs: [(role: String, text: String)] = []
        for c in recent {
            for m in c.activeMessages where m.role == "user" || m.role == "assistant" {
                msgs.append((role: m.role, text: m.text))
            }
        }
        let transcript = DreamSupport.transcript(msgs)
        guard !transcript.isEmpty else {
            return Outcome(ok: false, message: T("No conversations to review yet.", "Aún no hay conversaciones que revisar."), items: 0)
        }

        let prompt = DreamSupport.consolidationPrompt(existing: ProfileStore.profile, transcript: transcript)
        var out = ""
        do {
            for try await ev in ProviderFactory.make(kind: provider.kind).stream(
                turns: [ChatTurn(role: "user", content: prompt)],
                model: model, baseURL: provider.baseURL, apiKey: provider.apiKey) {
                if case .delta(let t) = ev { out += t }
            }
        } catch {
            return Outcome(ok: false, message: T("The model didn't respond.", "El modelo no respondió.") + " " + error.localizedDescription, items: 0)
        }

        let sections = DreamSupport.parseProfile(out)
        guard !sections.isEmpty else {
            return Outcome(ok: false, message: T("No valid profile returned.", "El modelo no devolvió un perfil válido."), items: 0)
        }
        ProfileStore.save(sections: sections)
        let n = sections.reduce(0) { $0 + $1.items.count }
        return Outcome(ok: true, message: T("Profile updated.", "Perfil actualizado."), items: n)
    }

    /// Fecha de actividad más reciente de una conversación (último mensaje).
    private static func latestActivity(_ c: Conversation) -> Date {
        c.messages.map(\.createdAt).max() ?? c.createdAt
    }
}