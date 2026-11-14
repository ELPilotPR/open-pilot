import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProviderConfig.createdAt) private var providers: [ProviderConfig]
    @AppStorage("imageModel") private var imageModel = "dall-e-3"
    @AppStorage("responseStyle") private var responseStyle = "conciso"

    var body: some View {
        List {
            Section {
                Picker(T("Language", "Idioma"), selection: langBinding) {
                    Text(T("Automatic", "Automático")).tag(Optional<AppLang>.none)
                    Text("English").tag(Optional<AppLang>.some(.en))
                    Text("Español").tag(Optional<AppLang>.some(.es))
                }
            } header: {
                Text(T("Language", "Idioma"))
            } footer: {
                Text(T("Follows your device language by default.", "Sigue el idioma de tu dispositivo por defecto."))
            }

            Section {
                ForEach(providers) { p in
                    NavigationLink {
                        ProviderEditorView(provider: p)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).foregroundStyle(OP.textPrimary)
                            Text(p.baseURL).font(.caption).foregroundStyle(OP.textSecondary).lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text(T("Providers", "Proveedores"))
            } footer: {
                Text(T("Stored only on this iPhone. The app connects directly to the model, no backend. Add any OpenAI-compatible API (your local server, OpenAI, OpenRouter…) or Anthropic.", "Se guardan solo en este iPhone. La app conecta directo al modelo, sin backend. Agrega cualquier API OpenAI-compatible (tu server local, OpenAI, OpenRouter…) o Anthropic."))
            }

            Section {
                TextField(T("Image model", "Modelo de imágenes"), text: $imageModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text(T("Images", "Imágenes"))
            } footer: {
                Text(T("Qwen/DashScope: uses wan2.7-image automatically (included in your plan). OpenAI: dall-e-3 or gpt-image-1. To analyze photos it uses the vision chat model (gpt-4o, qwen-vl).", "Qwen/DashScope: usa wan2.7-image automáticamente (incluido en tu plan). OpenAI: dall-e-3 o gpt-image-1. Para analizar fotos se usa el modelo de chat con visión (gpt-4o, qwen-vl)."))
            }

            Section {
                Picker(T("Response style", "Estilo de respuesta"), selection: $responseStyle) {
                    ForEach(ResponseStyle.allCases) { s in
                        Text(s.label).tag(s.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(T("Responses", "Respuestas"))
            } footer: {
                Text(T("Concise: short, direct answers. Detailed: in-depth analysis.", "Conciso: respuesta directa y corta. Detallado: análisis a fondo."))
            }

            Section {
                Button { addProvider() } label: {
                    Label(T("Add OpenAI-compatible API", "Agregar API OpenAI-compatible"), systemImage: "plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(T("Settings", "Ajustes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(T("Done", "Listo")) { dismiss() }
            }
        }
    }

    private var langBinding: Binding<AppLang?> {
        Binding(get: { LanguageManager.shared.override },
                set: { LanguageManager.shared.override = $0 })
    }

    private func addProvider() {
        let p = ProviderConfig(
            id: "api-" + UUID().uuidString.prefix(6).lowercased(),
            name: T("New API", "Nueva API"), kind: "openai", baseURL: "https://", models: []
        )
        context.insert(p)
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            let p = providers[i]
            KeychainStore.delete(p.id)
            context.delete(p)
        }
        try? context.save()
    }
}