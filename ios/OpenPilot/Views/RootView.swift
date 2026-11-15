import SwiftUI
import SwiftData

/// Shell: chat a pantalla completa + sidebar en drawer lateral.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var providers: [ProviderConfig]
    @State private var current: Conversation?
    @State private var sidebarOpen = false
    @State private var showSettings = false
    @AppStorage("appearanceMode") private var appearanceMode = "auto"

    var body: some View {
        ZStack(alignment: .leading) {
            ChatView(
                current: $current,
                onMenu: { withAnimation(.easeInOut(duration: 0.25)) { sidebarOpen = true } },
                onNewChat: { current = nil },
                onSettings: { showSettings = true }
            )

            if sidebarOpen {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { sidebarOpen = false } }
                SidebarView(
                    current: $current,
                    isOpen: $sidebarOpen,
                    onSettings: { sidebarOpen = false; showSettings = true }
                )
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .leading))
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .task { seedIfNeeded(); demoSidebarIfNeeded() }
    }

    /// Demo offline del sidebar con conversaciones fijadas y archivadas.
    private func demoSidebarIfNeeded() {
        guard CommandLine.arguments.contains("-demoSidebar") else { return }
        let samples: [(String, Bool, Bool)] = [
            ("Proyecto Open Pilot", true, false),
            ("Ideas de diseño", true, false),
            ("Consulta de clima", false, false),
            ("Recetas de cocina", false, false),
            ("Chat viejo archivado", false, true),
        ]
        for (title, pin, arch) in samples {
            let c = Conversation(title: title, providerID: "casa", model: "swift-iq3_s")
            c.isPinned = pin; c.isArchived = arch
            context.insert(c)
        }
        try? context.save()
        withAnimation(.easeInOut(duration: 0.25)) { sidebarOpen = true }
    }

    /// Auto = sigue al sistema; claro/oscuro = override explícito del usuario.
    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// Primer arranque: siembra el server de casa para que funcione out-of-the-box.
    private func seedIfNeeded() {
        guard providers.isEmpty else { return }
        let casa = ProviderConfig(
            id: "casa", name: "AI Server Casa", kind: "openai",
            baseURL: "http://192.168.1.190:8080/v1", models: ["swift-iq3_s"]
        )
        context.insert(casa)
        try? context.save()
    }
}