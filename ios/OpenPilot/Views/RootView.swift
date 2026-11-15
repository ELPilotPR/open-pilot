import SwiftUI
import SwiftData

/// Shell: chat a pantalla completa + sidebar en drawer lateral.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var providers: [ProviderConfig]
    @State private var current: Conversation?
    @AppStorage("accentColor") private var accentColor = "blue"
    @State private var sidebarOpen = false
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings = false
    @State private var demoProvider: ProviderConfig?
    @State private var demoMemory = false
    @State private var demoUsage = false
    @AppStorage("appearanceMode") private var appearanceMode = "auto"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if hSize == .regular {
                // iPad / Mac: sidebar persistente + chat en columna de detalle.
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(current: $current, isOpen: .constant(true),
                                onSettings: { showSettings = true })
                        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
                } detail: {
                    ChatView(
                        current: $current,
                        onMenu: { withAnimation { columnVisibility = columnVisibility == .all ? .detailOnly : .all } },
                        onNewChat: { current = nil },
                        onSettings: { showSettings = true }
                    )
                }
            } else {
                compactBody
            }
        }
        .id(accentColor)
        .userActivity(HandoffSupport.activityType, isActive: current != nil) { activity in HandoffSupport.configure(activity, for: current) }
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
        .sheet(isPresented: $demoUsage) {
            NavigationStack { UsageDashboardView() }
        }
        .task { purgeTemporary(); seedIfNeeded(); demoSidebarIfNeeded(); demoModelsIfNeeded(); demoProjectsIfNeeded(); demoMemoryIfNeeded(); demoShareIfNeeded(); demoOnDeviceIfNeeded(); demoUsageIfNeeded(); consumePendingShare(); consumeIntentFlags(); consumeSpotlight(); consumeHandoff(); WidgetBridge.refresh(context: context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingShare(); consumeIntentFlags(); consumeSpotlight(); consumeHandoff(); WidgetBridge.refresh(context: context) }
            if phase == .background { indexSpotlightIfNeeded(); WidgetBridge.refresh(context: context) }
        }
        .onChange(of: current?.id) { oldID, newID in
            guard let oldID, oldID != newID else { return }
            let desc = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == oldID })
            if let old = (try? context.fetch(desc))?.first, old.isTemporary {
                context.delete(old); try? context.save()
            }
        }
    }

    /// iPhone: chat a pantalla completa + sidebar en drawer lateral.
    private var compactBody: some View {
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
    }

    /// Los chats temporales no persisten: se borran al salir de ellos y al arrancar.
    private func purgeTemporary() {
        let desc = FetchDescriptor<Conversation>(predicate: #Predicate { $0.isTemporary })
        if let temps = try? context.fetch(desc) {
            for t in temps { context.delete(t) }
            try? context.save()
        }
    }

    /// Consume lo recibido por la Share Extension: crea una conversación con el
    /// contenido compartido como primer mensaje del usuario.
    private func consumePendingShare() {
        guard let item = ShareInbox.take() else { return }
        let p = providers.first
        let c = Conversation(title: ShareInbox.title(for: item),
                             providerID: p?.id ?? "casa", model: p?.models.first ?? "swift-iq3_s")
        let m = Message(role: "user", text: ShareInbox.messageText(for: item))
        if item.kind == .image { m.imageData = item.imageData }
        m.conversation = c
        c.messages.append(m)
        c.ensureTree()
        context.insert(c)
        try? context.save()
        current = c
    }

    /// Demo offline: siembra un share en el App Group y lo consume (sin extensión real).
    /// Consume las intents de Siri/Shortcuts que abren la app (chat nuevo).
    private func consumeIntentFlags() {
        let d = UserDefaults.standard
        if d.bool(forKey: IntentSupport.newChatFlag) {
            d.removeObject(forKey: IntentSupport.newChatFlag)
            current = nil
        }
    }

    /// Abre la conversación seleccionada desde un resultado de Spotlight.
    private func consumeSpotlight() {
        guard let id = SpotlightSupport.pendingID else { return }
        SpotlightSupport.pendingID = nil
        let desc = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        if let c = (try? context.fetch(desc))?.first { current = c }
    }

    /// Reindexa en Spotlight al pasar a segundo plano (si está activado).
    private func indexSpotlightIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "spotlightEnabled") else { return }
        let all = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        SpotlightSupport.index(all.filter { !$0.isTemporary })
    }

    /// Recibe un chat por Handoff desde otro dispositivo y lo crea localmente.
    private func consumeHandoff() {
        guard let p = HandoffSupport.pending else { return }
        HandoffSupport.pending = nil
        let prov = providers.first
        let c = Conversation(title: p.title.isEmpty ? T("Handoff chat", "Chat recibido") : p.title,
                             providerID: prov?.id ?? "casa", model: prov?.models.first ?? "swift-iq3_s")
        for hm in p.messages {
            let m = Message(role: hm.role, text: hm.text); m.conversation = c; c.messages.append(m)
        }
        c.ensureTree(); context.insert(c); try? context.save(); current = c
    }

    /// Demo offline: abre el editor del proveedor on-device con su estado real.
    private func demoOnDeviceIfNeeded() {
        guard CommandLine.arguments.contains("-demoOnDevice") else { return }
        demoProvider = ProviderConfig(id: "demo-ondevice", name: "On-device", kind: "ondevice",
                                      baseURL: "", models: ["apple-intelligence"])
    }

    private func demoShareIfNeeded() {
        guard CommandLine.arguments.contains("-demoShare") else { return }
        let item = SharedItem(kind: .url, text: "Artículo sobre energía solar",
                              url: "https://example.org/solar", imageData: Data(),
                              note: "Resume esto y dime si es fiable", date: Date())
        ShareInbox.put(item)
        consumePendingShare()
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

    /// Demo offline del dashboard de uso: siembra respuestas con tokens y lo abre.
    private func demoUsageIfNeeded() {
        guard CommandLine.arguments.contains("-demoUsage") else { return }
        let cloud = ProviderConfig(id: "demo-openai", name: "OpenAI", kind: "openai",
                                   baseURL: "https://api.openai.com/v1", models: ["gpt-4o", "gpt-4o-mini"])
        let local = ProviderConfig(id: "demo-ollama", name: "Ollama (LAN)", kind: "openai",
                                   baseURL: "http://192.168.1.50:11434/v1", models: ["llama3"])
        context.insert(cloud); context.insert(local)
        func chat(_ prov: String, _ model: String, _ title: String, days: [(Int, Int, Int)]) {
            let c = Conversation(title: title, providerID: prov, model: model)
            for (offset, pr, comp) in days {
                let m = Message(role: "assistant", text: "Respuesta de ejemplo")
                m.promptTokens = pr; m.completionTokens = comp
                m.createdAt = Date().addingTimeInterval(-86400 * Double(offset))
                m.conversation = c; c.messages.append(m)
            }
            c.ensureTree(); context.insert(c)
        }
        chat("demo-openai", "gpt-4o", "Investigación", days: [(0, 4200, 1800), (1, 3100, 900), (3, 5200, 2400), (6, 1500, 600)])
        chat("demo-openai", "gpt-4o-mini", "Notas rápidas", days: [(0, 800, 300), (2, 1200, 450), (5, 600, 200)])
        chat("demo-ollama", "llama3", "Local privado", days: [(0, 3000, 1500), (4, 2200, 1100)])
        try? context.save()
        demoUsage = true
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