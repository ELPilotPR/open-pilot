import SwiftUI
import SwiftData

struct ProviderEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var provider: ProviderConfig
    @State private var testing = false
    @State private var testResult: String?
    @State private var newModel = ""

    var body: some View {
        Form {
            Section(T("Provider", "Proveedor")) {
                TextField(T("Name", "Nombre"), text: $provider.name)
                Picker(T("Type", "Tipo"), selection: $provider.kind) {
                    Text("OpenAI-compatible").tag("openai")
                    Text("Anthropic").tag("anthropic")
                }
                TextField("Base URL", text: $provider.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField(T("API Key (optional)", "API Key (opcional)"), text: $provider.apiKey)
            }

            Section {
                ForEach(provider.models, id: \.self) { m in
                    Text(m).font(.callout)
                }
                .onDelete { provider.models.remove(atOffsets: $0) }

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

    private func addModel() {
        let m = newModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty, !provider.models.contains(m) else { return }
        provider.models.append(m)
        newModel = ""
        try? context.save()
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
