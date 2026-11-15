import SwiftUI
import SwiftData

/// Perfil aprendido + "modo sueño": el modelo revisa tus chats en segundo plano
/// y construye un perfil de ti (quién eres, gustos, proyectos, estilo) que se
/// inyecta en cada respuesta. Local, sin backend; usa tu provider configurado.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var providers: [ProviderConfig]
    @State private var profile = ProfileStore.profile
    @State private var dreamEnabled = ProfileStore.dreamEnabled
    @State private var threshold = ProfileStore.threshold
    @State private var isDreaming = false
    @State private var status = ""

    var body: some View {
        List {
            Section {
                Toggle(T("Dream mode", "Modo sueño"), isOn: $dreamEnabled)
                Stepper(value: $threshold, in: 5...100, step: 5) {
                    Text(T("Every \(threshold) messages", "Cada \(threshold) mensajes"))
                }
            } footer: {
                Text(T("While you're away, the model reviews your recent chats and builds a learned profile of you — likes, projects, style — to personalize every answer. Stored only on this iPhone.",
                       "Mientras no estás, el modelo revisa tus chats recientes y construye un perfil aprendido de ti — gustos, proyectos, estilo — para personalizar cada respuesta. Se guarda solo en este iPhone."))
            }

            Section {
                Button { dreamNow() } label: {
                    HStack {
                        Label(T("Dream now", "Soñar ahora"), systemImage: "moon.zzz")
                        Spacer()
                        if isDreaming { ProgressView() }
                    }
                }
                .disabled(isDreaming || providers.isEmpty)
                if let d = ProfileStore.lastDream {
                    Text(T("Last dream: ", "Último sueño: ") + d.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(OP.textSecondary)
                }
                if !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(OP.textSecondary)
                }
            } header: { Text(T("Dream", "Sueño")) }

            Section {
                if profile.isEmpty {
                    Text(T("No profile yet. Tap \"Dream now\" to build one from your chats.",
                           "Aún no hay perfil. Toca \"Soñar ahora\" para construirlo desde tus chats."))
                        .foregroundStyle(OP.textTertiary)
                } else {
                    ForEach(profile.sections, id: \.title) { sec in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sec.title).font(.subheadline.bold()).foregroundStyle(OP.textPrimary)
                            ForEach(sec.items, id: \.self) { item in
                                Text("• \(item)").font(.callout).foregroundStyle(OP.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: { Text(T("Learned profile", "Perfil aprendido")) }

            if !profile.isEmpty {
                Section {
                    Button(role: .destructive) { ProfileStore.clear(); profile = .empty; status = "" } label: {
                        Label(T("Clear profile", "Borrar perfil"), systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(T("Profile & Dream", "Perfil y sueño"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(T("Done", "Listo")) { dismiss() } }
        }
        .onChange(of: dreamEnabled) { _, v in ProfileStore.dreamEnabled = v }
        .onChange(of: threshold) { _, v in ProfileStore.threshold = v }
        .onAppear {
            profile = ProfileStore.profile
            dreamEnabled = ProfileStore.dreamEnabled
            threshold = ProfileStore.threshold
        }
    }

    private func dreamNow() {
        guard let p = providers.first else {
            status = T("Add a provider first.", "Añade un provider primero.")
            return
        }
        let model = p.models.first ?? ""
        guard !model.isEmpty else {
            status = T("Configure a model for this provider.", "Configura un modelo para este provider.")
            return
        }
        isDreaming = true
        status = T("Dreaming…", "Soñando…")
        Task { @MainActor in
            let r = await DreamEngine.dream(provider: p, model: model, context: context)
            isDreaming = false
            profile = ProfileStore.profile
            status = r.ok ? "\(r.message) (\(r.items))" : r.message
        }
    }
}