import SwiftUI
import SwiftData

/// Pregunta a los adjuntos de la conversación con RAG local: recupera los
/// fragmentos relevantes en el dispositivo (NaturalLanguage, sin red) y,
/// opcionalmente, responde con el provider del usuario usando ese contexto.
struct AttachmentQAView: View {
    let conversation: Conversation?
    @Environment(\.dismiss) private var dismiss
    @Query private var providers: [ProviderConfig]
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @AppStorage("selectedModel") private var selectedModel = "swift-iq3_s"
    @State private var question = ""
    @State private var excerpts: [(RAGChunk, Double)] = []
    @State private var answer: String?
    @State private var loading = false
    @State private var failed = false
    @State private var searched = false

    private var attachments: [(name: String, text: String)] {
        var seen = Set<String>(); var out: [(name: String, text: String)] = []
        for m in conversation?.messages ?? [] {
            if let t = m.attachmentText, !t.isEmpty {
                let n = m.attachmentName ?? "attachment"
                if !seen.contains(n) { seen.insert(n); out.append((n, t)) }
            }
        }
        return out
    }
    private var provider: ProviderConfig? {
        providers.first { $0.id == (conversation?.providerID ?? selectedProviderID) } ?? providers.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Attachments", "Adjuntos")) {
                    if attachments.isEmpty {
                        Text(T("No text attachments in this chat.", "No hay adjuntos de texto en este chat."))
                            .foregroundStyle(OP.textSecondary)
                    } else {
                        ForEach(attachments, id: \.name) { a in
                            Label(a.name, systemImage: "doc.text").font(.subheadline)
                        }
                    }
                }
                Section(T("Question", "Pregunta")) {
                    TextField(T("Ask about your documents…", "Pregunta sobre tus documentos…"), text: $question, axis: .vertical)
                        .lineLimit(1...4)
                    Button { findExcerpts() } label: {
                        Label(T("Find relevant excerpts (on-device)", "Buscar fragmentos relevantes (en el dispositivo)"), systemImage: "text.magnifyingglass")
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || attachments.isEmpty)
                    Button { askAI() } label: {
                        HStack { if loading { ProgressView() }; Label(T("Ask AI with context", "Preguntar a la IA con contexto"), systemImage: "sparkles") }
                    }
                    .disabled(loading || provider == nil || question.trimmingCharacters(in: .whitespaces).isEmpty || attachments.isEmpty)
                    if failed {
                        Text(T("Couldn't reach the model.", "No se pudo contactar el modelo.")).font(.caption).foregroundStyle(OP.danger)
                    }
                }
                if searched {
                    Section(T("Relevant excerpts", "Fragmentos relevantes")) {
                        if excerpts.isEmpty {
                            Text(T("No embeddings available on this device.", "No hay embeddings disponibles en este dispositivo."))
                                .font(.caption).foregroundStyle(OP.textSecondary)
                        } else {
                            ForEach(Array(excerpts.enumerated()), id: \.offset) { _, e in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(e.0.source).font(.caption2).foregroundStyle(OP.accent)
                                    Text(e.0.text).font(.caption).foregroundStyle(OP.textPrimary)
                                }
                            }
                        }
                    }
                }
                if let a = answer {
                    Section(T("Answer", "Respuesta")) { Text(a).textSelection(.enabled) }
                }
            }
            .navigationTitle(T("Ask attachments", "Preguntar a adjuntos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } } }
        }
    }

    private func findExcerpts() {
        let chunks = attachments.flatMap { LocalRAG.chunk($0.text, source: $0.name) }
        excerpts = LocalRAG.retrieve(query: question, chunks: chunks)
        searched = true; Haptic.light()
    }
    private func askAI() {
        guard let p = provider else { return }
        var ctx = LocalRAG.context(query: question, attachments: attachments)
        if ctx.isEmpty { ctx = attachments.map { "[\($0.name)] \($0.text.prefix(1500))" }.joined(separator: "\n\n") }
        let kind = p.kind, base = p.baseURL, api = p.apiKey, model = selectedModel
        let prompt = LocalRAG.qaPrompt(question: question, context: ctx)
        loading = true; failed = false
        Task { @MainActor in
            let r = await OneShot.complete(prompt: prompt, kind: kind, model: model, baseURL: base, apiKey: api)
            loading = false
            if let r { answer = r } else { failed = true }
        }
    }
}