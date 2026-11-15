import SwiftUI

/// Descarga y gestiona modelos GGUF para el proveedor offline (llama.cpp).
struct LocalModelsView: View {
    @State private var downloaded: [String] = []
    @State private var progress: [String: Double] = [:]
    @State private var busy: Set<String> = []
    @State private var errorText: String?
    @State private var customID = ""
    @State private var customFile = ""

    var body: some View {
        List {
            Section {
                ForEach(GGUFSupport.catalog) { m in
                    row(id: m.id, filename: m.filename, title: m.name,
                        subtitle: "~\(String(format: "%.1f", m.sizeGB)) GB · \(m.note)")
                }
            } header: {
                Text(T("Recommended", "Recomendados"))
            } footer: {
                Text(T("This iPhone has ~\(String(format: "%.0f", DeviceHealth.physicalRAMGB)) GB RAM. Models run fully on-device with llama.cpp; download over Wi-Fi. Larger models need more RAM.",
                       "Este iPhone tiene ~\(String(format: "%.0f", DeviceHealth.physicalRAMGB)) GB de RAM. Los modelos corren en el dispositivo con llama.cpp; descarga por Wi-Fi. Los grandes necesitan mas RAM."))
            }
            Section(T("Custom model", "Modelo propio")) {
                TextField(T("Hugging Face repo (owner/name)", "Repo de Hugging Face (owner/name)"), text: $customID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(T("GGUF filename", "Archivo GGUF"), text: $customFile)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(T("Download", "Descargar")) {
                    let id = customID.trimmingCharacters(in: .whitespaces)
                    let f = customFile.trimmingCharacters(in: .whitespaces)
                    guard !id.isEmpty, f.hasSuffix(".gguf") else { errorText = "Enter a repo and a .gguf filename."; return }
                    download(id: id, filename: f)
                }.disabled(busy.contains(customFile))
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(T("Local Models (GGUF)", "Modelos locales (GGUF)"))
        .onAppear { downloaded = LocalModelStore.downloaded() }
    }

    @ViewBuilder
    private func row(id: String, filename: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).foregroundStyle(OP.textPrimary)
            Text(subtitle).font(.caption).foregroundStyle(OP.textSecondary)
            if let model = GGUFSupport.model(for: filename) {
                let fit = DeviceHealth.fit(for: model)
                HStack(spacing: 4) {
                    Image(systemName: fit.symbol)
                    Text(fit.label)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(fit.tier == .comfortable ? OP.success : (fit.tier == .tight ? .orange : .red))
                .accessibilityLabel(fit.label)
            }
            if let p = progress[filename] {
                ProgressView(value: p).progressViewStyle(.linear)
            }
            HStack {
                if LocalModelStore.isDownloaded(filename) {
                    Text(T("Downloaded", "Descargado")).font(.caption).foregroundStyle(.green)
                    Spacer()
                    Button(T("Delete", "Borrar"), role: .destructive) {
                        LocalModelStore.delete(filename)
                        downloaded = LocalModelStore.downloaded()
                    }.font(.caption)
                } else {
                    Button(busy.contains(filename) ? T("Downloading…", "Descargando…") : T("Download", "Descargar")) {
                        download(id: id, filename: filename)
                    }.font(.caption).disabled(busy.contains(filename))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func download(id: String, filename: String) {
        busy.insert(filename)
        errorText = nil
        progress[filename] = 0
        Task {
            do {
                guard let url = URL(string: "https://huggingface.co/\(id)/resolve/main/\(filename)") else {
                    throw ProviderError.badURL(id)
                }
                let dl = ModelDownloader()
                _ = try await dl.download(from: url, to: LocalModelStore.url(for: filename)) { p in
                    Task { @MainActor in progress[filename] = p }
                }
                await MainActor.run {
                    progress[filename] = nil
                    busy.remove(filename)
                    downloaded = LocalModelStore.downloaded()
                }
            } catch {
                await MainActor.run {
                    progress[filename] = nil
                    busy.remove(filename)
                    errorText = error.localizedDescription
                }
            }
        }
    }
}
