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
                Text("Proveedores")
            } footer: {
                Text("Se guardan solo en este iPhone. La app conecta directo al modelo, sin backend. Agrega cualquier API OpenAI-compatible (tu server local, OpenAI, OpenRouter…) o Anthropic.")
            }

            Section {
                TextField("Modelo de imágenes", text: $imageModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Imágenes")
            } footer: {
                Text("Qwen/DashScope: usa wan2.7-image automáticamente (incluido en tu plan). OpenAI: dall-e-3 o gpt-image-1. Para analizar fotos se usa el modelo de chat con visión (gpt-4o, qwen-vl).")
            }

            Section {
                Picker("Estilo de respuesta", selection: $responseStyle) {
                    ForEach(ResponseStyle.allCases) { s in
                        Text(s.label).tag(s.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Respuestas")
            } footer: {
                Text("Conciso: respuesta directa y corta. Detallado: análisis a fondo.")
            }

            Section {
                Button { addProvider() } label: {
                    Label("Agregar API OpenAI-compatible", systemImage: "plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { dismiss() }
            }
        }
    }

    private func addProvider() {
        let p = ProviderConfig(
            id: "api-" + UUID().uuidString.prefix(6).lowercased(),
            name: "Nueva API", kind: "openai", baseURL: "https://", models: []
        )
        context.insert(p)
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(providers[i]) }
        try? context.save()
    }
}