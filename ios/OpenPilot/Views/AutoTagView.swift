import SwiftUI
import SwiftData

/// Etiquetas de una conversación: auto-etiquetado local (sin red), sugerencia
/// con IA (provider del usuario) y edición manual. Persiste en Conversation.tags.
struct AutoTagView: View {
    let conversation: Conversation?
    @Environment(\.dismiss) private var dismiss
    @Query private var providers: [ProviderConfig]
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var loading = false
    @State private var failed = false

    private var provider: ProviderConfig? {
        providers.first { $0.id == (conversation?.providerID ?? selectedProviderID) } ?? providers.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Tags", "Etiquetas")) {
                    if tags.isEmpty {
                        Text(T("No tags yet.", "Sin etiquetas aún.")).foregroundStyle(OP.textSecondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag).font(.caption)
                                    Button { remove(tag) } label: { Image(systemName: "xmark.circle.fill").font(.caption2) }
                                        .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(OP.accent.opacity(0.15)).clipShape(Capsule())
                            }
                        }
                    }
                    HStack {
                        TextField(T("Add tag", "Añadir etiqueta"), text: $newTag)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button(T("Add", "Añadir")) { add() }
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    Button { autoTag() } label: {
                        Label(T("Auto-tag (on-device)", "Auto-etiquetar (en el dispositivo)"), systemImage: "wand.and.stars")
                    }
                    .disabled(conversation?.messages.isEmpty ?? true)
                    Button { aiTags() } label: {
                        HStack { if loading { ProgressView() }; Label(T("Suggest with AI", "Sugerir con IA"), systemImage: "sparkles") }
                    }
                    .disabled(loading || provider == nil || (conversation?.messages.isEmpty ?? true))
                    if failed {
                        Text(T("Couldn't reach the model.", "No se pudo contactar el modelo."))
                            .font(.caption).foregroundStyle(OP.danger)
                    }
                }
            }
            .navigationTitle(T("Tags", "Etiquetas")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Done", "Listo")) { save(); dismiss() } } }
            .onAppear { tags = conversation?.tags ?? [] }
        }
    }

    private func save() { conversation?.tags = tags }
    private func add() {
        let t = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t); newTag = ""; save()
    }
    private func remove(_ t: String) { tags.removeAll { $0 == t }; save() }
    private func autoTag() {
        guard let c = conversation else { return }
        for t in AutoTagger.tags(for: c.messages) where !tags.contains(t) { tags.append(t) }
        save(); Haptic.light()
    }
    private func aiTags() {
        guard let p = provider, let c = conversation else { return }
        let kind = p.kind, base = p.baseURL, api = p.apiKey, model = c.model
        let prompt = AutoTagger.aiPrompt(c.messages)
        loading = true; failed = false
        Task { @MainActor in
            let r = await OneShot.complete(prompt: prompt, kind: kind, model: model, baseURL: base, apiKey: api)
            loading = false
            if let r { for t in AutoTagger.parseAITags(r) where !tags.contains(t) { tags.append(t) }; save() }
            else { failed = true }
        }
    }
}