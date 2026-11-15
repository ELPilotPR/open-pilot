import SwiftUI
import SwiftData

struct ProviderEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var provider: ProviderConfig
    @State private var testing = false
    @State private var testResult: String?
    @State private var newModel = ""
    @State private var scanning = false
    @State private var foundServers: [LocalServer] = []
    @State private var scanStatus: String?
    @State private var detectingContext = false
    @State private var contextStatus = ""

    var body: some View {
        Form {
            Section(T("Provider", "Proveedor")) {
                TextField(T("Name", "Nombre"), text: $provider.name)
                Picker(T("Type", "Tipo"), selection: $provider.kind) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("On-device (Apple Intelligence)").tag("ondevice")
                    Text("On-device (GGUF / llama.cpp)").tag("gguf")
                }
                if provider.kind == "ondevice" {
                    LabeledContent(T("Status", "Estado"), value: OnDeviceProvider.currentStatus())
                        .font(.callout)
                    Text(T("Runs Apple's on-device model (Apple Intelligence). No server, no API key, no model download. Requires a compatible device with iOS 26+.", "Ejecuta el modelo on-device de Apple (Apple Intelligence). Sin servidor, sin API key, sin descarga. Requiere un dispositivo compatible con iOS 26+."))
                        .font(.caption).foregroundStyle(.secondary)
                } else if provider.kind == "gguf" {
                    NavigationLink { LocalModelsView() } label: {
                        Label(T("Manage local models (GGUF)", "Gestionar modelos locales (GGUF)"), systemImage: "internaldrive")
                    }
                    Text(T("Runs a downloaded GGUF model on-device with llama.cpp. No server, no API key. Download a model first, then add its filename below (or use Test & discover).", "Ejecuta un modelo GGUF descargado en el dispositivo con llama.cpp. Sin servidor, sin API key. Descarga un modelo primero y añade su nombre de archivo abajo (o usa Probar y descubrir)."))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    TextField("Base URL", text: $provider.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField(T("API Key (optional)", "API Key (opcional)"), text: $provider.apiKey)
                }
            }

            if provider.kind != "ondevice" {
                Section {
                    TextField(T("Context window (0 = auto)", "Ventana de contexto (0 = auto)"), value: $provider.contextWindow, format: .number)
                        .keyboardType(.numberPad)
                    Button { detectContext() } label: {
                        HStack {
                            Label(T("Detect from server", "Detectar del servidor"), systemImage: "arrow.down.circle")
                            Spacer()
                            if detectingContext { ProgressView() }
                        }
                    }
                    .disabled(detectingContext)
                    if !contextStatus.isEmpty { Text(contextStatus).font(.caption).foregroundStyle(.secondary) }
                } header: {
                    Text(T("Context", "Contexto"))
                } footer: {
                    Text(T("Max tokens this model accepts. 0 = auto-detect from the server or estimate by model family. Set it by hand if your server doesn't report it (e.g. 512000 for a 512k Qwen).",
                           "Máx. de tokens que acepta el modelo. 0 = detectar del servidor o estimar por familia. Ponlo a mano si tu servidor no lo reporta (p. ej. 512000 para un Qwen de 512k)."))
                }
            }

            if provider.kind != "ondevice" && provider.kind != "gguf" {
                Section {
                    Button { scanLocal() } label: {
                        if scanning {
                            HStack(spacing: 8) { ProgressView(); Text(T("Scanning network…", "Escaneando la red…")) }
                        } else {
                            Label(T("Discover Ollama / LM Studio", "Descubrir Ollama / LM Studio"), systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                    .disabled(scanning)
                    Menu {
                        Button("Ollama · http://localhost:11434/v1") { provider.baseURL = "http://localhost:11434/v1"; provider.kind = "openai" }
                        Button("Ollama LAN · http://192.168.1.50:11434/v1") { provider.baseURL = "http://192.168.1.50:11434/v1"; provider.kind = "openai" }
                        Button("LM Studio · http://localhost:1234/v1") { provider.baseURL = "http://localhost:1234/v1"; provider.kind = "openai" }
                    } label: {
                        Label(T("Use a common address", "Usar una dirección común"), systemImage: "link")
                    }
                    ForEach(foundServers) { srv in
                        Button {
                            provider.baseURL = srv.baseURL
                            provider.kind = "openai"
                            provider.models = provider.models + srv.models.filter { !provider.models.contains($0) }
                            try? context.save()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(srv.name) · \(srv.baseURL)").font(.callout)
                                Text(srv.models.isEmpty ? T("no models listed", "sin modelos listados") : srv.models.prefix(4).joined(separator: ", "))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let st = scanStatus { Text(st).font(.caption).foregroundStyle(.secondary) }
                } header: {
                    Text(T("Local servers", "Servidores locales"))
                } footer: {
                    Text(T("Finds Ollama (:11434) and LM Studio (:1234) on your Wi-Fi network and fills the base URL + models. Nothing leaves your network.", "Encuentra Ollama (:11434) y LM Studio (:1234) en tu red Wi-Fi y rellena la base URL + modelos. Nada sale de tu red."))
                }
            }

            Section {
                ForEach(provider.models, id: \.self) { m in
                    HStack(spacing: 6) {
                        Text(m).font(.callout)
                        Spacer(minLength: 0)
                        ForEach(ModelCatalog.preset(for: m)?.badges ?? [], id: \.self) { badge in
                            Text(badgeLabel(badge))
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(OP.elevated).clipShape(Capsule())
                                .foregroundStyle(OP.textSecondary)
                        }
                    }
                }
                .onDelete { offsets in
                    var copy = provider.models
                    copy.remove(atOffsets: offsets)
                    provider.models = copy
                    try? context.save()
                }

                if !presets.isEmpty {
                    Menu {
                        ForEach(presets) { p in
                            Button {
                                if !provider.models.contains(p.id) {
                                    provider.models = provider.models + [p.id]; try? context.save()
                                }
                            } label: {
                                Label(p.name + (p.badges.isEmpty ? "" : " · " + p.badges.joined(separator: ", ")),
                                      systemImage: provider.models.contains(p.id) ? "checkmark" : "plus")
                            }
                        }
                    } label: {
                        Label(T("Add from presets", "Añadir de presets"), systemImage: "sparkles")
                    }
                }

                HStack {
                    TextField(T("Add model (e.g. qwen-plus)", "Añadir modelo (ej. qwen-plus)"), text: $newModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(T("Add", "Añadir")) { addModel() }
                        .disabled(newModel.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button { discover() } label: {
                    if testing {
                        ProgressView()
                    } else {
                        Label(T("Test & discover models", "Probar y descubrir modelos"), systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(testing)
                if let r = testResult {
                    Text(r).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text(T("Models", "Modelos"))
            } footer: {
                Text(T("Type the model by hand (e.g. qwen-plus, qwen-max) or use Test to discover them via GET /models. Qwen/DashScope: https://dashscope.aliyuncs.com/compatible-mode/v1", "Escribe el modelo a mano (p. ej. qwen-plus, qwen-max) o usa Probar para descubrirlos con GET /models. Qwen/DashScope: https://dashscope.aliyuncs.com/compatible-mode/v1"))
            }

            Section {
                Picker(T("Image generation", "Generación de imágenes"), selection: $provider.imageCapability) {
                    Text("Auto").tag("auto")
                    Text(T("Yes", "Sí")).tag("yes")
                    Text("No").tag("no")
                }
            } header: {
                Text(T("Images", "Imágenes"))
            } footer: {
                Text(T("Auto: Qwen/DashScope and OpenAI yes; a local text server no. Set Yes if your server generates images, No to warn when an image is requested.", "Auto: Qwen/DashScope y OpenAI sí; un server local de texto no. Pon «Sí» si tu servidor genera imágenes, «No» para avisar al pedir una imagen."))
            }
        }
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    private var presets: [ModelPreset] { ModelCatalog.presets(for: provider.baseURL, kind: provider.kind) }

    private func badgeLabel(_ b: String) -> String {
        switch b {
        case "vision": return T("vision", "visión")
        case "reasoning": return T("reasoning", "razonamiento")
        case "image": return T("image", "imagen")
        default: return b
        }
    }

    private func addModel() {
        let m = newModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty, !provider.models.contains(m) else { return }
        provider.models = provider.models + [m]   // reasignar: SwiftData observa el SET, no el append in-place
        newModel = ""
        try? context.save()
    }

    private func scanLocal() {
        scanning = true
        foundServers = []
        scanStatus = nil
        Task { @MainActor in
            guard let ip = LocalServerDiscovery.currentIPv4(),
                  let subnet = LocalServerDiscovery.subnetPrefix(ofIPv4: ip) else {
                scanStatus = T("No local network detected. Type the base URL by hand (e.g. http://192.168.1.50:11434/v1).", "No se detectó red local. Escribe la base URL a mano (ej. http://192.168.1.50:11434/v1).")
                scanning = false
                return
            }
            let servers = await LocalServerDiscovery.scan(subnet: subnet)
            foundServers = servers
            scanStatus = servers.isEmpty
                ? T("No Ollama/LM Studio found on \(subnet).0/24. Make sure the server is running and on the same Wi-Fi.", "No se encontró Ollama/LM Studio en \(subnet).0/24. Asegúrate de que el servidor esté activo y en el mismo Wi-Fi.")
                : T("Found \(servers.count) server(s). Tap one to use it.", "\(servers.count) servidor(es). Toca uno para usarlo.")
            scanning = false
        }
    }

    private func discover() {
        testing = true
        testResult = nil
        let p = ProviderFactory.make(kind: provider.kind)
        let base = provider.baseURL
        let key = provider.apiKey
        Task {
            do {
                let ms = try await p.models(baseURL: base, apiKey: key)
                let fresh = ms.filter { !provider.models.contains($0) }
                if !fresh.isEmpty { provider.models = provider.models + fresh }
                testResult = T("OK \(ms.count) model(s): ", "OK \(ms.count) modelo(s): ") + ms.joined(separator: ", ")
                try? context.save()
            } catch {
                testResult = "Error: " + error.localizedDescription
            }
            testing = false
        }
    }

    private func detectContext() {
        detectingContext = true
        contextStatus = T("Detecting…", "Detectando…")
        let base = provider.baseURL
        let key = provider.apiKey
        let model = provider.models.first ?? ""
        Task { @MainActor in
            if let w = await ContextWindowDetector.detect(baseURL: base, apiKey: key, model: model) {
                provider.contextWindow = w
                try? context.save()
                contextStatus = T("Detected: \(TokenFormat.short(w)) tokens.", "Detectado: \(TokenFormat.short(w)) tokens.")
            } else {
                contextStatus = T("This server doesn't report its context. Set it by hand (0 = estimate by model).", "Este servidor no reporta su contexto. Ponlo a mano (0 = estimar por modelo).")
            }
            detectingContext = false
        }
    }
}
