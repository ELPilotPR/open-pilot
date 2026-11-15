import SwiftUI

/// Reusable prompt library: create, edit and delete templates. Insert any of them
/// into the composer by typing "/". Everything stays on this iPhone.
struct PromptLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var library = PromptLibrary.shared
    @State private var editing: Prompt?
    @State private var showNew = false

    var body: some View {
        List {
            Section {
                if library.prompts.isEmpty {
                    Text(T("No prompts yet", "Aún no hay prompts")).foregroundStyle(OP.textTertiary)
                } else {
                    ForEach(library.prompts) { p in
                        Button { editing = p } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).foregroundStyle(OP.textPrimary)
                                Text(p.body).font(.caption).foregroundStyle(OP.textSecondary).lineLimit(2)
                            }
                        }
                    }
                    .onDelete { library.delete(at: $0) }
                }
            } header: {
                Text(T("Prompts", "Prompts"))
            } footer: {
                Text(T("Type \"/\" in the composer to insert a prompt. Stored only on this iPhone.",
                       "Escribe \"/\" en el composer para insertar un prompt. Se guarda solo en este iPhone."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(OP.canvas)
        .tint(OP.accent)
        .navigationTitle(T("Prompt library", "Librería de prompts"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(T("New prompt", "Nuevo prompt"))
            }
            ToolbarItem(placement: .topBarTrailing) { Button(T("Done", "Listo")) { dismiss() } }
        }
        .sheet(item: $editing) { p in PromptEditorView(prompt: p) }
        .sheet(isPresented: $showNew) { PromptEditorView(prompt: nil) }
    }
}

/// Create or edit a single prompt (title + body).
struct PromptEditorView: View {
    let prompt: Prompt?
    @Environment(\.dismiss) private var dismiss
    @State private var library = PromptLibrary.shared
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(T("Title", "Título"), text: $title)
                }
                Section {
                    TextEditor(text: $text).frame(minHeight: 160)
                } header: {
                    Text(T("Prompt", "Prompt"))
                } footer: {
                    Text(T("Inserted into the composer when selected.", "Se inserta en el composer al seleccionarlo."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(OP.canvas)
            .tint(OP.accent)
            .navigationTitle(prompt == nil ? T("New prompt", "Nuevo prompt") : T("Edit prompt", "Editar prompt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(T("Cancel", "Cancelar")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(T("Save", "Guardar")) { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = prompt { title = p.title; text = p.body }
            }
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if let p = prompt {
            library.update(p.id, title: t, body: text)
        } else {
            library.add(title: t, body: text)
        }
        dismiss()
    }
}