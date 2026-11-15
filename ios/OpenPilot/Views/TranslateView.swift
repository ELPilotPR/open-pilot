import SwiftUI
import SwiftData
import UIKit

/// Modo traducir: elige idioma destino y traduce el texto con el provider del
/// usuario. Pensado para abrirse con el último mensaje (o cualquier texto).
struct TranslateView: View {
    let initialText: String
    @Environment(\.dismiss) private var dismiss
    @Query private var providers: [ProviderConfig]
    @AppStorage("selectedProviderID") private var selectedProviderID = "casa"
    @AppStorage("selectedModel") private var selectedModel = "swift-iq3_s"
    @State private var text: String
    @State private var target: String = TranslationSupport.defaultTarget()
    @State private var result: String?
    @State private var loading = false
    @State private var failed = false

    init(initialText: String) {
        self.initialText = initialText
        _text = State(initialValue: initialText)
    }

    private var provider: ProviderConfig? {
        providers.first { $0.id == selectedProviderID } ?? providers.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Text", "Texto")) {
                    TextEditor(text: $text).frame(minHeight: 90)
                }
                Section(T("Translate to", "Traducir a")) {
                    Picker(T("Language", "Idioma"), selection: $target) {
                        ForEach(TranslationSupport.languages) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Button {
                        translate()
                    } label: {
                        HStack {
                            if loading { ProgressView() }
                            Text(loading ? T("Translating…", "Traduciendo…") : T("Translate", "Traducir"))
                        }
                    }
                    .disabled(loading || provider == nil || text.trimmingCharacters(in: .whitespaces).isEmpty)
                    if failed {
                        Text(T("Couldn't reach the model.", "No se pudo contactar el modelo."))
                            .font(.caption).foregroundStyle(OP.danger)
                    }
                }
                if let r = result {
                    Section(T("Translation", "Traducción")) {
                        Text(r).textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = r; Haptic.light()
                        } label: { Label(T("Copy", "Copiar"), systemImage: "doc.on.doc") }
                    }
                }
            }
            .navigationTitle(T("Translate", "Traducir"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } } }
        }
    }

    private func translate() {
        guard let p = provider else { return }
        let kind = p.kind, base = p.baseURL, api = p.apiKey, model = selectedModel
        let prompt = TranslationSupport.prompt(text: text, targetCode: target)
        loading = true; failed = false
        Task { @MainActor in
            let r = await OneShot.complete(prompt: prompt, kind: kind, model: model, baseURL: base, apiKey: api)
            loading = false
            if let r { result = r } else { failed = true }
        }
    }
}