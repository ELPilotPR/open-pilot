import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProviderConfig.createdAt) private var providers: [ProviderConfig]
    @AppStorage("imageModel") private var imageModel = "dall-e-3"
    @AppStorage("responseStyle") private var responseStyle = "conciso"
    @AppStorage("appearanceMode") private var appearanceMode = "auto"
    @AppStorage("accentColor") private var accentColor = "blue"
    @AppStorage("customInstructionsEnabled") private var ciEnabled = true
    @AppStorage("customAboutYou") private var ciAbout = ""
    @AppStorage("customResponsePrefs") private var ciPrefs = ""
    @AppStorage("context.autoCompact") private var autoCompact = true
    @AppStorage("context.budget") private var contextBudget = 6000
    @State private var showVoicePicker = false

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
                Picker(T("Appearance", "Apariencia"), selection: $appearanceMode) {
                    Text(T("Automatic", "Automático")).tag("auto")
                    Text(T("Light", "Claro")).tag("light")
                    Text(T("Dark", "Oscuro")).tag("dark")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(T("Accent color", "Color de acento")).font(.subheadline).foregroundStyle(OP.textSecondary)
                    AccentSwatchPicker(selection: $accentColor)
                }
                .padding(.vertical, 2)
            } header: {
                Text(T("Appearance", "Apariencia"))
            } footer: {
                Text(T("Follows your device setting by default.", "Sigue la configuración de tu dispositivo por defecto."))
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
                Toggle(T("Auto-compact context", "Auto-compactar contexto"), isOn: $autoCompact)
                Picker(T("Context budget", "Presupuesto de contexto"), selection: $contextBudget) {
                    Text("2k tokens").tag(2000)
                    Text("4k tokens").tag(4000)
                    Text("6k tokens").tag(6000)
                    Text("8k tokens").tag(8000)
                    Text("12k tokens").tag(12000)
                }
            } header: {
                Text(T("Context", "Contexto"))
            } footer: {
                Text(T("When a chat grows past the budget, older messages are condensed into a summary so it stays within the model's window. Recent messages are kept verbatim.",
                       "Cuando un chat supera el presupuesto, los mensajes antiguos se condensan en un resumen para no exceder la ventana del modelo. Los recientes se conservan intactos."))
            }

            Section {
                NavigationLink {
                    CustomInstructionsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Custom instructions", "Instrucciones personalizadas"))
                            .foregroundStyle(OP.textPrimary)
                        Text(ciStatus).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            } header: {
                Text(T("Personalization", "Personalización"))
            } footer: {
                Text(T("Tell the model about you and how you want it to respond. Applies to every chat.",
                       "Dile al modelo sobre ti y cómo quieres que responda. Se aplica a todos los chats."))
            }

            Section {
                NavigationLink {
                    PromptLibraryView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Prompt library", "Librería de prompts")).foregroundStyle(OP.textPrimary)
                        Text(T("Reusable prompts, insert with /", "Prompts reutilizables, inserta con /")).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    UsageDashboardView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Usage", "Uso")).foregroundStyle(OP.textPrimary)
                        Text(T("Tokens and estimated cost per provider", "Tokens y coste estimado por proveedor")).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    MemoryView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Memory", "Memoria")).foregroundStyle(OP.textPrimary)
                        Text(memoryStatus).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            } header: {
                Text(T("Memory", "Memoria"))
            } footer: {
                Text(T("Durable facts remembered across chats, stored only on this iPhone.",
                       "Hechos duraderos recordados entre chats, guardados solo en este iPhone."))
            }

            Section {
                Button { showVoicePicker = true } label: {
                    HStack {
                        Label(T("Voice", "Voz"), systemImage: "speaker.wave.2")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(OP.textTertiary)
                    }
                }
            } header: {
                Text(T("Speech", "Voz"))
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
        .sheet(isPresented: $showVoicePicker) { VoicePickerView() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(T("Done", "Listo")) { dismiss() }
            }
        }
    }

    private var ciStatus: String {
        if !ciEnabled { return T("Off", "Desactivadas") }
        let has = !ciAbout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !ciPrefs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return has ? T("On", "Activadas") : T("Not set", "Sin configurar")
    }

    private var memoryStatus: String {
        if !MemoryStore.enabled { return T("Off", "Desactivada") }
        let n = MemoryStore.entries.count
        return n == 0 ? T("No memories yet", "Sin recuerdos") : T("\(n) memories", "\(n) recuerdos")
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