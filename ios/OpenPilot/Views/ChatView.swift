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
    @State private var probingImage = false
    @ObservedObject private var voice = VoiceManager.shared
    @State private var dictationPrefix = ""
    @FocusState private var composerFocused: Bool
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @AppStorage("selectedModel") private var selectedModel = "swift-iq3_s"
    @AppStorage("imageModel") private var imageModel = "dall-e-3"

    private var activeProvider: ProviderConfig? {
        if let cid = current?.providerID, let p = providers.first(where: { $0.id == cid }) { return p }
        return providers.first(where: { $0.id == selectedProviderID }) ?? providers.first
    }
    private var activeModel: String { current?.model ?? selectedModel }
    private var messages: [Message] { current?.sortedMessages ?? [] }
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
    }

    /// Hook de verificación visual (SOLO con argumento -demoWeather/-demoCurrency al
    /// lanzar). No afecta el uso normal: envía una consulta demo para ver la tarjeta.
    private func runDemoIfNeeded() {
        let args = CommandLine.arguments
        if args.contains("-demoCitations") { demoCitations(); return }
        if args.contains("-demoReasoning") { demoReasoning(); return }
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

    private func attachmentPreview(_ ui: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Imagen adjunta").font(.caption).foregroundStyle(OP.textSecondary)
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

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            modelMenu
            HStack {
                Button(action: { onMenu(); Haptic.light() }) {
                    Image(systemName: "line.3.horizontal").font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(ScaleButtonStyle())
                Spacer()
                Button(action: { onNewChat(); Haptic.light() }) {
                    Image(systemName: "square.and.pencil").font(.system(size: 18, weight: .medium))
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
            Image(systemName: "sparkle")
                .font(.system(size: 34)).foregroundStyle(OP.textPrimary)
                .padding(.bottom, 14)
            Text(T("How can I help you?", "¿En qué puedo ayudarte?"))
                .font(.title2.weight(.semibold)).foregroundStyle(OP.textPrimary)
            Spacer()
            LanguageToggle()
                .padding(.bottom, 28)
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
                            MessageRow(message: m, isActive: vm.isStreaming && idx == messages.count - 1,
                                       onRegenerate: (!vm.isStreaming && m.role == "assistant" && idx == messages.count - 1) ? { regenerate() } : nil)
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
            }
            if !imageMode {
                Button { browse.toggle(); Haptic.selection() } label: {
                    Image(systemName: "globe").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(browse ? OP.accent : OP.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(browse ? OP.accent.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                        .animation(.easeInOut(duration: 0.2), value: browse)
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
                }
                .buttonStyle(ScaleButtonStyle())
            }
            TextField(imageMode ? T("Describe the image you want…", "Describe la imagen que quieres…") : T("Ask anything", "Pregunta lo que quieras"),
                      text: $input, axis: .vertical)
                .lineLimit(1...6)
                .focused($composerFocused)
                .tint(OP.accent)
                .foregroundStyle(OP.textPrimary)
                .padding(.vertical, 7)
            if vm.isStreaming {
                Button { vm.stop(); Haptic.light() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 30)).foregroundStyle(OP.textPrimary)
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
