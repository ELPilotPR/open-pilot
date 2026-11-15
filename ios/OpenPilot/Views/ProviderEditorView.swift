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

    var body: some View {
        Form {
            Section(T("Provider", "Proveedor")) {
                TextField(T("Name", "Nombre"), text: $provider.name)
                Picker(T("Type", "Tipo"), selection: $provider.kind) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("On-device (Apple Intelligence)").tag("ondevice")
                }
                if provider.kind == "ondevice" {
                    LabeledContent(T("Status", "Estado"), value: OnDeviceProvider.currentStatus())
                        .font(.callout)
                    Text(T("Runs Apple's on-device model (Apple Intelligence). No server, no API key, no model download. Requires a compatible device with iOS 26+.", "Ejecuta el modelo on-device de Apple (Apple Intelligence). Sin servidor, sin API key, sin descarga. Requiere un dispositivo compatible con iOS 26+."))
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
                            for m in srv.models where !provider.models.contains(m) { provider.models.append(m) }
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
                .onDelete { provider.models.remove(atOffsets: $0) }

                if !presets.isEmpty {
                    Menu {
                        ForEach(presets) { p in
                            Button {
                                if !provider.models.contains(p.id) {
                                    provider.models.append(p.id); try? context.save()
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
        provider.models.append(m)
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
                for m in ms where !provider.models.contains(m) { provider.models.append(m) }
                testResult = T("OK \(ms.count) model(s): ", "OK \(ms.count) modelo(s): ") + ms.joined(separator: ", ")
                try? context.save()
            } catch {
                testResult = "Error: " + error.localizedDescription
            }
            testing = false
        }
    }
}
