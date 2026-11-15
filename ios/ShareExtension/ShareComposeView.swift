import SwiftUI
import UniformTypeIdentifiers

/// Composición del share: preview del contenido + nota opcional. Al enviar,
/// escribe el item en el App Group y cierra la extensión; la app lo consume.
struct ShareComposeView: View {
    weak var extensionContext: NSExtensionContext?
    @State private var item = SharedItem(kind: .text, text: "", url: "", imageData: Data(), note: "", date: Date())
    @State private var loaded = false
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                if let img = previewImage {
                    Section {
                        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200)
                    }
                }
                if !item.url.isEmpty {
                    Section("URL") { Text(item.url).font(.callout) }
                }
                if !item.text.isEmpty && item.kind != .image {
                    Section("Text") { Text(item.text).font(.callout).lineLimit(6) }
                }
                Section("Note") {
                    TextField("Add a note…", text: $item.note, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle("Send to Open Pilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Send") { send() }.disabled(!loaded) }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let ctx = extensionContext, let items = ctx.inputItems as? [NSExtensionItem] else {
            loaded = true; return
        }
        for ext in items {
            for provider in ext.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let obj = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
                    if let data = obj as? Data {
                        item.kind = .image; item.imageData = data; previewImage = UIImage(data: data)
                    } else if let url = obj as? URL, let data = try? Data(contentsOf: url) {
                        item.kind = .image; item.imageData = data; previewImage = UIImage(data: data)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let obj = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                    if let url = obj as? URL { item.kind = .url; item.url = url.absoluteString }
                    else if let s = obj as? String { item.kind = .url; item.url = s }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    let obj = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier)
                    if let s = obj as? String { item.kind = .text; item.text = s }
                }
            }
        }
        loaded = true
    }

    private func send() {
        item.date = Date()
        ShareInbox.put(item)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.openpilot.app.share", code: 0))
    }
}
