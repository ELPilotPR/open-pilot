import SwiftUI
import SwiftData

/// Hoja de evidencia por turno: modelo, tiempos (TTFT/total), tok/s, tokens
/// prompt/completion, contenido y metadatos. Todo client-side, sin red.
struct TurnInspectorView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @Query private var providers: [ProviderConfig]

    private var totalTokens: Int { message.promptTokens + message.completionTokens }

    private var isLocalProvider: Bool {
        guard let pid = message.conversation?.providerID,
              let p = providers.first(where: { $0.id == pid }) else { return false }
        return UsagePricing.isLocal(kind: p.kind, baseURL: p.baseURL)
    }

    private var costLabel: String {
        if isLocalProvider { return T("Local (free)", "Local (gratis)") }
        let cost = UsagePricing.costUSD(model: message.conversation?.model ?? "",
                                        promptTokens: message.promptTokens,
                                        completionTokens: message.completionTokens,
                                        local: false)
        return TurnInspector.formatCost(cost)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(T("Model", "Modelo"), message.conversation?.model ?? "—")
                    row(T("Provider", "Proveedor"), message.conversation?.providerID ?? "—")
                    row(T("Role", "Rol"), message.role)
                } header: { Text(T("Turn", "Turno")) }

                Section {
                    row(T("Time to first token", "Tiempo al primer token"), TurnInspector.formatDuration(message.ttft))
                    row(T("Total time", "Tiempo total"), TurnInspector.formatDuration(message.elapsed))
                    row(T("Speed", "Velocidad"), TurnInspector.formatTPS(message.tokensPerSecond) + " tok/s")
                } header: { Text(T("Timing", "Tiempos")) }

                Section {
                    row(T("Prompt tokens", "Tokens de entrada"), "↑ " + TurnInspector.formatCount(message.promptTokens))
                    row(T("Completion tokens", "Tokens de salida"), "↓ " + TurnInspector.formatCount(message.completionTokens))
                    row(T("Total tokens", "Tokens totales"), TurnInspector.formatCount(totalTokens))
                    row(T("Estimated cost", "Coste estimado"), costLabel)
                } header: { Text(T("Tokens", "Tokens")) }

                Section {
                    row(T("Characters", "Caracteres"), "\(message.text.count)")
                    row(T("Reasoning characters", "Caracteres de razonamiento"), "\(message.reasoning.count)")
                    row(T("Sources", "Fuentes"), "\(message.sources.count)")
                    row(T("Citations", "Citas"), "\(message.citations.count)")
                    if let att = message.attachmentName { row(T("Attachment", "Adjunto"), att) }
                } header: { Text(T("Content", "Contenido")) }

                Section {
                    row(T("Created", "Creado"), createdLabel)
                    row(T("Version", "Versión"), "\(message.version)")
                    row(T("Feedback", "Voto"), feedbackLabel)
                } header: { Text(T("Metadata", "Metadatos")) }
            }
            .navigationTitle(T("Turn inspector", "Inspector de turno"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Done", "Listo")) { dismiss() }
                }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(OP.textSecondary)
            Spacer()
            Text(v).foregroundStyle(OP.textPrimary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var createdLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: message.createdAt)
    }

    private var feedbackLabel: String {
        message.feedback > 0 ? "👍" : (message.feedback < 0 ? "👎" : "—")
    }
}
