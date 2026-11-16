import Foundation
import SwiftData

/// Orquesta el envio de mensajes (texto + vision) y la generacion de imagenes,
/// persistiendo todo en el dispositivo (SwiftData). Sin backend: el provider habla
/// directo con el modelo. browse=true busca en la web; image=foto adjunta (vision).
///
/// Los mensajes se organizan en un ÁRBOL de versiones: editar un
/// mensaje de usuario o regenerar una respuesta crea una rama hermana que conserva
/// la original; la ruta raíz→hoja activa (`Conversation.activeMessages`) es lo que se
/// muestra y se envía como historial. Navegar < n/m > cambia de rama sin perder nada.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var isStreaming = false
    @Published var statusText: String?
    @Published var errorText: String?
    /// Velocidad de generación EN VIVO (tok/s) mientras llega el streaming.
    @Published var liveTPS: Double = 0
    private var task: Task<Void, Never>?

    func send(_ text: String, conversation: Conversation, provider: ProviderConfig,
              context: ModelContext, browse: Bool = false, image: Data? = nil,
              file: FileAttachment.Parsed? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = !(image?.isEmpty ?? true)
        let hasFile = !(file?.text.isEmpty ?? true)
        guard (!trimmed.isEmpty || hasImage || hasFile), !isStreaming else { return }
        let isFirstTurn = conversation.messages.isEmpty
        errorText = nil
        conversation.ensureTree()

        let userText = trimmed.isEmpty ? (hasImage ? "Describe esta imagen." : "Analiza este archivo.") : trimmed
        let userMsg = Message(role: "user", text: userText)
        if hasImage { userMsg.imageData = image! }
        if let f = file { userMsg.attachmentName = f.name; userMsg.attachmentText = f.text }
        userMsg.parentID = conversation.activeLeafID ?? conversation.sortedMessages.last?.id
        if let pid = userMsg.parentID, let parent = conversation.message(pid) {
            userMsg.version = conversation.siblings(of: userMsg).count + 1
            parent.preferredChildID = userMsg.id
        }
        userMsg.conversation = conversation
        conversation.messages.append(userMsg)
        context.insert(userMsg)

        let assistant = Message(role: "assistant", text: "")
        assistant.parentID = userMsg.id
        userMsg.preferredChildID = assistant.id
        assistant.conversation = conversation
        conversation.messages.append(assistant)
        context.insert(assistant)
        conversation.activeLeafID = assistant.id

        if conversation.title.isEmpty {
            conversation.title = String(userText.prefix(40))
        }
        try? context.save()

        runAssistant(assistant, userText: userText, hasImage: hasImage,
                     conversation: conversation, provider: provider, context: context,
                     browse: browse, isFirstTurn: isFirstTurn)
    }

    /// Ejecuta el streaming de una respuesta assistant ya insertada en el árbol.
    /// Compartido por send / regenerate / editAndResend (clima, divisas, browse, visión).
    private func runAssistant(_ assistant: Message, userText: String, hasImage: Bool,
                              conversation: Conversation, provider: ProviderConfig,
                              context: ModelContext, browse: Bool, isFirstTurn: Bool) {
        let history = conversation.activeMessages
            .filter { $0.role != "assistant" || !$0.text.isEmpty }
            .map { m -> ChatTurn in
                var content = m.text
                if m.role == "user", let ft = m.attachmentText, !ft.isEmpty {
                    content += "\n\n[Archivo adjunto: \(m.attachmentName ?? "archivo")]\n\(ft)"
                }
                return ChatTurn(role: m.role, content: content,
                                images: (m.role == "user" && !m.imageData.isEmpty) ? [m.imageData] : [])
            }

        let prov = ProviderFactory.make(kind: provider.kind)
        let model = VisionRouting.effectiveModel(current: conversation.model, hasImage: hasImage,
                                                 kind: provider.kind, baseURL: provider.baseURL)
        let baseURL = provider.baseURL
        let ctxWindow = ModelContextWindow.resolve(model: model, kind: provider.kind,
                                                   override: provider.contextWindow,
                                                   detected: ContextWindowDetector.cached(providerID: provider.id, model: model) ?? 0)
        let apiKey = provider.apiKey

        isStreaming = true
        task = Task { [weak self] in
            guard let self else { return }
            var turns = history
            if ContextSettings.autoCompact {
                let plan = ContextManager.compact(turns, budget: ContextManager.effectiveBudget(window: ctxWindow, manual: ContextSettings.budgetTokens))
                if plan.didCompact {
                    turns = plan.compacted
                    self.statusText = T("Compacting context…", "Compactando contexto…")
                }
            }
            var systemPrompt = ResponseStyle.current.systemPrompt
            let custom = CustomInstructions.systemPrompt
            if !custom.isEmpty { systemPrompt = custom + "\n\n" + systemPrompt }
            if !conversation.isTemporary {
                let mem = MemoryStore.systemPrompt
                if !mem.isEmpty { systemPrompt = mem + "\n\n" + systemPrompt }
                let profile = ProfileStore.systemPrompt
                if !profile.isEmpty { systemPrompt = profile + "\n\n" + systemPrompt }
            }
            if let pid = conversation.projectID {
                let desc = FetchDescriptor<Project>(predicate: #Predicate { $0.id == pid })
                if let proj = (try? context.fetch(desc))?.first, !proj.systemPrompt.isEmpty {
                    systemPrompt = proj.systemPrompt + "\n\n" + systemPrompt
                }
            }
            turns.insert(ChatTurn(role: "system", content: systemPrompt), at: 0)
            do {
                if WeatherService.isWeatherQuery(userText) && !hasImage {
                    self.statusText = T("Checking the weather…", "Consultando el tiempo…")
                    if let snap = await WeatherService.fetch(query: userText) {
                        assistant.weather = snap
                        try? context.save()
                        turns.insert(ChatTurn(role: "system", content: WeatherService.summaryContext(snap)), at: 0)
                    } else {
                        self.statusText = T("Couldn't find that place; answering without a card…", "No ubiqué ese lugar; respondo sin tarjeta…")
                    }
                } else if CurrencyService.isCurrencyQuery(userText) && !hasImage {
                    self.statusText = T("Checking exchange rates…", "Consultando divisas…")
                    if let p = CurrencyService.parse(userText),
                       let snap = await CurrencyService.fetch(amount: p.amount, from: p.from, to: p.to) {
                        assistant.currency = snap
                        try? context.save()
                        turns.insert(ChatTurn(role: "system", content: CurrencyService.summaryContext(snap)), at: 0)
                    } else {
                        self.statusText = T("Couldn't get the rate; answering without a card…", "No pude obtener la tasa; respondo sin tarjeta…")
                    }
                } else if browse {
                    self.statusText = T("Searching the web…", "Buscando en la web…")
                    let sources = await WebSearchService.enriched(query: userText, limit: 5)
                    assistant.sources = sources
                    if sources.isEmpty {
                        self.statusText = T("No results; answering without sources…", "Sin resultados; respondo sin fuentes…")
                    } else {
                        self.statusText = T("Reading \(sources.count) sources…", "Leyendo \(sources.count) fuentes…")
                        turns.insert(ChatTurn(role: "system",
                                              content: WebSearchService.contextBlock(query: userText, sources: sources)),
                                     at: 0)
                    }
                    try? context.save()
                }
                self.statusText = nil
                let stream = prov.stream(turns: turns, model: model, baseURL: baseURL, apiKey: apiKey)
                LiveActivityController.shared.start(title: conversation.title)
                let genStart = Date()
                var lastLive = genStart
                var usagePrompt = 0, usageCompletion = 0
                self.liveTPS = 0
                for try await ev in stream {
                    if Task.isCancelled { break }
                    switch ev {
                    case .delta(let t):
                        assistant.text += t
                        LiveActivityController.shared.update(snippet: assistant.text)
                        let now = Date()
                        if now.timeIntervalSince(lastLive) >= 0.25 {
                            lastLive = now
                            let tok = usageCompletion > 0 ? usageCompletion : LiveSpeed.estimateTokens(assistant.text)
                            self.liveTPS = LiveSpeed.tps(tokens: tok, elapsed: now.timeIntervalSince(genStart))
                        }
                    case .reasoning(let r): assistant.reasoning += r
                    case .usage(let p, let c): usagePrompt = p; usageCompletion = c
                    case .done: break
                    }
                }
                self.liveTPS = 0
                let elapsed = Date().timeIntervalSince(genStart)
                let outTok = usageCompletion > 0 ? usageCompletion : max(1, assistant.text.count / 4)
                let inTok = usagePrompt > 0 ? usagePrompt : max(1, turns.reduce(0) { $0 + $1.content.count } / 4)
                assistant.promptTokens = inTok
                assistant.completionTokens = outTok
                assistant.tokensPerSecond = elapsed > 0 ? Double(outTok) / elapsed : 0
                if !assistant.sources.isEmpty {
                    assistant.citations = CitationReference.parse(text: assistant.text, sources: assistant.sources)
                }
                if isFirstTurn {
                    self.generateTitle(conversation: conversation, provider: provider, context: context, firstUser: userText)
                }
                if MemoryStore.enabled && !assistant.text.isEmpty && !conversation.isTemporary {
                    self.extractMemories(userText: userText, assistantText: assistant.text, provider: provider, conversation: conversation)
                }
                // Modo sueño: cuenta el turno y consolida el perfil al llegar al umbral.
                if !conversation.isTemporary {
                    ProfileStore.newMessages += 1
                    if DreamSupport.shouldDream(enabled: ProfileStore.dreamEnabled, newMessages: ProfileStore.newMessages, threshold: ProfileStore.threshold) {
                        let dreamProvider = provider
                        let dreamModel = conversation.model
                        Task { @MainActor in
                            _ = await DreamEngine.dream(provider: dreamProvider, model: dreamModel, context: context)
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let recovered = await self.tryFallback(assistant: assistant, turns: turns,
                        conversation: conversation, failedProvider: provider, context: context,
                        hasImage: hasImage, isFirstTurn: isFirstTurn, userText: userText, originalError: error)
                    if !recovered {
                        self.errorText = error.localizedDescription
                        if assistant.text.isEmpty { context.delete(assistant) }
                    }
                }
            }
            LiveActivityController.shared.end()
            self.statusText = nil
            self.liveTPS = 0
            try? context.save()
            self.isStreaming = false
        }
    }

    /// Reintenta un turno fallido con el siguiente provider de la cadena de respaldo.
    /// Solo errores transitorios; nunca toca el happy path. Devuelve true si recuperó.
    private func tryFallback(assistant: Message, turns: [ChatTurn], conversation: Conversation,
                             failedProvider: ProviderConfig, context: ModelContext, hasImage: Bool,
                             isFirstTurn: Bool, userText: String, originalError: Error) async -> Bool {
        guard FallbackSettings.enabled, ProviderFallback.isRetryable(originalError) else { return false }
        let chain = ProviderFallback.chain(primaryID: failedProvider.id, fallbackIDs: FallbackSettings.ids)
        let all = (try? context.fetch(FetchDescriptor<ProviderConfig>())) ?? []
        var currentID = failedProvider.id
        while let nextID = ProviderFallback.next(after: currentID, in: chain) {
            currentID = nextID
            guard let cfg = all.first(where: { $0.id == nextID }) else { continue }
            let prov = ProviderFactory.make(kind: cfg.kind)
            let model = VisionRouting.effectiveModel(current: conversation.model, hasImage: hasImage,
                                                     kind: cfg.kind, baseURL: cfg.baseURL)
            assistant.text = ""; assistant.reasoning = ""
            self.statusText = T("Retrying with \(cfg.name)…", "Reintentando con \(cfg.name)…")
            do {
                let stream = prov.stream(turns: turns, model: model, baseURL: cfg.baseURL, apiKey: cfg.apiKey)
                let genStart = Date()
                var lastLive = genStart
                var usagePrompt = 0, usageCompletion = 0
                self.liveTPS = 0
                for try await ev in stream {
                    if Task.isCancelled { return false }
                    switch ev {
                    case .delta(let t):
                        assistant.text += t
                        LiveActivityController.shared.update(snippet: assistant.text)
                        let now = Date()
                        if now.timeIntervalSince(lastLive) >= 0.25 {
                            lastLive = now
                            let tok = usageCompletion > 0 ? usageCompletion : LiveSpeed.estimateTokens(assistant.text)
                            self.liveTPS = LiveSpeed.tps(tokens: tok, elapsed: now.timeIntervalSince(genStart))
                        }
                    case .reasoning(let r): assistant.reasoning += r
                    case .usage(let p, let c): usagePrompt = p; usageCompletion = c
                    case .done: break
                    }
                }
                self.liveTPS = 0
                let elapsed = Date().timeIntervalSince(genStart)
                let outTok = usageCompletion > 0 ? usageCompletion : max(1, assistant.text.count / 4)
                let inTok = usagePrompt > 0 ? usagePrompt : max(1, turns.reduce(0) { $0 + $1.content.count } / 4)
                assistant.promptTokens = inTok
                assistant.completionTokens = outTok
                assistant.tokensPerSecond = elapsed > 0 ? Double(outTok) / elapsed : 0
                if isFirstTurn {
                    self.generateTitle(conversation: conversation, provider: cfg, context: context, firstUser: userText)
                }
                self.statusText = nil
                return true
            } catch {
                if Task.isCancelled { return false }
                if !ProviderFallback.isRetryable(error) { return false }
                continue
            }
        }
        return false
    }

    /// Crea el par user+assistant para un turno de imagen y devuelve el mensaje assistant.
    private func makeImageTurn(prompt: String, conversation: Conversation, context: ModelContext) -> Message? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return nil }
        errorText = nil
        conversation.ensureTree()

        let userMsg = Message(role: "user", text: trimmed)
        userMsg.parentID = conversation.activeLeafID ?? conversation.sortedMessages.last?.id
        if let pid = userMsg.parentID, let parent = conversation.message(pid) {
            userMsg.version = conversation.siblings(of: userMsg).count + 1
            parent.preferredChildID = userMsg.id
        }
        userMsg.conversation = conversation
        conversation.messages.append(userMsg)
        context.insert(userMsg)

        let assistant = Message(role: "assistant", text: "")
        assistant.parentID = userMsg.id
        userMsg.preferredChildID = assistant.id
        assistant.conversation = conversation
        conversation.messages.append(assistant)
        context.insert(assistant)
        conversation.activeLeafID = assistant.id

        if conversation.title.isEmpty {
            conversation.title = String(trimmed.prefix(40))
        }
        try? context.save()
        return assistant
    }

    /// Corre una operación de imagen (generar/editar/variar) sobre un turno nuevo.
    private func runImageTurn(prompt: String, conversation: Conversation, context: ModelContext,
                              statusEN: String, statusES: String,
                              operation: @escaping () async throws -> Data) {
        guard let assistant = makeImageTurn(prompt: prompt, conversation: conversation, context: context) else { return }
        isStreaming = true
        statusText = T(statusEN, statusES)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await operation()
                if !Task.isCancelled { assistant.imageData = data }
            } catch {
                if !Task.isCancelled {
                    self.errorText = error.localizedDescription
                    if assistant.imageData.isEmpty { context.delete(assistant) }
                }
            }
            self.statusText = nil
            try? context.save()
            self.isStreaming = false
        }
    }

    func generateImage(prompt: String, conversation: Conversation, provider: ProviderConfig,
                       context: ModelContext, imageModel: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = provider.baseURL
        let key = provider.apiKey
        runImageTurn(prompt: trimmed, conversation: conversation, context: context,
                     statusEN: "Generating image…", statusES: "Generando imagen…") {
            try await ImageGenerationService.generate(prompt: trimmed, model: imageModel, baseURL: base, apiKey: key)
        }
    }

    /// Image-to-image: edita una imagen existente (p.ej. una generada) con un prompt.
    func editImage(prompt: String, source: Data, conversation: Conversation, provider: ProviderConfig,
                   context: ModelContext, imageModel: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = provider.baseURL
        let key = provider.apiKey
        runImageTurn(prompt: trimmed, conversation: conversation, context: context,
                     statusEN: "Editing image…", statusES: "Editando imagen…") {
            try await ImageGenerationService.edit(prompt: trimmed, image: source, model: imageModel, baseURL: base, apiKey: key)
        }
    }

    /// Variación de una imagen existente (sin prompt).
    func variationImage(source: Data, conversation: Conversation, provider: ProviderConfig,
                        context: ModelContext, imageModel: String) {
        let base = provider.baseURL
        let key = provider.apiKey
        runImageTurn(prompt: T("Variation", "Variación"), conversation: conversation, context: context,
                     statusEN: "Creating variation…", statusES: "Creando variación…") {
            try await ImageGenerationService.variation(image: source, model: imageModel, baseURL: base, apiKey: key)
        }
    }

    /// Título inteligente: llamada mínima al modelo tras el primer
    /// intercambio. Fire-and-forget; el prefijo del user queda como fallback.
    private func generateTitle(conversation: Conversation, provider: ProviderConfig, context: ModelContext, firstUser: String) {
        let model = conversation.model
        let base = provider.baseURL
        let kind = provider.kind
        let api = provider.apiKey
        Task { @MainActor in
            let prompt = "Resume el tema de este mensaje en un título de 3 a 5 palabras, en su mismo idioma, sin comillas ni punto final. Mensaje: \(firstUser.prefix(300))"
            var title = ""
            do {
                for try await ev in ProviderFactory.make(kind: kind).stream(turns: [ChatTurn(role: "user", content: prompt)], model: model, baseURL: base, apiKey: api) {
                    if case .delta(let t) = ev { title += t }
                }
            } catch { return }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'."))
            if !title.isEmpty, title.count <= 60, conversation.title != title {
                conversation.title = title
                try? context.save()
            }
        }
    }

    /// Memoria automática: tras cada respuesta, pide al modelo hechos duraderos
    /// del usuario y los guarda (dedup + tope). Fire-and-forget, como generateTitle.
    private func extractMemories(userText: String, assistantText: String, provider: ProviderConfig, conversation: Conversation) {
        let model = conversation.model
        let base = provider.baseURL
        let kind = provider.kind
        let api = provider.apiKey
        let existing = MemoryStore.entries.joined(separator: "\n")
        Task { @MainActor in
            let prompt = """
            Extrae hechos duraderos y específicos sobre el usuario (preferencias, datos personales estables, proyectos) que sirvan para personalizar futuras respuestas. Ignora datos pasajeros o triviales. No repitas hechos ya conocidos. Devuelve UN hecho por línea, sin viñetas ni numeración, en el idioma del usuario. Si no hay nada nuevo que recordar, responde exactamente NINGUNO.

            Hechos ya conocidos:
            \(existing.isEmpty ? "(ninguno)" : existing)

            Usuario: \(userText.prefix(600))
            Asistente: \(assistantText.prefix(600))
            """
            var out = ""
            do {
                for try await ev in ProviderFactory.make(kind: kind).stream(turns: [ChatTurn(role: "user", content: prompt)], model: model, baseURL: base, apiKey: api) {
                    if case .delta(let t) = ev { out += t }
                }
            } catch { return }
            let facts = MemoryStore.parseExtraction(out)
            if !facts.isEmpty { MemoryStore.add(facts) }
        }
    }

    /// Plan de compactación manual del chat actual (mismo presupuesto que el auto).
    func compactPlan(conversation: Conversation, provider: ProviderConfig) -> ContextManager.Plan {
        let turns = conversation.activeMessages
            .filter { $0.role != "assistant" || !$0.text.isEmpty }
            .map { ChatTurn(role: $0.role, content: $0.text) }
        let window = ModelContextWindow.resolve(model: conversation.model, kind: provider.kind,
                                                override: provider.contextWindow,
                                                detected: ContextWindowDetector.cached(providerID: provider.id, model: conversation.model) ?? 0)
        return ContextManager.compact(turns, budget: ContextManager.effectiveBudget(window: window, manual: ContextSettings.budgetTokens))
    }

    /// Regenera la última respuesta como una NUEVA versión (rama hermana): la
    /// anterior se conserva y se navega con < n/m >. Conserva si usó browse.
    func regenerate(conversation: Conversation, provider: ProviderConfig, context: ModelContext) {
        guard !isStreaming else { return }
        conversation.ensureTree()
        let msgs = conversation.activeMessages
        guard let lastAssistant = msgs.last(where: { $0.role == "assistant" }),
              let parentID = lastAssistant.parentID,
              let userMsg = conversation.message(parentID) else { return }
        let text = userMsg.text
        let img = userMsg.imageData.isEmpty ? nil : userMsg.imageData
        let hadBrowse = !lastAssistant.sources.isEmpty

        let assistant = Message(role: "assistant", text: "")
        assistant.parentID = parentID
        assistant.version = conversation.siblings(of: assistant).count + 1
        assistant.conversation = conversation
        conversation.messages.append(assistant)
        context.insert(assistant)
        userMsg.preferredChildID = assistant.id
        conversation.activeLeafID = assistant.id
        try? context.save()

        runAssistant(assistant, userText: text, hasImage: img != nil,
                     conversation: conversation, provider: provider, context: context,
                     browse: hadBrowse, isFirstTurn: false)
    }

    /// Edita un mensaje del usuario creando una NUEVA versión (rama hermana): el
    /// original y su respuesta se conservan; se navega con < n/m >. Conserva browse/imagen.
    func editAndResend(_ message: Message, newText: String, conversation: Conversation,
                       provider: ProviderConfig, context: ModelContext) {
        guard !isStreaming else { return }
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversation.ensureTree()
        let active = conversation.activeMessages
        let img = message.imageData.isEmpty ? nil : message.imageData
        let hadBrowse = active.contains { $0.role == "assistant" && !$0.sources.isEmpty }

        let newUser = Message(role: "user", text: trimmed)
        newUser.parentID = message.parentID
        newUser.imageData = message.imageData
        newUser.attachmentName = message.attachmentName
        newUser.attachmentText = message.attachmentText
        newUser.version = conversation.siblings(of: newUser).count + 1
        newUser.conversation = conversation
        conversation.messages.append(newUser)
        context.insert(newUser)
        if let pid = message.parentID, let parent = conversation.message(pid) {
            parent.preferredChildID = newUser.id
        }

        let assistant = Message(role: "assistant", text: "")
        assistant.parentID = newUser.id
        newUser.preferredChildID = assistant.id
        assistant.conversation = conversation
        conversation.messages.append(assistant)
        context.insert(assistant)
        conversation.activeLeafID = assistant.id
        try? context.save()

        runAssistant(assistant, userText: trimmed, hasImage: img != nil,
                     conversation: conversation, provider: provider, context: context,
                     browse: hadBrowse, isFirstTurn: false)
    }

    /// Continúa la última respuesta assistant EN EL MISMO mensaje (no crea rama):
    /// pide al modelo seguir donde quedó y anexa los deltas al texto existente.
    func continueAnswer(conversation: Conversation, provider: ProviderConfig, context: ModelContext) {
        guard !isStreaming else { return }
        conversation.ensureTree()
        let msgs = conversation.activeMessages
        guard let assistant = msgs.last(where: { $0.role == "assistant" }), !assistant.text.isEmpty else { return }
        let history = msgs
            .filter { $0.role != "assistant" || !$0.text.isEmpty }
            .map { m -> ChatTurn in
                var content = m.text
                if m.role == "user", let ft = m.attachmentText, !ft.isEmpty {
                    content += "\n\n[Archivo adjunto: \(m.attachmentName ?? "archivo")]\n\n\(ft)"
                }
                return ChatTurn(role: m.role, content: content,
                                images: (m.role == "user" && !m.imageData.isEmpty) ? [m.imageData] : [])
            }
        let prov = ProviderFactory.make(kind: provider.kind)
        let model = VisionRouting.effectiveModel(current: conversation.model, hasImage: false,
                                                 kind: provider.kind, baseURL: provider.baseURL)
        let baseURL = provider.baseURL
        let apiKey = provider.apiKey
        isStreaming = true
        task = Task { [weak self] in
            guard let self else { return }
            var turns = history
            turns.append(ChatTurn(role: "user", content: ContinueSupport.instruction))
            let genStart = Date()
            var lastLive = genStart
            var usageCompletion = 0
            self.liveTPS = 0
            do {
                for try await ev in prov.stream(turns: turns, model: model, baseURL: baseURL, apiKey: apiKey) {
                    if Task.isCancelled { break }
                    switch ev {
                    case .delta(let t):
                        assistant.text += t
                        let now = Date()
                        if now.timeIntervalSince(lastLive) >= 0.25 {
                            lastLive = now
                            let tok = usageCompletion > 0 ? usageCompletion : LiveSpeed.estimateTokens(assistant.text)
                            self.liveTPS = LiveSpeed.tps(tokens: tok, elapsed: now.timeIntervalSince(genStart))
                        }
                    case .reasoning(let r): assistant.reasoning += r
                    case .usage(_, let c): usageCompletion = c
                    case .done: break
                    }
                }
            } catch {
                if !Task.isCancelled { self.errorText = error.localizedDescription }
            }
            self.liveTPS = 0
            let elapsed = Date().timeIntervalSince(genStart)
            let outTok = usageCompletion > 0 ? usageCompletion : max(1, assistant.text.count / 4)
            assistant.completionTokens = outTok
            assistant.tokensPerSecond = elapsed > 0 ? Double(outTok) / elapsed : 0
            try? context.save()
            self.isStreaming = false
        }
    }

    func stop() {
        task?.cancel()
        isStreaming = false
        statusText = nil
    }
}
