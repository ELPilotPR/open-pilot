import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ChatView: View {
    @Binding var current: Conversation?
    let onMenu: () -> Void
    let onNewChat: () -> Void
    let onSettings: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var providers: [ProviderConfig]
    @StateObject private var vm = ChatViewModel()
    @State private var input = ""
    @State private var browse = false
    @State private var imageMode = false
    @State private var atBottom = true
    @State private var attachedImage: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var imageSupport: [String: Bool] = [:]
    @State private var demoCI = false
    @State private var probingImage = false
    @ObservedObject private var voice = VoiceManager.shared
    @State private var dictationPrefix = ""
    @State private var editingMessage: Message?
    @State private var editText = ""
    @FocusState private var composerFocused: Bool
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @AppStorage("selectedModel") private var selectedModel = "swift-iq3_s"
    @AppStorage("imageModel") private var imageModel = "dall-e-3"

    private var activeProvider: ProviderConfig? {
        if let cid = current?.providerID, let p = providers.first(where: { $0.id == cid }) { return p }
        return providers.first(where: { $0.id == selectedProviderID }) ?? providers.first
    }
    private var activeModel: String { current?.model ?? selectedModel }
    private var messages: [Message] { current?.activeMessages ?? [] }
    private var imagesAvailable: Bool {
        guard let p = activeProvider else { return false }
        switch p.imageCapability {
        case "yes": return true
        case "no": return false
        default: return imageSupport[p.id] ?? p.resolvesImageSupport
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.12)
            if messages.isEmpty {
                greeting
            } else {
                messageList
            }
            if let status = vm.statusText {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(status).font(.caption).foregroundStyle(OP.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .transition(.opacity)
            }
            if let img = attachedImage, let ui = UIImage(data: img) {
                attachmentPreview(ui)
            }
            if imageMode && probingImage {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(T("Checking if this model generates images…", "Comprobando si este modelo genera imágenes…"))
                        .font(.caption).foregroundStyle(OP.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            if imageMode && !imagesAvailable && !probingImage {
                imageWarning
            }
            if let ve = voice.voiceError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(ve).font(.caption).foregroundStyle(OP.textSecondary)
                    Spacer(minLength: 0)
                    Button { voice.voiceError = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(OP.textTertiary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }
            if let err = vm.errorText {
                errorBanner(err)
            }
            composer
        }
        .background(OP.canvas.ignoresSafeArea())
        .onAppear { runDemoIfNeeded() }
        .animation(.easeInOut(duration: 0.2), value: vm.statusText == nil)
        .onChange(of: imageMode) { _, on in if on { probeIfNeeded() } }
        .onChange(of: activeProvider?.id) { _, _ in if imageMode { probeIfNeeded() } }
        .onChange(of: voice.liveTranscript) { _, t in input = dictationPrefix + t }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self),
                   let c = ImageUtils.compress(d) {
                    attachedImage = c
                    Haptic.light()
                }
                photoItem = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in
                if let c = ImageUtils.compress(data) { attachedImage = c; Haptic.light() }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $editingMessage) { m in
            editSheet(m)
        }
        .sheet(isPresented: $demoCI) {
            NavigationStack { CustomInstructionsView() }
        }
    }

    /// Hook de verificación visual (SOLO con argumento -demoWeather/-demoCurrency al
    /// lanzar). No afecta el uso normal: envía una consulta demo para ver la tarjeta.
    private func runDemoIfNeeded() {
        let args = CommandLine.arguments
        if args.contains("-demoCitations") { demoCitations(); return }
        if args.contains("-demoReasoning") { demoReasoning(); return }
        if args.contains("-demoMarkdown") { demoMarkdown(); return }
        if args.contains("-demoStream") { demoStream(); return }
        if args.contains("-demoEdit") { demoEdit(); return }
        if args.contains("-demoKeychain") { demoKeychain(); return }
        if args.contains("-demoError") { demoError(); return }
        if args.contains("-demoVersions") { demoVersions(startVersion: args.contains("-v1") ? 1 : 2); return }
        if args.contains("-demoCI") {
            CustomInstructions.aboutYou = "Soy Javier, desarrollador en Wisconsin. Trabajo en iOS y crypto."
            CustomInstructions.responsePrefs = "Responde siempre en español, directo y con tablas cuando haya datos."
            CustomInstructions.enabled = true
            demoCI = true
            return
        }
        let prompt: String?
        if args.contains("-demoWeather") { prompt = "¿Cómo está el tiempo en Racine WI?" }
        else if args.contains("-demoCurrency") { prompt = "cuánto es 100 dólares en euros" }
        else { prompt = nil }
        guard let prompt, activeProvider != nil else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            browse = false; imageMode = false; input = prompt
            send()
        }
    }

    /// Demo OFFLINE de versiones: un mensaje de usuario con 2 versiones (ramas
    /// hermanas) y sus respuestas; la activa es la 2. Verifica el selector < n/m >.
    private func demoVersions(startVersion: Int = 2) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo versiones", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            let u1 = Message(role: "user", text: "¿Cuál es la capital de Francia?")
            u1.createdAt = now.addingTimeInterval(-4); u1.version = 1; u1.parentID = nil
            let a1 = Message(role: "assistant", text: "La capital de Francia es **París**, su ciudad más poblada y centro político y cultural.")
            a1.createdAt = now.addingTimeInterval(-3); a1.parentID = u1.id; a1.version = 1
            a1.completionTokens = 24; a1.tokensPerSecond = 31
            u1.preferredChildID = a1.id
            let u2 = Message(role: "user", text: "¿Cuál es la capital de Francia? (sé breve)")
            u2.createdAt = now.addingTimeInterval(-2); u2.version = 2; u2.parentID = nil
            let a2 = Message(role: "assistant", text: "París.")
            a2.createdAt = now.addingTimeInterval(-1); a2.parentID = u2.id; a2.version = 1
            a2.completionTokens = 2; a2.tokensPerSecond = 40
            u2.preferredChildID = a2.id
            for m in [u1, a1, u2, a2] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a2.id
            if startVersion == 1 { conv.switchToVersion(u1) }   // ejercita el cambio de rama
            try? context.save()
        }
    }

    /// Demo OFFLINE de citas estructuradas: inyecta un mensaje con [n] + fuentes
    /// para verificar el render inline tapable sin red ni modelo.
    private func demoCitations() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo citas", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "¿Qué noticias hay hoy en EEUU?")
            u.createdAt = Date().addingTimeInterval(-2)
            let a = Message(role: "assistant", text: "Hoy se reportan **vuelos cancelados** en varios aeropuertos de EEUU [1]. Lo más relevante:\n\n- Tormentas en el sur afectan operaciones [2].\n- Revisa el estado de tu vuelo antes de salir [1].")
            let srcs = [
                WebSource(title: "CNN EEUU — última hora", url: "https://www.cnn.com/2026/11/14/us/vuelos", snippet: "Cancelaciones por tormenta."),
                WebSource(title: "BBC Mundo", url: "https://www.bbc.com/mundo/noticias", snippet: "Nueva Orleans bajo aviso."),
            ]
            a.sources = srcs
            a.citations = CitationReference.parse(text: a.text, sources: srcs)
            a.promptTokens = 320; a.completionTokens = 48; a.tokensPerSecond = 27.4
            context.insert(u); context.insert(a)
            conv.messages.append(u); conv.messages.append(a)
            try? context.save()
        }
    }

    /// Demo OFFLINE de razonamiento: inyecta reasoning + respuesta para verificar
    /// el bloque colapsable "Razonamiento" sin red ni modelo.
    private func demoReasoning() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo razonamiento", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "¿Cuánto es 17 × 23?")
            u.createdAt = Date().addingTimeInterval(-2)
            let a = Message(role: "assistant", text: "17 × 23 = **391**.")
            a.reasoning = "Descompongo 23 en 20 + 3. Primero 17 × 20 = 340. Luego 17 × 3 = 51. Sumo 340 + 51 = 391. Verifico por otra vía: 17 × 23 = 17 × (25 − 2) = 425 − 34 = 391. Coincide."
            a.promptTokens = 42; a.completionTokens = 96; a.tokensPerSecond = 31.2
            context.insert(u); context.insert(a)
            conv.messages.append(u); conv.messages.append(a)
            try? context.save()
        }
    }

    /// Demo OFFLINE de markdown enriquecido: encabezados, listas anidadas, blockquote,
    /// tabla, regla horizontal y codigo con resaltado de sintaxis. Sin red ni modelo.
    /// Abre el editor sobre un mensaje demo para verificar la UI de edición.
    private func demoEdit() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo edit", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "¿Cuál es la capital de Francia?")
            u.conversation = conv; conv.messages.append(u); context.insert(u)
            let a = Message(role: "assistant", text: "La capital de Francia es París.")
            a.conversation = conv; conv.messages.append(a); context.insert(a)
            try? context.save()
            try? await Task.sleep(nanoseconds: 400_000_000)
            startEdit(u)
        }
    }

    /// Verificación offline del Keychain: round-trip de escritura/lectura y
    /// migración del respaldo legacy. No toca providers reales; limpia al final.
    private func demoKeychain() {
        let c = Conversation(); context.insert(c); current = c
        var results: [String] = []
        let id = "kctest-" + UUID().uuidString.prefix(6).lowercased()
        let p = ProviderConfig(id: id, name: "KeychainTest", baseURL: "https://example.com", apiKey: "sk-test-12345")
        context.insert(p)
        results.append(p.apiKey == "sk-test-12345" ? "✅ write → Keychain → read OK" : "❌ round-trip FAIL")
        results.append(p.apiKeyLegacy.isEmpty ? "✅ sin texto plano (legacy vacío)" : "❌ legacy aún guarda la key")
        let id2 = id + "-legacy"
        let p2 = ProviderConfig(id: id2, name: "LegacyTest", baseURL: "https://example.com", apiKey: "")
        context.insert(p2)
        p2.apiKeyLegacy = "sk-legacy-999"
        KeychainStore.delete(id2)
        ProviderConfig.migrateKeysToKeychain(in: context)
        results.append(p2.apiKey == "sk-legacy-999" && p2.apiKeyLegacy.isEmpty ? "✅ migración legacy → Keychain OK" : "❌ migración FAIL")
        KeychainStore.delete(id); KeychainStore.delete(id2)
        context.delete(p); context.delete(p2)
        let u = Message(role: "user", text: "Test de Keychain"); u.conversation = c; context.insert(u)
        let a = Message(role: "assistant", text: results.joined(separator: "\n")); a.conversation = c; context.insert(a)
        c.title = "Keychain"; try? context.save()
    }

    /// Simula streaming offline para verificar el cursor ▍ y el ocultado de acciones.
    private func demoStream() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo stream", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "Describe el mar al amanecer")
            u.conversation = conv; conv.messages.append(u); context.insert(u)
            let a = Message(role: "assistant", text: "")
            a.conversation = conv; conv.messages.append(a); context.insert(a)
            try? context.save()
            vm.isStreaming = true
            let full = "El mar en calma al amanecer tiene un color azul profundo que se va tiñendo de oro a medida que el sol asoma sobre el horizonte. Las olas llegan suaves a la orilla, dejando una estela de espuma que brilla un instante antes de deshacerse sobre la arena."
            var acc = ""
            for word in full.split(separator: " ") {
                acc += (acc.isEmpty ? "" : " ") + word
                a.text = acc
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
            vm.isStreaming = false
            try? context.save()
        }
    }

    private func demoMarkdown() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo markdown", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "Muéstrame un ejemplo con formato completo")
            u.createdAt = Date().addingTimeInterval(-2)
            let md = [
                "# Guía rápida",
                "",
                "Párrafo con **negrita**, *cursiva*, `código inline` y un [enlace](https://example.com). También una cita [1].",
                "",
                "## Listas anidadas",
                "- Frutas",
                "  - Manzana",
                "  - Pera",
                "- Verduras",
                "  1. Zanahoria",
                "  2. Guisantes",
                "",
                "> Una cita en bloque para resaltar una idea importante.",
                "",
                "| Lenguaje | Tipado | Año |",
                "|---|---|---|",
                "| Swift | Estático | 2014 |",
                "| Python | Dinámico | 1991 |",
                "",
                "---",
                "",
                "```swift",
                "// Comentario de ejemplo",
                "func saludo(_ nombre: String) -> String {",
                "    let mensaje = \"Hola, \" + nombre",
                "    return mensaje",
                "}",
                "```",
            ].joined(separator: "\n")
            let a = Message(role: "assistant", text: md)
            let srcs = [WebSource(title: "Documento de ejemplo", url: "https://example.com/doc", snippet: "Fuente de demostración.")]
            a.sources = srcs
            a.citations = CitationReference.parse(text: a.text, sources: srcs)
            a.promptTokens = 120; a.completionTokens = 210; a.tokensPerSecond = 29.8
            context.insert(u); context.insert(a)
            conv.messages.append(u); conv.messages.append(a)
            try? context.save()
        }
    }

    /// Demo OFFLINE del banner de error + reintento (sin red).
    private func demoError() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            let conv: Conversation
            if let c = current { conv = c }
            else {
                let c = Conversation(title: "Demo error", providerID: activeProvider?.id ?? "casa", model: activeModel)
                context.insert(c); current = c; conv = c
            }
            let u = Message(role: "user", text: "¿Cuál es la capital de Francia?")
            context.insert(u); conv.messages.append(u)
            try? context.save()
            vm.errorText = "The request timed out. (NSURLErrorDomain -1001)"
        }
    }

    private func attachmentPreview(_ ui: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(T("Attached image", "Imagen adjunta")).font(.caption).foregroundStyle(OP.textSecondary)
            Spacer()
            Button { attachedImage = nil; Haptic.light() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(OP.textTertiary)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 6)
    }

    private var imageWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(T("This model does not support image generation. Switch to Qwen (above) or enable it in the provider settings.", "Este modelo no soporta generación de imágenes. Cambia a Qwen (arriba) o actívalo en Ajustes del proveedor."))
                .font(.caption).foregroundStyle(OP.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
        .transition(.opacity)
    }

    /// Banner de error de red/modelo con reintento (sustituye al viejo "⚠️" crudo).
    private func errorBanner(_ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(T("Something went wrong", "Algo salió mal"))
                    .font(.caption.weight(.semibold)).foregroundStyle(OP.textPrimary)
                Text(detail).font(.caption2).foregroundStyle(OP.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Button { vm.errorText = nil; regenerate(); Haptic.light() } label: {
                Text(T("Retry", "Reintentar")).font(.caption.weight(.semibold)).foregroundStyle(OP.accent)
            }
            .buttonStyle(ScaleButtonStyle())
            Button { vm.errorText = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(OP.textTertiary)
            }
            .accessibilityLabel(T("Dismiss", "Descartar"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.red.opacity(0.10))
        .transition(.opacity)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            modelMenu
            HStack {
                Button(action: { onMenu(); Haptic.light() }) {
                    Image(systemName: "line.3.horizontal").font(.system(size: 18, weight: .medium))
                        .accessibilityLabel(T("Menu", "Menú"))
                }
                .buttonStyle(ScaleButtonStyle())
                Spacer()
                Button(action: { onNewChat(); Haptic.light() }) {
                    Image(systemName: "square.and.pencil").font(.system(size: 18, weight: .medium))
                        .accessibilityLabel(T("New chat", "Nueva conversación"))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .foregroundStyle(OP.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var modelMenu: some View {
        Menu {
            ForEach(providers) { p in
                Menu(p.name) {
                    ForEach(p.models, id: \.self) { m in
                        Button(m) { select(p, m); Haptic.selection() }
                    }
                }
            }
            Divider()
            Button(T("Model settings…", "Ajustes de modelos…"), action: onSettings)
        } label: {
            HStack(spacing: 4) {
                Text(activeModel).font(.headline).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(OP.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }

    private func select(_ p: ProviderConfig, _ m: String) {
        selectedProviderID = p.id
        selectedModel = m
        current?.providerID = p.id
        current?.model = m
        try? context.save()
    }

    // MARK: - Estado vacio

    private var greeting: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("Logo")
                .resizable().scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .padding(.bottom, 16)
            Text(T("How can I help you?", "¿En qué puedo ayudarte?"))
                .font(.title2.weight(.semibold)).foregroundStyle(OP.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { composerFocused = false }
    }

    // MARK: - Mensajes

    private var messageList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { idx, m in
                            let sibs = current?.siblings(of: m) ?? [m]
                            MessageRow(message: m, isActive: vm.isStreaming && idx == messages.count - 1,
                                       onRegenerate: (!vm.isStreaming && m.role == "assistant" && idx == messages.count - 1) ? { regenerate() } : nil,
                                       onEdit: (!vm.isStreaming && m.role == "user") ? { startEdit(m) } : nil,
                                       versionCurrent: sibs.count > 1 ? m.version : 0,
                                       versionTotal: sibs.count > 1 ? sibs.count : 0,
                                       onSwitchVersion: { target in switchVersion(m, to: target) })
                                .id(m.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                            .onScrollVisibilityChange(threshold: 0.5) { visible in atBottom = visible }
                    }
                    .padding(.horizontal, 16).padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { composerFocused = false })
                .onChange(of: messages.last?.text) { _, _ in if atBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: messages.last?.reasoning) { _, _ in if atBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: messages.count) { _, _ in
                    atBottom = true
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }

                if !atBottom {
                    ScrollToBottomButton {
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .padding(.trailing, 16).padding(.bottom, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: atBottom)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Menu {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(T("Choose photo", "Elegir foto"), systemImage: "photo.on.rectangle")
                }
                Button { showCamera = true } label: { Label(T("Camera", "Cámara"), systemImage: "camera") }
            } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(OP.textPrimary)
                    .frame(width: 34, height: 34)
                    .accessibilityLabel(T("Attach", "Adjuntar"))
            }
            if !imageMode {
                Button { browse.toggle(); Haptic.selection() } label: {
                    Image(systemName: "globe").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(browse ? OP.accent : OP.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(browse ? OP.accent.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                        .animation(.easeInOut(duration: 0.2), value: browse)
                        .accessibilityLabel(T("Search the web", "Buscar en la web"))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            Button { imageMode.toggle(); Haptic.selection() } label: {
                Image(systemName: "wand.and.stars").font(.system(size: 17, weight: .medium))
                    .foregroundStyle(imageMode ? OP.accent : OP.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(imageMode ? OP.accent.opacity(0.15) : Color.clear)
                    .clipShape(Circle())
                    .animation(.easeInOut(duration: 0.2), value: imageMode)
                    .accessibilityLabel(T("Generate image", "Generar imagen"))
            }
            .buttonStyle(ScaleButtonStyle())
            if !imageMode {
                Button {
                    if voice.isListening {
                        voice.stopDictation()
                    } else {
                        dictationPrefix = input.isEmpty ? "" : input + " "
                        voice.toggleDictation()
                    }
                    Haptic.selection()
                } label: {
                    Image(systemName: voice.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(voice.isListening ? Color.red : OP.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(voice.isListening ? Color.red.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                        .symbolEffect(.pulse, options: .repeating, isActive: voice.isListening)
                        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
                        .accessibilityLabel(T("Dictate", "Dictar"))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            TextField(imageMode ? T("Describe the image…", "Describe la imagen…") : T("Ask anything", "Pregunta algo"),
                      text: $input, axis: .vertical)
                .lineLimit(1...6)
                .focused($composerFocused)
                .tint(OP.accent)
                .foregroundStyle(OP.textPrimary)
                .padding(.vertical, 7)
            if vm.isStreaming {
                Button { vm.stop(); Haptic.light() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 30)).foregroundStyle(OP.textPrimary)
                        .accessibilityLabel(T("Stop", "Detener"))
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? OP.sendFg : OP.canvas)
                        .frame(width: 32, height: 32)
                        .background(canSend ? OP.sendBg : OP.textTertiary)
                        .clipShape(Circle())
                        .animation(.easeInOut(duration: 0.2), value: canSend)
                        .accessibilityLabel(T("Send", "Enviar"))
                }
                .disabled(!canSend)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(OP.border, lineWidth: 1))
        .padding(.horizontal, 12).padding(.bottom, 8).padding(.top, 4)
    }

    private var canSend: Bool {
        let hasContent = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
        return hasContent && activeProvider != nil
    }

    private func probeIfNeeded() {
        guard let p = activeProvider, p.imageCapability == "auto",
              imageSupport[p.id] == nil, !probingImage else { return }
        probingImage = true
        let base = p.baseURL, key = p.apiKey, pid = p.id
        Task { @MainActor in
            let ok = await ImageGenerationService.probeImageSupport(baseURL: base, apiKey: key)
            imageSupport[pid] = ok
            probingImage = false
        }
    }

    private func regenerate() {
        guard let p = activeProvider, let c = current else { return }
        vm.regenerate(conversation: c, provider: p, context: context)
    }

    /// Navega a otra versión (rama hermana) del mensaje, sin perder las demás.
    private func switchVersion(_ m: Message, to targetVersion: Int) {
        guard let c = current else { return }
        let sibs = c.siblings(of: m)
        guard let target = sibs.first(where: { $0.version == targetVersion }) else { return }
        c.switchToVersion(target)
        try? context.save()
        Haptic.selection()
    }

    // MARK: - Editar mensaje del usuario

    private func startEdit(_ m: Message) {
        editText = m.text
        editingMessage = m
        Haptic.light()
    }

    @ViewBuilder
    private func editSheet(_ m: Message) -> some View {
        NavigationStack {
            TextEditor(text: $editText)
                .font(.body)
                .foregroundStyle(OP.textPrimary)
                .scrollContentBackground(.hidden)
                .background(OP.canvas)
                .padding(12)
                .navigationTitle(T("Edit message", "Editar mensaje"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(T("Cancel", "Cancelar")) { editingMessage = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(T("Submit", "Enviar")) { submitEdit(m) }
                            .fontWeight(.semibold)
                            .tint(OP.accent)
                            .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private func submitEdit(_ m: Message) {
        guard let p = activeProvider, let c = current else { editingMessage = nil; return }
        let text = editText
        editingMessage = nil
        vm.editAndResend(m, newText: text, conversation: c, provider: p, context: context)
    }

    private func send() {
        guard let p = activeProvider else { return }
        if imageMode && !imagesAvailable {
            Haptic.warning()
            return   // la advertencia ya esta visible sobre el composer
        }
        voice.stopDictation()
        voice.stopSpeaking()
        Haptic.medium()
        let text = input
        let img = attachedImage
        input = ""
        attachedImage = nil
        composerFocused = false
        let c: Conversation
        if let cur = current { c = cur } else {
            c = Conversation(providerID: p.id, model: activeModel)
            context.insert(c); try? context.save()
        }
        current = c
        if imageMode {
            vm.generateImage(prompt: text, conversation: c, provider: p, context: context, imageModel: imageModel)
        } else {
            vm.send(text, conversation: c, provider: p, context: context, browse: browse, image: img)
        }
    }
}
