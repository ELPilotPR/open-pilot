import SwiftUI
import SwiftData

/// Shell: chat a pantalla completa + sidebar en drawer lateral.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var providers: [ProviderConfig]
    @State private var current: Conversation?
    @State private var sidebarOpen = false
    @State private var showSettings = false
    @State private var demoProvider: ProviderConfig?
    @State private var demoMemory = false
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
        .sheet(item: $demoProvider) { p in
            NavigationStack { ProviderEditorView(provider: p) }
        }
        .sheet(isPresented: $demoMemory) {
            NavigationStack { MemoryView() }
        }
        .task { purgeTemporary(); seedIfNeeded(); demoSidebarIfNeeded(); demoModelsIfNeeded(); demoProjectsIfNeeded(); demoMemoryIfNeeded() }
        .onChange(of: current?.id) { oldID, newID in
            guard let oldID, oldID != newID else { return }
            let desc = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == oldID })
            if let old = (try? context.fetch(desc))?.first, old.isTemporary {
                context.delete(old); try? context.save()
            }
        }
    }

    /// Los chats temporales no persisten: se borran al salir de ellos y al arrancar.
    private func purgeTemporary() {
        let desc = FetchDescriptor<Conversation>(predicate: #Predicate { $0.isTemporary })
        if let temps = try? context.fetch(desc) {
            for t in temps { context.delete(t) }
            try? context.save()
        }
    }

    /// Demo offline del editor de modelos con presets y capacidades (Qwen).
    private func demoModelsIfNeeded() {
        guard CommandLine.arguments.contains("-demoModels") else { return }
        let p = ProviderConfig(id: "demo-qwen", name: "Qwen Cloud", kind: "openai",
                               baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", apiKey: "")
        p.models = ["qwen-max", "qwen-vl-max", "qwq-plus"]
        context.insert(p)
        try? context.save()
        demoProvider = p
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

    /// Demo offline de proyectos: siembra dos proyectos con chats y abre el sidebar.
    private func demoProjectsIfNeeded() {
        guard CommandLine.arguments.contains("-demoProjects") else { return }
        let p1 = Project(name: "Trabajo", instructions: "Responde en tono profesional y conciso.", symbol: "briefcase")
        let p2 = Project(name: "Personal", instructions: "Tono cercano y casual.", symbol: "heart")
        context.insert(p1); context.insert(p2)
        let c1 = Conversation(title: "Informe trimestral", providerID: "casa", model: "swift-iq3_s")
        c1.projectID = p1.id; c1.isPinned = true
        let c2 = Conversation(title: "Ideas de viaje", providerID: "casa", model: "swift-iq3_s")
        c2.projectID = p2.id
        let c3 = Conversation(title: "Chat sin proyecto", providerID: "casa", model: "swift-iq3_s")
        context.insert(c1); context.insert(c2); context.insert(c3)
        try? context.save()
        withAnimation(.easeInOut(duration: 0.25)) { sidebarOpen = true }
    }

    /// Demo offline de la memoria: siembra hechos y abre la vista de Memoria.
    private func demoMemoryIfNeeded() {
        guard CommandLine.arguments.contains("-demoMemory") else { return }
        MemoryStore.enabled = true
        MemoryStore.clear()
        MemoryStore.add(["Vive en Wisconsin", "Prefiere respuestas en español", "Trabaja en una app iOS llamada Open Pilot"])
        demoMemory = true
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