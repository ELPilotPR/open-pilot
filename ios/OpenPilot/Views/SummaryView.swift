import SwiftUI
import SwiftData

/// TL;DR de una conversación: resumen extractivo local inmediato (sin red) y,
/// opcionalmente, un resumen más rico generado por el provider del usuario.
struct SummaryView: View {
    let conversation: Conversation?
    @Environment(\.dismiss) private var dismiss
    @Query private var providers: [ProviderConfig]
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @State private var aiSummary: String?
    @State private var loading = false
    @State private var failed = false

    private var provider: ProviderConfig? {
        let id = conversation?.providerID ?? selectedProviderID
        return providers.first { $0.id == id } ?? providers.first
    }
    private var bullets: [String] { ConversationSummarizer.extractive(conversation?.messages ?? []) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if bullets.isEmpty {
                        Text(T("Nothing to summarize yet.", "Aún no hay nada que resumir."))
                            .foregroundStyle(OP.textSecondary)
                    } else {
                        section(T("Key points (on-device)", "Puntos clave (en el dispositivo)")) {
                            ForEach(Array(bullets.enumerated()), id: \.offset) { _, b in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•").foregroundStyle(OP.accent)
                                    Text(b).font(.subheadline).foregroundStyle(OP.textPrimary)
                                }
                            }
                        }
                    }

                    if let ai = aiSummary {
                        section(T("AI summary", "Resumen con IA")) {
                            Text(ai).font(.subheadline).foregroundStyle(OP.textPrimary)
                        }
                    }

                    Button {
                        generateAI()
                    } label: {
                        HStack {
                            if loading { ProgressView().tint(.white) }
                            Text(loading ? T("Summarizing…", "Resumiendo…")
                                         : T("Generate with AI", "Generar con IA"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(OP.accent)
                    .disabled(loading || provider == nil || (conversation?.messages.isEmpty ?? true))

                    if failed {
                        Text(T("Couldn't reach the model. The on-device summary above still works.",
                               "No se pudo contactar el modelo. El resumen local de arriba sigue disponible."))
                            .font(.caption).foregroundStyle(OP.danger)
                    }
                }
                .padding(16)
            }
            .navigationTitle(T("Summary", "Resumen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } } }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(OP.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(OP.elevated).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func generateAI() {
        guard let p = provider, let c = conversation else { return }
        let kind = p.kind, base = p.baseURL, api = p.apiKey, model = c.model
        let prompt = ConversationSummarizer.aiPrompt(c.messages)
        loading = true; failed = false
        Task { @MainActor in
            let result = await OneShot.complete(prompt: prompt, kind: kind, model: model, baseURL: base, apiKey: api)
            loading = false
            if let r = result { aiSummary = r } else { failed = true }
        }
    }
}