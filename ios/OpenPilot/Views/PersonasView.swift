import SwiftUI

/// Gestión de personas: presets integrados + personalizados con nombre.
/// La persona elegida antepone su prompt al system prompt de cada chat.
struct PersonasView: View {
    @State private var selectedID = PersonaStore.selectedID
    @State private var custom = PersonaStore.custom
    @State private var showEditor = false
    @State private var editing: Persona?

    var body: some View {
        List {
            Section {
                ForEach(PersonaStore.builtins) { p in row(p) }
            } header: {
                Text(T("Built-in", "Integradas"))
            }
            Section {
                if custom.isEmpty {
                    Text(T("No custom personas yet. Tap + to create one.",
                           "Aún no hay personas personalizadas. Toca + para crear una."))
                        .font(.footnote).foregroundStyle(OP.textTertiary)
                }
                ForEach(custom) { p in
                    row(p)
                        .contextMenu {
                            Button { editing = p; showEditor = true } label: {
                                Label(T("Edit", "Editar"), systemImage: "pencil")
                            }
                            Button(role: .destructive) { delete(id: p.id) } label: {
                                Label(T("Delete", "Eliminar"), systemImage: "trash")
                            }
                        }
                }
                .onDelete { idx in
                    for i in idx { delete(id: custom[i].id) }
                }
            } header: {
                Text(T("Custom", "Personalizadas"))
            } footer: {
                Text(T("A persona prepends its instruction to every chat. Pick one to change the assistant's voice; 'Default' adds nothing.",
                       "Una persona antepone su instrucción a cada chat. Elige una para cambiar la voz del asistente; 'Por defecto' no añade nada."))
            }
        }
        .navigationTitle(T("Personas", "Personas"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = nil; showEditor = true } label: {
                    Image(systemName: "plus").accessibilityLabel(T("New persona", "Nueva persona"))
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            PersonaEditor(persona: editing) { saved in
                if let i = custom.firstIndex(where: { $0.id == saved.id }) {
                    PersonaStore.update(saved)
                } else {
                    PersonaStore.add(saved)
                }
                custom = PersonaStore.custom
            }
        }
        .onAppear { selectedID = PersonaStore.selectedID; custom = PersonaStore.custom }
    }

    private func row(_ p: Persona) -> some View {
        Button {
            PersonaStore.selectedID = p.id
            selectedID = p.id
            Haptic.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: p.symbol)
                    .font(.system(size: 16)).foregroundStyle(OP.accent).frame(width: 24)
                Text(p.name).foregroundStyle(OP.textPrimary)
                Spacer()
                if selectedID == p.id {
                    Image(systemName: "checkmark").foregroundStyle(OP.accent)
                }
            }
        }
    }

    private func delete(id: String) {
        PersonaStore.delete(id: id)
        custom = PersonaStore.custom
        selectedID = PersonaStore.selectedID
        Haptic.light()
    }
}

/// Editor de una persona personalizada (nombre, icono, prompt).
private struct PersonaEditor: View {
    let persona: Persona?
    let onSave: (Persona) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "star"
    @State private var prompt = ""

    private let symbols = ["star", "sparkles", "bolt", "book", "pencil.line", "quote.opening",
                           "chevron.left.forwardslash.chevron.right", "character.bubble",
                           "chart.xyaxis.line", "brain", "theatermasks", "globe", "heart", "flame"]

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Name", "Nombre")) {
                    TextField(T("e.g. Pirate", "p. ej. Pirata"), text: $name)
                }
                Section(T("Icon", "Icono")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(symbols, id: \.self) { s in
                            Button { symbol = s } label: {
                                Image(systemName: s)
                                    .font(.system(size: 18))
                                    .foregroundStyle(symbol == s ? OP.accent : OP.textSecondary)
                                    .frame(width: 34, height: 34)
                                    .background(symbol == s ? OP.accent.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section(T("Instruction", "Instrucción")) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                        .font(.body)
                }
            }
            .navigationTitle(persona == nil ? T("New persona", "Nueva persona") : T("Edit persona", "Editar persona"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Cancel", "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Save", "Guardar")) {
                        let p = Persona(id: persona?.id ?? UUID().uuidString,
                                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                        symbol: symbol,
                                        prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                                        isBuiltin: false)
                        onSave(p)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let p = persona { name = p.name; symbol = p.symbol; prompt = p.prompt }
            }
        }
    }
}