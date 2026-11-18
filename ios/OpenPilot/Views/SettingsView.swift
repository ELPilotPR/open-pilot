import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProviderConfig.createdAt) private var providers: [ProviderConfig]
    @Query private var conversations: [Conversation]
    @AppStorage("imageModel") private var imageModel = "dall-e-3"
    @AppStorage("responseStyle") private var responseStyle = "conciso"
    @AppStorage("appearanceMode") private var appearanceMode = "auto"
    @AppStorage("showUsageBadges") private var showUsageBadges = true
    @AppStorage("showCostEstimates") private var showCostEstimates = true
    @AppStorage("accentColor") private var accentColor = "blue"
    @AppStorage("customInstructionsEnabled") private var ciEnabled = true
    @AppStorage("customAboutYou") private var ciAbout = ""
    @AppStorage("customResponsePrefs") private var ciPrefs = ""
    @AppStorage("context.autoCompact") private var autoCompact = true
    @AppStorage("context.budget") private var contextBudget = 0
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("browseDepth") private var browseDepth = "standard"
    @State private var showVoicePicker = false
    @State private var showIntro = false
    @State private var backupShare: SharePayload?
    @State private var showBackupImport = false
    @State private var backupError: String?
    @State private var showBackupError = false
    @State private var pendingBackup: Backup.Bundle?
    @State private var showRestoreConfirm = false
    @State private var restoreMessage: String?
    @State private var showRestoreDone = false

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
                Toggle(T("Show usage & cost badges", "Mostrar consumo y coste"), isOn: $showUsageBadges)
                Toggle(T("Show cost estimates", "Mostrar coste estimado"), isOn: $showCostEstimates)
            } header: {
                Text(T("Appearance", "Apariencia"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Follows your device setting by default.", "Sigue la configuración de tu dispositivo por defecto."))
                    Text(T("Turn off cost estimates if you use a subscription (e.g. Qwen Token Plan) instead of pay-per-token API.", "Apaga el coste estimado si usas una subscripción (ej. Qwen Token Plan) en vez de API por token."))
                }
            }

            Section {
                Toggle(T("Haptic feedback", "Respuesta háptica"), isOn: $hapticsEnabled)
            } header: {
                Text(T("Feedback", "Feedback"))
            } footer: {
                Text(T("Subtle vibrations when you send, copy, or react. Turn off if you prefer a quieter feel.", "Vibraciones sutiles al enviar, copiar o reaccionar. Desactívalo si prefieres un tacto más silencioso."))
            }

            Section {
                Picker(T("Search depth", "Profundidad de búsqueda"), selection: $browseDepth) {
                    Text(T("Quick", "Rápida")).tag("quick")
                    Text(T("Standard", "Normal")).tag("standard")
                    Text(T("Deep", "Profunda")).tag("deep")
                }
            } header: {
                Text(T("Web search", "Búsqueda web"))
            } footer: {
                Text(T("How many pages the browser reads when browsing the web. Quick: 5 sources, reads 3. Standard: 8 sources, reads 5. Deep: 2 result pages, up to 12 sources, reads 8 in full.", "Cuántas páginas lee el navegador al buscar en la web. Rápida: 5 fuentes, lee 3. Normal: 8 fuentes, lee 5. Profunda: 2 páginas de resultados, hasta 12 fuentes, lee 8 completas."))
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
                    Text(T("Auto (by model)", "Auto (según modelo)")).tag(0)
                    Text("2k tokens").tag(2000)
                    Text("4k tokens").tag(4000)
                    Text("6k tokens").tag(6000)
                    Text("8k tokens").tag(8000)
                    Text("12k tokens").tag(12000)
                    Text("32k tokens").tag(32000)
                    Text("128k tokens").tag(128000)
                }
            } header: {
                Text(T("Context", "Contexto"))
            } footer: {
                Text(T("Auto scales the budget with the model's context window (~70%), so a 512k model keeps far more history. Pick a fixed value to override. When a chat grows past the budget, older messages are condensed into a summary; recent ones stay verbatim.",
                       "Auto escala el presupuesto con la ventana del modelo (~70%), así un modelo de 512k conserva mucho más historial. Elige un valor fijo para forzarlo. Cuando un chat supera el presupuesto, los mensajes antiguos se condensan en un resumen; los recientes se conservan intactos."))
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
                NavigationLink {
                    PersonasView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Personas", "Personas")).foregroundStyle(OP.textPrimary)
                        Text(PersonaStore.selected?.name ?? T("Default", "Por defecto"))
                            .font(.caption).foregroundStyle(OP.textSecondary)
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
                    SpotlightSettingsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Spotlight", "Spotlight")).foregroundStyle(OP.textPrimary)
                        Text(T("Search your chats from the system", "Busca tus chats desde el sistema")).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    FallbackSettingsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Fallback", "Respaldo")).foregroundStyle(OP.textPrimary)
                        Text(T("Retry with another provider on failure", "Reintenta con otro proveedor si falla")).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            }
            Section {
                NavigationLink {
                    KeyboardSettingsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("AI Keyboard", "Teclado IA")).foregroundStyle(OP.textPrimary)
                        Text(T("Ask your model from any app", "Pregunta a tu modelo desde cualquier app")).font(.caption).foregroundStyle(OP.textSecondary)
                    }
                }
            }
            Section {
                NavigationLink {
                    LocalModelsView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Local Models (GGUF)", "Modelos locales (GGUF)")).foregroundStyle(OP.textPrimary)
                        Text(T("Download on-device models for the GGUF provider", "Descarga modelos on-device para el proveedor GGUF")).font(.caption).foregroundStyle(OP.textSecondary)
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
                NavigationLink {
                    ProfileView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("Profile & Dream", "Perfil y sueño")).foregroundStyle(OP.textPrimary)
                        Text(T("Learns about you from your chats", "Aprende de ti desde tus chats")).font(.caption).foregroundStyle(OP.textSecondary)
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
                Button { exportBackup() } label: {
                    Label(T("Export backup", "Exportar respaldo"), systemImage: "square.and.arrow.up")
                }
                Button { showBackupImport = true } label: {
                    Label(T("Import backup", "Importar respaldo"), systemImage: "square.and.arrow.down")
                }
            } header: {
                Text(T("Backup", "Respaldo"))
            } footer: {
                Text(T("All chats and provider settings in one JSON file. API keys are never included (they stay in this device's Keychain). Temporary chats are excluded.", "Todos los chats y ajustes de proveedores en un archivo JSON. Las API keys nunca se incluyen (se quedan en el Keychain de este dispositivo). Los chats temporales se excluyen."))
            }

            Section {
                Button { showIntro = true } label: {
                    Label(T("View intro", "Ver introducción"), systemImage: "sparkles")
                }
            } header: {
                Text(T("About", "Acerca de"))
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
        .sheet(isPresented: $showIntro) { OnboardingView { showIntro = false } }
        .sheet(item: $backupShare) { payload in ShareSheet(items: payload.items) }
        .fileImporter(isPresented: $showBackupImport, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            handleBackupImport(result)
        }
        .alert(T("Backup failed", "Respaldo fallido"), isPresented: $showBackupError) {
            Button(T("OK", "Aceptar"), role: .cancel) {}
        } message: {
            Text(backupError ?? "")
        }
        .confirmationDialog(T("Restore backup", "Restaurar respaldo"), isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button(T("Add to existing chats", "Añadir a los chats existentes")) { restoreBackup(replace: false) }
            Button(T("Replace all chats", "Reemplazar todos los chats"), role: .destructive) { restoreBackup(replace: true) }
            Button(T("Cancel", "Cancelar"), role: .cancel) { pendingBackup = nil }
        } message: {
            Text(T("Replace deletes every current chat before restoring. Add keeps your chats and imports copies.", "Reemplazar borra todos los chats actuales antes de restaurar. Añadir conserva tus chats e importa copias."))
        }
        .alert(T("Restore complete", "Restauración completa"), isPresented: $showRestoreDone) {
            Button(T("OK", "Aceptar"), role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
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

    // MARK: - Respaldo completo

    private func exportBackup() {
        do {
            let bundle = Backup.bundle(conversations: conversations, providers: providers)
            let data = try Backup.jsonData(bundle)
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("openpilot-backup-\(df.string(from: Date())).json")
            try data.write(to: url, options: .atomic)
            backupShare = SharePayload(items: [url])
        } catch {
            backupError = error.localizedDescription
            showBackupError = true
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingBackup = try Backup.decode(data)
                showRestoreConfirm = true
            } catch {
                backupError = error.localizedDescription
                showBackupError = true
            }
        case .failure(let error):
            backupError = error.localizedDescription
            showBackupError = true
        }
    }

    private func restoreBackup(replace: Bool) {
        guard let bundle = pendingBackup else { return }
        let r = Backup.restore(bundle, into: context, replace: replace)
        pendingBackup = nil
        restoreMessage = T("\(r.conversations) chats · \(r.providers) new providers", "\(r.conversations) chats · \(r.providers) proveedores nuevos")
        showRestoreDone = true
    }
}