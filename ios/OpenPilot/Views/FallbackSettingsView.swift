import SwiftUI
import SwiftData

/// Activar fallback y elegir el orden de providers de respaldo.
struct FallbackSettingsView: View {
    @Query(sort: \ProviderConfig.createdAt) private var providers: [ProviderConfig]
    @AppStorage("fallbackEnabled") private var enabled = false
    @State private var ids: [String] = FallbackSettings.ids

    var body: some View {
        List {
            Section {
                Toggle(T("Enable fallback", "Activar fallback"), isOn: $enabled)
            } footer: {
                Text(T("If a provider fails with a transient error, automatically retry with the next one below.",
                       "Si un proveedor falla con un error transitorio, reintenta automáticamente con el siguiente."))
            }
            Section(T("Fallback order", "Orden de respaldo")) {
                if providers.isEmpty {
                    Text(T("No providers configured.", "No hay proveedores configurados."))
                        .foregroundStyle(OP.textSecondary)
                }
                ForEach(providers, id: \.id) { p in
                    Button { toggle(p.id) } label: {
                        HStack {
                            Text(p.name).foregroundStyle(OP.textPrimary)
                            Spacer()
                            if let idx = ids.firstIndex(of: p.id) {
                                Text("\(idx + 1)").font(.caption.monospacedDigit()).foregroundStyle(OP.accent)
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(OP.accent)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(T("Fallback", "Respaldo"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ id: String) {
        if let i = ids.firstIndex(of: id) { ids.remove(at: i) } else { ids.append(id) }
        FallbackSettings.ids = ids
        Haptic.light()
    }
}