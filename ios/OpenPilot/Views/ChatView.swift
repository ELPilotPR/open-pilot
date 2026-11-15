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
    @Environment(\.scenePhase) private var scenePhase
    @Query private var providers: [ProviderConfig]
    @StateObject private var vm = ChatViewModel()
    @State private var input = ""
    @State private var pendingXSuccess: String?
    @State private var pendingXError: String?
    @State private var library = PromptLibrary.shared
    @State private var showPromptLibrary = false
    @State private var browse = false
    @State private var imageMode = false
    @State private var atBottom = true
    @State private var attachedImage: Data?
    @State private var attachedFile: FileAttachment.Parsed?
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var imageSupport: [String: Bool] = [:]
    @State private var demoCI = false
    @State private var canvasDoc: CanvasDocument?
    @State private var probingImage = false
    @ObservedObject private var voice = VoiceManager.shared
    @StateObject private var live = LiveVoiceController()
    @State private var dictationPrefix = ""
    @State private var editingMessage: Message?
    @State private var editText = ""
    @State private var showSearch = false
    @State private var searchInChat = ""
    @State private var showCompare = false
    @StateObject private var compare = ModelCompare(columns: [])
    @StateObject private var research = DeepResearch()
    @State private var showResearch = false
    @State private var showVoicePicker = false
    @State private var showSummary = false
    @State private var showTranslate = false
    @State private var showAutoTag = false
    @State private var showRAG = false
    @State private var showVoiceNote = false
    @State private var editImageSource: Data? = nil
    @State private var editImagePrompt = ""
    @State private var showEditImagePrompt = false
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
    /// Mensajes visibles: si la búsqueda está activa, solo los que coinciden.
    private var displayedMessages: [Message] {
        guard showSearch else { return messages }
        return Self.filterMessages(messages, query: searchInChat)
    }
    /// Filtro de búsqueda en la conversación (insensible a mayúsculas). Testeable.
    static func filterMessages(_ messages: [Message], query: String) -> [Message] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return messages }
        return messages.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }
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
            if current?.isTemporary == true {
                temporaryBanner
            }
            if showSearch {
                searchBar
            }
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
            if let f = attachedFile {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill").font(.system(size: 16)).foregroundStyle(OP.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.name).font(.caption.weight(.medium)).foregroundStyle(OP.textPrimary).lineLimit(1)
                        Text(T("Attached file", "Archivo adjunto")).font(.caption2).foregroundStyle(OP.textSecondary)
                    }
                    Spacer()
                    Button { attachedFile = nil; Haptic.light() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(OP.textTertiary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(OP.elevated).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(OP.border, lineWidth: 1))
                .padding(.horizontal, 16).padding(.vertical, 4)
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
        .onAppear { runDemoIfNeeded(); consumeVoiceIntent(); consumeAskDeepLink() }
        .onChange(of: scenePhase) { _, p in if p == .active { consumeVoiceIntent(); consumeAskDeepLink() } }
        .onChange(of: vm.isStreaming) { old, new in if old && !new { fireDeepLinkCallback() } }
        .sheet(isPresented: $showPromptLibrary) { NavigationStack { PromptLibraryView() } }
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
        .fileImporter(isPresented: $showFilePicker,
                      allowedContentTypes: FileAttachment.allowedTypes,
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first,
               let parsed = FileAttachment.parse(url: url) {
                attachedFile = parsed
                Haptic.light()
            }
        }
        .sheet(item: $editingMessage) { m in
            editSheet(m)
        }
        .sheet(item: $canvasDoc) { doc in
            CanvasView(doc: doc, provider: activeProvider, model: activeModel)
        }
        .sheet(isPresented: $showCompare) {
            CompareView(compare: compare, providers: providers)
        }
        .sheet(isPresented: $showResearch) {
            DeepResearchView(research: research, provider: activeProvider, model: activeModel)
        }
        .sheet(isPresented: $showVoicePicker) { VoicePickerView() }
        .sheet(isPresented: $showSummary) { SummaryView(conversation: current) }
        .sheet(isPresented: $showTranslate) { TranslateView(initialText: messages.last(where: { $0.role == "assistant" })?.text ?? "") }
        .sheet(isPresented: $showAutoTag) { AutoTagView(conversation: current) }
        .sheet(isPresented: $showRAG) { AttachmentQAView(conversation: current) }
        .sheet(isPresented: $showVoiceNote) { VoiceNoteView { text in input = text } }
        .alert(T("Edit image", "Editar imagen"), isPresented: $showEditImagePrompt) {
            TextField(T("Describe the change…", "Describe el cambio…"), text: $editImagePrompt)
            Button(T("Cancel", "Cancelar"), role: .cancel) { editImageSource = nil }
            Button(T("Edit", "Editar")) {
                if let p = activeProvider, let c = current, let src = editImageSource {
                    vm.editImage(prompt: editImagePrompt, source: src, conversation: c, provider: p, context: context, imageModel: imageModel)
                }
                editImageSource = nil
            }
        } message: {
            Text(T("The model will redraw the image following your instruction.", "El modelo redibujará la imagen siguiendo tu instrucción."))
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCanvas)) { note in
            let lang = note.userInfo?["lang"] as? String ?? ""
            let code = note.userInfo?["code"] as? String ?? ""
            openCanvas(lang: lang, code: code)
        }
        .onAppear {
            live.sendUtterance = { text in
                self.input = text
                self.imageMode = false
                self.send()
            }
        }
        .onChange(of: vm.isStreaming) { _, streaming in
            if !streaming && live.isActive && live.phase == .thinking {
                let txt = messages.last(where: { $0.role == "assistant" })?.text ?? ""
                live.assistantDidFinish(txt)
            }
        }
        .overlay { if live.isActive { liveOverlay } }
        .sheet(isPresented: $demoCI) {
            NavigationStack { CustomInstructionsView() }
        }
    }

    /// Hook de verificación visual (SOLO con argumento -demoWeather/-demoCurrency al
    /// lanzar). No afecta el uso normal: envía una consulta demo para ver la tarjeta.
    /// Consume la intent de voz (Siri/Shortcuts): arranca el modo voz en vivo.
    private func consumeVoiceIntent() {
        let d = UserDefaults.standard
        guard d.bool(forKey: IntentSupport.voiceFlag) else { return }
        d.removeObject(forKey: IntentSupport.voiceFlag)
        if !live.isActive { live.start() }
    }

    /// Deep link openpilot://ask?text=…: abre un chat nuevo y envía la pregunta.
    private func consumeAskDeepLink() {
        let d = UserDefaults.standard
        guard let text = d.string(forKey: DeepLinkSupport.askTextFlag), !text.isEmpty else { return }
        d.removeObject(forKey: DeepLinkSupport.askTextFlag)
        pendingXSuccess = d.string(forKey: DeepLinkSupport.xSuccessKey)
        pendingXError = d.string(forKey: DeepLinkSupport.xErrorKey)
        d.removeObject(forKey: DeepLinkSupport.xSuccessKey)
        d.removeObject(forKey: DeepLinkSupport.xErrorKey)
        current = nil
        input = text
        send()
    }

    /// x-callback-url: al terminar el streaming devuelve la respuesta (o el error)
    /// a la app que abrió el deep link.
    private func fireDeepLinkCallback() {
        if let err = vm.errorText, !err.isEmpty, let base = pendingXError {
            if let url = URLRouter.callback(base, param: "error", value: err) { UIApplication.shared.open(url) }
            pendingXSuccess = nil; pendingXError = nil
            return
        }
        if let base = pendingXSuccess {
            let reply = messages.last(where: { $0.role == "assistant" })?.text ?? ""
            if let url = URLRouter.callback(base, param: "text", value: reply) { UIApplication.shared.open(url) }
            pendingXSuccess = nil; pendingXError = nil
        }
    }

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
        if args.contains("-demoFile") { demoFile(); return }
        if args.contains("-demoCanvas") { demoCanvas(); return }
        if args.contains("-demoLive") { demoLive(); return }
        if args.contains("-demoTemporary") { demoTemporary(); return }
        if args.contains("-demoSearch") { demoSearch(); return }
        if args.contains("-demoMath") { demoMath(); return }
        if args.contains("-demoExport") { demoExport(); return }
        if args.contains("-demoPrompts") { demoPrompts(); return }
        if args.contains("-demoCode") { demoCode(); return }
        if args.contains("-demoContext") { demoContext(); return }
        if args.contains("-demoCanvasPreview") { demoCanvasPreview(); return }
        if args.contains("-demoMermaid") { demoMermaid(); return }
        if args.contains("-demoCompare") { demoCompare(); return }
        if args.contains("-demoVoice") { demoVoice(); return }
        if args.contains("-demoImageEdit") { demoImageEdit(); return }
        if args.contains("-demoResearch") { demoResearch(); return }
        if args.contains("-demoComposer") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                input = "Como es esto ? https://github.com/maillab/cloud-mail ?"
                composerFocused = true
            }
            return
        }
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

    /// Demo OFFLINE de chat temporal: conversación isTemporary con un intercambio;
    /// verifica el banner superior (sin memoria ni historial).
    private func demoTemporary() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Chat temporal", providerID: activeProvider?.id ?? "casa", model: activeModel)
            conv.isTemporary = true
            context.insert(conv); current = conv
            let now = Date()
            let u = Message(role: "user", text: "¿Cuál es la capital de Francia?")
            u.createdAt = now; u.parentID = nil
            let a = Message(role: "assistant", text: "La capital de Francia es **París**.")
            a.createdAt = now.addingTimeInterval(1); a.parentID = u.id
            a.completionTokens = 12; a.tokensPerSecond = 30
            u.preferredChildID = a.id
            for m in [u, a] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a.id
            try? context.save()
        }
    }

    /// Demo OFFLINE de matemáticas LaTeX: display ($$…$$) e inline ($…$) nativas.
    private func demoMath() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo matemáticas", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            let u = Message(role: "user", text: "Explícame la fórmula cuadrática y la identidad de Euler")
            u.createdAt = now; u.parentID = nil
            let text = """
            La **fórmula cuadrática** resuelve $ax^2 + bx + c = 0$:

            $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

            La identidad de Euler es $e^{i\\pi} + 1 = 0$, y una integral famosa:

            $$\\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx = \\sqrt{\\pi}$$

            En línea: si $f(x) = x^2$, entonces $f'(x) = 2x$. El precio es $5 (no es fórmula).
            """
            let a = Message(role: "assistant", text: text)
            a.createdAt = now.addingTimeInterval(1); a.parentID = u.id
            a.completionTokens = 80; a.tokensPerSecond = 35
            u.preferredChildID = a.id
            for m in [u, a] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a.id
            try? context.save()
        }
    }

    /// Demo OFFLINE de export: siembra una conversación y escribe Markdown/PDF/JSON
    /// a Documents para verificación end-to-end (sin backend).
    private func demoExport() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo exportación", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            let u = Message(role: "user", text: "Resume la relatividad especial")
            u.createdAt = now
            let text = """
            La **relatividad especial** (Einstein, 1905) se basa en dos postulados:

            1. Las leyes de la física son iguales en todos los marcos inerciales.
            2. La velocidad de la luz $c$ es constante.

            De ahí sale la equivalencia masa-energía:

            $$E = mc^2$$

            | Concepto | Símbolo |
            | --- | --- |
            | Energía | E |
            | Masa | m |
            """
            let a = Message(role: "assistant", text: text, reasoning: "El usuario pide un resumen; doy postulados + fórmula + tabla.")
            a.createdAt = now.addingTimeInterval(1); a.parentID = u.id
            a.completionTokens = 120; a.tokensPerSecond = 40
            u.preferredChildID = a.id
            for m in [u, a] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a.id
            try? context.save()
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? Data(ConversationExport.markdown(conv).utf8).write(to: docs.appendingPathComponent("op-export-demo.md"))
                try? ConversationExport.jsonData(conv).write(to: docs.appendingPathComponent("op-export-demo.json"))
                try? ConversationExport.pdf(conv).write(to: docs.appendingPathComponent("op-export-demo.pdf"))
                print("OP_EXPORT_DIR=\(docs.path)")
            }
        }
    }

    /// Demo OFFLINE de búsqueda en conversación: 4 mensajes (2 mencionan París);
    /// abre la búsqueda con "parís" y muestra solo los coincidentes + contador.
    private func demoSearch() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo búsqueda", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            let u1 = Message(role: "user", text: "Háblame de París")
            let a1 = Message(role: "assistant", text: "París es la capital de Francia, la Ciudad de la Luz.")
            let u2 = Message(role: "user", text: "¿Y qué tiempo hace en Madrid?")
            let a2 = Message(role: "assistant", text: "Madrid tiene un clima continental seco.")
            let chain = [u1, a1, u2, a2]
            for (i, m) in chain.enumerated() {
                m.createdAt = now.addingTimeInterval(Double(i))
                m.parentID = i == 0 ? nil : chain[i - 1].id
                m.conversation = conv; conv.messages.append(m); context.insert(m)
            }
            u1.preferredChildID = a1.id; a1.preferredChildID = u2.id; u2.preferredChildID = a2.id
            conv.activeLeafID = a2.id
            try? context.save()
            showSearch = true
            searchInChat = "parís"
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

    /// Demo OFFLINE de adjunto: un mensaje de usuario con un archivo (chip) y
    /// su respuesta; verifica el chip de archivo en la burbuja sin red.
    private func demoFile() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo archivo", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let u = Message(role: "user", text: "Resume este documento en 3 puntos.")
            u.attachmentName = "informe-ventas.pdf"
            u.attachmentText = "Informe de ventas Q3. Ingresos: 1.2M. Crecimiento: 18%. Región norte lidera."
            u.parentID = nil
            let a = Message(role: "assistant", text: "Resumen del informe:\n\n1. **Ingresos** de 1.2M en el Q3.\n2. **Crecimiento** del 18% interanual.\n3. La **región norte** lidera las ventas.")
            a.parentID = u.id; u.preferredChildID = a.id
            a.completionTokens = 40; a.tokensPerSecond = 33
            for m in [u, a] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a.id
            try? context.save()
        }
    }

    /// Demo OFFLINE de Canvas: abre un documento de código con 2 versiones para
    /// verificar el editor y la navegación < n/m > sin red.
    private func demoCanvas() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let v1 = "func saluda(nombre: String) {\n    print(\"Hola, \\(nombre)\")\n}\n\nsaluda(nombre: \"Mundo\")"
            let v2 = "func saluda(nombre: String, emoji: String = \"👋\") {\n    print(\"\\(emoji) Hola, \\(nombre)\")\n}\n\nsaluda(nombre: \"Javier\")"
            let doc = CanvasDocument(title: "Swift", content: v2, language: "swift")
            doc.versions = [v1, v2]
            doc.versionIndex = 1
            canvasDoc = doc
        }
    }

    /// Demo OFFLINE del overlay de voz en vivo (sin tocar el micrófono): siembra
    /// el estado de escucha para verificar la UI a pantalla completa.
    private func demoLive() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            live.isActive = true
            live.phase = .listening
            live.heard = "¿Qué tiempo hace hoy en Madrid?"
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
                .keyboardShortcut("b", modifiers: .command)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showSearch.toggle() }
                    if !showSearch { searchInChat = "" }
                    Haptic.light()
                }) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(showSearch ? OP.accent : OP.textPrimary)
                        .accessibilityLabel(T("Search in chat", "Buscar en la conversación"))
                }
                .buttonStyle(ScaleButtonStyle())
                .keyboardShortcut("f", modifiers: .command)
                Menu {
                    Button { showSummary = true; Haptic.light() } label: {
                        Label(T("Summarize (TL;DR)", "Resumir (TL;DR)"), systemImage: "text.badge.checkmark")
                    }
                    Button { showTranslate = true; Haptic.light() } label: {
                        Label(T("Translate…", "Traducir…"), systemImage: "character.bubble")
                    }
                    Button { showAutoTag = true; Haptic.light() } label: {
                        Label(T("Tags…", "Etiquetas…"), systemImage: "tag")
                    }
                    Button { showRAG = true; Haptic.light() } label: {
                        Label(T("Ask attachments…", "Preguntar a adjuntos…"), systemImage: "doc.text.magnifyingglass")
                    }
                    Button { showVoiceNote = true; Haptic.light() } label: {
                        Label(T("Voice note…", "Nota de voz…"), systemImage: "waveform")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 18, weight: .medium))
                        .accessibilityLabel(T("More actions", "Más acciones"))
                }
                .buttonStyle(ScaleButtonStyle())
                Button(action: { onNewChat(); Haptic.light() }) {
                    Image(systemName: "square.and.pencil").font(.system(size: 18, weight: .medium))
                        .accessibilityLabel(T("New chat", "Nueva conversación"))
                }
                .buttonStyle(ScaleButtonStyle())
                .keyboardShortcut("n", modifiers: .command)
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
                .keyboardShortcut(",", modifiers: .command)
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

    /// Aviso de chat temporal: sin memoria ni historial.
    private var temporaryBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill").font(.system(size: 13)).foregroundStyle(OP.accent)
            Text(T("Temporary chat — won't use memory or be saved to history",
                   "Chat temporal: no usa memoria ni se guarda en el historial"))
                .font(.caption).foregroundStyle(OP.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(OP.accent.opacity(0.08))
    }

    /// Barra de búsqueda dentro de la conversación.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(OP.textTertiary)
            TextField(T("Search in this conversation", "Buscar en esta conversación"), text: $searchInChat)
                .foregroundStyle(OP.textPrimary).tint(OP.accent)
                .submitLabel(.search)
            if !searchInChat.isEmpty {
                Text("\(displayedMessages.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(OP.textTertiary)
                Button { searchInChat = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(OP.textTertiary)
                }
            }
        }
        .padding(10).background(OP.elevated).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 8)
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
                        if showSearch && displayedMessages.isEmpty {
                            Text(T("No matches in this conversation", "Sin coincidencias en esta conversación"))
                                .font(.footnote).foregroundStyle(OP.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(displayedMessages.enumerated()), id: \.element.id) { idx, m in
                            let sibs = current?.siblings(of: m) ?? [m]
                            MessageRow(message: m, isActive: vm.isStreaming && idx == messages.count - 1,
                                       onRegenerate: (!vm.isStreaming && !showSearch && m.role == "assistant" && idx == messages.count - 1) ? { regenerate() } : nil,
                                       onEdit: (!vm.isStreaming && !showSearch && m.role == "user") ? { startEdit(m) } : nil,
                                       onVariation: (!vm.isStreaming && m.role == "assistant" && !m.imageData.isEmpty) ? {
                                           if let p = activeProvider, let c = current {
                                               vm.variationImage(source: m.imageData, conversation: c, provider: p, context: context, imageModel: imageModel)
                                           }
                                       } : nil,
                                       onEditImage: (!vm.isStreaming && m.role == "assistant" && !m.imageData.isEmpty) ? {
                                           editImageSource = m.imageData
                                           editImagePrompt = ""
                                           showEditImagePrompt = true
                                       } : nil,
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

    /// Demo OFFLINE de prompts: muestra el panel de slash commands sobre el composer.
    private func demoPrompts() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !library.prompts.contains(where: { $0.title == "Traducir" }) {
                library.add(title: "Traducir", body: "Traduce al inglés manteniendo el tono:\n\n")
            }
            input = "/tr"
            composerFocused = true
        }
    }

    /// Demo OFFLINE de code interpreter: chart CSV (auto) + bloque JS con botón Ejecutar.
    private func demoCode() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo código", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            let u = Message(role: "user", text: "Grafica estas ventas y dime el total")
            u.createdAt = now
            let text = """
            Ventas del trimestre:

            ```csv
            mes,ventas
            Ene,120
            Feb,180
            Mar,150
            Abr,240
            ```

            Y el total con JavaScript (pulsa **Ejecutar**):

            ```js
            const ventas = [120, 180, 150, 240];
            const total = ventas.reduce((a, b) => a + b, 0);
            console.log("Total:", total);
            console.log("Promedio:", total / ventas.length);
            total;
            ```
            """
            let a = Message(role: "assistant", text: text)
            a.createdAt = now.addingTimeInterval(1); a.parentID = u.id
            u.preferredChildID = a.id
            for m in [u, a] { m.conversation = conv; conv.messages.append(m); context.insert(m) }
            conv.activeLeafID = a.id
            try? context.save()
        }
    }

    /// Demo OFFLINE de contexto largo: indicador de tokens por encima del presupuesto.
    private func demoContext() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let conv = Conversation(title: "Demo contexto", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(conv); current = conv
            let now = Date()
            var prev: UUID?
            for i in 0..<14 {
                let role = i % 2 == 0 ? "user" : "assistant"
                let body = String(repeating: "Este es un mensaje de prueba con contenido suficiente para sumar tokens al contexto. ", count: 24)
                let m = Message(role: role, text: "[\(i + 1)] \(body)")
                m.createdAt = now.addingTimeInterval(Double(i))
                m.parentID = prev
                if let p = prev, let parent = conv.messages.first(where: { $0.id == p }) { parent.preferredChildID = m.id }
                m.conversation = conv; conv.messages.append(m); context.insert(m)
                prev = m.id
            }
            conv.activeLeafID = prev
            try? context.save()
        }
    }

    // MARK: - Composer

    /// Estimated token size of the current conversation's active context.
    private var contextTokens: Int {
        guard let c = current else { return 0 }
        return ContextManager.estimateTokens(c.activeMessages.map { ChatTurn(role: $0.role, content: $0.text) })
    }

    /// DEMO offline: abre el selector de voz del dispositivo.
    private func demoVoice() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            showVoicePicker = true
        }
    }

    /// DEMO offline: siembra una imagen generada (mock) con botones Variación/Editar.
    private func demoImageEdit() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let c = Conversation(title: "Demo imagen", providerID: activeProvider?.id ?? "casa", model: activeModel)
            context.insert(c)
            let u = Message(role: "user", text: "Dibuja un atardecer sobre el mar")
            u.conversation = c; c.messages.append(u); context.insert(u)
            let a = Message(role: "assistant", text: "")
            a.imageData = Self.mockImageData()
            a.parentID = u.id; u.preferredChildID = a.id
            a.conversation = c; c.messages.append(a); context.insert(a)
            c.activeLeafID = a.id
            try? context.save()
            current = c
        }
    }

    /// Imagen mock (gradiente + sol) para demos offline; no toca la red.
    nonisolated static func mockImageData() -> Data {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let colors = [UIColor.systemOrange.cgColor, UIColor.systemPurple.cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 512), options: [])
            }
            ctx.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 200, y: 180, width: 112, height: 112))
        }
        return img.pngData() ?? Data()
    }

    private func openCompare() {
        compare.columns = ModelCompare.defaultColumns(providers: providers, preferred: activeProvider, model: activeModel)
        showCompare = true
    }

    private func openResearch() {
        research.question = ""
        showResearch = true
    }

    /// DEMO offline: abre el comparador con dos respuestas de ejemplo (sin red).
    private func demoCompare() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            var a = ModelCompare.Column(providerID: "casa", model: "swift-iq3_s", label: "Casa")
            a.text = "**Capital de Francia:** París.\n\nEs la ciudad más poblada del país y su centro político y cultural."
            a.completionTokens = 31
            var b = ModelCompare.Column(providerID: "qwen", model: "qwen-max", label: "Qwen")
            b.text = "La capital de Francia es **París**, sede del gobierno y conocida como la *Ciudad de la Luz*."
            b.completionTokens = 38
            compare.columns = [a, b]
            compare.prompt = "¿Cuál es la capital de Francia?"
            showCompare = true
        }
    }

    /// DEMO offline: abre deep research con plan, fuentes e informe de ejemplo (sin red).
    private func demoResearch() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            research.question = "¿Qué impacto tiene la IA en el empleo?"
            research.steps = [
                DeepResearch.Step(query: "IA y empleo: estadísticas recientes", isDone: true, sourceCount: 3),
                DeepResearch.Step(query: "sectores con mayor automatización", isDone: true, sourceCount: 2),
                DeepResearch.Step(query: "nuevos roles creados por la IA", isDone: true, sourceCount: 2)
            ]
            research.sources = [
                WebSource(title: "Informe OIT sobre IA y empleo", url: "https://example.org/oit-ia-empleo", snippet: "Estudio de la OIT."),
                WebSource(title: "Automatización por sectores", url: "https://example.org/sectores", snippet: "Análisis sectorial."),
                WebSource(title: "Nuevos roles en IA", url: "https://example.org/roles-ia", snippet: "Empleos emergentes.")
            ]
            research.report = "## Impacto de la IA en el empleo\n\nLa evidencia sugiere un efecto **neto mixto**: la IA automatiza tareas rutinarias pero también crea nuevos roles [1].\n\n- **Sectores más expuestos:** manufactura, atención al cliente y tareas administrativas [2].\n- **Roles emergentes:** ingeniería de datos, supervisión de modelos y ética de IA [3].\n\n> El saldo depende de la velocidad de adopción y de las políticas de recualificación [1].\n\n## Fuentes\n1. https://example.org/oit-ia-empleo\n2. https://example.org/sectores\n3. https://example.org/roles-ia"
            research.phase = .done
            research.isRunning = false
            showResearch = true
        }
    }

    /// Subtle context-size indicator above the composer; turns orange near the budget.
    private var contextBar: some View {
        let budget = ContextSettings.budgetTokens
        let over = ContextSettings.autoCompact && contextTokens > budget
        return HStack(spacing: 5) {
            Image(systemName: "text.alignleft").font(.system(size: 10))
            Text("≈ \(contextTokens) tokens")
                .font(.caption2.monospacedDigit())
            if over {
                Text(T("· auto-compact on", "· auto-compacción activa"))
                    .font(.caption2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(over ? Color.orange : OP.textTertiary)
        .padding(.horizontal, 16)
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let c = current, !c.activeMessages.isEmpty {
                contextBar
            }
            if !slashMatches.isEmpty {
                slashPanel
            }
            VStack(spacing: 8) {
                TextField(imageMode ? T("Describe the image…", "Describe la imagen…") : T("Ask anything", "Pregunta algo"),
                          text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($composerFocused)
                    .tint(OP.accent)
                    .foregroundStyle(OP.textPrimary)
                    .padding(.vertical, 4)
                HStack(spacing: 6) {
            Menu {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(T("Choose photo", "Elegir foto"), systemImage: "photo.on.rectangle")
                }
                Button { showCamera = true } label: { Label(T("Camera", "Cámara"), systemImage: "camera") }
                Button { showFilePicker = true } label: { Label(T("Attach file", "Adjuntar archivo"), systemImage: "doc") }
                Button { openCanvasFromChat() } label: { Label("Canvas", systemImage: "square.and.pencil") }
                Button { showPromptLibrary = true } label: { Label(T("Prompt library", "Librería de prompts"), systemImage: "sparkles") }
                Button { openCompare() } label: { Label(T("Compare models", "Comparar modelos"), systemImage: "rectangle.split.2x2") }
                Button { openResearch() } label: { Label(T("Deep research", "Investigar a fondo"), systemImage: "magnifyingglass") }
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
                Button {
                    if live.isActive { live.stop() } else { live.start() }
                    Haptic.selection()
                } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(live.isActive ? OP.accent : OP.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(live.isActive ? OP.accent.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                        .symbolEffect(.pulse, options: .repeating, isActive: live.isActive)
                        .accessibilityLabel(T("Live voice", "Voz en vivo"))
                }
                .buttonStyle(ScaleButtonStyle())
            }
                Spacer(minLength: 0)
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
                .keyboardShortcut(.return, modifiers: .command)
            }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(OP.border, lineWidth: 1))
        .padding(.horizontal, 12).padding(.bottom, 8).padding(.top, 4)
        }
    }

    private var slashMatches: [Prompt] {
        PromptLibrary.suggestions(for: input, in: library.prompts)
    }

    private var slashPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(slashMatches.prefix(5))) { p in
                Button {
                    input = p.body
                    composerFocused = true
                    Haptic.selection()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(OP.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.subheadline.weight(.medium)).foregroundStyle(OP.textPrimary)
                            Text(p.body).font(.caption).foregroundStyle(OP.textSecondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if p.id != slashMatches.prefix(5).last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(OP.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OP.border, lineWidth: 1))
        .padding(.horizontal, 12)
    }

    private var canSend: Bool {
        let hasContent = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil || attachedFile != nil
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

    /// Demo OFFLINE: Canvas HTML abierto en modo vista previa (WKWebView en el dispositivo).
    private func demoCanvasPreview() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let html = """
            <!doctype html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              body{font-family:-apple-system,system-ui,sans-serif;margin:0;padding:24px;
                   background:linear-gradient(160deg,#4578FA,#1A246B);color:#fff;min-height:100vh}
              .card{background:rgba(255,255,255,.14);border-radius:16px;padding:20px}
              h1{margin:0 0 8px;font-size:24px}
              p{opacity:.9;line-height:1.5}
              button{margin-top:12px;padding:10px 18px;border:none;border-radius:10px;
                     background:#fff;color:#1A246B;font-weight:600;font-size:15px}
              #count{font-size:40px;font-weight:700;margin:8px 0}
            </style></head>
            <body><div class="card">
              <h1>Open Pilot</h1>
              <p>Vista previa en vivo de HTML + JavaScript, renderizada en el dispositivo.</p>
              <div id="count">0</div>
              <button onclick="tick()">Sumar</button>
            </div>
            <script>
              let n=0;
              function tick(){n++;document.getElementById('count').textContent=n;}
            </script>
            </body></html>
            """
            let doc = CanvasDocument(title: "HTML", content: html, language: "html")
            doc.startInPreview = true
            canvasDoc = doc
        }
    }

    /// Demo OFFLINE: diagrama Mermaid renderizado con la librería bundleada (sin red).
    private func demoMermaid() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let src = """
            graph TD
              A[Usuario] --> B{Open Pilot}
              B --> C[Modelo local]
              B --> D[Nube opcional]
              C --> E[Respuesta]
              D --> E
            """
            let doc = CanvasDocument(title: "Mermaid", content: src, language: "mermaid")
            doc.startInPreview = true
            canvasDoc = doc
        }
    }

    /// Abre Canvas con un contenido dado (desde un bloque de código o el botón).
    private func openCanvas(lang: String, code: String) {
        let title = lang.isEmpty ? T("Document", "Documento") : lang.uppercased()
        canvasDoc = CanvasDocument(title: title, content: code, language: lang)
        Haptic.light()
    }

    /// Abre Canvas con el último bloque de código del asistente (o vacío).
    private func openCanvasFromChat() {
        for m in messages.reversed() where m.role == "assistant" {
            if let (lang, code) = Self.firstCodeBlock(in: m.text) {
                openCanvas(lang: lang, code: code)
                return
            }
        }
        openCanvas(lang: "", code: "")
    }

    /// Extrae el primer bloque ```lang … ``` de un texto.
    static func firstCodeBlock(in text: String) -> (String, String)? {
        let ns = text as NSString
        guard let re = try? NSRegularExpression(pattern: "```([^\\n`]*)\\n?([\\s\\S]*?)(?:```|$)") else { return nil }
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let lang = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let code = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .newlines)
        return (lang, code)
    }

    /// Overlay a pantalla completa del modo voz en vivo: fase actual, lo que se
    /// oye y un botón grande para terminar.
    private var liveOverlay: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: live.phase == .listening ? "waveform" : (live.phase == .thinking ? "brain" : "speaker.wave.2.fill"))
                    .font(.system(size: 56))
                    .foregroundStyle(OP.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: live.phase != .idle)
                Text(livePhaseLabel).font(.title3.weight(.semibold)).foregroundStyle(.white)
                Text(live.heard.isEmpty ? "…" : live.heard)
                    .font(.body).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center).padding(.horizontal, 32).lineLimit(6)
                Spacer()
                Button { live.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white).frame(width: 64, height: 64)
                        .background(Color.red.opacity(0.85)).clipShape(Circle())
                }
                .accessibilityLabel(T("End live voice", "Terminar voz en vivo"))
                Text(T("Tap to end", "Toca para terminar")).font(.caption).foregroundStyle(.white.opacity(0.6))
                Spacer().frame(height: 40)
            }
        }
    }

    private var livePhaseLabel: String {
        switch live.phase {
        case .listening: return T("Listening…", "Escuchando…")
        case .thinking: return T("Thinking…", "Pensando…")
        case .speaking: return T("Speaking…", "Hablando…")
        case .idle: return ""
        }
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
        let file = attachedFile
        input = ""
        attachedImage = nil
        attachedFile = nil
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
            vm.send(text, conversation: c, provider: p, context: context, browse: browse, image: img, file: file)
        }
    }
}
